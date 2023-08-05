void FormatSeconds(float seconds, char[] buffer, int maxlength, const char[] format, bool precision = false) {
	int t = RoundToFloor(seconds);

	int day; char sDay[32];
	if (t >= 86400) {
		day = RoundToFloor(t / 86400.0);
		t = t % 86400;

		Format(sDay, sizeof(sDay), "%02d", day);
	}

	int hour; char sHour[32];
	if (t >= 3600) {
		hour = RoundToFloor(t / 3600.0);
		t = t % 3600;

		Format(sHour, sizeof(sHour), "%02d", hour);
	}

	int mins; char sMinute[32];
	if (t >= 60) {
		mins = RoundToFloor(t / 60.0);
		t = t % 60;

		Format(sMinute, sizeof(sMinute), "%02d", mins);
	}

	char sSeconds[32];
	switch (precision) {
		case true: {
			Format(sSeconds, sizeof(sSeconds), "%05.2f", float(t) + seconds - RoundToFloor(seconds));
		}
		case false: {
			Format(sSeconds, sizeof(sSeconds), "%02d", t);
		}
	}

	strcopy(buffer, maxlength, format);

	ReplaceString(buffer, maxlength, "%D", strlen(sDay) > 0 ? sDay : "00");
	ReplaceString(buffer, maxlength, "%H", strlen(sHour) > 0 ? sHour : "00");
	ReplaceString(buffer, maxlength, "%M", strlen(sMinute) > 0 ? sMinute : "00");
	ReplaceString(buffer, maxlength, "%S", strlen(sSeconds) > 0 ? sSeconds : "00");
}

bool StopTimer(Handle& timer) {
	if (timer != null) {
		KillTimer(timer);
		timer = null;
		return true;
	}
	
	return false;
}

bool StringToColor(const char[] explode, int buffer[4], int defaultvalues[4] = {255, 255, 255, 255}) {
	if (strlen(explode) == 0) {
		buffer[0] = defaultvalues[0]; buffer[1] = defaultvalues[1]; buffer[2] = defaultvalues[2]; buffer[3] = defaultvalues[3];
		return false;
	}

	char sPart[4][32];
	int iReturned = ExplodeString(explode, StrContains(explode, ",") != -1 ? ", " : " ", sPart, 4, 32);

	if (iReturned != 4) {
		buffer[0] = defaultvalues[0]; buffer[1] = defaultvalues[1]; buffer[2] = defaultvalues[2]; buffer[3] = defaultvalues[3];
		return false;
	}

	buffer[0] = StringToInt(sPart[0]); buffer[1] = StringToInt(sPart[1]); buffer[2] = StringToInt(sPart[2]); buffer[3] = StringToInt(sPart[3]);
	return true;
}

bool GetClientCrosshairOrigin(int client, float pOrigin[3], bool filter_players = true, float distance = 5.0)
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client))
		return false;

	float vOrigin[3];
	GetClientEyePosition(client,vOrigin);

	float vAngles[3];
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, filter_players ? TraceEntityFilterPlayer : TraceEntityFilterNone, client);
	bool bReturn = TR_DidHit(trace);

	if (bReturn)
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace);

		float vBuffer[3];
		GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);

		pOrigin[0] = vStart[0] + (vBuffer[0] * -distance);
		pOrigin[1] = vStart[1] + (vBuffer[1] * -distance);
		pOrigin[2] = vStart[2] + (vBuffer[2] * -distance);
	}

	delete trace;
	return bReturn;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data) {
	return entity > MaxClients || !entity;
}

public bool TraceEntityFilterNone(int entity, int contentsMask, any data) {
	return entity != data;
}

void DropVictim(int client, int target, int stagger = 3)
{
	//Needs to be called otherwise it crashes.
	SDKCall(g_hSDK_OnPummelEnded, client, "", target);

	SetEntPropEnt(client, Prop_Send, "m_carryVictim", -1);
	SetEntPropEnt(target, Prop_Send, "m_carryAttacker", -1);

	float vPos[3];

	vPos[0] = 50.0;
	SetVariantString("!activator");
	AcceptEntityInput(target, "SetParent", client);
	TeleportEntity(target, vPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(target, "ClearParent");

	// Fix stuck in flying animation bug, 0.3 seems enough to cover, any earlier may not always detect the falling anim
	CreateTimer(0.3, TimerFixAnim, GetClientUserId(target));

	// Event
	Event hEvent = CreateEvent("charger_carry_end");
	if( hEvent )
	{
		hEvent.SetInt("userid", GetClientUserId(client));
		hEvent.SetInt("victim", GetClientUserId(target));
		hEvent.Fire();
	}

	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityMoveType(target, MOVETYPE_WALK);

	// Stagger
	if( stagger & (1<<0) )
	{
		GetClientEyePosition(target, vPos);
		StaggerClient(client, vPos);
	}

	if( stagger & (1<<1) )
	{
		GetClientEyePosition(client, vPos);
		StaggerClient(target, vPos);
	}
}

public Action TimerFixAnim(Handle timer, int target)
{
	target = GetClientOfUserId(target);
	if( target && IsPlayerAlive(target) )
	{
		int seq = GetEntProp(target, Prop_Send, "m_nSequence");
		// "ACT_TERROR_FALL" sequence number
		if( seq == 650 || seq == 665 || seq == 661 || seq == 651 || seq == 554 || seq == 551 ) // Coach, Ellis, Nick, Rochelle, Francis/Zoey, Bill/Louis
		{
			float vPos[3];
			vPos = GetOrigin(target);
			SetEntityMoveType(target, MOVETYPE_WALK);
			TeleportEntity(target, vPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		}
	}

	return Plugin_Continue;
}

void StaggerClient(int userid, float vPos[3])
{
	userid = GetClientUserId(userid);
	int logic = CreateEntityByName("logic_script");
	if( logic == INVALID_ENT_REFERENCE )
	{
		LogError("Could not create 'logic_script");
		return;
	}
	DispatchSpawn(logic);

	char sBuffer[96];
	Format(sBuffer, sizeof(sBuffer), "GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", userid, RoundFloat(vPos[0]), RoundFloat(vPos[1]), RoundFloat(vPos[2]));
	SetVariantString(sBuffer);
	AcceptEntityInput(logic, "RunScriptCode");
	RemoveEntity(logic);
}

bool PushMenuInt(Menu menu, const char[] id, int value) {
	if (menu == null || strlen(id) == 0) {
		return false;
	}
	
	char sBuffer[128];
	IntToString(value, sBuffer, sizeof(sBuffer));
	return menu.AddItem(id, sBuffer, ITEMDRAW_IGNORE);
}

int GetMenuInt(Menu menu, const char[] id, int defaultvalue = 0) {
	if (menu == null || strlen(id) == 0) {
		return defaultvalue;
	}
	
	char info[128]; char data[128];
	for (int i = 0; i < menu.ItemCount; i++) {
		if (menu.GetItem(i, info, sizeof(info), _, data, sizeof(data)) && StrEqual(info, id)) {
			return StringToInt(data);
		}
	}
	
	return defaultvalue;
}

//Returns the speed of the client based on velocity.
float GetSpeed(int client) {
	float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	return SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0));
}

//Returns the origin of the client with an offset.
float[] GetOrigin(int client, float offset = 0.0) { 
	float origin[3];
	GetClientAbsOrigin(client, origin);
	origin[2] += offset;
	return origin;
}

//Returns the distance between two vectors.
float GetDistance(float origin1[3], float origin2[3]) {
	return GetVectorDistance(origin1, origin2);
}

int GetTeamAliveCount(int team) {
	int count;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientSourceTV(i) || !IsPlayerAlive(i) || GetClientTeam(i) != team) {
			continue;
		}

		count++;
	}

	return count;
}

bool StringToBool(const char[] str) {
	return view_as<bool>(StringToInt(str));
}

void GetCharacterName(int index, char[] buffer, int size) {
	switch (index) {
		case 0:		// Nick
		{
			strcopy(buffer, size, "Nick");
		}
		case 1:		// Rochelle
		{
			strcopy(buffer, size, "Rochelle");
		}
		case 2:		// Coach
		{
			strcopy(buffer, size, "Coach");
		}
		case 3:		// Ellis
		{
			strcopy(buffer, size, "Ellis");
		}
		case 4:		// Bill
		{
			strcopy(buffer, size, "Bill");
		}
		case 5:		// Francis
		{
			strcopy(buffer, size, "Francis");
		}
		case 6:		// Zoey
		{
			strcopy(buffer, size, "Zoey");
		}
		case 7:		// Louis
		{
			strcopy(buffer, size, "Louis");
		}
	}
}