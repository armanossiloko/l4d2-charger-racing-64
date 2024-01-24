enum struct Track {
	char name[64];			//The name of the track to be displayed and called.
	Difficulty difficulty;	//The difficulty of the track, this is just an arbitrary value set when creating or editing the track.
	
	//Nodes
	ArrayList node_origins;		//The list of origin points for the track which consists of 3D vectors in order. Index 0 is the start and the last index is the finish line.
	ArrayList node_colors;		//The colors that correspond to the beams of the track in corresponding order.

	//Objects
	ArrayList object_entity;	//The entities for objects spawned on the track.
	ArrayList object_origin;	//The origin points for the objects.
	ArrayList object_angles;	//The angles for the objects.
	ArrayList object_model;		//The model for the objects.
	ArrayList object_scale;		//The scale for the objects.
	ArrayList object_color;		//The color for the objects.
	ArrayList object_skin;		//The skin for the objects.

	void Init() {
		//Nodes
		this.node_origins = new ArrayList(3);
		this.node_colors = new ArrayList(4);

		//Objects
		this.object_entity = new ArrayList(ByteCountToCells(64));
		this.object_origin = new ArrayList(3);
		this.object_angles = new ArrayList(3);
		this.object_model = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
		this.object_scale = new ArrayList();
		this.object_color = new ArrayList(4);
		this.object_skin = new ArrayList();
	}

	void Delete() {
		this.name[0] = '\0';
		this.difficulty = DIFFICULTY_EASY;

		delete this.node_origins;
		delete this.node_colors;

		delete this.object_entity;
		delete this.object_origin;
		delete this.object_angles;
		delete this.object_model;
		delete this.object_scale;
		delete this.object_color;
		delete this.object_skin;
	}

	bool Valid() {
		if (strlen(this.name) == 0) {
			return false;
		}

		return true;
	}

	void Set(const char[] name, Difficulty difficulty) {
		strcopy(this.name, sizeof(Track::name), name);
		this.difficulty = difficulty;
	}

	/////////////////////////
	// Nodes
	bool ValidNodes() {
		if (this.node_origins == null || this.node_colors == null) {
			return false;
		}

		return true;
	}

	void AddNode(float origin[3], int colors[4]) {
		this.node_origins.PushArray(origin, sizeof(origin));
		this.node_colors.PushArray(colors, sizeof(colors));
	}

	void SetNode(int index, float origin[3], int colors[4]) {
		this.node_origins.SetArray(index, origin, sizeof(origin));
		this.node_colors.SetArray(index, colors, sizeof(colors));
	}

	void SetNodeOrigin(int index, float origin[3]) {
		this.node_origins.SetArray(index, origin, sizeof(origin));
	}

	void SetNodeColor(int index, int colors[4]) {
		this.node_colors.SetArray(index, colors, sizeof(colors));
	}

	int GetTotalNodes() {
		return this.node_origins.Length;
	}

	void GetNode(int index, float origin[3], int colors[4]) {
		this.node_origins.GetArray(index, origin, sizeof(origin));
		this.node_colors.GetArray(index, colors, sizeof(colors));
	}

	void GetNodeOrigin(int index, float origin[3]) {
		this.node_origins.GetArray(index, origin, sizeof(origin));
	}

	void GetNodeColor(int index, int colors[4]) {
		this.node_colors.GetArray(index, colors, sizeof(colors));
	}

	void DeleteNode(int index) {
		this.node_origins.Erase(index);
		this.node_colors.Erase(index);
	}

	void ClearNodes() {
		this.node_origins.Clear();
		this.node_colors.Clear();
	}

	/////////////////////////
	// Objects
	bool ValidObjects() {
		if (this.object_entity == null || this.object_origin == null || this.object_angles == null || this.object_model == null || this.object_scale == null || this.object_color == null || this.object_skin == null) {
			return false;
		}

		return true;
	}

	void AddObject(const char[] entity, float origin[3], float angles[3], const char[] model, float scale, int color[4], int skin) {
		this.object_entity.PushString(entity);
		this.object_origin.PushArray(origin, sizeof(origin));
		this.object_angles.PushArray(angles, sizeof(angles));
		this.object_model.PushString(model);
		this.object_scale.Push(scale);
		this.object_color.PushArray(color, sizeof(color));
		this.object_skin.Push(skin);
	}

	void SetObject(int index, const char[] entity, float origin[3], float angles[3], const char[] model, float scale, int color[4], int skin) {
		this.object_entity.SetString(index, entity);
		this.object_origin.SetArray(index, origin, sizeof(origin));
		this.object_angles.SetArray(index, angles, sizeof(angles));
		this.object_model.SetString(index, model);
		this.object_scale.Set(index, scale);
		this.object_color.SetArray(index, color, sizeof(color));
		this.object_skin.Set(index, skin);
	}

	void SetObjectEntity(int index, const char[] entity) {
		this.object_entity.SetString(index, entity);
	}

	void SetObjectOrigin(int index, float origin[3]) {
		this.object_origin.SetArray(index, origin, sizeof(origin));
	}

	void SetObjectAngles(int index, float angles[3]) {
		this.object_angles.SetArray(index, angles, sizeof(angles));
	}

	void SetObjectModel(int index, const char[] model) {
		this.object_model.SetString(index, model);
	}

	void SetObjectScale(int index, float scale) {
		this.object_scale.Set(index, scale);
	}

	void SetObjectColor(int index, int color[4]) {
		this.object_color.SetArray(index, color, sizeof(color));
	}

	void SetObjectSkin(int index, int skin) {
		this.object_skin.Set(index, skin);
	}

	int GetTotalObjects() {
		return this.object_entity.Length;
	}

	void GetObject(int index, char entity[64], float origin[3], float angles[3], char model[PLATFORM_MAX_PATH], float scale, int color[4], int skin) {
		this.object_entity.GetString(index, entity, sizeof(entity));
		this.object_origin.GetArray(index, origin, sizeof(origin));
		this.object_angles.GetArray(index, angles, sizeof(angles));
		this.object_model.GetString(index, model, sizeof(model));
		scale = this.object_scale.Get(index);
		this.object_color.GetArray(index, color, sizeof(color));
		skin = this.object_skin.Get(index);
	}

	void GetObjectEntity(int index, char[] entity, int size) {
		this.object_entity.GetString(index, entity, size);
	}

	void GetObjectOrigin(int index, float origin[3]) {
		this.object_origin.GetArray(index, origin, sizeof(origin));
	}

	void GetObjectAngles(int index, float angles[3]) {
		this.object_angles.GetArray(index, angles, sizeof(angles));
	}

	void GetObjectModel(int index, char[] model, int size) {
		this.object_model.GetString(index, model, size);
	}

	float GetObjectScale(int index) {
		return this.object_scale.Get(index);
	}

	void GetObjectColor(int index, int color[4]) {
		this.object_color.GetArray(index, color, sizeof(color));
	}

	int GetObjectSkin(int index) {
		return this.object_skin.Get(index);
	}

	void DeleteObject(int index) {
		this.object_entity.Erase(index);
		this.object_origin.Erase(index);
		this.object_angles.Erase(index);
		this.object_model.Erase(index);
		this.object_scale.Erase(index);
		this.object_color.Erase(index);
		this.object_skin.Erase(index);
	}

	void ClearObjects() {
		this.object_entity.Clear();
		this.object_origin.Clear();
		this.object_angles.Clear();
		this.object_model.Clear();
		this.object_scale.Clear();
		this.object_color.Clear();
		this.object_skin.Clear();
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

			if (kv.JumpToKey("track-objects") && kv.GotoFirstSubKey()) {
				char entity[64]; float origin[3]; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale; int color[4]; int skin;
				do {
					kv.GetString("entity", entity, sizeof(entity));
					kv.GetVector("origin", origin);
					kv.GetVector("angles", angles);
					kv.GetString("model", model, sizeof(model));
					scale = kv.GetFloat("scale");
					kv.GetColor4("color", color);
					skin = kv.GetNum("skin");
					
					g_Tracks[index].AddObject(entity, origin, angles, model, scale, color, skin);
					PrintToServer("Added object: %s", entity);
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

		if (kv.JumpToKey("track-points", true)) {
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

		if (kv.JumpToKey("track-objects", true)) {
			char sObject[16]; char entity[64]; float origin[3]; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale; int color[4]; int skin; char sColor[64];
			for (int obj = 0; obj < g_Tracks[i].GetTotalObjects(); obj++) {
				IntToString(obj, sObject, sizeof(sObject));
				kv.JumpToKey(sObject, true);

				g_Tracks[i].GetObject(obj, entity, origin, angles, model, scale, color, skin);

				kv.SetString("entity", entity);
				kv.SetVector("origin", origin);
				kv.SetVector("angles", angles);
				kv.SetString("model", model);
				kv.SetFloat("scale", scale);
				//kv.SetColor4("color", color); //Currently broken in Source.
				FormatEx(sColor, sizeof(sColor), "%i %i %i %i", color[0], color[1], color[2], color[3]);
				kv.SetString("color", sColor);
				kv.SetNum("skin", skin);

				kv.GoBack();
			}

			kv.GoBack();
		}

		kv.GoBack();
		kv.GoBack();
	}

	kv.Rewind();
	kv.ExportToFile(file);

	delete kv;
	ModeLog("Saving %d tracks to file: %s", g_TotalTracks, file);
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
	if (g_CreatingTrack[client].GetTotalNodes() == 0) {
		menu.AddItem("add_node", "Add First Node");
	} else {
		menu.AddItem("add_node", "Add Node");
	}
	menu.AddItem("total_nodes", "--- (Total Nodes: 0)");
	menu.AddItem("add_obj", "Add Object");
	menu.AddItem("total_objs", "--- (Total Objects: 0)");
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
			} else if (StrEqual(sInfo, "total_nodes")) {
				FormatEx(sDisplay, sizeof(sDisplay), "--- (Total Nodes: %d)", g_CreatingTrack[param1].GetTotalNodes());
			} else if (StrEqual(sInfo, "total_objs")) {
				FormatEx(sDisplay, sizeof(sDisplay), "--- (Total Objects: %d)", g_CreatingTrack[param1].GetTotalObjects());
			}

			return RedrawMenuItem(sDisplay);
		}

		case MenuAction_Select: {
			char sInfo[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				g_CreatingTrack[param1].Delete();
				return 0;
			}

			if (StrEqual(sInfo, "name")) {
				g_SettingName[param1] = true;
				PrintToClient(param1, "%T", "editor enter a track name", param1);
				return 0;
			} else if (StrEqual(sInfo, "difficulty")) {
				g_CreatingTrack[param1].difficulty++;

				if (g_CreatingTrack[param1].difficulty > DIFFICULTY_IMPOSSIBLE) {
					g_CreatingTrack[param1].difficulty = DIFFICULTY_EASY;
				}

			} else if (StrEqual(sInfo, "add_node")) {
				g_NewNode[param1] = g_CreatingTrack[param1].GetTotalNodes();

				float origin[3];
				origin = GetOrigin(param1, 10.0);

				int color[4] = {255, 255, 255, 255};
				g_CreatingTrack[param1].AddNode(origin, color);

				OpenAddNodeMenu(param1, Action_Create);
				return 0;
			} else if (StrEqual(sInfo, "add_obj")) {
				g_NewObj[param1] = g_CreatingTrack[param1].GetTotalObjects();

				float origin[3];
				GetClientCrosshairOrigin(param1, origin);

				char entity[64] = "info_l4d1_survivor_spawn"; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale = 1.0; int color[4] = {255, 255, 255, 255}; int skin;
				g_CreatingTrack[param1].AddObject(entity, origin, angles, model, scale, color, skin);

				g_NewObjectEnt[param1].Register(entity, origin, angles, model, scale, color, skin);
				g_NewObjectEnt[param1].Create();

				OpenAddObjectMenu(param1, Action_Create);
				return 0;

			} else if (StrEqual(sInfo, "save")) {
				if (g_CreatingTrack[param1].GetTotalNodes() >= 2 && strlen(g_CreatingTrack[param1].name) > 0) {
					SaveTrack(param1);
					return 0;
				} else {
					PrintToClient(param1, "%T", "missing data while saving", param1);
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

void SaveTrack(int client) {
	int index = g_TotalTracks++;

	//Main track data.
	strcopy(g_Tracks[index].name, sizeof(Track::name), g_CreatingTrack[client].name);
	g_Tracks[index].difficulty = g_CreatingTrack[client].difficulty;

	//Nodes.
	g_Tracks[index].node_origins = g_CreatingTrack[client].node_origins.Clone();
	g_Tracks[index].node_colors = g_CreatingTrack[client].node_colors.Clone();

	//Objects.
	g_Tracks[index].object_entity = g_CreatingTrack[client].object_entity.Clone();
	g_Tracks[index].object_origin = g_CreatingTrack[client].object_origin.Clone();
	g_Tracks[index].object_angles = g_CreatingTrack[client].object_angles.Clone();
	g_Tracks[index].object_model = g_CreatingTrack[client].object_model.Clone();
	g_Tracks[index].object_scale = g_CreatingTrack[client].object_scale.Clone();
	g_Tracks[index].object_color = g_CreatingTrack[client].object_color.Clone();
	g_Tracks[index].object_skin = g_CreatingTrack[client].object_skin.Clone();

	PrintToClient(client, "%T", "editor track save", client);
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
				if (g_State.status != STATUS_PREPARING && g_State.track == id) { 
					ReplyToClient(param1, "%T", "must be in preparation phase", param1);
					return 0;
				}

				if (DeleteTrack(id)) {
					PrintToClient(param1, "%T", "track deleted", param1);
					ParseTracks(g_TracksPath);
				} else {
					PrintToClient(param1, "%T", "track deletion failed", param1);
				}
			} else if (StrEqual(sInfo, "No")) {
				PrintToClient(param1, "%T", "track not deleted", param1);
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
	menu.AddItem("objects", "Manage Objects");

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
				PrintToClient(param1, "%T", "enter new track name", param1);
				return 0;
			} else if (StrEqual(sInfo, "difficulty")) {
				g_Tracks[id].difficulty++;

				if (g_Tracks[id].difficulty > DIFFICULTY_IMPOSSIBLE) {
					g_Tracks[id].difficulty = DIFFICULTY_EASY;
				}
			} else if (StrEqual(sInfo, "nodes")) {
				OpenNodeEditorMenu(param1, id);
				return 0;
			} else if (StrEqual(sInfo, "nodes")) {
				OpenObjectEditorMenu(param1, id);
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
					PrintToClient(param1, "%T", "track set successfully", param1);
				} else {
					PrintToClient(param1, "%T", "track set failed", param1);
				}
			} else if (StrEqual(sInfo, "No")) {
				PrintToClient(param1, "%T", "track not changed", param1);
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
			PrintToClients("%t", "track set to existing", g_Tracks[id].name);
		} else {
			PrintToClients("%t", "track set to none");
		}
	}

	CreatePathNodes();
	CreateTrackObjects();
	
	return true;
}

void SetNextTrack(int id) {
	g_State.nexttrack = id;
}