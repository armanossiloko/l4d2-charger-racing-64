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
	bool charging;		//Whether or not the player is charging.
	float jumpdelay;	//The delay between jumps while charging.
	bool hud;			//Whether the hud should be shown or not.
	bool playing;		//Whether the player is playing or not.
	bool finished;		//Has this player finished the race?
	float time;			//How many precise seconds has it been since the race started?
	int spawnent;		//The entity index of the prop or bot being created.
	Statistics stats;	//Cached statistics for the player stored via cache.
	int cache_points;	//Cached points for the player stored via cache.
	float cache_time;	//Cached time for the player stored via cache.
	bool ready;			//Whether the player is ready or not for the next match.
	bool racing;		//Whether the player is actively racing or not.

	void Init(int client) {
		this.client = client;
		this.points = 0;
		this.currentnode = 0;
		this.SyncHud();
		this.speeds = new ArrayList();
		this.charging = false;
		this.jumpdelay = 0.0;
		this.hud = true;
		this.finished = false;
		this.time = 0.0;
		this.spawnent = -1;
		this.stats.Init();
		this.cache_points = 0;
		this.cache_time = 0.0;
		this.ready = false;
		this.racing = false;
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
		if (!this.hud || g_State.status == STATUS_NONE) {
			return;
		}

		char sBuffer[256];

		switch (g_State.mode) {
			case MODE_SINGLES: {
				int[] clients = new int[MaxClients];
				int[] scores = new int[MaxClients];

				int total = GetTopScores(MaxClients, clients, scores);

				char sTime[64]; int client;
				for (int i = 0; i < total; i++) {
					client = clients[i];
					FormatSeconds((g_Player[client].cache_time > 0) ? g_Player[client].cache_time : g_Player[client].GetTime(), sTime, sizeof(sTime), " (%M:%S)", true);
					Format(sBuffer, sizeof(sBuffer), "%s#%i: %N (%i)%s\n", sBuffer, i + 1, client, scores[i], (g_Player[client].racing || g_Player[client].finished) ? sTime : " (00:00)");
				}
			}

			case MODE_GROUPS: {
				int clients[5]; int scores[5];
				int total = GetTopScores(5, clients, scores);

				char sTime[64]; int client;
				for (int i = 0; i < total; i++) {
					client = clients[i];
					FormatSeconds((g_Player[client].cache_time > 0) ? g_Player[client].cache_time : g_Player[client].GetTime(), sTime, sizeof(sTime), " (%M:%S)", true);
					Format(sBuffer, sizeof(sBuffer), "%s#%i: %N (%i)%s\n", sBuffer, i + 1, client, scores[i], (g_Player[client].racing || g_Player[client].finished) ? sTime : " (00:00)");
				}
			}

			case MODE_TEAMS: {
				for (int i = 0; i < g_Groups.GetTotalGroups(); i++) {
					int score = GetGroupScore(i);
					Format(sBuffer, sizeof(sBuffer), "%sTeam: #%i (%i)\n", sBuffer, (i + 1), score);
				}
			}

			case MODE_GROUPTEAMS: {
				for (int i = 0; i < g_Groups.GetTotalGroups(); i++) {
					int score = GetGroupScore(i);
					Format(sBuffer, sizeof(sBuffer), "%sTeam: #%i (%i)\n", sBuffer, (i + 1), score);
				}
			}
		}

		GameRules_SetPropString("m_szScriptedHUDStringSet", sBuffer, false, 0);

		Panel panel = new Panel();
		char sTime[64];
		FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", true);
		char sTitle[256]; FormatEx(sTitle, sizeof(sTitle), "Leaderboard (Points: %i) (%s)", (g_Player[this.client].cache_points > 0) ? g_Player[this.client].cache_points : g_Player[this.client].points, sTime);
		panel.SetTitle(sTitle);
		panel.DrawText("----------------");
		if (g_State.status == STATUS_PREPARING) {
			panel.DrawText("Waiting to race...");
		} else {
			panel.DrawText(sBuffer);
		}
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
		if (this.time == 0.0) {
			return 0.0;
		}
		
		return GetGameTime() - this.time;
	}

	void Cache() {
		this.cache_points = this.points;
		this.cache_time = this.GetTime();
	}

	void Delete() {
		this.client = 0;
		this.points = 0;
		this.currentnode = 0;
		delete this.speeds;
		this.charging = false;
		this.jumpdelay = 0.0;
		this.hud = true;
		this.finished = false;
		this.time = 0.0;
		this.spawnent = -1;
		this.stats.Clear();
		this.cache_points = 0;
		this.cache_time = 0.0;
		this.ready = false;
		this.racing = false;
	}
}