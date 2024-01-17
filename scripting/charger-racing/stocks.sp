bool IsModeEnabled() {
	return convar_Enabled.BoolValue;
}

void ModeLog(const char[] format, any ...) {
	char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 2);

	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "logs/charger-racing.log");

	LogToFileEx(path, "[Charger-Racing] %s", buffer);
	PrintToServer("[Charger-Racing] %s", buffer);
}

void CreateFolders() {
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

int[] GetConVarColor(ConVar convar) {
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

void GetStateDisplayName(Status state, char[] buffer, int size) {
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

void LookAtPoint(int client, float point[3]){
	float angles[3]; float clientEyes[3]; float resultant[3];
	GetClientEyePosition(client, clientEyes);
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

int FindAvailablePlayer() {
	int[] clients = new int[MaxClients];
	int total;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i) || HasGroup(i)) {
			continue;
		}

		clients[total++] = i;
	}

	if (total < 1) {
		return -1;
	}

	return clients[GetRandomInt(0, total - 1)];
}

bool IsPlayersAvailable() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && L4D_GetClientTeam(i) == L4DTeam_Infected) {
			return true;
		}
	}

	return false;
}

int GetTotalPlayers() {
	int amount;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsFakeClient(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
			continue;
		}

		amount++;
	}

	return amount;
}

public int MenuAction_Void(Menu menu, MenuAction action, int param1, int param2) {
	return 0;
}

bool AllPlayersFinished() {
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

int GetWinnerForSingles() {
	int winner;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || !g_Player[i].playing) {
			continue;
		}

		if (winner == 0) {
			winner = i;
			continue;
		}

		if (g_Player[i].points > g_Player[winner].points) {
			winner = i;
		}
	}

	return winner;
}

int GetWinnerGroup() {
	int winner = -1;
	int winnerpoints;
	int points;

	for (int group = 0; group < g_Groups.GetTotalGroups(); group++) {
		points = 0;

		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || !g_Groups.IsInGroup(group, i)) {
				continue;
			}

			points += g_Player[i].points;
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

void TeleportToSurvivorPos(int client) {
	int positions[16];
	int total;

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "info_survivor_position")) != -1) {
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

void GetDifficultyName(Difficulty difficulty, char[] buffer, int size) {
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

int GetChargerTeamScore(int team) {
	int score;

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && L4D_GetClientTeam(i) == L4DTeam_Infected && g_Player[i].team == team) {
			score += g_Player[i].points;
		}
	}

	return score;
}

int GetTopScores(int max, int[] clients, int[] scores, bool finished = false) {
	int total = max;

	if (total >= GetTeamAliveCount(3)) {
		total = GetTeamAliveCount(3);
	}

	int val;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || L4D_GetClientTeam(i) != L4DTeam_Infected || (finished && g_Player[i].finished)) {
			continue;
		}

		clients[val++] = i;
	}

	SortCustom1D(clients, val, OnSortScores);

	for (int i = 0; i < total; i++) {
		scores[i] = g_Player[clients[i]].points;
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

void KickBots() {
	for (int i = 0; i < g_TotalObjects; i++) {
		if (g_Objects[i].IsSurvivor()) {
			g_Objects[i].Delete();
		}
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && L4D_GetClientTeam(i) == L4DTeam_Survivor) {
			KickClient(i);
		}
	}

	DeleteItems();
	DeleteDoors();
	DeleteInfected();
	DeleteElevators();
}

void DeleteItems() {
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

void DeleteDoors() {
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

void DeleteInfected() {
	if (!convar_Spawns_Infected.BoolValue) {
		return;
	}

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "infected")) != -1) {
		RemoveEntity(entity);
	}
}

void DeleteElevators() {
	if (!convar_Spawns_Infected.BoolValue) {
		return;
	}

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_elevator")) != -1) {
		RemoveEntity(entity);
	}
}

bool IsStringNumeric(const char[] str) {
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

int FindValueInADTArray(any[] array, int size, any value, int start = 0) {
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