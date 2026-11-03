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
ECOS DE AETHRA - COMO JOGAR ONLINE

Para quem hospeda:
1. Abra Ecos-de-Aethra.exe.
2. Escolha seu nome e classe.
3. Deixe a porta 7777 e clique em "Hospedar partida".
4. Passe ao convidado o seu IP do Radmin VPN, ZeroTier ou Tailscale.

Para quem entra:
1. Entre na mesma rede virtual do host.
2. Abra Ecos-de-Aethra.exe.
3. Digite o IP que o host enviou em "IP do host".
4. Deixe a porta 7777 e clique em "Entrar na partida".

Se nao conectar:
- Confirme que os dois estao na mesma VPN/rede virtual.
- Libere Ecos-de-Aethra.exe no Firewall do Windows quando ele perguntar.
- Confirme que o host abriu a partida antes do convidado tentar entrar.
- A conexao usa UDP na porta 7777.

O convidado nao precisa instalar Godot.
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
