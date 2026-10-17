@echo off
rem Switch Doomscent's other mods on and off: see tools\launcher.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher.ps1" -mods
if errorlevel 1 pause
