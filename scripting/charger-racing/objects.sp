enum struct Object {
	char class[64];
	float origin[3];
	float angles[3];
	char model[PLATFORM_MAX_PATH];
	int skin;

	int entity;

	void Set(const char[] class, float origin[3], float angles[3], const char[] model, int skin) {
		strcopy(this.class, sizeof(Object::class), class);
		this.origin[0] = origin[0];
		this.origin[1] = origin[1];
		this.origin[2] = origin[2];
		this.angles[0] = angles[0];
		this.angles[1] = angles[1];
		this.angles[2] = angles[2];
		strcopy(this.model, sizeof(Object::model), model);
		this.skin = skin;
	}

	void Save(const char[] file, const char[] track, int index) {
		KeyValues kv = new KeyValues("racing-tracks");

		kv.ImportFromFile(file);
		kv.JumpToKey(track);
		kv.JumpToKey("track-objects", true);
		
		char sIndex[16];
		IntToString(index, sIndex, sizeof(sIndex));
		kv.JumpToKey(sIndex, true);
		
		kv.SetString("class", this.class);
		kv.SetVector("origin", this.origin);
		kv.SetVector("angles", this.angles);
		kv.SetString("model", this.model);
		kv.SetNum("skin", this.skin);

		kv.Rewind();
		kv.ExportToFile(file);

		delete kv;
	}

	void Remove(const char[] file, const char[] track, int index) {
		KeyValues kv = new KeyValues("racing-tracks");

		kv.ImportFromFile(file);
		kv.JumpToKey(track);
		kv.JumpToKey("track-objects", true);
		
		char sIndex[16];
		IntToString(index, sIndex, sizeof(sIndex));
		kv.DeleteKey(sIndex);

		kv.Rewind();
		kv.ExportToFile(file);

		delete kv;
	}

	bool IsSurvivor() {
		return StrEqual(this.class, "info_l4d1_survivor_spawn", false);
	}

	void SetClass(const char[] class) {
		this.Delete();
		strcopy(this.class, sizeof(Object::class), class);
		this.Spawn();
	}

	void SetOrigin(float origin[3]) {
		this.origin[0] = origin[0];
		this.origin[1] = origin[1];
		this.origin[2] = origin[2];
		this.Spawn();
	}

	void GetAngles(float angles[3]) {
		angles[0] = this.angles[0];
		angles[1] = this.angles[1];
		angles[2] = this.angles[2];
	}

	void SetAngles(float angles[3]) {
		this.angles[0] = angles[0];
		this.angles[1] = angles[1];
		this.angles[2] = angles[2];
		this.Spawn();
	}

	void SetModel(const char[] model) {
		strcopy(this.model, sizeof(Object::model), model);
		this.Spawn();
	}

	void SetSkin(int skin) {
		this.skin = skin;
		this.Spawn();
	}
	
	void Spawn() {
		this.Delete();

		if (StrEqual(this.class, "info_l4d1_survivor_spawn")) {
			this.entity = SpawnSurvivor(this.origin, this.angles, this.skin);
			return;
		}

		this.entity = CreateEntityByName(this.class);

		if (!IsValidEntity(this.entity)) {
			return;
		}

		DispatchKeyValueVector(this.entity, "origin", this.origin);
		DispatchKeyValueVector(this.entity, "angles", this.angles);
		DispatchKeyValue(this.entity, "model", this.model);
		DispatchKeyValueInt(this.entity, "skin", this.skin);
		DispatchSpawn(this.entity);
	}

	void Delete() {
		if (this.entity > 0 && IsValidEntity(this.entity)) {
			if (StrEqual(this.class, "info_l4d1_survivor_spawn")) {
				KickClient(this.entity);
			} else {
				RemoveEntity(this.entity);
			}
		}

		this.entity = -1;
	}

	void Clear() {
		this.class[0] = '\0';
		this.origin[0] = 0.0;
		this.origin[1] = 0.0;
		this.origin[2] = 0.0;
		this.angles[0] = 0.0;
		this.angles[1] = 0.0;
		this.angles[2] = 0.0;
		this.model[0] = '\0';
		this.skin = 0;
	}
}

enum struct ObjModel {
	char name[64];
	char path[PLATFORM_MAX_PATH];

	void Set(const char[] name, const char[] path) {
		strcopy(this.name, sizeof(ObjModel::name), name);
		strcopy(this.path, sizeof(ObjModel::path), path);
	}

	void Clear() {
		this.name[0] = '\0';
		this.path[0] = '\0';
	}
}

void ParseModels(const char[] file) {
	for (int i = 0; i < MAX_MODELS; i++) {
		g_Model[i].Clear();
	}
	g_TotalModels = 0;

	KeyValues kv = new KeyValues("models");

	if (kv.ImportFromFile(file) && kv.GotoFirstSubKey()) {
		char name[64]; char model[PLATFORM_MAX_PATH];
		do {
			kv.GetSectionName(name, sizeof(name));
			kv.GetString(NULL_STRING, model, sizeof(model));

			if (strlen(name) == 0 || strlen(model) == 0) {
				continue;
			}

			if (StrContains(model, ".mdl", false) == -1) {
				StrCat(model, sizeof(model), ".mdl");
			}

			g_Model[g_TotalModels++].Set(name, model);
			PrecacheModel(model);

		} while (kv.GotoNextKey());
	}

	delete kv;
	LogMessage("Parsed %i models from file: %s", g_TotalModels, file);
	PrintToServer("Parsed %i models from file: %s", g_TotalModels, file);
}

int SpawnSurvivor(float origin[3], float angles[3] = NULL_VECTOR, int character = 0) {
	int entity = CreateEntityByName("info_l4d1_survivor_spawn");

	if (!IsValidEntity(entity)) {
		return entity;
	}
	
	DispatchKeyValueVector(entity, "origin", origin);
	DispatchKeyValueVector(entity, "angles", angles);
	DispatchKeyValueInt(entity, "character", character);

	//By default, this entity doesn't allow us to spawn the L4D2 survivors as bots so we set them as L4D1 survivors by default then switch their model later.
	if (character >= 0 && character <= 3) {
		DispatchKeyValueInt(entity, "character", character + 4);
	}

	DispatchSpawn(entity);

	AcceptEntityInput(entity, "SpawnSurvivor");
	RemoveEntity(entity);

	//Find the bot we just spawned from the entity.
	int bot = FindLatestBot();

	if (bot == -1) {
		return -1;
	}

	//SetEntProp(bot, Prop_Send, "m_survivorCharacter", character);

	switch (character)
	{
		case 0:		// Nick
		{
			SetEntityModel(bot, MODEL_NICK);
		}
		case 1:		// Rochelle
		{
			SetEntityModel(bot, MODEL_ROCHELLE);
		}
		case 2:		// Coach
		{
			SetEntityModel(bot, MODEL_COACH);
		}
		case 3:		// Ellis
		{
			SetEntityModel(bot, MODEL_ELLIS);
		}
		case 4:		// Bill
		{
			SetEntityModel(bot, MODEL_BILL);
		}
		case 5:		// Francis
		{
			SetEntityModel(bot, MODEL_FRANCIS);
		}
		case 6:		// Zoey
		{
			SetEntityModel(bot, MODEL_ZOEY);
		}
		case 7:		// Louis
		{
			SetEntityModel(bot, MODEL_LOUIS);
		}
	}

	return bot;
}

int FindLatestBot() {
	for (int i = MaxClients; i > 0; --i) {
		if (!IsClientInGame(i)) {
			continue;
		}

		if (IsPlayerAlive(i) && IsFakeClient(i)) {
			return i;
		}
	}

	return -1;
}

void OpenSpawnPropMenu(int client) {
	Menu menu = new Menu(MenuHandler_SpawnProp, MENU_ACTIONS_ALL);
	menu.SetTitle("Manage new %s:", g_SpawningObjects[client].IsSurvivor() ? "survivor" : "prop");

	menu.AddItem("class", "Type: Object");
	menu.AddItem("origin", "Origin: 0.0/0.0/0.0");
	if (!g_SpawningObjects[client].IsSurvivor()) {
		menu.AddItem("angles", "Angles: 0.0/0.0/0.0");
		menu.AddItem("model", "Model: error.mdl");
		menu.AddItem("skin", "Skin: 0");
	} else {
		menu.AddItem("skin", "Character: Nick");
	}
	menu.AddItem("save", "Save");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SpawnProp(Menu menu, MenuAction action, int param1, int param2) {
	char sInfo[64]; int itemdraw; char sDisplay[256];
	menu.GetItem(param2, sInfo, sizeof(sInfo), itemdraw, sDisplay, sizeof(sDisplay));

	switch (action) {
		case MenuAction_DisplayItem: {
			if (StrEqual(sInfo, "class")) {
				FormatEx(sDisplay, sizeof(sDisplay), "Type: %s", g_SpawningObjects[param1].IsSurvivor() ? "Survivor" : "Prop");
			} else if (StrEqual(sInfo, "origin")) {
				FormatEx(sDisplay, sizeof(sDisplay), "Origin: %.2f/%.2f/%.2f", g_SpawningObjects[param1].origin[0], g_SpawningObjects[param1].origin[1], g_SpawningObjects[param1].origin[2]);
			} else if (StrEqual(sInfo, "angles")) {
				FormatEx(sDisplay, sizeof(sDisplay), "Angles: %.2f/%.2f/%.2f", g_SpawningObjects[param1].angles[0], g_SpawningObjects[param1].angles[1], g_SpawningObjects[param1].angles[2]);
			} else if (StrEqual(sInfo, "model")) {
				FormatEx(sDisplay, sizeof(sDisplay), "Model: %s", g_SpawningObjects[param1].model);
			} else if (StrEqual(sInfo, "skin")) {
				if (g_SpawningObjects[param1].IsSurvivor()) {
					char sSurvivor[64];
					GetCharacterName(g_SpawningObjects[param1].skin, sSurvivor, sizeof(sSurvivor));
					FormatEx(sDisplay, sizeof(sDisplay), "Character: %s", sSurvivor);
				} else {
					FormatEx(sDisplay, sizeof(sDisplay), "Skin: %i", g_SpawningObjects[param1].skin);
				}
			}
			return RedrawMenuItem(sDisplay);
		}

		case MenuAction_DrawItem: {
			return itemdraw;
		}

		case MenuAction_Select: {
			if (StrEqual(sInfo, "class")) {
				g_SpawningObjects[param1].SetClass(g_SpawningObjects[param1].IsSurvivor() ? "prop_dynamic_override" : "info_l4d1_survivor_spawn");
				CPrintToChat(param1, "%s%T", PLUGIN_TAG, "object type changed", param1, g_SpawningObjects[param1].IsSurvivor() ? "Survivor" : "Prop");
				OpenSpawnPropMenu(param1);
			} else if (StrEqual(sInfo, "origin")) {
				float origin[3];
				GetClientCrosshairOrigin(param1, origin);
				g_SpawningObjects[param1].SetOrigin(origin);
				OpenSpawnPropMenu(param1);
			} else if (StrEqual(sInfo, "angles")) {
				OpenSpawnPropAnglesMenu(param1);
			} else if (StrEqual(sInfo, "model")) {
				OpenSpawnPropModelMenu(param1);
			} else if (StrEqual(sInfo, "skin")) {
				OpenSpawnPropSkinMenu(param1);
			} else if (StrEqual(sInfo, "save")) {
				CPrintToChat(param1, "%s%T", PLUGIN_TAG, "object saved", param1, g_SpawningObjects[param1].IsSurvivor() ? "Survivor" : "Prop");
				SaveNewProp(param1);
			}
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

void OpenSpawnPropAnglesMenu(int client) {
	Menu menu = new Menu(MenuHandler_SpawnPropAngles);
	menu.SetTitle("Tweak the angles:");

	menu.AddItem("+x", "+ Pitch");
	menu.AddItem("-x", "- Pitch");
	menu.AddItem("+y", "+ Yaw");
	menu.AddItem("-y", "- Yaw");
	menu.AddItem("+z", "+ Roll");
	menu.AddItem("-z", "- Roll");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SpawnPropAngles(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			float angles[3];
			g_SpawningObjects[param1].GetAngles(angles);

			float offset = 5.0;

			if (StrEqual(sInfo, "+x")) {
				angles[0] += offset;
			} else if (StrEqual(sInfo, "-x")) {
				angles[0] -= offset;
			} else if (StrEqual(sInfo, "+y")) {
				angles[1] += offset;
			} else if (StrEqual(sInfo, "-y")) {
				angles[1] -= offset;
			} else if (StrEqual(sInfo, "+z")) {
				angles[2] += offset;
			} else if (StrEqual(sInfo, "-z")) {
				angles[2] -= offset;
			}

			g_SpawningObjects[param1].SetAngles(angles);
			OpenSpawnPropAnglesMenu(param1);
		}
		
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenSpawnPropMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void OpenSpawnPropModelMenu(int client) {
	Menu menu = new Menu(MenuHandler_SpawnPropModel);
	menu.SetTitle("Select a model:");
	
	menu.AddItem(DEFAULT_OBJECT, "Traffic Cone");

	for (int i = 0; i < g_TotalModels; i++) {
		menu.AddItem(g_Model[i].path, g_Model[i].name);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SpawnPropModel(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[PLATFORM_MAX_PATH];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			g_SpawningObjects[param1].SetModel(sInfo);
			OpenSpawnPropModelMenu(param1);
		}
		
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenSpawnPropMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void OpenSpawnPropSkinMenu(int client) {
	Menu menu = new Menu(MenuHandler_SpawnPropSkin);
	menu.SetTitle("Select a model:");

	if (g_SpawningObjects[client].IsSurvivor()) {
		menu.AddItem("0", "Character: Nick");
		menu.AddItem("1", "Character: Rochelle");
		menu.AddItem("2", "Character: Coach");
		menu.AddItem("3", "Character: Ellis");
		menu.AddItem("4", "Character: Bill");
		menu.AddItem("5", "Character: Zoey");
		menu.AddItem("6", "Character: Francis");
		menu.AddItem("7", "Character: Louis");
	} else {
		menu.AddItem("0", "Skin: 0");
		menu.AddItem("1", "Skin: 1");
		menu.AddItem("2", "Skin: 2");
		menu.AddItem("3", "Skin: 3");
		menu.AddItem("4", "Skin: 4");
		menu.AddItem("5", "Skin: 5");
		menu.AddItem("6", "Skin: 6");
		menu.AddItem("7", "Skin: 7");
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SpawnPropSkin(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			g_SpawningObjects[param1].SetSkin(StringToInt(sInfo));
			OpenSpawnPropSkinMenu(param1);
		}
		
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenSpawnPropMenu(param1);
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

void SaveNewProp(int client) {
	int index = g_TotalObjects++;
	g_Objects[index].Set(g_SpawningObjects[client].class, g_SpawningObjects[client].origin, g_SpawningObjects[client].angles, g_SpawningObjects[client].model, g_SpawningObjects[client].skin);
	g_Objects[index].Spawn();

	g_SpawningObjects[client].Save(g_TracksPath, g_Tracks[g_State.track].name, index);
	g_SpawningObjects[client].Delete();
	g_SpawningObjects[client].Clear();
}

void ParseObjects(const char[] file, int track) {
	for (int i = 0; i < MAX_OBJECTS; i++) {
		g_Objects[i].Delete();
		g_Objects[i].Clear();
	}

	g_TotalObjects = 0;

	if (track == NO_TRACK) {
		return;
	}

	if (!FileExists(file)) {
		LogError("File does not exist: %s", file);
		return;
	}

	KeyValues kv = new KeyValues("racing-tracks");

	if (kv.ImportFromFile(file) && kv.GotoFirstSubKey()) {
		char name[64]; int index;
		do {
			kv.GetSectionName(name, sizeof(name));

			if (strlen(name) == 0) {
				continue;
			}

			index = FindTrack(name);

			if (index == track && kv.JumpToKey("track-objects") && kv.GotoFirstSubKey()) {
				char class[64];
				float origin[3];
				float angles[3];
				char model[PLATFORM_MAX_PATH];
				int skin;

				do {
					kv.GetString("class", class, sizeof(class));
					kv.GetVector("origin", origin);
					kv.GetVector("angles", angles);
					kv.GetString("model", model, sizeof(model));
					if (strlen(model) > 0) {
						PrecacheModel(model);
					}
					skin = kv.GetNum("skin");
					g_Objects[g_TotalObjects++].Set(class, origin, angles, model, skin);
				} while (kv.GotoNextKey());

				kv.GoBack();
				kv.GoBack();
			}

		} while (kv.GotoNextKey());
	}

	delete kv;
	LogMessage("Parsed %d objects from file: %s", g_TotalObjects, file);
	PrintToServer("Parsed %d objects from file: %s", g_TotalObjects, file);

	SpawnObjects();
}

void SpawnObjects() {
	DeleteObjects();

	if (g_TotalObjects == 0) {
		return;
	}
	
	for (int i = 0; i < g_TotalObjects; i++) {
		g_Objects[i].Spawn();
	}
}

void DeleteObjects() {
	if (g_TotalObjects == 0) {
		return;
	}

	for (int i = 0; i < g_TotalObjects; i++) {
		g_Objects[i].Delete();
	}
}

int GetEntityObjectIndex(int entity) {
	for (int i = 0; i < g_TotalObjects; i++) {
		if (g_Objects[i].entity == entity) {
			return i;
		}
	}
	return -1;
}