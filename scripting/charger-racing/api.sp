enum struct API {
	GlobalForward onStartRace;
	GlobalForward onEndRace;
	GlobalForward onPlayerStart;
	GlobalForward onPlayerFinish;
	GlobalForward onTrackSet;
	GlobalForward onModeSet;
	GlobalForward onStatusChange;

	void Init() {
		CreateNative("ChargerRacing_SetTrack", Native_SetTrack);
		CreateNative("ChargerRacing_GetTrack", Native_GetTrack);
		CreateNative("ChargerRacing_SetMode", Native_SetMode);
		CreateNative("ChargerRacing_GetMode", Native_GetMode);
		CreateNative("ChargerRacing_SetStatus", Native_SetStatus);
		CreateNative("ChargerRacing_GetStatus", Native_GetStatus);

		this.onStartRace = new GlobalForward("ChargerRacing_OnStartRace", ET_Ignore);
		this.onEndRace = new GlobalForward("ChargerRacing_OnEndRace", ET_Ignore);
		this.onPlayerStart = new GlobalForward("ChargerRacing_OnPlayerStart", ET_Ignore, Param_Cell);
		this.onPlayerFinish = new GlobalForward("ChargerRacing_OnPlayerFinish", ET_Ignore, Param_Cell);
		this.onTrackSet = new GlobalForward("ChargerRacing_OnTrackSet", ET_Ignore, Param_Cell);
		this.onStatusChange = new GlobalForward("ChargerRacing_OnStatusChange", ET_Ignore, Param_Cell);
	}

	void Call_OnStartRace() {
		Call_StartForward(this.onStartRace);
		Call_Finish();
	}

	void Call_OnEndRace() {
		Call_StartForward(this.onEndRace);
		Call_Finish();
	}

	void Call_OnPlayerStart(int client) {
		Call_StartForward(this.onPlayerStart);
		Call_PushCell(client);
		Call_Finish();
	}

	void Call_OnPlayerFinish(int client) {
		Call_StartForward(this.onPlayerFinish);
		Call_PushCell(client);
		Call_Finish();
	}

	void Call_OnTrackSet(int track) {
		Call_StartForward(this.onTrackSet);
		Call_PushCell(track);
		Call_Finish();
	}

	void Call_OnModeSet(Modes mode) {
		Call_StartForward(this.onModeSet);
		Call_PushCell(mode);
		Call_Finish();
	}

	void Call_OnStatusChange(Status status) {
		Call_StartForward(this.onStatusChange);
		Call_PushCell(status);
		Call_Finish();
	}
}

public int Native_SetTrack(Handle plugin, int numParams) {
	int track = GetNativeCell(1);

	if (track < 0 || track >= g_TotalTracks) {
		return 0;
	}

	return SetTrack(track);
}

public int Native_GetTrack(Handle plugin, int numParams) {
	return g_State.track;
}

public int Native_SetMode(Handle plugin, int numParams) {
	Modes mode = GetNativeCell(1);

	if (mode < MODE_SINGLES || mode > MODE_GROUPTEAMS) {
		return 0;
	}

	return SetMode(mode);
}

public int Native_GetMode(Handle plugin, int numParams) {
	return view_as<int>(g_State.mode);
}

public int Native_SetStatus(Handle plugin, int numParams) {
	Status status = GetNativeCell(1);

	if (status < STATUS_NONE || status > STATUS_FINISHED) {
		return 0;
	}

	return SetStatus(status);
}

public int Native_GetStatus(Handle plugin, int numParams) {
	return view_as<int>(g_State.status);
}