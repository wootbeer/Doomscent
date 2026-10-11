// Doomscent - the Descent cockpit.
//
// Everything is laid out in Descent's 320x200 cockpit coordinates (taken
// from GAUGES.C) and stretched to the screen, as Descent's own ports do.

class DDStatusBar : BaseStatusBar
{
	TextureID texCockpit;
	Font hudFont;

	override void Init()
	{
		Super.Init();
		// Height 0: never shrink the 3D view for a status bar.
		SetSize(0, 320, 200);
		texCockpit = TexMan.CheckForTexture("DDCOCKPT", TexMan.Type_Any);
		hudFont = SmallFont;
	}

	override void Draw(int state, double ticFrac)
	{
		Super.Draw(state, ticFrac);
		if (CPlayer == null || CPlayer.mo == null) return;
		if (automapactive) return;
		let ship = DDShip(CPlayer.mo);
		if (ship == null) return;
		if (CPlayer.playerstate != PST_LIVE) return;
		if (CPlayer.camera != CPlayer.mo) return;

		bool cockpit = CVar.GetCVar('dd_cockpit', CPlayer).GetBool() && texCockpit.IsValid() && state != HUD_None;
		if (cockpit)
			DrawCockpit(ship);
		else
			DrawMinimal(ship, state != HUD_None);
		DrawReticle(ship);

		// Without mouselook the mouse moves the ship instead of aiming it.
		if (!CVar.GetCVar('freelook', CPlayer).GetBool())
		{
			SetupScale();
			String msg = StringTable.Localize("$DD_FREELOOK");
			Txt(msg, 160 - hudFont.StringWidth(msg) * 0.35, 20, Font.CR_YELLOW, 0.7);
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

	void Pic(String name, double x, double y, double clipL = -1, double clipR = -1)
	{
		TextureID t = TexMan.CheckForTexture(name, TexMan.Type_Any);
		if (!t.IsValid()) return;
		int w, h;
		[w, h] = TexMan.GetSize(t);
		double cl = clipL >= 0 ? x + clipL : x;
		double cr = clipR >= 0 ? x + clipR : x + w;
		Screen.DrawTexture(t, false, x * sx, y * sy,
			DTA_DestWidthF, w * sx, DTA_DestHeightF, h * sy,
			DTA_TopOffset, 0, DTA_LeftOffset, 0,
			DTA_ClipLeft, int(cl * sx), DTA_ClipRight, int(cr * sx));
	}

	void Txt(String s, double x, double y, int color, double scale = 0.55)
	{
		Screen.DrawText(hudFont, color, x * sx, y * sy, s,
			DTA_ScaleX, sx * scale, DTA_ScaleY, sy * scale);
	}

	void TxtRight(String s, double right, double y, int color, double scale = 0.55)
	{
		double w = hudFont.StringWidth(s) * scale;
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
		int notEnergy = 61 - (min(energy, 100) * 61) / 100;
		Pic("DDENRGL", 70, 131, notEnergy, -1);
		Pic("DDENRGR", 190, 131, -1, 64 - notEnergy);

		// Numerical readout (draw_numerical_display).
		Pic("DDNUMER", 154, 130);
		TxtRight(String.Format("%d", energy), 154 + 16, 131.5, Font.CR_ORANGE);
		TxtRight(String.Format("%d", shields), 154 + 16, 144.5, Font.CR_LIGHTBLUE);

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

		// Keys (draw_keys).
		Pic(HasKey('BlueCard', 'BlueSkull') ? "DDKEYB" : "DDKEYB0", 45, 152);
		Pic(HasKey('YellowCard', 'YellowSkull') ? "DDKEYY" : "DDKEYY0", 44, 162);
		Pic(HasKey('RedCard', 'RedSkull') ? "DDKEYR" : "DDKEYR0", 43, 172);

		// Homing warning light.
		Pic(ship.homingWarning > 0 && (Level.maptime & 4) ? "DDHOMON" : "DDHOMOF", 7, 171);

		DrawWeaponBoxes(ship);
	}

	bool HasKey(Name card, Name skull)
	{
		return CPlayer.mo.FindInventory(card) != null || CPlayer.mo.FindInventory(skull) != null;
	}

	void DrawWeaponBoxes(DDShip ship)
	{
		int primary = ship.CurrentPrimary();
		static const String ppics[] = { "DDWLASR", "DDWVULC", "DDWSPRD", "DDWPLAS", "DDWFUSN" };
		static const String pnames[] = { "$DD_LASER", "$DD_VULCAN", "$DD_SPREADFIRE", "$DD_PLASMA", "$DD_FUSION" };
		int green = Font.CR_GREEN;

		// Primary box (draw_weapon_info_sub).
		Pic(ppics[primary], 64, 154);
		Txt(StringTable.Localize(pnames[primary]), 87, 157, green);
		if (primary == DD.PW_LASER)
		{
			Txt(String.Format("%s: %d", StringTable.Localize("$DD_LVL"), ship.laserLevel + 1), 87, 163, green);
			if (ship.quadLasers) Txt(StringTable.Localize("$DD_QUAD"), 87, 169, green);
		}
		else if (primary == DD.PW_VULCAN)
		{
			int rounds = int(ship.CountInv('DDVulcanAmmo') * DD.VULCAN_AMMO_SCALE);
			Txt(String.Format("%05d", rounds), 93, 171, Font.CR_RED);
		}

		// Secondary box.
		int sec = ship.secondary;
		Pic(DD.SecondaryPicture(sec), 234, 154);
		String nm = DD.SecondaryName(sec);
		Txt(nm, 207, 157, green);
		Txt(String.Format("%03d", ship.CountInv(DD.SecondaryAmmo(sec))), 213, 171, Font.CR_RED);
	}

	// Without the cockpit: Descent's full-screen HUD readouts.
	void DrawMinimal(DDShip ship, bool showText)
	{
		if (!showText) return;
		SetupScale();
		int shields = max(CPlayer.health, 0);
		int energy = ship.CountInv('DDEnergy');
		int primary = ship.CurrentPrimary();
		static const String pnames[] = { "$DD_LASER", "$DD_VULCAN", "$DD_SPREADFIRE", "$DD_PLASMA", "$DD_FUSION" };

		Txt(String.Format("%s: %d", StringTable.Localize("$DD_ENERGY"), energy), 4, 186, Font.CR_ORANGE, 0.7);
		Txt(String.Format("%s: %d", StringTable.Localize("$DD_SHIELD"), shields), 4, 178, Font.CR_LIGHTBLUE, 0.7);

		String p = StringTable.Localize(pnames[primary]);
		if (primary == DD.PW_LASER)
			p = String.Format("%s %s %d%s", p, StringTable.Localize("$DD_LVL"), ship.laserLevel + 1,
				ship.quadLasers ? " " .. StringTable.Localize("$DD_QUAD") : "");
		else if (primary == DD.PW_VULCAN)
			p = String.Format("%s: %d", p, int(ship.CountInv('DDVulcanAmmo') * DD.VULCAN_AMMO_SCALE));
		TxtRight(p, 316, 178, Font.CR_GREEN, 0.7);
		TxtRight(String.Format("%s: %d", DD.SecondaryName(ship.secondary), ship.CountInv(DD.SecondaryAmmo(ship.secondary))),
			316, 186, Font.CR_GREEN, 0.7);

		int kx = 4;
		static const Name cards[] = { 'BlueCard', 'YellowCard', 'RedCard' };
		static const Name skulls[] = { 'BlueSkull', 'YellowSkull', 'RedSkull' };
		static const String icons[] = { "DDKICB", "DDKICY", "DDKICR" };
		for (int i = 0; i < 3; i++)
		{
			if (HasKey(cards[i], skulls[i]))
			{
				Pic(icons[i], kx, 4);
				kx += 10;
			}
		}
	}

	// show_reticle(): the cross plus primary/secondary readiness markers.
	void DrawReticle(DDShip ship)
	{
		SetupScale();
		double now = Level.maptime * DD.TIC;
		int primary = ship.CurrentPrimary();
		bool primReady = now >= ship.primaryReadyTime && ship.HasPrimaryAmmo(primary);
		bool secReady = now >= ship.secondaryReadyTime && ship.CountInv(DD.SecondaryAmmo(ship.secondary)) > 0;

		int primaryBm = primReady ? 1 : 0;
		if (primaryBm && primary == DD.PW_LASER && ship.quadLasers) primaryBm++;
		int secondaryBm = secReady ? 1 : 0;
		if (ship.secondary != DD.SW_CONCUSSION && ship.secondary != DD.SW_HOMING)
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
