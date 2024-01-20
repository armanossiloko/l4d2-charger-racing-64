public void OnLibraryRemoved(const char[] name) {
	if (StrEqual(name, "adminmenu", false)) {
		g_AdminMenu = null;
	}
}

public void OnAdminMenuCreated(Handle aTopMenu) {
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (topmenu == g_AdminMenu && g_AdminMenuObj != INVALID_TOPMENUOBJECT) {
		return;
	}

	g_AdminMenuObj = AddToTopMenu(topmenu, "Charger Racing 64", TopMenuObject_Category, CategoryHandler, INVALID_TOPMENUOBJECT);
}

public void OnAdminMenuReady(Handle aTopMenu) {
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	if (g_AdminMenuObj == INVALID_TOPMENUOBJECT) {
		OnAdminMenuCreated(topmenu);
	}

	if (topmenu == g_AdminMenu) {
		return;
	}

	g_AdminMenu = topmenu;

	AddToTopMenu(g_AdminMenu, "sm_startrace", TopMenuObject_Item, AdminMenu_StartRace, g_AdminMenuObj, "sm_startrace", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_endrace", TopMenuObject_Item, AdminMenu_EndRace, g_AdminMenuObj, "sm_endrace", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_setmode", TopMenuObject_Item, AdminMenu_SetMode, g_AdminMenuObj, "sm_setmode", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_pause", TopMenuObject_Item, AdminMenu_Pause, g_AdminMenuObj, "sm_pause", ADMFLAG_ROOT);
	
	AddToTopMenu(g_AdminMenu, "sm_votetrack", TopMenuObject_Item, AdminMenu_VoteTrack, g_AdminMenuObj, "sm_votetrack", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_reloadtracks", TopMenuObject_Item, AdminMenu_ReloadTracks, g_AdminMenuObj, "sm_reloadtracks", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_savetracks", TopMenuObject_Item, AdminMenu_SaveTracks, g_AdminMenuObj, "sm_savetracks", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_createtrack", TopMenuObject_Item, AdminMenu_CreateTrack, g_AdminMenuObj, "sm_createtrack", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_deletetrack", TopMenuObject_Item, AdminMenu_DeleteTrack, g_AdminMenuObj, "sm_deletetrack", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_edittrack", TopMenuObject_Item, AdminMenu_EditTrack, g_AdminMenuObj, "sm_edittrack", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_settrack", TopMenuObject_Item, AdminMenu_SetTrack, g_AdminMenuObj, "sm_settrack", ADMFLAG_ROOT);
}
 
public void CategoryHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayTitle: {
			strcopy(buffer, maxlength, "Charger Racing 64");
		}
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Charger Racing 64");
		}
	}
}
 
public void AdminMenu_StartRace(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Start the Race");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_startrace");
		}
	}
}

public void AdminMenu_EndRace(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "End the Race");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_endrace");
		}
	}
}

public void AdminMenu_SetMode(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Set the Gamemode");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_setmode");
		}
	}
}

public void AdminMenu_Pause(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Pause the Timer");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_pause");
		}
	}
}
 
public void AdminMenu_VoteTrack(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Start a Track Vote");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_votetrack");
		}
	}
}
 
public void AdminMenu_ReloadTracks(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Reload Tracks");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_reloadtracks");
		}
	}
}
 
public void AdminMenu_SaveTracks(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Save Tracks");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_savetracks");
		}
	}
}
 
public void AdminMenu_CreateTrack(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Create a Track");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_createtrack");
		}
	}
}
 
public void AdminMenu_DeleteTrack(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Delete a Track");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_deletetrack");
		}
	}
}
 
public void AdminMenu_EditTrack(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Edit a Track");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_edittrack");
		}
	}
}
 
public void AdminMenu_SetTrack(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption: {
			strcopy(buffer, maxlength, "Set the Track");
		}
		case TopMenuAction_SelectOption: {
			FakeClientCommand(param, "sm_settrack");
		}
	}
}