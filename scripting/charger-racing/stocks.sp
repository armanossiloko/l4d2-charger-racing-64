stock bool IsModeEnabled() {
	return convar_Enabled.BoolValue;
}

stock void PrintToClient(int client, const char[] format, any ...) {
	char mode[64];
	GetModeName(g_State.mode, mode, sizeof(mode));

	char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 3);
	CPrintToChat(client, "%T%s", "print tag", client, mode, buffer);
}

stock void PrintToClients(const char[] format, any ...) {
	char mode[64];
	GetModeName(g_State.mode, mode, sizeof(mode));

	char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 2);
	CPrintToChatAll("%t%s", "print tag", mode, buffer);
}

stock void ReplyToClient(int client, const char[] format, any ...) {
	char mode[64];
	GetModeName(g_State.mode, mode, sizeof(mode));

	char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 3);
	CReplyToCommand(client, "%T%s", "print tag", client, mode, buffer);
}

stock void PrintHintTextToClients(const char[] format, any ...) {
	char mode[64];
	GetModeName(g_State.mode, mode, sizeof(mode));

	char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 2);
	PrintHintTextToAll("%t%s", "print tag no color", mode, buffer);
}

stock void ModeLog(const char[] format, any ...) {
	char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 2);

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "logs/charger-racing.log");

	LogToFileEx(path, "[Charger-Racing] %s", buffer);
	PrintToServer("[Charger-Racing] %s", buffer);
}

stock void CreateFolders() {
	BuildPath(Path_SM, g_ConfigsFolder, sizeof(g_ConfigsFolder), "configs/charger-racing/");
	if (!DirExists(g_ConfigsFolder)) {
		CreateDirectory(g_ConfigsFolder, 511);
	}

	BuildPath(Path_SM, g_DataFolder, sizeof(g_DataFolder), "data/charger-racing/");
	if (!DirExists(g_DataFolder)) {
		CreateDirectory(g_DataFolder, 511);
	}

	BuildPath(Path_SM, g_TracksPath, sizeof(g_TracksPath), "data/charger-racing/tracks/");
	if (!DirExists(g_TracksPath)) {
		CreateDirectory(g_TracksPath, 511);
	}
}

stock void FormatSeconds(float seconds, char[] buffer, int maxlength, const char[] format, bool precision = false) {
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

stock bool StopTimer(Handle& timer) {
	if (timer != null) {
		KillTimer(timer);
		timer = null;
		return true;
	}
	
	return false;
}

stock bool StringToColor(const char[] explode, int buffer[4], int defaultvalues[4] = {255, 255, 255, 255}) {
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

stock bool GetClientCrosshairOrigin(int client, float pOrigin[3], bool filter_players = true, float distance = 5.0)
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client))
		return false;

	float vOrigin[3]; vOrigin = GetEyePosition(client);

	float vAngles[3]; vAngles = GetEyeAngles(client);

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

stock void DropVictim(int client, int target, int stagger = 3)
{
	//Needs to be called otherwise it crashes.
	SDKCall(g_GameData.OnPummelEnded, client, "", target);

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
		vPos = GetEyePosition(target);
		StaggerClient(client, vPos);
	}

	if( stagger & (1<<1) )
	{
		vPos = GetEyePosition(client);
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
			float vPos[3]; vPos = GetOrigin(target);
			SetEntityMoveType(target, MOVETYPE_WALK);
			TeleportEntity(target, vPos, NULL_VECTOR, view_as<float>({0.0, 0.0, 0.0}));
		}
	}

	return Plugin_Continue;
}

stock void StaggerClient(int userid, float vPos[3])
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

stock bool PushMenuInt(Menu menu, const char[] id, int value) {
	if (menu == null || strlen(id) == 0) {
		return false;
	}
	
	char sBuffer[128];
	IntToString(value, sBuffer, sizeof(sBuffer));
	return menu.AddItem(id, sBuffer, ITEMDRAW_IGNORE);
}

stock int GetMenuInt(Menu menu, const char[] id, int defaultvalue = 0) {
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
stock float GetSpeed(int client) {
	float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	return SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0));
}

//Returns the origin of the client with an offset.
stock float[] GetOrigin(int client, float offset = 0.0) { 
	float origin[3];
	GetClientAbsOrigin(client, origin);
	origin[2] += offset;
	return origin;
}

//Returns the angles of the client.
stock float[] GetAngles(int client) {
	float angles[3];
	GetClientAbsAngles(client, angles);
	return angles;
}

//Returns the eye position of the client.
stock float[] GetEyePosition(int client) {
	float origin[3];
	GetClientEyePosition(client, origin);
	return origin;
}

//Returns the eye angles of the client.
stock float[] GetEyeAngles(int client) {
	float angles[3];
	GetClientEyeAngles(client, angles);
	return angles;
}

//Returns the distance between two vectors.
stock float GetDistance(float origin1[3], float origin2[3]) {
	return GetVectorDistance(origin1, origin2);
}

stock int GetTeamAliveCount(int team) {
	int count;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientSourceTV(i) || !IsPlayerAlive(i) || GetClientTeam(i) != team) {
			continue;
		}

		count++;
	}

	return count;
}

stock bool StringToBool(const char[] str) {
	return view_as<bool>(StringToInt(str));
}

stock void GetCharacterName(int index, char[] buffer, int size) {
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

stock int[] GetConVarColor(ConVar convar) {
	int colors[4] = {255, 255, 255, 255};

	char sBuffer[128];
	convar.GetString(sBuffer, sizeof(sBuffer));

	if (strlen(sBuffer) == 0) {
		return colors;
	}

	char sPart[4][6];
	int iReturned = ExplodeString(sBuffer, StrContains(sBuffer, ", ") != -1 ? ", " : " ", sPart, 4, 6);

	for (int i = 0; i < iReturned; i++) {
		colors[i] = StringToInt(sPart[i]);
	}

	return colors;
}

stock void GetStateDisplayName(Status state, char[] buffer, int size) {
	switch (state) {
		case STATUS_NONE: {
			strcopy(buffer, size, "None");
		}
		case STATUS_PREPARING: {
			strcopy(buffer, size, "Preparing");
		}
		case STATUS_READY: {
			strcopy(buffer, size, "Ready");
		}
		case STATUS_RACING: {
			strcopy(buffer, size, "Racing");
		}
		case STATUS_FINISHED: {
			strcopy(buffer, size, "Finished");
		}
	}
}

stock void LookAtPoint(int client, float point[3]){
	float angles[3]; float clientEyes[3]; float resultant[3];
	clientEyes = GetEyePosition(client);
	MakeVectorFromPoints(point, clientEyes, resultant);
	GetVectorAngles(resultant, angles);
	if (angles[0] >= 270){
		angles[0] -= 270;
		angles[0] = (90-angles[0]);
	} else {
		if (angles[0] <= 90){
			angles[0] *= -1;
		}
	}
	angles[1] -= 180;
	TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
}

stock int FindAvailablePlayer() {
	int[] clients = new int[MaxClients];
	int total;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || HasGroup(i) || !g_Player[i].ready || added[i]) {
			continue;
		}

		clients[total++] = i;
	}

	if (total < 1) {
		return -1;
	}

	return clients[GetRandomInt(0, total - 1)];
}

stock bool IsPlayersAvailable() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && L4D_GetClientTeam(i) == L4DTeam_Infected) {
			return true;
		}
	}

	return false;
}

stock int GetTotalPlayers() {
	int amount;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}

		amount++;
	}

	return amount;
}

public int MenuAction_Void(Menu menu, MenuAction action, int param1, int param2) {
	return 0;
}

stock bool AllPlayersFinished() {
	for (int i = 1; i <= MaxClients; i++) {
		if (g_Player[i].playing && !g_Player[i].finished && !IsFakeClient(i)) {
			return false;
		}
	}
	return true;
}

stock bool IsPlayersPlaying() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i) && g_Player[i].playing) {
			return true;
		}
	}
	return false;
}

stock int GetWinnerForSingles() {
	int winner = -1;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || !g_Player[i].playing) {
			continue;
		}

		if (winner == -1) {
			winner = i;
			continue;
		}

		if (g_Player[i].cache_points > g_Player[winner].cache_points) {
			winner = i;
		}
	}

	return winner;
}

stock int GetWinnerGroup() {
	int winner = -1;
	int winnerpoints;
	int points;

	for (int group = 0; group < g_Groups.GetTotalGroups(); group++) {
		points = 0;

		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || !g_Groups.IsInGroup(group, i)) {
				continue;
			}

			points += g_Player[i].cache_points;
		}

		if (winner == 0) {
			winner = group;
			winnerpoints = points;
			continue;
		}

		if (points > winnerpoints) {
			winner = group;
			winnerpoints = points;
		}
	}

	return winner;
}

stock void TeleportToSurvivorPos(int client) {
	int positions[32];
	int total;

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "info_survivor_position")) != -1) {
		if (total >= 32) {
			break;
		}

		positions[total++] = entity;
	}

	if (total < 1) {
		return;
	}

	int random = positions[GetRandomInt(0, total - 1)];

	if (!IsValidEntity(random)) {
		return;
	}

	float vecOrigin[3];
	GetAbsOrigin(random, vecOrigin);

	TeleportEntity(client, vecOrigin, NULL_VECTOR, NULL_VECTOR);
}

stock void GetDifficultyName(Difficulty difficulty, char[] buffer, int size) {
	switch (difficulty) {
		case DIFFICULTY_EASY: {
			strcopy(buffer, size, "Easy");
		}

		case DIFFICULTY_NORMAL: {
			strcopy(buffer, size, "Normal");
		}

		case DIFFICULTY_HARD: {
			strcopy(buffer, size, "Hard");
		}

		case DIFFICULTY_EXPERT: {
			strcopy(buffer, size, "Expert");
		}

		case DIFFICULTY_IMPOSSIBLE: {
			strcopy(buffer, size, "Impossible");
		}
	}
}

stock int GetGroupScore(int group) {
	int[] players = new int[MaxClients];
	g_Groups.GetGroupMembers(group, players);

	int score; int client;
	for (int i = 0; i < MaxClients; i++) {
		if ((client = players[i]) == 0) {
			continue;
		}

		if (client < 1) {
			continue;
		}

		if (g_Player[client].cache_points > 0) {
			score += g_Player[client].cache_points;
		} else {
			score += g_Player[client].points;
		}
	}

	return score;
}

stock int GetTopScores(int max, int[] clients, int[] scores, bool finished = false) {
	int total = max;

	int val;
	for (int i = 1; i <= MaxClients; i++) {
		if (!g_Player[i].playing) {
			continue;
		}

		if ((finished && !g_Player[i].finished)) {
			continue;
		}

		clients[val++] = i;
	}

	SortCustom1D(clients, val, OnSortScores);

	int client;
	for (int i = 0; i < total; i++) {
		client = clients[i];

		if (g_Player[client].cache_points > 0) {
			scores[i] = g_Player[client].cache_points;
		} else {
			scores[i] = g_Player[clients[i]].points;
		}
	}

	if (total > val) {
		total = val;
	}

	return total;
}

public int OnSortScores(int elem1, int elem2, const int[] array, Handle hndl) {
	if (elem1 > elem2) {
		return -1;
	} else if (elem1 < elem2) {
		return 1;
	}

	return 0;
}

stock void ClearEntities(bool tempbots = true) {
	DeleteBots(tempbots);
	DeleteItems();
	DeleteDoors();
	DeleteInfected();
	DeleteElevators();
}

stock void DeleteBots(bool tempbots = true) {
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsFakeClient(i) || L4D_GetClientTeam(i) != L4DTeam_Survivor || g_TrackObjects.FindValue(EntIndexToEntRef(i)) != -1) {
			continue;
		}

		if (!tempbots && g_IsTemporarySurvivor[i]) {
			continue;
		}

		KickClient(i);
	}
}

stock void DeleteItems() {
	if (!convar_Spawns_Items.BoolValue) {
		return;
	}

	int entity = -1;

	while ((entity = FindEntityByClassname(entity, "item_*")) != -1) {
		RemoveEntity(entity);
	}

	entity = -1;
	while ((entity = FindEntityByClassname(entity, "weapon_*")) != -1) {
		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
		
		if (owner < 1 || owner > MaxClients) {
			RemoveEntity(entity);
		}
	}
}

stock void DeleteDoors() {
	if (!convar_Spawns_Doors.BoolValue) {
		return;
	}

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_door*")) != -1) {
		RemoveEntity(entity);
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "momentary_door")) != -1) {
		RemoveEntity(entity);
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_door*")) != -1) {
		RemoveEntity(entity);
	}
	entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_wall*")) != -1) {
		RemoveEntity(entity);
	}
}

stock void DeleteInfected() {
	if (!convar_Spawns_Infected.BoolValue) {
		return;
	}

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "infected")) != -1) {
		RemoveEntity(entity);
	}
}

stock void DeleteElevators() {
	if (!convar_Spawns_Infected.BoolValue) {
		return;
	}

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_elevator")) != -1) {
		RemoveEntity(entity);
	}
}

stock bool IsStringNumeric(const char[] str) {
	int x = 0;
	int dotsFound = 0;
	int numbersFound = 0;

	if (str[x] == '+' || str[x] == '-') {
		x++;
	}

	while (str[x] != '\0') {
		if (IsCharNumeric(str[x])) {
			numbersFound++;
		} else if (str[x] == '.') {
			dotsFound++;

			if (dotsFound > 1) {
				return false;
			}
		} else {
			return false;
		}

		x++;
	}

	return numbersFound > 0;
}

stock int FindValueInADTArray(any[] array, int size, any value, int start = 0) {
	if (start < 0) {
		start = 0;
	}

	for (int i = start; i < size; i++) {
		if (array[i] == value) {
			return i;
		}
	}

	return -1;
}

stock int FindTargetEx(int client, const char[] target, bool nobots = false, bool immunity = true) {
	int flags = COMMAND_FILTER_NO_MULTI;
	
	if (nobots) {
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	
	if (!immunity) {
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[1];
	bool tn_is_ml;
	
	if (ProcessTargetString(target, client, target_list, 1, flags, target_name, sizeof(target_name), tn_is_ml) > 0) {
		return target_list[0];
	}
	
	return -1;
}

stock int GetReadyPlayers() {
	int count;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || !g_Player[i].ready) {
			continue;
		}

		count++;
	}

	return count;
}

stock char[] ParseColor(int color[4]) {
	char buffer[32];
	Format(buffer, sizeof(buffer), "%d %d %d %d", color[0], color[1], color[2], color[3]);
	return buffer;
}

stock bool DeleteEntity(int entity) {
	if (!IsValidEntity(entity) || entity < 1) {
		return false;
	}

	RemoveEntity(entity);
	return true;
}

#define SURVBOTS_L4D1				(1 << 0) // 1
#define SURVBOTS_L4D2				(1 << 1) // 2
#define SURVBOTS_PASSING_L4D1		(1 << 2) // 4

stock int SpawnSurvivor(float origin[3], float angles[3] = NULL_VECTOR, int character = 0, ObjectType type) {
	int spawn = CreateEntityByName("info_l4d1_survivor_spawn");

	if (!IsValidEntity(spawn)) {
		return -1;
	}

	DispatchKeyValue(spawn, "character", "4");
	DispatchKeyValueVector(spawn, "origin", origin);
	DispatchKeyValueVector(spawn, "angles", angles);

	DispatchSpawn(spawn);
	ActivateEntity(spawn);
	AcceptEntityInput(spawn, "Kill");
	
	AcceptEntityInput(spawn, "SpawnSurvivor");
	
	int result = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidClient(i, true, true) || !IsPassingSurvivor(i) || !IsFakeClient(i)) {
			continue;
		}

		result = i;
		break;
	}
	
	if (result == 0 || !IsValidClient(result, false, true)) {
		return -1;
	}

	int team = L4D_TEAM_SURVIVOR;
	int survSet = SURVBOTS_L4D2;
	
	ChangeClientTeam(result, team);
	SetSurvivorChar(result, character, true, survSet);
	
	if (!IsPlayerAlive(result)) {
		RespawnSurvivor(result, origin, angles);
	}
	
	TeleportEntity(result, origin, angles, NULL_VECTOR);

	int bot_client_id = result;

	if (!IsPlayerAlive(bot_client_id)) {
		L4D_RespawnPlayer(bot_client_id);
	}

	SetCharacter(bot_client_id, character);
	TeleportEntity(bot_client_id, origin, angles, NULL_VECTOR);

	int color[3];
	switch (type) {
		case ObjectType_Creating: {
			color[0] = 255; color[1] = 255; color[2] = 0;
		}
		case ObjectType_Editing: {
			color[0] = 0; color[1] = 255; color[2] = 0;
		}
		case ObjectType_Active: {
			color[0] = 0; color[1] = 0; color[2] = 255;
		}
	}

	L4D2_SetEntityGlow(bot_client_id, L4D2Glow_Constant, 0, 5, color, false);
	g_BotType[bot_client_id] = BotType_Buff;

	return bot_client_id;
}

stock void SetCharacter(int entity, int character) {
	switch (character) {
		case 0: {
			SetClientName(entity, "Nick");
			SetEntityModel(entity, MODEL_NICK);
		}
		case 1: {
			SetClientName(entity, "Rochelle");
			SetEntityModel(entity, MODEL_ROCHELLE);
		}
		case 2: {
			SetClientName(entity, "Coach");
			SetEntityModel(entity, MODEL_COACH);
		}
		case 3: {
			SetClientName(entity, "Ellis");
			SetEntityModel(entity, MODEL_ELLIS);
		}
		case 4: {
			SetClientName(entity, "Bill");
			SetEntityModel(entity, MODEL_BILL);
		}
		case 5: {
			SetClientName(entity, "Francis");
			SetEntityModel(entity, MODEL_FRANCIS);
		}
		case 6: {
			SetClientName(entity, "Zoey");
			SetEntityModel(entity, MODEL_ZOEY);
		}
		case 7: {
			SetClientName(entity, "Louis");
			SetEntityModel(entity, MODEL_LOUIS);
		}
	}

	int weapon = -1;
	if ((weapon = GetEntPropEnt(entity, Prop_Send, "m_hActiveWeapon")) != -1) {
		RemovePlayerItem(entity, weapon);
		vCheatCommand(entity, "give", "weapon_pistol");
	}
}

stock void vCheatCommand(int client, char[] command, char[] arguments = "") {
	int iCmdFlags = GetCommandFlags(command);
	SetCommandFlags(command, iCmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, iCmdFlags | FCVAR_CHEAT);
}

static char survivor_names[8][] = { "Nick", "Rochelle", "Coach", "Ellis", "Bill", "Zoey", "Francis", "Louis"};
static char survivor_mdls[8][] = { "gambler", "producer", "coach", "mechanic", "namvet", "teenangst", "biker", "manager"};

void SetSurvivorChar(int client, int character, bool setMdl = false, int survSet = SURVBOTS_L4D2) {
	int survOffset = character;

	if (view_as<bool>(survSet & SURVBOTS_L4D1)) {
		if (character < 4) {
			survOffset += 4;

			switch (character) {
				case 2: {
					// Coach, Louis to Coach
					survOffset += 1;
				} // 2 + 4 = 6	6 + 1 = 7
				case 3: {
					// Ellis, Francis to Ellis
					survOffset -= 1;
				} // 3 + 4 = 7	7 - 1 = 6

				// Louis and Francis take place of Coach = 2 and Ellis = 3 on m_survivorCharacter
				// respectively, but Francis = 6 and Louis = 7 for the Passing team, 
				// hence this switch check.
			}
		}
	}
	
	if (IsFakeClient(client)) {
		SetClientName(client, survivor_names[survOffset]);
	}

	SetEntProp(client, Prop_Send, "m_survivorCharacter", character);

	if (setMdl) {
		char temp_str[PLATFORM_MAX_PATH+1];
		Format(temp_str, sizeof(temp_str), "models/survivors/survivor_%s.mdl", survivor_mdls[survOffset]);

		if (!IsModelPrecached(temp_str)) {
			PrecacheModel(temp_str);
		}

		SetEntityModel(client, temp_str);
	}
}

stock bool IsPassingSurvivor(int client) {
	return (GetClientTeam(client) == L4D_TEAM_FOUR);
}

stock bool IsValidClient(int client, bool replaycheck = true, bool isLoop = false) {
	if ((isLoop || client > 0 && client <= MaxClients) && IsClientInGame(client)) {
		if (replaycheck) {
			if (IsClientSourceTV(client) || IsClientReplay(client)) {
				return false;
			}
		}

		return true;
	}
	
	return false;
}

stock void RespawnSurvivor(int client, const float origin[3], const float angles[3]) {
	// We respawn the player via rescue entity; we don't need a signature at all!
	int rescue_ent = CreateEntityByName("info_survivor_rescue");
	
	if (!IsValidEntity(rescue_ent)) {
		return;
	}

	AcceptEntityInput(rescue_ent, "Kill");
	
	TeleportEntity(rescue_ent, origin, angles, NULL_VECTOR);
	
	char cl_model[PLATFORM_MAX_PATH];
	GetClientModel(client, cl_model, sizeof(cl_model));
	SetEntityModel(rescue_ent, cl_model);
	
	DispatchSpawn(rescue_ent);
	ActivateEntity(rescue_ent);
	
	DispatchKeyValue(rescue_ent, "nextthink", "10.0");
	
	SetEntPropEnt(rescue_ent, Prop_Send, "m_survivor", client);
	AcceptEntityInput(rescue_ent, "Rescue");
	
	SetEntityHealth(client, GetEntProp(client, Prop_Send, "m_iMaxHealth"));
}

stock float GetBotPointsMultiplier(int client) {
	int bot = L4D2_GetInfectedAttacker(client);

	if (!IsValidEntity(bot)) {
		return 0.0;
	}

	switch (g_BotType[bot]) {
		case BotType_Normal: {
			return 0.0;
		}
		case BotType_Buff: {
			return 1.20;
		}
		case BotType_Debuff: {
			return 0.80;
		}
	}

	return 0.0;
}