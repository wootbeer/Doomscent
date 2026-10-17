@echo off
rem Mods.bat: switch Doomscent's other mods (Brutal Doom and so on) on and
rem off without moving them out of the mods folder.
rem
rem Put a mod's .pk3/.wad/.zip (or folder) in the mods folder, then run this.
rem It lists the mods, numbered, [x] for on and [ ] for off:
rem
rem    1. [x] brutalv22.pk3
rem
rem Type a mod's number to switch it on or off; press Enter when done.
rem Most gameplay mods (Brutal Doom included) are for Doom only: switch them
rem off before playing Heretic, Hexen or Chex Quest.
rem
rem The choices are saved in mods\mods.txt.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher.ps1" -mods
if errorlevel 1 pause
