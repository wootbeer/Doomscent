// Doomscent - the Descent cockpit.
//
// Everything is laid out in Descent's 320x200 cockpit coordinates (taken
// from GAUGES.C) and stretched to the screen, as Descent's own ports do.

class DDStatusBar : BaseStatusBar
{
	TextureID texCockpit;
	TextureID texRearView;
	Font gaugeFont;

	override void Init()
	{
		Super.Init();
		// Height 0: never shrink the 3D view for a status bar.
		SetSize(0, 320, 200);
		texCockpit = TexMan.CheckForTexture("DDCOCKPT", TexMan.Type_Any);
		texRearView = TexMan.CheckForTexture("DDREARVW", TexMan.Type_Any);
		// Descent's own gauge font if the asset pack has it.
		gaugeFont = Font.GetFont('ddsmall');
		fontScale = 1.0;
		if (gaugeFont == null)
		{
			gaugeFont = SmallFont;
			fontScale = 0.55;
		}
	}

	double fontScale;

	override void Draw(int state, double ticFrac)
	{
		Super.Draw(state, ticFrac);
		if (CPlayer == null || CPlayer.mo == null) return;
		let ship = DDShip(CPlayer.mo);
		if (ship == null) return;

		// The message line shows on the automap and when dead too.
		CollectShipMessage(ship);
		bool showView = !automapactive && CPlayer.playerstate == PST_LIVE && CPlayer.camera == CPlayer.mo;
		if (!showView)
		{
			DrawMessages();
			return;
		}

		bool cockpit = CVar.GetCVar('dd_cockpit', CPlayer).GetBool() && texCockpit.IsValid() && state != HUD_None;
		if (ship.rearView)
		{
			// Descent's rear view: its own cockpit art and no gauges or
			// reticle; without the cockpit just a "REAR VIEW" label.
			SetupScale();
			if (cockpit && texRearView.IsValid())
			{
				Screen.DrawTexture(texRearView, false, 0, 0,
					DTA_DestWidth, Screen.GetWidth(), DTA_DestHeight, Screen.GetHeight(),
					DTA_TopOffset, 0, DTA_LeftOffset, 0);
			}
			else
			{
				String label = StringTable.Localize("$DD_REARVIEW");
				Txt(label, 160 - gaugeFont.StringWidth(label) * fontScale / 2, 186, COL_MESSAGE);
			}
			DrawMessages();
			return;
		}

		if (cockpit)
			DrawCockpit(ship);
		else
			DrawMinimal(ship, state != HUD_None);
		DrawReticle(ship);
		DrawMessages();

		// 320x200 virtual screen, like the cockpit.
		BeginHUD(1, true, 320, 200);
		DrawOtherKeys(!cockpit);
		DrawInventory();

		// Without mouselook the mouse moves the ship instead of aiming it.
		if (!CVar.GetCVar('freelook', CPlayer).GetBool())
		{
			SetupScale();
			String msg = StringTable.Localize("$DD_FREELOOK");
			Txt(msg, 160 - gaugeFont.StringWidth(msg) * fontScale * 0.65, 20, COL_ENERGY, 1.3);
		}
	}

	//----------------------------------------------------------------------
	// Descent's HUD message line: our messages and everything GZDoom would
	// print top-left, up to three lines, three seconds each.

	const MSG_LINES = 3;
	const MSG_TICS = 105;
	Array<String> msgLines;
	Array<int> msgTimes;
	int lastShipMsg;

	override bool ProcessNotify(EPrintLevel printlevel, String outline)
	{
		if (printlevel & PRINT_NONOTIFY) return false;
		int level = printlevel & PRINT_TYPES;
		if (level == PRINT_CHAT || level == PRINT_TEAMCHAT || level == PRINT_LOG) return false;
		PushMessage(outline);
		return true;
	}

	void CollectShipMessage(DDShip ship)
	{
		if (ship.msgTime != lastShipMsg && ship.msgText.Length() > 0)
		{
			lastShipMsg = ship.msgTime;
			PushMessage(ship.msgText);
		}
	}

	// Text without colour escapes and trailing newlines.
	static String PlainText(String s)
	{
		String res = "";
		int i = 0;
		int len = s.Length();
		while (i < len)
		{
			int c;
			[c, i] = s.GetNextCodePoint(i);
			if (c == 0x1C)                  // TEXTCOLOR_ESCAPE
			{
				if (i < len && s.ByteAt(i) == 0x5B)       // \c[name]
				{
					int close = s.IndexOf("]", i);
					i = close < 0 ? len : close + 1;
				}
				else
				{
					i++;
				}
				continue;
			}
			if (c == 0x0A || c == 0x0D) c = 0x20;
			res.AppendCharacter(c);
		}
		res.StripRight();
		return res;
	}

	void PushMessage(String text)
	{
		text = PlainText(text);
		// Skip empty lines and the console's echo of typed commands.
		if (text.Length() == 0 || text.Left(1) == "]") return;
		let lines = gaugeFont.BreakLines(text, int(300 / fontScale));
		for (int i = 0; i < lines.Count(); i++)
		{
			msgLines.Push(lines.StringAt(i));
			msgTimes.Push(Level.maptime);
		}
		while (msgLines.Size() > MSG_LINES)
		{
			msgLines.Delete(0);
			msgTimes.Delete(0);
		}
	}

	void DrawMessages()
	{
		// Drop expired lines (and any left over from a previous map, whose
		// timestamps are ahead of the restarted map clock).
		while (msgTimes.Size() > 0 && (Level.maptime - msgTimes[0] > MSG_TICS || msgTimes[0] > Level.maptime))
		{
			msgLines.Delete(0);
			msgTimes.Delete(0);
		}
		SetupScale();
		for (int i = 0; i < msgLines.Size(); i++)
		{
			double w = gaugeFont.StringWidth(msgLines[i]) * fontScale;
			Txt(msgLines[i], 160 - w / 2, 4 + i * 7, COL_MESSAGE);
		}
	}

	//----------------------------------------------------------------------
	// Coordinate helpers (320x200 space -> screen)

	double sx, sy;

	void SetupScale()
	{
		sx = Screen.GetWidth() / 320.;
		sy = Screen.GetHeight() / 200.;
	}

	// Clips are in the picture's own (320x200-space) units from its left
	// or top edge.  Descent II's hi-res pictures report their 320x200 size
	// (see the asset pack's TEXTURES).
	void Pic(String name, double x, double y, double clipL = -1, double clipR = -1, double clipT = -1)
	{
		TextureID t = TexMan.CheckForTexture(name, TexMan.Type_Any);
		if (!t.IsValid()) return;
		Vector2 size = TexMan.GetScaledSize(t);
		double w = size.x, h = size.y;
		double cl = clipL >= 0 ? x + clipL : x;
		double cr = clipR >= 0 ? x + clipR : x + w;
		double ct = clipT >= 0 ? y + clipT : y;
		Screen.DrawTexture(t, false, x * sx, y * sy,
			DTA_DestWidthF, w * sx, DTA_DestHeightF, h * sy,
			DTA_TopOffset, 0, DTA_LeftOffset, 0,
			DTA_ClipLeft, int(cl * sx), DTA_ClipRight, int(cr * sx), DTA_ClipTop, int(ct * sy));
	}

	static double PicWidth(String name, double fallback)
	{
		TextureID t = TexMan.CheckForTexture(name, TexMan.Type_Any);
		if (!t.IsValid()) return fallback;
		Vector2 size = TexMan.GetScaledSize(t);
		return size.x;
	}

	static double PicHeight(String name, double fallback)
	{
		TextureID t = TexMan.CheckForTexture(name, TexMan.Type_Any);
		if (!t.IsValid()) return fallback;
		Vector2 size = TexMan.GetScaledSize(t);
		return size.y;
	}

	// Descent's gauge colours (gr_getcolor values from GAUGES.C, brightened
	// a little for modern displays).
	const COL_ENERGY = 0xFFE0A030;
	const COL_SHIELD = 0xFF9090FF;
	const COL_WEAPON = 0xFF20C020;
	const COL_AMMO = 0xFFD02020;
	const COL_MESSAGE = 0xFF20E020;

	void Txt(String s, double x, double y, Color col, double scale = 1.0)
	{
		scale *= fontScale;
		Screen.DrawText(gaugeFont, Font.CR_UNTRANSLATED, x * sx, y * sy, s,
			DTA_ScaleX, sx * scale, DTA_ScaleY, sy * scale, DTA_Color, col);
	}

	void TxtRight(String s, double right, double y, Color color, double scale = 1.0)
	{
		double w = gaugeFont.StringWidth(s) * scale * fontScale;
		Txt(s, right - w, y, color, scale);
	}

	//----------------------------------------------------------------------

	void DrawCockpit(DDShip ship)
	{
		SetupScale();
		int shields = max(CPlayer.health, 0);
		int energy = ship.CountInv('DDEnergy');

		// The dashboard first, then the gauges on top.
		Screen.DrawTexture(texCockpit, false, 0, 0,
			DTA_DestWidth, Screen.GetWidth(), DTA_DestHeight, Screen.GetHeight(),
			DTA_TopOffset, 0, DTA_LeftOffset, 0);

		// Energy bars (draw_energy_bar): they empty from the outside in.
		bool d2 = DD.IsD2();
		double barW = PicWidth("DDENRGL", 64);
		double notEnergy = (61 - (min(energy, 100) * 61) / 100.) * barW / 64;
		Pic("DDENRGL", d2 ? 68.5 : 70, 131, notEnergy, -1);
		Pic("DDENRGR", 190, 131, -1, barW - notEnergy);

		// Numerical readout (draw_numerical_display).
		Pic("DDNUMER", 154, 130);
		TxtRight(String.Format("%d", energy), 154 + 16, 131.5, COL_ENERGY);
		TxtRight(String.Format("%d", shields), 154 + 16, 144.5, COL_SHIELD);

		// Shield ring and ship (draw_shield_bar / draw_player_ship).
		bool invul = CPlayer.mo.FindInventory('PowerInvulnerable') != null;
		if (invul)
		{
			int f = (Level.maptime / 3) % 10;
			Pic(String.Format("DDINVU%d", f), 146, 155);
		}
		else
		{
			int bm = shields >= 100 ? 9 : shields / 10;
			Pic(String.Format("DDSHLD%d", 9 - bm), 146, 155);
		}
		Pic("DDSHIP", 151, 160);

		// Keys (draw_keys): Descent II moved them to the right, and put the
		// afterburner gauge where they were.
		if (d2)
		{
			Pic(HasKey('BlueCard', 'BlueSkull', 'KeyBlue') ? "DDKEYB" : "DDKEYB0", 267.5, 155.8);
			Pic(HasKey('YellowCard', 'YellowSkull', 'KeyYellow') ? "DDKEYY" : "DDKEYY0", 268.5, 164.6);
			Pic(HasKey('RedCard', 'RedSkull') ? "DDKEYR" : "DDKEYR0", 269.5, 173.3);
			if (ship.hasAfterburner)
			{
				double h = PicHeight("DDAFTBRN", 27);
				Pic("DDAFTBRN", 44, 157, -1, -1, (1 - ship.afterburnerCharge) * h);
			}
		}
		else
		{
			Pic(HasKey('BlueCard', 'BlueSkull', 'KeyBlue') ? "DDKEYB" : "DDKEYB0", 45, 152);
			Pic(HasKey('YellowCard', 'YellowSkull', 'KeyYellow') ? "DDKEYY" : "DDKEYY0", 44, 162);
			Pic(HasKey('RedCard', 'RedSkull') ? "DDKEYR" : "DDKEYR0", 43, 172);
		}

		// Homing warning light.
		Pic(ship.homingWarning > 0 && (Level.maptime & 4) ? "DDHOMON" : "DDHOMOF", 7, 171);

		DrawWeaponBoxes(ship);
	}

	// Subclasses count too (Chex Quest's ChexBlueCard is a BlueCard); the
	// third name is Heretic's key of that colour.
	bool HasKey(Name card, Name skull, Name heretic = 'None')
	{
		if (CPlayer.mo.FindInventory(card, true) || CPlayer.mo.FindInventory(skull, true)) return true;
		return heretic != 'None' && CPlayer.mo.FindInventory(heretic, true);
	}

	// Keys Descent has no light for (Heretic's green key, Hexen's keys) are
	// shown as their own icons along the top left.
	static bool HasDescentLight(Inventory k)
	{
		static const Name lit[] = { 'BlueCard', 'BlueSkull', 'KeyBlue', 'YellowCard', 'YellowSkull', 'KeyYellow', 'RedCard', 'RedSkull' };
		for (int i = 0; i < lit.Size(); i++)
		{
			class<Inventory> c = lit[i];
			if (c && k is c) return true;
		}
		return false;
	}

	void DrawOtherKeys(bool includeLit)
	{
		double x = 4;
		for (let item = CPlayer.mo.Inv; item; item = item.Inv)
		{
			if (!(item is 'Key') || !item.Icon.IsValid()) continue;
			if (!includeLit && HasDescentLight(item)) continue;
			DrawInventoryIcon(item, (x, 4), DI_SCREEN_LEFT_TOP | DI_ITEM_LEFT_TOP, 1.0, (10, 10));
			x += 12;
		}
	}

	// Heretic/Hexen artifacts and puzzle items: GZDoom's inventory bar
	// while browsing ([ and ]), otherwise the selected item at top right.
	InventoryBarState invBar;
	HUDFont invFont;

	void DrawInventory()
	{
		if (invBar == null)
		{
			invFont = HUDFont.Create(gaugeFont);
			invBar = InventoryBarState.Create(invFont);
		}
		if (isInventoryBarVisible())
		{
			DrawInventoryBar(invBar, (0, 24), 7, DI_SCREEN_CENTER_TOP, 0.7);
			return;
		}
		let sel = CPlayer.mo.InvSel;
		if (sel == null || !sel.Icon.IsValid()) return;
		DrawInventoryIcon(sel, (-16, 16), DI_SCREEN_RIGHT_TOP | DI_ITEM_CENTER, 1.0, (20, 20));
		if (sel.Amount > 1)
			DrawString(invFont, FormatNumber(sel.Amount), (-4, 24), DI_SCREEN_RIGHT_TOP | DI_TEXT_ALIGN_RIGHT, Font.CR_GOLD);
	}

	void DrawWeaponBoxes(DDShip ship)
	{
		int primary = ship.CurrentPrimary();
		Color green = COL_WEAPON;

		// Primary box (draw_weapon_info_sub).
		Pic(DD.PrimaryPicture(primary), 64, 154);
		String pname = DD.PrimaryName(primary);
		if (primary == DD.PW_SUPERLASER)
		{
			// Two words; Descent II splits it over two lines too.
			Array<String> words;
			pname.Split(words, " ");
			Txt(words[0], 87, 157, green);
			if (words.Size() > 1) Txt(words[1], 87, 163, green);
		}
		else
		{
			Txt(pname, 87, 157, green);
		}
		if (primary == DD.PW_LASER || primary == DD.PW_SUPERLASER)
		{
			int lvl = LaserLevel(ship, primary);
			double ly = primary == DD.PW_SUPERLASER ? 169 : 163;
			Txt(String.Format("%s: %d", StringTable.Localize("$DD_LVL"), lvl), 87, ly, green);
			if (ship.quadLasers) Txt(StringTable.Localize("$DD_QUAD"), 87, ly + 6, green);
		}
		else if (primary == DD.PW_VULCAN || primary == DD.PW_GAUSS)
		{
			int rounds = int(ship.CountInv('DDVulcanAmmo') * DD.VULCAN_AMMO_SCALE);
			Txt(String.Format("%05d", rounds), 93, 171, COL_AMMO);
		}
		else if (primary == DD.PW_OMEGA)
		{
			Txt(String.Format("%s: %d%%", StringTable.Localize("$DD_CHARGE"), int(ship.omegaCharge * 100)), 87, 165, green);
		}

		// Secondary box.
		int sec = ship.secondary;
		Pic(DD.SecondaryPicture(sec), 234, 154);
		String nm = DD.SecondaryName(sec);
		Txt(nm, 207, 157, green);
		Txt(String.Format("%03d", ship.CountInv(DD.SecondaryAmmo(sec))), 213, 171, COL_AMMO);
	}

	// The level the selected laser fires at (1-4, super laser 5-6).
	static int LaserLevel(DDShip ship, int primary)
	{
		int id = DDShip.PrimaryWeaponId(primary, ship.laserLevel);
		return id >= 30 ? id - 25 : id + 1;
	}

	// Without the cockpit: Descent's full-screen HUD readouts.
	void DrawMinimal(DDShip ship, bool showText)
	{
		if (!showText) return;
		SetupScale();
		int shields = max(CPlayer.health, 0);
		int energy = ship.CountInv('DDEnergy');
		int primary = ship.CurrentPrimary();

		Txt(String.Format("%s: %d", StringTable.Localize("$DD_ENERGY"), energy), 4, 186, COL_ENERGY, 1.3);
		Txt(String.Format("%s: %d", StringTable.Localize("$DD_SHIELD"), shields), 4, 178, COL_SHIELD, 1.3);

		String p = DD.PrimaryName(primary);
		if (primary == DD.PW_LASER || primary == DD.PW_SUPERLASER)
		{
			int lvl = LaserLevel(ship, primary);
			p = String.Format("%s %s %d%s", p, StringTable.Localize("$DD_LVL"), lvl,
				ship.quadLasers ? " " .. StringTable.Localize("$DD_QUAD") : "");
		}
		else if (primary == DD.PW_VULCAN || primary == DD.PW_GAUSS)
			p = String.Format("%s: %d", p, int(ship.CountInv('DDVulcanAmmo') * DD.VULCAN_AMMO_SCALE));
		else if (primary == DD.PW_OMEGA)
			p = String.Format("%s: %d%%", p, int(ship.omegaCharge * 100));
		if (ship.hasAfterburner)
			Txt(String.Format("BURN: %d%%", int(ship.afterburnerCharge * 100)), 4, 170, COL_ENERGY, 1.3);
		TxtRight(p, 316, 178, COL_WEAPON, 1.3);
		TxtRight(String.Format("%s: %d", DD.SecondaryName(ship.secondary), ship.CountInv(DD.SecondaryAmmo(ship.secondary))),
			316, 186, COL_WEAPON, 1.3);
	}

	// show_reticle(): the cross plus primary/secondary readiness markers.
	void DrawReticle(DDShip ship)
	{
		SetupScale();
		double now = ship.GameTime();
		int primary = ship.CurrentPrimary();
		bool primReady = now >= ship.primaryReadyTime && ship.HasPrimaryAmmo(primary);
		bool secReady = now >= ship.secondaryReadyTime && ship.CountInv(DD.SecondaryAmmo(ship.secondary)) > 0;

		int primaryBm = primReady ? 1 : 0;
		if (primaryBm && (primary == DD.PW_LASER || primary == DD.PW_SUPERLASER) && ship.quadLasers) primaryBm++;
		int secondaryBm = secReady ? 1 : 0;
		int sw = ship.secondary;
		bool twoGuns = sw == DD.SW_CONCUSSION || sw == DD.SW_HOMING || sw == DD.SW_FLASH
			|| sw == DD.SW_GUIDED || sw == DD.SW_MERCURY;
		if (!twoGuns)
			secondaryBm += 3;
		else if (secondaryBm && !(ship.missileGun & 1))
			secondaryBm++;
		int crossBm = (primaryBm > 0 || secondaryBm > 0) ? 1 : 0;

		double cx = 160, cy = 100;
		Pic(String.Format("DDRCRS%d", crossBm), cx - 4, cy - 2);
		Pic(String.Format("DDRPRI%d", primaryBm), cx - 15, cy + 6);
		Pic(String.Format("DDRSEC%d", secondaryBm), cx - 12, cy + 1);
	}
}
