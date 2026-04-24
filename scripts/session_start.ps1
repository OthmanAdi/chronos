# chronos — SessionStart hook (PowerShell)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

$Input = [Console]::In.ReadToEnd()
$Session = Resolve-SessionId -Input $Input
$Ledger = Get-LedgerPath -Session $Session
$State = Get-StatePath -Session $Session
$NowUtc = Get-NowUtcIso
$NowLocal = Get-NowLocalIso
$NowEpoch = Get-NowEpoch
$Tz = Get-TzName
$Offset = Get-UtcOffset

# Reset ledger
Set-Content -Path $Ledger -Value '' -NoNewline

$StateObj = @{
    session_id = $Session
    started_at_utc = $NowUtc
    started_at_local = $NowLocal
    started_at_epoch = $NowEpoch
    tz = $Tz
    utc_offset = $Offset
    turn = 0
    last_user_at_utc = $NowUtc
    last_user_at_epoch = $NowEpoch
}
$StateObj | ConvertTo-Json -Compress | Set-Content -Path $State -NoNewline

try { Invoke-LedgerCleanup } catch {}

Set-Content -Path (Join-Path $script:ChronosHome 'current-session') -Value $Session -NoNewline

$Ctx = @"
chronos baseline
now_utc: $NowUtc
now_local: $NowLocal
tz: $Tz ($Offset)
ledger: $Ledger
state: $State
session: $Session

Before reasoning about 'when' or 'how long ago', consult the ledger or run ``date -u``. Follow chronos/SKILL.md decision rules.
"@

Write-AdditionalContext -Event 'SessionStart' -Context $Ctx
exit 0
