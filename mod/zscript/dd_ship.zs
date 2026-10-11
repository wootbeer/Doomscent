// Doomscent - the Pyro-GX.
//
// A PlayerPawn with Descent's six degrees of freedom.  Orientation is kept as
// an orthonormal basis (forward/right/up) and only converted to Doom's
// yaw/pitch/roll for the renderer, so the ship can loop, roll and fly upside
// down.  Thrust, drag and rotational drag follow Descent's do_physics_sim().

class DDShip : PlayerPawn
{
	// Orientation in world space.
	Vector3 fwd, rgt, up;

	// Velocity in Doom units per second, and Descent rotational velocity in
	// revolutions per second (x = pitch, y = heading, z = bank).
	Vector3 shipVel;
	Vector3 rotVel;

	double turnRoll;         // visual bank from turning (degrees)
	double yawRate;          // smoothed turning rate, degrees per second
	double bankInput;        // this tic's bank keys (-1..1)
	bool directView;         // renderer previews the mouse every frame
	bool orientInit;

	// Weapons
	int laserLevel;          // 0..3
	bool quadLasers;
	int secondary;           // DD.SW_*
	double nextPrimaryTime;
	double lastPrimaryTime;
	double nextSecondaryTime;
	double nextFlareTime;
	int missileGun;
	bool spreadToggle;
	double fusionCharge;
	double fusionNextSound;
	bool fusionCharging;
	double primaryReadyTime;     // for the reticle
	double secondaryReadyTime;

	int homingWarning;           // tics left on the homing warning light

	String msgText;
	int msgTime;

	void ShowMessage(String msg)
	{
		msgText = msg;
		msgTime = shipTics;
	}

	Default
	{
		Player.DisplayName "Pyro-GX";
		Player.SoundClass "ddship";
		Player.ViewHeight 16;
		Player.AttackZOffset 0;
		Player.UseRange 96;
		Player.MaxHealth 200;
		Player.ForwardMove 0, 0;
		Player.SideMove 0, 0;
		Player.JumpZ 0;
		Player.ViewBob 0;
		Player.FlyBob 0;
		Player.MugShotMaxHealth 100;
		Player.StartItem "DDLaserCannon";
		Player.StartItem "DDEnergy", DD.START_ENERGY;
		Player.StartItem "DDConcussionAmmo", 3;
		Player.WeaponSlot 1, "DDLaserCannon";
		Player.WeaponSlot 2, "DDVulcanCannon";
		Player.WeaponSlot 3, "DDSpreadfireCannon";
		Player.WeaponSlot 4, "DDPlasmaCannon";
		Player.WeaponSlot 5, "DDFusionCannon";
		Health 100;
		Radius 16;
		Height 32;
		Mass 400;
		MaxStepHeight 8;
		Gravity 0;
		+NOGRAVITY
		+NOFRICTION
		+NOSKIN
		+DONTBLAST
	}

	States
	{
	Spawn:
		DMDL A -1;
		Stop;
	See:
		DMDL A -1;
		Stop;
	Missile:
	Melee:
	Pain:
		DMDL A 4;
		Goto Spawn;
	Death:
	XDeath:
		TNT1 A 0 A_PlayerScream;
		TNT1 A 0 A_DDShipDeath;
		TNT1 A -1;
		Stop;
	}

	//======================================================================
	// Setup

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		ResetOrientation();
		// Hover off the floor so damaging floors (nukage) only hurt when
		// the ship actually scrapes them.
		if (pos.z <= floorz && ceilingz - floorz > Height + 8)
			SetZ(floorz + 8);
	}

	void ResetOrientation()
	{
		fwd = (cos(Angle) * cos(Pitch), sin(Angle) * cos(Pitch), -sin(Pitch));
		rgt = (sin(Angle), -cos(Angle), 0);
		up = rgt cross fwd;
		shipVel = (0, 0, 0);
		rotVel = (0, 0, 0);
		turnRoll = 0;
		orientInit = true;
	}

	override void Travelled()
	{
		Super.Travelled();
		ResetOrientation();
	}

	override void OnRespawn()
	{
		Super.OnRespawn();
		ResetOrientation();
		laserLevel = 0;
		quadLasers = false;
		secondary = DD.SW_CONCUSSION;
	}

	//======================================================================
	// Disable the walking-player behaviour.

	override bool CanCrouch() const { return false; }
	override void CheckCrouch(bool totallyfrozen) {}
	override void CheckJump() {}
	override void CheckMoveUpDown() {}
	override void CheckPitch() {}

	override void CalcHeight()
	{
		let player = self.player;
		if (player.playerstate != PST_LIVE)
		{
			Super.CalcHeight();
			return;
		}
		player.viewheight = ViewHeight;
		player.deltaviewheight = 0;
		player.bob = 0;
		player.viewz = pos.z + ViewHeight;
		if (player.viewz > ceilingz - 2) player.viewz = ceilingz - 2;
		if (player.viewz < floorz + 2) player.viewz = floorz + 2;
	}

	//======================================================================
	// Movement

	override void MovePlayer()
	{
		let player = self.player;
		UserCmd cmd = player.cmd;
		if (!orientInit) ResetOrientation();

		double dt = DD.TIC;
		int buttons = cmd.buttons;

		// --- Rotation ---------------------------------------------------
		// Mouse and turn keys rotate directly (like modern Descent ports);
		// banking uses Descent's rotational thrust and drag.  No extra
		// sensitivity scale here: the renderer previews mouse movement
		// unscaled between tics (see UpdateViewAngles).
		double yawIn = cmd.yaw * (360. / 65536.);            // + = left
		double pitchIn = 0;
		if (cmd.pitch == -32768)
		{
			// "centerview": level the ship.
			LevelShip(180);
		}
		else
		{
			pitchIn = cmd.pitch * (360. / 65536.);            // + = nose up
		}

		double bankIn = 0;
		if (buttons & BT_USER1) bankIn -= 1;
		if (buttons & BT_USER2) bankIn += 1;
		if (player.turnticks)
		{
			player.turnticks--;
			yawIn += 180. / TURN180_TICKS;
		}

		Vector3 rotThrust = (0, 0, bankIn * DD.SHIP_MAX_ROTTHRUST);
		rotVel = SimulateDrag(rotVel, rotThrust / DD.SHIP_MASS, DD.SHIP_DRAG * 5 / 2, dt);

		// Mouse/turn keys.  Near level flight, turn about the world's
		// vertical axis like Doom: the horizon stays straight and the view
		// matches what GZDoom draws between tics.  Rolled over, or with
		// dd_levelturn off, turn about the ship's own axes like Descent.
		if (CVar.GetCVar('dd_levelturn', player).GetBool() && abs(CurrentRoll()) < 45 && abs(fwd.z) < 0.98)
		{
			Rotate(pitchIn, 0, 0);
			RotateWorldZ(yawIn);
		}
		else
		{
			Rotate(pitchIn, -yawIn, 0);
		}
		// Descent's rotational physics (banking keys, knocks from hits).
		Rotate(rotVel.x * 360 * dt, rotVel.y * 360 * dt, rotVel.z * 360 * dt);

		if (bankIn == 0 && CVar.GetCVar('dd_autolevel', player).GetBool())
			LevelShip(DD.ROLL_RATE * 360 * dt);

		bankInput = bankIn;

		// Mouse input arrives unevenly per tic, so smooth the turn rate
		// that drives the bank-into-turns effect (~0.12s time constant).
		yawRate += (-yawIn / dt - yawRate) * 0.21;

		// --- Translation ------------------------------------------------
		// Read back what the engine did to us last tic (wall slides etc).
		shipVel = Vel * TICRATE;

		Vector3 thrustDir = (0, 0, 0);
		double fm = clamp(cmd.forwardmove / 6400., -1, 1);
		double sm = clamp(cmd.sidemove / 6144., -1, 1);
		double um = clamp(cmd.upmove / 256., -1, 1);
		if (buttons & BT_JUMP) um = 1;
		if (buttons & BT_CROUCH) um = -1;
		thrustDir = fwd * fm + rgt * sm + up * um;

		double thrustScale = CVar.GetCVar('dd_thrust', player).GetFloat();
		Vector3 accel = thrustDir * (DD.SHIP_MAX_THRUST * thrustScale / DD.SHIP_MASS * DD.SCALE);
		shipVel = SimulateDrag(shipVel, accel, DD.SHIP_DRAG, dt);
		Vel = shipVel / TICRATE;

		if (fm != 0 || sm != 0)
			PlayRunning();

		if (player.cheats & CF_REVERTPLEASE)
		{
			player.cheats &= ~CF_REVERTPLEASE;
			player.camera = player.mo;
		}

		UpdateViewAngles();
	}

	// Descent's do_physics_sim(): per 1/64s step, v += a; v *= 1 - drag.
	static Vector3 SimulateDrag(Vector3 v, Vector3 a, double drag, double dt)
	{
		double steps = dt / DD.PHYS_STEP;
		int count = int(steps);
		double k = steps - count;
		for (int i = 0; i < count; i++)
		{
			v += a;
			v *= 1 - drag;
		}
		v += a * k;
		v *= 1 - k * drag;
		return v;
	}

	// Rotate the ship about its own axes (degrees): pitch up, yaw right,
	// bank right.
	void Rotate(double pitchUp, double yawRight, double bankRight)
	{
		if (yawRight != 0)
		{
			double c = cos(yawRight), s = sin(yawRight);
			Vector3 f = fwd * c + rgt * s;
			rgt = rgt * c - fwd * s;
			fwd = f;
		}
		if (pitchUp != 0)
		{
			double c = cos(pitchUp), s = sin(pitchUp);
			Vector3 f = fwd * c + up * s;
			up = up * c - fwd * s;
			fwd = f;
		}
		if (bankRight != 0)
		{
			double c = cos(bankRight), s = sin(bankRight);
			Vector3 u = up * c + rgt * s;
			rgt = rgt * c - up * s;
			up = u;
		}
		// Re-orthonormalize.
		fwd = fwd.Unit();
		rgt = (fwd cross up).Unit();
		up = rgt cross fwd;
	}

	// Turn about the world's vertical axis (degrees, + = left).
	void RotateWorldZ(double deg)
	{
		if (deg == 0) return;
		double c = cos(deg), s = sin(deg);
		fwd = (fwd.x * c - fwd.y * s, fwd.x * s + fwd.y * c, fwd.z);
		rgt = (rgt.x * c - rgt.y * s, rgt.x * s + rgt.y * c, rgt.z);
		up = (up.x * c - up.y * s, up.x * s + up.y * c, up.z);
		fwd = fwd.Unit();
		rgt = (fwd cross up).Unit();
		up = rgt cross fwd;
	}

	// Roll back toward the world's up direction by at most maxDeg.
	void LevelShip(double maxDeg)
	{
		double roll = CurrentRoll();
		double step = clamp(-roll, -maxDeg, maxDeg);
		if (step != 0) Rotate(0, 0, step);
	}

	// Bank relative to the world, in degrees (+ = rolled right).
	double CurrentRoll()
	{
		Vector3 flatRight = (fwd cross (0, 0, 1));
		if (flatRight.Length() < 0.001) return 0;
		flatRight = flatRight.Unit();
		Vector3 flatUp = flatRight cross fwd;
		return atan2(up dot flatRight, up dot flatUp);
	}

	// Convert the basis into Doom angles for the renderer.
	void UpdateViewAngles()
	{
		let player = self.player;
		double newAngle, newPitch, newRoll;
		double h = fwd.xy.Length();
		newPitch = -atan2(fwd.z, h);
		if (h > 0.0001)
		{
			newAngle = atan2(fwd.y, fwd.x);
		}
		else
		{
			// Looking straight up or down: heading comes from the up vector.
			newAngle = fwd.z < 0 ? atan2(up.y, up.x) : atan2(-up.y, -up.x);
		}
		// Up vector the renderer would have with no roll.
		Vector3 r0 = (sin(newAngle), -cos(newAngle), 0);
		Vector3 u0 = r0 cross fwd;
		newRoll = atan2(up dot r0, up dot u0);

		// Visual bank into turns (PF_TURNROLL).  It goes in the view-roll
		// offset, which the renderer interpolates on its own.
		if (CVar.GetCVar('dd_bankturns', player).GetBool())
		{
			// Descent's formula, capped: mouse turns can be much faster
			// than Descent's keyboard turning.
			double desired = clamp(-yawRate * DD.TURNROLL_SCALE, -25, 25);
			double maxStep = DD.ROLL_RATE * 360. * DD.TIC;
			turnRoll += clamp(desired - turnRoll, -maxStep, maxStep);
		}
		else
		{
			turnRoll = 0;
		}
		ViewRoll = turnRoll;
		player.cheats |= CF_INTERPVIEWANGLES;

		// The Euler angles flip when passing straight up or down; don't
		// interpolate across that or the frame in between spins.
		bool flipped = abs(deltaangle(Angle, newAngle)) > 90 || abs(deltaangle(Roll, newRoll)) > 90;

		// How the renderer turns the view between tics:
		//  - direct: GZDoom's own path, which adds not-yet-processed mouse
		//    movement every frame.  Smooth and immediate, but it turns about
		//    the world's vertical axis, so it is only right when the ship is
		//    close to level and not banking.
		//  - interpolated: blend the last two tics.  Correct in any
		//    orientation, one tic behind the mouse.
		double rollLimit = directView ? 20 : 10;
		directView = abs(newRoll) < rollLimit && abs(newPitch) < 80 && bankInput == 0
			&& abs(rotVel.x) < 0.02 && abs(rotVel.y) < 0.02 && abs(rotVel.z) < 0.02;

		player.MinPitch = -90;
		player.MaxPitch = 90;
		Angle = newAngle;
		Pitch = newPitch;
		Roll = newRoll;
		if (!directView && !flipped) player.cheats |= CF_INTERPVIEW;
	}

	//======================================================================
	// Per-tic logic

	override void PlayerThink()
	{
		Super.PlayerThink();
		let player = self.player;
		shipTics++;
		if (player.playerstate != PST_LIVE) return;

		// Keep the Doom-side "fly" state off; we do our own physics.
		bFly = false;
		bNoGravity = true;

		if (CVar.GetCVar('dd_bumpuse', player).GetBool())
			BumpActivate();

		HandleFiring();
		if (homingWarning > 0) homingWarning--;
	}

	// Descent opens doors by flying into them.  When the ship is pushing
	// into a door that is actually in its way, open it as if "use" was
	// pressed.
	int lastBumpTics;

	void BumpActivate()
	{
		if (Level.maptime & 3) return;
		// Re-using a Doom door while it is open closes it again, so leave
		// time between activations.
		if (shipTics - lastBumpTics < 35) return;

		Vector3 dir = shipVel;
		if (player.cmd.forwardmove > 0) dir += fwd * 100;
		if (dir.Length() < 20) return;
		dir = dir.Unit();

		Line l = MovementBlockingLine;
		Vector2 at = pos.xy;
		if (l == null || !IsUsable(l))
		{
			double a, p;
			[a, p] = DD.VectorAngles(dir);
			FLineTraceData t;
			bool hit = LineTrace(a, radius + 20, p, TRF_THRUACTORS, Height / 2, 0, 0, t);
			if (!hit) return;
			if (t.HitType != TRACE_HitWall || t.HitLine == null) return;
			l = t.HitLine;
			at = t.HitLocation.xy;
			if (!IsUsable(l)) return;
		}
		if (!BlocksShip(l, at)) return;

		int side = Level.PointOnLineSide(pos.xy, l);
		l.Activate(self, side, SPAC_Use);
		lastBumpTics = shipTics;
	}

	// True if the ship can't fly through the line at its height: a wall or
	// switch, or a door/opening that is (still) too small.
	bool BlocksShip(Line l, Vector2 at)
	{
		if (l.frontsector == null || l.backsector == null) return true;
		double top = min(l.frontsector.ceilingplane.ZatPoint(at), l.backsector.ceilingplane.ZatPoint(at));
		double bottom = max(l.frontsector.floorplane.ZatPoint(at), l.backsector.floorplane.ZatPoint(at));
		return top - max(bottom, pos.z) < Height;
	}

	// Only doors open on contact.  Switches (including level exits) still
	// need the use key, so brushing past one doesn't trigger it.
	static bool IsUsable(Line l)
	{
		if (!(l.activation & (SPAC_Use | SPAC_UseThrough))) return false;
		switch (l.special)
		{
			case 11:  // Door_Open
			case 12:  // Door_Raise
			case 13:  // Door_LockedRaise
			case 14:  // Door_Animated
			case 105: // Door_WaitRaise
			case 202: // Generic_Door
			case 249: // Door_CloseWaitOpen
				return true;
		}
		return false;
	}

	//======================================================================
	// Weapons

	// The ship's own clock.  Level.maptime restarts on every map but the
	// ship (and its weapon timers) carries over, so firing times use this.
	int shipTics;

	clearscope double GameTime() { return shipTics * DD.TIC; }

	clearscope int CurrentPrimary()
	{
		let w = player.ReadyWeapon;
		if (w is 'DDVulcanCannon') return DD.PW_VULCAN;
		if (w is 'DDSpreadfireCannon') return DD.PW_SPREADFIRE;
		if (w is 'DDPlasmaCannon') return DD.PW_PLASMA;
		if (w is 'DDFusionCannon') return DD.PW_FUSION;
		return DD.PW_LASER;
	}

	clearscope static int PrimaryWeaponId(int primary, int laserLevel)
	{
		switch (primary)
		{
			case DD.PW_VULCAN: return 11;
			case DD.PW_SPREADFIRE: return 12;
			case DD.PW_PLASMA: return 13;
			case DD.PW_FUSION: return 14;
		}
		return laserLevel;
	}

	static int SecondaryWeaponId(int sec)
	{
		static const int ids[] = { 8, 15, 16, 17, 18 };
		return ids[sec];
	}

	clearscope double Energy() { return CountInv('DDEnergy'); }

	void UseEnergy(double amount)
	{
		// Energy is kept as an integer item with a fractional remainder.
		energyFrac += amount;
		int whole = int(energyFrac);
		if (whole > 0)
		{
			TakeInventory('DDEnergy', whole);
			energyFrac -= whole;
		}
	}
	double energyFrac;

	clearscope bool HasPrimaryAmmo(int primary)
	{
		if (primary == DD.PW_VULCAN) return CountInv('DDVulcanAmmo') > 0;
		DDWeaponStats s;
		DDWeaponTable.Get(PrimaryWeaponId(primary, laserLevel), s);
		return Energy() >= max(s.energy, 0.01) || (primary == DD.PW_FUSION && Energy() > 0);
	}

	void HandleFiring()
	{
		let player = self.player;
		int buttons = player.cmd.buttons;
		double now = GameTime();

		// No weapon waits more than a few seconds; anything further ahead is
		// a stale timer (e.g. from a save made by an older version).
		if (nextPrimaryTime > now + 5) nextPrimaryTime = primaryReadyTime = now;
		if (nextSecondaryTime > now + 5) nextSecondaryTime = secondaryReadyTime = now;
		if (nextFlareTime > now + 5) nextFlareTime = now;

		// The Doom weapon only exists for selection; we fire it ourselves.
		if (player.ReadyWeapon == null || player.PendingWeapon != WP_NOCHANGE)
		{
			fusionCharging = false;
			fusionCharge = 0;
			return;
		}

		int primary = CurrentPrimary();
		if (primary == DD.PW_FUSION)
			HandleFusion(buttons & BT_ATTACK, now);
		else if (buttons & BT_ATTACK)
			FirePrimaryHeld(primary, now);

		if (buttons & BT_ALTATTACK)
			FireSecondary(now);

		if ((buttons & BT_USER3) && now >= nextFlareTime)
		{
			DDWeaponStats s;
			DDWeaponTable.Get(9, s);
			if (Energy() >= s.energy)
			{
				nextFlareTime = now + s.fireWait;
				UseEnergy(s.energy);
				FireFromGun('DDFlare', 9, 6, 0, 0, true);
			}
		}

		if ((buttons & BT_USER4) && !(player.oldbuttons & BT_USER4))
		{
			// Descent's "drop bomb" key.
			int saved = secondary;
			secondary = DD.SW_PROXIMITY;
			FireSecondary(now);
			secondary = saved;
		}
	}

	// do_laser_firing_player(): fire as many times as fire_wait allows.
	void FirePrimaryHeld(int primary, double now)
	{
		int id = PrimaryWeaponId(primary, laserLevel);
		DDWeaponStats s;
		DDWeaponTable.Get(id, s);

		if (lastPrimaryTime + 2 * DD.TIC < now)
			nextPrimaryTime = max(nextPrimaryTime, now);
		lastPrimaryTime = now;

		int guard = 0;
		while (nextPrimaryTime <= now && guard++ < 4)
		{
			if (primary == DD.PW_VULCAN)
			{
				if (CountInv('DDVulcanAmmo') <= 0) { AutoSelectPrimary(); break; }
				TakeInventory('DDVulcanAmmo', 1);
			}
			else
			{
				if (Energy() < s.energy) { AutoSelectPrimary(); break; }
				UseEnergy(s.energy);
			}
			nextPrimaryTime += s.fireWait;
			FirePrimaryOnce(primary, id);
		}
		primaryReadyTime = nextPrimaryTime;
	}

	void FirePrimaryOnce(int primary, int id, double multiplier = 1.0)
	{
		switch (primary)
		{
		case DD.PW_LASER:
		{
			class<Actor> bolt = 'DDLaserBolt1';
			if (laserLevel == 1) bolt = 'DDLaserBolt2';
			else if (laserLevel == 2) bolt = 'DDLaserBolt3';
			else if (laserLevel >= 3) bolt = 'DDLaserBolt4';
			double mult = quadLasers ? 0.75 : 1.0;
			FireFromGun(bolt, id, 0, 0, 0, true, mult);
			FireFromGun(bolt, id, 1, 0, 0, false, mult);
			if (quadLasers)
			{
				FireFromGun(bolt, id, 2, 0, 0, false, mult);
				FireFromGun(bolt, id, 3, 0, 0, false, mult);
			}
			break;
		}
		case DD.PW_VULCAN:
			FireFromGun('DDVulcanRound', id, 6, frandom(-1, 1) / 16, frandom(-1, 1) / 16, true);
			break;
		case DD.PW_SPREADFIRE:
			if (spreadToggle)
			{
				FireFromGun('DDSpreadBlob', id, 6, 1. / 16, 0, false);
				FireFromGun('DDSpreadBlob', id, 6, -1. / 16, 0, false);
			}
			else
			{
				FireFromGun('DDSpreadBlob', id, 6, 0, 1. / 16, false);
				FireFromGun('DDSpreadBlob', id, 6, 0, -1. / 16, false);
			}
			FireFromGun('DDSpreadBlob', id, 6, 0, 0, true);
			spreadToggle = !spreadToggle;
			break;
		case DD.PW_PLASMA:
			FireFromGun('DDPlasmaBlob', id, 0, 0, 0, true);
			FireFromGun('DDPlasmaBlob', id, 1, 0, 0, false);
			break;
		case DD.PW_FUSION:
			FireFromGun('DDFusionBolt', id, 0, 0, 0, true, multiplier);
			FireFromGun('DDFusionBolt', id, 1, 0, 0, false, multiplier);
			// Recoil (phys_apply_force with -fvec << 7).
			shipVel -= fwd * (128. / DD.SHIP_MASS * DD.SCALE);
			Vel = shipVel / TICRATE;
			rotVel += (frandom(-.25, .25), frandom(-.25, .25), frandom(-.25, .25)) * 0.25;
			break;
		}
	}

	// Fusion charges while the trigger is held and fires on release.
	void HandleFusion(bool held, double now)
	{
		if (held && now >= nextPrimaryTime)
		{
			if (!fusionCharging)
			{
				if (Energy() < 2) { AutoSelectPrimary(); return; }
				UseEnergy(2);
				fusionCharging = true;
				fusionCharge = 0;
			}
			fusionCharge += DD.TIC;
			UseEnergy(DD.TIC);
			if (now >= fusionNextSound)
			{
				fusionNextSound = now + 0.125 + frandom(0, 0.125);
				if (fusionCharge > 2)
				{
					A_StartSound("ddsnd/11", CHAN_WEAPON);
					DamageMobj(self, self, random(0, 2), 'Fusion');
				}
				else
				{
					A_StartSound("ddsnd/34", CHAN_WEAPON);
				}
			}
			// Shake while charging.
			rotVel.x += frandom(-1, 1) / 64;
			rotVel.z += frandom(-1, 1) / 64;
			if (Energy() <= 0) held = false;
		}
		if (!held && fusionCharging)
		{
			double mult = 1 + fusionCharge / 2;
			if (mult > 4) mult = 4;
			fusionCharging = false;
			fusionCharge = 0;
			DDWeaponStats s;
			DDWeaponTable.Get(14, s);
			nextPrimaryTime = now + s.fireWait;
			primaryReadyTime = nextPrimaryTime;
			FirePrimaryOnce(DD.PW_FUSION, 14, mult);
		}
	}

	void FireSecondary(double now)
	{
		if (now < nextSecondaryTime) return;
		let ammo = DD.SecondaryAmmo(secondary);
		if (CountInv(ammo) <= 0)
		{
			AutoSelectSecondary();
			return;
		}
		int id = SecondaryWeaponId(secondary);
		DDWeaponStats s;
		DDWeaponTable.Get(id, s);
		TakeInventory(ammo, 1);
		nextSecondaryTime = now + s.fireWait;
		secondaryReadyTime = nextSecondaryTime;

		switch (secondary)
		{
		case DD.SW_CONCUSSION:
			FireFromGun('DDConcussionMissile', id, 4 + (missileGun & 1), 0, 0, true);
			missileGun++;
			break;
		case DD.SW_HOMING:
			FireFromGun('DDHomingMissile', id, 4 + (missileGun & 1), 0, 0, true);
			missileGun++;
			break;
		case DD.SW_PROXIMITY:
			FireFromGun('DDProximityBomb', id, 7, 0, 0, true);
			break;
		case DD.SW_SMART:
			FireFromGun('DDSmartMissile', id, 7, 0, 0, true);
			break;
		case DD.SW_MEGA:
			FireFromGun('DDMegaMissile', id, 7, 0, 0, true);
			shipVel -= fwd * (128. / DD.SHIP_MASS * DD.SCALE);
			Vel = shipVel / TICRATE;
			rotVel += (frandom(-.25, .25), frandom(-.25, .25), frandom(-.25, .25)) * 0.25;
			break;
		}
		if (CountInv(ammo) <= 0) AutoSelectSecondary();
	}

	// Player_ship->gun_points[] for the Pyro-GX (Descent units, x right,
	// y up, z forward).
	static Vector3 GunPoint(int gun)
	{
		switch (gun)
		{
			case 0: return (2.23, -0.91, 0.55);
			case 1: return (-2.25, -0.91, 0.53);
			case 2: return (3.39, -1.81, 2.26);
			case 3: return (-3.41, -1.80, 2.26);
			case 4: return (2.33, 0.0, -1.39);
			case 5: return (-2.39, 0.0, -1.39);
			case 6: return (0.02, -1.34, 2.82);
			case 7: return (-0.02, -1.34, -2.91);
		}
		return (0, 0, 0);
	}

	// Laser_player_fire_spread(): spawn a weapon at a gun point.
	Actor FireFromGun(class<Actor> type, int weaponId, int gun, double spreadR, double spreadU,
		bool makeSound, double multiplier = 1.0)
	{
		Vector3 center = pos + (0, 0, Height / 2);
		Vector3 ofs = DD.LocalToWorld(GunPoint(gun) * DD.SCALE, fwd, rgt, up);
		Vector3 start = center + ofs;

		// Don't fire through a wall the gun point is poking into.
		double dist = ofs.Length();
		if (dist > 0)
		{
			double a, p;
			[a, p] = DD.VectorAngles(ofs);
			FLineTraceData t;
			if (LineTrace(a, dist + 4, p, TRF_THRUACTORS, Height / 2, 0, 0, t) && t.HitType != TRACE_HitNone)
				start = center;
		}

		Vector3 dir = fwd + rgt * spreadR + up * spreadU;
		dir = dir.Unit();

		DDWeaponStats s;
		DDWeaponTable.Get(weaponId, s);

		let mo = DDProjectile(Spawn(type, start, ALLOW_REPLACE));
		if (mo == null) return null;
		mo.target = self;
		mo.weaponId = weaponId;
		mo.multiplier = multiplier;
		mo.InitStats(s);

		double speed = s.speed * DD.SCALE;
		if (weaponId == 16)
		{
			// Proximity bombs keep the ship's forward speed.
			speed = shipVel dot fwd;
		}
		mo.Vel = dir * speed / TICRATE;
		mo.FaceDirection(dir);
		if (makeSound)
			A_StartSound(String.Format("ddsnd/%d", s.flashSound), CHAN_WEAPON, CHANF_OVERLAP);
		SpawnMuzzleFlash(s, start);

		if (!mo.CheckMissileSpawn(radius))
			return null;
		return mo;
	}

	void SpawnMuzzleFlash(DDWeaponStats s, Vector3 at)
	{
		if (s.flashVclip < 0) return;
		let fx = DDEffect(Spawn('DDEffect', at, ALLOW_REPLACE));
		if (fx)
		{
			fx.Setup(s.flashVclip, s.flashSize * DD.SCALE);
			fx.followActor = self;
			fx.followOffset = at - pos;
		}
	}

	//======================================================================
	// Weapon selection

	// Keys 6-0 ("slot 6".."slot 0") pick secondary weapons, as in Descent.
	override Weapon PickWeapon(int slot, bool checkammo)
	{
		if (slot >= 6 || slot == 0)
		{
			int which = (slot == 0) ? DD.SW_MEGA : slot - 6;
			EventHandler.SendNetworkEvent("dd_secondary", which);
			return player.ReadyWeapon;
		}
		return Super.PickWeapon(slot, checkammo);
	}

	void SelectSecondary(int which, bool quiet = false)
	{
		if (which < 0 || which >= DD.NUM_SECONDARIES) return;
		if (CountInv(DD.SecondaryAmmo(which)) <= 0)
		{
			if (!quiet)
			{
				A_StartSound("ddsnd/156", CHAN_ITEM, CHANF_UI | CHANF_LOCAL);
				ShowMessage(String.Format(StringTable.Localize("$DD_NOSECONDARY"), DD.SecondaryName(which)));
			}
			return;
		}
		if (which == secondary)
		{
			if (!quiet) A_StartSound("ddsnd/155", CHAN_ITEM, CHANF_UI | CHANF_LOCAL);
			return;
		}
		secondary = which;
		if (!quiet)
		{
			A_StartSound("ddsnd/154", CHAN_ITEM, CHANF_UI | CHANF_LOCAL);
			ShowMessage(String.Format(StringTable.Localize("$DD_SELECTED"), DD.SecondaryName(which)));
		}
	}

	// auto_select_weapon(): pick the best secondary that has ammo.
	void AutoSelectSecondary()
	{
		static const int order[] = { DD.SW_MEGA, DD.SW_SMART, DD.SW_HOMING, DD.SW_CONCUSSION, DD.SW_PROXIMITY };
		for (int i = 0; i < order.Size(); i++)
		{
			if (order[i] == DD.SW_PROXIMITY) continue;   // never auto-select bombs
			if (CountInv(DD.SecondaryAmmo(order[i])) > 0)
			{
				secondary = order[i];
				return;
			}
		}
	}

	void AutoSelectPrimary()
	{
		static const class<Weapon> order[] = { 'DDFusionCannon', 'DDPlasmaCannon', 'DDSpreadfireCannon', 'DDVulcanCannon', 'DDLaserCannon' };
		static const int prim[] = { DD.PW_FUSION, DD.PW_PLASMA, DD.PW_SPREADFIRE, DD.PW_VULCAN, DD.PW_LASER };
		int cur = CurrentPrimary();
		for (int i = 0; i < order.Size(); i++)
		{
			if (prim[i] == cur) continue;
			let w = Weapon(FindInventory(order[i]));
			if (w && HasPrimaryAmmo(prim[i]))
			{
				player.PendingWeapon = w;
				return;
			}
		}
	}

	//======================================================================
	// Damage and death

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		int dmg = Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
		if (dmg > 0 && health > 0)
		{
			A_StartSound("ddsnd/71", CHAN_BODY, CHANF_OVERLAP);
			// Getting hit knocks the ship around a little.
			double k = min(dmg, 40) / 400.;
			rotVel += (frandom(-k, k), frandom(-k, k), frandom(-k, k));
		}
		return dmg;
	}

	void A_DDShipDeath()
	{
		let fx = DDEffect(Spawn('DDEffect', pos + (0, 0, Height / 2), ALLOW_REPLACE));
		if (fx) fx.Setup(0, 40);
		bNoGravity = false;
		Gravity = 0.25;
	}
}
