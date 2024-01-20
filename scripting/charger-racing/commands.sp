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
		ReplyToClient(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	if (args > 0) {
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));
		g_Player[client].hud = view_as<bool>(StringToInt(arg));
	} else {
		g_Player[client].hud = !g_Player[client].hud;
	}

	PrintToClient(client, "%T%T", "hud status", client, (g_Player[client].hud ? "hud enabled" : "hud disabled"), client);

	if (AreClientCookiesCached(client)) {
		g_Cookies.hud.Set(client, (g_Player[client].hud ? "1" : "0"));
	}

	return Plugin_Handled;
}

public Action Command_Commands(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		ReplyToClient(client, "%T", "Command is in-game only", client);
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
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	char name[MAX_NAME_LENGTH];
	if (g_State.track != NO_TRACK) {
		strcopy(name, sizeof(name), g_Tracks[g_State.track].name);
	} else {
		strcopy(name, sizeof(name), "none");
	}

	ReplyToClient(client, "Track '%i/%i' is currently set to: %s", g_State.track, g_TotalTracks, name);

	return Plugin_Handled;
}

public Action Command_Stats(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		ReplyToClient(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	OpenStatsPanel(client);

	return Plugin_Handled;
}

public Action Command_VoteTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		switch (CallTrackVote(NO_TRACK)) {
			case VoteState_InProgress: {
				ReplyToClient(client, "%T", "reply vote for track already in progress", client);
			}
			case VoteState_Active: {
				ReplyToClient(client, "%T", "reply vote for track started", client);
			}
			case VoteState_Empty: {
				ReplyToClient(client, "%T", "reply vote for track empty", client);
			}
		}

		return Plugin_Handled;
	}

	char sTrack[64];
	GetCmdArg(1, sTrack, sizeof(sTrack));

	int track = FindTrack(sTrack);

	if (track == -1) {
		ReplyToClient(client, "%T", "reply track not found", client);
		return Plugin_Handled;
	}

	switch (CallTrackVote(track)) {
		case VoteState_InProgress: {
			ReplyToClient(client, "%T", "reply vote for track already in progress", client);
		}
		case VoteState_Active: {
			ReplyToClient(client, "%T", "reply vote for track started", client);
		}
		case VoteState_Empty: {
			ReplyToClient(client, "%T", "reply vote for track empty", client);
		}
	}

	return Plugin_Handled;
}

public Action Command_ReloadTracks(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (g_State.status != STATUS_PREPARING) { 
		ReplyToClient(client, "%T", "must be in preparation phase", client);
		return Plugin_Handled;
	}

	ParseTracks(g_TracksPath);
	ReplyToClient(client, "%T", "reply reloaded tracks", client, g_TracksPath);

	return Plugin_Handled;
}

public Action Command_SaveTracks(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	SaveTracks(g_TracksPath);
	ReplyToClient(client, "%T", "reply saved all tracks", client, g_TracksPath);

	return Plugin_Handled;
}

public Action Command_CreateTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		ReplyToClient(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	if (g_State.status != STATUS_PREPARING) { 
		ReplyToClient(client, "%T", "must be in preparation phase", client);
		return Plugin_Handled;
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
		ReplyToClient(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	if (args > 0) {
		char search[MAX_NAME_LENGTH];
		GetCmdArgString(search, sizeof(search));

		int track = StringToInt(search);

		if (!IsStringNumeric(search)) {
			track = FindTrack(search);
		}

		if (track == NO_TRACK) {
			ReplyToClient(client, "%T", "track not found", client);
			return Plugin_Handled;
		}

		AskConfirmDeleteTrack(client, track);

		return Plugin_Handled;
	}

	OpenTracksMenu(client, Action_Delete);

	return Plugin_Handled;
}

public Action Command_EditTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		ReplyToClient(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	if (g_State.status != STATUS_PREPARING) { 
		ReplyToClient(client, "%T", "must be in preparation phase", client);
		return Plugin_Handled;
	}

	if (args > 0) {
		char search[MAX_NAME_LENGTH];
		GetCmdArgString(search, sizeof(search));

		int track = StringToInt(search);

		if (!IsStringNumeric(search)) {
			track = FindTrack(search);
		}

		if (track == NO_TRACK) {
			ReplyToClient(client, "%T", "track not found", client);
			return Plugin_Handled;
		}

		OpenTrackEditorMenu(client, track);

		return Plugin_Handled;
	}

	OpenTracksMenu(client, Action_Edit);

	return Plugin_Handled;
}

public Action Command_SetTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		ReplyToClient(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	if (g_State.status != STATUS_PREPARING) { 
		ReplyToClient(client, "%T", "must be in preparation phase", client);
		return Plugin_Handled;
	}

	if (args > 0) {
		char sTrack[16];
		GetCmdArg(1, sTrack, sizeof(sTrack));

		if (SetTrack(StringToInt(sTrack))) {
			PrintToClient(client, "%T", "track set successfully", client);
		} else {
			PrintToClient(client, "%T", "track set failed", client);
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

	if (g_State.status != STATUS_PREPARING) { 
		ReplyToClient(client, "%T", "must be in preparation phase", client);
		return Plugin_Handled;
	}

	g_State.StartRace();
	PrintToClients("%t", "force start race", client);

	return Plugin_Handled;
}

public Action Command_EndRace(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (g_State.status != STATUS_RACING) {
		ReplyToClient(client, "%T", "no race active", client);
		return Plugin_Handled;
	}

	g_State.Finish();
	g_API.Call_OnEndRace();

	PrintToClients("%t", "force end race", client);

	return Plugin_Handled;
}

public Action Command_SetMode(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		ReplyToClient(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	if (g_State.status != STATUS_PREPARING) { 
		ReplyToClient(client, "%T", "must be in preparation phase", client);
		return Plugin_Handled;
	}

	if (args > 0) {
		char sMode[16];
		GetCmdArg(1, sMode, sizeof(sMode));

		Modes mode = view_as<Modes>(StringToInt(sMode));

		char sName[64];
		GetModeName(mode, sName, sizeof(sName));

		Response_SetMode response = SetMode(mode);

		if (response == Success) {
			PrintToClient(client, "%T", "mode set successfully", client, sName);
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

			PrintToClient(client, "%T", "mode set unsuccessfully", client, sMode, reason);
		}

		return Plugin_Handled;
	}

	OpenModesMenu(client);

	return Plugin_Handled;
}

public Action Command_Pause(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	g_State.paused = !g_State.paused;
	ReplyToClient(client, "%T%T", "pause status", client, g_State.paused ? "pause enabled" : "pause disabled", client);

	return Plugin_Handled;
}

public Action Command_State(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}
	
	char name[64];
	GetStateDisplayName(g_State.status, name, sizeof(name));

	ReplyToClient(client, "%T", "state status", client, name);

	return Plugin_Handled;
}

public Action Command_Respawn(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	char search[MAX_TARGET_LENGTH];
	GetCmdArgString(search, sizeof(search));

	int target = FindTargetEx(client, search, false, false);

	if (target == -1) {
		target = client;
	}

	L4D_ChangeClientTeam(target, L4DTeam_Infected);
	L4D_RespawnPlayer(client);

	return Plugin_Handled;
}

public Action Command_Groups(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	//g_State.SetupGroups();

	int groups = g_Groups.GetTotalGroups();

	PrintToServer("===========================================");
	PrintToServer("Total groups: %i", groups);
	for (int i = 0; i < groups; i++) {
		PrintToServer(" - Group %i:", i);
		int[] players = new int[MaxClients];
		g_Groups.GetGroupMembers(i, players);
		
		for (int x = 0; x < MaxClients; x++) {
			PrintToServer("  - Player %i: %i %s", x, players[x], g_Player[players[x]].finished ? "finished" : "");
		}
	}
	PrintToServer("===========================================");

	return Plugin_Handled;
}

public Action Command_Ready(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		ReplyToClient(client, "%T", "Command is in-game only", client);
		return Plugin_Handled;
	}

	if (g_State.status != STATUS_PREPARING) { 
		ReplyToClient(client, "%T", "must be in preparation phase", client);
		return Plugin_Handled;
	}

	g_Player[client].ready = !g_Player[client].ready;
	PrintToClient(client, "%T", "ready toggle", client, (g_Player[client].ready ? "Enabled" : "Disabled"));

	for (int i = 1; i <= MaxClients; i++) {
		g_Player[i].ready = true;
	}

	return Plugin_Handled;
}