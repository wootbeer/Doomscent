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

	void HandleOmega(bool held, double now)
	{
		if (!held) return;
		if (!(omegaCharge >= 1. / 8 || (omegaCharge > 0 && Energy() <= 0)))
		{
			if (omegaCharge <= 0 && Energy() <= 0) AutoSelectPrimary();
			return;
		}
		omegaCharge = max(omegaCharge - DD.TIC, 0);
		lastOmegaTime = now;
		primaryReadyTime = now;

		DDWeaponStats s;
		DDWeaponTable.Get(35, s);
		Vector3 start = pos + (0, 0, Height / 2) + DD.LocalToWorld(GunPoint(1) * DD.SCALE, fwd, rgt, up);

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
		if (best)
		{
			goal = best.pos + (0, 0, best.Height / 2);
			int dmg = int(round(max(s.strength * CVar.GetCVar('dd_damage').GetFloat(), 1)));
			best.DamageMobj(self, self, dmg, 'Omega');
			if (random(0, 3) == 0)
				DDEffect.Make(goal, s.robotHitVclip, s.impactSize * DD.SCALE / 2);
		}
		else
		{
			// Nothing to lock onto: crackle straight ahead to a wall.
			Vector3 dir = (fwd + (frandom(-1, 1), frandom(-1, 1), frandom(-1, 1)) / 16).Unit();
			double a, p;
			[a, p] = DD.VectorAngles(dir);
			FLineTraceData t;
			double dist = OMEGA_RANGE;
			if (LineTrace(a, OMEGA_RANGE, p, TRF_THRUACTORS, Height / 2, 0, 0, t))
				dist = t.Distance;
			goal = start + dir * dist;
		}

		// The bolt: sprites every 5 Descent units, jittered.
		Vector3 d = goal - start;
		double len = d.Length();
		int n = clamp(int(len / (5 * DD.SCALE)), 3, 16);
		for (int i = 1; i <= n; i++)
		{
			Vector3 p = start + d * (double(i) / n);
			if (i < n) p += (frandom(-1, 1), frandom(-1, 1), frandom(-1, 1)) * DD.SCALE;
			DDOmegaSpark.Make(p, s.blobSize * 2 * DD.SCALE);
		}
		if (now >= nextOmegaSound)
		{
			A_StartSound(String.Format("ddsnd/%d", s.flashSound), CHAN_WEAPON, CHANF_OVERLAP);
			nextOmegaSound = now + 0.25;
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
