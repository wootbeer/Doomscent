// Doomscent - Descent weapon objects.

class DDProjectile : Actor
{
	int weaponId;
	double multiplier;
	double strength;
	double splashRadius;
	double lifeLeft;
	double age;
	double impactSize;
	int robotHitVclip;
	int wallHitVclip;
	int hitSound;
	double blobSize;
	double maxSpeed;

	bool isHoming;
	Actor trackGoal;

	Default
	{
		Projectile;
		Radius 3;
		Height 6;
		Damage 1;           // the real damage comes from DoSpecialDamage
		RenderStyle "Normal";
		+BRIGHT
		+FORCEXYBILLBOARD
		+DONTSPLASH
		+NOTELEPORT
		+SKYEXPLODE
		+NOBLOODDECALS
		+BLOODLESSIMPACT
		+HITTRACER
	}

	States
	{
	Spawn:
		DMDL A -1;
		Stop;
	Death:
		TNT1 A 0 A_DDImpact;
		Stop;
	}

	virtual void InitStats(DDWeaponStats s)
	{
		strength = s.strength * multiplier;
		splashRadius = s.damageRadius * DD.SCALE;
		lifeLeft = s.lifetime;
		impactSize = s.impactSize;
		robotHitVclip = s.robotHitVclip;
		wallHitVclip = s.wallHitVclip;
		hitSound = s.hitSound;
		blobSize = s.blobSize;
		maxSpeed = s.speed * DD.SCALE;
		if (blobSize > 0) SetBlobScale();
	}

	virtual void SetBlobScale() {}

	void FaceDirection(Vector3 dir)
	{
		double a, p;
		[a, p] = DD.VectorAngles(dir);
		Angle = a;
		Pitch = p;
	}

	double DamageScale()
	{
		return CVar.GetCVar('dd_damage').GetFloat();
	}

	override int DoSpecialDamage(Actor victim, int damage, Name damagetype)
	{
		return int(round(max(strength * DamageScale(), 1)));
	}

	override void Tick()
	{
		if (!IsFrozen() && !InStateSequence(CurState, ResolveState('Death')))
		{
			age += DD.TIC;
			lifeLeft -= DD.TIC;
			if (lifeLeft <= 0)
			{
				OnExpire();
				if (bDestroyed) return;
			}
			if (isHoming && age > 0.125)
				DoHoming();
		}
		Super.Tick();
	}

	// Weapons with a blast radius explode at the end of their life.
	virtual void OnExpire()
	{
		if (splashRadius > 0)
			ExplodeMissile();
		else
			Destroy();
	}

	//----------------------------------------------------------------------
	// Homing (Laser_do_weapon_sequence)

	virtual double MinTrackDot() { return 0.75; }

	bool Trackable(Actor a, Vector3 dir)
	{
		if (a == null || a.health <= 0 || !a.bShootable || a == target) return false;
		if (!a.bIsMonster || a.bFriendly) return false;
		Vector3 to = Vec3To(a) + (0, 0, a.Height / 2);
		double d = to.Length();
		if (d > 250 * DD.SCALE || d < 0.001) return false;
		if ((to / d) dot dir < MinTrackDot()) return false;
		return CheckSight(a, SF_IGNOREVISIBILITY);
	}

	Actor FindHomingTarget(Vector3 dir)
	{
		Actor best = null;
		double bestDot = -2;
		let it = BlockThingsIterator.Create(self, 250 * DD.SCALE);
		while (it.Next())
		{
			let a = it.thing;
			if (!Trackable(a, dir)) continue;
			Vector3 to = (Vec3To(a) + (0, 0, a.Height / 2)).Unit();
			double d = to dot dir;
			if (d > bestDot)
			{
				bestDot = d;
				best = a;
			}
		}
		return best;
	}

	virtual void DoHoming()
	{
		double speed = Vel.Length();
		if (speed < 0.001) return;
		Vector3 dir = Vel / speed;
		if (!Trackable(trackGoal, dir))
			trackGoal = FindHomingTarget(dir);
		if (trackGoal == null) return;

		Vector3 to = (Vec3To(trackGoal) + (0, 0, trackGoal.Height / 2)).Unit();
		double maxTic = maxSpeed / TICRATE;
		if (speed + DD.SCALE / TICRATE < maxTic)
			speed = min(speed + maxTic * DD.TIC / 2 * TICRATE, maxTic);
		Vector3 nd = dir + to;
		if (blobSize > 0) nd += to;          // blobs track harder
		nd = nd.Unit();
		Vel = nd * speed;
		FaceDirection(nd);
	}

	//----------------------------------------------------------------------
	// Impact

	void A_DDImpact()
	{
		bool hitThing = tracer != null && tracer.bShootable && tracer.health > 0 || (tracer != null && tracer.bIsMonster);
		int vc = hitThing ? robotHitVclip : wallHitVclip;
		DDEffect.Make(pos, vc, impactSize * DD.SCALE);
		if (hitSound >= 0)
			A_StartSound(String.Format("ddsnd/%d", hitSound), CHAN_BODY);
		ShootSwitch();
		if (splashRadius > 0)
		{
			// Descent's explode_badass_weapon: full strength at the centre,
			// falling off to nothing at damage_radius.
			int dmg = int(round(strength * DamageScale()));
			A_Explode(dmg, int(splashRadius), XF_HURTSOURCE, true, 0);
		}
		OnImpact();
	}

	virtual void OnImpact() {}

	// In Descent you press switches by shooting them.  A player's shot that
	// hits a usable line other than a door activates it, as the use key
	// would (doors still open by flying into them).
	void ShootSwitch()
	{
		Line l = BlockingLine;
		if (l == null || l.special == 0 || target == null || target.player == null) return;
		if (!(l.activation & (SPAC_Use | SPAC_UseThrough)) || DDShip.IsUsable(l)) return;
		int side = Level.PointOnLineSide(target.pos.xy, l);
		l.Activate(target, side, SPAC_Use);
	}
}

//--------------------------------------------------------------------------
// Primary weapons

class DDLaserBolt1 : DDProjectile
{
	Default
	{
		Radius 3;
		Height 6;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('glow', DynamicLight.PointLight, Color(255, 64, 32), 48, 0);
	}
}

class DDLaserBolt2 : DDLaserBolt1 {}
class DDLaserBolt3 : DDLaserBolt1 {}
class DDLaserBolt4 : DDLaserBolt1 {}

class DDBlobProjectile : DDProjectile
{
	int blobVclip;
	property BlobVclip: blobVclip;

	override void SetBlobScale()
	{
		double s = DDVclip.ScaleFor(blobVclip, blobSize * 2 * DD.SCALE);
		Scale = (s, s);
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || InStateSequence(CurState, ResolveState('Death'))) return;
		int n;
		double ft;
		[n, ft] = DDVclip.Info(blobVclip);
		if (n > 0) frame = int(age / ft) % n;
	}
}

// Vulcan rounds are invisible in Descent; only the impacts show.
class DDVulcanRound : DDProjectile
{
	Default
	{
		Radius 2;
		Height 4;
		+BLOODSPLATTER
		-NOBLOODDECALS
		-BLOODLESSIMPACT
	}

	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}
}

class DDSpreadBlob : DDProjectile
{
	States
	{
	Spawn:
		DBSP A -1;
		Stop;
	}

	override void SetBlobScale()
	{
		TextureID tex = TexMan.CheckForTexture("DBSPA0", TexMan.Type_Sprite);
		if (!tex.IsValid()) return;
		int w, h;
		[w, h] = TexMan.GetSize(tex);
		if (w > 0) Scale = (blobSize * 2 * DD.SCALE / w, blobSize * 2 * DD.SCALE / w);
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('glow', DynamicLight.PointLight, Color(64, 96, 255), 32, 0);
	}
}

class DDPlasmaBlob : DDBlobProjectile
{
	Default
	{
		DDBlobProjectile.BlobVclip 54;
	}

	States
	{
	Spawn:
		DX54 A -1;
		Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('glow', DynamicLight.PointLight, Color(64, 255, 96), 48, 0);
	}
}

// The fusion bolt passes through everything it kills, hitting each thing once.
class DDFusionBolt : DDProjectile
{
	Array<Actor> alreadyHit;

	Default
	{
		Radius 6;
		Height 12;
		+RIPPER
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('glow', DynamicLight.PointLight, Color(160, 64, 255), 96, 0);
	}

	override int SpecialMissileHit(Actor victim)
	{
		if (victim == target) return 1;
		if (alreadyHit.Find(victim) != alreadyHit.Size()) return 1;
		alreadyHit.Push(victim);
		if (victim.bShootable)
		{
			int dmg = int(round(strength * DamageScale()));
			victim.DamageMobj(self, target, dmg, 'Fusion');
			DDEffect.Make(victim.pos + (0, 0, victim.Height / 2), robotHitVclip, impactSize * DD.SCALE);
			A_StartSound(String.Format("ddsnd/%d", hitSound), CHAN_BODY, CHANF_OVERLAP);
		}
		return 1;
	}
}

class DDFlare : DDProjectile
{
	bool stuck;

	Default
	{
		Radius 2;
		Height 4;
		-NOBLOCKMAP
		+NOTARGET
	}

	States
	{
	Death:
		DMDL A 0 { stuck = true; }
		DMDL A 1;
		Wait;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		lifeLeft += frandom(-2, 2);
		A_AttachLight('glow', DynamicLight.PointLight, Color(255, 220, 160), 160, 0);
	}

	override void OnExpire()
	{
		Destroy();
	}
}

//--------------------------------------------------------------------------
// Secondary weapons

class DDMissile : DDProjectile
{
	Default
	{
		Radius 4;
		Height 8;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_AttachLight('glow', DynamicLight.PointLight, Color(255, 160, 64), 64, 0);
	}

	override void Tick()
	{
		Super.Tick();
		// Smoke trail.
		if (!bDestroyed && !IsFrozen() && (Level.maptime & 3) == 0 && !InStateSequence(CurState, ResolveState('Death')))
			DDEffect.Make(pos - Vel, 2, 2 * DD.SCALE / 2);
	}
}

class DDConcussionMissile : DDMissile {}

class DDHomingMissile : DDMissile
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		isHoming = true;
	}
}

// Splits into homing blobs when it explodes.
class DDSmartMissile : DDMissile
{
	override void OnImpact()
	{
		// create_smart_children(): up to six blobs aimed at nearby enemies.
		Array<Actor> targets;
		let it = BlockThingsIterator.Create(self, 150 * DD.SCALE);
		while (it.Next())
		{
			let a = it.thing;
			if (a.bIsMonster && !a.bFriendly && a.health > 0 && a.bShootable && Distance3D(a) < 150 * DD.SCALE && CheckSight(a))
				targets.Push(a);
		}
		for (int i = 0; i < 6; i++)
		{
			Vector3 dir;
			Actor goal = null;
			if (targets.Size() > 0)
			{
				goal = targets[random(0, targets.Size() - 1)];
				dir = (Vec3To(goal) + (0, 0, goal.Height / 2)).Unit();
			}
			else
			{
				dir = (frandom(-1, 1), frandom(-1, 1), frandom(-1, 1));
				if (dir.Length() < 0.01) dir = (1, 0, 0);
				dir = dir.Unit();
			}
			let blob = DDSmartBlob(Spawn('DDSmartBlob', pos, ALLOW_REPLACE));
			if (blob == null) continue;
			DDWeaponStats s;
			DDWeaponTable.Get(19, s);
			blob.target = target;
			blob.weaponId = 19;
			blob.multiplier = 1;
			blob.InitStats(s);
			blob.trackGoal = goal;
			blob.Vel = dir * (s.speed * DD.SCALE / 4) / TICRATE;
			blob.FaceDirection(dir);
		}
	}
}

class DDSmartBlob : DDBlobProjectile
{
	Default
	{
		DDBlobProjectile.BlobVclip 54;
		BounceType "Doom";
		BounceFactor 1.0;
		WallBounceFactor 1.0;
		BounceCount 3;
	}

	States
	{
	Spawn:
		DX54 A -1;
		Stop;
	}

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		isHoming = true;
	}

	override double MinTrackDot() { return -0.5; }

	override void DoHoming()
	{
		// Smart children stop bouncing once they start tracking.
		bBounceOnWalls = false;
		bBounceOnFloors = false;
		bBounceOnCeilings = false;
		Super.DoHoming();
	}
}

class DDMegaMissile : DDMissile
{
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		isHoming = true;
	}

	override void OnImpact()
	{
		A_QuakeEx(3, 3, 3, 20, 0, splashRadius * 3, "", QF_SCALEDOWN);
	}
}

// Proximity bombs drift with drag and go off when something comes close.
class DDProximityBomb : DDBlobProjectile
{
	Default
	{
		DDBlobProjectile.BlobVclip 53;
		Radius 6;
		Height 12;
		BounceType "Doom";
		BounceFactor 0.5;
		WallBounceFactor 0.5;
		+USEBOUNCESTATE
		+CANBOUNCEWATER
	}

	States
	{
	Spawn:
		DX53 A -1;
		Stop;
	Bounce:
		DX53 A 0;
		Goto Spawn;
	}

	override void Tick()
	{
		if (!IsFrozen() && !InStateSequence(CurState, ResolveState('Death')))
		{
			// Physics drag (0.033 per 1/64s, as for the ship).
			Vector3 v = DDShip.SimulateDrag(Vel * TICRATE, (0, 0, 0), DD.SHIP_DRAG, DD.TIC);
			Vel = v / TICRATE;
			if (age > 1.0 && (Level.maptime % 4) == 0 && SomethingNear())
			{
				ExplodeMissile();
				return;
			}
		}
		Super.Tick();
	}

	bool SomethingNear()
	{
		let it = BlockThingsIterator.Create(self, 64);
		while (it.Next())
		{
			let a = it.thing;
			if (a == self || a.health <= 0 || !a.bShootable) continue;
			if (a == target && age < 2) continue;
			if (!a.bIsMonster && !a.player) continue;
			if (a.bFriendly && a != target) continue;
			if (Distance3D(a) < 24 + a.radius) return true;
		}
		return false;
	}

	// Bombs don't blow up when they touch walls; they bounce instead.
	override int SpecialMissileHit(Actor victim)
	{
		if (victim == target && age < 2) return 1;
		return -1;
	}
}
