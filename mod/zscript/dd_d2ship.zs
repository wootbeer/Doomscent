// Doomscent - Descent II mode: the Pyro-GX's extra equipment (afterburner,
// headlight, energy converter), the omega cannon and the guided missile
// view.  Numbers from the Descent II source (CONTROLS.C, GAME.C,
// GAMECNTL.C, LASER.C).

extend class DDShip
{
	void D2Tick()
	{
		// Guided missile: watch through it while it flies.
		if (guided)
		{
			bool alive = guided.guided && !guided.bDestroyed && !guided.InStateSequence(guided.CurState, guided.ResolveState('Death'));
			if (!alive)
			{
				if (player.camera == guided) player.camera = self;
				guided = null;
			}
		}
		else if (player.camera is 'DDGuidedMissile')
		{
			player.camera = self;
		}

		// Headlight: 3/8 energy a second, and it goes off below 10.
		if (headlightOn)
		{
			UseEnergy(DD.TIC * 3 / 8);
			if (Energy() < 10) SetHeadlight(false);
		}

		// Energy to shield converter: 20 energy a second for 10 shields,
		// only above 100 energy.
		if (converting && hasConverter)
			ConvertEnergy();

		OmegaRecharge();
		if (GameTime() - lastOmegaTime > 2 * DD.TIC) StopOmegaSound();
	}

	//----------------------------------------------------------------------
	// Afterburner (CONTROLS.C): full forward thrust plus up to double, for
	// three seconds; recharges over eight seconds from energy.

	double Afterburner(double fm, double dt)
	{
		bool burn = hasAfterburner && afterburnerHeld && afterburnerCharge > 0 && player.playerstate == PST_LIVE;
		if (burn)
		{
			fm = 1 + min(0.5, afterburnerCharge) * 2;
			afterburnerCharge = max(afterburnerCharge - dt / 3, 0);
			if (!afterburnerOn)
			{
				A_StartSound("ddsnd/247", CHAN_7, CHANF_OVERLAP);
				A_StartSound("ddsnd/248", CHAN_6, CHANF_LOOPING);
				afterburnerOn = true;
			}
		}
		else
		{
			if (afterburnerOn)
			{
				A_StopSound(CHAN_6);
				afterburnerOn = false;
			}
			if (hasAfterburner && afterburnerCharge < 1)
			{
				double up = min(dt / 8, 1 - afterburnerCharge);
				up = min(up, max(Energy() - 10, 0) / 10);
				if (up > 0)
				{
					afterburnerCharge += up;
					UseEnergy(up * 10);
				}
			}
		}
		return fm;
	}

	//----------------------------------------------------------------------
	// Headlight

	void ToggleHeadlight()
	{
		if (!hasHeadlight)
		{
			ShowMessage(StringTable.Localize("$DD_NOHEADLIGHT"));
			return;
		}
		SetHeadlight(!headlightOn);
		ShowMessage(StringTable.Localize(headlightOn ? "$DD_HEADLIGHTON" : "$DD_HEADLIGHTOFF"));
	}

	void SetHeadlight(bool on)
	{
		headlightOn = on;
		if (on)
			A_AttachLight('headlight', DynamicLight.PointLight, Color(255, 250, 230), 480, 0,
				DynamicLight.LF_SPOT | DynamicLight.LF_ATTENUATE, (0, 0, 0), 0, 15, 35, 0);
		else
			A_RemoveLight('headlight');
	}

	//----------------------------------------------------------------------
	// Energy to shield converter (transfer_energy_to_shield)

	void ConvertEnergy()
	{
		double e = min(DD.TIC * 20, Energy() - DD.START_ENERGY);
		e = min(e, (DD.MAX_SHIELDS - health) * 2);
		if (e <= 0) return;
		UseEnergy(e);
		convertFrac += e / 2;
		int whole = int(convertFrac);
		if (whole > 0)
		{
			GiveBody(whole, DD.MAX_SHIELDS);
			convertFrac -= whole;
		}
		double now = GameTime();
		if (now >= nextConvertSound)
		{
			A_StartSound("ddsnd/241", CHAN_ITEM, CHANF_OVERLAP);
			nextConvertSound = now + 0.5;
		}
	}
	double convertFrac;

	void ConvertKey(bool down)
	{
		converting = down;
		if (!down) return;
		if (!hasConverter)
			ShowMessage(StringTable.Localize("$DD_NOCONVERTER"));
		else if (Energy() <= DD.START_ENERGY)
			ShowMessage(String.Format(StringTable.Localize("$DD_CONVERTLOW"), DD.START_ENERGY));
		else if (health >= DD.MAX_SHIELDS)
			ShowMessage(StringTable.Localize("$DD_CONVERTFULL"));
	}

	//----------------------------------------------------------------------
	// Omega cannon: lightning that locks onto the nearest enemy in front.
	// It runs on its own charge (one second of fire), which refills over
	// four seconds from energy while the trigger is up.

	const OMEGA_RANGE = 80 * DD.SCALE;          // MAX_OMEGA_DIST
	const OMEGA_MIN_DOT = 15. / 16;             // OMEGA_MIN_TRACKABLE_DOT

	void OmegaRecharge()
	{
		if (!FindInventory('DDOmegaCannon'))
		{
			omegaCharge = 1;
			return;
		}
		double now = GameTime();
		if (omegaCharge >= 1 || now - lastOmegaTime < 2 * DD.TIC || Energy() <= 0) return;
		double dc = min(DD.TIC / 4, 1 - omegaCharge);
		omegaCharge += dc;
		double cost = dc * 190 / 17;
		int diff = DD.Difficulty();
		if (diff < 2) cost *= (diff + 2) / 4.0;
		UseEnergy(min(cost, Energy()));
	}

	bool omegaSoundOn;
	int omegaTics;

	void StopOmegaSound()
	{
		if (omegaSoundOn)
		{
			A_StopSound(CHAN_5);
			omegaSoundOn = false;
		}
	}

	void HandleOmega(bool held, double now)
	{
		if (!held)
		{
			StopOmegaSound();
			return;
		}
		if (!(omegaCharge >= 1. / 8 || (omegaCharge > 0 && Energy() <= 0)))
		{
			StopOmegaSound();
			if (omegaCharge <= 0 && Energy() <= 0) AutoSelectPrimary();
			return;
		}
		omegaCharge = max(omegaCharge - DD.TIC, 0);
		lastOmegaTime = now;
		primaryReadyTime = now;
		omegaTics++;

		DDWeaponStats s;
		DDWeaponTable.Get(35, s);
		Vector3 gunOfs = DD.LocalToWorld(GunPoint(1) * DD.SCALE, fwd, rgt, up);
		Vector3 start = pos + (0, 0, Height / 2) + gunOfs;

		// find_homing_object with the omega's narrow cone.
		Actor best = null;
		double bestDot = OMEGA_MIN_DOT;
		let it = BlockThingsIterator.Create(self, OMEGA_RANGE);
		while (it.Next())
		{
			let a = it.thing;
			if (a == self || a.health <= 0 || !a.bShootable || !a.bIsMonster || a.bFriendly) continue;
			Vector3 to = Vec3To(a) + (0, 0, a.Height / 2 - Height / 2);
			double d = to.Length();
			if (d > OMEGA_RANGE || d < 1) continue;
			double dp = (to / d) dot fwd;
			if (dp > bestDot && CheckSight(a, SF_IGNOREVISIBILITY))
			{
				bestDot = dp;
				best = a;
			}
		}

		Vector3 goal;
		bool hitSomething = true;
		if (best)
		{
			goal = best.pos + (0, 0, best.Height / 2);
			// OMEGA_DAMAGE_SCALE (32) x FrameTime x strength: 32 x 7 a second.
			omegaDamage += 32 * DD.TIC * s.strength * CVar.GetCVar('dd_damage').GetFloat();
			int dmg = int(omegaDamage);
			if (dmg > 0)
			{
				omegaDamage -= dmg;
				best.DamageMobj(self, self, dmg, 'Omega');
			}
		}
		else
		{
			// Nothing to lock onto: crackle straight ahead, slightly
			// perturbed, up to a wall or the omega's reach.
			Vector3 dir = (fwd + RandomUnit() / 16).Unit();
			double a, p;
			[a, p] = DD.VectorAngles(dir);
			FLineTraceData t;
			double dist = OMEGA_RANGE;
			hitSomething = false;
			if (LineTrace(a, OMEGA_RANGE, p, TRF_THRUACTORS, Height / 2 + gunOfs.z, 0, 0, t) && t.HitType != TRACE_HitNone)
			{
				dist = t.Distance;
				hitSomething = true;
			}
			goal = start + dir * dist;
		}

		DrawOmegaBolt(start, goal, s);

		// The bolt's end crackles against whatever it hit, every frame as in
		// Descent II, and the gun flashes.
		if (hitSomething)
		{
			DDEffect.Make(goal, best ? s.robotHitVclip : s.wallHitVclip, s.impactSize * DD.SCALE / 2);
			if (best && (omegaTics & 3) == 0)
				best.A_StartSound("ddsnd/11", CHAN_BODY, CHANF_OVERLAP);
		}
		if ((omegaTics % 6) == 1)
			SpawnMuzzleFlash(s, start);
		if (!omegaSoundOn)
		{
			// Descent II restarts the zap every frame; a loop is the same buzz.
			A_StartSound(String.Format("ddsnd/%d", s.flashSound), CHAN_5, CHANF_LOOPING);
			omegaSoundOn = true;
		}
	}
	double omegaDamage;

	static Vector3 RandomUnit()
	{
		Vector3 v;
		do
		{
			v = (frandom(-1, 1), frandom(-1, 1), frandom(-1, 1));
		} while (v.Length() > 1 || v.Length() < 0.01);
		return v.Unit();
	}

	// create_omega_blobs(): blobs every 5 Descent units (3 when close, 3 to
	// 16 of them), bowed out along a random direction that leans away from
	// the ship's up, re-randomised every fourth blob.  The arc is redrawn
	// every tic, so it crackles.
	void DrawOmegaBolt(Vector3 start, Vector3 goal, DDWeaponStats s)
	{
		double sc = DD.SCALE;
		Vector3 toGoal = goal - start;
		double dist = toGoal.Length() / sc;          // Descent units
		if (dist < 0.01) return;
		Vector3 dir = toGoal.Unit();

		int n;
		double spacing;
		if (dist < 3 * 3)
		{
			spacing = 3;
			n = max(int(dist / spacing), 1);
		}
		else
		{
			spacing = 5;
			n = int(dist / spacing);
			if (n > 16) { n = 16; spacing = dist / n; }
			else if (n < 3) { n = 3; spacing = dist / n; }
		}
		Vector3 delta = dir * spacing * sc;

		double perturb[16];
		for (int i = 0; i < 16; i++) perturb[i] = 0;
		Vector3 blobPos = start;
		if (dist >= 3 * 4)
		{
			blobPos += delta / 2;
			for (int i = 0; i < n / 2; i++)
			{
				perturb[i] = i + 0.25;
				perturb[n - 1 - i] = i;
			}
		}

		Vector3 pv = RandomUnit() - up * 0.5;
		Vector3 eye = (pos.xy, player.viewz);
		double size = s.blobSize * 2 * sc;
		for (int i = 0; i < n; i++)
		{
			if (i == n - 1) blobPos += delta * 15 / 32;
			if ((i % 4) == 3) pv += RandomUnit() / 4;
			Vector3 p = blobPos + pv * (perturb[i] * sc);
			// Skip blobs right in front of the eye (the cockpit hides them
			// in Descent II; without it they would fill the screen).
			if (Level.IsPointInLevel(p) && (p - eye).Length() > 24)
				DDOmegaSpark.Make(p, size, (i % 4) == 1 || i == n - 1);
			blobPos += delta;
		}
	}

	//----------------------------------------------------------------------
	// Secondary keys 6-0 pick Descent 1's missile, or with that already
	// selected, its Descent II counterpart (and back).

	void SecondaryKey(int base)
	{
		if (base < 0 || base >= 5) return;
		int other = base + 5;
		bool haveBase = CountInv(DD.SecondaryAmmo(base)) > 0;
		bool haveOther = CountInv(DD.SecondaryAmmo(other)) > 0;
		int pick = base;
		if (secondary == base && haveOther) pick = other;
		else if (secondary == other && haveBase) pick = base;
		else if (secondary == other || (!haveBase && haveOther)) pick = other;
		SelectSecondary(pick);
	}
}
