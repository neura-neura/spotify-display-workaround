@echo off
echo This closes Spotify and applies a reversible workaround.
echo Protected video inside Spotify may stop playing.
choice /C YN /N /M "Continue? [Y/N] "
if errorlevel 2 exit /b 0
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-Workaround.ps1" -CloseSpotify
if errorlevel 1 echo The workaround was not applied successfully. Read the error above.
pause
