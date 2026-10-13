# Downloads official TinyCC 0.9.27 Windows 64-bit portable distribution.
# Never installs into PATH, never runs downloaded files during installation.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$url = 'https://download.savannah.gnu.org/releases/tinycc/tcc-0.9.27-win64-bin.zip'
$sha256 = '34a721949a2583fdff725312da092fa0f5f1f284b702e6f811c6954714faabb2'
$zip = Join-Path $env:TEMP 'data-rescue-tcc-0.9.27-win64-bin.zip'
$target = Join-Path $root 'tools'
Write-Host 'Downloading TinyCC from its official release archive.' -ForegroundColor Cyan
Write-Host $url
Write-Host 'License: LGPL-2.1; separate third-party component.'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -TimeoutSec 90
    $actual = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash.ToLowerInvariant()
    if ($actual -ne $sha256) { throw "SHA256 mismatch: $actual" }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $target + '_install_tmp')
    $src = Join-Path ($target + '_install_tmp') 'tcc'
    if (-not (Test-Path (Join-Path $src 'tcc.exe'))) { throw 'Downloaded package did not contain tcc/tcc.exe' }
    $dst = Join-Path $target 'tcc'
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Move-Item -Path $src -Destination $dst
    Remove-Item ($target + '_install_tmp') -Recurse -Force
    Write-Host 'Portable compiler is ready. No global installation was needed.' -ForegroundColor Green
} catch {
    Write-Host ('Setup failed: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'You can also install GCC or Clang and add it to PATH.'
    if (Test-Path ($target + '_install_tmp')) { Remove-Item ($target + '_install_tmp') -Recurse -Force }
    exit 1
} finally {
    if (Test-Path $zip) { Remove-Item $zip -Force }
}
