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
		for (class<Actor> cls = e.Replacee; cls != null; cls = (class<Actor>)(cls.GetParentClass()))
		{
			Name rep = DoomReplacement(cls.GetClassName());
			if (rep != 'None')
			{
				e.Replacement = rep;
				return;
			}
		}
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
			ship.SelectSecondary(e.Args[0]);
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
