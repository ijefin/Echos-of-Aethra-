# Teste de integração da rede do Ecos de Aethra (protótipo 3D):
# 1 servidor dedicado + 2 clientes headless (processos separados) em 127.0.0.1.
# Fase 2: reinicia o servidor e confere a persistência com um 3º cliente.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools/net_session_test.ps1 [-Port 17777] [-Godot <exe>]
#
# Saída: linhas "CHECK PASS|FAIL <papel>: <item>" e um resumo. Código de saída 0 = tudo passou.
param(
	[int]$Port = 17777,
	[string]$Godot = "C:/Users/Jeff/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe",
	[int]$TimeoutSec = 150
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("aethra-net-test-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null
$data = (Join-Path $work "data") -replace "\\", "/"
$state = (Join-Path $work "bruno-state.json") -replace "\\", "/"
Write-Host "dados do teste: $work"

function Start-Godot([string]$name, [string[]]$extra) {
	$out = Join-Path $work "$name.out.log"
	$err = Join-Path $work "$name.err.log"
	$argList = @("--headless", "--path", "`"$root`"") + $extra
	return Start-Process -FilePath $Godot -ArgumentList $argList -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -NoNewWindow
}

function Wait-Ready([string]$name, [int]$sec) {
	$out = Join-Path $work "$name.out.log"
	$deadline = (Get-Date).AddSeconds($sec)
	while ((Get-Date) -lt $deadline) {
		if ((Test-Path $out) -and (Select-String -Path $out -Pattern "AETHRA_SERVER_READY" -Quiet)) { return $true }
		Start-Sleep -Milliseconds 200
	}
	return $false
}

function Start-Server([string]$name) {
	$p = Start-Godot $name @("-s", "res://src/game/net/server_main.gd", "--", "--port=$Port", "--data_dir=$data", "--log_level=info")
	if (-not (Wait-Ready $name 30)) { throw "servidor $name não ficou pronto (veja $work)" }
	return $p
}

function Start-Bot([string]$role) {
	return Start-Godot "bot-$role" @("-s", "res://src/game/net/tests/net_bot.gd", "--", "--role=$role", "--port=$Port", "--state=$state")
}

function Wait-All($procs, [int]$sec) {
	$deadline = (Get-Date).AddSeconds($sec)
	foreach ($p in $procs) {
		$left = [int][Math]::Max(1, ($deadline - (Get-Date)).TotalSeconds)
		if (-not $p.WaitForExit($left * 1000)) { Write-Host "TIMEOUT: processo $($p.Id)"; $p.Kill() }
	}
}

$server = $null
try {
	Write-Host "== fase 1: servidor + Alice + Bruno =="
	$server = Start-Server "server1"
	$alice = Start-Bot "alice"
	Start-Sleep -Milliseconds 300
	$bruno = Start-Bot "bruno"
	Wait-All @($alice, $bruno) $TimeoutSec
	Stop-Process -Id $server.Id -Force   # queda brusca do servidor: só vale o que já foi salvo
	$server.WaitForExit(5000) | Out-Null
	$server = $null

	Write-Host "== fase 2: servidor reiniciado + relogin do Bruno =="
	$server = Start-Server "server2"
	$re = Start-Bot "relogin"
	Wait-All @($re) 60
}
finally {
	if ($server -ne $null -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
}

$lines = @()
foreach ($f in @("bot-alice", "bot-bruno", "bot-relogin")) {
	$path = Join-Path $work "$f.out.log"
	if (Test-Path $path) { $lines += Get-Content $path | Where-Object { $_ -match "^CHECK |^BOT_DONE " } }
}
foreach ($f in @("server1", "server2")) {
	$path = Join-Path $work "$f.out.log"
	if (Test-Path $path) {
		Write-Host "--- log $f ---"
		Get-Content $path | Where-Object { $_ -match "\[(INFO|WARN|ERROR)\]" } | ForEach-Object { Write-Host "  $_" }
	}
}
$errs = @()
foreach ($f in Get-ChildItem $work -Filter "*.err.log") {
	$errs += Get-Content $f.FullName | Where-Object { $_ -match "SCRIPT ERROR|Parse Error" } | ForEach-Object { "$($f.Name): $_" }
}
Write-Host "--- verificação ---"
$lines | ForEach-Object { Write-Host $_ }
$pass = @($lines | Where-Object { $_ -match "^CHECK PASS" }).Count
$fail = @($lines | Where-Object { $_ -match "^CHECK FAIL" }).Count
$done = @($lines | Where-Object { $_ -match "^BOT_DONE" }).Count
if ($errs.Count -gt 0) { Write-Host "--- erros de script ---"; $errs | Select-Object -First 20 | ForEach-Object { Write-Host $_ } }
$ok = ($fail -eq 0) -and ($done -eq 3) -and ($pass -gt 0) -and ($errs.Count -eq 0)
Write-Host ("NET_SESSION_TEST: {0} ({1} PASS, {2} FAIL, {3}/3 bots concluíram, {4} erros de script)" -f ($(if ($ok) { "OK" } else { "FAIL" }), $pass, $fail, $done, $errs.Count))
if ($ok) { Remove-Item -Recurse -Force $work } else { Write-Host "logs mantidos em $work" }
exit $(if ($ok) { 0 } else { 1 })
