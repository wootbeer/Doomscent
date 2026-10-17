// Doomscent - shared constants and the Descent weapon table.
//
// Numbers come from Descent 1.5's game data (Weapon_info, player_ship) and
// source (PHYSICS.C, LASER.C, POWERUP.C).  Descent distances are converted to
// Doom map units with DD.SCALE.

class DD abstract
{
	// Doom map units per Descent unit.  The Pyro-GX's collision radius is
	// 4 Descent units, which makes it the same width as Doomguy.
	const SCALE = 4.0;

	// Descent simulates physics in steps of 1/64 second.
	const PHYS_STEP = 1.0 / 64.0;
	const TIC = 1.0 / 35.0;

	// player_ship (bitmaps.tbl, Pyro-GX)
	const SHIP_MASS = 4.0;
	const SHIP_DRAG = 0.033;
	const SHIP_MAX_THRUST = 7.8;
	const SHIP_MAX_ROTTHRUST = 0.14;
	const SHIP_WIGGLE = 0.5;

	// PHYSICS.C
	const ROLL_RATE = 0.125;             // revolutions per second
	const TURNROLL_SCALE = 0.1538;

	const MAX_SHIELDS = 200;
	const MAX_ENERGY = 200;
	const START_ENERGY = 100;
	const VULCAN_AMMO_MAX = 784;
	const VULCAN_AMMO_SCALE = 12.75;     // VULCAN_AMMO_SCALE / 65536, for display

	// Primary weapon indices (Descent's Primary_weapon; 5-9 are Descent
	// II's).
	enum EPrimary
	{
		PW_LASER, PW_VULCAN, PW_SPREADFIRE, PW_PLASMA, PW_FUSION,
		PW_SUPERLASER, PW_GAUSS, PW_HELIX, PW_PHOENIX, PW_OMEGA, NUM_PRIMARIES
	}

	// Secondary weapon indices (Descent's Secondary_weapon; 5-9 are
	// Descent II's).
	enum ESecondary
	{
		SW_CONCUSSION, SW_HOMING, SW_PROXIMITY, SW_SMART, SW_MEGA,
		SW_FLASH, SW_GUIDED, SW_SMARTMINE, SW_MERCURY, SW_EARTHSHAKER, NUM_SECONDARIES
	}

	// Descent II mode: on when the Descent II asset pack is loaded (the
	// launcher's -descent2 option).
	static clearscope bool IsD2()
	{
		return Wads.CheckNumForFullName("ddescent2.txt") >= 0;
	}

	static bool IsD2Item(class<Inventory> cls)
	{
		static const class<Inventory> items[] = { 'DDSuperLaserCannon', 'DDGaussCannon', 'DDHelixCannon',
			'DDPhoenixCannon', 'DDOmegaCannon', 'DDFlashAmmo', 'DDGuidedAmmo', 'DDSmartMineAmmo',
			'DDMercuryAmmo', 'DDEarthshakerAmmo', 'DDAmmoRack' };
		for (int i = 0; i < items.Size(); i++)
			if (cls == items[i]) return true;
		return false;
	}

	// Descent's difficulty levels line up with Doom's five skills.
	static int Difficulty()
	{
		return clamp(G_SkillPropertyInt(SKILLP_ACSReturn), 0, 4);
	}

	static class<Inventory> SecondaryAmmo(int which)
	{
		switch (which)
		{
			case SW_CONCUSSION: return 'DDConcussionAmmo';
			case SW_HOMING:     return 'DDHomingAmmo';
			case SW_PROXIMITY:  return 'DDProximityAmmo';
			case SW_SMART:      return 'DDSmartAmmo';
			case SW_MEGA:       return 'DDMegaAmmo';
			case SW_FLASH:      return 'DDFlashAmmo';
			case SW_GUIDED:     return 'DDGuidedAmmo';
			case SW_SMARTMINE:  return 'DDSmartMineAmmo';
			case SW_MERCURY:    return 'DDMercuryAmmo';
			case SW_EARTHSHAKER: return 'DDEarthshakerAmmo';
		}
		return null;
	}

	static String SecondaryName(int which)
	{
		static const String names[] = { "$DD_CONCUSSION", "$DD_HOMING", "$DD_PROXIMITY", "$DD_SMART", "$DD_MEGA",
			"$DD_FLASH", "$DD_GUIDED", "$DD_SMARTMINE", "$DD_MERCURY", "$DD_EARTHSHAKER" };
		return StringTable.Localize(names[which]);
	}

	static String SecondaryPicture(int which)
	{
		static const String pics[] = { "DDWCONC", "DDWHOMG", "DDWPROX", "DDWSMRT", "DDWMEGA",
			"DDWFLSH", "DDWGUID", "DDWSMIN", "DDWMERC", "DDWSHAK" };
		return pics[which];
	}

	static String PrimaryName(int which)
	{
		static const String names[] = { "$DD_LASER", "$DD_VULCAN", "$DD_SPREADFIRE", "$DD_PLASMA", "$DD_FUSION",
			"$DD_SUPERLASER", "$DD_GAUSS", "$DD_HELIX", "$DD_PHOENIX", "$DD_OMEGA" };
		return StringTable.Localize(names[which]);
	}

	static String PrimaryPicture(int which)
	{
		static const String pics[] = { "DDWLASR", "DDWVULC", "DDWSPRD", "DDWPLAS", "DDWFUSN",
			"DDWSLSR", "DDWGAUS", "DDWHELX", "DDWPHNX", "DDWOMEG" };
		return pics[which];
	}

	// Rotate a ship-local vector (Descent axes: x right, y up, z forward)
	// into the world using an orthonormal basis.
	static Vector3 LocalToWorld(Vector3 local, Vector3 fwd, Vector3 rgt, Vector3 up)
	{
		return rgt * local.x + up * local.y + fwd * local.z;
	}

	static double, double VectorAngles(Vector3 dir)
	{
		double len2 = dir.xy.Length();
		return atan2(dir.y, dir.x), -atan2(dir.z, len2);
	}
}

// One entry of Descent's Weapon_info table, in Descent units.
struct DDWeaponStats
{
	double energy;        // energy per firing
	double fireWait;      // seconds between firings
	double strength;      // damage (difficulty adjusted)
	double speed;         // units per second
	double lifetime;      // seconds
	double damageRadius;  // splash radius
	double blobSize;      // sprite radius for blob weapons
	double flashSize;
	double impactSize;
	int flashVclip;
	int flashSound;
	int robotHitVclip;
	int wallHitVclip;
	int hitSound;
}

class DDWeaponTable abstract
{
	// Laser level 1-4 (ids 0-3), then the other ids the player uses.
	static void Get(int id, out DDWeaponStats s)
	{
		int diff = DD.Difficulty();
		s.energy = 0; s.lifetime = 10; s.damageRadius = 0; s.blobSize = 0;
		s.hitSound = 11;
		if (DD.IsD2())
			GetD2(id, s);
		else switch (id)
		{
		case 0:  Fill(s, 0.5, 0.25, 10, 120, 10, 0, 0, 1.0, 3, 11, 13, 59, 1); break;
		case 1:  Fill(s, 0.5, 0.25, 11, 125, 10, 0, 0, 1.25, 3, 15, 14, 21, 30); break;
		case 2:  Fill(s, 0.5, 0.20, 12, 130, 10, 0, 0, 1.5, 3, 14, 15, 23, 31); break;
		case 3:  Fill(s, 0.5, 0.20, 13, 135, 10, 0, 0, 2.0, 3, 12, 16, 22, 32); break;
		case 8:  Fill(s, 0, 0.5, 30, 90, 10, 30, 0, 5, 7, 11, 130, 5, 5); break;          // concussion
		case 9:  Fill(s, 1, 1.15, 1, 120, 5, 0, 0, 0.5, 1, 11, 23, 59, -1); break;         // flare
		case 11: Fill(s, 0, 0.05, 4, 500, 3, 0, 0.5, 2, 2.5, 11, 115, 1, 1); break;        // vulcan
		case 12: Fill(s, 0.5, 0.2, 10, 120, 10, 0, 0.5, 2, 2.5, 14, 18, 23, 23); break;    // spreadfire
		case 13: Fill(s, 0.5, 0.15, 11, 150, 10, 0, 1.3, 2, 3.5, 12, 25, 23, 32); break;   // plasma
		case 14: Fill(s, 0, 1.0, 60, 150, 10, 0, 0, 6, 5, 15, 24, 65, 65); break;          // fusion
		case 15: Fill(s, 0, 0.5, 40, 90, 20, 20, 0, 5, 7, 11, 130, 5, 5); break;          // homing
		case 16: Fill(s, 0, 0.2, 30, 0, 35, 40, 3, 5, 7, 11, 26, 5, 5); break;             // proximity bomb
		case 17: Fill(s, 0, 0.5, 25, 85, 3, 20, 0, 5, 7, 11, 130, 5, 5); break;           // smart missile
		case 18: Fill(s, 0, 0.5, 199, 85, 10, 80, 0, 5, 30, 11, 132, 63, 5); break;       // mega missile
		case 19: Fill(s, 0, 1.5, 35, 90, 12, 0, 1.5, 5, 7, 11, 12, 5, 5); break;          // smart missile blob
		}
		// Descent makes energy weapons cheaper on Trainee and Rookie.
		if (diff < 2)
			s.energy *= (diff + 2) / 4.0;
	}

	// Descent II's Weapon_info (DESCENT2.HAM).  Its versions of Descent 1's
	// weapons differ a little (weaker lasers, for one).
	private static void GetD2(int id, out DDWeaponStats s)
	{
		switch (id)
		{
		case 0:  Fill(s, 0.49, 0.25, 9, 120, 10, 0, 0, 1, 3, 11, 13, 59, 1); break;           // laser 1
		case 1:  Fill(s, 0.49, 0.25, 9.75, 125, 10, 0, 0, 1.1, 3, 15, 14, 21, 30); break;     // laser 2
		case 2:  Fill(s, 0.49, 0.25, 10.5, 130, 10, 0, 0, 1.15, 3, 14, 15, 23, 31); break;    // laser 3
		case 3:  Fill(s, 0.49, 0.25, 11.25, 135, 10, 0, 0, 1.2, 3, 12, 16, 22, 32); break;    // laser 4
		case 8:  Fill(s, 0, 0.5, 30, 90, 10, 30, 0, 5, 7, 11, 130, 5, 5); break;              // concussion
		case 9:  Fill(s, 1, 1.15, 1, 120, 5, 0, 0, 0.5, 1, 11, 23, 59, -1); break;            // flare
		case 11: Fill(s, 0, 0.05, 4, 500, 3, 0, 0.5, 2, 2.5, 11, 115, 1, 1); break;           // vulcan
		case 12: Fill(s, 0.5, 0.2, 9, 130, 10, 0, 0.5, 2, 2.5, 14, 18, 23, 23); break;        // spreadfire
		case 13: Fill(s, 0.5, 0.15, 11, 150, 10, 0, 1.3, 2, 3.5, 12, 25, 23, 32); break;      // plasma
		case 14: Fill(s, 0.5, 1, 30, 150, 10, 0, 0, 6, 5, 15, 24, 65, 65); break;             // fusion
		case 15: Fill(s, 0, 0.5, 40, 90, 10, 20, 0, 5, 7, 11, 130, 5, 5); break;              // homing
		case 16: Fill(s, 0, 0.2, 30, 0, 35, 40, 3, 5, 7, 11, 26, 5, 5); break;                // proximity bomb
		case 17: Fill(s, 0, 0.5, 25, 85, 3, 20, 0, 5, 7, 11, 130, 5, 5); break;               // smart missile
		case 18: Fill(s, 0, 1, 199, 85, 10, 80, 0, 5, 30, 11, 132, 63, 5); break;             // mega missile
		case 19: Fill(s, 0, 1.5, 35, 90, 12, 0, 1.5, 5, 7, 11, 12, 5, 5); break;              // smart missile blob
		case 30: Fill(s, 0.75, 0.25, 12, 135, 10, 0, 0, 1.25, 3, 85, 44, 59, 87); break;      // super laser 5
		case 31: Fill(s, 0.75, 0.25, 12.5, 135, 10, 0, 0, 1.25, 3, 86, 45, 59, 88); break;    // super laser 6
		case 32: Fill(s, 0, 0.15, 25, 700, 3, 10, 0.5, 2, 3.5, 11, 230, 95, 95); break;       // gauss
		case 33: Fill(s, 0.75, 0.15, 11, 130, 10, 0, 0.5, 2, 2.5, 12, 37, 22, 22); break;     // helix
		case 34: Fill(s, 1, 0.12, 12, 140, 10, 0, 2.25, 2, 3.5, 11, 38, 23, 59); break;       // phoenix
		case 35: Fill(s, 0, 1, 7, 1000, 0.01, 0, 0.9, 1.25, 4, 86, 77, 105, 105); break;      // omega
		case 36: Fill(s, 0, 0.6, 9, 110, 30, 80, 0, 5, 7, 11, 130, 5, 5); break;              // flash missile
		case 37: Fill(s, 0, 0.3, 55, 60, 20, 40, 0, 5, 7, 11, 130, 5, 5); break;              // guided missile
		case 38: Fill(s, 0, 0.2, 30, 0, 120, 0, 3, 5, 7, 11, 26, 5, 5); break;                // smart mine
		case 39: Fill(s, 0, 0.75, 50, 400, 10, 30, 0, 5, 5, 11, 133, 106, 5); break;          // mercury missile
		case 40: Fill(s, 0, 1.5, 220, 120, 10, 80, 0, 5, 50, 11, 250, 104, 5); break;         // earthshaker
		case 47: Fill(s, 0, 1.5, 25, 90, 12, 0, 2, 5, 3, 11, 12, 5, 2); break;                // smart mine blob
		case 54: Fill(s, 0, 1, 100, 285, 10, 80, 0, 5, 30, 11, 132, 104, 5); break;           // earthshaker child
		}
		if (id == 18 || id == 40 || id == 54) s.hitSound = 231;
	}

	private static void Fill(out DDWeaponStats s, double energy, double wait, double str, double speed,
		double life, double radius, double blob, double flash, double impact,
		int flashVclip, int flashSound, int robotHit, int wallHit)
	{
		s.energy = energy;
		s.fireWait = wait;
		s.strength = str;
		s.speed = speed;
		s.lifetime = life;
		s.damageRadius = radius;
		s.blobSize = blob;
		s.flashSize = flash;
		s.impactSize = impact;
		s.flashVclip = flashVclip;
		s.flashSound = flashSound;
		s.robotHitVclip = robotHit;
		s.wallHitVclip = wallHit;
	}

	static Sound FlashSound(int id)
	{
		DDWeaponStats s;
		Get(id, s);
		return String.Format("ddsnd/%d", s.flashSound);
	}
}
