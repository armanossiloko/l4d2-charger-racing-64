//Pragmas
#pragma semicolon 1
#pragma newdecls required

//Inclues
#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <left4dhooks>

//Defines
#define PLUGIN_TAG "[Racing] "
#define MAX_TRACKS 64 	//The total tracks allowed per map.
#define MAX_OBJECTS 128 //The total objects allowed per track and difficulty.
#define NO_TRACK -1 	//This is the corresponding index for data to know that this track either doesn't exist, is invalid, or is not set.
#define NO_NODE -1 		//This is the corresponding index for data to know that this node either doesn't exist, is invalid, or is not set.

#define MODEL_FRANCIS "models/survivors/survivor_biker.mdl"
#define MODEL_LOUIS "models/survivors/survivor_manager.mdl"
#define MODEL_ZOEY "models/survivors/survivor_teenangst.mdl"
#define MODEL_BILL "models/survivors/survivor_namvet.mdl"
#define MODEL_NICK "models/survivors/survivor_gambler.mdl"
#define MODEL_ROCHELLE "models/survivors/survivor_producer.mdl"
#define MODEL_COACH "models/survivors/survivor_coach.mdl"
#define MODEL_ELLIS "models/survivors/survivor_mechanic.mdl"

//ConVars
ConVar convar_Enabled;
ConVar convar_Strafing;
ConVar convar_Strafing_Scale;
ConVar convar_Jumping;
ConVar convar_Jumping_Scale;
ConVar convar_Pathing;
ConVar convar_Pathing_Width;
ConVar convar_Preparation_Timer;
ConVar convar_Racing_Countdown;
ConVar convar_Racing_Timer;
ConVar convar_Charging_Particle;

//General
char g_TracksPath[PLATFORM_MAX_PATH];
bool g_LateLoad;

//Difficulties for tracks are just tags to help tell players how easy or hard this track is.
enum Difficulty {
	DIFFICULTY_EASY,
	DIFFICULTY_NORMAL,
	DIFFICULTY_HARD,
	DIFFICULTY_EXPERT,
	DIFFICULTY_IMPOSSIBLE	//Send Help.
}

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
				KickClient(this.entity, "");
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

Object g_Objects[MAX_OBJECTS + 1];
int g_TotalObjects;

enum struct Track {
	char name[64];			//The name of the track to be displayed and called.
	Difficulty difficulty;	//The difficulty of the track, this is just an arbitrary value set when creating or editing the track.
	
	//Nodes
	ArrayList nodes;		//The list of origin points for the track which consists of 3D vectors in order. Index 0 is the start and the last index is the finish line.
	ArrayList colors;		//The colors that correspond to the beams of the track in corresponding order.

	void Init() {
		this.nodes = new ArrayList(3);
		this.colors = new ArrayList(4);
	}

	void Set(const char[] name, Difficulty difficulty) {
		strcopy(this.name, sizeof(Track::name), name);
		this.difficulty = difficulty;
	}

	void AddNode(float origin[3], int colors[4]) {
		this.nodes.PushArray(origin, sizeof(origin));
		this.colors.PushArray(colors, sizeof(colors));
	}

	void SetNode(int index, float origin[3], int colors[4]) {
		this.nodes.SetArray(index, origin, sizeof(origin));
		this.colors.SetArray(index, colors, sizeof(colors));
	}

	void SetNodeOrigin(int index, float origin[3]) {
		this.nodes.SetArray(index, origin, sizeof(origin));
	}

	void SetNodeColor(int index, int colors[4]) {
		this.colors.SetArray(index, colors, sizeof(colors));
	}

	int GetTotalNodes() {
		return this.nodes.Length;
	}

	void GetNode(int index, float origin[3], int colors[4]) {
		this.nodes.GetArray(index, origin, sizeof(origin));
		this.colors.GetArray(index, colors, sizeof(colors));
	}

	void GetNodeOrigin(int index, float origin[3]) {
		this.nodes.GetArray(index, origin, sizeof(origin));
	}

	void GetNodeColor(int index, int colors[4]) {
		this.colors.GetArray(index, colors, sizeof(colors));
	}

	void DeleteNode(int index) {
		this.nodes.Erase(index);
		this.colors.Erase(index);
	}

	void Clear() {
		this.nodes.Clear();
		this.colors.Clear();
	}

	void Delete() {
		this.name[0] = '\0';
		this.difficulty = DIFFICULTY_EASY;
		delete this.nodes;
		delete this.colors;
	}
}

Track g_Tracks[MAX_TRACKS + 1];
int g_TotalTracks;

//Each status is used to manage the game state.
enum Status {
	STATUS_NONE,		//No racing going on at all currently, mode is basically disabled.
	STATUS_PREPARING,	//Racing is about to start and players should be prepared.
	STATUS_READY,		//The ready sequence where it counts down from 3 to GO!
	STATUS_RACING,		//The active race itself where players are participating.
	STATUS_FINISHED		//The finish line has been hit and now we're waiting for the end race call.
}

//Modes consist of how the races are played out for players.
enum Modes {
	MODE_SINGLES,	//All players for themselves one by one and the player with the most points wins.
	MODE_GROUPS,	//All players for themselves and the player with the most points wins.
	MODE_TEAMS		//Players are split into teams and race one by one and the team with the most points wins.
}

enum struct GameState {
	int track;		//The track that is currently being used.
	Status status;	//Status of the mode.
	Modes mode;		//Mode to use.
	int countdown;	//Countdown from 3 to GO!
	float timer;	//Timer while the race is active.
	Handle ticker;	//The ticker to handle the race algorithm as a while.

	void Preparing() {
		PrintToServer("Preparing...");
		this.status = STATUS_PREPARING;
		this.timer = convar_Preparation_Timer.FloatValue;
		this.ticker = CreateTimer(1.0, Timer_Tick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		KickBots();
	}

	void Ready() {
		this.status = STATUS_READY;
		this.countdown = convar_Racing_Countdown.IntValue;
		this.timer = convar_Racing_Timer.FloatValue;

		float origin[3];
		g_Tracks[this.track].GetNodeOrigin(0, origin); //0 = Start

		//Teleport the players to the starting line and freeze them in place.
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
				continue;
			}

			TeleportEntity(i, origin, NULL_VECTOR, NULL_VECTOR);
			SetEntityMoveType(i, MOVETYPE_NONE);
			SetEntProp(i, Prop_Send, "m_CollisionGroup", 0);
		}

		DeleteObjects();
		SpawnObjects();
	}

	void Racing() {
		this.status = STATUS_RACING;

		//Unfreeze them so they can move again.
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
				continue;
			}

			SetEntityMoveType(i, MOVETYPE_WALK);
			SetEntProp(i, Prop_Send, "m_CollisionGroup", 0);
		}
	}

	void None() {
		this.status = STATUS_NONE;
		this.countdown = 0;
		this.timer = 0.0;
		StopTimer(this.ticker);
	}
}

GameState g_State;

int g_ModelIndex;
int g_HaloIndex;

TopMenu g_AdminMenu;
TopMenuObject g_AdminMenuObj;

enum struct Vote {
	int track;	//The track we're voting on.
	Menu menu;	//The menu handle itself.
}

Vote g_Vote;

enum struct Player {
	int client;			//The client index of the player.
	int points;			//How many points the player has accumulated throughout the race total.
	int currentnode;	//The current node the player is on in the track.
	ArrayList speeds;	//Helpful for calculating averages in order to give points.
	int team;			//The team the player is on if the mode is teams.
	bool charging;		//Whether or not the player is charging.
	float jumpdelay;	//The delay between jumps while charging.
	bool hud;			//Whether the hud should be shown or not.
	bool finished;		//Has this player finished the race?
	float time;			//How many precise seconds has it been since the race started?

	void Init(int client) {
		this.client = client;
		this.points = 0;
		this.currentnode = 0;
		this.SyncHud();
		this.speeds = new ArrayList();
		this.team = 0;
		this.charging = false;
		this.jumpdelay = 0.0;
		this.hud = true;
		this.finished = false;
		this.time = 0.0;
	}

	void SetPoints(int points) {
		this.points = points;
		this.SyncHud();
	}

	void AddPoints(int point) {
		this.points += point;
		this.SyncHud();
	}

	void RemovePoints(int point) {
		this.points -= point;

		if (this.points < 0) {
			this.points = 0;
		}

		this.SyncHud();
	}

	void Clear() {
		this.points = 0;
		this.currentnode = 0;
		this.SyncHud();
	}

	void SyncHud() {
		if (!this.hud) {
			return;
		}

		float x = -1.0;
		float y = -1.0;
		float holdTime = 99999.0;
		int red = 255;
		int green = 255;
		int blue = 255;
		int alpha = 255;
		int effect;
		float fxTime;
		float fadeIn;
		float fadeOut;

		SetHudTextParams(x, y, holdTime, red, green, blue, alpha, effect, fxTime, fadeIn, fadeOut);

		char sBuffer[256];

		switch (g_State.mode) {
			case MODE_SINGLES: {
				int[] clients = new int[MaxClients]; int[] scores = new int[MaxClients];
				int total = GetTopScores(MaxClients, clients, scores, true);
				for (int i = 0; i < total; i++) {
					Format(sBuffer, sizeof(sBuffer), "%s#%i: %N (%i)\n", sBuffer, i + 1, clients[i], scores[i]);
				}
			}

			case MODE_GROUPS: {
				int clients[5]; int scores[5];
				int total = GetTopScores(5, clients, scores);
				for (int i = 0; i < total; i++) {
					Format(sBuffer, sizeof(sBuffer), "%s#%i: %N (%i)\n", sBuffer, i + 1, clients[i], scores[i]);
				}
			}

			case MODE_TEAMS: {
				int score1 = GetChargerTeamScore(1);
				int score2 = GetChargerTeamScore(2);
				FormatEx(sBuffer, sizeof(sBuffer), "Team: #1 (%i)\nTeam: #2 (%i)", score1, score2);
			}
		}

		GameRules_SetPropString("m_szScriptedHUDStringSet", sBuffer, false, 0);

		Panel panel = new Panel();
		char sTime[64];
		FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", true);
		char sTitle[256]; FormatEx(sTitle, sizeof(sTitle), "Leaderboard (Points: %i) (%s)", this.points, sTime);
		panel.SetTitle(sTitle);
		panel.DrawText("----------------");
		panel.DrawText(sBuffer);
		panel.Send(this.client, MenuAction_Void, MENU_TIME_FOREVER);
		delete panel;
	}

	void CacheSpeed() {
		float speed = GetSpeed(this.client);
		this.speeds.Push(speed);
		//PrintToServer("Speed: %.2f", speed);
	}

	float GetAverageSpeed() {
		int cached = this.speeds.Length;
		if (cached == 0) {
			return 0.0;
		}

		float total;
		for (int i = 0; i < cached; i++) {
			total += this.speeds.Get(i);
		}

		PrintToServer("total: %.2f", total);

		if (total == 0.0) {
			return 0.0;
		}

		float average = total / float(cached);
		PrintToServer("average: %.2f", average);

		return average;
	}

	float GetTime() {
		return GetGameTime() - this.time;
	}

	void Delete() {
		this.client = 0;
		this.points = 0;
		this.currentnode = 0;
		delete this.speeds;
		this.team = 0;
		this.charging = false;
		this.jumpdelay = 0.0;
		this.hud = true;
		this.finished = false;
		this.time = 0.0;
	}
}

public int MenuAction_Void(Menu menu, MenuAction action, int param1, int param2) {
	return 0;
}

Player g_Player[MAXPLAYERS + 1];
Track g_CreatingTrack[MAXPLAYERS + 1];
bool g_SettingName[MAXPLAYERS + 1];
int g_EditingTrack[MAXPLAYERS + 1] = {NO_TRACK, ...};
int g_EditingNode[MAXPLAYERS + 1] = {NO_NODE, ...};
int g_NewNode[MAXPLAYERS + 1] = {NO_NODE, ...};

Handle g_hSDK_OnPummelEnded;

//The action to take when managing tracks through the commands and menus.
enum TrackAction {
	Action_Create,	//We're creating a new track.
	Action_Delete,	//We're deleting this track entirely.
	Action_Edit,	//We're editing this track.
	Action_Set		//We're setting the current track.
}

public Plugin myinfo = {
	name = "[L4D2] Charger Racing 64",
	author = "Drixevel",
	description = "A gamemode that involves Chargers, racing and the number 64.",
	version = "1.0.2 [Alpha Dev]",
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_LateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	//Translations
	LoadTranslations("common.phrases");
	LoadTranslations("l4d2-charger-racing-64.phrases");

	//ConVars
	CreateConVar("sm_l4d2_charger_racing_64_version", "1.0.0", "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_l4d2_charger_racing_64_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Strafing = CreateConVar("sm_l4d2_charger_racing_64_strafing", "1", "Should the players be allowed to strafe while charging?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Strafing_Scale = CreateConVar("sm_l4d2_charger_racing_64_strafing_scale", "50.0", "How much strafing while charging based on a scale is allowed?", FCVAR_NOTIFY, true, 0.0);
	convar_Jumping = CreateConVar("sm_l4d2_charger_racing_64_jumping", "1", "Should the players be allowed to jump while charging?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Jumping_Scale = CreateConVar("sm_l4d2_charger_racing_64_jumping_scale", "400.0", "How much jump height while charging based on a scale is allowed?", FCVAR_NOTIFY, true, 0.0);
	convar_Pathing = CreateConVar("sm_l4d2_charger_racing_64_pathing", "1", "Should the paths be drawn to players?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Pathing_Width = CreateConVar("sm_l4d2_charger_racing_64_pathing_width", "1.0", "How wide should the paths be?", FCVAR_NOTIFY, true, 0.0);
	convar_Preparation_Timer = CreateConVar("sm_l4d2_charger_racing_64_preparation_timer", "60", "How long should the preparation phase be?", FCVAR_NOTIFY, true, 0.0);
	convar_Racing_Countdown = CreateConVar("sm_l4d2_charger_racing_64_countdown", "5", "How long should the countdown to start the race be?", FCVAR_NOTIFY, true, 0.0);
	convar_Racing_Timer = CreateConVar("sm_l4d2_charger_racing_64_timer", "360", "How long should races be in terms of time max?", FCVAR_NOTIFY, true, 0.0);
	convar_Charging_Particle = CreateConVar("sm_l4d2_charger_racing_64_charging_particle", "", "Which particle should be attached to the Charger while charging?", FCVAR_NOTIFY);
	//AutoExecConfig();

	convar_Racing_Timer.AddChangeHook(OnPrepareTimerChanged);
	convar_Racing_Timer.AddChangeHook(OnRacingTimerChanged);
	convar_Charging_Particle.AddChangeHook(OnParticleChanged);

	//Events
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("charger_charge_start", Event_OnChargeStart);
	HookEvent("charger_charge_end", Event_OnChargeEnd);
	HookEvent("charger_pummel_start", Event_OnPummelStart);

	//Player Commands
	RegConsoleCmd("sm_fix", Command_Fix, "Fix your synced state to match where you should be at.");
	RegConsoleCmd("sm_hud", Command_Hud, "Toggles the gamemodes HUD on or off.");

	//Track Commands
	RegAdminCmd("sm_votetrack", Command_VoteTrack, ADMFLAG_ROOT, "Start a vote for which track to be on.");
	RegAdminCmd("sm_reloadtracks", Command_ReloadTracks, ADMFLAG_ROOT, "Reloads all tracks from the file.");
	RegAdminCmd("sm_savetracks", Command_SaveTracks, ADMFLAG_ROOT, "Saves all tracks to the file.");
	RegAdminCmd("sm_createtrack", Command_CreateTrack, ADMFLAG_ROOT, "Create a new track.");
	RegAdminCmd("sm_deletetrack", Command_DeleteTrack, ADMFLAG_ROOT, "Deletes an existing track.");
	RegAdminCmd("sm_edittrack", Command_EditTrack, ADMFLAG_ROOT, "Edit an existing track.");
	RegAdminCmd("sm_settrack", Command_SetTrack, ADMFLAG_ROOT, "Sets the current track.");

	//Misc Admin Commands
	RegAdminCmd("sm_startrace", Command_StartRace, ADMFLAG_ROOT, "Starts the race manually.");
	RegAdminCmd("sm_endrace", Command_EndRace, ADMFLAG_ROOT, "Ends the race manually.");
	RegAdminCmd("sm_setmode", Command_SetMode, ADMFLAG_ROOT, "Sets the mode manually.");
	RegAdminCmd("sm_survivor", Command_SpawnSurvivor, ADMFLAG_ROOT, "Spawns a survivor where you're looking.");

	//General
	g_State.status = STATUS_NONE;

	//Admin Menu
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
		OnAdminMenuReady(topmenu);
	}

	//Gamedata
	Handle hGameData = LoadGameConfigFile("l4d2-charger-racing-64.games");

	if (hGameData == null) {
		SetFailState("Failed to load game data file: l4d2-charger-racing-64.games.txt");
		return;
	}

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnPummelEnded")) {
		SetFailState("Failed to find signature: CTerrorPlayer::OnPummelEnded");
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDK_OnPummelEnded = EndPrepSDKCall();
	if ((g_hSDK_OnPummelEnded = EndPrepSDKCall()) == null) {
		SetFailState("Failed to create SDKCall: CTerrorPlayer::OnPummelEnded");
	}

	delete hGameData;

	//Second ticker and chat print
	CreateTimer(1.0, Timer_Ticker, _, TIMER_REPEAT);
	PrintToChatAll("%sCharger Racing 64 has been loaded.", PLUGIN_TAG);
}

public void OnPluginEnd() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			SetEntityMoveType(i, MOVETYPE_WALK);
		}
	}
}

public void OnPrepareTimerChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	float timer = StringToFloat(newValue);

	//If the new timer we're setting is less than the current time then update it to reflect the new max cap.
	if (g_State.status == STATUS_PREPARING && g_State.timer > timer) {
		g_State.timer = timer;
	}
}

public void OnRacingTimerChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	float timer = StringToFloat(newValue);

	//If the new timer we're setting is less than the current time then update it to reflect the new max cap.
	if (g_State.status == STATUS_RACING && g_State.timer > timer) {
		g_State.timer = timer;
	}
}

public void OnParticleChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	//Make sure the particles precache whenever we use new ones.
	if (strlen(newValue) > 0) {
		Precache_Particle_System(newValue);
	}
}

public Action Timer_Ticker(Handle timer) {
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

//Easy command to just fix players if they're stuck in any other state that isn't a Charger that can participate in the mode.
public Action Command_Fix(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	PrintToChat(client, "%sFixing...", PLUGIN_TAG);
	CreateTimer(0.5, Timer_DelaySpawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Handled;
}

public Action Command_Hud(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	g_Player[client].hud = !g_Player[client].hud;
	PrintToChat(client, "%sHud: %s", PLUGIN_TAG, (g_Player[client].hud ? "Enabled" : "Disabled"));

	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	//All of these ConVars are required for the mode to function, otherwise other ConVars are put into configuration files.
	FindConVar("sb_all_bot_game").BoolValue = true;
	FindConVar("allow_all_bot_survivor_team").BoolValue = true;
	FindConVar("sb_unstick").BoolValue = false;
	FindConVar("mp_gamemode").SetString("versus");
	FindConVar("z_charge_duration").IntValue = 99999;
	FindConVar("sb_dont_shoot").BoolValue = true;

	if (g_LateLoad) {
		g_LateLoad = false;

		//Make sure players are preloaded on live load who are already on the server.
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientConnected(i)) {
				OnClientConnected(i);
			}

			if (IsClientInGame(i)) {
				OnClientPutInServer(i);
			}
		}

		//Kick the bots on live load if there is any and set the state of the game to preparing.
		KickBots();
	}

	char sParticle[64];
	convar_Charging_Particle.GetString(sParticle, sizeof(sParticle));
	if (strlen(sParticle) > 0) {
		Precache_Particle_System(sParticle);
	}

	g_State.Preparing();
}

public void OnMapStart() {
	g_ModelIndex = PrecacheModel("sprites/laserbeam.vmt");
	g_HaloIndex = PrecacheModel("sprites/glow01.vmt");

	//Since we spawn survivors manually, we have to make sure every model is available otherwise we crash.
	PrecacheModel(MODEL_FRANCIS);
	PrecacheModel(MODEL_LOUIS);
	PrecacheModel(MODEL_ZOEY);
	PrecacheModel(MODEL_BILL);
	PrecacheModel(MODEL_NICK);
	PrecacheModel(MODEL_ROCHELLE);
	PrecacheModel(MODEL_COACH);
	PrecacheModel(MODEL_ELLIS);

	char sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	GetMapDisplayName(sMap, sMap, sizeof(sMap));
	
	BuildPath(Path_SM, g_TracksPath, sizeof(g_TracksPath), "data/charger-racing-64/");

	if (!DirExists(g_TracksPath)) {
		CreateDirectory(g_TracksPath, 511);
	}

	Format(g_TracksPath, sizeof(g_TracksPath), "%s%s.cfg", g_TracksPath, sMap);
	ParseTracks(g_TracksPath);
}

public void OnMapEnd() {
	SetTrack(NO_TRACK);
}

void ParseTracks(const char[] file) {
	for (int i = 0; i <= MAX_TRACKS; i++) {
		g_Tracks[i].Delete();
	}
	g_TotalTracks = 0;

	if (!FileExists(file)) {
		LogError("File does not exist: %s", file);
		PrintToServer("File does not exist: %s", file);
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

			g_Tracks[index].Set(name, difficulty);

		} while (kv.GotoNextKey());
	}

	delete kv;
	LogMessage("Parsed %d tracks from file: %s", g_TotalTracks, file);
	PrintToServer("Parsed %d tracks from file: %s", g_TotalTracks, file);
}

void SaveTracks(const char[] file) {
	if (FileExists(file)) {
		DeleteFile(file);
	}

	KeyValues kv = new KeyValues("racing-tracks");

	for (int i = 0; i < g_TotalTracks; i++) {
		kv.JumpToKey(g_Tracks[i].name, true);
		kv.SetNum("difficulty", view_as<int>(g_Tracks[i].difficulty));

		kv.JumpToKey("track-points", true);

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

	kv.Rewind();
	kv.ExportToFile(file);

	delete kv;
	LogMessage("Saving %d tracks to file: %s", g_TotalTracks, file);
	PrintToServer("Saving %d tracks from file: %s", g_TotalTracks, file);
}

public Action Command_ReloadTracks(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	ParseTracks(g_TracksPath);
	ReplyToCommand(client, "[Racing] Reloaded tracks from file: %s", g_TracksPath);
	return Plugin_Handled;
}

public Action Command_SaveTracks(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	SaveTracks(g_TracksPath);
	ReplyToCommand(client, "[Racing] Saved all tracks to file: %s", g_TracksPath);
	return Plugin_Handled;
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (!IsModeEnabled()) {
		return;
	}

	//By default, we don't have a track to pick at the start of the round.
	SetTrack(NO_TRACK);

	//If we have any available tracks on the map, just pick the 1st one.
	if (g_TotalTracks > 0) {
		g_State.track = 0;
	}

	//Make sure all doors are opened.
	int entity = -1; char class[32];
	while ((entity = FindEntityByClassname(entity, "*")) != -1) {
		GetEntityClassname(entity, class, sizeof(class));

		if (StrContains(class, "door", false) != -1) {
			SetEntProp(entity, Prop_Data, "m_eDoorState", DOOR_STATE_OPENED);
		}
	}

	CreateTimer(2.0, Timer_KickBots, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KickBots(Handle timer) {
	KickBots();
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2]) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (IsFakeClient(client)) {
		return Plugin_Continue;
	}

	//Make sure the player is alive, charging and is on the ground.
	if (IsPlayerAlive(client) && g_Player[client].charging && GetEntProp(client, Prop_Send, "m_fFlags") & FL_ONGROUND) {
		//Cache the original velocity to manipulate it or keep it consistent when charging.
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);

		if (convar_Strafing.BoolValue) {
			//Strafing left and right handling.
			if ((buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT)) {
				float vAng[3];
				GetClientEyeAngles(client, vAng);

				float vVec[3];
				GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
				NormalizeVector(vVec, vVec);

				ScaleVector(vVec, convar_Strafing_Scale.FloatValue);
				if (buttons & IN_MOVELEFT)
					ScaleVector(vVec, -1.0);

				AddVectors(vVel, vVec, vVel);
			}
		}

		//Jumping with a delayed cooldown.
		if (convar_Jumping.BoolValue) {
			float time = GetGameTime();
			if (buttons & IN_JUMP && g_Player[client].jumpdelay < time) {
				g_Player[client].jumpdelay = time + 0.2;
				vVel[2] = convar_Jumping_Scale.FloatValue;
			}
		}

		//Update the player's actual velocity.
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	}

	int StartFrame = 0;
	int FrameRate = 0;
	float Life = 0.1;
	float Width = convar_Pathing_Width.FloatValue;
	float EndWidth = convar_Pathing_Width.FloatValue;
	int FadeLength = 0;
	float Amplitude = 0.0;
	int Speed = 0;

	// Shows the track you're creating but not an actual live track.
	if (g_CreatingTrack[client].nodes != null) {
		
		int length = g_CreatingTrack[client].GetTotalNodes();
		float origin[3]; int color[4];
		float origin2[3];

		for (int i = 0; i < length; i++) {
			if ((i + 1) >= length) {
				continue;
			}

			g_CreatingTrack[client].GetNodeOrigin(i, origin);
			g_CreatingTrack[client].GetNode((i+1), origin2, color);

			TE_SetupBeamPoints(origin, origin2, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, color, Speed);
			TE_SendToClient(client);
		}

		return Plugin_Continue;
	}

	if (g_EditingTrack[client] != NO_TRACK) {
		int track = g_EditingTrack[client];

		int length = g_Tracks[track].GetTotalNodes();
		float origin[3]; int color[4];
		float origin2[3];

		for (int i = 0; i < length; i++) {
			if ((i + 1) >= length) {
				continue;
			}

			g_Tracks[track].GetNodeOrigin(i, origin);
			g_Tracks[track].GetNode((i+1), origin2, color);

			if (g_EditingNode[client] == i) {
				origin[2] += 25.0;
				origin2[2] += 25.0;
			}

			TE_SetupBeamPoints(origin, origin2, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, color, Speed);
			TE_SendToClient(client);
		}

		return Plugin_Continue;
	}

	//Shows the active track path to all players.
	int track = g_State.track;

	if (track == NO_TRACK) {
		return Plugin_Continue;
	}

	if (convar_Pathing.BoolValue) {		
		int length = g_Tracks[track].GetTotalNodes();
		float origin[3]; int color[4];
		float origin2[3];

		float start_radius = 20.0;
		float end_radius = 25.0;
		int start_color[4] = { 255, 0, 0, 255 };
		int current_color[4] = { 255, 255, 255, 255 };
		int end_color[4] = { 0, 0, 255, 255 };

		for (int i = 0; i < length; i++) {
			g_Tracks[track].GetNodeOrigin(i, origin);

			//Show the ring for the start and end of the track.
			if (i == 0) {
				TE_SetupBeamRingPoint(origin, start_radius, end_radius, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, start_color, Speed, 0);
				TE_SendToClient(client);
			} else if (i == (length - 1)) {
				TE_SetupBeamRingPoint(origin, start_radius, end_radius, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, end_color, Speed, 0);
				TE_SendToClient(client);
			}

			if ((i + 1) >= length) {
				continue;
			}

			g_Tracks[track].GetNode((i+1), origin2, color);

			TE_SetupBeamPoints(origin, origin2, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, color, Speed);
			TE_SendToClient(client);

			if (g_Player[client].currentnode == (i - 1) && (g_State.status == STATUS_READY || g_State.status == STATUS_RACING)) {
				TE_SetupBeamRingPoint(origin, start_radius, end_radius, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, current_color, Speed, 0);
				TE_SendToClient(client);
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnGameFrame() {
	int track = g_State.track;

	//No track set so we don't need to do anything.
	if (track == NO_TRACK) {
		return;
	}

	int length = g_Tracks[track].GetTotalNodes();

	//There needs to be at least 1 node to bother doing anything.
	if (length < 1) {
		return;
	}

	float origin[3];
	for (int i = 0; i < length; i++) {
		g_Tracks[track].GetNodeOrigin(i, origin);
		OnNodeTick(i, origin);
	}
}

void OnNodeTick(int index, float origin[3]) {
	float pos[3];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
			continue;
		}

		pos = GetOrigin(i);

		if (GetDistance(origin, pos) <= 100.0) {
			IsNearNode(i, index);
		}
	}
}

void IsNearNode(int client, int index) {
	if (g_State.status != STATUS_RACING) {
		return;
	}

	//If a player tries to take an unintended shortcut then stop progress.
	if (g_Player[client].currentnode != (index - 1)) {
		return;
	}

	//If we're at the first node, we're at the starting line.
	if (index == 0) {
		IsNearStart(client);
		return;
	//If we're at the first node, we're at the finish line.
	} else if (index == g_Tracks[g_State.track].GetTotalNodes() - 1) {
		IsNearFinish(client);
		return;
	}

	g_Player[client].currentnode = index;
	//PrintHintText(client, "Node %i reached!", index);

	//Calculate a points value based on our average speed then clear the cache so we get a fresh average between nodes.
	float average = g_Player[client].GetAverageSpeed();
	int points = RoundToCeil(average) / 5;
	g_Player[client].speeds.Clear();
	PrintToChat(client, "You reached node %i and gained %i points.", index, points);

	//If we're carrying a survivor, give our points a multiplier.
	if (L4D2_GetInfectedAttacker(client) != -1) {
		points *= 1.20;
	}

	//Give the points and update the hud.
	g_Player[client].AddPoints(points);
}

void IsNearStart(int client) {
	PrintToChat(client, "You are at the starting line!");
}

void IsNearFinish(int client) {
	if (g_Player[client].finished) {
		return;
	}

	g_Player[client].finished = true;
	PrintToChatAll("%s%N has finished the race!", PLUGIN_TAG, client);

	char sTime[32];
	FormatSeconds(g_Player[client].GetTime(), sTime, sizeof(sTime), "%M:%S", true);

	ForcePlayerSuicide(client);
	PrintToChat(client, "Your time was %s and your score is %i.", sTime, g_Player[client].points);
}

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
	AddToTopMenu(g_AdminMenu, "sm_votetrack", TopMenuObject_Item, AdminMenu_VoteTrack, g_AdminMenuObj, "sm_votetrack", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_reloadtracks", TopMenuObject_Item, AdminMenu_ReloadTracks, g_AdminMenuObj, "sm_reloadtracks", ADMFLAG_ROOT);
	AddToTopMenu(g_AdminMenu, "sm_savetracks", TopMenuObject_Item, AdminMenu_SaveTracks, g_AdminMenuObj, "sm_savetracks", ADMFLAG_ROOT);
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

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (!IsModeEnabled()) {
		return;
	}

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1 || IsFakeClient(client)) {
		return;
	}

	g_Player[client].charging = false;
	CreateTimer(0.5, Timer_DelaySpawn, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelaySpawn(Handle timer, any userid) {
	if (!IsModeEnabled()) {
		return Plugin_Stop;
	}

	int client;
	if ((client = GetClientOfUserId(userid)) < 1) {
		return Plugin_Stop;
	}

	//Make sure all players are on the infected team.
	if (L4D_GetClientTeam(client) != L4DTeam_Infected) {
		ChangeClientTeam(client, view_as<int>(L4DTeam_Infected));
	}

	//Make sure all players are alive.
	if (!IsPlayerAlive(client)) {
		L4D_RespawnPlayer(client);
	}

	//Make sure all players who are ghosts are materialized.
	if (L4D_IsPlayerGhost(client)) {
		L4D_MaterializeFromGhost(client);
	}

	//Make sure all players are chargers.
	if (L4D2_GetPlayerZombieClass(client) != L4D2ZombieClass_Charger) {
		L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
	}

	TeleportToSurvivorPos(client);

	return Plugin_Stop;
}

void TeleportToSurvivorPos(int client) {
	int positions[16];
	int total;

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "info_survivor_position")) != -1) {
		positions[total++] = entity;
	}

	if (total < 1) {
		//PrintToServer("No survivor positions found.");
		return;
	}

	int random = positions[GetRandomInt(0, total - 1)];

	if (!IsValidEntity(random)) {
		//PrintToServer("Invalid survivor position.");
		return;
	}

	float vecOrigin[3];
	if (!GetAbsOrigin(random, vecOrigin)) {
		GetEntPropVector(random, Prop_Send, "m_vecOrigin", vecOrigin);
		//PrintToServer("Using m_vecOrigin instead of GetAbsOrigin.");
	}

	TeleportEntity(client, vecOrigin, NULL_VECTOR, NULL_VECTOR);
}

public void Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	if (!IsModeEnabled()) {
		return;
	}

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1) {
		return;
	}

	g_Player[client].charging = false;
}

public void Event_OnChargeStart(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1) {
		return;
	}

	g_Player[client].charging = true;

	//Chargers can move left and right if they don't have the frozen flag applied.
	SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);

	//Chargers should have a particle attached while charging.
	char sParticle[64];
	convar_Charging_Particle.GetString(sParticle, sizeof(sParticle));
	if (strlen(sParticle) > 0) {
		TE_SetupParticleFollowEntity_Name(sParticle, client);
	}
}

public void Event_OnChargeEnd(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1) {
		return;
	}

	g_Player[client].charging = false;

	//Immediately allows players to charge very shortly after it ends.
	CreateTimer(0.2, Timer_DelayChargeEnd, userid);

	//Chargers should no longer be have a particle shown once they stop charging.
	TE_SetupStopAllParticles(client);
}

public Action Timer_DelayChargeEnd(Handle timer, any userid) {
	int client;
	if ((client = GetClientOfUserId(userid)) > 0) {
		L4D2_SetCustomAbilityCooldown(client, 0.2);
	}

	return Plugin_Continue;
}

public Action Command_VoteTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (args == 0) {
		if (CallTrackVote(NO_TRACK)) {
			ReplyToCommand(client, "You have started a vote for a new track.");
		} else {
			ReplyToCommand(client, "A vote is already in progress.");
		}
		return Plugin_Handled;
	}

	char sTrack[64];
	GetCmdArg(1, sTrack, sizeof(sTrack));

	int track = FindTrack(sTrack);

	if (track == -1) {
		ReplyToCommand(client, "Track not found, please try again.");
		return Plugin_Handled;
	}

	if (CallTrackVote(track)) {
		ReplyToCommand(client, "You have started a vote for a new track.");
	} else {
		ReplyToCommand(client, "A vote is already in progress.");
	}

	return Plugin_Handled;
}

int FindTrack(const char[] name) {
	for (int i = 0; i < g_TotalTracks; i++) {
		if (StrContains(g_Tracks[i].name, name, false) != -1) {
			return i;
		}
	}

	return NO_TRACK;
}

bool CallTrackVote(int track = NO_TRACK) {
	if (IsVoteInProgress()) {
		return false;
	}

	g_Vote.track = track;
	g_Vote.menu = new Menu(MenuHandler_VoteCallback, MENU_ACTIONS_ALL);

	//If a track is specified, we only want a yes or no vote for it.
	if (track != NO_TRACK) {
		g_Vote.menu.SetTitle("Vote for track: %s", g_Tracks[track].name);
		g_Vote.menu.AddItem("1", "Yes");
		g_Vote.menu.AddItem("0", "No");

	} else {
		g_Vote.menu.SetTitle("Vote for a new track:");

		char sID[16];
		for (int i = 0; i < g_TotalTracks; i++) {
			if (i == g_State.track) {
				continue;
			}

			IntToString(i, sID, sizeof(sID));
			g_Vote.menu.AddItem(sID, g_Tracks[i].name);
		}

		if (g_Vote.menu.ItemCount == 0) {
			delete g_Vote.menu;
			return false;
		}
	}

	g_Vote.menu.ExitButton = false;
	g_Vote.menu.DisplayVoteToAll(20);

	return true;
}

public int MenuHandler_VoteCallback(Menu menu, MenuAction action, int param1, int param2) {
	if (!IsModeEnabled()) {
		delete menu;
		return 0;
	}

	char sInfo[64]; char sDisplay[64];
	menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));
	
	switch (action) {
		case MenuAction_Select: {
			if (g_Vote.track != NO_TRACK) {
				PrintToChatAll("%s%t", PLUGIN_TAG, "voted for track", param1, g_Tracks[g_Vote.track].name);
			} else {
				PrintToChatAll("%s%t", PLUGIN_TAG, "voted for next track", param1, sDisplay);
			}
		}

		case MenuAction_VoteEnd: {
			PrintToChatAll("%s%t", PLUGIN_TAG, "vote has ended");

			int winningvotes, totalvotes;
			GetMenuVoteInfo(param2, winningvotes, totalvotes);

			if (g_Vote.track != NO_TRACK) {
				//0 = yes, 1 = no
				if (param1 == 0) {
					SetTrack(g_Vote.track);
					PrintToChatAll("%s%t", PLUGIN_TAG, "vote results track selected", g_Tracks[g_Vote.track].name, winningvotes, totalvotes);
				} else {
					PrintToChatAll("%s%t", PLUGIN_TAG, "vote results track not selected", g_Tracks[g_Vote.track].name, winningvotes, totalvotes);
				}

			} else {
				char sWinner[64]; char sName[64];
				menu.GetItem(param1, sWinner, sizeof(sWinner), _, sName, sizeof(sName));

				SetTrack(StringToInt(sWinner));
				PrintToChatAll("%s%t", PLUGIN_TAG, "vote results track selected", sName, winningvotes, totalvotes);
			}

			g_Vote.track = NO_TRACK;
			g_Vote.menu = null;
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

bool IsModeEnabled() {
	return convar_Enabled.BoolValue;
}

public Action Command_StartRace(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	g_State.Ready();
	PrintToChatAll("%s%N has started the race.", PLUGIN_TAG, client);

	return Plugin_Handled;
}

public Action Command_EndRace(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	g_State.None();
	PrintToChatAll("%s%N has ended the race.", PLUGIN_TAG, client);

	return Plugin_Handled;
}

public Action Timer_Tick(Handle timer) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (g_State.status == STATUS_NONE) {
		return Plugin_Continue;
	}

	if (g_State.status == STATUS_PREPARING) {
		char sTime[64];
		FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", true);

		PrintHintTextToAll("Preparing to race... %s", sTime);
		g_State.timer--;

		if (g_State.timer <= 0.0) {
			g_State.Ready();
		}
		
		return Plugin_Continue;
	}

	if (g_State.countdown > -1) {
		if (g_State.countdown > 0) {
			PrintToChatAll("%s%t", PLUGIN_TAG, "race starting in print", g_State.countdown);
			PrintHintTextToAll("%s%t", PLUGIN_TAG, "race starting in center", g_State.countdown);
		} else {
			PrintToChatAll("%s%t", PLUGIN_TAG, "race starting go print");
			PrintHintTextToAll("%s%t", PLUGIN_TAG, "race starting go center");
			g_State.Racing();

			for (int i = 1; i <= MaxClients; i++) {
				g_Player[i].finished = false;
				g_Player[i].time = GetGameTime();
			}
		}

		g_State.countdown--;
		return Plugin_Continue;
	}

	char sTime[64];
	FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", true);

	PrintHintTextToAll("Race ends in... %s", sTime);
	g_State.timer--;

	if (g_State.timer <= 0.0) {
		PrintToChatAll("%s%t", PLUGIN_TAG, "race times up print");
		PrintHintTextToAll("%s%t", PLUGIN_TAG, "race times up center");
		g_State.None();
	}

	return Plugin_Continue;
}

void FormatSeconds(float seconds, char[] buffer, int maxlength, const char[] format, bool precision = false) {
	int t = RoundToFloor(seconds);

	int day; char sDay[32];
	if (t >= 86400) {
		day = RoundToFloor(t / 86400.0);
		t %= 86400;

		Format(sDay, sizeof(sDay), "%02d", day);
	}

	int hour; char sHour[32];
	if (t >= 3600) {
		hour = RoundToFloor(t / 3600.0);
		t %= 3600;

		Format(sHour, sizeof(sHour), "%02d", hour);
	}

	int mins; char sMinute[32];
	if (t >= 60) {
		mins = RoundToFloor(t / 60.0);
		t %= 60;

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

public Action Command_CreateTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	g_CreatingTrack[client].Init();
	OpenCreateTrackMenu(client);

	return Plugin_Handled;
}

void OpenCreateTrackMenu(int client) {
	Menu menu = new Menu(MenuHandler_CreateTrack, MENU_ACTIONS_ALL);
	menu.SetTitle("Create a new track:");

	menu.AddItem("name", "Name: N/A");
	menu.AddItem("difficulty", "Difficulty: Easy");
	menu.AddItem("add", "Add Node");
	menu.AddItem("total", "--- (Total Nodes: 0)");
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
			} else if (StrEqual(sInfo, "total")) {
				FormatEx(sDisplay, sizeof(sDisplay), "--- (Total Nodes: %d)", g_CreatingTrack[param1].GetTotalNodes());
			}

			return RedrawMenuItem(sDisplay);
		}

		case MenuAction_Select: {
			char sInfo[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "name")) {
				g_SettingName[param1] = true;
				PrintToChat(param1, "%s%T", PLUGIN_TAG, "editor enter a track name", param1);
				return 0;
			} else if (StrEqual(sInfo, "difficulty")) {
				g_CreatingTrack[param1].difficulty++;

				if (g_CreatingTrack[param1].difficulty > DIFFICULTY_IMPOSSIBLE) {
					g_CreatingTrack[param1].difficulty = DIFFICULTY_EASY;
				}

			} else if (StrEqual(sInfo, "add")) {
				g_NewNode[param1] = g_CreatingTrack[param1].GetTotalNodes();

				float origin[3];
				origin = GetOrigin(param1, 10.0);

				int color[4] = {255, 255, 255, 255};
				g_CreatingTrack[param1].AddNode(origin, color);

				OpenAddNodeMenu(param1, Action_Create);
				return 0;
			} else if (StrEqual(sInfo, "save")) {
				if (g_CreatingTrack[param1].GetTotalNodes() >= 2 && strlen(g_CreatingTrack[param1].name) > 0) {
					SaveTrack(param1);
					return 0;
				} else {
					PrintToChat(param1, "%sYou must specify a track name and have at least 2 nodes created to save.", PLUGIN_TAG);
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

void OpenAddNodeMenu(int client, TrackAction action) {
	float origin[3]; char sColor[32];
	switch (action) {
		case Action_Create: {
			int node = g_NewNode[client];

			int color[4];
			g_CreatingTrack[client].GetNode(node, origin, color);

			FormatEx(sColor, sizeof(sColor), "%d/%d/%d", color[0], color[1], color[2]);
		}

		case Action_Edit: {
			int id = g_EditingTrack[client];
			int node = g_EditingNode[client];

			int color[4];
			g_Tracks[id].GetNode(node, origin, color);

			FormatEx(sColor, sizeof(sColor), "%d/%d/%d", color[0], color[1], color[2]);
		}
	}

	Menu menu = new Menu(MenuHandler_AddNode);
	menu.SetTitle("Add a new node:\nOrigin: %.2f/%.2f/%.2f\nColor: %s", origin[0], origin[1], origin[2], sColor);

	menu.AddItem("position", "Update Position");
	menu.AddItem("color", "Change Color");
	menu.AddItem("save", "Save Node");

	PushMenuInt(menu, "action", view_as<int>(action));

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AddNode(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sInfo[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			switch (trackaction) {
				case Action_Create: {
					int node = g_NewNode[param1];
					
					if (StrEqual(sInfo, "position")) {
						float origin[3];
						origin = GetOrigin(param1, 10.0);
						g_CreatingTrack[param1].SetNodeOrigin(node, origin);
					} else if (StrEqual(sInfo, "color")) {
						OpenColorsMenu(param1, Action_Create);
						return 0;
					} else if (StrEqual(sInfo, "save")) {
						OpenCreateTrackMenu(param1);
						return 0;
					}

					OpenAddNodeMenu(param1, Action_Create);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int node = g_EditingNode[param1];

					if (StrEqual(sInfo, "position")) {
						float origin[3];
						origin = GetOrigin(param1, 10.0);
						g_Tracks[id].SetNodeOrigin(node, origin);
					} else if (StrEqual(sInfo, "color")) {
						OpenColorsMenu(param1, Action_Edit);
						return 0;
					} else if (StrEqual(sInfo, "save")) {
						OpenNodeEditorMenu(param1, id);
						return 0;
					}

					OpenAddNodeMenu(param1, Action_Edit);
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

void OpenColorsMenu(int client, TrackAction action) {
	Menu menu = new Menu(MenuHandler_Colors);
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

public int MenuHandler_Colors(Menu menu, MenuAction action, int param1, int param2) {
	TrackAction trackaction = view_as<TrackAction>(GetMenuInt(menu, "action"));

	switch (action) {
		case MenuAction_Select: {
			char sColor[64];
			menu.GetItem(param2, sColor, sizeof(sColor));

			int color[4];
			StringToColor(sColor, color);

			switch (trackaction) {
				case Action_Create: {
					int node = g_NewNode[param1];
					g_CreatingTrack[param1].SetNodeColor(node, color);
					OpenAddNodeMenu(param1, trackaction);
				}

				case Action_Edit: {
					int id = g_EditingTrack[param1];
					int node = g_EditingNode[param1];
					g_Tracks[id].SetNodeColor(node, color);
					OpenNodeEditorMenu(param1, id);
				}
			}
		}

		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack) {
				switch (trackaction) {
					case Action_Create: {
						OpenAddNodeMenu(param1, trackaction);
					}

					case Action_Edit: {
						int id = g_EditingTrack[param1];
						OpenNodeEditorMenu(param1, id);
					}
				}
			} else {
				switch (trackaction) {
					case Action_Create: {
						g_CreatingTrack[param1].Delete();
					}

					case Action_Edit: {
						g_EditingTrack[param1] = NO_TRACK;
						g_EditingNode[param1] = NO_NODE;
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

public void OnClientConnected(int client) {
	g_Player[client].Init(client);
}

public void OnClientPutInServer(int client) {
	//No players should be taking damage in this mode unless specified.
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype) {
	damage = 0.0;
	return Plugin_Changed;
}

public void OnClientDisconnect_Post(int client) {
	g_CreatingTrack[client].Delete();

	g_Player[client].Delete();

	g_SettingName[client] = false;
	g_EditingTrack[client] = NO_TRACK;
	g_EditingNode[client] = NO_NODE;
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

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
	if (g_SettingName[client]) {
		g_SettingName[client] = false;

		char sName[64];
		strcopy(sName, sizeof(sName), sArgs);
		TrimString(sName);

		int track = g_EditingTrack[client];

		if (track != NO_TRACK) {
			strcopy(g_Tracks[track].name, sizeof(Track::name), sName);
			OpenTrackEditorMenu(client, track);
		} else {
			strcopy(g_CreatingTrack[client].name, sizeof(Track::name), sName);
			OpenCreateTrackMenu(client);
		}
	}
}

void SaveTrack(int client) {
	int index = g_TotalTracks++;

	strcopy(g_Tracks[index].name, sizeof(Track::name), g_CreatingTrack[client].name);
	g_Tracks[index].difficulty = g_CreatingTrack[client].difficulty;
	g_Tracks[index].nodes = g_CreatingTrack[client].nodes.Clone();
	g_Tracks[index].colors = g_CreatingTrack[client].colors.Clone();

	PrintToChat(client, "%s%T", PLUGIN_TAG, "editor track save", client);
	g_CreatingTrack[client].Delete();

	SaveTracks(g_TracksPath);
}

public Action Command_SpawnSurvivor(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	int survivor = GetCmdArgInt(1);

	float origin[3];
	GetClientCrosshairOrigin(client, origin, true, 35.0);

	if (SpawnSurvivor(origin, NULL_VECTOR, survivor) != -1) {
		PrintToChat(client, "%s%T", PLUGIN_TAG, "survivor bot created", client);
	} else {
		PrintToChat(client, "%s%T", PLUGIN_TAG, "survivor bot failed", client);
	}

	return Plugin_Handled;
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

	SetEntProp(bot, Prop_Send, "m_survivorCharacter", character);

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

	return entity;
}

int FindLatestBot() {
	for (int i = MaxClients; i > 0; i--) {
		if (!IsClientInGame(i)) {
			continue;
		}

		if (IsPlayerAlive(i) && IsFakeClient(i)) {
			return i;
		}
	}

	return -1;
}

bool GetClientCrosshairOrigin(int client, float pOrigin[3], bool filter_players = true, float distance = 35.0)
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

public void Event_OnPummelStart(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int target = GetClientOfUserId(event.GetInt("victim"));

	DropVictim(client, target);
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

public Action Command_DeleteTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args > 0) {

	}

	OpenTracksMenu(client, Action_Delete);

	return Plugin_Handled;
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
				if (DeleteTrack(id)) {
					PrintToChat(param1, "%sTrack deleted.", PLUGIN_TAG);
					ParseTracks(g_TracksPath);
				} else {
					PrintToChat(param1, "%sFailed to delete track.", PLUGIN_TAG);
				}
			} else if (StrEqual(sInfo, "No")) {
				PrintToChat(param1, "%sTrack not deleted.", PLUGIN_TAG);
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

public Action Command_EditTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args > 0) {

	}

	OpenTracksMenu(client, Action_Edit);

	return Plugin_Handled;
}

void OpenTrackEditorMenu(int client, int id) {
	g_EditingTrack[client] = id;

	Menu menu = new Menu(MenuHandler_TrackEditor, MENU_ACTIONS_ALL);
	menu.SetTitle("Track Editor for %s:", g_Tracks[id].name);

	menu.AddItem("name", "Name: N/A");
	menu.AddItem("difficulty", "Difficulty: Easy");
	menu.AddItem("nodes", "Manage Nodes");

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
				PrintToChat(param1, "%sEnter a new name for the track:", PLUGIN_TAG);
				return 0;
			} else if (StrEqual(sInfo, "difficulty")) {
				g_Tracks[id].difficulty++;

				if (g_Tracks[id].difficulty > DIFFICULTY_IMPOSSIBLE) {
					g_Tracks[id].difficulty = DIFFICULTY_EASY;
				}
			} else if (StrEqual(sInfo, "nodes")) {
				OpenNodeEditorMenu(param1, id);
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

void OpenNodeEditorMenu(int client, int id) {
	Menu menu = new Menu(MenuHandler_NodeEditor);
	menu.SetTitle("Node Editor for %s:\n - Targeted Node: %i", g_Tracks[id].name, g_EditingNode[client]);

	menu.AddItem("add", "Add Node");
	menu.AddItem("target", "Target Node");
	menu.AddItem("remove", "Remove Node");
	menu.AddItem("move", "Move Node");
	menu.AddItem("color", "Change Color");

	PushMenuInt(menu, "id", id);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_NodeEditor(Menu menu, MenuAction action, int param1, int param2) {
	int id = GetMenuInt(menu, "id");

	switch (action) {
		case MenuAction_Select: {
			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "add")) {
				g_EditingNode[param1] = g_Tracks[id].GetTotalNodes();

				float origin[3];
				origin = GetOrigin(param1, 10.0);

				int color[4] = {255, 255, 255, 255};
				g_Tracks[id].AddNode(origin, color);

				OpenAddNodeMenu(param1, Action_Edit);
				return 0;
			} else if (StrEqual(sInfo, "target")) {
				g_EditingNode[param1] = GetNearestNode(param1, id);
			} else if (StrEqual(sInfo, "remove")) {
				int node = g_EditingNode[param1];

				if (node == 0 || node == g_Tracks[id].GetTotalNodes() - 1) {
					PrintToChat(param1, "%sYou cannot remove the first or last node.", PLUGIN_TAG);
					OpenNodeEditorMenu(param1, id);
					return 0;
				}

				g_Tracks[id].DeleteNode(node);

			} else if (StrEqual(sInfo, "move")) {
				float origin[3];
				origin = GetOrigin(param1, 10.0);
				g_Tracks[id].GetNodeOrigin(g_EditingNode[param1], origin);
			} else if (StrEqual(sInfo, "color")) {
				OpenColorsMenu(param1, Action_Edit);
				return 0;
			}

			OpenNodeEditorMenu(param1, id);
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

int GetNearestNode(int client, int id) {
	float origin[3];
	origin = GetOrigin(client);

	int node = NO_NODE;
	float origin2[3]; float origin3[3];

	for (int i = 0; i < g_Tracks[id].GetTotalNodes(); i++) {
		if (node == NO_NODE) {
			node = i;
			continue;
		}
		
		g_Tracks[id].GetNodeOrigin(i, origin2);
		g_Tracks[id].GetNodeOrigin(node, origin3);

		if (GetDistance(origin, origin2) < GetDistance(origin, origin3)) {
			node = i;
		}
	}

	return node;
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

public Action Command_SetTrack(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args > 0) {
		char sTrack[16];
		GetCmdArg(1, sTrack, sizeof(sTrack));

		if (SetTrack(StringToInt(sTrack))) {
			PrintToChat(client, "%sTrack has been set.", PLUGIN_TAG);
		} else {
			PrintToChat(client, "%sFailed to set track.", PLUGIN_TAG);
		}

		return Plugin_Handled;
	}

	OpenTracksMenu(client, Action_Set);
	return Plugin_Handled;
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
					PrintToChat(param1, "%sTrack has been set.", PLUGIN_TAG);
				} else {
					PrintToChat(param1, "%sFailed to set track.", PLUGIN_TAG);
				}
			} else if (StrEqual(sInfo, "No")) {
				PrintToChat(param1, "%sTrack has not changed.", PLUGIN_TAG);
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

bool SetTrack(int id) {
	if (id < NO_TRACK || id > g_TotalTracks) {
		return false;
	}

	g_State.track = id;
	PrintToChatAll("%sTrack has been set to %s.", PLUGIN_TAG, g_Tracks[id].name);
	ParseObjects(g_TracksPath, g_State.track);

	return true;
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

void KickBots() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i)) {
			KickClient(i, "");
		}
	}

	DeleteItems();
	PrintToServer("Bots have been kicked.");
}

void DeleteItems() {
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

	PrintToServer("Items have been deleted.");
}

public Action Command_SetMode(int client, int args) {
	if (!IsModeEnabled()) {
		return Plugin_Continue;
	}

	if (client < 1) {
		return Plugin_Handled;
	}

	if (args > 0) {
		char sMode[16];
		GetCmdArg(1, sMode, sizeof(sMode));

		if (SetMode(view_as<Modes>(StringToInt(sMode)))) {
			PrintToChat(client, "%sMode has been set.", PLUGIN_TAG);
		} else {
			PrintToChat(client, "%sFailed to set mode.", PLUGIN_TAG);
		}

		return Plugin_Handled;
	}

	OpenModesMenu(client);

	return Plugin_Handled;
}

void OpenModesMenu(int client) {
	Menu menu = new Menu(MenuHandler_Modes);
	menu.SetTitle("Select a mode:");

	menu.AddItem("Players", "Players");
	menu.AddItem("Groups", "Groups");
	menu.AddItem("Teams", "Teams");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Modes(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char sInfo[16];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "Players")) {
				if (SetMode(MODE_SINGLES)) {
					PrintToChat(param1, "%sMode has been set.", PLUGIN_TAG);
				} else {
					PrintToChat(param1, "%sFailed to set mode.", PLUGIN_TAG);
				}
			} else if (StrEqual(sInfo, "Groups")) {
				if (SetMode(MODE_GROUPS)) {
					PrintToChat(param1, "%sMode has been set.", PLUGIN_TAG);
				} else {
					PrintToChat(param1, "%sFailed to set mode.", PLUGIN_TAG);
				}
			} else if (StrEqual(sInfo, "Teams")) {
				if (SetMode(MODE_TEAMS)) {
					PrintToChat(param1, "%sMode has been set.", PLUGIN_TAG);
				} else {
					PrintToChat(param1, "%sFailed to set mode.", PLUGIN_TAG);
				}
			}

			OpenModesMenu(param1);
		}
		
		case MenuAction_End: {
			delete menu;
		}
	}
	
	return 0;
}

bool SetMode(Modes mode) {
	if (mode < MODE_SINGLES || mode > MODE_TEAMS) {
		return false;
	}

	char sName[64];
	GetModeName(mode, sName, sizeof(sName));

	g_State.mode = mode;
	PrintToChatAll("%sMode has been set to %s.", PLUGIN_TAG, sName);

	return true;
}

void GetModeName(Modes mode, char[] buffer, int size) {
	switch (mode) {
		case MODE_SINGLES: {
			strcopy(buffer, size, "Singles");
		}
		case MODE_GROUPS: {
			strcopy(buffer, size, "Groups");
		}
		case MODE_TEAMS: {
			strcopy(buffer, size, "Teams");
		}
	}
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
		PrintToServer("File does not exist: %s", file);
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