// Ick Mode (dd_ickmode): every monster wears the same face (ICKF, made by
// ddconvert from data/ickface.png or its built-in face), scaled to the
// monster's own sprite.  Monsters bleed green and warp out when they die
// instead of leaving a corpse.

// Only lends its green blood colour (see CopyBloodColor).
class DDIckBloodDonor : Actor
{
	Default
	{
		BloodColor "30 D0 30";
	}
}

// Carried by every monster Ick Mode has touched.  Hides the monster's own
// sprite while Ick Mode is on, keeps a warped-out corpse hidden, and puts
// everything back when Ick Mode is turned off.
class DDIckToken : Inventory
{
	int savedStyle;
	double savedAlpha;
	bool warped;

	Default
	{
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.UNCLEARABLE
		Inventory.MaxAmount 1;
	}

	static DDIckToken Get(Actor mo)
	{
		let t = DDIckToken(mo.FindInventory('DDIckToken'));
		if (t == null)
		{
			t = DDIckToken(mo.GiveInventoryType('DDIckToken'));
			if (t)
			{
				t.savedStyle = mo.GetRenderStyle();
				t.savedAlpha = mo.Alpha;
			}
		}
		return t;
	}

	override void DoEffect()
	{
		Super.DoEffect();
		if (owner == null) return;
		bool alive = owner.health > 0;
		if (alive) warped = false;
		if (!warped && !dd_ickmode)
		{
			// Back to normal.
			owner.A_SetRenderStyle(savedAlpha, savedStyle);
			owner.CopyBloodColor(GetDefaultByType(owner.GetClass()));
			Destroy();
			return;
		}
		// The monster may change its own style (spectres, ghosts, wraiths
		// fading in); remember the latest for its face and for restoring.
		int st = owner.GetRenderStyle();
		if (st != STYLE_None)
		{
			savedStyle = st;
			savedAlpha = owner.Alpha;
			owner.A_SetRenderStyle(owner.Alpha, STYLE_None);
		}
	}
}

class DDIckFace : Actor
{
	DDIckToken token;
	double warpTime;

	Default
	{
		Radius 1;
		Height 1;
		RenderStyle "Normal";
		+NOBLOCKMAP
		+NOGRAVITY
		+NOINTERACTION
		+DONTSPLASH
		+NOTONAUTOMAP
	}

	States
	{
	Spawn:
		ICKF A -1;
		Stop;
	}

	static bool Wanted(Actor mo)
	{
		return mo != null && mo.bIsMonster && mo.health > 0 && mo.player == null;
	}

	static void Attach(Actor mo)
	{
		let tok = DDIckToken.Get(mo);
		if (tok == null) return;
		let f = DDIckFace(Spawn('DDIckFace', mo.pos, NO_REPLACE));
		if (f == null) return;
		f.master = mo;
		f.token = tok;
		f.FitTo(mo);
		f.Follow();
		f.ClearInterpolation();
		mo.CopyBloodColor(GetDefaultByType('DDIckBloodDonor'));
	}

	// Scale the face to the monster's own (spawn) sprite, so big monsters
	// get big faces, wide ones wide faces and so on.
	void FitTo(Actor mo)
	{
		int fw = 64, fh = 64;
		TextureID face = TexMan.CheckForTexture("ICKFA1", TexMan.Type_Sprite);
		if (face.IsValid())
			[fw, fh] = TexMan.GetSize(face);
		double w = mo.Radius * 2, h = mo.Height;
		if (mo.SpawnState)
		{
			TextureID tex;
			bool flip;
			Vector2 sc;
			[tex, flip, sc] = mo.SpawnState.GetSpriteTexture(0);
			if (tex.IsValid())
			{
				int tw, th;
				[tw, th] = TexMan.GetSize(tex);
				if (th > 4)
				{
					w = tw * abs(mo.Scale.X);
					h = th * abs(mo.Scale.Y);
				}
			}
		}
		double sy = max(h, 16) / fh;
		double sx = clamp(w / fw, sy * 0.7, sy * 1.6);
		Scale = (sx, sy);
	}

	void Follow()
	{
		SetOrigin(master.pos, false);
		Prev = master.Prev;
		Angle = master.Angle;
		Floorclip = master.Floorclip;
		bInvisible = master.bInvisible;
		if (token)
		{
			int st = token.savedStyle;
			if (GetRenderStyle() != st || Alpha != token.savedAlpha)
				A_SetRenderStyle(token.savedAlpha, st);
		}
	}

	override void Tick()
	{
		if (IsFrozen()) return;
		if (warpTime > 0)
		{
			// Beam out: squeeze sideways, stretch up and fade.
			warpTime += 1;
			Scale.X *= 0.72;
			Scale.Y *= 1.06;
			Alpha -= 0.07;
			if (Alpha <= 0 || warpTime > 16) Destroy();
			return;
		}
		if (master == null || !dd_ickmode || token == null || token.owner != master)
		{
			Destroy();
			return;
		}
		if (master.health <= 0)
		{
			WarpOut();
			return;
		}
		Follow();
	}

	void WarpOut()
	{
		token.warped = true;
		Vector3 mid = master.pos + (0, 0, master.Height / 2);
		DDEffect.Make(mid, 61, max(master.Radius, master.Height / 2) * 1.2);
		A_StartSound("ddvclip/61", CHAN_BODY);
		Follow();
		master = null;
		A_SetRenderStyle(1, STYLE_Add);
		bBright = true;
		warpTime = 1;
	}
}
