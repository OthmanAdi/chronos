# chronos — ledger reader (PowerShell)
#
# Usage:
#   ledger_read.ps1 [-Session SID] [-Tool NAME] [-ArgsHash HASH] [-Since 10m|1h|2d] [-Last] [-Count] [-PathOnly]

[CmdletBinding()]
param(
    [string]$Session,
    [string]$Tool,
    [string]$ArgsHash,
    [string]$Since,
    [switch]$Last,
    [switch]$Count,
    [switch]$PathOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_lib.ps1')

if (-not $Session) {
    $cur = Join-Path $script:ChronosHome 'current-session'
    if (Test-Path $cur) { $Session = (Get-Content $cur -Raw).Trim() }
    else { Write-Error 'no session — pass -Session SID'; exit 2 }
}

$Ledger = Get-LedgerPath -Session $Session
if ($PathOnly) { Write-Output $Ledger; exit 0 }
if (-not (Test-Path $Ledger)) { Write-Error "no ledger at $Ledger"; exit 0 }

$NowEpoch = Get-NowEpoch
$CutoffEpoch = 0
if ($Since) { $CutoffEpoch = $NowEpoch - (ConvertTo-DurationSec -D $Since) }

$Entries = Get-Content $Ledger | ForEach-Object {
    try { $_ | ConvertFrom-Json -ErrorAction Stop } catch { $null }
} | Where-Object { $_ }

if ($Tool) { $Entries = $Entries | Where-Object { $_.tool -eq $Tool } }
if ($ArgsHash) { $Entries = $Entries | Where-Object { $_.args_hash -eq $ArgsHash } }
if ($CutoffEpoch -gt 0) {
    $Entries = $Entries | Where-Object {
        $ep = if ($_.started_epoch) { [int]$_.started_epoch } elseif ($_.finished_epoch) { [int]$_.finished_epoch } else { 0 }
        $ep -ge $CutoffEpoch
    }
}

if ($Last) { $Entries = $Entries | Select-Object -Last 1 }
if ($Count) { Write-Output ($Entries | Measure-Object).Count; exit 0 }

$Entries | ForEach-Object { $_ | ConvertTo-Json -Compress }
