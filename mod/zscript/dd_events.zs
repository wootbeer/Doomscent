// Doomscent - item replacements and network events.

class DDEventHandler : EventHandler
{
	override void CheckReplacement(ReplaceEvent e)
	{
		if (e.IsFinal) return;
		Name rep = 'None';
		switch (e.Replacee.GetClassName())
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
		}
		if (rep != 'None')
			e.Replacement = rep;
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
			Console.Printf("map %s energy %d shields %d", Level.MapName, ship.CountInv('DDEnergy'), ship.health);
		}
		else if (e.Name == 'dd_level')
		{
			ship.LevelShip(180);
		}
	}

	override void WorldTick()
	{
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
