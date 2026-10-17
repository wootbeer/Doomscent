// Doomscent - item replacements and network events.

class DDEventHandler : EventHandler
{
	override void CheckReplacement(ReplaceEvent e)
	{
		if (e.IsFinal) return;
		// Walk up the class tree so games built on Doom's actors (Chex Quest's
		// Large Zorcher is a Shotgun, its glass of water a HealthBonus...)
		// get the same replacements.  The class itself is checked first, so
		// ClipBox matches before its parent Clip.
		bool d2 = DD.IsD2();
		for (class<Actor> cls = e.Replacee; cls != null; cls = (class<Actor>)(cls.GetParentClass()))
		{
			Name rep = Replacement(cls.GetClassName(), d2);
			if (rep != 'None')
			{
				e.Replacement = rep;
				return;
			}
		}
		// Gameplay mods (Brutal Doom, Beautiful Doom...) drop pickups of
		// their own that aren't based on the game's classes.
		Name like = ModPickupEquivalent(e.Replacee);
		if (like != 'None')
			e.Replacement = Replacement(like, d2);
	}

	static Name Replacement(Name cls, bool d2)
	{
		Name rep = d2 ? D2Replacement(cls) : 'None';
		return rep != 'None' ? rep : DoomReplacement(cls);
	}

	static bool Has(String s, String part) { return s.IndexOf(part) >= 0; }

	// The Doom pickup a mod's own weapon, ammo, health or armour pickup
	// stands for: weapons by slot (mods keep Doom's), ammo by its name.
	static Name ModPickupEquivalent(class<Actor> cls)
	{
		String cname = cls.GetClassName();
		if (cname.Left(2) == "DD") return 'None';
		cname.ToLower();
		if (cls is 'Weapon')
		{
			static const Name bySlot[] = { 'Pistol', 'Chainsaw', 'Clip', 'Shotgun', 'Chaingun', 'RocketLauncher', 'PlasmaRifle', 'BFG9000' };
			let w = GetDefaultByType((class<Weapon>)(cls));
			int slot = w.SlotNumber;
			if (slot >= 1 && slot <= 7) return bySlot[slot];
			// No slot of its own (the mod's player class assigns them): go
			// by the name.
			if (Has(cname, "bfg")) return 'BFG9000';
			if (Has(cname, "plasma") || Has(cname, "rail")) return 'PlasmaRifle';
			if (Has(cname, "rocket") || Has(cname, "launcher")) return 'RocketLauncher';
			if (Has(cname, "shotgun") || Has(cname, "ssg")) return 'Shotgun';
			if (Has(cname, "chaingun") || Has(cname, "minigun") || Has(cname, "rifle") || Has(cname, "dmr") || Has(cname, "smg"))
				return 'Chaingun';
			if (Has(cname, "saw")) return 'Chainsaw';
			return 'Clip';
		}
		if (cls is 'Ammo')
		{
			bool big = Has(cname, "box") || Has(cname, "pack") || Has(cname, "big");
			if (Has(cname, "shell")) return big ? 'ShellBox' : 'Shell';
			if (Has(cname, "rocket") || Has(cname, "missile") || Has(cname, "grenade"))
				return big ? 'RocketBox' : 'RocketAmmo';
			if (Has(cname, "cell") || Has(cname, "plasma") || Has(cname, "energy"))
				return big ? 'CellPack' : 'Cell';
			return big ? 'ClipBox' : 'Clip';
		}
		if (cls is 'Health')
		{
			let h = GetDefaultByType((class<Inventory>)(cls));
			return h.Amount >= 25 ? 'Medikit' : 'Stimpack';
		}
		if (cls is 'BasicArmorBonus') return 'ArmorBonus';
		if (cls is 'BasicArmorPickup') return 'GreenArmor';
		return 'None';
	}

	// Descent II mode: half of the weapon and missile pickups become their
	// Descent II counterparts, and Doom's other powerups become Descent
	// II's equipment.  Anything not listed falls back to DoomReplacement.
	static Name D2Replacement(Name cls)
	{
		bool d2 = random(0, 1) == 1;
		switch (cls)
		{
			// Weapons
			case 'Shotgun': case 'Crossbow': case 'FWeapAxe': case 'CWeapStaff': case 'MWeapFrost':
				return d2 ? 'DDHelixPowerup' : 'DDSpreadfirePowerup';
			case 'SuperShotgun':
				return d2 ? 'DDSuperLaserPowerup' : 'DDQuadLasers';
			case 'Chaingun': case 'Blaster':
				return d2 ? 'DDGaussPowerup' : 'DDVulcanPowerup';
			case 'RocketLauncher': case 'PhoenixRod':
				return d2 ? 'DDMercury4' : 'DDSmartPowerup';
			case 'PlasmaRifle': case 'SkullRod': case 'FWeapHammer': case 'CWeapFlame': case 'MWeapLightning':
				return d2 ? 'DDPhoenixPowerup' : 'DDPlasmaPowerup';
			case 'BFG9000': case 'Mace':
				return d2 ? 'DDOmegaPowerup' : 'DDFusionPowerup';
			case 'Berserk':
				return 'DDSuperBerserk';

			// Missiles
			case 'Shell': case 'CrossbowAmmo': case 'ArtiPoisonBag':
				return d2 ? 'DDFlash1' : 'DDConcussion1';
			case 'ShellBox': case 'CrossbowHefty':
				return d2 ? 'DDFlash4' : 'DDConcussion4';
			case 'RocketAmmo': case 'PhoenixRodAmmo': case 'ArtiTeleportOther':
				return d2 ? 'DDGuided1' : 'DDHoming1';
			case 'RocketBox': case 'PhoenixRodHefty':
				return d2 ? 'DDGuided4' : 'DDHoming4';

			// Equipment
			case 'RadSuit': case 'ArtiSpeedBoots':
				return 'DDAfterburnerPowerup';
			case 'Infrared': case 'ArtiTorch':
				return 'DDHeadlightPowerup';
			case 'Allmap': case 'SuperMap':
				return 'DDFullMapPowerup';
			case 'Megasphere':
				return 'DDD2MegaSphere';
		}
		return 'None';
	}

	static Name DoomReplacement(Name cls)
	{
		Name rep = 'None';
		switch (cls)
		{
			// Weapons
			case 'Chainsaw':        rep = 'DDLaserUpgrade'; break;
			case 'Pistol':          rep = 'DDLaserUpgrade'; break;
			case 'Shotgun':         rep = 'DDSpreadfirePowerup'; break;
			case 'SuperShotgun':    rep = 'DDQuadLasers'; break;
			case 'Chaingun':        rep = 'DDVulcanPowerup'; break;
			case 'RocketLauncher':  rep = 'DDSmartPowerup'; break;
			case 'PlasmaRifle':     rep = 'DDPlasmaPowerup'; break;
			case 'BFG9000':         rep = 'DDFusionPowerup'; break;

			// Ammo
			case 'Clip':            rep = 'DDVulcanAmmoPowerup'; break;
			case 'ClipBox':         rep = 'DDVulcanAmmoBox'; break;
			case 'Shell':           rep = 'DDConcussion1'; break;
			case 'ShellBox':        rep = 'DDConcussion4'; break;
			case 'RocketAmmo':      rep = 'DDHoming1'; break;
			case 'RocketBox':       rep = 'DDHoming4'; break;
			case 'Cell':            rep = 'DDEnergyBoost'; break;
			case 'CellPack':        rep = 'DDEnergyLarge'; break;
			case 'Backpack':        rep = 'DDBackpack'; break;

			// Health -> shields, armour -> energy
			case 'HealthBonus':     rep = 'DDShieldBonus'; break;
			case 'Stimpack':        rep = 'DDShieldBoost'; break;
			case 'Medikit':         rep = 'DDShieldDouble'; break;
			case 'Soulsphere':      rep = 'DDShieldMega'; break;
			case 'Megasphere':      rep = 'DDMegaSphere'; break;
			case 'ArmorBonus':      rep = 'DDEnergyBonus'; break;
			case 'GreenArmor':      rep = 'DDEnergyPack'; break;
			case 'BlueArmor':       rep = 'DDEnergyLarge'; break;

			// Powerups
			case 'InvulnerabilitySphere': rep = 'DDInvulnerability'; break;
			case 'BlurSphere':      rep = 'DDCloak'; break;
			case 'Berserk':         rep = 'DDBerserkUpgrade'; break;

			// Keys
			case 'BlueCard':        rep = 'DDBlueCard'; break;
			case 'BlueSkull':       rep = 'DDBlueSkull'; break;
			case 'YellowCard':      rep = 'DDYellowCard'; break;
			case 'YellowSkull':     rep = 'DDYellowSkull'; break;
			case 'RedCard':         rep = 'DDRedCard'; break;
			case 'RedSkull':        rep = 'DDRedSkull'; break;
		
			// Heretic (Raven's items shared with Hexen are below).  By role:
			// staff/gauntlets/wand/crossbow/claw/phoenix/hellstaff/firemace
			// line up with Doom's fist/chainsaw/pistol/shotgun/chaingun/
			// rocket launcher/plasma/BFG.
			case 'Gauntlets':       rep = 'DDLaserUpgrade'; break;
			case 'Crossbow':        rep = 'DDSpreadfirePowerup'; break;
			case 'Blaster':         rep = 'DDVulcanPowerup'; break;
			case 'PhoenixRod':      rep = 'DDSmartPowerup'; break;
			case 'SkullRod':        rep = 'DDPlasmaPowerup'; break;
			case 'Mace':            rep = 'DDFusionPowerup'; break;
			case 'GoldWandAmmo':    rep = 'DDVulcanAmmoPowerup'; break;
			case 'GoldWandHefty':   rep = 'DDVulcanAmmoBox'; break;
			case 'BlasterAmmo':     rep = 'DDVulcanAmmoPowerup'; break;
			case 'BlasterHefty':    rep = 'DDVulcanAmmoBox'; break;
			case 'CrossbowAmmo':    rep = 'DDConcussion1'; break;
			case 'CrossbowHefty':   rep = 'DDConcussion4'; break;
			case 'PhoenixRodAmmo':  rep = 'DDHoming1'; break;
			case 'PhoenixRodHefty': rep = 'DDHoming4'; break;
			case 'SkullRodAmmo':    rep = 'DDEnergyBoost'; break;
			case 'SkullRodHefty':   rep = 'DDEnergyLarge'; break;
			case 'MaceAmmo':        rep = 'DDEnergyBoost'; break;
			case 'MaceHefty':       rep = 'DDEnergyLarge'; break;
			case 'BagOfHolding':    rep = 'DDBackpack'; break;
			case 'SilverShield':    rep = 'DDEnergyPack'; break;
			case 'EnchantedShield': rep = 'DDEnergyLarge'; break;
			case 'ArtiTomeOfPower': rep = 'DDLaserUpgrade'; break;
			case 'ArtiInvisibility': rep = 'DDCloak'; break;

			// Heretic and Hexen
			case 'CrystalVial':     rep = 'DDShieldBoost'; break;
			case 'ArtiHealth':      rep = 'DDShieldDouble'; break;
			case 'ArtiSuperHealth': rep = 'DDShieldMega'; break;
			case 'ArtiFly':         rep = 'DDEnergyPack'; break;   // the ship already flies
			case 'ArtiInvulnerability':  rep = 'DDInvulnerability'; break;
			case 'ArtiInvulnerability2': rep = 'DDInvulnerability'; break;

			// Hexen.  Each class's second and third weapons become spreadfire
			// and plasma; the pieces of the fourth become the fusion cannon
			// (extra pieces then give energy, like a weapon you already have).
			case 'FWeapAxe':        rep = 'DDSpreadfirePowerup'; break;
			case 'CWeapStaff':      rep = 'DDSpreadfirePowerup'; break;
			case 'MWeapFrost':      rep = 'DDSpreadfirePowerup'; break;
			case 'FWeapHammer':     rep = 'DDPlasmaPowerup'; break;
			case 'CWeapFlame':      rep = 'DDPlasmaPowerup'; break;
			case 'MWeapLightning':  rep = 'DDPlasmaPowerup'; break;
			case 'FighterWeaponPiece': rep = 'DDFusionPowerup'; break;
			case 'ClericWeaponPiece':  rep = 'DDFusionPowerup'; break;
			case 'MageWeaponPiece':    rep = 'DDFusionPowerup'; break;
			case 'Mana1':           rep = 'DDEnergyBoost'; break;
			case 'Mana2':           rep = 'DDVulcanAmmoPowerup'; break;
			case 'Mana3':           rep = 'DDEnergyPack'; break;
			case 'ArtiBoostMana':   rep = 'DDEnergyLarge'; break;
			case 'MeshArmor':       rep = 'DDEnergyPack'; break;
			case 'FalconShield':    rep = 'DDEnergyPack'; break;
			case 'PlatinumHelm':    rep = 'DDEnergyPack'; break;
			case 'AmuletOfWarding': rep = 'DDEnergyPack'; break;
			case 'ArtiBoostArmor':  rep = 'DDEnergyLarge'; break;
			case 'ArtiSpeedBoots':  rep = 'DDEnergyPack'; break;
			case 'ArtiHealingRadius': rep = 'DDShieldDouble'; break;
			// Hexen has no missile pickups; flechettes and banishment
			// devices are common, so they supply them (one at a time).
			case 'ArtiPoisonBag':   rep = 'DDConcussion1'; break;
			case 'ArtiTeleportOther': rep = 'DDHoming1'; break;

			// Chex Quest: its locks want its own key classes.
			case 'ChexBlueCard':    rep = 'DDChexBlueCard'; break;
			case 'ChexYellowCard':  rep = 'DDChexYellowCard'; break;
			case 'ChexRedCard':     rep = 'DDChexRedCard'; break;
		}
		return rep;
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Player < 0 || !playeringame[e.Player]) return;
		let ship = DDShip(players[e.Player].mo);
		if (ship == null) return;

		if (e.Name == 'dd_secondary')
		{
			ship.SecondaryKey(e.Args[0]);
		}
		else if (e.Name == 'dd_afterburner')
		{
			ship.afterburnerHeld = e.Args[0] != 0;
		}
		else if (e.Name == 'dd_headlight')
		{
			ship.ToggleHeadlight();
		}
		else if (e.Name == 'dd_convert')
		{
			ship.ConvertKey(e.Args[0] != 0);
		}
		else if (e.Name == 'dd_nextsecondary')
		{
			for (int i = 1; i <= DD.NUM_SECONDARIES; i++)
			{
				int s = (ship.secondary + i) % DD.NUM_SECONDARIES;
				if (ship.CountInv(DD.SecondaryAmmo(s)) > 0)
				{
					ship.SelectSecondary(s);
					break;
				}
			}
		}
		else if (e.Name == 'dd_info')
		{
			// Diagnostic output for bug reports.
			Console.Printf("pos (%.1f %.1f %.1f) vel %.1f u/s", ship.pos.x, ship.pos.y, ship.pos.z, ship.shipVel.Length());
			Console.Printf("fwd (%.3f %.3f %.3f) up (%.3f %.3f %.3f)", ship.fwd.x, ship.fwd.y, ship.fwd.z, ship.up.x, ship.up.y, ship.up.z);
			Console.Printf("angle %.1f pitch %.1f roll %.1f", ship.Angle, ship.Pitch, ship.Roll);
			Console.Printf("map %s energy %d shields %d rearview %d", Level.MapName, ship.CountInv('DDEnergy'), ship.health, ship.rearView);
		}
		else if (e.Name == 'dd_rear')
		{
			ship.RearViewKey(e.Args[0] != 0);
		}
		else if (e.Name == 'dd_level')
		{
			ship.LevelShip(180);
		}
	}

	// Ick Mode: give monsters their faces, and say so when it's turned on.
	bool ickStarted, ickWas;

	override void WorldThingSpawned(WorldEvent e)
	{
		if (dd_ickmode && DDIckFace.Wanted(e.thing))
			DDIckFace.Attach(e.thing);
		// Some mods spawn their drops without going through replacement.
		// Check them next tic: items given straight to someone have an owner
		// by then and are left alone.
		if (e.thing is 'Inventory' && ModPickupEquivalent(e.thing.GetClass()) != 'None')
			loosePickups.Push(Inventory(e.thing));
	}

	Array<Inventory> loosePickups;

	void ReplaceLoosePickups()
	{
		if (loosePickups.Size() == 0) return;
		bool d2 = DD.IsD2();
		for (int i = 0; i < loosePickups.Size(); i++)
		{
			let inv = loosePickups[i];
			if (inv == null || inv.owner != null) continue;
			Name rep = Replacement(ModPickupEquivalent(inv.GetClass()), d2);
			if (rep == 'None') continue;
			let mo = Actor.Spawn(rep, inv.pos, ALLOW_REPLACE);
			if (mo) mo.Vel = inv.Vel;
			inv.Destroy();
		}
		loosePickups.Clear();
	}

	override void WorldThingRevived(WorldEvent e)
	{
		if (dd_ickmode && DDIckFace.Wanted(e.thing))
			DDIckFace.Attach(e.thing);
	}

	void CheckIckMode()
	{
		bool on = dd_ickmode;
		if (!ickStarted)
		{
			ickStarted = true;
			ickWas = on;
			return;
		}
		if (on == ickWas) return;
		ickWas = on;
		if (!on) return;
		let it = ThinkerIterator.Create('Actor', Thinker.STAT_DEFAULT);
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (DDIckFace.Wanted(mo) && mo.FindInventory('DDIckToken') == null)
				DDIckFace.Attach(mo);
		}
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			let ship = playeringame[i] ? DDShip(players[i].mo) : null;
			if (ship) ship.ShowMessage(StringTable.Localize("$DD_ICKON"));
		}
	}

	override void WorldTick()
	{
		ReplaceLoosePickups();
		CheckIckMode();
		// Light the homing warning when a homing missile is chasing a ship.
		if (Level.maptime % 4) return;
		let it = ThinkerIterator.Create('Actor', Thinker.STAT_DEFAULT);
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (!mo.bMissile || !mo.bSeekerMissile) continue;
			let ship = DDShip(mo.tracer);
			if (ship) ship.homingWarning = 6;
		}
	}
}
