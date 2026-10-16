// Doomscent - weapons, ammo and the Descent powerups that replace Doom's
// pickups.

//--------------------------------------------------------------------------
// Primary weapons.  These exist so Doom's weapon slots, switching and
// pickups keep working; DDShip does the actual firing.

class DDPrimaryWeapon : Weapon
{
	int primaryIndex;
	property PrimaryIndex: primaryIndex;

	Default
	{
		Weapon.AmmoType1 "DDEnergy";
		Weapon.AmmoUse1 0;
		Weapon.AmmoGive1 0;
		Weapon.BobStyle "Smooth";
		Weapon.BobRangeX 0;
		Weapon.BobRangeY 0;
		Weapon.UpSound "ddsnd/153";
		+WEAPON.NOAUTOFIRE
		+WEAPON.AMMO_OPTIONAL
		+WEAPON.NOALERT
		+INVENTORY.UNDROPPABLE
	}

	States
	{
	Ready:
		TNT1 A 1 A_WeaponReady(WRF_NOFIRE | WRF_NOBOB);
		Loop;
	Select:
		TNT1 A 1 A_Raise(100);
		Loop;
	Deselect:
		TNT1 A 1 A_Lower(100);
		Loop;
	Fire:
		TNT1 A 1;
		Goto Ready;
	Spawn:
		TNT1 A -1;
		Stop;
	}
}

class DDLaserCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_LASER";
		Weapon.SlotNumber 1;
		DDPrimaryWeapon.PrimaryIndex DD.PW_LASER;
	}
}

class DDVulcanCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_VULCAN";
		Weapon.SlotNumber 2;
		Weapon.AmmoType1 "DDVulcanAmmo";
		Weapon.AmmoGive1 196;
		DDPrimaryWeapon.PrimaryIndex DD.PW_VULCAN;
	}
}

class DDSpreadfireCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_SPREADFIRE";
		Weapon.SlotNumber 3;
		DDPrimaryWeapon.PrimaryIndex DD.PW_SPREADFIRE;
	}
}

class DDPlasmaCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_PLASMA";
		Weapon.SlotNumber 4;
		DDPrimaryWeapon.PrimaryIndex DD.PW_PLASMA;
	}
}

class DDFusionCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_FUSION";
		Weapon.SlotNumber 5;
		DDPrimaryWeapon.PrimaryIndex DD.PW_FUSION;
	}
}

//--------------------------------------------------------------------------
// Ammo

class DDEnergy : Ammo
{
	Default
	{
		Tag "$DD_ENERGY";
		Inventory.MaxAmount DD.MAX_ENERGY;
		Ammo.BackpackMaxAmount DD.MAX_ENERGY;
		Inventory.Icon "TNT1A0";
		+INVENTORY.IGNORESKILL
	}
}

class DDVulcanAmmo : Ammo
{
	Default
	{
		Tag "$DD_VULCANAMMO";
		Inventory.MaxAmount DD.VULCAN_AMMO_MAX;
		Ammo.BackpackMaxAmount DD.VULCAN_AMMO_MAX * 2;     // Descent II's ammo rack
		Inventory.Icon "TNT1A0";
		+INVENTORY.IGNORESKILL
	}
}

// Each missile type derives straight from Ammo: GZDoom treats a subclass
// of an ammo type as a pickup for its parent.  BackpackMaxAmount is what
// Descent II's ammo rack raises them to (DDAmmoRack, only in that mode).
class DDConcussionAmmo : Ammo
{
	Default { Tag "$DD_CONCUSSION"; Inventory.MaxAmount 20; Ammo.BackpackMaxAmount 40; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}
class DDHomingAmmo : Ammo
{
	Default { Tag "$DD_HOMING"; Inventory.MaxAmount 10; Ammo.BackpackMaxAmount 20; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}
class DDProximityAmmo : Ammo
{
	Default { Tag "$DD_PROXIMITY"; Inventory.MaxAmount 10; Ammo.BackpackMaxAmount 20; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}
class DDSmartAmmo : Ammo
{
	Default { Tag "$DD_SMART"; Inventory.MaxAmount 5; Ammo.BackpackMaxAmount 10; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}
class DDMegaAmmo : Ammo
{
	Default { Tag "$DD_MEGA"; Inventory.MaxAmount 5; Ammo.BackpackMaxAmount 10; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}

//--------------------------------------------------------------------------
// Powerups.  They float in the air like Descent's and use Descent's
// spinning sprites (DPnn = powerup vclip nn).

class DDPowerup : CustomInventory
{
	double powSize;    // Descent powerup size (radius, Descent units)
	property PowSize: powSize;

	Default
	{
		Radius 12;
		Height 24;
		DDPowerup.PowSize 3;
		Inventory.PickupSound "ddsnd/83";
		+INVENTORY.ALWAYSPICKUP
		+NOGRAVITY
		+FLOATBOB
		+FORCEXYBILLBOARD
		+BRIGHT
		+DONTGIB
		FloatBobStrength 0.5;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		SetSpriteScale();
		// Lift off the floor so the ship can fly into it.  The sprite is
		// centred on the item, so raise it by half its drawn height plus
		// the bob, leaving it just touching the floor at the bottom of the
		// bob (and clear of the ceiling at the top).
		if (pos.z <= floorz + 1)
		{
			double half = SpriteHalfHeight();
			double bob = 8 * FloatBobStrength;
			double z = floorz + half + bob - 1;
			double top = ceilingz - half - bob;
			SetZ(max(min(z, top), floorz));
		}
	}

	double SpriteHalfHeight()
	{
		if (sprite == 0) return Height / 2;
		TextureID tex = CurState.GetSpriteTexture(0);
		if (!tex.IsValid()) return Height / 2;
		int w, h;
		[w, h] = TexMan.GetSize(tex);
		return h * abs(Scale.Y) / 2;
	}

	void SetSpriteScale()
	{
		if (sprite == 0) return;
		TextureID tex = CurState.GetSpriteTexture(0);
		if (!tex.IsValid()) return;
		int w, h;
		[w, h] = TexMan.GetSize(tex);
		if (w > 0)
		{
			double s = powSize * 2 * DD.SCALE / w;
			Scale = (s, s);
		}
	}

	static DDShip Ship(Actor toucher)
	{
		return DDShip(toucher);
	}

	// Descent prints pickups on its HUD message line, not in the corner.
	override String PickupMessage()
	{
		return "";
	}

	override void PlayPickupSound(Actor toucher)
	{
		Super.PlayPickupSound(toucher);
		let ship = DDShip(toucher);
		if (ship) ship.ShowMessage(DescentMessage(toucher));
	}

	virtual String DescentMessage(Actor toucher)
	{
		return StringTable.Localize(Super.PickupMessage());
	}

	// Descent's 3 + 3 * (NDL - Difficulty_level) boost.
	static int BoostAmount()
	{
		return 3 + 3 * (5 - DD.Difficulty());
	}
}

class DDEnergyBoost : DDPowerup
{
	int amount;
	property Amount: amount;

	Default
	{
		Inventory.PickupMessage "$DD_GOTENERGY";
		Inventory.PickupSound "ddsnd/80";
		DDPowerup.PowSize 3;
		DDEnergyBoost.Amount 0;
	}

	States
	{
	Spawn:
		DP18 ABCDEFGHIJKLMNO 2;
		Loop;
	Pickup:
		TNT1 A 0 { return invoker.GiveEnergy(self); }
		Stop;
	}

	override String DescentMessage(Actor toucher)
	{
		return String.Format(StringTable.Localize("$DD_ENERGYTO"), toucher.CountInv('DDEnergy'));
	}

	bool GiveEnergy(Actor toucher)
	{
		int have = toucher.CountInv('DDEnergy');
		if (have >= DD.MAX_ENERGY) return false;
		int amt = amount > 0 ? amount : BoostAmount();
		toucher.GiveInventory('DDEnergy', amt);
		return true;
	}
}

class DDEnergyPack : DDEnergyBoost
{
	Default
	{
		DDEnergyBoost.Amount 50;
		DDPowerup.PowSize 4;
		Inventory.PickupMessage "$DD_GOTENERGYPACK";
	}
}

class DDEnergyBonus : DDEnergyBoost
{
	Default
	{
		DDEnergyBoost.Amount 2;
		DDPowerup.PowSize 1.5;
		Inventory.PickupMessage "$DD_GOTENERGYBONUS";
	}
}

class DDEnergyLarge : DDEnergyBoost
{
	Default
	{
		DDEnergyBoost.Amount 100;
		DDPowerup.PowSize 5;
		Inventory.PickupMessage "$DD_GOTENERGYPACK";
	}
}

class DDShieldBoost : DDPowerup
{
	int amount;
	property Amount: amount;

	Default
	{
		Inventory.PickupMessage "$DD_GOTSHIELD";
		Inventory.PickupSound "ddsnd/81";
		DDPowerup.PowSize 3;
		DDShieldBoost.Amount 0;
	}

	States
	{
	Spawn:
		DP19 ABCDEFGH 2;
		Loop;
	Pickup:
		TNT1 A 0 { return invoker.GiveShields(self); }
		Stop;
	}

	override String DescentMessage(Actor toucher)
	{
		return String.Format(StringTable.Localize("$DD_SHIELDTO"), toucher.health);
	}

	bool GiveShields(Actor toucher)
	{
		if (toucher.health >= DD.MAX_SHIELDS) return false;
		int amt = amount > 0 ? amount : BoostAmount();
		toucher.GiveBody(amt, DD.MAX_SHIELDS);
		return true;
	}
}

class DDShieldBonus : DDShieldBoost
{
	Default
	{
		DDShieldBoost.Amount 2;
		DDPowerup.PowSize 1.5;
		Inventory.PickupMessage "$DD_GOTSHIELDBONUS";
	}
}

class DDShieldDouble : DDShieldBoost
{
	Default
	{
		DDShieldBoost.Amount 25;
		DDPowerup.PowSize 4;
	}
}

// Soulsphere / megasphere: Descent's "extra life" sprite.
class DDShieldMega : DDPowerup
{
	int shields;
	int energy;
	property Shields: shields;
	property Energy: energy;

	Default
	{
		Inventory.PickupMessage "$DD_GOTSUPERSHIELD";
		Inventory.PickupSound "ddsnd/82";
		DDPowerup.PowSize 3;
		DDShieldMega.Shields 100;
		DDShieldMega.Energy 0;
	}

	States
	{
	Spawn:
		DP36 ABCDEFGHIJKLMNO 2;
		Loop;
	Pickup:
		TNT1 A 0
		{
			GiveBody(invoker.shields, DD.MAX_SHIELDS);
			if (invoker.energy > 0) GiveInventory('DDEnergy', invoker.energy);
		}
		Stop;
	}
}

class DDMegaSphere : DDShieldMega
{
	Default
	{
		DDShieldMega.Shields 200;
		DDShieldMega.Energy 200;
		Inventory.PickupMessage "$DD_GOTMEGASPHERE";
	}
}

// Descent II mode's megasphere: an earthshaker missile comes with it.
class DDD2MegaSphere : DDMegaSphere
{
	States
	{
	Pickup:
		TNT1 A 0
		{
			GiveBody(invoker.shields, DD.MAX_SHIELDS);
			GiveInventory('DDEnergy', invoker.energy);
			GiveInventory('DDEarthshakerAmmo', 1);
		}
		Stop;
	}
}

class DDLaserUpgrade : DDPowerup
{
	Default
	{
		Inventory.PickupMessage "$DD_GOTLASERUP";
		DDPowerup.PowSize 3;
	}

	States
	{
	Spawn:
		DP20 ABCDEFGHIJKLMNO 2;
		Loop;
	Pickup:
		TNT1 A 0 { return invoker.Upgrade(self); }
		Stop;
	}

	bool Upgrade(Actor toucher)
	{
		let ship = Ship(toucher);
		if (ship == null) return false;
		if (ship.laserLevel >= 3)
		{
			// Already maxed out: Descent turns it into energy.
			if (toucher.CountInv('DDEnergy') >= DD.MAX_ENERGY) return false;
			toucher.GiveInventory('DDEnergy', BoostAmount());
			return true;
		}
		ship.laserLevel++;
		return true;
	}
}

class DDBerserkUpgrade : DDLaserUpgrade
{
	States
	{
	Pickup:
		TNT1 A 0
		{
			invoker.Upgrade(self);
			GiveBody(100, DD.MAX_SHIELDS);
			return true;
		}
		Stop;
	}
}

class DDQuadLasers : DDPowerup
{
	Default
	{
		Inventory.PickupMessage "$DD_GOTQUAD";
		DDPowerup.PowSize 3;
	}

	States
	{
	Spawn:
		DP51 ABCDEFGHIJKLMNO 2;
		Loop;
	Pickup:
		TNT1 A 0
		{
			let ship = DDShip(self);
			if (ship == null) return false;
			if (ship.quadLasers)
			{
				if (ship.laserLevel < 3) { ship.laserLevel++; return true; }
				if (CountInv('DDEnergy') >= DD.MAX_ENERGY) return false;
				GiveInventory('DDEnergy', DDPowerup.BoostAmount());
				return true;
			}
			ship.quadLasers = true;
			return true;
		}
		Stop;
	}
}

// Picking up a primary weapon.
class DDWeaponPowerup : DDPowerup
{
	class<Weapon> weaponType;
	int extraEnergy;
	property WeaponType: weaponType;
	property ExtraEnergy: extraEnergy;

	Default
	{
		DDPowerup.PowSize 4;
		DDWeaponPowerup.ExtraEnergy 0;
		Inventory.PickupSound "ddsnd/83";
	}

	States
	{
	Pickup:
		TNT1 A 0 { return invoker.GiveWeapon(self); }
		Stop;
	}

	bool GiveWeapon(Actor toucher)
	{
		if (toucher.FindInventory(weaponType))
		{
			// Already have it: Descent gives energy (or vulcan ammo) instead.
			if (weaponType == 'DDVulcanCannon' || weaponType == 'DDGaussCannon')
			{
				if (toucher.CountInv('DDVulcanAmmo') >= DD.VULCAN_AMMO_MAX) return false;
				toucher.GiveInventory('DDVulcanAmmo', 196);
				return true;
			}
			if (toucher.CountInv('DDEnergy') >= DD.MAX_ENERGY) return false;
			toucher.GiveInventory('DDEnergy', max(BoostAmount(), extraEnergy));
			return true;
		}
		toucher.GiveInventory(weaponType, 1);
		if (extraEnergy > 0) toucher.GiveInventory('DDEnergy', extraEnergy);
		return true;
	}
}

class DDVulcanPowerup : DDWeaponPowerup
{
	Default { DDWeaponPowerup.WeaponType "DDVulcanCannon"; Inventory.PickupMessage "$DD_GOTVULCAN"; }
	States { Spawn: DP37 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDSpreadfirePowerup : DDWeaponPowerup
{
	Default { DDWeaponPowerup.WeaponType "DDSpreadfireCannon"; Inventory.PickupMessage "$DD_GOTSPREADFIRE"; }
	States { Spawn: DP38 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDPlasmaPowerup : DDWeaponPowerup
{
	Default { DDWeaponPowerup.WeaponType "DDPlasmaCannon"; DDWeaponPowerup.ExtraEnergy 40; Inventory.PickupMessage "$DD_GOTPLASMA"; }
	States { Spawn: DP39 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDFusionPowerup : DDWeaponPowerup
{
	Default { DDWeaponPowerup.WeaponType "DDFusionCannon"; DDWeaponPowerup.ExtraEnergy 40; Inventory.PickupMessage "$DD_GOTFUSION"; }
	States { Spawn: DP40 ABCDEFGHIJKLMNO 3; Loop; }
}

// Ammo powerups
class DDAmmoPowerup : DDPowerup
{
	class<Inventory> ammoType;
	int amount;
	property AmmoType: ammoType;
	property Amount: amount;

	Default
	{
		DDPowerup.PowSize 2.5;
	}

	States
	{
	Pickup:
		TNT1 A 0 { return invoker.GiveAmmo(self); }
		Stop;
	}

	bool GiveAmmo(Actor toucher)
	{
		let inv = toucher.FindInventory(ammoType);
		int maxAmt = inv ? inv.MaxAmount : GetDefaultByType(ammoType).MaxAmount;
		if (inv && inv.Amount >= maxAmt) return false;
		bool hadNone = toucher.CountInv(ammoType) == 0;
		toucher.GiveInventory(ammoType, amount);
		// Like Descent, switch to a better missile when it is picked up.
		let ship = DDShip(toucher);
		if (ship && hadNone)
		{
			for (int i = 0; i < DD.NUM_SECONDARIES; i++)
			{
				if (DD.SecondaryAmmo(i) == ammoType)
				{
					if (i > ship.secondary || toucher.CountInv(DD.SecondaryAmmo(ship.secondary)) == 0)
						ship.secondary = i;
					break;
				}
			}
		}
		return true;
	}
}

class DDVulcanAmmoPowerup : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDVulcanAmmo"; DDAmmoPowerup.Amount 49; DDPowerup.PowSize 1.8; Inventory.PickupMessage "$DD_GOTVULCANAMMO"; }
	States { Spawn: DP46 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDVulcanAmmoBox : DDVulcanAmmoPowerup
{
	Default { DDAmmoPowerup.Amount 196; DDPowerup.PowSize 2.5; }
}
class DDConcussion1 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDConcussionAmmo"; DDAmmoPowerup.Amount 1; Inventory.PickupMessage "$DD_GOTCONCUSSION1"; }
	States { Spawn: DP34 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDConcussion4 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDConcussionAmmo"; DDAmmoPowerup.Amount 4; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTCONCUSSION4"; }
	States { Spawn: DP35 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDHoming1 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDHomingAmmo"; DDAmmoPowerup.Amount 1; Inventory.PickupMessage "$DD_GOTHOMING1"; }
	States { Spawn: DP42 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDHoming4 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDHomingAmmo"; DDAmmoPowerup.Amount 4; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTHOMING4"; }
	States { Spawn: DP43 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDProximityPack : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDProximityAmmo"; DDAmmoPowerup.Amount 4; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTPROXIMITY"; }
	States { Spawn: DP41 ABCDEFGHIJ 3; Loop; }
}
class DDSmartPowerup : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDSmartAmmo"; DDAmmoPowerup.Amount 1; Inventory.PickupMessage "$DD_GOTSMART"; }
	States { Spawn: DP44 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDMegaPowerup : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDMegaAmmo"; DDAmmoPowerup.Amount 1; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTMEGA"; }
	States { Spawn: DP45 ABCDEFGHIJKLMNO 3; Loop; }
}

// Backpack: a bit of everything.
class DDBackpack : DDPowerup
{
	Default
	{
		Inventory.PickupMessage "$DD_GOTBACKPACK";
		DDPowerup.PowSize 3;
	}

	// Descent has no backpack; use its ammo pack sprite (Doom's BPAK
	// sprite doesn't exist in Heretic, Hexen or Chex Quest).
	States
	{
	Spawn:
		DP46 ABCDEFGHIJKLMNO 3;
		Loop;
	Pickup:
		TNT1 A 0
		{
			GiveInventory('DDVulcanAmmo', 98);
			GiveInventory('DDConcussionAmmo', 4);
			GiveInventory('DDHomingAmmo', 2);
			GiveInventory('DDProximityAmmo', 4);
			GiveInventory('DDEnergy', 25);
			// Descent II mode: Doom's backpack also does what Descent II's
			// ammo rack does (double capacity), and brings smart mines and
			// the energy-to-shield converter.
			if (DD.IsD2())
			{
				GiveInventory('DDAmmoRack', 1);
				GiveInventory('DDSmartMineAmmo', 2);
				let ship = DDShip(self);
				if (ship) ship.hasConverter = true;
			}
		}
		Stop;
	}

}

// Invulnerability and cloak use Doom's powers with Descent sprites.
class DDInvulnerability : DDPowerup
{
	Default
	{
		Inventory.PickupMessage "$DD_GOTINVUL";
		Inventory.PickupSound "ddsnd/162";
		DDPowerup.PowSize 2.6;
	}
	States
	{
	Spawn:
		DP49 ABCDEFGHIJKLMNOP 2;
		Loop;
	Pickup:
		TNT1 A 0 A_GiveInventory("PowerInvulnerable");
		Stop;
	}
}

class DDCloak : DDPowerup
{
	Default
	{
		Inventory.PickupMessage "$DD_GOTCLOAK";
		Inventory.PickupSound "ddsnd/160";
		DDPowerup.PowSize 2;
	}
	States
	{
	Spawn:
		DP47 ABCDEFGHIJKLMNOP 2;
		Loop;
	Pickup:
		TNT1 A 0 A_GiveInventory("PowerInvisibility");
		Stop;
	}
}

// Keys.  Doom's locks look for the original key classes, so these give them.
class DDKey : DDPowerup
{
	class<Key> keyType;
	property KeyType: keyType;

	Default
	{
		DDPowerup.PowSize 3;
		Inventory.PickupSound "ddsnd/83";
		+INVENTORY.NOSCREENFLASH
		+DONTGIB
		+NOTDMATCH
	}

	States
	{
	Pickup:
		TNT1 A 0
		{
			if (FindInventory(invoker.keyType)) return false;
			GiveInventory(invoker.keyType, 1);
			return true;
		}
		Stop;
	}

	override bool ShouldStay()
	{
		return multiplayer;
	}
}

class DDBlueCard : DDKey
{
	Default { DDKey.KeyType "BlueCard"; Inventory.PickupMessage "$GOTBLUECARD"; }
	States { Spawn: DP24 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDBlueSkull : DDKey
{
	Default { DDKey.KeyType "BlueSkull"; Inventory.PickupMessage "$GOTBLUESKUL"; }
	States { Spawn: DP24 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDYellowCard : DDKey
{
	Default { DDKey.KeyType "YellowCard"; Inventory.PickupMessage "$GOTYELWCARD"; }
	States { Spawn: DP25 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDYellowSkull : DDKey
{
	Default { DDKey.KeyType "YellowSkull"; Inventory.PickupMessage "$GOTYELWSKUL"; }
	States { Spawn: DP25 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDRedCard : DDKey
{
	Default { DDKey.KeyType "RedCard"; Inventory.PickupMessage "$GOTREDCARD"; }
	States { Spawn: DP26 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDRedSkull : DDKey
{
	Default { DDKey.KeyType "RedSkull"; Inventory.PickupMessage "$GOTREDSKUL"; }
	States { Spawn: DP26 ABCDEFGHIJKLMNO 2; Loop; }
}

// Chex Quest's keys (its locks only accept these).
class DDChexBlueCard : DDKey
{
	Default { DDKey.KeyType "ChexBlueCard"; Inventory.PickupMessage "$GOTBLUECARD"; }
	States { Spawn: DP24 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDChexYellowCard : DDKey
{
	Default { DDKey.KeyType "ChexYellowCard"; Inventory.PickupMessage "$GOTYELWCARD"; }
	States { Spawn: DP25 ABCDEFGHIJKLMNO 2; Loop; }
}
class DDChexRedCard : DDKey
{
	Default { DDKey.KeyType "ChexRedCard"; Inventory.PickupMessage "$GOTREDCARD"; }
	States { Spawn: DP26 ABCDEFGHIJKLMNO 2; Loop; }
}
