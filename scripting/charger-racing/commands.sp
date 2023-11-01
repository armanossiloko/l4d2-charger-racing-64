enum struct Command {
	char command[64];
	char description[64];
	int adminFlags;

	void Set(const char[] command, const char[] description, int adminFlags) {
		strcopy(this.command, sizeof(Command::command), command);
		strcopy(this.description, sizeof(Command::description), description);
		this.adminFlags = adminFlags;
	}
}

void RegConsoleCmd2(const char[] cmd, ConCmd callback, const char[] description = "", int flags = 0) {
	g_Command[g_TotalCommands++].Set(cmd, description, 0);
	RegConsoleCmd(cmd, callback, description, flags);
}

void RegAdminCmd2(const char[] cmd, ConCmd callback, int adminFlags, const char[] description = "", const char[] group = "", int flags = 0) {
	g_Command[g_TotalCommands++].Set(cmd, description, adminFlags);
	RegAdminCmd(cmd, callback, adminFlags, description, group, flags);
}

public Action Command_Hud(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	g_Player[client].hud = !g_Player[client].hud;
	CPrintToChat(client, "%s%T%T", PLUGIN_TAG, "hud status", client, (g_Player[client].hud ? "hud enabled" : "hud disabled"), client);

	if (AreClientCookiesCached(client)) {
		g_Cookie_Hud.Set(client, (g_Player[client].hud ? "1" : "0"));
	}

	return Plugin_Handled;
}

public Action Command_Commands(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	Menu menu = new Menu(MenuAction_Commands);
	menu.SetTitle("Commands");
	
	char sBuffer[256];
	for (int i = 0; i < g_TotalCommands; i++) {
		if (g_Command[i].adminFlags > 0 && !(GetUserFlagBits(client) & g_Command[i].adminFlags)) {
			continue;
		}

		FormatEx(sBuffer, sizeof(sBuffer), "%s - %s", g_Command[i].command, g_Command[i].description);
		menu.AddItem("", sBuffer, ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuAction_Commands(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

public Action Command_Track(int client, int args) {
	char name[MAX_NAME_LENGTH];
	if (g_State.track != NO_TRACK) {
		strcopy(name, sizeof(name), g_Tracks[g_State.track].name);
	} else {
		strcopy(name, sizeof(name), "none");
	}
	CReplyToCommand(client, "%sTrack '%i/%i' is currently set to: %s", PLUGIN_TAG, g_State.track, g_TotalTracks, name);
	return Plugin_Handled;
}

public Action Command_VoteTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		if (CallTrackVote(NO_TRACK)) {
			CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply vote for track started", client);
		} else {
			CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply vote for track already in progress", client);
		}
		return Plugin_Handled;
	}

	char sTrack[64];
	GetCmdArg(1, sTrack, sizeof(sTrack));

	int track = FindTrack(sTrack);

	if (track == -1) {
		CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply track not found", client);
		return Plugin_Handled;
	}

	if (CallTrackVote(track)) {
		CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply vote for track started", client);
	} else {
		CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply vote for track already in progress", client);
	}

	return Plugin_Handled;
}

public Action Command_ReloadTracks(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	ParseTracks(g_TracksPath);
	CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply reloaded tracks", client, g_TracksPath);
	return Plugin_Handled;
}

public Action Command_SaveTracks(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	SaveTracks(g_TracksPath);
	CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply saved all tracks", client, g_TracksPath);
	return Plugin_Handled;
}

public Action Command_CreateTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	g_CreatingTrack[client].Init();
	OpenCreateTrackMenu(client);

	return Plugin_Handled;
}

public Action Command_DeleteTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args > 0) {

	}

	OpenTracksMenu(client, Action_Delete);

	return Plugin_Handled;
}

public Action Command_EditTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args > 0) {

	}

	OpenTracksMenu(client, Action_Edit);

	return Plugin_Handled;
}

public Action Command_SetTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args > 0) {
		char sTrack[16];
		GetCmdArg(1, sTrack, sizeof(sTrack));

		if (SetTrack(StringToInt(sTrack))) {
			CPrintToChat(client, "%s%T", PLUGIN_TAG, "track set successfully", client);
		} else {
			CPrintToChat(client, "%s%T", PLUGIN_TAG, "track set failed", client);
		}

		return Plugin_Handled;
	}

	OpenTracksMenu(client, Action_Set);
	return Plugin_Handled;
}

public Action Command_StartRace(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	g_State.SetupGroups();
	g_State.Ready(true);

	CPrintToChatAll("%s%t", PLUGIN_TAG, "force start race", client);

	return Plugin_Handled;
}

public Action Command_EndRace(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (g_State.status != STATUS_RACING) {
		CReplyToCommand(client, "%s%T", PLUGIN_TAG, "no race active", client);
		return Plugin_Handled;
	}

	g_State.Finish();
	g_API.Call_OnEndRace();

	CPrintToChatAll("%s%t", PLUGIN_TAG, "force end race", client);

	return Plugin_Handled;
}

public Action Command_SetMode(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args > 0) {
		char sMode[16];
		GetCmdArg(1, sMode, sizeof(sMode));

		if (SetMode(view_as<Modes>(StringToInt(sMode)))) {
			CPrintToChat(client, "%s%T", PLUGIN_TAG, "mode set successfully", client);
		} else {
			CPrintToChat(client, "%s%T", PLUGIN_TAG, "mode set failure", client);
		}

		return Plugin_Handled;
	}

	OpenModesMenu(client);

	return Plugin_Handled;
}

public Action Command_SpawnSurvivor(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	int survivor = GetCmdArgInt(1);

	float origin[3];
	GetClientCrosshairOrigin(client, origin, true, 35.0);

	if (SpawnSurvivor(origin, NULL_VECTOR, survivor) != -1) {
		CPrintToChat(client, "%s%T", PLUGIN_TAG, "survivor bot created", client);
	} else {
		CPrintToChat(client, "%s%T", PLUGIN_TAG, "survivor bot failed", client);
	}

	return Plugin_Handled;
}

public Action Command_SpawnProp(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args == 0) {
		float origin[3];
		GetClientCrosshairOrigin(client, origin);
		float angles[3];
		g_SpawningObjects[client].Set("prop_dynamic_override", origin, angles, DEFAULT_OBJECT, 0);
		g_SpawningObjects[client].Spawn();
		OpenSpawnPropMenu(client);
		return Plugin_Handled;
	}

	float origin[3];
	GetClientCrosshairOrigin(client, origin);
	float angles[3];
	g_SpawningObjects[client].Set("prop_dynamic_override", origin, angles, DEFAULT_OBJECT, 0);
	g_SpawningObjects[client].Spawn();
	OpenSpawnPropMenu(client);

	return Plugin_Handled;
}

public Action Command_SpawnBot(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args == 0) {
		float origin[3];
		GetClientCrosshairOrigin(client, origin);
		float angles[3];
		g_SpawningObjects[client].Set("info_l4d1_survivor_spawn", origin, angles, DEFAULT_OBJECT, 0);
		g_SpawningObjects[client].Spawn();
		OpenSpawnPropMenu(client);
		return Plugin_Handled;
	}

	float origin[3];
	GetClientCrosshairOrigin(client, origin);
	float angles[3];
	g_SpawningObjects[client].Set("info_l4d1_survivor_spawn", origin, angles, DEFAULT_OBJECT, 0);
	g_SpawningObjects[client].Spawn();
	OpenSpawnPropMenu(client);

	return Plugin_Handled;
}

public Action Command_Delete(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args == 0) {
		int target = GetClientAimTarget(client, false);

		if (!IsValidEntity(target)) {
			CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply not aiming at valid entity", client);
			return Plugin_Handled;
		}

		int obj = GetEntityObjectIndex(target);

		if (obj < 0) {
			CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply not aiming at valid object", client);
			return Plugin_Handled;
		}

		g_Objects[obj].Delete();
		g_Objects[obj].Remove(g_TracksPath, g_Tracks[g_State.track].name, obj);
		CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply object deleted", client);

		return Plugin_Handled;
	}

	int target = GetClientAimTarget(client, false);

	if (!IsValidEntity(target)) {
		CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply not aiming at valid entity", client);
		return Plugin_Handled;
	}

	int obj = GetEntityObjectIndex(target);

	if (obj < 0) {
		CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply not aiming at valid object", client);
		return Plugin_Handled;
	}

	g_Objects[obj].Delete();
	g_Objects[obj].Remove(g_TracksPath, g_Tracks[g_State.track].name, obj);
	CReplyToCommand(client, "%s%T", PLUGIN_TAG, "reply object deleted", client);

	return Plugin_Handled;
}

public Action Command_Pause(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	g_State.paused = !g_State.paused;
	CReplyToCommand(client, "%s%T%T", PLUGIN_TAG, "pause status", client, g_State.paused ? "pause enabled" : "pause disabled", client);

	return Plugin_Handled;
}

public Action Command_State(int client, int args) {
	char name[64];
	GetStateDisplayName(g_State.status, name, sizeof(name));
	CReplyToCommand(client, "%s%T", PLUGIN_TAG, "state status", client, name);
	return Plugin_Handled;
}