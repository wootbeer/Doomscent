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

	// Primary weapon indices (Descent's Primary_weapon).
	enum EPrimary
	{
		PW_LASER, PW_VULCAN, PW_SPREADFIRE, PW_PLASMA, PW_FUSION, NUM_PRIMARIES
	}

	// Secondary weapon indices (Descent's Secondary_weapon).
	enum ESecondary
	{
		SW_CONCUSSION, SW_HOMING, SW_PROXIMITY, SW_SMART, SW_MEGA, NUM_SECONDARIES
	}

	// Descent's difficulty levels line up with Doom's five skills.
	static int Difficulty()
	{
		return clamp(G_SkillPropertyInt(SKILLP_ACSReturn), 0, 4);
	}

	static int SecondaryMax(int which)
	{
		static const int maxes[] = { 20, 10, 10, 5, 5 };
		return maxes[which];
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
		}
		return null;
	}

	static String SecondaryName(int which)
	{
		static const String names[] = { "$DD_CONCUSSION", "$DD_HOMING", "$DD_PROXIMITY", "$DD_SMART", "$DD_MEGA" };
		return StringTable.Localize(names[which]);
	}

	static String SecondaryPicture(int which)
	{
		static const String pics[] = { "DDWCONC", "DDWHOMG", "DDWPROX", "DDWSMRT", "DDWMEGA" };
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
		switch (id)
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
