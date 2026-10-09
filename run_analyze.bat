@echo off
cd /d "%~dp0"
if not exist evidence mkdir evidence
call "C:\Users\unehi\Flutter SDK\flutter\bin\flutter.bat" analyze > evidence\analysis_output.txt 2>&1
type evidence\analysis_output.txt
echo.
echo Saved to evidence\analysis_output.txt
pause
