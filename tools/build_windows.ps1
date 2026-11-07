[CmdletBinding()]
param(
    [string]$GodotPath = "",
    [string]$OutputDirectory = "builds/windows",
    [switch]$SkipArchive
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$projectConfig = Join-Path $projectRoot "project.yaml"
$presetPath = Join-Path $projectRoot "export_presets.cfg"

if (-not $GodotPath) {
    $configuredPath = Select-String -LiteralPath $projectConfig -Pattern '^\s*path:\s*"([^"]+)"' | Select-Object -First 1
    if ($configuredPath) {
        $GodotPath = $configuredPath.Matches[0].Groups[1].Value
    }
}

if (-not $GodotPath) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($godotCommand) {
        $GodotPath = $godotCommand.Source
    }
}

if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot nao encontrado. Informe o caminho com -GodotPath 'C:\caminho\godot.exe'."
}

if (-not (Test-Path -LiteralPath $presetPath -PathType Leaf)) {
    throw "Preset de exportacao ausente: $presetPath"
}

$resolvedOutput = Join-Path $projectRoot $OutputDirectory
$gameExe = Join-Path $resolvedOutput "Ecos-de-Aethra.exe"
$guidePath = Join-Path $resolvedOutput "COMO-JOGAR.txt"
$archivePath = Join-Path (Split-Path -Parent $resolvedOutput) "Ecos-de-Aethra-Windows.zip"

New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null

Write-Host "Exportando Ecos de Aethra para Windows x64..."
& $GodotPath --headless --path $projectRoot --export-release "Windows x64" $gameExe
if ($LASTEXITCODE -ne 0) {
    throw "A exportacao falhou (codigo $LASTEXITCODE). Confirme que os templates de exportacao da mesma versao do Godot estao instalados."
}

if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) {
    throw "O Godot terminou sem criar o executavel esperado: $gameExe"
}

$guide = @"
ECOS DE AETHRA - JOGO 3D

Abra Ecos-de-Aethra.exe para jogar offline.

Para entrar em um servidor dedicado existente, execute:
Ecos-de-Aethra.exe -- --connect=IP:7777 --user=Nome --pass=SENHA
No primeiro acesso, acrescente --register. Use uma senha exclusiva para o jogo.
A conexao usa UDP; o servidor deve estar acessivel na porta informada.

O executavel nao inclui uma tela de hospedagem de partida.
Hospedagem e operacao do servidor sao documentadas em server/README.md no repositorio.
O jogador nao precisa instalar Godot.
"@
Set-Content -LiteralPath $guidePath -Value $guide -Encoding UTF8

if (-not $SkipArchive) {
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }
    Compress-Archive -LiteralPath $gameExe, $guidePath -DestinationPath $archivePath -CompressionLevel Optimal
    Write-Host "Pacote para envio: $archivePath"
}

Write-Host "Executavel pronto: $gameExe"
