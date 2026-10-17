// Doomscent - Descent's cheat codes, typed during play like Doom's (which
// still work).  Descent 1 mode takes Descent 1's codes, Descent II mode
// Descent II's; the effects follow the games' FinalCheats().

class DDCheatHandler : EventHandler
{
	enum ECheat
	{
		CH_ENABLE, CH_WOWIE, CH_WOWIE2, CH_ALLKEYS, CH_INVUL, CH_CLOAK, CH_SHIELDS,
		CH_KILLREACTOR, CH_LEVELWARP, CH_RAPIDFIRE, CH_ROBOTSNOFIRE, CH_LAMER,
		CH_ACCESSORY, CH_FULLMAP, CH_BOUNCY, CH_HOMING, CH_KILLROBOTS,
		CH_ROBOTSKILLROBOTS, CH_MONSTERDAMAGE, CH_EXITPATH, CH_GHOST, CH_TURBO,
		CH_ACID
	}

	static const String d1Codes[] =
	{
		"gabbagabbahey", "scourge", "bigred", "mitzi", "racerx", "guile",
		"twilight", "poboys", "farmerjoe", "porgys", "ahimsa",
		"flash", "astral", "buggin", "bittersweet"
	};
	static const int d1Cheats[] =
	{
		CH_ENABLE, CH_WOWIE, CH_WOWIE2, CH_ALLKEYS, CH_INVUL, CH_CLOAK,
		CH_SHIELDS, CH_KILLREACTOR, CH_LEVELWARP, CH_RAPIDFIRE, CH_ROBOTSNOFIRE,
		CH_EXITPATH, CH_GHOST, CH_TURBO, CH_ACID
	};

	static const String d2Codes[] =
	{
		"gabbagabbahey", "motherlode", "currygoat", "zingermans", "eatangelos",
		"ericaanne", "joshuaakira", "whammazoom",
		"honestbob", "oralgroove", "alifalafel", "almighty", "blueorb",
		"delshiftb", "freespace", "rockrgrl", "wildfire", "duddaboo",
		"lpnlizard", "imagespace", "spaniard", "silkwing", "godzilla",
		"flash", "astral", "buggin", "bittersweet"
	};
	static const int d2Cheats[] =
	{
		CH_LAMER, CH_LAMER, CH_LAMER, CH_LAMER, CH_LAMER,
		CH_LAMER, CH_LAMER, CH_LAMER,
		CH_WOWIE, CH_ALLKEYS, CH_ACCESSORY, CH_INVUL, CH_SHIELDS,
		CH_KILLREACTOR, CH_LEVELWARP, CH_FULLMAP, CH_RAPIDFIRE, CH_BOUNCY,
		CH_HOMING, CH_ROBOTSNOFIRE, CH_KILLROBOTS, CH_ROBOTSKILLROBOTS, CH_MONSTERDAMAGE,
		CH_EXITPATH, CH_GHOST, CH_TURBO, CH_ACID
	};

	ui String typed;
	ui String warpDigits;
	ui bool warping;
	ui bool acidShown;

	override bool InputProcess(InputEvent e)
	{
		if (e.Type != InputEvent.Type_KeyDown || gamestate != GS_LEVEL) return false;
		int c = e.KeyChar;
		if (c >= 0x41 && c <= 0x5a) c += 0x20;

		// The level warp asks for a number: two digits, like Doom's idclev.
		if (warping)
		{
			if (c >= 0x30 && c <= 0x39)
			{
				warpDigits.AppendCharacter(c);
				if (warpDigits.Length() == 2)
				{
					warping = false;
					SendNetworkEvent("dd_warp", warpDigits.ToInt());
				}
				return true;
			}
			warping = false;
			return false;
		}

		if (c < 0x61 || c > 0x7a) return false;
		typed.AppendCharacter(c);
		if (typed.Length() > 15) typed = typed.Mid(typed.Length() - 15);

		bool d2 = DD.IsD2();
		int n = d2 ? d2Codes.Size() : d1Codes.Size();
		int matched = 0;
		for (int i = 0; i < n; i++)
		{
			String code = d2 ? d2Codes[i] : d1Codes[i];
			if (typed.Length() >= code.Length() && typed.Mid(typed.Length() - code.Length()) == code)
			{
				typed = "";
				SendNetworkEvent("dd_cheat", d2 ? d2Cheats[i] : d1Cheats[i]);
				return true;
			}
			matched = max(matched, PrefixTyped(code));
		}
		// Like GZDoom's own cheats, keys three letters into a code don't
		// reach their bindings, so codes with T in them don't open the chat.
		// In single player the chat key is never needed, so it can start one.
		if (matched >= 3) return true;
		if (matched >= 1 && !multiplayer && Bindings.GetBinding(e.KeyScan).Left(11) ~== "messagemode") return true;
		return false;
	}

	// How many of the code's first letters were just typed.
	ui int PrefixTyped(String code)
	{
		for (int len = min(code.Length() - 1, typed.Length()); len > 0; len--)
			if (typed.Mid(typed.Length() - len) == code.Left(len)) return len;
		return 0;
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Player < 0 || !playeringame[e.Player]) return;
		let ship = DDShip(players[e.Player].mo);
		if (ship == null || ship.health <= 0) return;
		// Like Doom's, the codes need sv_cheats in multiplayer.
		if (multiplayer && !CVar.FindCVar('sv_cheats').GetBool()) return;

		if (e.Name == 'dd_cheat')
		{
			int cheat = e.Args[0];
			// Descent 1 takes no codes until gabbagabbahey.
			if (!DD.IsD2() && !ship.cheatsEnabled && cheat != CH_ENABLE) return;
			ship.DoCheat(cheat);
			if (cheat == CH_LEVELWARP && e.Player == consoleplayer)
				warpRequests++;
		}
		else if (e.Name == 'dd_warp')
		{
			ship.WarpToLevel(e.Args[0]);
		}
	}

	// The warp prompt and the screen effects live in ui scope; play scope
	// asks for them through these.
	int warpRequests;
	ui int warpRequestsSeen;

	override void UiTick()
	{
		if (warpRequests != warpRequestsSeen)
		{
			warpRequestsSeen = warpRequests;
			warping = true;
			warpDigits = "";
		}
		let ship = DDShip(players[consoleplayer].mo);

		// Acid: Descent wobbles the level's vertices; a post-process shader
		// wobbles the view.
		bool acid = ship != null && ship.cheatAcid;
		if (acid != acidShown)
		{
			acidShown = acid;
			PPShader.SetEnabled("ddacid", acid);
		}
		if (acid)
			PPShader.SetUniform1f("ddacid", "timer", MSTimeF() / 1000.);
	}

	override void WorldTick()
	{
		if (Level.maptime % 4) return;
		bool noFire = false, rabid = false;
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			let ship = playeringame[i] ? DDShip(players[i].mo) : null;
			if (ship == null) continue;
			noFire |= ship.cheatRobotsNoFire;
			rabid |= ship.cheatRobotsKillRobots;
			// The full map stays on from level to level.
			if (ship.cheatFullMap) Level.allmap = true;
		}
		if (!noFire && !rabid) return;

		let it = ThinkerIterator.Create('Actor', Thinker.STAT_DEFAULT);
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (!mo.bIsMonster || mo.health <= 0 || mo.bFriendly) continue;
			let ship = mo.target ? DDShip(mo.target) : null;
			if (rabid && (mo.target == null || ship) && Level.maptime % 35 < 4)
			{
				// Rabid robots go for the nearest other robot they can see.
				let other = NearestMonster(mo);
				if (other)
				{
					mo.target = other;
					if (mo.InStateSequence(mo.CurState, mo.SpawnState)) mo.SetState(mo.SeeState);
					continue;
				}
			}
			if (noFire && ship && ship.cheatRobotsNoFire)
			{
				mo.target = null;
				mo.lastheard = null;
				mo.lastenemy = null;
			}
		}
	}

	static Actor NearestMonster(Actor mo)
	{
		double range = 100 * DD.SCALE;
		Actor best = null;
		let it = BlockThingsIterator.Create(mo, range);
		while (it.Next())
		{
			let a = it.thing;
			if (a == mo || !a.bIsMonster || a.health <= 0 || !a.bShootable) continue;
			double d = mo.Distance3D(a);
			if (d < range && mo.CheckSight(a))
			{
				range = d;
				best = a;
			}
		}
		return best;
	}
}

extend class DDShip
{
	bool cheatsEnabled;
	bool cheatRapidFire, cheatBouncy, cheatHoming, cheatTurbo, cheatAcid;
	bool cheatRobotsNoFire, cheatRobotsKillRobots, cheatMonsterDamage, cheatFullMap;
	bool exitPathMade;
	String exitPathMap;

	void CheatMessage(String msg)
	{
		ShowMessage(StringTable.Localize(msg));
	}

	void CheatToggleMessage(String what, bool on)
	{
		ShowMessage(String.Format("%s %s!", StringTable.Localize(what), StringTable.Localize(on ? "$DD_ON" : "$DD_OFF")));
	}

	void DoCheat(int cheat)
	{
		A_StartSound("ddsnd/200", CHAN_VOICE, CHANF_UI | CHANF_LOCAL);
		bool d2 = DD.IsD2();
		switch (cheat)
		{
		case DDCheatHandler.CH_ENABLE:
			if (!cheatsEnabled) CheatMessage("$DD_CHEATSON");
			cheatsEnabled = true;
			break;

		case DDCheatHandler.CH_WOWIE:
			if (d2)
			{
				GiveAllPrimaries(DD.NUM_PRIMARIES);
				GiveAllSecondaries(DD.NUM_SECONDARIES);
				SetLaserLevel(5);
			}
			else
			{
				// Descent 1's: laser, vulcan and spreadfire, and the first
				// three missiles.
				GiveAllPrimaries(3);
				GiveAllSecondaries(3);
				SetLaserLevel(3);
			}
			CheatMessage("$DD_WOWIE");
			break;

		case DDCheatHandler.CH_WOWIE2:
			GiveAllPrimaries(5);
			GiveAllSecondaries(5);
			SetLaserLevel(3);
			ShowMessage(StringTable.Localize("$DD_SUPER") .. " " .. StringTable.Localize("$DD_WOWIE"));
			break;

		case DDCheatHandler.CH_ALLKEYS:
			CheatGive("keys", 0);
			CheatMessage("$DD_ALLKEYS");
			break;

		case DDCheatHandler.CH_INVUL:
			player.cheats ^= CF_GODMODE;
			CheatToggleMessage("$DD_INVULNERABILITY", player.cheats & CF_GODMODE);
			break;

		case DDCheatHandler.CH_CLOAK:
		{
			bool on = FindInventory('PowerInvisibility') == null;
			if (on) GiveInventory('PowerInvisibility', 1);
			else TakeInventory('PowerInvisibility', 1);
			CheatToggleMessage("$DD_CLOAK", on);
			break;
		}

		case DDCheatHandler.CH_SHIELDS:
			player.health = health = DD.MAX_SHIELDS;
			CheatMessage("$DD_FULLSHIELDS");
			break;

		case DDCheatHandler.CH_KILLREACTOR:
			// Kill every robot, pick up every powerup, blow the reactor and
			// leave: here, the level is over.
			CheatMessage("$DD_KILLREACTOR");
			KillMonsters(true);
			CollectItems();
			Level.ExitLevel(0, false);
			break;

		case DDCheatHandler.CH_LEVELWARP:
			CheatMessage("$DD_WARPTO");
			break;

		case DDCheatHandler.CH_RAPIDFIRE:
			cheatRapidFire = !cheatRapidFire;
			CheatToggleMessage("$DD_RAPIDFIRE", cheatRapidFire);
			// Descent 1's also hands out everything (the mega-wowie powerup).
			if (cheatRapidFire && !d2) MegaWowie(200);
			break;

		case DDCheatHandler.CH_ROBOTSNOFIRE:
			cheatRobotsNoFire = !cheatRobotsNoFire;
			if (cheatRobotsNoFire) player.cheats |= CF_NOTARGET;
			else player.cheats &= ~CF_NOTARGET;
			CheatToggleMessage("$DD_ROBOTFIRING", !cheatRobotsNoFire);
			break;

		case DDCheatHandler.CH_LAMER:
			// Descent II's old Descent 1 codes: a cheater gets nothing.
			player.health = health = 1;
			SetInventory('DDEnergy', 1);
			CheatMessage("$DD_LAMER");
			break;

		case DDCheatHandler.CH_ACCESSORY:
			hasHeadlight = hasConverter = true;
			hasAfterburner = true;
			afterburnerCharge = 1;
			GiveInventory('DDAmmoRack', 1);
			CheatMessage("$DD_ACCESSORIES");
			break;

		case DDCheatHandler.CH_FULLMAP:
			cheatFullMap = !cheatFullMap;
			Level.allmap = cheatFullMap;
			CheatMessage(cheatFullMap ? "$DD_FULLMAP" : "$DD_REGULARMAP");
			break;

		case DDCheatHandler.CH_BOUNCY:
			cheatBouncy = !cheatBouncy;
			CheatToggleMessage("$DD_BOUNCY", cheatBouncy);
			break;

		case DDCheatHandler.CH_HOMING:
			cheatHoming = !cheatHoming;
			CheatToggleMessage("$DD_HOMINGFIRE", cheatHoming);
			break;

		case DDCheatHandler.CH_KILLROBOTS:
			ShowMessage(String.Format(StringTable.Localize("$DD_TOASTED"), KillMonsters(false)));
			break;

		case DDCheatHandler.CH_ROBOTSKILLROBOTS:
			cheatRobotsKillRobots = !cheatRobotsKillRobots;
			CheatMessage(cheatRobotsKillRobots ? "$DD_RABID" : "$DD_KILLPLAYER");
			break;

		case DDCheatHandler.CH_MONSTERDAMAGE:
			cheatMonsterDamage = !cheatMonsterDamage;
			CheatMessage(cheatMonsterDamage ? "$DD_TOKYO" : "$DD_SHRINKING");
			break;

		case DDCheatHandler.CH_EXITPATH:
			if (MarkExitPath()) CheatMessage("$DD_EXITPATH");
			break;

		case DDCheatHandler.CH_GHOST:
			player.cheats ^= CF_NOCLIP;
			CheatToggleMessage("$DD_GHOSTY", player.cheats & CF_NOCLIP);
			break;

		case DDCheatHandler.CH_TURBO:
			cheatTurbo = !cheatTurbo;
			CheatToggleMessage("$DD_TURBO", cheatTurbo);
			break;

		case DDCheatHandler.CH_ACID:
			cheatAcid = !cheatAcid;
			break;
		}
	}

	void GiveAllPrimaries(int count)
	{
		static const class<Weapon> weapons[] = { 'DDLaserCannon', 'DDVulcanCannon', 'DDSpreadfireCannon',
			'DDPlasmaCannon', 'DDFusionCannon', 'DDSuperLaserCannon', 'DDGaussCannon', 'DDHelixCannon',
			'DDPhoenixCannon', 'DDOmegaCannon' };
		for (int i = 0; i < count; i++)
			if (!FindInventory(weapons[i])) GiveInventory(weapons[i], 1);
		GiveInventory('DDVulcanAmmo', DD.VULCAN_AMMO_MAX * 2);
		GiveInventory('DDEnergy', DD.MAX_ENERGY);
		omegaCharge = 1;
	}

	// Fills the missiles to their (current) maximum.
	void GiveAllSecondaries(int count)
	{
		for (int i = 0; i < count; i++)
			GiveInventory(DD.SecondaryAmmo(i), 1000);
	}

	void SetLaserLevel(int level)
	{
		laserLevel = level;
		quadLasers = true;
	}

	// do_megawow_powerup(): every weapon, missiles, full shields and energy.
	void MegaWowie(int quantity)
	{
		GiveAllPrimaries(5);
		for (int i = 0; i < 5; i++)
			SetInventory(DD.SecondaryAmmo(i), i < 3 ? quantity : quantity / 5);
		player.health = health = DD.MAX_SHIELDS;
		SetLaserLevel(3);
		ShowMessage(StringTable.Localize("$DD_MEGAWOWIE"));
	}

	// Kills every monster but the bosses (kill_all_robots); with
	// everything, the bosses too.  Returns how many died.
	int KillMonsters(bool everything)
	{
		int count = 0;
		let it = ThinkerIterator.Create('Actor', Thinker.STAT_DEFAULT);
		Actor mo;
		while (mo = Actor(it.Next()))
		{
			if (!mo.bIsMonster || mo.health <= 0 || mo.bFriendly) continue;
			if (mo.bBoss && !everything) continue;
			mo.DamageMobj(null, self, TELEFRAG_DAMAGE, 'Massacre', DMG_FORCED);
			count++;
		}
		return count;
	}

	// Picks up everything lying around the level (do_powerup on each).
	void CollectItems()
	{
		Array<Inventory> items;
		let it = ThinkerIterator.Create('Inventory', Thinker.STAT_DEFAULT);
		Inventory inv;
		while (inv = Inventory(it.Next()))
			if (inv.owner == null && inv.bSpecial) items.Push(inv);
		for (int i = 0; i < items.Size(); i++)
			if (items[i] && !items[i].owner) items[i].Touch(self);
	}

	// Level warp (farmerjoe, freespace): two digits, like Doom's idclev.
	void WarpToLevel(int num)
	{
		String dest;
		String cur = Level.MapName.MakeUpper();
		if (cur.Length() == 4 && cur.Left(1) == "E" && cur.Mid(2, 1) == "M")
		{
			dest = String.Format("E%dM%d", num / 10, num % 10);
		}
		else
		{
			let info = LevelInfo.FindLevelByNum(num);
			dest = info ? info.MapName : String.Format("MAP%02d", num);
		}
		if (!LevelInfo.MapExists(dest))
		{
			ShowMessage(String.Format(StringTable.Localize("$DD_NOLEVEL"), num));
			return;
		}
		Level.ChangeLevel(dest, 0, CHANGELEVEL_NOINTERMISSION);
	}

	// Rapid fire: a shot every 1/25 second.  Turbo mode (Descent doubles
	// the game's clock) runs the ship's flight and guns at double speed.
	double FireWait(double wait)
	{
		if (cheatRapidFire) wait = 1. / 25;
		return cheatTurbo ? wait / 2 : wait;
	}

	// Descent II's bouncing and homing weapons apply to the ship's shots.
	void CheatProjectile(DDProjectile mo)
	{
		if (cheatHoming) mo.isHoming = true;
		if (cheatBouncy && !mo.bBounceOnWalls)
		{
			// PF_BOUNCES_TWICE
			mo.bBounceOnWalls = mo.bBounceOnFloors = mo.bBounceOnCeilings = true;
			mo.BounceCount = 3;
			mo.BounceFactor = mo.WallBounceFactor = 1;
			mo.bBounceAutoOff = false;
		}
	}

	// Descent II's godzilla: ramming a robot destroys it.
	void RamMonsters()
	{
		if (!cheatMonsterDamage) return;
		let it = BlockThingsIterator.Create(self, radius + 64);
		while (it.Next())
		{
			let a = it.thing;
			if (!a.bIsMonster || a.health <= 0 || a.bFriendly) continue;
			if (Distance2D(a) > radius + a.radius + 2) continue;
			if (a.pos.z > pos.z + Height + 2 || pos.z > a.pos.z + a.Height + 2) continue;
			a.DamageMobj(self, self, TELEFRAG_DAMAGE, 'Melee', DMG_FORCED);
		}
	}

	// flash: a trail of energy powerups from the ship to the exit, once a
	// level (mark_player_path_to_segment).  Searches the sector graph for
	// the nearest exit line and drops a powerup at each opening passed.
	bool MarkExitPath()
	{
		if (exitPathMade && exitPathMap == Level.MapName) return false;

		int count = Level.Sectors.Size();
		Array<int> from, via;
		from.Resize(count);
		via.Resize(count);
		for (int i = 0; i < count; i++) from[i] = via[i] = -1;

		Array<int> queue;
		int start = CurSector.Index();
		from[start] = start;
		queue.Push(start);
		int goal = -1;
		for (int q = 0; q < queue.Size() && goal < 0; q++)
		{
			let sec = Level.Sectors[queue[q]];
			for (int i = 0; i < sec.Lines.Size(); i++)
			{
				let l = sec.Lines[i];
				if (DDProjectile.IsExit(l))
				{
					goal = sec.Index();
					break;
				}
				if (l.frontsector == null || l.backsector == null) continue;
				if (l.flags & (Line.ML_BLOCKING | Line.ML_BLOCKEVERYTHING | Line.ML_BLOCK_PLAYERS)) continue;
				let other = l.frontsector == sec ? l.backsector : l.frontsector;
				int o = other.Index();
				if (from[o] >= 0) continue;
				from[o] = sec.Index();
				via[o] = l.Index();
				queue.Push(o);
			}
		}
		if (goal < 0) return false;

		Array<int> path;
		for (int s = goal; s != start; s = from[s])
			path.Push(via[s]);
		for (int i = path.Size() - 1; i >= 0; i--)
		{
			let l = Level.Lines[path[i]];
			Vector2 mid = (l.v1.p + l.v2.p) / 2;
			double floor = max(l.frontsector.floorplane.ZatPoint(mid), l.backsector.floorplane.ZatPoint(mid));
			Spawn('DDPathEnergy', (mid, floor), ALLOW_REPLACE);
		}
		exitPathMade = true;
		exitPathMap = Level.MapName;
		return true;
	}
}

// An energy powerup on the exit path; it disappears after a hundred
// seconds or so.
class DDPathEnergy : DDEnergyBoost
{
	int lifeLeft;

	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		lifeLeft = 35 * 100 + random(0, 35 * 4);
	}

	override void Tick()
	{
		Super.Tick();
		if (!bDestroyed && owner == null && !IsFrozen() && --lifeLeft <= 0) Destroy();
	}
}
