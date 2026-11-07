[CmdletBinding()]
param(
    [ValidateSet('unit', 'offline', 'world', 'network', 'all')]
    [string]$Suite = 'unit',
    [string]$Godot = "",
    [int]$TimeoutSec = 120
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($TimeoutSec -lt 1) { throw 'TimeoutSec deve ser positivo.' }
if (-not $Godot) {
    $pin = Select-String -LiteralPath (Join-Path $projectRoot 'project.yaml') -Pattern '^\s*path:\s*"([^"]+)"' | Select-Object -First 1
    if ($pin) { $Godot = $pin.Matches[0].Groups[1].Value }
}
if (-not $Godot -or -not (Test-Path -LiteralPath $Godot)) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if (-not $installed) { throw 'Informe -Godot <executavel> ou configure engine.path em project.yaml.' }
    $Godot = $installed.Source
}
$logRoot = Join-Path $projectRoot ('.scratch/test-results/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$testFiles = @()
if ($Suite -in @('unit', 'all')) {
    $testFiles += Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests/unit') -Recurse -Filter '*_test.gd' |
        Where-Object { $_.Name -ne 'icon_baker_test.gd' }
}
if ($Suite -eq 'world') {
    $testFiles += Get-ChildItem -LiteralPath (Join-Path $projectRoot 'tests/unit/world') -Filter '*_test.gd'
}
if ($Suite -in @('offline', 'all')) {
    foreach ($testName in @('shop', 'equip', 'gear_look', 'quests', 'world_reach', 'vocations', 'mage_combat', 'floors', 'day_night', 'core_light', 'enemy_ai')) {
        $testFiles += Get-Item -LiteralPath (Join-Path $projectRoot "src/game/tools/test_$testName.gd")
    }
}
if ($Suite -in @('world', 'all')) {
    $testFiles += Get-Item -LiteralPath (Join-Path $projectRoot 'tests/integration/world/world_module_test.gd')
}
$failed = 0
$passed = 0
foreach ($testFile in $testFiles) {
    $relative = $testFile.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
    $logName = $relative.Replace('/', '_')
    $stdout = Join-Path $logRoot "$logName.out.log"
    $stderr = Join-Path $logRoot "$logName.err.log"
    $testArguments = @('--headless', '--path', "`"$projectRoot`"", '-s', "res://$relative", '--', '--no_save', '--mute')
    $process = Start-Process -FilePath $Godot -ArgumentList $testArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    # Cache the native handle before exit; Windows PowerShell otherwise loses ExitCode
    # for very short-lived processes returned by Start-Process.
    $null = $process.Handle
    $timedOut = -not $process.WaitForExit($TimeoutSec * 1000)
    if ($timedOut) { Stop-Process -Id $process.Id -Force; $process.WaitForExit() }
    $process.Refresh()
    $output = @(Get-Content -LiteralPath $stdout -ErrorAction SilentlyContinue) + @(Get-Content -LiteralPath $stderr -ErrorAction SilentlyContinue)
    $errors = @($output | Select-String -Pattern 'SCRIPT ERROR|Parse Error|^(FAIL(ED|URE)?|CHECK FAIL|FALHOU)\b|:\s*(FAIL(ED|URE)?|FALHOU)\b|\b[1-9][0-9]*\s+(FAIL|falhou|falharam)\b')
    if ($timedOut -or $process.ExitCode -ne 0 -or $errors.Count -gt 0) {
        $failed++
        Write-Host "FAIL $relative (exit=$($process.ExitCode), timeout=$timedOut)"
        $errors | Select-Object -First 8 | ForEach-Object { Write-Host $_.Line }
    } else {
        $passed++
        Write-Host "PASS $relative"
    }
}
if ($Suite -in @('network', 'all')) {
    & (Join-Path $PSScriptRoot 'net_session_test.ps1') -Godot $Godot
    if ($LASTEXITCODE -ne 0) { $failed++ } else { $passed++ }
}
if ($passed + $failed -eq 0) { throw "Nenhum teste encontrado para $Suite." }
Write-Host "RESULT $Suite : $passed passaram, $failed falharam. Logs: $logRoot"
if ($failed -gt 0) { exit 1 }
exit 0
