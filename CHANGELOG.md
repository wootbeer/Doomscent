# Unreleased

- Rear view (V): tap to toggle, hold to look back only while held, with
  Descent's rear-view cockpit art (re-run the converter to get it; the
  launcher does this automatically)
- All game messages (locked doors, other games' pickups, obituaries...) go
  to Descent's message line at the top of the screen, up to three lines
- Optional mouse momentum (Options → Doomscent Options → Mouse momentum):
  mouse turns ease in and out like Descent's rotational physics instead of
  stopping dead; the total turn is unchanged

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
