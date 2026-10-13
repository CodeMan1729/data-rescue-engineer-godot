# Downloads the official Windows Godot ZIP with resume, progress and SHA512 verification.
# It does not alter system PATH or require admin.
param([string]$Proxy = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$version = '4.7.2'
$url = "https://github.com/godotengine/godot/releases/download/$version-stable/Godot_v$version-stable_win64.exe.zip"
$target = Join-Path $root 'tools\godot'
# SHA512 hash of the official ZIP, independently listed by Scoop's Godot manifest.
$expectedSha512 = '83decd58fdf67b9d657958a1ae6bf1929c20785315a81effe245874cdc57acb709bf868e00778a96984338c1b29dafdb453c6847747694621c6ecf5da2259993'
$archive = Join-Path $env:TEMP ("data-rescue-godot-$version.zip")
$part = $archive + '.part'
$exe = Join-Path $target "Godot_v$version-stable_win64.exe"
$maxAttempts = 5

function Fmt-MB([double]$b) { '{0:N1} MB' -f ($b / 1MB) }
function Fmt-Time([double]$s) {
    if ($s -lt 0 -or [double]::IsInfinity($s) -or [double]::IsNaN($s)) { return '--:--' }
    $t = [TimeSpan]::FromSeconds([math]::Round($s)); return ('{0:00}:{1:00}:{2:00}' -f [int]$t.TotalHours, $t.Minutes, $t.Seconds)
}
function Get-Hash([string]$p) { (Get-FileHash -Algorithm SHA512 -LiteralPath $p).Hash.ToLowerInvariant() }

function New-Request([string]$method, [long]$from) {
    $req = [Net.HttpWebRequest]::Create($url)
    $req.Method = $method
    $req.UserAgent = 'data-rescue-launcher'
    $req.Timeout = 30000
    $req.ReadWriteTimeout = 30000
    $req.AllowAutoRedirect = $true
    if ($Proxy) { $req.Proxy = New-Object Net.WebProxy($Proxy) }
    elseif ($env:HTTPS_PROXY) { $req.Proxy = New-Object Net.WebProxy($env:HTTPS_PROXY) }
    else { $req.Proxy = [Net.WebRequest]::GetSystemWebProxy(); $req.Proxy.Credentials = [Net.CredentialCache]::DefaultCredentials }
    if ($from -gt 0) { $req.AddRange([long]$from) }
    return $req
}

function Get-TotalSize {
    try {
        $resp = (New-Request 'HEAD' 0).GetResponse()
        $len = $resp.ContentLength; $resp.Close()
        if ($len -gt 0) { return [long]$len }
    } catch { Write-Host ('  (HEAD failed: ' + $_.Exception.Message + ')') -ForegroundColor DarkYellow }
    return -1
}

# One download attempt, resuming from the current .part size. Returns when the stream ends.
function Download-Once([long]$total) {
    $have = 0L
    if (Test-Path $part) { $have = (Get-Item $part).Length }
    if ($total -gt 0 -and $have -gt $total) { Move-Item $part ($part + '.oversize') -Force; $have = 0L }
    if ($total -gt 0 -and $have -eq $total) { return }
    $resp = $null
    try {
        try { $resp = (New-Request 'GET' $have).GetResponse() }
        catch [Net.WebException] {
            if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 416) { return }  # already complete
            throw
        }
        $mode = [IO.FileMode]::Append
        if ($have -gt 0 -and [int]$resp.StatusCode -ne 206) {
            Write-Host '  Server ignored resume request; restarting from 0.' -ForegroundColor Yellow
            $have = 0L; $mode = [IO.FileMode]::Create
        }
        if ($have -eq 0) { $mode = [IO.FileMode]::Create }
        if ($total -le 0 -and $resp.ContentLength -gt 0) { $total = $have + $resp.ContentLength }
        $in = $resp.GetResponseStream()
        $out = New-Object IO.FileStream($part, $mode, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        try {
            $buf = New-Object byte[] 262144
            $done = $have; $startBytes = $have
            $sw = [Diagnostics.Stopwatch]::StartNew(); $lastPrint = -1.0
            while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                $out.Write($buf, 0, $n); $done += $n
                if ($sw.Elapsed.TotalSeconds - $lastPrint -ge 1) {
                    $lastPrint = $sw.Elapsed.TotalSeconds
                    $speed = ($done - $startBytes) / [math]::Max($sw.Elapsed.TotalSeconds, 0.001)
                    if ($total -gt 0) {
                        $pct = 100.0 * $done / $total
                        $eta = if ($speed -gt 0) { ($total - $done) / $speed } else { -1 }
                        Write-Host ('  {0,5:N1}%  {1} / {2}  {3}/s  ETA {4}' -f $pct, (Fmt-MB $done), (Fmt-MB $total), (Fmt-MB $speed), (Fmt-Time $eta))
                    } else {
                        Write-Host ('  {0} downloaded (total unknown)  {1}/s' -f (Fmt-MB $done), (Fmt-MB $speed))
                    }
                }
            }
        } finally { $out.Dispose(); $in.Dispose() }
    } finally { if ($resp) { $resp.Close() } }
}

try {
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    if (Test-Path $exe) { Write-Host 'Godot already available.'; exit 0 }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # 1) A complete ZIP from an earlier run: verify, never download again.
    $verified = $false
    if (Test-Path $archive) {
        Write-Host ('Found existing ZIP (' + (Fmt-MB (Get-Item $archive).Length) + '), verifying SHA512...')
        if ((Get-Hash $archive) -eq $expectedSha512) { $verified = $true; Write-Host 'Existing ZIP is valid. Skipping download.' -ForegroundColor Green }
        else {
            $bad = $archive + '.corrupt'
            Move-Item $archive $bad -Force
            Write-Host ('Existing ZIP failed verification; kept as ' + $bad + ' and will download again.') -ForegroundColor Yellow
        }
    }

    # 2) Download / resume
    if (-not $verified) {
        Write-Host "Source: $url"
        $total = Get-TotalSize
        if ($total -gt 0) { Write-Host ('Total size: ' + (Fmt-MB $total)) } else { Write-Host 'Total size: unknown' }
        if (Test-Path $part) { Write-Host ('Resuming from partial file: ' + (Fmt-MB (Get-Item $part).Length)) }
        $lastErr = $null
        for ($i = 1; $i -le $maxAttempts; $i++) {
            try {
                Write-Host "Download attempt $i/$maxAttempts..."
                Download-Once $total
                $size = (Get-Item $part).Length
                if ($total -gt 0 -and $size -lt $total) { throw ('Connection ended early at ' + (Fmt-MB $size) + ' of ' + (Fmt-MB $total)) }
                $lastErr = $null; break
            } catch {
                $lastErr = $_.Exception.Message
                Write-Host ('  Interrupted: ' + $lastErr) -ForegroundColor Yellow
                if ($i -lt $maxAttempts) { Start-Sleep -Seconds ([math]::Min(5 * $i, 20)) }
            }
        }
        if ($lastErr) { throw ('Download failed after ' + $maxAttempts + ' attempts: ' + $lastErr + ' | Partial file kept for resume: ' + $part) }

        Write-Host 'Verifying SHA512...'
        $actual = Get-Hash $part
        if ($actual -ne $expectedSha512) {
            $bad = $archive + '.corrupt'
            Move-Item $part $bad -Force
            throw ('SHA512 mismatch (got ' + $actual + '). File NOT used, kept as ' + $bad + '. Re-run to download fresh.')
        }
        Move-Item $part $archive -Force
        Write-Host 'SHA512 OK.' -ForegroundColor Green
    }

    # 3) Extract into a staging dir, then move into place
    Write-Host 'Extracting...'
    $stage = Join-Path $env:TEMP ("data-rescue-godot-stage-$PID")
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try { [IO.Compression.ZipFile]::ExtractToDirectory($archive, $stage) }
    catch { throw ('Extraction failed: ' + $_.Exception.Message + ' (ZIP kept at ' + $archive + ')') }
    $found = Get-ChildItem -Path $stage -Recurse -Filter "Godot_v$version-stable_win64*.exe"
    if (-not ($found | ?{ $_.Name -eq "Godot_v$version-stable_win64.exe" })) { throw 'Godot.exe missing from archive' }
    foreach ($f in $found) { Move-Item -LiteralPath $f.FullName -Destination (Join-Path $target $f.Name) -Force }
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $exe)) { throw 'Godot.exe missing after extraction' }

    $sig = Get-AuthenticodeSignature -FilePath $exe
    if ($sig.Status -ne 'Valid') {
        Write-Warning ('Windows could not verify signature. Status: ' + $sig.Status)
        Write-Warning 'Check the official download manually if uncertain: https://godotengine.org/download/windows/'
    }
    Remove-Item $archive -Force -ErrorAction SilentlyContinue   # only after verified + extracted
    Write-Host 'Godot installed locally under tools\godot. No administrator rights needed.' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'What to do:'
    Write-Host '  - Network/proxy problem: re-run; the partial download resumes automatically.'
    Write-Host '  - Behind a proxy: powershell -File scripts\install-godot.ps1 -Proxy http://127.0.0.1:10810'
    Write-Host '  - Manual: download https://godotengine.org/download/windows/ and put Godot_v4.7.2-stable_win64.exe in tools\godot'
    exit 1
}
