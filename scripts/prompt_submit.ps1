# chronos — UserPromptSubmit hook (PowerShell)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

$Input = [Console]::In.ReadToEnd()
$Session = Resolve-SessionId -Input $Input
$State = Get-StatePath -Session $Session
$Ledger = Get-LedgerPath -Session $Session

# Bootstrap BEFORE capturing NOW (otherwise bootstrap writes a later started_at → negative deltas).
if (-not (Test-Path $State)) {
    & (Join-Path $PSScriptRoot 'session_start.ps1') < $Input | Out-Null
}

$NowUtc = Get-NowUtcIso
$NowEpoch = Get-NowEpoch

$PrevLastEpoch = 0; $PrevStartEpoch = $NowEpoch; $PrevTurn = 0
if (Test-Path $State) {
    $S = Get-Content $State -Raw | ConvertFrom-Json
    $PrevLastEpoch = [int]$S.last_user_at_epoch
    $PrevStartEpoch = [int]$S.started_at_epoch
    $PrevTurn = [int]$S.turn
}

$SinceLast = $NowEpoch - $PrevLastEpoch
$SessionDuration = $NowEpoch - $PrevStartEpoch
$NewTurn = $PrevTurn + 1

if ($SinceLast -lt 0) { $SinceLast = 0 }
if ($SessionDuration -lt 0) { $SessionDuration = 0 }

$S.last_user_at_utc = $NowUtc
$S.last_user_at_epoch = $NowEpoch
$S.turn = $NewTurn
$S | ConvertTo-Json -Compress | Set-Content -Path $State -NoNewline

function Format-Duration($s) {
    if ($s -lt 60) { "${s}s" }
    elseif ($s -lt 3600) { "$([int]($s/60))m $($s%60)s" }
    elseif ($s -lt 86400) { "$([int]($s/3600))h $([int](($s%3600)/60))m" }
    else { "$([int]($s/86400))d $([int](($s%86400)/3600))h" }
}

$SinceH = Format-Duration $SinceLast
$SessionH = Format-Duration $SessionDuration

$IdleWarn = ''
if ($SinceLast -gt $script:IdleThresholdSec -and $NewTurn -gt 1) {
    $IdleWarn = "`nidle_warning: user was away for $SinceH — if running autonomously, re-confirm direction."
}

$Ctx = @"
chronos turn
now_utc: $NowUtc
turn: $NewTurn
session_duration: $SessionH ($SessionDuration s)
since_last_user: $SinceH ($SinceLast s)
ledger: $Ledger$IdleWarn
"@

Write-AdditionalContext -Event 'UserPromptSubmit' -Context $Ctx
exit 0
