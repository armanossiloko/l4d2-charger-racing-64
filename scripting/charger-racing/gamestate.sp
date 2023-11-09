enum struct GameState {
	int track;		//The track that is currently being used.
	Status status;	//Status of the mode.
	Modes mode;		//Mode to use.
	int countdown;	//Countdown from 3 to GO!
	float timer;	//Timer while the race is active.
	Handle ticker;	//The ticker to handle the race algorithm as a while.
	bool paused;	//Whether the timer is paused or not.
	int rounds;		//How many rounds have been played.
	int group;		//The current group that is racing.

	void Init() {
		this.track = NO_TRACK;
		this.status = STATUS_NONE;
		this.mode = MODE_SINGLES;
		this.countdown = 0;
		this.timer = 0.0;
		this.ticker = null;
		this.paused = false;
		this.rounds = 0;
		this.group = 0;
	}

	void Preparing(int stage) {
		#if defined DEBUG
		PrintToServer("Starting the preparation phase [%i]...", stage);
		#endif

		this.status = STATUS_PREPARING;
		g_API.Call_OnStatusChange(this.status);

		this.timer = convar_Preparation_Timer.FloatValue;
		StopTimer(this.ticker);
		this.ticker = CreateTimer(1.0, Timer_Tick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

		SpawnObjects();
		KickBots();
		CreateTrackEnts();
	}

	void Ready(bool popqueue) {
		this.status = STATUS_READY;
		g_API.Call_OnStatusChange(this.status);

		this.countdown = convar_Racing_Countdown.IntValue;
		this.timer = convar_Racing_Timer.FloatValue;

		if (popqueue) {
			this.PopQueue(false);
		}

		SpawnObjects();
		KickBots();
		CreateTrackEnts();

		//Run code a frame after ready starts, mostly used to stop compile errors.
		RequestFrame(Frame_DelayReady);
	}

	void Racing() {
		this.status = STATUS_RACING;
		g_API.Call_OnStatusChange(this.status);

		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
				continue;
			}

			SetEntityMoveType(i, MOVETYPE_WALK);
			SetEntProp(i, Prop_Send, "m_CollisionGroup", 0);
		}
	}

	void Finish() {
		this.status = STATUS_FINISHED;
		g_API.Call_OnStatusChange(this.status);
		this.rounds++;

		//Run code a frame after the race finishes, mostly used to stop compile errors.
		RequestFrame(Frame_DelayFinish);

		StopTimer(this.ticker);
		this.paused = false;
		float preparation = convar_Preparation_Delay.FloatValue;

		if (convar_Rounds.IntValue > 0 && this.rounds >= convar_Rounds.IntValue) {
			//InitiateMapChooserVote(MapChange_Instant);
			//CPrintToChatAll("%s%t", PLUGIN_TAG, "prepare post match map change");
			CreateTimer(preparation, Timer_Prepare, _, TIMER_FLAG_NO_MAPCHANGE);
			CPrintToChatAll("%s%t", PLUGIN_TAG, "prepare post match", RoundFloat(preparation));
		} else {
			CreateTimer(preparation, Timer_Prepare, _, TIMER_FLAG_NO_MAPCHANGE);
			CPrintToChatAll("%s%t", PLUGIN_TAG, "prepare post match", RoundFloat(preparation));
		}
	}

	void None(int stage) {
		#if defined DEBUG
		PrintToServer("State set to none [%i]...", stage);
		#endif

		this.status = STATUS_NONE;
		g_API.Call_OnStatusChange(this.status);

		this.countdown = 0;
		this.timer = 0.0;
		StopTimer(this.ticker);
		this.paused = false;
	}

	void SetupGroups() {
		g_Groups.Clear();
		this.group = 0;
		
		switch (this.mode) {
			case MODE_SINGLES, MODE_GROUPS: {
				for (int i = 1; i <= MaxClients; i++) {
					if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
						continue;
					}

					g_Groups.AddPlayer(i);
					CPrintToChat(i, "%s%T", PLUGIN_TAG, "added to slot queue", i, i);
				}
			}
			case MODE_TEAMS, MODE_GROUPTEAMS: {
				int totalplayers = GetTotalPlayers();
				float ratio = convar_Ratio.FloatValue;
				int players = RoundToCeil(totalplayers * ratio);
				int teams = totalplayers / players;

				int clients[MAXPLAYERS];
				int total;

				for (int i = 0; i < teams; i++) {
					total = 0;

					for (int x = 0; x < players; x++) {
						if ((clients[total++] = FindAvailablePlayer()) == -1) {
							break;
						}
						CPrintToChat(clients[total], "%s%T", PLUGIN_TAG, "added to group queue", clients[total], i);
					}

					g_Groups.AddGroup(clients, total);
				}
			}
		}
	}

	void PopQueue(bool ready) {		
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i)) {
				continue;
			}

			ChangeClientTeam(i, view_as<int>(L4D_TEAM_SPECTATOR));
		}

		int[] players = new int[MaxClients];
		int client;

		switch (this.mode) {
			case MODE_SINGLES, MODE_TEAMS: {
				//One at a time.
				g_Groups.GetGroupMembers(this.group, players);
				this.group++;

				for (int j = 0; j < MaxClients; j++) {
					if ((client = players[j]) == 0) {
						continue;
					}

					CPrintToChat(client, "%s%T", PLUGIN_TAG, "you're up", client);

					ChangeClientTeam(client, view_as<int>(L4D_TEAM_INFECTED));
					L4D_RespawnPlayer(client);
				}
			}
			case MODE_GROUPS, MODE_GROUPTEAMS: {
				//All at once.
				for (int i = 0; i < g_Groups.GetTotalGroups(); i++) {
					g_Groups.GetGroupMembers(i, players);

					for (int j = 0; j < MaxClients; j++) {
						if ((client = players[j]) == 0) {
							continue;
						}

						CPrintToChat(client, "%s%T", PLUGIN_TAG, "you're up for team", client);

						ChangeClientTeam(client, view_as<int>(L4D_TEAM_INFECTED));
						L4D_RespawnPlayer(client);
					}
				}
			}
		}

		float origin[3]; float origin2[3]; bool teleport;
		if (this.track != NO_TRACK) {
			g_Tracks[this.track].GetNodeOrigin(0, origin); //0 = Start
			teleport = true;

			g_Tracks[this.track].GetNodeOrigin(1, origin2); //1 = First node
		}

		//Teleport the players to the starting line and freeze them in place.
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsFakeClient(i)) {
				continue;
			}

			if (teleport) {
				#if defined DEBUG
				PrintToServer("%N teleported to the starting node.", i);
				#endif
					
				TeleportEntity(i, origin, NULL_VECTOR, NULL_VECTOR);
				LookAtPoint(i, origin2);
			} else {
				#if defined DEBUG
				PrintToServer("%N teleported to a survivor position.", i);
				#endif

				TeleportToSurvivorPos(i);
			}

			SetEntityMoveType(i, MOVETYPE_NONE);
			SetEntProp(i, Prop_Send, "m_CollisionGroup", 0);
		}

		if (ready) {
			#if defined DEBUG
			PrintToServer("ready");
			#endif

			this.Ready(false);
		}
	}
}

void OpenModesMenu(int client) {
	Menu menu = new Menu(MenuHandler_Modes);
	menu.SetTitle("Select a mode:");

	menu.AddItem("Players", "Players");
	menu.AddItem("Groups", "Groups");
	menu.AddItem("Teams", "Teams");
	menu.AddItem("GroupTeams", "Group Teams");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Modes(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			Modes mode;
			if (StrEqual(sInfo, "Players")) {
				mode = MODE_SINGLES;
			} else if (StrEqual(sInfo, "Groups")) {
				mode = MODE_GROUPS;
			} else if (StrEqual(sInfo, "Teams")) {
				mode = MODE_TEAMS;
			} else if (StrEqual(sInfo, "GroupTeams")) {
				mode = MODE_GROUPTEAMS;
			}

			if (SetMode(mode)) {
				CPrintToChat(param1, "%s%T", PLUGIN_TAG, "mode set successfully", param1);
			} else {
				CPrintToChat(param1, "%s%T", PLUGIN_TAG, "mode set failure", param1);
			}

			OpenModesMenu(param1);
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

bool SetMode(Modes mode) {
	if (mode < MODE_SINGLES || mode > MODE_TEAMS) {
		return false;
	}

	char sName[64];
	GetModeName(mode, sName, sizeof(sName));

	g_State.mode = mode;
	g_API.Call_OnModeSet(g_State.mode);

	CPrintToChatAll("%s%t", PLUGIN_TAG, "mode set to", sName);

	return true;
}

void GetModeName(Modes mode, char[] buffer, int size) {
	switch (mode) {
		case MODE_SINGLES: {
			strcopy(buffer, size, "Singles");
		}
		case MODE_GROUPS: {
			strcopy(buffer, size, "Groups");
		}
		case MODE_TEAMS: {
			strcopy(buffer, size, "Teams");
		}
		case MODE_GROUPTEAMS: {
			strcopy(buffer, size, "Group Teams");
		}
	}
}

Modes GetMode(const char[] name) {
	char buffer[64];
	for (Modes i = MODE_SINGLES; i <= MODE_GROUPTEAMS; i++) {
		GetModeName(i, buffer, sizeof(buffer));
		if (StrEqual(name, buffer)) {
			return i;
		}
	}
	return view_as<Modes>(-1);
}

bool SetStatus(Status status) {
	switch (status) {
		case STATUS_NONE: {
			g_State.status = STATUS_NONE;
			g_API.Call_OnStatusChange(g_State.status);
			return true;
		}
		case STATUS_PREPARING: {
			if (g_State.status == STATUS_NONE) {
				g_State.Preparing(1);
				g_API.Call_OnStatusChange(g_State.status);
				return true;
			}
			return false;
		}
		case STATUS_READY: {
			if (g_State.status == STATUS_PREPARING) {
				g_State.SetupGroups();
				g_State.Ready(true);
				g_API.Call_OnStatusChange(g_State.status);
				return true;
			}
			return false;
		}
		case STATUS_RACING: {
			if (g_State.status == STATUS_READY) {
				g_State.Racing();
				g_API.Call_OnStatusChange(g_State.status);
				return true;
			}
			return false;
		}
		case STATUS_FINISHED: {
			if (g_State.status == STATUS_RACING) {
				g_State.Finish();
				g_API.Call_OnStatusChange(g_State.status);
				return true;
			}
			return false;
		}
	}

	return false;
}

void EndRace() {
	CPrintToChatAll("%s%t", PLUGIN_TAG, "race finished print");

	char sTime[64];
	for (int i = 1; i <= MaxClients; i++) {
		if (g_Player[i].playing) {
			FormatSeconds(g_Player[i].GetTime(), sTime, sizeof(sTime), "%M:%S", true);
			PrintHintTextToAll("%s%T", PLUGIN_TAG_NOCOLOR, "race finished with time center", i, sTime);
		} else {
			PrintHintTextToAll("%s%T", PLUGIN_TAG_NOCOLOR, "race finished center", i);
		}
	}

	g_State.Finish();
	g_API.Call_OnEndRace();
}