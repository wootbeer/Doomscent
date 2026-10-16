// Doomscent - Descent II mode: weapon objects.  Behaviour follows the
// Descent II source (LASER.C, COLLIDE.C); stats are in DDWeaponTable.GetD2.

class DDLaserBolt5 : DDLaserBolt1
{
	override void PostBeginPlay()
	{
		DDProjectile.PostBeginPlay();
		A_AttachLight('glow', DynamicLight.PointLight, Color(96, 255, 64), 56, 0);
	}
}
class DDLaserBolt6 : DDLaserBolt5 {}

// Gauss: an invisible high-speed round with a small blast, fed by vulcan
// ammo.
class DDGaussRound : DDVulcanRound {}

class DDHelixBlob : DDBlobProjectile
{
	Default
	{
		DDBlobProjectile.BlobVclip 98;
	}

	States
	{
	Spawn:
		DX98 A -1;
		Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('glow', DynamicLight.PointLight, Color(64, 255, 255), 32, 0);
	}
}

// Phoenix: fireballs that bounce off walls twice.
class DDPhoenixBlob : DDBlobProjectile
{
	Default
	{
		DDBlobProjectile.BlobVclip 68;
		BounceType "Doom";
		BounceFactor 1.0;
		WallBounceFactor 1.0;
		BounceCount 3;
		-BOUNCEAUTOOFF
	}

	States
	{
	Spawn:
		DX68 A -1;
		Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('glow', DynamicLight.PointLight, Color(255, 128, 32), 64, 0);
	}
}

// One flicker of the omega cannon's lightning.
class DDOmegaSpark : Actor
{
	Default
	{
		RenderStyle "Add";
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+BRIGHT
		+FORCEXYBILLBOARD
		+DONTSPLASH
		+NOTONAUTOMAP
	}

	States
	{
	Spawn:
		TNT1 A 2;
		Stop;
	}

	static void Make(Vector3 at, double size)
	{
		let s = Actor.Spawn('DDOmegaSpark', at, ALLOW_REPLACE);
		if (s == null) return;
		s.sprite = s.GetSpriteIndex("DY03");
		s.frame = random(0, 2);
		double sc = DDVclip.ScaleFor(103, size);
		s.Scale = (sc, sc);
	}
}

//--------------------------------------------------------------------------
// Secondary weapons

// Six homing children (create_smart_children), as the smart missile,
// smart mine and earthshaker release.
class DDSmartChildren abstract play
{
	static void Spawn(Actor from, Actor owner, class<DDProjectile> cls, int weaponId, int count, double speedDiv)
	{
		Array<Actor> targets;
		let it = BlockThingsIterator.Create(from, 150 * DD.SCALE);
		while (it.Next())
		{
			let a = it.thing;
			if (a.bIsMonster && !a.bFriendly && a.health > 0 && a.bShootable && from.Distance3D(a) < 150 * DD.SCALE && from.CheckSight(a))
				targets.Push(a);
		}
		DDWeaponStats s;
		DDWeaponTable.Get(weaponId, s);
		for (int i = 0; i < count; i++)
		{
			Vector3 dir;
			Actor goal = null;
			if (targets.Size() > 0)
			{
				goal = targets[random(0, targets.Size() - 1)];
				dir = (from.Vec3To(goal) + (0, 0, goal.Height / 2)).Unit();
			}
			else
			{
				dir = (frandom(-1, 1), frandom(-1, 1), frandom(-1, 1));
				if (dir.Length() < 0.01) dir = (1, 0, 0);
				dir = dir.Unit();
			}
			let child = DDProjectile(Actor.Spawn(cls, from.pos, ALLOW_REPLACE));
			if (child == null) continue;
			child.target = owner;
			child.weaponId = weaponId;
			child.multiplier = 1;
			child.InitStats(s);
			child.trackGoal = goal;
			child.Vel = dir * (s.speed * DD.SCALE / speedDiv) / TICRATE;
			child.FaceDirection(dir);
		}
	}
}

// Flash missile: a blinding white flash.  Monsters caught in it lose
// track of their target for a few seconds; ships in view are dazzled.
class DDFlashMissile : DDMissile
{
	override void OnImpact()
	{
		A_SpawnItemEx('DDFlashLight', flags: SXF_NOCHECKPOSITION);
		double range = splashRadius * 2;
		let it = BlockThingsIterator.Create(self, range);
		while (it.Next())
		{
			let a = it.thing;
			if (a.health <= 0 || Distance3D(a) > range || !CheckSight(a)) continue;
			if (a.player)
			{
				a.A_SetBlend("FF FF FF", 0.8, 35);
			}
			else if (a.bIsMonster && !a.bFriendly)
			{
				a.GiveInventory('DDBlinded', 1);
			}
		}
	}
}

class DDFlashLight : Actor
{
	Default
	{
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+NOTONAUTOMAP
	}

	States
	{
	Spawn:
		TNT1 A 10;
		Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('flash', DynamicLight.PointLight, Color(255, 255, 255), 400, 0);
	}
}

// A blinded monster forgets its target for three seconds.
class DDBlinded : Inventory
{
	int tics;

	Default
	{
		Inventory.MaxAmount 1;
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
	}

	override void AttachToOwner(Actor other)
	{
		Super.AttachToOwner(other);
		tics = 105;
	}

	override bool HandlePickup(Inventory item)
	{
		if (item is 'DDBlinded')
		{
			tics = 105;
			item.bPickupGood = true;
			return true;
		}
		return false;
	}

	override void DoEffect()
	{
		Super.DoEffect();
		if (owner == null) return;
		if (--tics <= 0 || owner.health <= 0)
		{
			Destroy();
			return;
		}
		owner.target = null;
		owner.lastheard = null;
		owner.lastenemy = null;
	}
}

// Guided missile: the player flies it.  DDShip routes its turning input
// here and watches through it while it's alive.
class DDGuidedMissile : DDMissile
{
	Vector3 gFwd, gRgt, gUp;
	bool guided;

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		let ship = DDShip(target);
		if (ship)
		{
			gFwd = ship.fwd;
			gRgt = ship.rgt;
			gUp = ship.up;
		}
		else
		{
			gFwd = (AngleToVector(Angle, cos(Pitch)), -sin(Pitch));
			gRgt = (sin(Angle), -cos(Angle), 0);
			gUp = gRgt cross gFwd;
		}
	}

	// Turn by Descent's guided-missile rule: the controls at half rate.
	void Steer(double pitchUp, double yawRight, double bankRight)
	{
		if (yawRight != 0)
		{
			double c = cos(yawRight), s = sin(yawRight);
			Vector3 f = gFwd * c + gRgt * s;
			gRgt = gRgt * c - gFwd * s;
			gFwd = f;
		}
		if (pitchUp != 0)
		{
			double c = cos(pitchUp), s = sin(pitchUp);
			Vector3 f = gFwd * c + gUp * s;
			gUp = gUp * c - gFwd * s;
			gFwd = f;
		}
		if (bankRight != 0)
		{
			double c = cos(bankRight), s = sin(bankRight);
			Vector3 u = gUp * c + gRgt * s;
			gRgt = gRgt * c - gUp * s;
			gUp = u;
		}
		gFwd = gFwd.Unit();
		gRgt = (gFwd cross gUp).Unit();
		gUp = gRgt cross gFwd;
	}

	override void Tick()
	{
		if (guided && !IsFrozen() && !InStateSequence(CurState, ResolveState('Death')))
		{
			Vel = gFwd * (maxSpeed / TICRATE);
			double a, p;
			[a, p] = DD.VectorAngles(gFwd);
			Angle = a;
			Pitch = p;
			// Roll as DDShip.UpdateViewAngles works it out.
			Vector3 r0 = (sin(a), -cos(a), 0);
			Vector3 u0 = r0 cross gFwd;
			Roll = atan2(gUp dot r0, gUp dot u0);
		}
		else if (!guided)
		{
			// Once released, it homes like a homing missile.
			isHoming = true;
		}
		Super.Tick();
	}
}

// Smart mine: a proximity mine that releases homing blobs.
class DDSmartMine : DDProximityBomb
{
	Default
	{
		DDBlobProjectile.BlobVclip 80;
	}

	States
	{
	Spawn:
		DX80 A -1;
		Stop;
	Bounce:
		DX80 A 0;
		Goto Spawn;
	}

	override void OnImpact()
	{
		DDSmartChildren.Spawn(self, target, 'DDSmartMineBlob', 47, 6, 4);
	}
}

class DDSmartMineBlob : DDSmartBlob
{
	Default
	{
		DDBlobProjectile.BlobVclip 92;
	}

	States
	{
	Spawn:
		DX92 A -1;
		Stop;
	}
}

class DDMercuryMissile : DDMissile {}

// Earthshaker: a huge blast, an earthquake, and six homing warheads.
class DDEarthshaker : DDMissile
{
	override void OnImpact()
	{
		A_QuakeEx(6, 6, 6, 70, 0, splashRadius * 6, "", QF_SCALEDOWN);
		DDSmartChildren.Spawn(self, target, 'DDShakerChild', 54, 6, 4);
	}
}

class DDShakerChild : DDMissile
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		isHoming = true;
	}

	override void OnImpact()
	{
		A_QuakeEx(2, 2, 2, 20, 0, splashRadius * 3, "", QF_SCALEDOWN);
	}
}
