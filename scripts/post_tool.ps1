# chronos — PostToolUse hook (PowerShell)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

$Input = [Console]::In.ReadToEnd()
$Session = Resolve-SessionId -Input $Input
$Ledger = Get-LedgerPath -Session $Session
$NowUtc = Get-NowUtcIso
$NowEpoch = Get-NowEpoch

$Obj = $Input | ConvertFrom-Json
$Tool = if ($Obj.tool_name) { $Obj.tool_name } else { 'unknown' }
$TuId = if ($Obj.tool_use_id) { $Obj.tool_use_id } else { "na-$NowEpoch" }

$StartedEpoch = 0
if (Test-Path $Ledger) {
    $Lines = Get-Content $Ledger
    foreach ($line in $Lines) {
        try {
            $e = $line | ConvertFrom-Json -ErrorAction Stop
            if ($e.tool_use_id -eq $TuId -and $e.started_epoch) {
                $StartedEpoch = [int]$e.started_epoch
            }
        } catch {}
    }
}

$DurationMs = if ($StartedEpoch -gt 0) { ($NowEpoch - $StartedEpoch) * 1000 } else { 0 }

$Success = $true
if ($Obj.tool_response) {
    if ($Obj.tool_response.is_error -or $Obj.tool_response.error) { $Success = $false }
}

$Entry = @{
    tool_use_id = $TuId
    tool = $Tool
    finished_at = $NowUtc
    finished_epoch = $NowEpoch
    duration_ms = $DurationMs
    success = $Success
} | ConvertTo-Json -Compress

Add-Content -Path $Ledger -Value $Entry
exit 0
