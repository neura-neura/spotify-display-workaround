@echo off
echo This closes Spotify and restores its backed-up Widevine folder.
choice /C YN /N /M "Continue? [Y/N] "
if errorlevel 2 exit /b 0
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore-Workaround.ps1" -CloseSpotify
if errorlevel 1 echo Restoration did not complete. Read the error above.
pause
