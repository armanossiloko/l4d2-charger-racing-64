enum struct Statistics {
	int races;
	int wins;
	int losses;
	int totalpoints;

	void Init() {
		this.races = 0;
		this.wins = 0;
		this.losses = 0;
		this.totalpoints = 0;
	}

	void Clear() {
		this.races = 0;
		this.wins = 0;
		this.losses = 0;
		this.totalpoints = 0;
	}
}

enum struct Player {
	int client;			//The client index of the player.
	int points;			//How many points the player has accumulated throughout the race total.
	int currentnode;	//The current node the player is on in the track.
	ArrayList speeds;	//Helpful for calculating averages in order to give points.
	int team;			//The team the player is on if the mode is teams.
	bool charging;		//Whether or not the player is charging.
	float jumpdelay;	//The delay between jumps while charging.
	bool hud;			//Whether the hud should be shown or not.
	bool playing;		//Whether the player is playing or not.
	bool finished;		//Has this player finished the race?
	float time;			//How many precise seconds has it been since the race started?
	int spawnent;		//The entity index of the prop or bot being created.
	Statistics stats;	//Cached statistics for the player stored via cache.

	void Init(int client) {
		this.client = client;
		this.points = 0;
		this.currentnode = 0;
		this.SyncHud();
		this.speeds = new ArrayList();
		this.team = 0;
		this.charging = false;
		this.jumpdelay = 0.0;
		this.hud = true;
		this.finished = false;
		this.time = 0.0;
		this.spawnent = -1;
		this.stats.Init();
	}

	void SetPoints(int points) {
		this.points = points;
		this.SyncHud();
	}

	void AddPoints(int point) {
		this.points += point;
		this.SyncHud();

		g_Player[this.client].stats.totalpoints += point;
		IncrementStat(this.client, "totalpoints");
	}

	void RemovePoints(int point) {
		this.points -= point;

		if (this.points < 0) {
			this.points = 0;
		}

		this.SyncHud();
	}

	void Clear() {
		this.points = 0;
		this.currentnode = 0;
		this.SyncHud();
	}

	void SyncHud() {
		if (!this.hud) {
			return;
		}

		float x = -1.0;
		float y = -1.0;
		float holdTime = 99999.0;
		int red = 255;
		int green = 255;
		int blue = 255;
		int alpha = 255;
		int effect;
		float fxTime;
		float fadeIn;
		float fadeOut;

		SetHudTextParams(x, y, holdTime, red, green, blue, alpha, effect, fxTime, fadeIn, fadeOut);

		char sBuffer[256];

		switch (g_State.mode) {
			case MODE_SINGLES: {
				int[] clients = new int[MaxClients]; int[] scores = new int[MaxClients];
				int total = GetTopScores(MaxClients, clients, scores, true);
				for (int i = 0; i < total; i++) {
					Format(sBuffer, sizeof(sBuffer), "%s#%i: %N (%i)\n", sBuffer, i + 1, clients[i], scores[i]);
				}
			}

			case MODE_GROUPS: {
				int clients[5]; int scores[5];
				int total = GetTopScores(5, clients, scores);
				for (int i = 0; i < total; i++) {
					Format(sBuffer, sizeof(sBuffer), "%s#%i: %N (%i)\n", sBuffer, i + 1, clients[i], scores[i]);
				}
			}

			case MODE_TEAMS: {
				int score1 = GetChargerTeamScore(1);
				int score2 = GetChargerTeamScore(2);
				FormatEx(sBuffer, sizeof(sBuffer), "Team: #1 (%i)\nTeam: #2 (%i)", score1, score2);
			}

			case MODE_GROUPTEAMS: {

			}
		}

		GameRules_SetPropString("m_szScriptedHUDStringSet", sBuffer, false, 0);

		Panel panel = new Panel();
		char sTime[64];
		FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", true);
		char sTitle[256]; FormatEx(sTitle, sizeof(sTitle), "Leaderboard (Points: %i) (%s)", this.points, sTime);
		panel.SetTitle(sTitle);
		panel.DrawText("----------------");
		panel.DrawText(sBuffer);
		panel.Send(this.client, MenuAction_Void, MENU_TIME_FOREVER);
		delete panel;
	}

	void CacheSpeed() {
		float speed = GetSpeed(this.client);
		this.speeds.Push(speed);
	}

	float GetAverageSpeed() {
		int cached = this.speeds.Length;
		if (cached == 0) {
			return 0.0;
		}

		float total;
		for (int i = 0; i < cached; i++) {
			total += this.speeds.Get(i);
		}

		if (total == 0.0) {
			return 0.0;
		}

		float average = total / float(cached);

		return average;
	}

	float GetTime() {
		return GetGameTime() - this.time;
	}

	void Delete() {
		this.client = 0;
		this.points = 0;
		this.currentnode = 0;
		delete this.speeds;
		this.team = 0;
		this.charging = false;
		this.jumpdelay = 0.0;
		this.hud = true;
		this.finished = false;
		this.time = 0.0;
		this.spawnent = -1;
		this.stats.Clear();
	}
}