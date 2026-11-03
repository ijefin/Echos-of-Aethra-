[CmdletBinding()]
param(
    [string]$Version = "4.7.2.stable",
    [string]$ArchiveUrl = "https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Net.Http

function Get-RangeBytes {
    param(
        [System.Net.Http.HttpClient]$Client,
        [long]$Start,
        [long]$End
    )

    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $ArchiveUrl)
    $request.Headers.Range = [System.Net.Http.Headers.RangeHeaderValue]::new($Start, $End)
    $response = $Client.SendAsync($request).GetAwaiter().GetResult()
    try {
        if ($response.StatusCode -ne [System.Net.HttpStatusCode]::PartialContent) {
            throw "O servidor nao aceitou o download parcial (HTTP $([int]$response.StatusCode))."
        }
        return $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
    }
    finally {
        $response.Dispose()
        $request.Dispose()
    }
}

function Expand-ZipEntry {
    param(
        [byte[]]$Compressed,
        [int]$Method,
        [long]$ExpectedLength
    )

    if ($Method -eq 0) {
        return $Compressed
    }
    if ($Method -ne 8) {
        throw "Metodo de compressao ZIP nao suportado: $Method"
    }

    $inputStream = [System.IO.MemoryStream]::new($Compressed, $false)
    $deflateStream = [System.IO.Compression.DeflateStream]::new($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
    $outputStream = [System.IO.MemoryStream]::new([int]$ExpectedLength)
    try {
        $deflateStream.CopyTo($outputStream)
        return $outputStream.ToArray()
    }
    finally {
        $outputStream.Dispose()
        $deflateStream.Dispose()
        $inputStream.Dispose()
    }
}

$templateDirectory = Join-Path $env:APPDATA "Godot\export_templates\$Version"
$requiredFiles = @(
    "windows_release_x86_64.exe",
    "windows_release_x86_64_console.exe",
    "version.txt"
)

$alreadyInstalled = $true
foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $templateDirectory $file) -PathType Leaf)) {
        $alreadyInstalled = $false
        break
    }
}
if ($alreadyInstalled) {
    Write-Host "Template Windows x64 ja instalado em: $templateDirectory"
    exit 0
}

$client = [System.Net.Http.HttpClient]::new()
try {
    $headRequest = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $ArchiveUrl)
    $headResponse = $client.SendAsync($headRequest).GetAwaiter().GetResult()
    try {
        $archiveLength = $headResponse.Content.Headers.ContentLength
        if (-not $archiveLength) {
            throw "O servidor nao informou o tamanho do arquivo oficial."
        }
    }
    finally {
        $headResponse.Dispose()
        $headRequest.Dispose()
    }

    $tailLength = [Math]::Min(131072, $archiveLength)
    $tailStart = $archiveLength - $tailLength
    $tail = Get-RangeBytes -Client $client -Start $tailStart -End ($archiveLength - 1)

    $eocdOffset = -1
    for ($i = $tail.Length - 22; $i -ge 0; $i--) {
        if ([BitConverter]::ToUInt32($tail, $i) -eq 0x06054b50) {
            $eocdOffset = $i
            break
        }
    }
    if ($eocdOffset -lt 0) {
        throw "Diretorio ZIP nao encontrado no pacote oficial."
    }

    $centralSize = [long][BitConverter]::ToUInt32($tail, $eocdOffset + 12)
    $centralOffset = [long][BitConverter]::ToUInt32($tail, $eocdOffset + 16)
    $central = Get-RangeBytes -Client $client -Start $centralOffset -End ($centralOffset + $centralSize - 1)

    $entries = @{}
    $position = 0
    while ($position -lt $central.Length) {
        if ([BitConverter]::ToUInt32($central, $position) -ne 0x02014b50) {
            throw "Entrada invalida no diretorio ZIP (offset $position)."
        }
        $method = [BitConverter]::ToUInt16($central, $position + 10)
        $compressedSize = [long][BitConverter]::ToUInt32($central, $position + 20)
        $uncompressedSize = [long][BitConverter]::ToUInt32($central, $position + 24)
        $nameLength = [BitConverter]::ToUInt16($central, $position + 28)
        $extraLength = [BitConverter]::ToUInt16($central, $position + 30)
        $commentLength = [BitConverter]::ToUInt16($central, $position + 32)
        $localOffset = [long][BitConverter]::ToUInt32($central, $position + 42)
        $name = [System.Text.Encoding]::UTF8.GetString($central, $position + 46, $nameLength)
        $leaf = [System.IO.Path]::GetFileName($name)
        if ($leaf -in $requiredFiles) {
            $entries[$leaf] = @{
                Method = $method
                CompressedSize = $compressedSize
                UncompressedSize = $uncompressedSize
                LocalOffset = $localOffset
            }
        }
        $position += 46 + $nameLength + $extraLength + $commentLength
    }

    foreach ($file in $requiredFiles) {
        if (-not $entries.ContainsKey($file)) {
            throw "Arquivo esperado nao encontrado no pacote oficial: $file"
        }
    }

    New-Item -ItemType Directory -Path $templateDirectory -Force | Out-Null
    foreach ($file in $requiredFiles) {
        $entry = $entries[$file]
        Write-Host "Baixando somente $file..."
        $header = Get-RangeBytes -Client $client -Start $entry.LocalOffset -End ($entry.LocalOffset + 29)
        if ([BitConverter]::ToUInt32($header, 0) -ne 0x04034b50) {
            throw "Cabecalho ZIP invalido para $file."
        }
        $nameLength = [BitConverter]::ToUInt16($header, 26)
        $extraLength = [BitConverter]::ToUInt16($header, 28)
        $dataStart = $entry.LocalOffset + 30 + $nameLength + $extraLength
        $compressed = Get-RangeBytes -Client $client -Start $dataStart -End ($dataStart + $entry.CompressedSize - 1)
        $content = Expand-ZipEntry -Compressed $compressed -Method $entry.Method -ExpectedLength $entry.UncompressedSize
        if ($content.LongLength -ne $entry.UncompressedSize) {
            throw "Tamanho inesperado ao extrair ${file}: $($content.LongLength) bytes."
        }
        [System.IO.File]::WriteAllBytes((Join-Path $templateDirectory $file), $content)
    }
}
finally {
    $client.Dispose()
}

Write-Host "Template Windows x64 instalado em: $templateDirectory"
