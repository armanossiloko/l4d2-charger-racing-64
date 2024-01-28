enum ObjectType {
	ObjectType_Creating,
	ObjectType_Editing,
	ObjectType_Active,
	ObjectType_Temporary,
}

enum struct Object {
	char entity[64];
	float origin[3];
	float angles[3];
	char model[PLATFORM_MAX_PATH];
	float scale;
	int color[4];
	int skin;

	int index;

	void Register(const char[] entity, float origin[3], float angles[3], const char[] model, float scale, int color[4], int skin) {
		strcopy(this.entity, sizeof(Object::entity), entity);
		this.origin = origin;
		this.angles = angles;
		strcopy(this.model, sizeof(Object::model), model);
		this.scale = scale;
		this.color = color;
		this.skin = skin;
	}

	void Clear() {
		this.entity[0] = '\0';
		this.origin = {0.0, 0.0, 0.0};
		this.angles = {0.0, 0.0, 0.0};
		this.model[0] = '\0';
		this.scale = 1.0;
		this.color = {255, 255, 255, 255};
		this.skin = 0;
	}

	void Create(ObjectType type) {
		this.Delete();

		if (StrEqual(this.entity, "info_l4d1_survivor_spawn")) {
			this.index = SpawnSurvivor(this.origin, this.angles, this.skin, type);
		} else {
			this.index = CreateEntityByName(this.entity);
		}

		if (!IsValidEntity(this.index)) {
			return;
		}

		DispatchKeyValueVector(this.index, "origin", this.origin);
		DispatchKeyValueVector(this.index, "angles", this.angles);
		DispatchKeyValue(this.index, "model", this.model);
		DispatchKeyValueFloat(this.index, "scale", this.scale);
		DispatchKeyValue(this.index, "rendercolor", ParseColor(this.color));
		DispatchKeyValueInt(this.index, "skin", this.skin);

		DispatchSpawn(this.index);
		ActivateEntity(this.index);
	}

	void SetEntity(const char[] entity, ObjectType type) {
		strcopy(this.entity, sizeof(Object::entity), entity);
		this.Delete();
		this.Create(type);
	}

	void SetOrigin(float origin[3]) {
		this.origin = origin;
		
		if (IsValidEntity(this.index)) {
			TeleportEntity(this.index, this.origin, NULL_VECTOR, NULL_VECTOR);
		}
	}

	void SetAngles(float angles[3]) {
		this.angles = angles;
		
		if (IsValidEntity(this.index)) {
			TeleportEntity(this.index, NULL_VECTOR, this.angles, NULL_VECTOR);
		}
	}

	void SetModel(const char[] model) {
		strcopy(this.model, sizeof(Object::model), model);
		
		if (IsValidEntity(this.index)) {
			SetEntityModel(this.index, this.model);
		}
	}

	void SetScale(float scale) {
		this.scale = scale;
		
		if (IsValidEntity(this.index)) {
			SetEntPropFloat(this.index, Prop_Data, "m_flModelScale", this.scale);
		}
	}

	void SetColor(int color[4]) {
		this.color = color;
		
		if (IsValidEntity(this.index)) {
			SetEntityRenderColor(this.index, this.color[0], this.color[1], this.color[2], this.color[3]);
		}
	}

	void SetSkin(int skin) {
		this.skin = skin;
		
		if (IsValidEntity(this.index)) {
			if (StrEqual(this.entity, "info_l4d1_survivor_spawn", false)) {

				if (this.skin >= 0 && this.skin <= 3) {
					SetEntProp(this.index, Prop_Send, "m_survivorCharacter", this.skin + 4);
				}

				SetCharacter(this.index, this.skin);
			} else {
				SetEntProp(this.index, Prop_Data, "m_nSkin", this.skin + 4);
			}
		}
	}

	void Delete() {
		if (IsValidEntity(this.index) && this.index > 0) {
			DeleteEntity(this.index);
		}

		this.index = 0;
	}
}

void OpenAddObjectMenu(int client, TrackAction action) {
	char entity[64]; float origin[3]; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale; int color[4]; int skin;
	switch (action) {
		case Action_Create: {
			int obj = g_NewObj[client];
			g_CreatingTrack[client].GetObject(obj, entity, origin, angles, model, scale, color, skin);
		}

		case Action_Edit: {
			int id = g_EditingTrack[client];
			int obj = g_EditingObj[client];
			g_Tracks[id].GetObject(obj, entity, origin, angles, model, scale, color, skin);
		}
	}

	Menu menu = new Menu(MenuHandler_AddObject, MENU_ACTIONS_ALL);
	menu.SetTitle("Add a new object:");

	menu.AddItem("entity", "Update Entity");
	menu.AddItem("origin", "Update Origin");

	if (StrEqual(entity, "info_l4d1_survivor_spawn", false)) {
		menu.AddItem("character", "Update Character");
	} else {
		menu.AddItem("angles", "Update Angles");
		menu.AddItem("model", "Update Model");
		menu.AddItem("scale", "Update Scale");
		menu.AddItem("skin", "Update Skin");
	}

	menu.AddItem("color", "Update Color");
	menu.AddItem("save", "Save Object");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AddObject(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_DisplayItem: {
			char sInfo[64]; char sDisplay[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

			switch (trackaction) {
				case Action_Create: {
					int obj = g_NewObj[param1];

					if (StrEqual(sInfo, "entity")) {
						char entity[64];
						g_CreatingTrack[param1].GetObjectEntity(obj, entity, sizeof(entity));
						char name[64];
						GetObjectDisplayName(entity, name, sizeof(name));
						FormatEx(sDisplay, sizeof(sDisplay), "Entity: %s", strlen(entity) > 0 ? name : "< Empty >");
					} else if (StrEqual(sInfo, "origin")) {
						float origin[3];
						g_CreatingTrack[param1].GetObjectOrigin(obj, origin);
						FormatEx(sDisplay, sizeof(sDisplay), "Origin: %.2f/%.2f/%.2f", origin[0], origin[1], origin[2]);
					} else if (StrEqual(sInfo, "angles")) {
						float angles[3];
						g_CreatingTrack[param1].GetObjectAngles(obj, angles);
						FormatEx(sDisplay, sizeof(sDisplay), "Angles: %.2f/%.2f/%.2f", angles[0], angles[1], angles[2]);
					} else if (StrEqual(sInfo, "model")) {
						char model[PLATFORM_MAX_PATH];
						g_CreatingTrack[param1].GetObjectModel(obj, model, sizeof(model));
						FormatEx(sDisplay, sizeof(sDisplay), "Model: %s", strlen(model) > 0 ? model : "< Empty >");
					} else if (StrEqual(sInfo, "scale")) {
						float scale = g_CreatingTrack[param1].GetObjectScale(obj);
						FormatEx(sDisplay, sizeof(sDisplay), "Scale: %f", scale);
					} else if (StrEqual(sInfo, "color")) {
						int color[4];
						g_CreatingTrack[param1].GetObjectColor(obj, color);
						FormatEx(sDisplay, sizeof(sDisplay), "Color: %i/%i/%i/%i", color[0], color[1], color[2], color[3]);
					} else if (StrEqual(sInfo, "skin")) {
						int skin = g_CreatingTrack[param1].GetObjectSkin(obj);
						FormatEx(sDisplay, sizeof(sDisplay), "Skin: %i", skin);
					} else if (StrEqual(sInfo, "character")) {
						int skin = g_CreatingTrack[param1].GetObjectSkin(obj);
						char name[64];
						GetCharacterName(skin, name, sizeof(name));
						FormatEx(sDisplay, sizeof(sDisplay), "Character: %s", name);
					}
				}
			}

			return RedrawMenuItem(sDisplay);
		}

		case MenuAction_DrawItem: {
			char sInfo[64]; int itemdraw;
			menu.GetItem(param2, sInfo, sizeof(sInfo), itemdraw);
			return itemdraw;
		}

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
					int obj = g_NewObj[param1];
					
					if (StrEqual(sInfo, "entity")) {
						OpenObjectEntitiesMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "origin")) {
						float origin[3];
						GetClientCrosshairOrigin(param1, origin);
						g_CreatingTrack[param1].SetObjectOrigin(obj, origin);
						g_NewObjectEnt[param1].SetOrigin(origin);
					} else if (StrEqual(sInfo, "angles")) {
						OpenObjectAnglesMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "model")) {
						OpenObjectModelsMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "scale")) {
						OpenObjectScalesMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "color")) {
						OpenObjectColorsMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "skin") || StrEqual(sInfo, "character")) {
						OpenObjectSkinsMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "save")) {
						g_NewObjectEnt[param1].Delete();
						g_NewObjectEnt[param1].Clear();
						OpenCreateTrackMenu(param1);
						return 0;
					}

					OpenAddObjectMenu(param1, Action_Create);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];

					if (StrEqual(sInfo, "entity")) {
						OpenObjectEntitiesMenu(param1, Action_Edit);
						return 0;
					} else if (StrEqual(sInfo, "origin")) {
						float origin[3];
						origin = GetOrigin(param1, 10.0);
						g_Tracks[id].SetObjectOrigin(obj, origin);
					} else if (StrEqual(sInfo, "angles")) {
						OpenObjectAnglesMenu(param1, Action_Edit);
						return 0;
					} else if (StrEqual(sInfo, "model")) {
						OpenObjectModelsMenu(param1, Action_Edit);
						return 0;
					} else if (StrEqual(sInfo, "scale")) {
						OpenObjectScalesMenu(param1, Action_Edit);
						return 0;
					} else if (StrEqual(sInfo, "color")) {
						OpenObjectColorsMenu(param1, Action_Edit);
						return 0;
					} else if (StrEqual(sInfo, "skin")) {
						OpenObjectSkinsMenu(param1, Action_Edit);
						return 0;
					} else if (StrEqual(sInfo, "save")) {
						OpenObjectEditorMenu(param1, id);
						return 0;
					}

					OpenAddObjectMenu(param1, Action_Edit);
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

void OpenObjectEditorMenu(int client, int id) {
	Menu menu = new Menu(MenuHandler_ObjectEditor, MENU_ACTIONS_ALL);
	menu.SetTitle("Object Editor for %s:\n - Targeted Object: %i", g_Tracks[id].name, g_EditingObj[client]);

	menu.AddItem("add", "Add Object");
	menu.AddItem("target", "Target Object");
	menu.AddItem("remove", "Remove Object");
	menu.AddItem("entity", "Set Object Entity");
	menu.AddItem("origin", "Set Object Origin");
	menu.AddItem("angles", "Set Object Angles");
	menu.AddItem("model", "Set Object Model");
	menu.AddItem("scale", "Set Object Scale");
	menu.AddItem("color", "Set Object Color");
	menu.AddItem("skin", "Set Object Skin");

	PushMenuInt(menu, "id", id);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ObjectEditor(Menu menu, MenuAction action, int param1, int param2) {
	int id = GetMenuInt(menu, "id");

	switch (action) {
		case MenuAction_DisplayItem: {
			char sInfo[64]; int itemdraw; char sDisplay[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo), itemdraw, sDisplay, sizeof(sDisplay));
			return RedrawMenuItem(sDisplay);
		}

		case MenuAction_DrawItem: {
			char sInfo[64]; int itemdraw;
			menu.GetItem(param2, sInfo, sizeof(sInfo), itemdraw);
			return itemdraw;
		}

		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "add")) {
				g_EditingObj[param1] = g_Tracks[id].GetTotalObjects();

				float origin[3];
				GetClientCrosshairOrigin(param1, origin);

				char entity[64] = "info_l4d1_survivor_spawn"; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale; int color[4]; int skin;
				g_Tracks[id].AddObject(entity, origin, angles, model, scale, color, skin);

				OpenAddObjectMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "target")) {
				g_EditingObj[param1] = GetNearestObj(param1, id);

				if (g_EditingObj[param1] != NO_OBJECT) {
					PrintToClient(param1, "%T", "object targeted", param1);
				} else {
					PrintToClient(param1, "%T", "no object targeted", param1);
				}

			} else if (StrEqual(sInfo, "remove")) {
				int obj = g_EditingObj[param1];

				if (obj != NO_OBJECT) {
					g_Tracks[id].DeleteObject(obj);
					PrintToClient(param1, "%T", "object removed", param1);
				} else {
					PrintToClient(param1, "%T", "no object selected", param1);
				}

			} else if (StrEqual(sInfo, "entity")) {
				OpenObjectEntitiesMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "origin")) {
				int obj = g_EditingObj[param1];

				if (obj != NO_OBJECT) {
					float origin[3];
					GetClientCrosshairOrigin(param1, origin);
					g_Tracks[id].SetObjectOrigin(obj, origin);
					PrintToClient(param1, "%T", "object origin updated", param1);
				} else {
					PrintToClient(param1, "%T", "no object selected", param1);
				}

			} else if (StrEqual(sInfo, "angles")) {
				OpenObjectAnglesMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "model")) {
				OpenObjectModelsMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "scale")) {
				OpenObjectScalesMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "color")) {
				OpenObjectColorsMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "skin")) {
				OpenObjectSkinsMenu(param1, Action_Edit);
				return 0;
			}

			OpenObjectEditorMenu(param1, id);
		}
		
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				OpenTrackEditorMenu(param1, id);
			} else {
				g_EditingObj[param1] = NO_OBJECT;
				g_EditingTrack[param1] = NO_TRACK;
			}
		}

		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

int GetNearestObj(int client, int id) {
	float origin[3];
	origin = GetOrigin(client);

	int obj = NO_OBJECT;
	float origin2[3]; float origin3[3];

	for (int i = 0; i < g_Tracks[id].GetTotalObjects(); i++) {
		g_Tracks[id].GetObjectOrigin(i, origin2);

		if (GetVectorDistance(origin, origin2) > 100.0) {
			continue;
		}

		if (obj == NO_OBJECT) {
			obj = i;
			continue;
		}
		
		g_Tracks[id].GetObjectOrigin(obj, origin3);

		if (GetDistance(origin, origin2) < GetDistance(origin, origin3)) {
			obj = i;
		}
	}

	return obj;
}

void OpenObjectEntitiesMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_ObjectEntities);
	menu.SetTitle("Select an entity:");

	menu.AddItem("prop_dynamic_override", "Prop");
	menu.AddItem("info_l4d1_survivor_spawn", "Survivor");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ObjectEntities(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sEntity[64];
			menu.GetItem(param2, sEntity, sizeof(sEntity));

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				g_CreatingTrack[param1].Delete();
				return 0;
			}

			switch (trackaction) {
				case Action_Create: {
					int obj = g_NewObj[param1];

					g_CreatingTrack[param1].SetObjectEntity(obj, sEntity);

					g_NewObjectEnt[param1].SetEntity(sEntity, ObjectType_Creating);

					OpenObjectEntitiesMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];

					g_Tracks[id].SetObjectEntity(obj, sEntity);

					OpenObjectEditorMenu(param1, id);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				switch (trackaction) {
					case Action_Create: {
						OpenAddObjectMenu(param1, trackaction);
					}

					case Action_Edit: {
						int id = g_EditingTrack[param1];
						OpenObjectEditorMenu(param1, id);
					}
				}
			} else {
				switch (trackaction) {
					case Action_Create: {
						g_CreatingTrack[param1].Delete();
					}

					case Action_Edit: {
						g_EditingTrack[param1] = NO_TRACK;
						g_EditingObj[param1] = NO_OBJECT;
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

void OpenObjectAnglesMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_ObjectAngles);
	menu.SetTitle("Change Object Angles:");

	menu.AddItem("+x", "+ X");
	menu.AddItem("-x", "- X");
	menu.AddItem("+y", "+ Y");
	menu.AddItem("-y", "- Y");
	menu.AddItem("+z", "+ Z");
	menu.AddItem("-z", "- Z");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ObjectAngles(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				g_CreatingTrack[param1].Delete();
				return 0;
			}

			switch (trackaction) {
				case Action_Create: {
					int obj = g_NewObj[param1];

					float angles[3];
					g_CreatingTrack[param1].GetObjectAngles(obj, angles);

					if (StrEqual(sInfo, "+x")) {
						angles[0] += 1.0;
					} else if (StrEqual(sInfo, "-x")) {
						angles[0] -= 1.0;
					} else if (StrEqual(sInfo, "+y")) {
						angles[1] += 1.0;
					} else if (StrEqual(sInfo, "-y")) {
						angles[1] -= 1.0;
					} else if (StrEqual(sInfo, "+z")) {
						angles[2] += 1.0;
					} else if (StrEqual(sInfo, "-z")) {
						angles[2] -= 1.0;
					}

					g_CreatingTrack[param1].SetObjectAngles(obj, angles);

					g_NewObjectEnt[param1].SetAngles(angles);

					OpenObjectAnglesMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];

					if (obj == NO_OBJECT) {
						PrintToClient(param1, "%T", "no object selected", param1);
						OpenObjectEditorMenu(param1, id);
						return 0;
					}

					float angles[3];
					g_Tracks[id].GetObjectAngles(obj, angles);

					if (StrEqual(sInfo, "+x")) {
						angles[0] += 1.0;
					} else if (StrEqual(sInfo, "-x")) {
						angles[0] -= 1.0;
					} else if (StrEqual(sInfo, "+y")) {
						angles[1] += 1.0;
					} else if (StrEqual(sInfo, "-y")) {
						angles[1] -= 1.0;
					} else if (StrEqual(sInfo, "+z")) {
						angles[2] += 1.0;
					} else if (StrEqual(sInfo, "-z")) {
						angles[2] -= 1.0;
					}

					g_Tracks[id].SetObjectAngles(obj, angles);

					OpenObjectEditorMenu(param1, id);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				switch (trackaction) {
					case Action_Create: {
						OpenAddObjectMenu(param1, trackaction);
					}

					case Action_Edit: {
						int id = g_EditingTrack[param1];
						OpenObjectEditorMenu(param1, id);
					}
				}
			} else {
				switch (trackaction) {
					case Action_Create: {
						g_CreatingTrack[param1].Delete();
					}

					case Action_Edit: {
						g_EditingTrack[param1] = NO_TRACK;
						g_EditingObj[param1] = NO_OBJECT;
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

void OpenObjectModelsMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_ObjectModels);
	menu.SetTitle("Choose Object Model:");

	int stringTable = FindStringTable("modelprecache");
	int numStrings = GetStringTableNumStrings(stringTable);

	char strModel[PLATFORM_MAX_PATH]; char display[PLATFORM_MAX_PATH];
	for (int i = 0; i < numStrings; i++) {
		ReadStringTable(stringTable, i, strModel, sizeof(strModel));

		if (StrContains(strModel, "models/props", false) != 0 || StrContains(strModel, ".mdl", false) == -1) {
			continue;
		}

		GetModelName(strModel, display, sizeof(display));

		if (strlen(display) == 0) {
			continue;
		}

		menu.AddItem(strModel, display);
	}

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void GetModelName(const char[] model, char[] display, int size) {
	char part[16][64];
	int found = ExplodeString(model, "/", part, 16, 64);
	strcopy(display, size, part[found-1]);
}

public int MenuHandler_ObjectModels(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sModel[PLATFORM_MAX_PATH];
			menu.GetItem(param2, sModel, sizeof(sModel));

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				g_CreatingTrack[param1].Delete();
				return 0;
			}

			switch (trackaction) {
				case Action_Create: {
					int obj = g_NewObj[param1];

					g_CreatingTrack[param1].SetObjectModel(obj, sModel);

					g_NewObjectEnt[param1].SetModel(sModel);

					OpenObjectModelsMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];

					if (obj == NO_OBJECT) {
						PrintToClient(param1, "%T", "no object selected", param1);
						OpenObjectEditorMenu(param1, id);
						return 0;
					}

					g_Tracks[id].SetObjectModel(obj, sModel);

					OpenObjectEditorMenu(param1, id);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				switch (trackaction) {
					case Action_Create: {
						OpenAddObjectMenu(param1, trackaction);
					}

					case Action_Edit: {
						int id = g_EditingTrack[param1];
						OpenObjectEditorMenu(param1, id);
					}
				}
			} else {
				switch (trackaction) {
					case Action_Create: {
						g_CreatingTrack[param1].Delete();
					}

					case Action_Edit: {
						g_EditingTrack[param1] = NO_TRACK;
						g_EditingObj[param1] = NO_OBJECT;
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

void OpenObjectScalesMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_ObjectScales);
	menu.SetTitle("Change Object Scale:");

	menu.AddItem("+0.1", " + 0.1");
	menu.AddItem("-0.1", " - 0.1");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ObjectScales(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				g_CreatingTrack[param1].Delete();
				return 0;
			}

			switch (trackaction) {
				case Action_Create: {
					int obj = g_NewObj[param1];

					float scale = g_CreatingTrack[param1].GetObjectScale(obj);

					if (StrEqual(sInfo, "+0.1")) {
						scale += 0.1;
					} else if (StrEqual(sInfo, "-0.1")) {
						scale -= 0.1;
					}

					g_CreatingTrack[param1].SetObjectScale(obj, scale);

					g_NewObjectEnt[param1].SetScale(scale);

					OpenObjectScalesMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];

					if (obj == NO_OBJECT) {
						PrintToClient(param1, "%T", "no object selected", param1);
						OpenObjectEditorMenu(param1, id);
						return 0;
					}

					float scale = g_Tracks[id].GetObjectScale(obj);

					if (StrEqual(sInfo, "+0.1")) {
						scale += 0.1;
					} else if (StrEqual(sInfo, "-0.1")) {
						scale -= 0.1;
					} else if (StrEqual(sInfo, "+1.0")) {
						scale += 1.0;
					} else if (StrEqual(sInfo, "-1.0")) {
						scale -= 1.0;
					}

					g_Tracks[id].SetObjectScale(obj, scale);

					OpenObjectEditorMenu(param1, id);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				switch (trackaction) {
					case Action_Create: {
						OpenAddObjectMenu(param1, trackaction);
					}

					case Action_Edit: {
						int id = g_EditingTrack[param1];
						OpenObjectEditorMenu(param1, id);
					}
				}
			} else {
				switch (trackaction) {
					case Action_Create: {
						g_CreatingTrack[param1].Delete();
					}

					case Action_Edit: {
						g_EditingTrack[param1] = NO_TRACK;
						g_EditingObj[param1] = NO_OBJECT;
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

void OpenObjectColorsMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_ObjectColors);
	menu.SetTitle("Select a color:");

	menu.AddItem("255 255 255 255", "None");
	menu.AddItem("255 0 0 255", "Red");
	menu.AddItem("0 255 0 255", "Green");
	menu.AddItem("0 0 255 255", "Blue");
	menu.AddItem("255 255 0 255", "Yellow");
	menu.AddItem("255 0 255 255", "Magenta");
	menu.AddItem("0 255 255 255", "Cyan");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ObjectColors(Menu menu, MenuAction action, int param1, int param2) {
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
					int obj = g_NewObj[param1];

					g_CreatingTrack[param1].SetObjectColor(obj, color);

					g_NewObjectEnt[param1].SetColor(color);

					OpenObjectColorsMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];

					if (obj == NO_OBJECT) {
						PrintToClient(param1, "%T", "no object selected", param1);
						OpenObjectEditorMenu(param1, id);
						return 0;
					}

					g_Tracks[id].SetObjectColor(obj, color);

					OpenObjectEditorMenu(param1, id);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				switch (trackaction) {
					case Action_Create: {
						OpenAddObjectMenu(param1, trackaction);
					}

					case Action_Edit: {
						int id = g_EditingTrack[param1];
						OpenObjectEditorMenu(param1, id);
					}
				}
			} else {
				switch (trackaction) {
					case Action_Create: {
						g_CreatingTrack[param1].Delete();
					}

					case Action_Edit: {
						g_EditingTrack[param1] = NO_TRACK;
						g_EditingObj[param1] = NO_OBJECT;
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

void OpenObjectSkinsMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_ObjectSkins);
	menu.SetTitle("Select a skin:");

	bool survivors;
	switch (action) {
		case Action_Create: {
			int obj = g_NewObj[client];

			char entity[64];
			g_CreatingTrack[client].GetObjectEntity(obj, entity, sizeof(entity));

			survivors = StrEqual(entity, "info_l4d1_survivor_spawn", false);
		}

		case Action_Edit: {
			int id = g_EditingTrack[client];
			int obj = g_EditingObj[client];

			char entity[64];
			g_Tracks[id].GetObjectEntity(obj, entity, sizeof(entity));

			survivors = StrEqual(entity, "info_l4d1_survivor_spawn", false);
		}
	}

	if (survivors) {
		menu.AddItem("0", "Nick");
		menu.AddItem("1", "Rochelle");
		menu.AddItem("2", "Coach");
		menu.AddItem("3", "Ellis");
		menu.AddItem("4", "Bill");
		menu.AddItem("5", "Francis");
		menu.AddItem("6", "Zoey");
		menu.AddItem("7", "Louis");
	} else {
		menu.AddItem("0", "0");
		menu.AddItem("1", "1");
		menu.AddItem("2", "2");
		menu.AddItem("3", "3");
		menu.AddItem("4", "4");
		menu.AddItem("5", "5");
		menu.AddItem("6", "6");
		menu.AddItem("7", "7");
		menu.AddItem("8", "8");
	}

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ObjectSkins(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sSkin[16];
			menu.GetItem(param2, sSkin, sizeof(sSkin));

			if (g_State.status != STATUS_PREPARING) { 
				ReplyToClient(param1, "%T", "must be in preparation phase", param1);
				g_CreatingTrack[param1].Delete();
				return 0;
			}

			int skin = StringToInt(sSkin);

			switch (trackaction) {
				case Action_Create: {
					int obj = g_NewObj[param1];

					g_CreatingTrack[param1].SetObjectSkin(obj, skin);

					g_NewObjectEnt[param1].SetSkin(skin);

					OpenObjectSkinsMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];

					if (obj == NO_OBJECT) {
						PrintToClient(param1, "%T", "no object selected", param1);
						OpenObjectEditorMenu(param1, id);
						return 0;
					}

					g_Tracks[id].SetObjectSkin(obj, skin);

					OpenObjectEditorMenu(param1, id);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				switch (trackaction) {
					case Action_Create: {
						OpenAddObjectMenu(param1, trackaction);
					}

					case Action_Edit: {
						int id = g_EditingTrack[param1];
						OpenObjectEditorMenu(param1, id);
					}
				}
			} else {
				switch (trackaction) {
					case Action_Create: {
						g_CreatingTrack[param1].Delete();
					}

					case Action_Edit: {
						g_EditingTrack[param1] = NO_TRACK;
						g_EditingObj[param1] = NO_OBJECT;
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

void GetObjectDisplayName(const char[] entity, char[] buffer, int size) {
	if (StrEqual(entity, "prop_dynamic_override")) {
		FormatEx(buffer, size, "Prop");
	} else if (StrEqual(entity, "info_l4d1_survivor_spawn")) {
		FormatEx(buffer, size, "Survivor");
	} else {
		FormatEx(buffer, size, "< Unknown >");
	}
}

void CreateTrackObjects() {
	ClearTrackObjects();

	int track = g_State.track;

	if (track == NO_TRACK) {
		return;
	}

	if (convar_Objects.BoolValue) {
		//float test;
		for (int i = 0; i < g_Tracks[track].GetTotalObjects(); i++) {

			char entity[64]; float origin[3]; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale; int color[4]; int skin;
			g_Tracks[track].GetObject(i, entity, origin, angles, model, scale, color, skin);

			if (StrEqual(entity, "info_l4d1_survivor_spawn", false)) {
				//PrintToServer("Creating survivor %i: [Entity: %s] [Origin: %.2f/%.2f/%.2f] [Angles: %.2f/%.2f/%.2f] [Skin: %i]", i, entity, origin[0], origin[1], origin[2], angles[0], angles[1], angles[2], skin);
				
				int ent = SpawnSurvivor(origin, angles, skin, ObjectType_Active);				

				if (!IsValidEntity(ent)) {
					continue;
				}

				g_TrackObjects.Push(EntIndexToEntRef(ent));

				int StartFrame = 0;
				int FrameRate = 0;
				float Life = 10.0;
				float Width = convar_Pathing_Width.FloatValue;
				//float EndWidth = convar_Pathing_Width.FloatValue;
				//int FadeLength = 0;
				float Amplitude = 0.0;
				int Speed = 0;

				float start_radius = convar_Point_Start_Radius.FloatValue;
				float end_radius = convar_Point_End_Radius.FloatValue;
				int current_color[4]; current_color = GetConVarColor(convar_Point_Current_Color);

				TE_SetupBeamRingPoint(origin, start_radius, end_radius, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, current_color, Speed, 0);
				TE_SendToAll();

				continue;
			}

			int ent = CreateEntityByName(entity);

			if (!IsValidEntity(ent)) {
				continue;
			}

			DispatchKeyValueVector(ent, "origin", origin);
			DispatchKeyValueVector(ent, "angles", angles);
			DispatchKeyValue(ent, "model", model);
			DispatchKeyValueFloat(ent, "scale", scale);
			DispatchKeyValueInt(ent, "renderamt", color[3]);
			DispatchKeyValueInt(ent, "rendermode", 0);
			DispatchKeyValueInt(ent, "renderfx", 0);
			DispatchKeyValueInt(ent, "skin", skin);

			DispatchSpawn(ent);
			ActivateEntity(ent);

			g_TrackObjects.Push(EntIndexToEntRef(ent));
		}
	}
}

void ClearTrackObjects() {
	int length = g_TrackObjects.Length;
	int entity = -1;

	for (int i = 0; i < length; i++) {
		if ((entity = EntRefToEntIndex(g_TrackObjects.Get(i))) > 0 && IsValidEntity(entity)) {
			AcceptEntityInput(entity, "Kill");
		}
	}

	g_TrackObjects.Clear();
}