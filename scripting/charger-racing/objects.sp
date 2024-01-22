void OpenAddObjectMenu(int client, TrackAction action) {
	float origin[3];
	switch (action) {
		case Action_Create: {
			int obj = g_NewObj[client];

			char entity[64]; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale; int color[4]; int skin;
			g_CreatingTrack[client].GetObject(obj, entity, origin, angles, model, scale, color, skin);
		}

		case Action_Edit: {
			int id = g_EditingTrack[client];
			int obj = g_EditingObj[client];

			char entity[64]; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale; int color[4]; int skin;
			g_Tracks[id].GetObject(obj, entity, origin, angles, model, scale, color, skin);
		}
	}

	Menu menu = new Menu(MenuHandler_AddObject);
	menu.SetTitle("Add a new object:");

	menu.AddItem("entity", "Update Entity");
	menu.AddItem("origin", "Update Origin");
	menu.AddItem("angles", "Update Angles");
	menu.AddItem("model", "Update Model");
	menu.AddItem("scale", "Update Scale");
	menu.AddItem("color", "Update Color");
	menu.AddItem("skin", "Update Skin");
	menu.AddItem("save", "Save Object");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AddObject(Menu menu, MenuAction action, int param1, int param2) {
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
					int obj = g_NewObj[param1];
					
					if (StrEqual(sInfo, "entity")) {
						OpenObjectEntitiesMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "origin")) {
						float origin[3];
						origin = GetOrigin(param1, 10.0);
						g_CreatingTrack[param1].SetObjectOrigin(obj, origin);
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
					} else if (StrEqual(sInfo, "skin")) {
						OpenObjectSkinsMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "save")) {
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
	Menu menu = new Menu(MenuHandler_ObjectEditor);
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
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "add")) {
				g_EditingObj[param1] = g_Tracks[id].GetTotalObjects();

				float origin[3];
				origin = GetOrigin(param1, 10.0);

				char entity[64]; float angles[3]; char model[PLATFORM_MAX_PATH]; float scale; int color[4]; int skin;
				g_Tracks[id].AddObject(entity, origin, angles, model, scale, color, skin);

				OpenAddObjectMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "target")) {
				g_EditingObj[param1] = GetNearestObj(param1, id);
			} else if (StrEqual(sInfo, "remove")) {
				int obj = g_EditingObj[param1];
				g_Tracks[id].DeleteObject(obj);
			} else if (StrEqual(sInfo, "entity")) {
				OpenObjectEntitiesMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "origin")) {
				float origin[3];
				origin = GetOrigin(param1, 10.0);
				g_Tracks[id].GetObjectOrigin(g_EditingObj[param1], origin);
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
		if (obj == NO_OBJECT) {
			obj = i;
			continue;
		}
		
		g_Tracks[id].GetObjectOrigin(i, origin2);
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

	menu.AddItem("info_l4d1_survivor_spawn", "Prop");
	menu.AddItem("prop_dynamic_override", "Survivor");

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
					OpenAddObjectMenu(param1, trackaction);
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
					OpenAddObjectMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];
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

	menu.AddItem("models/props_c17/furnituretable001a.mdl", "Table");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
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
					OpenAddObjectMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];
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
	menu.AddItem("+1.0", " + 1.0");
	menu.AddItem("-1.0", " - 1.0");

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
					} else if (StrEqual(sInfo, "+1.0")) {
						scale += 1.0;
					} else if (StrEqual(sInfo, "-1.0")) {
						scale -= 1.0;
					}
					g_CreatingTrack[param1].SetObjectScale(obj, scale);
					OpenAddObjectMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];
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
					OpenAddObjectMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];
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

	menu.AddItem("1", "1");
	menu.AddItem("2", "2");
	menu.AddItem("3", "3");
	menu.AddItem("4", "4");
	menu.AddItem("5", "5");

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
					OpenAddObjectMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int obj = g_EditingObj[param1];
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