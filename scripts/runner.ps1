# Runs only local, user-authored C code with the compiler installed by the user.
# Execution is time-limited, but NOT sandboxed. Never run untrusted firmware.
param([Parameter(Mandatory=$true)][string]$WorkDir,
      [Parameter(Mandatory=$true)][string]$GameRoot)
$ErrorActionPreference = 'Stop'
$result = Join-Path $WorkDir 'run_result.txt'
$lines = New-Object 'System.Collections.Generic.List[string]'
function Finish {
    [System.IO.File]::WriteAllLines($result, [string[]]$lines, [System.Text.UTF8Encoding]::new($false))
}
function Quote([string]$p) { return '"' + $p.Replace('"','') + '"' }
function Execute-WithLimit([string]$exe, [string]$arguments, [int]$ms) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = $arguments
    $psi.WorkingDirectory = $WorkDir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    if (-not $p.Start()) { throw 'Unable to launch process' }
    if (-not $p.WaitForExit($ms)) {
        try { $p.Kill() } catch { }
        $p.WaitForExit()
        return @{ Timeout = $true; Exit = -1; Out = ''; Err = 'Execution timed out' }
    }
    return @{ Timeout = $false; Exit = $p.ExitCode;
              Out = $p.StandardOutput.ReadToEnd(); Err = $p.StandardError.ReadToEnd() }
}
try {
    $portable = Join-Path $GameRoot 'tools\tcc\tcc.exe'
    $compiler = ''
    if (Test-Path $portable) { $compiler = $portable }
    if (-not $compiler) {
        foreach ($cmd in @('gcc.exe','clang.exe','tcc.exe','gcc','clang','tcc')) {
            $found = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($found) { $compiler = $found.Source; break }
        }
    }
    if (-not $compiler) {
        $lines.Add('ERROR|NO_COMPILER|未找到 C 编译器。请先运行 安装编译器.bat。')
        Finish
        exit 0
    }
    $lines.Add('COMPILER|' + $compiler)
    $binary = Join-Path $WorkDir 'firmware_test.exe'
    if (Test-Path $binary) { Remove-Item $binary -Force }
    $src = Join-Path $WorkDir 'player.c'
    $harness = Join-Path $WorkDir 'trace_harness.c'
    if (-not ((Test-Path $src) -and (Test-Path $harness))) { throw 'Firmware files are missing' }
    # Paths are only local files controlled by the game. No cmd.exe interpolation.
    $args = '-I ' + (Quote $WorkDir) + ' ' + (Quote $src) + ' ' + (Quote $harness) + ' -o ' + (Quote $binary)
    $build = Execute-WithLimit $compiler $args 9000
    if ($build.Timeout) { $lines.Add('ERROR|TIMEOUT|编译超时。'); Finish; exit 0 }
    if ($build.Exit -ne 0 -or -not (Test-Path $binary)) {
        $errorText = ($build.Out + ' ' + $build.Err).Trim().Replace("`r",' ').Replace("`n",' ~ ')
        $lines.Add('ERROR|COMPILE|' + $errorText)
        Finish
        exit 0
    }
    $lines.Add('COMPILE|OK')
    $execution = Execute-WithLimit $binary '' 3500
    if ($execution.Timeout) { $lines.Add('ERROR|TIMEOUT|固件执行超过 3.5 秒。'); Finish; exit 0 }
    foreach ($line in ($execution.Out -split "`r?`n")) {
        if ($line.Trim()) { $lines.Add($line.Trim()) }
    }
    if ($execution.Err.Trim()) {
        $lines.Add('NOTICE|' + $execution.Err.Replace("`n", ' '))
    }
    if (-not ($execution.Out -match 'SUMMARY\|')) { $lines.Add('ERROR|PROTOCOL|程序没有返回完整测试结果。') }
    Finish
} catch {
    $lines.Add('ERROR|SYSTEM|' + $_.Exception.Message.Replace("`n", ' '))
    Finish
}
