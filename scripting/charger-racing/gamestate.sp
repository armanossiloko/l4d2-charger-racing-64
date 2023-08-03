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

	void Preparing() {
		this.status = STATUS_PREPARING;
		g_API.Call_OnStatusChange(this.status);

		this.timer = convar_Preparation_Timer.FloatValue;
		this.ticker = CreateTimer(1.0, Timer_Tick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}

	void Ready() {
		this.status = STATUS_READY;
		g_API.Call_OnStatusChange(this.status);

		this.countdown = convar_Racing_Countdown.IntValue;
		this.timer = convar_Racing_Timer.FloatValue;

		g_Groups.Clear();
		this.group = 0;
		
		switch (this.mode) {
			case MODE_SINGLES, MODE_GROUP: {
				for (int i = 1; i <= MaxClients; i++) {
					if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
						continue;
					}

					g_Groups.AddPlayer(i);
					PrintToChat(i, "%sYou have been added to queue in slot: %i", PLUGIN_TAG, i);
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
						PrintToChat(clients[total], "%sYou have been added to group: %i", PLUGIN_TAG, i);
					}

					g_Groups.AddGroup(clients, total);
				}
			}
		}

		PopQueue();

		DeleteObjects();
		SpawnObjects();
		KickBots();

		//Run code a frame after ready starts, mostly used to stop compile errors.
		RequestFrame(Frame_DelayReady);
	}

	void Racing() {
		this.status = STATUS_RACING;
		g_API.Call_OnStatusChange(this.status);

		switch (this.mode) {
			case MODE_SINGLES: {
				
			}
			case MODE_GROUP: {
				//Unfreeze them so they can move again.
				for (int i = 1; i <= MaxClients; i++) {
					if (!IsClientInGame(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
						continue;
					}

					SetEntityMoveType(i, MOVETYPE_WALK);
					SetEntProp(i, Prop_Send, "m_CollisionGroup", 0);
				}
			}
			case MODE_TEAMS: {
				
			}
			case MODE_GROUPTEAMS: {

			}
		}
	}

	void Finish() {
		this.status = STATUS_FINISHED;
		g_API.Call_OnStatusChange(this.status);
		this.rounds++;

		//Run code a frame after the race finishes, mostly used to stop compile errors.
		RequestFrame(Frame_DelayFinish);

		this.None();
		if (convar_Rounds.IntValue > 0 && this.rounds >= convar_Rounds.IntValue) {
			InitiateMapChooserVote(MapChange_Instant);
		} else {
			CreateTimer(10.0, Timer_Prepare, _, TIMER_FLAG_NO_MAPCHANGE);
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
}