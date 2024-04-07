enum struct GameState {
	int track;		//The track that is currently being used.
	int nexttrack;	//The track that will be used next.
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
		this.nexttrack = NO_TRACK;
		this.status = STATUS_NONE;
		this.mode = MODE_SINGLES;
		this.countdown = 0;
		this.timer = 0.0;
		this.ticker = null;
		this.paused = false;
		this.rounds = 0;
		this.group = 0;
	}

	void Preparing() {
		this.status = STATUS_PREPARING;
		g_API.Call_OnStatusChange(this.status);

		this.timer = convar_Preparation_Timer.FloatValue;
		StopTimer(this.ticker);
		this.ticker = CreateTimer(1.0, Timer_Tick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

		ClearEntities();

		if (g_TotalTracks > 0 && g_State.track == NO_TRACK) {
			SetTrack(0, false);
		}

		for (int i = 1; i <= MaxClients; i++) {
			g_BotType[i] = BotType_Normal;
			g_BotOrigin[i] = NULL_VECTOR;
			g_IsTemporarySurvivor[i] = false;

			if (IsClientInGame(i) && !IsFakeClient(i)) {
				if (g_Player[i].playing) {
					L4D_ChangeClientTeam(i, L4DTeam_Infected);
					L4D_RespawnPlayer(i);
				}
			}

			g_Player[i].playing = false;
			g_Player[i].finished = false;
			g_Player[i].time = 0.0;
			g_Player[i].points = 0;
			g_Player[i].currentnode = 0;
			g_Player[i].cache_points = 0;
			g_Player[i].cache_time = 0.0;
			g_Player[i].ready = false;
		}

		if (this.nexttrack != NO_TRACK) {
			SetTrack(this.nexttrack, false);
			this.nexttrack = NO_TRACK;
		}
	}

	void StartRace() {
		g_State.SetupGroups();

		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
				continue;
			}

			if (!g_Player[i].ready) {
				if (L4D_GetClientTeam(i) != L4DTeam_Spectator) {
					L4D_ChangeClientTeam(i, L4DTeam_Spectator);
				}

				PrintToClient(i, "%T", "not ready moved to spec", i);
				continue;
			}

			g_Player[i].ready = false;
			g_Player[i].playing = true;
			g_Player[i].finished = false;
			g_Player[i].time = GetGameTime();
			g_API.Call_OnPlayerStart(i);
		}

		g_State.PopQueue(true);
		g_API.Call_OnStartRace();
	}

	void EndRace() {
		if (this.status == STATUS_FINISHED) {
			return;
		}

		PrintToClients("%t", "race finished print");

		char sTime[64];
		for (int i = 1; i <= MaxClients; i++) {
			if (g_Player[i].playing) {
				FormatSeconds(g_Player[i].GetTime(), sTime, sizeof(sTime), "%M:%S", true);
				PrintHintTextToClients("%T", "race finished with time center", i, sTime);
			} else {
				PrintHintTextToClients("%T", "race finished center", i);
			}
		}

		g_State.Finish();
		g_API.Call_OnEndRace();
	}

	void Ready() {
		this.status = STATUS_READY;
		g_API.Call_OnStatusChange(this.status);

		this.countdown = convar_Racing_Countdown.IntValue;
		this.timer = convar_Racing_Timer.FloatValue;

		ClearEntities(false);
		CreatePathNodes();
		CreateTrackObjects();
		HandleTemporaryBots();
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

			g_Player[i].stats.races++;
			IncrementStat(i, "races");

			g_Player[i].points = 0;
			g_Player[i].cache_points = 0;
			g_Player[i].time = GetGameTime();
			g_Player[i].cache_time = 0.0;
			g_Player[i].racing = true;
		}
	}

	bool IsFinished() {
		for (int i = 1; i <= MaxClients; i++) {
			if (g_Player[i].playing && !g_Player[i].finished && !IsFakeClient(i)) {
				return false;
			}
		}

		return true;
	}

	void Finish() {
		this.status = STATUS_FINISHED;
		g_API.Call_OnStatusChange(this.status);
		this.rounds++;

		PrintHintTextToClients("%t", "match is ending");

		//Run code a frame after the race finishes, mostly used to stop compile errors.
		RequestFrame(Frame_DelayFinish);

		StopTimer(this.ticker);
		this.paused = false;
		float preparation = convar_Preparation_Delay.FloatValue;

		if (convar_Rounds.IntValue > 0 && this.rounds >= convar_Rounds.IntValue) {
			//InitiateMapChooserVote(MapChange_Instant);
			//PrintToClients("%t", "prepare post match map change");
			CreateTimer(preparation, Timer_Prepare, _, TIMER_FLAG_NO_MAPCHANGE);
			PrintToClients("%t", "prepare post match", RoundFloat(preparation));
		} else {
			CreateTimer(preparation, Timer_Prepare, _, TIMER_FLAG_NO_MAPCHANGE);
			PrintToClients("%t", "prepare post match", RoundFloat(preparation));
		}
	}

	void None() {
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
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_Player[i].ready) {
						continue;
					}

					g_Groups.AddPlayer(i);
					PrintToClient(i, "%T", "added to slot queue", i, i);
				}
			}
			case MODE_TEAMS, MODE_GROUPTEAMS: {
				int totalplayers = GetTotalPlayers();
				float ratio = convar_Ratio.FloatValue;
				int teams = 2; // Set the number of teams to 2
				int playersInFirstTeam = RoundToCeil(float(totalplayers) * ratio); // Calculate the number of players in the first team
				int playersInSecondTeam = totalplayers - playersInFirstTeam; // Calculate the number of players in the second team

				for (int i = 1; i <= MaxClients; i++) {
					added[i] = false;
				}

				for (int i = 0; i < teams; i++) {
					int[] clients = new int[MaxClients];
					int total;

					int playersInThisTeam = (i == 0) ? playersInFirstTeam : playersInSecondTeam;
					int client;

					for (int x = 0; x < playersInThisTeam; x++) {
						client = FindAvailablePlayer();

						if (client < 1) {
							continue;
						}

						added[client] = true;

						clients[total] = client;
						PrintToClient(clients[total], "%T", "added to group queue", clients[total], (i + 1));
						total++
					}

					g_Groups.AddGroup(clients, MaxClients);
				}
			}
		}
	}

	void PopQueue(bool ready) {
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i)) {
				continue;
			}

			if (L4D_GetClientTeam(i) != L4DTeam_Spectator) {
				L4D_ChangeClientTeam(i, L4DTeam_Spectator);
			}
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

					if (!IsClientInGame(client) || IsFakeClient(client)) {
						continue;
					}

					PrintToClient(client, "%T", "you're up", client);

					L4D_ChangeClientTeam(client, L4DTeam_Infected);
					L4D_RespawnPlayer(client);
					L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
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

						if (!IsClientInGame(client) || IsFakeClient(client)) {
							continue;
						}

						PrintToClient(client, "%T", "you're up for team", client);

						L4D_ChangeClientTeam(client, L4DTeam_Infected);
						L4D_RespawnPlayer(client);
						L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
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
				TeleportEntity(i, origin, NULL_VECTOR, NULL_VECTOR);
				LookAtPoint(i, origin2);
			}

			g_Player[i].currentnode = 0;

			SetEntityMoveType(i, MOVETYPE_NONE);
			SetEntProp(i, Prop_Send, "m_CollisionGroup", 0);
			L4D_SetClass(i, view_as<int>(L4D2ZombieClass_Charger));
		}

		if (ready) {
			this.Ready();
		}
	}
}

void OpenModesMenu(int client) {
	Menu menu = new Menu(MenuHandler_Modes);
	menu.SetTitle("Select a mode:");

	menu.AddItem("Players", "Players\n - Players play 1 at a time.");
	menu.AddItem("Groups", "Groups\n - All players play at once.");
	menu.AddItem("Teams", "Teams\n - Teams play 1 at a time.");
	menu.AddItem("GroupTeams", "Group Teams\n - All teams play at once.");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Modes(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				return 0;
			}

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

			char sName[64];
			GetModeName(mode, sName, sizeof(sName));

			Response_SetMode response = SetMode(mode);

			if (response == Success) {
				PrintToClient(param1, "%T", "mode set successfully", param1, sName);
			} else {
				char reason[64];
				switch (response) {
					case InvalidMode: {
						strcopy(reason, sizeof(reason), "Mode specified is invalid.");
					}
					case AlreadySet: {
						strcopy(reason, sizeof(reason), "Mode is already set.");
					}
					case AlreadyActive: {
						strcopy(reason, sizeof(reason), "Gamemode is already active.");
					}
				}
				
				PrintToClient(param1, "%T", "mode set unsuccessfully", param1, sInfo, reason);
			}
			
			OpenModesMenu(param1);
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

enum Response_SetMode {
	Success,
	InvalidMode,
	AlreadySet,
	AlreadyActive
}

Response_SetMode SetMode(Modes mode) {
	if (mode < MODE_SINGLES || mode > MODE_GROUPTEAMS) {
		return InvalidMode;
	}

	if (g_State.mode == mode) {
		return AlreadySet;
	}

	if (g_State.status != STATUS_PREPARING) {
		return AlreadyActive;
	}

	char sName[64];
	GetModeName(mode, sName, sizeof(sName));

	PrintToClients("%t", "mode changing to", sName);

	g_State.mode = mode;
	g_API.Call_OnModeSet(g_State.mode);

	return Success;
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
				g_State.Preparing();
				g_API.Call_OnStatusChange(g_State.status);
				return true;
			}
			return false;
		}
		case STATUS_START: {
			if (g_State.status == STATUS_PREPARING) {
				g_State.StartRace();
				g_API.Call_OnStatusChange(g_State.status);
				return true;
			}
			return false;
		}
		case STATUS_READY: {
			if (g_State.status == STATUS_START) {
				g_State.Ready();
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