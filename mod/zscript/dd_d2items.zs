// Doomscent - Descent II mode: weapons, ammo and powerups.  These only
// appear when the Descent II asset pack is loaded (DD.IsD2()); see
// DDEventHandler.D2Replacement for where they come from.

//--------------------------------------------------------------------------
// Primary weapons (each shares a slot with its Descent 1 counterpart, so
// pressing the key again switches between them, as in Descent II).

class DDSuperLaserCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_SUPERLASER";
		Weapon.SlotNumber 1;
		DDPrimaryWeapon.PrimaryIndex DD.PW_SUPERLASER;
	}
}

class DDGaussCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_GAUSS";
		Weapon.SlotNumber 2;
		Weapon.AmmoType1 "DDVulcanAmmo";
		Weapon.AmmoGive1 196;
		DDPrimaryWeapon.PrimaryIndex DD.PW_GAUSS;
	}
}

class DDHelixCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_HELIX";
		Weapon.SlotNumber 3;
		DDPrimaryWeapon.PrimaryIndex DD.PW_HELIX;
	}
}

class DDPhoenixCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_PHOENIX";
		Weapon.SlotNumber 4;
		DDPrimaryWeapon.PrimaryIndex DD.PW_PHOENIX;
	}
}

class DDOmegaCannon : DDPrimaryWeapon
{
	Default
	{
		Tag "$DD_OMEGA";
		Weapon.SlotNumber 5;
		DDPrimaryWeapon.PrimaryIndex DD.PW_OMEGA;
	}
}

//--------------------------------------------------------------------------
// Secondary ammo (Secondary_ammo_max; the ammo rack doubles it)

class DDFlashAmmo : Ammo
{
	Default { Tag "$DD_FLASH"; Inventory.MaxAmount 20; Ammo.BackpackMaxAmount 40; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}
class DDGuidedAmmo : Ammo
{
	Default { Tag "$DD_GUIDED"; Inventory.MaxAmount 20; Ammo.BackpackMaxAmount 40; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}
class DDSmartMineAmmo : Ammo
{
	Default { Tag "$DD_SMARTMINE"; Inventory.MaxAmount 15; Ammo.BackpackMaxAmount 30; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}
class DDMercuryAmmo : Ammo
{
	Default { Tag "$DD_MERCURY"; Inventory.MaxAmount 10; Ammo.BackpackMaxAmount 20; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}
class DDEarthshakerAmmo : Ammo
{
	Default { Tag "$DD_EARTHSHAKER"; Inventory.MaxAmount 10; Ammo.BackpackMaxAmount 20; Inventory.Icon "TNT1A0"; +INVENTORY.IGNORESKILL }
}

// The ammo rack: GZDoom's backpack mechanism raises every ammo type to
// its BackpackMaxAmount (double, for Descent's).
class DDAmmoRack : BackpackItem
{
	Default
	{
		Inventory.PickupMessage "";
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
	}
}

//--------------------------------------------------------------------------
// Powerups

class DDSuperLaserPowerup : DDPowerup
{
	Default
	{
		Inventory.PickupMessage "$DD_GOTSUPERLASER";
		DDPowerup.PowSize 4;
	}

	States
	{
	Spawn:
		DP77 ABCDEFGHIJKLMNO 3;
		Loop;
	Pickup:
		TNT1 A 0 { return invoker.Upgrade(self); }
		Stop;
	}

	// POW_SUPER_LASER: straight to level 5, then 6.
	bool Upgrade(Actor toucher)
	{
		let ship = Ship(toucher);
		if (ship == null) return false;
		if (ship.laserLevel >= 5)
		{
			if (toucher.CountInv('DDEnergy') >= DD.MAX_ENERGY) return false;
			toucher.GiveInventory('DDEnergy', BoostAmount());
			return true;
		}
		ship.laserLevel = max(ship.laserLevel, 3) + 1;
		if (!toucher.FindInventory('DDSuperLaserCannon'))
		{
			toucher.GiveInventory('DDSuperLaserCannon', 1);
			if (ship.CurrentPrimary() == DD.PW_LASER)
				ship.player.PendingWeapon = Weapon(toucher.FindInventory('DDSuperLaserCannon'));
		}
		return true;
	}
}

// Berserk in Descent II mode: the super laser, and shields like Doom's.
class DDSuperBerserk : DDSuperLaserPowerup
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

class DDGaussPowerup : DDWeaponPowerup
{
	Default { DDWeaponPowerup.WeaponType "DDGaussCannon"; Inventory.PickupMessage "$DD_GOTGAUSS"; }
	States { Spawn: DP69 ABCDEFGHIJKLMNOP 3; Loop; }
}
class DDHelixPowerup : DDWeaponPowerup
{
	Default { DDWeaponPowerup.WeaponType "DDHelixCannon"; Inventory.PickupMessage "$DD_GOTHELIX"; }
	States { Spawn: DP70 ABCDEFGHIJKLMNOP 3; Loop; }
}
class DDPhoenixPowerup : DDWeaponPowerup
{
	Default { DDWeaponPowerup.WeaponType "DDPhoenixCannon"; DDWeaponPowerup.ExtraEnergy 40; Inventory.PickupMessage "$DD_GOTPHOENIX"; }
	States { Spawn: DP71 ABCDEFGHIJKLMNOP 3; Loop; }
}
class DDOmegaPowerup : DDWeaponPowerup
{
	Default { DDWeaponPowerup.WeaponType "DDOmegaCannon"; DDWeaponPowerup.ExtraEnergy 40; Inventory.PickupMessage "$DD_GOTOMEGA"; }
	States { Spawn: DP72 ABCDEFGHIJKLMNO 3; Loop; }
}

class DDFlash1 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDFlashAmmo"; DDAmmoPowerup.Amount 1; Inventory.PickupMessage "$DD_GOTFLASH1"; }
	States { Spawn: DP78 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDFlash4 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDFlashAmmo"; DDAmmoPowerup.Amount 4; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTFLASH4"; }
	States { Spawn: DP89 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDGuided1 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDGuidedAmmo"; DDAmmoPowerup.Amount 1; Inventory.PickupMessage "$DD_GOTGUIDED1"; }
	States { Spawn: DP79 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDGuided4 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDGuidedAmmo"; DDAmmoPowerup.Amount 4; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTGUIDED4"; }
	States { Spawn: DP90 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDSmartMinePack : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDSmartMineAmmo"; DDAmmoPowerup.Amount 4; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTSMARTMINE"; }
	States { Spawn: DP91 ABCDEFGHIJ 3; Loop; }
}
class DDMercury1 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDMercuryAmmo"; DDAmmoPowerup.Amount 1; Inventory.PickupMessage "$DD_GOTMERCURY1"; }
	States { Spawn: DP81 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDMercury4 : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDMercuryAmmo"; DDAmmoPowerup.Amount 4; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTMERCURY4"; }
	States { Spawn: DQ02 ABCDEFGHIJKLMNO 3; Loop; }
}
class DDEarthshakerPowerup : DDAmmoPowerup
{
	Default { DDAmmoPowerup.AmmoType "DDEarthshakerAmmo"; DDAmmoPowerup.Amount 1; DDPowerup.PowSize 3; Inventory.PickupMessage "$DD_GOTEARTHSHAKER"; }
	States { Spawn: DP82 ABCDEFGHIJKLMNO 3; Loop; }
}

// Ship equipment: afterburner, headlight, energy-to-shield converter,
// ammo rack and the full map.
class DDEquipmentPowerup : DDPowerup
{
	Default
	{
		DDPowerup.PowSize 4;
	}

	States
	{
	Pickup:
		TNT1 A 0 { return invoker.Equip(self); }
		Stop;
	}

	virtual bool Have(DDShip ship) { return false; }
	virtual void Give(DDShip ship) {}

	bool Equip(Actor toucher)
	{
		let ship = Ship(toucher);
		if (ship == null) return false;
		if (Have(ship))
		{
			// Already fitted: Descent II turns it into energy.
			if (toucher.CountInv('DDEnergy') >= DD.MAX_ENERGY) return false;
			toucher.GiveInventory('DDEnergy', BoostAmount());
			return true;
		}
		Give(ship);
		return true;
	}
}

class DDAfterburnerPowerup : DDEquipmentPowerup
{
	Default { Inventory.PickupMessage "$DD_GOTAFTERBURNER"; }
	States { Spawn: DP76 ABCDEFGHIJKLMNO 3; Loop; }
	override bool Have(DDShip ship) { return ship.hasAfterburner; }
	override void Give(DDShip ship) { ship.hasAfterburner = true; ship.afterburnerCharge = 1; }
}

class DDHeadlightPowerup : DDEquipmentPowerup
{
	Default { Inventory.PickupMessage "$DD_GOTHEADLIGHT"; }
	States { Spawn: DP83 ABCDEFGHIJKLMNO 3; Loop; }
	override bool Have(DDShip ship) { return ship.hasHeadlight; }
	override void Give(DDShip ship) { ship.hasHeadlight = true; }
}

class DDConverterPowerup : DDEquipmentPowerup
{
	Default { Inventory.PickupMessage "$DD_GOTCONVERTER"; }
	States { Spawn: DP74 ABCDEFGHIJKLMNOP 3; Loop; }
	override bool Have(DDShip ship) { return ship.hasConverter; }
	override void Give(DDShip ship) { ship.hasConverter = true; }
}

class DDAmmoRackPowerup : DDEquipmentPowerup
{
	Default { Inventory.PickupMessage "$DD_GOTAMMORACK"; }
	States { Spawn: DP75 ABCDEFGHIJKLMNOP 3; Loop; }
	override bool Have(DDShip ship) { return ship.FindInventory('DDAmmoRack') != null; }
	override void Give(DDShip ship) { ship.GiveInventory('DDAmmoRack', 1); }
}

class DDFullMapPowerup : DDEquipmentPowerup
{
	Default { Inventory.PickupMessage "$DD_GOTFULLMAP"; }
	States { Spawn: DP73 ABCDEFGHIJKLMNOP 3; Loop; }
	override bool Have(DDShip ship) { return Level.allmap; }
	override void Give(DDShip ship) { ship.GiveInventoryType('MapRevealer'); }
}
