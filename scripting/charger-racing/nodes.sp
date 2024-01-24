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
		g_Player[client].AddPoints(total);
		PrintToClient(client, "%T", "points lost for skipping nodes", client, total, missed);
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
		PrintToClient(client, "%T", "points gained for reaching node", client, index, points, g_Player[client].points);

		//Update their current node.
		g_Player[client].currentnode = index;
	}
}

void IsNearFinish(int client) {
	if (g_Player[client].finished) {
		return;
	}

	g_Player[client].finished = true;

	int points = g_Points.Get(g_State.mode, "finished");

	if (L4D2_GetInfectedAttacker(client) != -1) {
		points += g_Points.Get(g_State.mode, "survivor");
	}

	g_Player[client].AddPoints(points);
	g_Player[client].Cache();

	char sTime[32];
	FormatSeconds(g_Player[client].cache_time, sTime, sizeof(sTime), "%M:%S", true);

	PrintToClients("%t", "finished the race", client, sTime, g_Player[client].cache_points);

	if (convar_Death_On_Finish.BoolValue) {
		ForcePlayerSuicide(client);
	}

	if (AllPlayersFinished()) {
		switch (g_State.mode) {
			case MODE_SINGLES, MODE_GROUPS: {
				int winner = GetWinnerForSingles();

				if (winner == -1) {
					PrintToClients("%t", "no winner for player");
				} else {
					points = g_Points.Get(g_State.mode, "winner");

					if (L4D2_GetInfectedAttacker(winner) != -1) {
						points += g_Points.Get(g_State.mode, "survivor");
					}
					
					g_Player[winner].AddPoints(points);
					g_Player[winner].Cache();

					g_Player[winner].stats.wins++;
					IncrementStat(winner, "wins");
					
					PrintToClients("%t", "winner for player", winner, g_Player[winner].cache_points);

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
					PrintToClients("%t", "no winner for team");
				} else {
					int[] players = new int[MaxClients];
					g_Groups.GetGroupMembers(group, players);
					
					points = g_Points.Get(g_State.mode, "winner");

					int total; int temp; int player;
					for (int i = 0; i < MaxClients; i++) {
						temp = points;
						player = players[i];

						if (player < 1) {
							continue;
						}

						if (L4D2_GetInfectedAttacker(player) != -1) {
							temp += g_Points.Get(g_State.mode, "survivor");
						}

						g_Player[player].AddPoints(temp);
						g_Player[player].Cache();

						total += g_Player[player].cache_points;

						g_Player[player].stats.wins++;
						IncrementStat(player, "wins");
					}

					for (int i = 1; i <= MaxClients; i++) {
						if (IsClientAuthorized(i) && FindValueInADTArray(players, MaxClients, i) == -1) {
							g_Player[i].stats.losses++;
							IncrementStat(i, "losses");
						}
					}

					PrintToClients("%t", "winner for team", group, total);
				}
			}
		}

		g_State.Finish();
		g_API.Call_OnEndRace();

	} else {
		if (g_State.mode == MODE_SINGLES || (g_State.mode == MODE_TEAMS && IsTeamFinished((g_State.group - 1)))) {
			g_State.PopQueue(true, 6);
		}
	}
}

void OpenAddNodeMenu(int client, TrackAction action) {
	int node;
	float origin[3]; char sColor[32];
	switch (action) {
		case Action_Create: {
			node = g_NewNode[client];

			int color[4];
			g_CreatingTrack[client].GetNode(node, origin, color);

			FormatEx(sColor, sizeof(sColor), "%d/%d/%d", color[0], color[1], color[2]);
		}

		case Action_Edit: {
			int id = g_EditingTrack[client];
			node = g_EditingNode[client];

			int color[4];
			g_Tracks[id].GetNode(node, origin, color);

			FormatEx(sColor, sizeof(sColor), "%d/%d/%d", color[0], color[1], color[2]);
		}
	}

	Menu menu = new Menu(MenuHandler_AddNode);
	if (node == 0) {
		menu.SetTitle("Add a new node:\nOrigin: %.2f/%.2f/%.2f", origin[0], origin[1], origin[2]);
	} else {
		menu.SetTitle("Add a new node:\nOrigin: %.2f/%.2f/%.2f\nColor: %s", origin[0], origin[1], origin[2], sColor);
	}

	menu.AddItem("position", "Update Position");

	if (node > 0) {
		menu.AddItem("color", "Change Color");
	}

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

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				g_CreatingTrack[param1].Delete();
				return 0;
			}

			switch (trackaction) {
				case Action_Create: {
					int node = g_NewNode[param1];
					
					if (StrEqual(sInfo, "position")) {
						float origin[3];
						origin = GetOrigin(param1, 10.0);
						g_CreatingTrack[param1].SetNodeOrigin(node, origin);
					} else if (StrEqual(sInfo, "color")) {
						OpenNodeColorsMenu(param1, Action_Create);
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
						OpenNodeColorsMenu(param1, Action_Edit);
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

void OpenNodeEditorMenu(int client, int id) {
	Menu menu = new Menu(MenuHandler_NodeEditor);
	menu.SetTitle("Node Editor for %s:\n - Targeted Node: %i", g_Tracks[id].name, g_EditingNode[client]);

	menu.AddItem("add", "Add Node");
	menu.AddItem("target", "Target Node");
	menu.AddItem("remove", "Remove Node");
	menu.AddItem("move", "Move Node");
	menu.AddItem("color", "Change Node Color");

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
				OpenNodeColorsMenu(param1, Action_Edit);
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

void OpenNodeColorsMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_NodeColors);
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

public int MenuHandler_NodeColors(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sColor[64];
			menu.GetItem(param2, sColor, sizeof(sColor));

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				g_CreatingTrack[param1].Delete();
				return 0;
			}

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

void CreatePathNodes() {
	ClearPathNodes();

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

			g_TrackNodes.Push(EntIndexToEntRef(entity));
		}
	}
}

void ClearPathNodes() {
	int length = g_TrackNodes.Length;
	int entity = -1;

	for (int i = 0; i < length; i++) {
		if ((entity = EntRefToEntIndex(g_TrackNodes.Get(i))) > 0 && IsValidEntity(entity)) {
			AcceptEntityInput(entity, "Kill");
		}
	}

	g_TrackNodes.Clear();
}