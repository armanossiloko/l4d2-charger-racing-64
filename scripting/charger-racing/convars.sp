public void OnPathingChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	bool enabled = StringToBool(newValue);

	if (enabled) {
		if (convar_Pathing_Rendering.IntValue == 1) {
			CreatePathNodes();
		}
	} else {
		if (convar_Pathing_Rendering.IntValue == 1) {
			ClearPathNodes();
		}
	}
}

public void OnPathingRenderingChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	bool render = StringToBool(newValue);

	if (render) {
		CreatePathNodes();
	} else {
		ClearPathNodes();
	}
}

public void OnPrepareTimerChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	float timer = StringToFloat(newValue);

	//If the new timer we're setting is less than the current time then update it to reflect the new max cap.
	if (g_State.status == STATUS_PREPARING && g_State.timer > timer) {
		g_State.timer = timer;
	}
}

public void OnRacingTimerChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	float timer = StringToFloat(newValue);

	//If the new timer we're setting is less than the current time then update it to reflect the new max cap.
	if (g_State.status == STATUS_RACING && g_State.timer > timer) {
		g_State.timer = timer;
	}
}

public void OnParticleChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	//Make sure the particles precache whenever we use new ones.
	if (strlen(newValue) > 0) {
		Precache_Particle_System(newValue);
	}
}

public void OnItemSpawnsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	DeleteItems();
}

public void OnDoorsSpawnsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	DeleteDoors();
}

public void OnInfectedSpawnsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	DeleteInfected();
}

public void OnPreparationTimeChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (StrEqual(oldValue, newValue)) {
		return;
	}

	float timer = StringToFloat(newValue);

	if (g_State.status == STATUS_PREPARING && g_State.timer > timer) {
		g_State.timer = timer;
	}
}

public Action Timer_Seconds(Handle timer) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			g_Player[i].SyncHud();

			if (IsPlayerAlive(i) && g_State.status == STATUS_RACING) {
				g_Player[i].CacheSpeed();
			}
		}
	}

	return Plugin_Continue;
}