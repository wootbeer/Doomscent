# Doomscent

Doom plus Descent: fly the Pyro-GX through Doom's levels with Descent's
six-degrees-of-freedom flight, cockpit and weapons.

Doomscent is a mod for an unmodified [GZDoom](https://zdoom.org/downloads)
(4.14 or newer). Doom monsters, maps and music stay as they are. The player
becomes Descent's ship:

- **Full 6DOF flight.** Thrust, slide and bank, loop and fly upside down.
  Movement uses Descent's own physics (thrust 7.8, mass 4, drag 0.033,
  rotational drag, the bank when turning), ported from the Descent 1 source.
- **Descent's cockpit.** Energy and shield gauges, the shield ring, key
  lights, weapon boxes and the reticle, laid out as in Descent.
- **Descent's weapons.**
  - Primaries: lasers (levels 1-4 plus quad), vulcan, spreadfire, plasma, and
    fusion (charge by holding fire).
  - Secondaries: concussion, homing and smart missiles, proximity bombs, mega
    missile. Plus flares.
  - Damage, speed, fire rate and energy cost come from Descent's weapon tables.
- **Descent powerups.** Doom's pickups are replaced by Descent's spinning
  powerups: health becomes shields, armour and cells become energy, and Doom
  weapons become Descent weapons.
- **Doors** open when you fly into them, as in Descent. Switches (including
  level exits) need the use key, so you can't trigger them by accident.

## What you need

| | |
|---|---|
| GZDoom 4.14+ | <https://zdoom.org/downloads> (OpenGL or Vulkan renderer; the software renderer cannot roll the view) |
| Python 3 | Only for the first run, to build the mod and convert the Descent data |
| Doom data | `DOOM.WAD`, `DOOM2.WAD`, `TNT.WAD`, `PLUTONIA.WAD`, shareware `DOOM1.WAD`, or [Freedoom](https://freedoom.github.io/) |
| Descent data | `DESCENT.HOG` and `DESCENT.PIG` from Descent 1 (registered 1.4/1.5 is tested; shareware should work but is untested) |

**No game data is included.** You need your own copies. For Descent, the
retail game is sold on GOG and Steam, and the shareware version is widely
available.

## Setup (Windows)

1. Download or clone this repository, e.g. to `C:\dev\doomscent`.
2. Unzip GZDoom into `C:\dev\doomscent\gzdoom\` (so `gzdoom\gzdoom.exe`
   exists), or set the `GZDOOM` environment variable to your `gzdoom.exe`.
3. Copy your Doom WAD(s), `DESCENT.HOG` and `DESCENT.PIG` into
   `C:\dev\doomscent\data\`.
4. Run `Doomscent.bat`.

On the first run the launcher:

- builds `doomscent.pk3` from `mod/`;
- converts your Descent files into `dd_descent_assets.pk3` (cockpit, gauges,
  sprites, models, sounds).

Both files stay on your machine. The asset pack contains Descent's data and
must not be shared.

On Linux/macOS, use `./doomscent.sh` the same way, with `gzdoom` on your PATH.

Manual equivalent:

```
python tools/build_pk3.py doomscent.pk3
python tools/ddconvert.py path/to/descent -o dd_descent_assets.pk3
gzdoom -iwad DOOM2.WAD -file dd_descent_assets.pk3 doomscent.pk3
```

## Controls

GZDoom's normal bindings mostly carry over. **Options → Doomscent Options →
Bind Descent-style keys** sets up the full layout:

| Action | Key |
|---|---|
| Thrust forward / back | W / S |
| Slide left / right | A / D |
| Slide up / down | Space / C (or Left Ctrl) |
| Pitch and turn | Mouse (arrow keys also turn and pitch) |
| Bank left / right | Q / E |
| Fire primary / secondary | Left / right mouse button |
| Select primary weapon | 1-5 (laser, vulcan, spreadfire, plasma, fusion) |
| Select secondary weapon | 6-0 (concussion, homing, proximity, smart, mega) |
| Cycle secondary | Middle mouse button |
| Fire flare | F |
| Drop proximity bomb | B |
| Level the ship | Z |
| Use (switches; doors also open on contact) | R |

Mouselook must be on (the bind option turns it on).

The **Doomscent Options** menu also has:

- thrust and weapon damage multipliers (mouse speed is GZDoom's own mouse
  sensitivity setting);
- banking into turns;
- auto-levelling;
- bump-to-open doors;
- the cockpit on or off.

## How Doom's items map to Descent

| Doom | Doomscent |
|---|---|
| Health bonus / stimpack / medikit | Shield +2 / shield boost / big shield boost |
| Soulsphere / megasphere | +100 shields / full shields and energy |
| Armour bonus / green / blue armour | Energy +2 / +50 / +100 |
| Cell / cell pack | Energy boost / +100 energy |
| Clip / box of bullets | Vulcan ammo |
| Shells / box of shells | Concussion missile / 4-pack |
| Rocket / box of rockets | Homing missile / 4-pack |
| Chainsaw, berserk | Laser upgrade (berserk also restores shields) |
| Shotgun | Spreadfire cannon |
| Super shotgun | Quad lasers |
| Chaingun | Vulcan cannon |
| Rocket launcher | Smart missile |
| Plasma rifle | Plasma cannon |
| BFG 9000 | Fusion cannon |
| Invulnerability / partial invisibility | Invulnerability / cloak |
| Backpack | Supply pack (vulcan ammo, missiles, bombs, energy) |
| Keys | Descent keys (still open Doom's locked doors) |

## Repository layout

```
mod/              the GZDoom mod (ZScript, menus, key setup) -> doomscent.pk3
tools/ddconvert.py  converts DESCENT.HOG/PIG into dd_descent_assets.pk3
tools/build_pk3.py  zips mod/ into doomscent.pk3
Doomscent.bat, doomscent.sh   launchers
data/             where you put your WADs and Descent files (git-ignored)
```

## Licence

Doomscent is free for **non-commercial** use. Parts of it are derived from
the Descent 1 source code release, which Parallax Software licensed for
non-commercial use. See [LICENSE](LICENSE).

GZDoom is a separate GPL program. Doom and Descent belong to their respective
owners. This project is not affiliated with id Software, Parallax Software or
Interplay.
