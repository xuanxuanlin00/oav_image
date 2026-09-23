@echo off
rem Image search system - starts the local server and opens the browser
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Server.ps1"
pause
