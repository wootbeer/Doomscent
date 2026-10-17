@echo off
rem Mods.bat: switch Doomscent's other mods (Brutal Doom and so on) on and
rem off without moving them out of the mods folder.
rem
rem Put a mod's .pk3/.wad/.zip (or folder) in the mods folder, then run this.
rem It lists the mods, numbered:
rem
rem    1. [x] brutalv22.pk3  (Doom)
rem
rem   [x] means on, [ ] means off; after the name are the games
rem   the mod loads for.  Then type:
rem
rem   1, 2, 3...  switch that mod on or off
rem   g1, g2...   change the games that mod loads for: each press moves to
rem               the next of all games, Doom, Heretic, Hexen, Chex Quest
rem               (Brutal Doom and most gameplay mods are Doom only)
rem   Enter       save and close
rem
rem The choices are saved in mods\mods.txt.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launcher.ps1" -mods
if errorlevel 1 pause
