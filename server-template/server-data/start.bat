@echo off
setlocal
cd /d "%~dp0"

echo Checking NUI builds...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resources\build-react-uis.ps1" -OnlyStale -AskCleanup
if errorlevel 1 (
    echo.
    echo [WARN] Some UIs failed to build and were skipped. Starting the server anyway.
    timeout /t 5 >nul
)

rem FXServer artifacts live in ..\server next to server-data. Set FXSERVER_DIR to override.
if not defined FXSERVER_DIR set "FXSERVER_DIR=%~dp0..\server"
call "%FXSERVER_DIR%\run.cmd" %*
