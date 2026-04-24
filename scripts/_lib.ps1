# chronos — shared library (PowerShell)
# Dot-sourced by all hook scripts on Windows.

$ErrorActionPreference = 'Stop'

$script:ChronosHome = if ($env:CHRONOS_HOME) { $env:CHRONOS_HOME } else { Join-Path $HOME '.chronos' }
$script:IdleThresholdSec = if ($env:CHRONOS_IDLE_THRESHOLD_SEC) { [int]$env:CHRONOS_IDLE_THRESHOLD_SEC } else { 900 }
$script:RetentionDays = if ($env:CHRONOS_LEDGER_RETENTION_DAYS) { [int]$env:CHRONOS_LEDGER_RETENTION_DAYS } else { 30 }
$script:GzipAfterDays = if ($env:CHRONOS_LEDGER_GZIP_AFTER_DAYS) { [int]$env:CHRONOS_LEDGER_GZIP_AFTER_DAYS } else { 1 }

if (-not (Test-Path $script:ChronosHome)) { New-Item -ItemType Directory -Path $script:ChronosHome -Force | Out-Null }

function Get-NowUtcIso { (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
function Get-NowLocalIso { (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz") }
function Get-NowEpoch { [int][double]::Parse((Get-Date -UFormat %s)) }
function Get-TzName {
    try { [System.TimeZoneInfo]::Local.Id } catch { 'UTC' }
}
function Get-UtcOffset {
    $o = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date))
    ('{0}{1:D2}{2:D2}' -f $(if ($o.Ticks -ge 0) {'+'} else {'-'}), [Math]::Abs($o.Hours), [Math]::Abs($o.Minutes))
}

function Read-JsonField {
    param([string]$Field, [string]$Input)
    try {
        $obj = $Input | ConvertFrom-Json -ErrorAction Stop
        return $obj.$Field
    } catch { return '' }
}

function Write-AdditionalContext {
    param([string]$Event, [string]$Context)
    $obj = @{
        hookSpecificOutput = @{
            hookEventName = $Event
            additionalContext = $Context
        }
    }
    $obj | ConvertTo-Json -Compress -Depth 5
}

function Get-LedgerPath { param($Session) Join-Path $script:ChronosHome "ledger-$Session.jsonl" }
function Get-StatePath  { param($Session) Join-Path $script:ChronosHome "session-$Session.json" }

function Get-ArgsHash {
    param([string]$Input)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Input)
    $hash = $sha.ComputeHash($bytes)
    ([BitConverter]::ToString($hash) -replace '-','').ToLower().Substring(0,12)
}

function ConvertTo-DurationSec {
    param([string]$D)
    if ($D -match '^(\d+)([smhd])$') {
        $n = [int]$Matches[1]; $u = $Matches[2]
        switch ($u) { 's' {return $n}; 'm' {return $n*60}; 'h' {return $n*3600}; 'd' {return $n*86400} }
    }
    return [int]$D
}

function Invoke-LedgerCleanup {
    Get-ChildItem -Path $script:ChronosHome -Filter 'ledger-*.jsonl' -ErrorAction SilentlyContinue | ForEach-Object {
        $ageDays = (New-TimeSpan -Start $_.LastWriteTime -End (Get-Date)).Days
        if ($ageDays -gt $script:RetentionDays) {
            Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
            Remove-Item "$($_.FullName).gz" -Force -ErrorAction SilentlyContinue
        } elseif ($ageDays -gt $script:GzipAfterDays -and -not (Test-Path "$($_.FullName).gz")) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
                $out = New-Object System.IO.FileStream("$($_.FullName).gz"), Create, Write
                $gz = New-Object System.IO.Compression.GZipStream($out, [System.IO.Compression.CompressionMode]::Compress)
                $gz.Write($bytes, 0, $bytes.Length); $gz.Close(); $out.Close()
                Remove-Item $_.FullName -Force
            } catch { }
        }
    }
}

function Resolve-SessionId {
    param([string]$Input)
    $sid = Read-JsonField -Field 'session_id' -Input $Input
    if (-not $sid) {
        $file = Join-Path $script:ChronosHome 'current-session'
        if (Test-Path $file) {
            $sid = Get-Content $file -Raw
        } else {
            $sid = "anon-$(Get-NowEpoch)"
            Set-Content -Path $file -Value $sid -NoNewline
        }
    }
    $sid.Trim()
}
