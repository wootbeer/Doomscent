@echo off
rem Doomscent in Descent II mode: see tools\launcher.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher.ps1" -descent2 %*
if errorlevel 1 pause
