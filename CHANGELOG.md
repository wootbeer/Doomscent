# Doomscent 0.5.1

- The 3D view fills the cockpit's window, as in Descent, instead of running
  behind the dashboard: the reticle sits in the middle of the window, and
  shots from the lower guns (like the omega's lightning) stay in view.
  On widescreen the laser guns sit a little lower and wider apart than
  Descent's, so their shots come out from under the dashboard on either
  side as they do in Descent. Without the cockpit (or
  with the full-screen view size) the view is as before
- Mods with their own maps (UDMF, like Doom City) have all their placed
  things again: the ship's Hexen spawn class kept every thing in such
  maps from appearing. It now only applies in Hexen
- Descent II's omega cannon looks like Descent II's: a fresh arc of
  lightning blobs every tic, solid instead of faded, with crisp lightning
  streaks and blue-white light, and the impact flash every quarter second
- The Descent 1 shareware (1.0-1.2) converts: the converter no longer
  crashes on its PIG, and reads the game tables it keeps in its HOG, so
  the cockpit gauges, weapon pictures and 3D weapon models all work

# Doomscent 0.5.0

- Descent's cheat codes: Descent 1's in Descent 1 mode (start with
  `gabbagabbahey`), Descent II's in Descent II mode. Doom's, Heretic's and
  Hexen's own cheats still work
- Cheats like IDKFA no longer give Descent II weapons in Descent 1 mode,
  and max out the laser

# Doomscent 0.4.3

- Powerups that monsters drop float just above the floor; with mods like
  Brutal Doom they used to rise up to the ceiling

# Doomscent 0.4.2

- Weapon switching works again with mods like Brutal Doom, which set their
  own weapon slots
- Switch mods on and off without moving them: run `Mods.bat`, or edit
  `mods/mods.txt` (a `#` in front of a mod switches it off; mods load top
  to bottom). Gameplay mods like Brutal Doom are Doom-only: switch them
  off before playing Heretic, Hexen or Chex Quest
- The Windows launcher works when Python is installed as `python` rather
  than with the `py` launcher

# Doomscent 0.4.1

- Works with gameplay mods like Brutal Doom, Project Brutality and Beautiful
  Doom: drop them in the new `mods` folder (or pass them with `-file`) and
  the launcher loads them before Doomscent, so you fly the ship through
  their monsters and gore. Their own weapons, ammo, health and armour
  pickups become Descent powerups, and the ship ignores add-ons that would
  fight its controls (other weapons, Tilt++ view tilting)
- Mods that pick their player class in KEYCONF (like Brutal Doom) no longer
  replace the ship
- "Bind Descent-style keys" now really binds Ctrl (slide down) and Shift
  (Descent II afterburner); the key names were wrong

# Doomscent 0.4.0

- Descent II mode (`Doomscent2.bat`, or `-descent2`; Descent 1 stays the
  default): converts your DESCENT2.HOG/HAM, GROUPA.PIG and DESCENT2.S22 and
  adds Descent II's high-resolution cockpit, sounds and music, its weapons
  (super laser, gauss, helix, phoenix and omega cannons; flash, guided,
  smart mine, mercury and earthshaker missiles) and equipment (afterburner,
  headlight, energy-to-shield converter, ammo rack, full map). Works in
  Doom, Chex Quest, Heretic and Hexen
- Descent music option (Options → Doomscent Options → Descent music): each
  level plays one of Descent's songs, as in Descent
- Ick Mode (Options → Doomscent Options): every monster gets sick of slop!
- Damage taken slider (Options → Doomscent Options): scales the damage that
  hits the ship; 1.0 (the default) is Doom's own damage
- Lasers and the fusion bolt glow with their bright core showing, as in
  Descent
- Powerups float just above the floor instead of dipping into it
- The launchers reconvert the Descent data when the converter or
  `data/ickface.png` changes

# Doomscent 0.3.0

- Rear view (V): tap to toggle, hold to look back only while held, with
  Descent's rear-view cockpit art (re-run the converter to get it; the
  launcher does this automatically)
- All game messages (locked doors, other games' pickups, obituaries...) go
  to Descent's message line at the top of the screen, up to three lines
- Mouse momentum (Options → Doomscent Options → Mouse momentum), on by
  default: mouse turns ease in and out like Descent's rotational physics
  instead of stopping dead; the total turn is unchanged
- Mouse momentum and the ship bob are on by default for everyone, including
  players whose config saved them off

# Doomscent 0.2.1

- Heretic's wind and water currents (and Boom wind/current pushers) only
  move the ship when it is down on the floor or water, not while flying
  above them

# Doomscent 0.2.0

Chexscent, Herescent and Hexscent: the Pyro-GX now flies through Chex Quest,
Heretic and Hexen as well as Doom.

- **Chexscent, Herescent and Hexscent**: Chex Quest, Heretic and Hexen are
  playable, with their weapons, ammo and items replaced by Descent's
- Inventory bar and selected-item display for Heretic/Hexen artifacts and
  puzzle items; icons for keys Descent has no light for
- Descent's ship bob ("wiggle"), on by default, toggle in the options
- The supply pack (Doom's backpack) uses a Descent sprite, so it shows in
  every game

# Doomscent 0.1.0

First release: fly Descent's Pyro-GX through Doom's levels.

- Full 6DOF flight with Descent's physics; level (Doom-style) turning near
  level flight, Descent-style ship-axis turning when rolled
- Descent cockpit, gauges, fonts and HUD messages
- All Descent 1 player weapons, with stats from Descent's own tables
- Doom pickups replaced by Descent powerups
- Doors open when you fly into them; switches work on contact or when shot
  (exit switches only from close range)
- Windows launcher downloads GZDoom on first run and converts your Descent
  files; no Python needed

**You need your own game data**: a Doom IWAD (or Freedoom) and Descent 1's
`DESCENT.HOG` and `DESCENT.PIG`. See the README for setup.
