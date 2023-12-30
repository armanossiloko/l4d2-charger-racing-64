enum struct Track {
	char name[64];			//The name of the track to be displayed and called.
	Difficulty difficulty;	//The difficulty of the track, this is just an arbitrary value set when creating or editing the track.
	
	//Nodes
	ArrayList nodes;		//The list of origin points for the track which consists of 3D vectors in order. Index 0 is the start and the last index is the finish line.
	ArrayList colors;		//The colors that correspond to the beams of the track in corresponding order.

	void Init() {
		this.nodes = new ArrayList(3);
		this.colors = new ArrayList(4);
	}

	bool Valid() {
		if (strlen(this.name) == 0 || this.nodes == null || this.colors == null) {
			return false;
		}

		return true;
	}

	void Set(const char[] name, Difficulty difficulty) {
		strcopy(this.name, sizeof(Track::name), name);
		this.difficulty = difficulty;
	}

	void AddNode(float origin[3], int colors[4]) {
		this.nodes.PushArray(origin, sizeof(origin));
		this.colors.PushArray(colors, sizeof(colors));
	}

	void SetNode(int index, float origin[3], int colors[4]) {
		this.nodes.SetArray(index, origin, sizeof(origin));
		this.colors.SetArray(index, colors, sizeof(colors));
	}

	void SetNodeOrigin(int index, float origin[3]) {
		this.nodes.SetArray(index, origin, sizeof(origin));
	}

	void SetNodeColor(int index, int colors[4]) {
		this.colors.SetArray(index, colors, sizeof(colors));
	}

	int GetTotalNodes() {
		return this.nodes.Length;
	}

	void GetNode(int index, float origin[3], int colors[4]) {
		this.nodes.GetArray(index, origin, sizeof(origin));
		this.colors.GetArray(index, colors, sizeof(colors));
	}

	void GetNodeOrigin(int index, float origin[3]) {
		this.nodes.GetArray(index, origin, sizeof(origin));
	}

	void GetNodeColor(int index, int colors[4]) {
		this.colors.GetArray(index, colors, sizeof(colors));
	}

	void DeleteNode(int index) {
		this.nodes.Erase(index);
		this.colors.Erase(index);
	}

	void Clear() {
		this.nodes.Clear();
		this.colors.Clear();
	}

	void Delete() {
		this.name[0] = '\0';
		this.difficulty = DIFFICULTY_EASY;
		delete this.nodes;
		delete this.colors;
	}
}

void ParseTracks(const char[] file) {
	ClearTracks();

	if (!FileExists(file)) {
		return;
	}

	KeyValues kv = new KeyValues("racing-tracks");

	if (kv.ImportFromFile(file) && kv.GotoFirstSubKey()) {
		char name[64]; int index; Difficulty difficulty;
		do {
			kv.GetSectionName(name, sizeof(name));

			if (strlen(name) == 0) {
				continue;
			}

			index = g_TotalTracks++;
			g_Tracks[index].Init();

			difficulty = view_as<Difficulty>(kv.GetNum("difficulty"));

			if (kv.JumpToKey("track-points") && kv.GotoFirstSubKey()) {
				float origin[3]; int color[4];
				do {
					kv.GetVector("origin", origin);
					kv.GetColor4("color", color);
					
					g_Tracks[index].AddNode(origin, color);
				} while (kv.GotoNextKey());

				kv.GoBack();
				kv.GoBack();
			}

			g_Tracks[index].Set(name, difficulty);

		} while (kv.GotoNextKey());
	}

	delete kv;
	ModeLog("Parsed %d tracks from file: %s", g_TotalTracks, file);
}

void ClearTracks() {
	for (int i = 0; i <= MAX_TRACKS; i++) {
		g_Tracks[i].Delete();
	}
	g_TotalTracks = 0;
}

void SaveTracks(const char[] file) {
	if (FileExists(file)) {
		DeleteFile(file);
	}

	KeyValues kv = new KeyValues("racing-tracks");

	for (int i = 0; i < g_TotalTracks; i++) {
		kv.JumpToKey(g_Tracks[i].name, true);
		kv.SetNum("difficulty", view_as<int>(g_Tracks[i].difficulty));

		kv.JumpToKey("track-points", true);

		char sTrack[16]; float origin[3]; int color[4]; char sColor[64];
		for (int track = 0; track < g_Tracks[i].GetTotalNodes(); track++) {
			IntToString(track, sTrack, sizeof(sTrack));
			kv.JumpToKey(sTrack, true);

			g_Tracks[i].GetNode(track, origin, color);

			kv.SetVector("origin", origin);
			//kv.SetColor4("color", color); //Currently broken in Source.
			FormatEx(sColor, sizeof(sColor), "%i %i %i %i", color[0], color[1], color[2], color[3]);
			kv.SetString("color", sColor);

			kv.GoBack();
		}

		kv.GoBack();
	}

	kv.Rewind();
	kv.ExportToFile(file);

	delete kv;
	ModeLog("Saving %d tracks to file: %s", g_TotalTracks, file);
}

void OnNodeTick(int index, float origin[3]) {
	float radius = convar_Node_Radius.FloatValue;

	float pos[3];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
			continue;
		}

		pos = GetOrigin(i);

		if (GetDistance(origin, pos) <= radius) {
			IsNearNode(i, index);
		}
	}
}

void IsNearNode(int client, int index) {
	if (g_State.status != STATUS_RACING) {
		return;
	}

	//If we're at the last node, we're at the finish line.
	if (index == g_Tracks[g_State.track].GetTotalNodes() - 1) {
		IsNearFinish(client);
		return;
	}

	//If a player tries to take an unintended shortcut then stop progress.
	if (convar_Skip_Nodes.BoolValue && g_Player[client].currentnode < (index - 1)) {
		//Count how many nodes they've missed total.
		int missed = (index - 1) - g_Player[client].currentnode;
		int points = g_Points.Get(g_State.mode, "skipping-checkpoint");

		//Deduct points based on each node so if it's 2 points per node and they miss 3 nodes then they lose 6.
		int total;
		for (int i = 0; i < missed; i++) {
			total += points;
		}

		//Update their points and tell them how many they missed.
		g_Player[client].AddPoints(points);
		CPrintToChat(client, "%s%T", PLUGIN_TAG, "points lost for skipping nodes", client, total, missed);

		//Update their current node.
		g_Player[client].currentnode = index;

		return;
	}

	//Calculate a points value based on our average speed then clear the cache so we get a fresh average between nodes.
	//float average = g_Player[client].GetAverageSpeed();
	//int points = RoundToCeil(average) / 5;

	if (g_Player[client].currentnode < index) {
		//Give them points based on reaching the checkpoint and clear their speed calculations.
		int points = g_Points.Get(g_State.mode, "checkpoint");
		g_Player[client].speeds.Clear();

		//If we're carrying a survivor, give our points a multiplier.
		if (L4D2_GetInfectedAttacker(client) != -1) {
			points *= 1.20;
		}

		//Give the points and update the hud.
		g_Player[client].AddPoints(points);
		CPrintToChat(client, "%s%T", PLUGIN_TAG, "points gained for reaching node", client, index, points);

		//Update their current node.
		g_Player[client].currentnode = index;
	}
}

void IsNearFinish(int client) {
	if (g_Player[client].finished) {
		return;
	}

	g_Player[client].finished = true;
	CPrintToChatAll("%s%t", PLUGIN_TAG, "finished the race", client);

	if (convar_Death_On_Finish.BoolValue) {
		ForcePlayerSuicide(client);
	}

	char sTime[32];
	FormatSeconds(g_Player[client].GetTime(), sTime, sizeof(sTime), "%M:%S", true);
	
	CPrintToChat(client, "%s%T", PLUGIN_TAG, "time and score", client, sTime, g_Player[client].points);

	int points = g_Points.Get(g_State.mode, "finished");

	if (L4D2_GetInfectedAttacker(client) != -1) {
		points += g_Points.Get(g_State.mode, "survivor");
	}

	g_Player[client].AddPoints(points);

	if (AllPlayersFinished()) {
		switch (g_State.mode) {
			case MODE_SINGLES, MODE_GROUPS: {
				int winner = GetWinnerForSingles();

				if (winner == -1) {
					CPrintToChatAll("%s%t", PLUGIN_TAG, "no winner for player");
				} else {
					points = g_Points.Get(g_State.mode, "winner");

					if (L4D2_GetInfectedAttacker(winner) != -1) {
						points += g_Points.Get(g_State.mode, "survivor");
					}
					
					g_Player[winner].AddPoints(points);

					g_Player[winner].stats.wins++;
					IncrementStat(winner, "wins");
					
					CPrintToChatAll("%s%t", PLUGIN_TAG, "winner for player", winner, g_Player[winner].points);

					for (int i = 1; i <= MaxClients; i++) {
						if (IsClientAuthorized(i) && winner != i) {
							g_Player[i].stats.losses++;
							IncrementStat(i, "losses");
						}
					}
				}
			}
			case MODE_TEAMS, MODE_GROUPTEAMS: {
				int group = GetWinnerGroup();
				
				if (group == -1) {
					CPrintToChatAll("%s%t", PLUGIN_TAG, "no winner for team");
				} else {
					int[] players = new int[MaxClients];
					g_Groups.GetGroupMembers(group, players);

					points = g_Points.Get(g_State.mode, "winner");

					int total; int temp; int player;
					for (int i = 0; i <= MaxClients; i++) {
						temp = points;
						player = players[i];

						if (L4D2_GetInfectedAttacker(player) != -1) {
							temp += g_Points.Get(g_State.mode, "survivor");
						}

						g_Player[player].AddPoints(temp);
						total += g_Player[player].points;

						g_Player[player].stats.wins++;
						IncrementStat(player, "wins");
					}

					for (int i = 1; i <= MaxClients; i++) {
						if (IsClientAuthorized(i) && FindValueInADTArray(players, MaxClients, i) == -1) {
							g_Player[i].stats.losses++;
							IncrementStat(i, "losses");
						}
					}

					CPrintToChatAll("%s%t", PLUGIN_TAG, "winner for team", group, total);
				}
			}
		}

		g_State.Finish();
		g_API.Call_OnEndRace();
	} else {
		if (g_State.mode == MODE_SINGLES || g_State.mode == MODE_TEAMS) {
			g_State.PopQueue(true);
		}
	}
}

int FindTrack(const char[] name) {
	for (int i = 0; i < g_TotalTracks; i++) {
		if (StrContains(g_Tracks[i].name, name, false) != -1) {
			return i;
		}
	}

	return NO_TRACK;
}

void OpenCreateTrackMenu(int client) {
	Menu menu = new Menu(MenuHandler_CreateTrack, MENU_ACTIONS_ALL);
	menu.SetTitle("Create a new track:");

	menu.AddItem("name", "Name: N/A");
	menu.AddItem("difficulty", "Difficulty: Easy");
	menu.AddItem("add", "Add Node");
	menu.AddItem("total", "--- (Total Nodes: 0)");
	//menu.AddItem("prop", "Add a Prop");
	//menu.AddItem("bot", "Add a Bot");
	menu.AddItem("save", "Save Track");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_CreateTrack(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_DisplayItem: {
			char sInfo[64]; char sDisplay[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

			if (StrEqual(sInfo, "name")) {
				FormatEx(sDisplay, sizeof(sDisplay), "Name: %s", strlen(g_CreatingTrack[param1].name) > 0 ? g_CreatingTrack[param1].name : "N/A");
			} else if (StrEqual(sInfo, "difficulty")) {
				char sDifficulty[32];
				GetDifficultyName(g_CreatingTrack[param1].difficulty, sDifficulty, sizeof(sDifficulty));
				FormatEx(sDisplay, sizeof(sDisplay), "Difficulty: %s", sDifficulty);
			} else if (StrEqual(sInfo, "total")) {
				FormatEx(sDisplay, sizeof(sDisplay), "--- (Total Nodes: %d)", g_CreatingTrack[param1].GetTotalNodes());
			}

			return RedrawMenuItem(sDisplay);
		}

		case MenuAction_Select: {
			char sInfo[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "name")) {
				g_SettingName[param1] = true;
				CPrintToChat(param1, "%s%T", PLUGIN_TAG, "editor enter a track name", param1);
				return 0;
			} else if (StrEqual(sInfo, "difficulty")) {
				g_CreatingTrack[param1].difficulty++;

				if (g_CreatingTrack[param1].difficulty > DIFFICULTY_IMPOSSIBLE) {
					g_CreatingTrack[param1].difficulty = DIFFICULTY_EASY;
				}

			} else if (StrEqual(sInfo, "add")) {
				g_NewNode[param1] = g_CreatingTrack[param1].GetTotalNodes();

				float origin[3];
				origin = GetOrigin(param1, 10.0);

				int color[4] = {255, 255, 255, 255};
				g_CreatingTrack[param1].AddNode(origin, color);

				OpenAddNodeMenu(param1, Action_Create);
				return 0;
			} else if (StrEqual(sInfo, "save")) {
				if (g_CreatingTrack[param1].GetTotalNodes() >= 2 && strlen(g_CreatingTrack[param1].name) > 0) {
					SaveTrack(param1);
					return 0;
				} else {
					CPrintToChat(param1, "%s%T", PLUGIN_TAG, "missing data while saving", param1);
				}
			}

			OpenCreateTrackMenu(param1);
		}
		
		case MenuAction_Cancel: {
			g_CreatingTrack[param1].Delete();
		}

		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

void OpenAddNodeMenu(int client, TrackAction action) {
	float origin[3]; char sColor[32];
	switch (action) {
		case Action_Create: {
			int node = g_NewNode[client];

			int color[4];
			g_CreatingTrack[client].GetNode(node, origin, color);

			FormatEx(sColor, sizeof(sColor), "%d/%d/%d", color[0], color[1], color[2]);
		}

		case Action_Edit: {
			int id = g_EditingTrack[client];
			int node = g_EditingNode[client];

			int color[4];
			g_Tracks[id].GetNode(node, origin, color);

			FormatEx(sColor, sizeof(sColor), "%d/%d/%d", color[0], color[1], color[2]);
		}
	}

	Menu menu = new Menu(MenuHandler_AddNode);
	menu.SetTitle("Add a new node:\nOrigin: %.2f/%.2f/%.2f\nColor: %s", origin[0], origin[1], origin[2], sColor);

	menu.AddItem("position", "Update Position");
	menu.AddItem("color", "Change Color");
	menu.AddItem("save", "Save Node");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AddNode(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sInfo[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			switch (trackaction) {
				case Action_Create: {
					int node = g_NewNode[param1];
					
					if (StrEqual(sInfo, "position")) {
						float origin[3];
						origin = GetOrigin(param1, 10.0);
						g_CreatingTrack[param1].SetNodeOrigin(node, origin);
					} else if (StrEqual(sInfo, "color")) {
						OpenColorsMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "save")) {
						OpenCreateTrackMenu(param1);
						return 0;
					}

					OpenAddNodeMenu(param1, Action_Create);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int node = g_EditingNode[param1];

					if (StrEqual(sInfo, "position")) {
						float origin[3];
						origin = GetOrigin(param1, 10.0);
						g_Tracks[id].SetNodeOrigin(node, origin);
					} else if (StrEqual(sInfo, "color")) {
						OpenColorsMenu(param1, Action_Edit);
						return 0;
					} else if (StrEqual(sInfo, "save")) {
						OpenNodeEditorMenu(param1, id);
						return 0;
					}

					OpenAddNodeMenu(param1, Action_Edit);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenCreateTrackMenu(param1);
			} else {
				g_CreatingTrack[param1].Delete();
			}
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void OpenColorsMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_Colors);
	menu.SetTitle("Select a color:");

	menu.AddItem("255 0 0 255", "Red");
	menu.AddItem("0 255 0 255", "Green");
	menu.AddItem("0 0 255 255", "Blue");
	menu.AddItem("255 255 0 255", "Yellow");
	menu.AddItem("255 0 255 255", "Magenta");
	menu.AddItem("0 255 255 255", "Cyan");
	menu.AddItem("255 255 255 255", "White");
	menu.AddItem("0 0 0 255", "Black");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Colors(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sColor[64];
			menu.GetItem(param2, sColor, sizeof(sColor));

			int color[4];
			StringToColor(sColor, color);

			switch (trackaction) {
				case Action_Create: {
					int node = g_NewNode[param1];
					g_CreatingTrack[param1].SetNodeColor(node, color);
					OpenAddNodeMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int node = g_EditingNode[param1];
					g_Tracks[id].SetNodeColor(node, color);
					OpenNodeEditorMenu(param1, id);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				switch (trackaction) {
					case Action_Create: {
						OpenAddNodeMenu(param1, trackaction);
					}

					case Action_Edit: {
						int id = g_EditingTrack[param1];
						OpenNodeEditorMenu(param1, id);
					}
				}
			} else {
				switch (trackaction) {
					case Action_Create: {
						g_CreatingTrack[param1].Delete();
					}

					case Action_Edit: {
						g_EditingTrack[param1] = NO_TRACK;
						g_EditingNode[param1] = NO_NODE;
					}
				}
			}
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void SaveTrack(int client) {
	int index = g_TotalTracks++;

	strcopy(g_Tracks[index].name, sizeof(Track::name), g_CreatingTrack[client].name);
	g_Tracks[index].difficulty = g_CreatingTrack[client].difficulty;
	g_Tracks[index].nodes = g_CreatingTrack[client].nodes.Clone();
	g_Tracks[index].colors = g_CreatingTrack[client].colors.Clone();

	CPrintToChat(client, "%s%T", PLUGIN_TAG, "editor track save", client);
	g_CreatingTrack[client].Delete();

	SaveTracks(g_TracksPath);
}

void OpenTracksMenu(int client, TrackAction action) {
	char sAction[64];
	switch (action) {
		case Action_Delete:
			sAction = "delete";
		case Action_Edit:
			sAction = "edit";
		case Action_Set:
			sAction = "use";
	}

	Menu menu = new Menu(MenuHandler_Tracks);
	menu.SetTitle("Pick a track to %s:", sAction);

	menu.AddItem("-1", "None");

	char sID[16];
	for (int i = 0; i < g_TotalTracks; i++) {
		IntToString(i, sID, sizeof(sID));
		menu.AddItem(sID, g_Tracks[i].name);
	}

	if (menu.ItemCount == 0) {
		menu.AddItem("", "No tracks available.", ITEMDRAW_DISABLED);
	}

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Tracks(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));
	
	switch (action) {
		case MenuAction_Select: {
			char sID[16];
			menu.GetItem(param2, sID, sizeof(sID));

			int id = StringToInt(sID);

			switch (trackaction) {
				case Action_Edit: {
					OpenTrackEditorMenu(param1, id);
				}

				case Action_Delete: {
					AskConfirmDeleteTrack(param1, id);
				}

				case Action_Set: {
					AskConfirmSetTrack(param1, id);
				}
			}
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void AskConfirmDeleteTrack(int client, int id) {
	Menu menu = new Menu(MenuHandler_AskConfirmDeleteTrack);
	menu.SetTitle("Are you sure you want to delete this track?\n - %s", g_Tracks[id].name);

	menu.AddItem("Yes", "Yes");
	menu.AddItem("No", "No");

	PushMenuInt(menu, "id", id);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AskConfirmDeleteTrack(Menu menu, MenuAction action, int param1, int param2) {
	int id = GetMenuInt(menu, "id");

	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "Yes")) {
				if (DeleteTrack(id)) {
					CPrintToChat(param1, "%s%T", PLUGIN_TAG, "track deleted", param1);
					ParseTracks(g_TracksPath);
				} else {
					CPrintToChat(param1, "%s%T", PLUGIN_TAG, "track deletion failed", param1);
				}
			} else if (StrEqual(sInfo, "No")) {
				CPrintToChat(param1, "%s%T", PLUGIN_TAG, "track not deleted", param1);
			}

			OpenTracksMenu(param1, Action_Delete);
		}
		
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenTracksMenu(param1, Action_Delete);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

bool DeleteTrack(int track) {

	KeyValues kv = new KeyValues("racing-tracks");

	if (!kv.ImportFromFile(g_TracksPath)) {
		delete kv;
		return false;
	}

	kv.JumpToKey(g_Tracks[track].name);
	kv.DeleteThis();
	kv.Rewind();
	kv.ExportToFile(g_TracksPath);
	delete kv;

	//If the track is currently selected, deselect it.
	if (g_State.track == track) {
		SetTrack(NO_TRACK);
	}

	return true;
}

void OpenTrackEditorMenu(int client, int id) {
	g_EditingTrack[client] = id;

	Menu menu = new Menu(MenuHandler_TrackEditor, MENU_ACTIONS_ALL);
	menu.SetTitle("Track Editor for %s:", g_Tracks[id].name);

	menu.AddItem("name", "Name: N/A");
	menu.AddItem("difficulty", "Difficulty: Easy");
	menu.AddItem("nodes", "Manage Nodes");
	//menu.AddItem("prop", "Spawn a Prop");
	//menu.AddItem("bot", "Spawn a Bot");

	PushMenuInt(menu, "id", id);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TrackEditor(Menu menu, MenuAction action, int param1, int param2) {
	int id = GetMenuInt(menu, "id");

	switch (action) {
		case MenuAction_DisplayItem: {
			char sInfo[32]; char sDisplay[256];
			menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

			char sBuffer[256];
			if (StrEqual(sInfo, "name")) {
				FormatEx(sBuffer, sizeof(sBuffer), "Name: %s", g_Tracks[id].name);
			} else if (StrEqual(sInfo, "difficulty")) {
				char sDifficulty[64];
				GetDifficultyName(g_Tracks[id].difficulty, sDifficulty, sizeof(sDifficulty));
				FormatEx(sBuffer, sizeof(sBuffer), "Difficulty: %s", sDifficulty);
			} else {
				strcopy(sBuffer, sizeof(sBuffer), sDisplay);
			}

			return RedrawMenuItem(sBuffer);
		}

		case MenuAction_DrawItem: {
			char sInfo[32]; char sDisplay[256]; int draw;
			menu.GetItem(param2, sInfo, sizeof(sInfo), draw, sDisplay, sizeof(sDisplay));
			return draw;
		}

		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "name")) {
				g_SettingName[param1] = true;
				CPrintToChat(param1, "%s%T", PLUGIN_TAG, "enter new track name", param1);
				return 0;
			} else if (StrEqual(sInfo, "difficulty")) {
				g_Tracks[id].difficulty++;

				if (g_Tracks[id].difficulty > DIFFICULTY_IMPOSSIBLE) {
					g_Tracks[id].difficulty = DIFFICULTY_EASY;
				}
			} else if (StrEqual(sInfo, "nodes")) {
				OpenNodeEditorMenu(param1, id);
				return 0;
			}

			OpenTrackEditorMenu(param1, id);
		}
		
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenTracksMenu(param1, Action_Edit);
				g_EditingTrack[param1] = NO_TRACK;
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void OpenNodeEditorMenu(int client, int id) {
	Menu menu = new Menu(MenuHandler_NodeEditor);
	menu.SetTitle("Node Editor for %s:\n - Targeted Node: %i", g_Tracks[id].name, g_EditingNode[client]);

	menu.AddItem("add", "Add Node");
	menu.AddItem("target", "Target Node");
	menu.AddItem("remove", "Remove Node");
	menu.AddItem("move", "Move Node");
	menu.AddItem("color", "Change Color");

	PushMenuInt(menu, "id", id);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_NodeEditor(Menu menu, MenuAction action, int param1, int param2) {
	int id = GetMenuInt(menu, "id");

	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "add")) {
				g_EditingNode[param1] = g_Tracks[id].GetTotalNodes();

				float origin[3];
				origin = GetOrigin(param1, 10.0);

				int color[4] = {255, 255, 255, 255};
				g_Tracks[id].AddNode(origin, color);

				OpenAddNodeMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "target")) {
				g_EditingNode[param1] = GetNearestNode(param1, id);
			} else if (StrEqual(sInfo, "remove")) {
				int node = g_EditingNode[param1];
				g_Tracks[id].DeleteNode(node);
			} else if (StrEqual(sInfo, "move")) {
				float origin[3];
				origin = GetOrigin(param1, 10.0);
				g_Tracks[id].GetNodeOrigin(g_EditingNode[param1], origin);
			} else if (StrEqual(sInfo, "color")) {
				OpenColorsMenu(param1, Action_Edit);
				return 0;
			}

			OpenNodeEditorMenu(param1, id);
		}
		
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenTrackEditorMenu(param1, id);
			} else {
				g_EditingTrack[param1] = NO_TRACK;
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

int GetNearestNode(int client, int id) {
	float origin[3];
	origin = GetOrigin(client);

	int node = NO_NODE;
	float origin2[3]; float origin3[3];

	for (int i = 0; i < g_Tracks[id].GetTotalNodes(); i++) {
		if (node == NO_NODE) {
			node = i;
			continue;
		}
		
		g_Tracks[id].GetNodeOrigin(i, origin2);
		g_Tracks[id].GetNodeOrigin(node, origin3);

		if (GetDistance(origin, origin2) < GetDistance(origin, origin3)) {
			node = i;
		}
	}

	return node;
}

void AskConfirmSetTrack(int client, int id) {
	Menu menu = new Menu(MenuHandler_AskConfirmSetTrack);
	menu.SetTitle("Are you sure you want to set this track as current?\n - %s", g_Tracks[id].name);

	menu.AddItem("Yes", "Yes");
	menu.AddItem("No", "No");

	PushMenuInt(menu, "id", id);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AskConfirmSetTrack(Menu menu, MenuAction action, int param1, int param2) {
	int id = GetMenuInt(menu, "id");

	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "Yes")) {
				if (SetTrack(id)) {
					CPrintToChat(param1, "%s%T", PLUGIN_TAG, "track set successfully", param1);
				} else {
					CPrintToChat(param1, "%s%T", PLUGIN_TAG, "track set failed", param1);
				}
			} else if (StrEqual(sInfo, "No")) {
				CPrintToChat(param1, "%s%T", PLUGIN_TAG, "track not changed", param1);
			}

			OpenTracksMenu(param1, Action_Set);
		}
		
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenTracksMenu(param1, Action_Set);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

bool SetTrack(int id, bool verbose = true) {
	if (id < NO_TRACK || id > g_TotalTracks) {
		return false;
	}

	g_State.track = id;
	g_API.Call_OnTrackSet(g_State.track);
	
	if (verbose) {
		if (g_State.track != NO_TRACK) {
			CPrintToChatAll("%s%t", PLUGIN_TAG, "track set to existing", g_Tracks[id].name);
		} else {
			CPrintToChatAll("%s%t", PLUGIN_TAG, "track set to none");
		}
	}

	ParseObjects(g_TracksPath, g_State.track);
	CreateTrackEnts();
	
	return true;
}

void CreateTrackEnts() {
	ClearTrackEnts();

	if (convar_Pathing_Rendering.IntValue != 1) {
		return;
	}

	int track = g_State.track;

	if (track == NO_TRACK) {
		return;
	}

	if (convar_Pathing.BoolValue) {		
		int length = g_Tracks[track].GetTotalNodes();
		float origin[3]; int color[4];
		float origin2[3];

		int StartFrame = 0;
		int FrameRate = 0;
		float Life = 0.1;
		float Width = convar_Pathing_Width.FloatValue;
		//float EndWidth = convar_Pathing_Width.FloatValue;
		//int FadeLength = 0;
		float Amplitude = 0.0;
		int Speed = 0;

		for (int i = 0; i < length; i++) {
			g_Tracks[track].GetNodeOrigin(i, origin);

			if ((i + 1) >= length) {
				continue;
			}

			g_Tracks[track].GetNode((i+1), origin2, color);

			int entity = CreateEntityByName("env_beam");

			if (!IsValidEntity(entity)) {
				continue;
			}

			char sColor[64];
			FormatEx(sColor, sizeof(sColor), "%i %i %i", color[0], color[1], color[2]);

			DispatchKeyValueVector(entity, "origin", origin);
			DispatchKeyValueFloat(entity, "BoltWidth", Width);
			DispatchKeyValueInt(entity, "damage", 0);
			DispatchKeyValue(entity, "decalname", "BigShot");
			DispatchKeyValueInt(entity, "framerate", FrameRate);
			DispatchKeyValueInt(entity, "framestart", StartFrame);
			DispatchKeyValueFloat(entity, "HDRColorScale", 1.0);
			DispatchKeyValueFloat(entity, "life", Life);
			DispatchKeyValueInt(entity, "TouchType", 0);
			DispatchKeyValueFloat(entity, "NoiseAmplitude", Amplitude);
			DispatchKeyValueInt(entity, "TextureScroll", Speed);
			DispatchKeyValueInt(entity, "speed", Speed);
			DispatchKeyValueInt(entity, "Radius", 256);
			DispatchKeyValue(entity, "texture", "sprites/laserbeam.spr");
			DispatchKeyValueInt(entity, "renderamt", color[3]);
			DispatchKeyValueInt(entity, "StrikeTime", 1);
			DispatchKeyValue(entity, "rendercolor", sColor);
			DispatchKeyValueVector(entity, "origin", origin);
			DispatchKeyValueInt(entity, "spawnflags", 0);
			DispatchKeyValueInt(entity, "renderfx", 0);

			DispatchSpawn(entity);
			ActivateEntity(entity);

			SetEntityModel(entity, "sprites/laserbeam.vmt");

			SetEntPropVector(entity, Prop_Send, "m_vecEndPos", origin2);
			SetEntProp(entity, Prop_Send, "m_nHaloIndex", g_HaloIndex);

			AcceptEntityInput(entity, "TurnOn");
			g_BeamEnts.Push(EntIndexToEntRef(entity));
		}
	}
}

void ClearTrackEnts() {
	int length = g_BeamEnts.Length;
	int entity = -1;

	for (int i = 0; i < length; i++) {
		if ((entity = EntRefToEntIndex(g_BeamEnts.Get(i))) > 0 && IsValidEntity(entity)) {
			AcceptEntityInput(entity, "Kill");
		}
	}

	g_BeamEnts.Clear();
}