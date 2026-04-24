# chronos — Stop hook (PowerShell)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

$Input = [Console]::In.ReadToEnd()
$Session = Resolve-SessionId -Input $Input
$State = Get-StatePath -Session $Session
$NowEpoch = Get-NowEpoch

if (-not (Test-Path $State)) { exit 0 }
$S = Get-Content $State -Raw | ConvertFrom-Json
$SinceLast = $NowEpoch - [int]$S.last_user_at_epoch

if ($SinceLast -gt $script:IdleThresholdSec) {
    [Console]::Error.WriteLine("chronos: stop after idle=${SinceLast}s (threshold=$($script:IdleThresholdSec)s). If autonomous, consider escalation.")
}
exit 0
