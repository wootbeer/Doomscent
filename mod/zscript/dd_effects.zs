// Doomscent - animated Descent "vclip" effects (explosions, muzzle flashes,
// impacts).  The sprites come from dd_descent_assets.pk3 as DXnn, one sprite
// per vclip with frames A, B, C...

class DDVclip abstract
{
	// Frame count and seconds per frame of the vclips we use (from the
	// Vclip[] table in DESCENT.PIG).
	static int, double Info(int vclip)
	{
		switch (vclip)
		{
			case 0:  return 17, 0.059;
			case 1:  return 5, 0.1;
			case 2:  return 9, 0.056;
			case 3:  return 10, 0.1;
			case 5:  return 12, 0.062;
			case 7:  return 17, 0.053;
			case 9:  return 5, 0.1;
			case 11: return 3, 0.1;
			case 12: return 3, 0.133;
			case 14: return 3, 0.1;
			case 15: return 3, 0.1;
			case 21: return 5, 0.1;
			case 22: return 5, 0.1;
			case 23: return 5, 0.1;
			case 30: return 5, 0.1;
			case 31: return 5, 0.1;
			case 32: return 5, 0.1;
			case 53: return 10, 0.05;
			case 54: return 6, 0.125;
			case 55: return 5, 0.1;
			case 56: return 5, 0.1;
			case 58: return 17, 0.052;
			case 59: return 5, 0.1;
			case 60: return 11, 0.079;
			case 63: return 13, 0.038;
			case 64: return 5, 0.1;
			case 65: return 10, 0.04;
		}
		return 0, 0.1;
	}

	// Scale that makes the vclip's first frame 'diameter' map units wide.
	static double ScaleFor(int vclip, double diameter)
	{
		TextureID tex = TexMan.CheckForTexture(String.Format("DX%02dA0", vclip), TexMan.Type_Sprite);
		if (!tex.IsValid()) return 1;
		int w, h;
		[w, h] = TexMan.GetSize(tex);
		if (w <= 0) return 1;
		return diameter / w;
	}
}

class DDEffect : Actor
{
	int vclip;
	int numFrames;
	double frameTime;
	double age;
	Actor followActor;
	Vector3 followOffset;

	Default
	{
		Radius 1;
		Height 1;
		RenderStyle "Normal";
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
		TNT1 A -1;
		Stop;
	}

	// size = radius in map units, as Descent sizes are radii.
	void Setup(int vc, double size)
	{
		vclip = vc;
		[numFrames, frameTime] = DDVclip.Info(vc);
		if (numFrames <= 0)
		{
			Destroy();
			return;
		}
		sprite = GetSpriteIndex(String.Format("DX%02d", vc));
		frame = 0;
		double s = DDVclip.ScaleFor(vc, size * 2);
		Scale = (s, s);
		// Descent explosions cast light; give the big ones a dynamic light.
		if (size >= 12)
			A_AttachLight('fx', DynamicLight.PointLight, Color(255, 200, 120), int(size * 3), 0);
	}

	override void Tick()
	{
		if (IsFrozen()) return;
		if (followActor != null)
			SetOrigin(followActor.pos + followOffset, true);
		age += DD.TIC;
		int f = int(age / frameTime);
		if (f >= numFrames)
		{
			Destroy();
			return;
		}
		frame = f;
	}

	static DDEffect Make(Vector3 at, int vclip, double size)
	{
		if (vclip < 0) return null;
		let fx = DDEffect(Actor.Spawn('DDEffect', at, ALLOW_REPLACE));
		if (fx) fx.Setup(vclip, size);
		return fx;
	}
}

// Never spawned.  GZDoom only knows sprite names that appear in some
// actor's states, so list every vclip sprite DDEffect looks up by name.
class DDSpriteNames : Actor abstract
{
	States
	{
	Spawn:
		DX00 A 0;
		DX01 A 0;
		DX02 A 0;
		DX03 A 0;
		DX05 A 0;
		DX07 A 0;
		DX09 A 0;
		DX11 A 0;
		DX12 A 0;
		DX14 A 0;
		DX15 A 0;
		DX21 A 0;
		DX22 A 0;
		DX23 A 0;
		DX30 A 0;
		DX31 A 0;
		DX32 A 0;
		DX53 A 0;
		DX54 A 0;
		DX55 A 0;
		DX56 A 0;
		DX58 A 0;
		DX59 A 0;
		DX60 A 0;
		DX63 A 0;
		DX64 A 0;
		DX65 A 0;
		Stop;
	}
}
