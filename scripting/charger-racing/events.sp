public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (!IsModeEnabled()) {
		return;
	}

	//By default, we don't have a track to pick at the start of the round.
	SetTrack(NO_TRACK);

	//If we have any available tracks on the map, just pick the 1st one.
	if (g_TotalTracks > 0 && g_State.track == NO_TRACK) {
		SetTrack(0, false);
	}
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (!IsModeEnabled()) {
		return;
	}

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1 || IsFakeClient(client)) {
		return;
	}

	if (g_State.status == STATUS_PREPARING) {
		PrintToClient(client, "%T", "type ready", client);
	}

	g_Player[client].charging = false;
	CreateTimer(0.1, Timer_DelaySpawn, userid, TIMER_FLAG_NO_MAPCHANGE);

	//If the state is currently set to none when the first player spawns on the server then start the preparation period.
	if (g_State.status == STATUS_NONE && !convar_NewRoundState.BoolValue) {
		g_State.Preparing();
	}

	//Move the player to the infected team if they're not on there already while spawning into the map.
	if (L4D_GetClientTeam(client) == L4DTeam_Survivor) {
		L4D_ChangeClientTeam(client, L4DTeam_Infected);
	}

	//Respawn the player if they currently aren't alive but on a team.
	if (!IsPlayerAlive(client)) {
		L4D_RespawnPlayer(client);
	}

	//Make sure the player is a charger and no other type of zombie.
	if (L4D2_GetPlayerZombieClass(client) != L4D2ZombieClass_Charger) {
		L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
	}

	if (g_State.status != STATUS_READY && g_State.status != STATUS_RACING) {
		TeleportToSurvivorPos(client);
	}
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	if (!IsModeEnabled()) {
		return;
	}

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1 || IsFakeClient(client)) {
		return;
	}

	g_Player[client].charging = false;

	if (g_Player[client].finished) {
		return;
	}

	if (g_State.status == STATUS_RACING && (g_State.mode == MODE_SINGLES || g_State.mode == MODE_GROUPS)) {
		//If the player is racing but dies, move onto the next player then end the race.
		g_Player[client].finished = true;
		//PrintToClients("%t", "finished the race", client);

		if (g_State.IsFinished()) {
			g_State.EndRace();
		} else {
			g_State.PopQueue(true);
		}
	}
}

public void Event_OnChargeStart(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1) {
		return;
	}

	g_Player[client].charging = true;

	//Chargers can move left and right if they don't have the frozen flag applied.
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);

	//Chargers should have a particle attached while charging.
	char sParticle[64];
	convar_Charging_Particle.GetString(sParticle, sizeof(sParticle));
	if (strlen(sParticle) > 0) {
		TE_SetupParticleFollowEntity_Name(sParticle, client);
	}
}

public void Event_OnChargeEnd(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1) {
		return;
	}

	g_Player[client].charging = false;

	//Immediately allows players to charge very shortly after it ends.
	CreateTimer(0.2, Timer_DelayChargeEnd, userid);

	//Chargers should no longer be have a particle shown once they stop charging.
	TE_SetupStopAllParticles(client);
}

public void Event_OnPummelStart(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int target = GetClientOfUserId(event.GetInt("victim"));

	DropVictim(client, target);
}

public void Event_OnBotReplacePlayer(Event event, const char[] name, bool dontBroadcast) {
	int bot = GetClientOfUserId(event.GetInt("bot"));

	if (IsValidEntity(bot)) {
		KickClient(bot);
	}
}