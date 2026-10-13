@echo off
setlocal
chcp 65001 >nul
set "ROOT=%~dp0"
rem PROJ = ROOT without trailing backslash (a trailing \ before the closing quote escapes it)
set "PROJ=%ROOT:~0,-1%"
set "ENGINE=%ROOT%tools\godot\Godot_v4.7.2-stable_win64.exe"
if exist "%ENGINE%" goto play
where godot >nul 2>nul
if %errorlevel%==0 (
    godot --path "%PROJ%"
    exit /b %errorlevel%
)
echo This game uses a native Godot 4 engine (NOT a browser).
echo Godot is missing. This launcher will download the official portable engine once (about 82 MB).
echo Progress, speed and ETA are shown below. Interrupted downloads resume automatically.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\install-godot.ps1"
if errorlevel 1 goto failed
if not exist "%ENGINE%" goto failed
:play
"%ENGINE%" --path "%PROJ%"
if errorlevel 1 (
    echo.
    echo Godot exited with error code %errorlevel%.
    echo If the engine file is damaged, delete tools\godot\Godot_v4.7.2-stable_win64.exe and run this again.
    pause
    exit /b %errorlevel%
)
exit /b 0
:failed
echo.
echo Could not install Godot. See the error above. Re-run to resume, or manually place
echo Godot_v4.7.2-stable_win64.exe in tools\godot.
pause
exit /b 1
