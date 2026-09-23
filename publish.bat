@echo off
rem Publish to GitHub Pages: rebuild images.json, commit everything, push
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\Build-Index.ps1"
git add -A
git commit -m "Update images"
git push
echo.
echo Site: https://xuanxuanlin00.github.io/oav_image/  (updates in about 1 minute)
pause
