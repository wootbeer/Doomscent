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
- Ick Mode (Options → Doomscent Options): every monster wears a face
  (`tools/ickface.png`, or your own `data/ickface.png`) sized to the
  monster, with side and back views as it turns; monsters bleed green and
  warp out instead of leaving corpses
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
