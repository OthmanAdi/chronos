# chronos — PreToolUse hook (PowerShell)
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
$ToolInput = if ($Obj.tool_input) { $Obj.tool_input | ConvertTo-Json -Compress -Depth 10 } else { '{}' }
$Hash = Get-ArgsHash -Input $ToolInput

$Entry = @{
    tool_use_id = $TuId
    tool = $Tool
    args_hash = $Hash
    started_at = $NowUtc
    started_epoch = $NowEpoch
} | ConvertTo-Json -Compress

Add-Content -Path $Ledger -Value $Entry
exit 0
