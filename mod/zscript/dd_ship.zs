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
	bool rearView;           // looking backwards (Descent's rear view key)
	bool rearViewChanged;
	int rearViewSince;
	double pendingYaw;       // mouse momentum: turn still to be made (degrees)
	double pendingPitch;
	bool aimMomentum;
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

	// Descent II equipment and weapons.
	bool hasAfterburner, hasHeadlight, hasConverter;
	double afterburnerCharge;    // 0..1
	bool afterburnerHeld, afterburnerOn;
	bool headlightOn;
	bool converting;
	double nextConvertSound;
	double omegaCharge;          // 0..1
	double lastOmegaTime;
	int helixOrient;
	DDGuidedMissile guided;

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
		// Hexen spawns weapons per player class; spawn the Fighter's so
		// there aren't three copies of everything.
		Player.SpawnClass "Fighter";
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
		Player.WeaponSlot 1, "DDLaserCannon", "DDSuperLaserCannon";
		Player.WeaponSlot 2, "DDVulcanCannon", "DDGaussCannon";
		Player.WeaponSlot 3, "DDSpreadfireCannon", "DDHelixCannon";
		Player.WeaponSlot 4, "DDPlasmaCannon", "DDPhoenixCannon";
		Player.WeaponSlot 5, "DDFusionCannon", "DDOmegaCannon";
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
		SetRearView(false);
		ResetOrientation();
	}

	override void OnRespawn()
	{
		Super.OnRespawn();
		SetRearView(false);
		ResetOrientation();
		laserLevel = 0;
		quadLasers = false;
		secondary = DD.SW_CONCUSSION;
		hasAfterburner = hasHeadlight = hasConverter = false;
		afterburnerCharge = 0;
		omegaCharge = 1;
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

		double dt = cheatTurbo ? DD.TIC * 2 : DD.TIC;
		int buttons = cmd.buttons;

		// --- Rotation ---------------------------------------------------
		// Mouse and turn keys rotate directly, unscaled, so the result
		// matches GZDoom's between-tic preview (see UpdateViewAngles);
		// banking uses Descent's rotational thrust and drag.
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

		// Mouse momentum (dd_aimmomentum): Descent's mouse fed rotational
		// thrust, so turns eased in and out.  The movement is banked and
		// paid out at Descent's rotational drag; the total turn is unchanged.
		aimMomentum = CVar.GetCVar('dd_aimmomentum', player).GetBool();
		if (aimMomentum)
		{
			// Fraction of the remaining turn left after one tic of drag.
			double keep = (1 - DD.SHIP_DRAG * 5 / 2) ** (dt / DD.PHYS_STEP);
			pendingYaw += yawIn;
			pendingPitch += pitchIn;
			yawIn = pendingYaw * (1 - keep);
			pitchIn = pendingPitch * (1 - keep);
			pendingYaw -= yawIn;
			pendingPitch -= pitchIn;
		}
		else
		{
			pendingYaw = pendingPitch = 0;
		}

		// Flying a guided missile: the turn controls steer it (at half
		// rate, as in Descent II) and the ship coasts.
		bool steering = guided != null && guided.guided && guided.health > 0 && !guided.InStateSequence(guided.CurState, guided.ResolveState('Death'));
		if (steering)
		{
			guided.Steer(pitchIn / 2, -yawIn / 2, bankIn * 90 * dt);
			yawIn = pitchIn = bankIn = 0;
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
		shipVel = Vel / dt;

		Vector3 thrustDir = (0, 0, 0);
		double fm = clamp(cmd.forwardmove / 6400., -1, 1);
		double sm = clamp(cmd.sidemove / 6144., -1, 1);
		double um = clamp(cmd.upmove / 256., -1, 1);
		if (buttons & BT_JUMP) um = 1;
		if (buttons & BT_CROUCH) um = -1;
		if (steering) fm = sm = um = 0;
		fm = Afterburner(fm, dt);
		thrustDir = fwd * fm + rgt * sm + up * um;

		double thrustScale = CVar.GetCVar('dd_thrust', player).GetFloat();
		Vector3 accel = thrustDir * (DD.SHIP_MAX_THRUST * thrustScale / DD.SHIP_MASS * DD.SCALE);

		// PF_WIGGLE: Descent adds wiggle * sin(GameTime) along the up axis
		// every frame; applied here as an acceleration sized for Descent's
		// ~30fps, so it doesn't depend on frame rate.
		if (CVar.GetCVar('dd_shipbob', player).GetBool())
		{
			double wiggle = DD.SHIP_WIGGLE * 30 * DD.PHYS_STEP * sin(360. * shipTics * DD.TIC);
			accel += up * (wiggle * DD.SCALE);
		}
		shipVel = SimulateDrag(shipVel, accel, DD.SHIP_DRAG, dt);
		Vel = shipVel * dt;

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

		// The Euler angles flip when passing straight up or down; don't
		// interpolate across that or the frame in between spins.
		bool flipped = abs(deltaangle(Angle, newAngle)) > 90 || abs(deltaangle(Roll, newRoll)) > 90;

		// View offsets on top of the ship's angles: the bank into turns, and
		// the rear view.  Looking back is a half turn about the ship's own up
		// axis, which in yaw/pitch/roll terms is yaw + 180, pitch and roll
		// mirrored.
		if (rearView)
		{
			ViewAngle = 180;
			ViewPitch = -2 * newPitch;
			ViewRoll = -2 * newRoll - turnRoll;
		}
		else
		{
			ViewAngle = 0;
			ViewPitch = 0;
			ViewRoll = turnRoll;
		}
		if (!flipped && !rearViewChanged) player.cheats |= CF_INTERPVIEWANGLES;
		rearViewChanged = false;

		// Between tics the view is either "direct" (GZDoom adds pending mouse
		// movement each frame: immediate, but only right near level flight)
		// or interpolated (correct in any orientation, a tic behind).
		double rollLimit = directView ? 20 : 10;
		// With mouse momentum the ship lags the mouse on purpose, and in the
		// rear view the preview would pitch the wrong way, so always
		// interpolate then.
		directView = !aimMomentum && !rearView && abs(newRoll) < rollLimit && abs(newPitch) < 80 && bankInput == 0
			&& abs(rotVel.x) < 0.02 && abs(rotVel.y) < 0.02 && abs(rotVel.z) < 0.02;

		player.MinPitch = -90;
		player.MaxPitch = 90;
		Angle = newAngle;
		Pitch = newPitch;
		Roll = newRoll;
		if (!directView && !flipped) player.cheats |= CF_INTERPVIEW;
	}

	// check_rear_view(): a tap toggles the rear view; holding the key
	// longer than a quarter second makes it last only while held.
	void RearViewKey(bool down)
	{
		if (down)
		{
			SetRearView(!rearView);
			rearViewSince = shipTics;
		}
		else if (rearView && shipTics - rearViewSince > 35 / 4)
		{
			SetRearView(false);
		}
	}

	void SetRearView(bool on)
	{
		if (on == rearView) return;
		rearView = on;
		rearViewChanged = true;
	}

	//======================================================================
	// Per-tic logic

	// Heretic's wind (and Boom's wind/current pushers) push anything with
	// WINDTHRUST, at any height.  Over Heretic's water that reads as a
	// current, so it only moves the ship while it is down on the floor or
	// water surface.  (Scrolling "carry" floors already ignore flying things.)
	override void Tick()
	{
		bWindThrust = pos.z - floorz < 4;
		Super.Tick();
	}

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
		D2Tick();
		RamMonsters();
		if (homingWarning > 0) homingWarning--;
	}

	// Descent opens doors by flying into them.  When the ship is pushing
	// into a door that is actually in its way, or into a switch, use it as
	// if "use" was pressed.
	int lastBumpTics;

	void BumpActivate()
	{
		if (Level.maptime & 3) return;
		// Re-using a Doom door while it is open closes it again (and
		// repeatable switches retrigger), so leave time between activations.
		if (shipTics - lastBumpTics < 35) return;

		Vector3 dir = shipVel;
		if (player.cmd.forwardmove > 0) dir += fwd * 100;
		if (dir.Length() < 20) return;
		dir = dir.Unit();

		Line l = MovementBlockingLine;
		Vector2 at = pos.xy;
		if (l == null || !(IsDoor(l) || IsSwitch(l)))
		{
			double a, p;
			[a, p] = DD.VectorAngles(dir);
			FLineTraceData t;
			bool hit = LineTrace(a, radius + 20, p, TRF_THRUACTORS, Height / 2, 0, 0, t);
			if (!hit) return;
			if (t.HitType != TRACE_HitWall || t.HitLine == null) return;
			l = t.HitLine;
			at = t.HitLocation.xy;
			if (!(IsDoor(l) || IsSwitch(l))) return;
		}
		if (IsDoor(l) && !BlocksShip(l, at)) return;

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

	static bool IsDoor(Line l)
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

	// Any other line the use key would activate: switches, lifts, exits.
	static bool IsSwitch(Line l)
	{
		return l.special != 0 && (l.activation & (SPAC_Use | SPAC_UseThrough)) && !IsDoor(l);
	}

	//======================================================================
	// Weapons

	// The ship's own clock.  Level.maptime restarts on every map but the
	// ship (and its weapon timers) carries over, so firing times use this.
	int shipTics;

	clearscope double GameTime() { return shipTics * DD.TIC; }

	clearscope int CurrentPrimary()
	{
		let w = DDPrimaryWeapon(player.ReadyWeapon);
		return w ? w.primaryIndex : DD.PW_LASER;
	}

	clearscope static int PrimaryWeaponId(int primary, int laserLevel)
	{
		switch (primary)
		{
			case DD.PW_VULCAN: return 11;
			case DD.PW_SPREADFIRE: return 12;
			case DD.PW_PLASMA: return 13;
			case DD.PW_FUSION: return 14;
			// Descent II: the laser stops at level 4; the super laser is 5-6.
			case DD.PW_SUPERLASER: return laserLevel >= 5 ? 31 : 30;
			case DD.PW_GAUSS: return 32;
			case DD.PW_HELIX: return 33;
			case DD.PW_PHOENIX: return 34;
			case DD.PW_OMEGA: return 35;
		}
		return min(laserLevel, 3);
	}

	static int SecondaryWeaponId(int sec)
	{
		static const int ids[] = { 8, 15, 16, 17, 18, 36, 37, 38, 39, 40 };
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
		if (primary == DD.PW_VULCAN || primary == DD.PW_GAUSS) return CountInv('DDVulcanAmmo') > 0;
		if (primary == DD.PW_OMEGA) return omegaCharge > 0 || Energy() > 0;
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
		else if (primary == DD.PW_OMEGA)
			HandleOmega(buttons & BT_ATTACK, now);
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
			// Descent's "drop bomb" key: proximity bombs, or Descent II's
			// smart mines when those are selected or the only ones left.
			int saved = secondary;
			bool mine = CountInv('DDSmartMineAmmo') > 0
				&& (secondary == DD.SW_SMARTMINE || CountInv('DDProximityAmmo') == 0);
			secondary = mine ? DD.SW_SMARTMINE : DD.SW_PROXIMITY;
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
			if (primary == DD.PW_VULCAN || primary == DD.PW_GAUSS)
			{
				if (CountInv('DDVulcanAmmo') <= 0) { AutoSelectPrimary(); break; }
				// Gauss uses vulcan ammo twice as fast (ammo_usage 2).
				TakeInventory('DDVulcanAmmo', primary == DD.PW_GAUSS ? 2 : 1);
			}
			else
			{
				if (Energy() < s.energy) { AutoSelectPrimary(); break; }
				UseEnergy(s.energy);
			}
			nextPrimaryTime += FireWait(s.fireWait);
			FirePrimaryOnce(primary, id);
		}
		primaryReadyTime = nextPrimaryTime;
	}

	void FirePrimaryOnce(int primary, int id, double multiplier = 1.0)
	{
		switch (primary)
		{
		case DD.PW_LASER:
		case DD.PW_SUPERLASER:
		{
			class<Actor> bolt = 'DDLaserBolt1';
			if (id == 1) bolt = 'DDLaserBolt2';
			else if (id == 2) bolt = 'DDLaserBolt3';
			else if (id == 3) bolt = 'DDLaserBolt4';
			else if (id == 30) bolt = 'DDLaserBolt5';
			else if (id == 31) bolt = 'DDLaserBolt6';
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
		case DD.PW_GAUSS:
			FireFromGun('DDGaussRound', id, 6, frandom(-1, 1) / 64, frandom(-1, 1) / 64, true);
			break;
		case DD.PW_HELIX:
		{
			// Five blobs in a line that turns 22.5 degrees each shot.
			static const double hr[] = { 1./16, 1./17, 1./22, 1./42, 0, -1./42, -1./22, -1./17 };
			static const double hu[] = { 0, 1./42, 1./22, 1./17, 1./16, 1./17, 1./22, 1./42 };
			double r = hr[helixOrient], u = hu[helixOrient];
			FireFromGun('DDHelixBlob', id, 6, 0, 0, true);
			FireFromGun('DDHelixBlob', id, 6, r, u, false);
			FireFromGun('DDHelixBlob', id, 6, -r, -u, false);
			FireFromGun('DDHelixBlob', id, 6, r * 2, u * 2, false);
			FireFromGun('DDHelixBlob', id, 6, -r * 2, -u * 2, false);
			helixOrient = (helixOrient + 1) % 8;
			break;
		}
		case DD.PW_PHOENIX:
			FireFromGun('DDPhoenixBlob', id, 0, 0, 0, true);
			FireFromGun('DDPhoenixBlob', id, 1, 0, 0, false);
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
			nextPrimaryTime = now + FireWait(s.fireWait);
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
		nextSecondaryTime = now + FireWait(s.fireWait);
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
		case DD.SW_EARTHSHAKER:
			FireFromGun(secondary == DD.SW_MEGA ? 'DDMegaMissile' : 'DDEarthshaker', id, 7, 0, 0, true);
			shipVel -= fwd * (128. / DD.SHIP_MASS * DD.SCALE);
			Vel = shipVel / TICRATE;
			rotVel += (frandom(-.25, .25), frandom(-.25, .25), frandom(-.25, .25)) * 0.25;
			break;
		case DD.SW_FLASH:
			FireFromGun('DDFlashMissile', id, 4 + (missileGun & 1), 0, 0, true);
			missileGun++;
			break;
		case DD.SW_GUIDED:
		{
			// A new guided missile takes over from the last one, which then
			// homes on its own.
			if (guided) guided.guided = false;
			let m = DDGuidedMissile(FireFromGun('DDGuidedMissile', id, 4 + (missileGun & 1), 0, 0, true));
			missileGun++;
			if (m)
			{
				m.guided = true;
				guided = m;
				player.camera = m;
			}
			break;
		}
		case DD.SW_SMARTMINE:
			FireFromGun('DDSmartMine', id, 7, 0, 0, true);
			break;
		case DD.SW_MERCURY:
			FireFromGun('DDMercuryMissile', id, 4 + (missileGun & 1), 0, 0, true);
			missileGun++;
			break;
		}
		if (CountInv(ammo) <= 0) AutoSelectSecondary();
	}

	// Player_ship->gun_points[] for the Pyro-GX (Descent units, x right,
	// y up, z forward).  A widescreen view shows more to the sides than
	// Descent's 4:3 one, so the laser guns sit GUN_SPREAD times wider and
	// the forward guns GUN_DROP lower: their shots then look as they do
	// in Descent, coming out from under the dashboard on either side.
	const GUN_DROP = 0.75;
	const GUN_SPREAD = 4. / 3;

	static Vector3 GunPoint(int gun)
	{
		switch (gun)
		{
			case 0: return (2.23 * GUN_SPREAD, -0.91 - GUN_DROP, 0.55);
			case 1: return (-2.25 * GUN_SPREAD, -0.91 - GUN_DROP, 0.53);
			case 2: return (3.39 * GUN_SPREAD, -1.81 - GUN_DROP, 2.26);
			case 3: return (-3.41 * GUN_SPREAD, -1.80 - GUN_DROP, 2.26);
			case 4: return (2.33, 0.0, -1.39);
			case 5: return (-2.39, 0.0, -1.39);
			case 6: return (0.02, -1.34 - GUN_DROP, 2.82);
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
		CheatProjectile(mo);

		double speed = s.speed * DD.SCALE;
		if (weaponId == 16 || weaponId == 38)
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
		static const int order[] = { DD.SW_EARTHSHAKER, DD.SW_MEGA, DD.SW_MERCURY, DD.SW_SMART, DD.SW_GUIDED,
			DD.SW_HOMING, DD.SW_FLASH, DD.SW_CONCUSSION, DD.SW_PROXIMITY, DD.SW_SMARTMINE };
		for (int i = 0; i < order.Size(); i++)
		{
			// Never auto-select bombs (or guided missiles, which take over
			// the view).
			if (order[i] == DD.SW_PROXIMITY || order[i] == DD.SW_SMARTMINE || order[i] == DD.SW_GUIDED) continue;
			if (CountInv(DD.SecondaryAmmo(order[i])) > 0)
			{
				secondary = order[i];
				return;
			}
		}
	}

	void AutoSelectPrimary()
	{
		static const class<Weapon> order[] = { 'DDOmegaCannon', 'DDFusionCannon', 'DDPhoenixCannon', 'DDPlasmaCannon',
			'DDHelixCannon', 'DDSpreadfireCannon', 'DDGaussCannon', 'DDVulcanCannon', 'DDSuperLaserCannon', 'DDLaserCannon' };
		static const int prim[] = { DD.PW_OMEGA, DD.PW_FUSION, DD.PW_PHOENIX, DD.PW_PLASMA,
			DD.PW_HELIX, DD.PW_SPREADFIRE, DD.PW_GAUSS, DD.PW_VULCAN, DD.PW_SUPERLASER, DD.PW_LASER };
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

	// Weapons from other mods (scripts can hand them out) would fight our
	// own weapon handling, so the ship only takes Doomscent's.
	// Also refuse Tilt++ (in Project Brutality and others): it rewrites the
	// player's roll every tic, which would undo the ship's.
	// Descent II's weapons and missiles only exist in Descent II mode (the
	// Descent 1 asset pack has no art for them); cheats like IDKFA would
	// hand them out.
	override bool CanReceive(Inventory item)
	{
		if (item is 'Weapon' && !(item is 'DDPrimaryWeapon')) return false;
		if (item.GetClassName() == 'Z_TiltMe') return false;
		if (!DD.IsD2() && DD.IsD2Item(item.GetClass())) return false;
		return Super.CanReceive(item);
	}

	// Doom's give-all cheats (IDKFA, "give all"...) max the laser too.
	override void CheatGive(String name, int amount)
	{
		Super.CheatGive(name, amount);
		if (health > 0 && (name ~== "all" || name ~== "everything" || name ~== "weapons"))
			SetLaserLevel(DD.IsD2() ? 5 : 3);
		// "Give ammo" attaches every ammo type without asking CanReceive.
		if (!DD.IsD2())
		{
			for (let i = inv; i; )
			{
				let next = i.inv;
				if (DD.IsD2Item(i.GetClass())) i.Destroy();
				i = next;
			}
		}
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		// Damage-taken multiplier (telefrags and the like stay lethal).
		if (damage > 0 && damage < TELEFRAG_DAMAGE && dd_damagetaken != 1)
			damage = max(1, int(round(damage * max(dd_damagetaken, 0.1))));
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
		SetRearView(false);
		// Descent II: let go of a guided missile, stop the afterburner and
		// the headlight.
		if (guided)
		{
			guided.guided = false;
			guided = null;
		}
		player.camera = self;
		afterburnerHeld = false;
		if (afterburnerOn)
		{
			A_StopSound(CHAN_6);
			afterburnerOn = false;
		}
		if (headlightOn) SetHeadlight(false);
		ViewAngle = ViewPitch = ViewRoll = 0;
		let fx = DDEffect(Spawn('DDEffect', pos + (0, 0, Height / 2), ALLOW_REPLACE));
		if (fx) fx.Setup(0, 40);
		bNoGravity = false;
		Gravity = 0.25;
	}
}
