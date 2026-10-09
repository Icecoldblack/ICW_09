@echo off
REM Pushes this project to https://github.com/Icecoldblack/ICW_09
REM Run AFTER creating the empty repository ICW_09 on GitHub.
cd /d "%~dp0"
git remote remove origin 2>nul
git remote add origin https://github.com/Icecoldblack/ICW_09.git
git push -u origin main
pause
