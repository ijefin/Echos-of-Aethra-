[CmdletBinding()]
param(
    [string]$Godot = "",
    [switch]$Qa,
    [string[]]$GameArgs = @()
)
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $pin = Select-String -LiteralPath (Join-Path $projectRoot 'project.yaml') -Pattern '^\s*path:\s*"([^"]+)"' | Select-Object -First 1
    if ($pin) { $Godot = $pin.Matches[0].Groups[1].Value }
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $installed) { throw 'Informe -Godot <executavel> ou configure engine.path em project.yaml.' }
    $Godot = $installed.Source
}
if ($Qa) { $GameArgs = @('--no_save', '--mute') + $GameArgs }
& $Godot --path $projectRoot -- @GameArgs
exit $LASTEXITCODE
