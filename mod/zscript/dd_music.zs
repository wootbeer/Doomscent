// dd_music: play Descent's songs (DDGAMEnn in the asset pack) instead of
// the map's own music, and put the map's music back when it's turned off.
// Static so it keeps running between levels.

class DDMusicHandler : StaticEventHandler
{
	int numSongs;
	ui String playing;  // the Descent song we started, or ""

	override void OnRegister()
	{
		numSongs = 0;
		while (Wads.CheckNumForName(String.Format("DDGAME%02d", numSongs + 1), Wads.ns_music) >= 0)
			numSongs++;
	}

	// Like Descent, levels cycle through the songs.
	ui String LevelSong()
	{
		if (numSongs <= 0) return "";
		int n = max(Level.levelnum, 1);
		return String.Format("DDGAME%02d", (n - 1) % numSongs + 1);
	}

	override void UiTick()
	{
		let cv = CVar.GetCVar('dd_music', players[consoleplayer]);
		bool on = cv && cv.GetBool();
		String want = "";
		if (on)
		{
			if (gamestate == GS_LEVEL)
				want = LevelSong();
			else if (gamestate == GS_INTERMISSION && Wads.CheckNumForName("DDENDLEV", Wads.ns_music) >= 0)
				want = "DDENDLEV";
		}
		if (want != "")
		{
			// Start it, and again if something else (a new map, a script)
			// changed the music since.
			if (playing != want || (musplaying.name != "" && !(musplaying.name ~== want)))
			{
				S_ChangeMusic(want);
				playing = want;
			}
		}
		else if (playing != "")
		{
			// Turned off: back to the map's own music if ours is playing.
			if (gamestate == GS_LEVEL && (musplaying.name == "" || musplaying.name ~== playing))
				S_ChangeMusic(Level.Music, Level.musicorder);
			playing = "";
		}
	}
}
