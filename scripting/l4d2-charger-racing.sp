//Pragmas
#pragma semicolon 1
#pragma newdecls required

//Inclues
#include <sourcemod>
#include <sdktools>
#include <adminmenu>
#include <clientprefs>
#include <left4dhooks>
#include <colors>

#include <charger_racing>
#include <l4d2_spawnSurvBotsHack>

//Defines
#define PLUGIN_VERSION "1.0.3"
//#define PLUGIN_TAG "{green}[Racing] {default}"
//#define PLUGIN_TAG_NOCOLOR "[Racing] "

#define TABLE_STATS "l4d2cr_stats"

#define DEBUG

#define MAX_TRACKS 64 	//The total tracks allowed per map.
#define MAX_COMMANDS 64 //The total commands in the plugin.
#define NO_TRACK -1 	//This is the corresponding index for data to know that this track either doesn't exist, is invalid, or is not set.
#define NO_NODE -1 		//This is the corresponding index for data to know that this node either doesn't exist, is invalid, or is not set.
#define NO_OBJECT -1 	//This is the corresponding index for data to know that this object either doesn't exist, is invalid, or is not set.
#define DEFAULT_OBJECT "models/props_fortifications/orange_cone001_clientside.mdl"	//Default model to use for a model object when first created.
#define MAX_MODELS 256	//Maximum amount of models allowed to be precached.

//Precache the survivor models for use when spawning bot objects for charging.
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
ConVar convar_Pathing_Rendering;
ConVar convar_Objects;
ConVar convar_Preparation_Timer;
ConVar convar_Racing_Countdown;
ConVar convar_Racing_Timer;
ConVar convar_Charging_Particle;
ConVar convar_Rounds;
ConVar convar_Ratio;
ConVar convar_Spawns_Items;
ConVar convar_Spawns_Doors;
ConVar convar_Spawns_Infected;
ConVar convar_Track_Culling;
ConVar convar_Preparation_Delay;
ConVar convar_Death_On_Finish;
ConVar convar_Point_Start_Radius;
ConVar convar_Point_End_Radius;
ConVar convar_Point_Start_Color;
ConVar convar_Point_Current_Color;
ConVar convar_Point_End_Color;
ConVar convar_Skip_Nodes;
ConVar convar_Node_Radius;
ConVar convar_NewRoundState;

//General
char g_ConfigsFolder[PLATFORM_MAX_PATH];
char g_DataFolder[PLATFORM_MAX_PATH];
char g_TracksPath[PLATFORM_MAX_PATH];
bool g_LateLoad;
bool g_LateLoad2;
char g_CurrentMap[64];
bool g_MapStarted;

Database g_Database;

API g_API;
GameState g_State;
Points g_Points;
Group g_Groups;
Vote g_Vote;

Command g_Command[MAX_COMMANDS + 1];
int g_TotalCommands;

Track g_Tracks[MAX_TRACKS + 1];
int g_TotalTracks;

int g_ModelIndex;
int g_HaloIndex;

TopMenu g_AdminMenu;
TopMenuObject g_AdminMenuObj;

Player g_Player[MAXPLAYERS + 1];
Track g_CreatingTrack[MAXPLAYERS + 1];
bool g_SettingName[MAXPLAYERS + 1];
int g_EditingTrack[MAXPLAYERS + 1] = {NO_TRACK, ...};

int g_NewNode[MAXPLAYERS + 1] = {NO_NODE, ...};
int g_EditingNode[MAXPLAYERS + 1] = {NO_NODE, ...};

int g_NewObj[MAXPLAYERS + 1] = {NO_OBJECT, ...};
Object g_NewObjectEnt[MAXPLAYERS + 1];
int g_EditingObj[MAXPLAYERS + 1] = {NO_OBJECT, ...};

GameDataHandlers g_GameData;

Cookies g_Cookies;

ArrayList g_TrackNodes;
ArrayList g_TrackObjects;

bool added[MAXPLAYERS + 1];

int g_iLastSpawnClient;

bool g_IsTemporarySurvivor[MAXPLAYERS + 1];

//Sub-Files
#include "charger-racing/adminmenu.sp"
#include "charger-racing/api.sp"
#include "charger-racing/commands.sp"
#include "charger-racing/convars.sp"
#include "charger-racing/cookies.sp"
#include "charger-racing/events.sp"
#include "charger-racing/gamedata.sp"
#include "charger-racing/gamestate.sp"
#include "charger-racing/groups.sp"
#include "charger-racing/nodes.sp"
#include "charger-racing/objects.sp"
#include "charger-racing/players.sp"
#include "charger-racing/points.sp"
#include "charger-racing/statistics.sp"
#include "charger-racing/stocks.sp"
#include "charger-racing/tracks.sp"
#include "charger-racing/view-controller.sp"
#include "charger-racing/votes.sp"

public Plugin myinfo = {
	name = "[L4D2] Charger Racing 64",
	author = "Drixevel",
	description = "A gamemode that involves Chargers, racing and the number 64.",
	version = PLUGIN_VERSION,
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("charger-racing");
	g_API.Init();
	g_LateLoad = late;
	g_LateLoad2 = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	//Translations
	LoadTranslations("common.phrases");
	LoadTranslations("l4d2-charger-racing.phrases");

	Database.Connect(OnSQLConnect, "l4d2-charger-racing");

	//ConVars
	CreateConVar("sm_l4d2_charger_racing_version", PLUGIN_VERSION, "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_l4d2_charger_racing_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Strafing = CreateConVar("sm_l4d2_charger_racing_strafing", "1", "Should the players be allowed to strafe while charging?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Strafing_Scale = CreateConVar("sm_l4d2_charger_racing_strafing_scale", "50.0", "How much strafing while charging based on a scale is allowed?", FCVAR_NOTIFY, true, 0.0);
	convar_Jumping = CreateConVar("sm_l4d2_charger_racing_jumping", "1", "Should the players be allowed to jump while charging?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Jumping_Scale = CreateConVar("sm_l4d2_charger_racing_jumping_scale", "400.0", "How much jump height while charging based on a scale is allowed?", FCVAR_NOTIFY, true, 0.0);
	convar_Pathing = CreateConVar("sm_l4d2_charger_racing_pathing", "1", "Should the paths be drawn to players?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Pathing_Width = CreateConVar("sm_l4d2_charger_racing_pathing_width", "1.0", "How wide should the paths be?", FCVAR_NOTIFY, true, 0.0);
	convar_Pathing_Rendering = CreateConVar("sm_l4d2_charger_racing_pathing_rendering", "1", "What type of rendering should the pathing use?\n(0 = tempents, 1 = ents)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Objects = CreateConVar("sm_l4d2_charger_racing_objects", "1", "Should objects be spawned on the track?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Preparation_Timer = CreateConVar("sm_l4d2_charger_racing_preparation_timer", "60", "How long should the preparation phase be?", FCVAR_NOTIFY, true, 0.0);
	convar_Racing_Countdown = CreateConVar("sm_l4d2_charger_racing_countdown", "5", "How long should the countdown to start the race be?", FCVAR_NOTIFY, true, 0.0);
	convar_Racing_Timer = CreateConVar("sm_l4d2_charger_racing_timer", "360", "How long should races be in terms of time max?", FCVAR_NOTIFY, true, 0.0);
	convar_Charging_Particle = CreateConVar("sm_l4d2_charger_racing_charging_particle", "", "Which particle should be attached to the Charger while charging?", FCVAR_NOTIFY);
	convar_Rounds = CreateConVar("sm_l4d2_charger_racing_rounds", "5", "How many rounds total before the map automatically changes?", FCVAR_NOTIFY, true, 0.0);
	convar_Ratio = CreateConVar("sm_l4d2_charger_racing_ratio", "0.5", "Percentage of players to split into groups?\n(0.25 = 25%, 0.50 = 50%, etc.)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Spawns_Items = CreateConVar("sm_l4d2_charger_racing_spawns_items", "1", "Should the items be deleted and stopped from spawning entirely?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Spawns_Doors = CreateConVar("sm_l4d2_charger_racing_spawns_doors", "1", "Should the doors be deleted and stopped from spawning entirely?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Spawns_Infected = CreateConVar("sm_l4d2_charger_racing_spawns_infected", "1", "Should the common infected be deleted and stopped from spawning entirely?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Track_Culling = CreateConVar("sm_l4d2_charger_racing_track_culling", "5000.0", "After what distance from the player should the track no longer draw?", FCVAR_NOTIFY, true, 0.0);
	convar_Preparation_Delay = CreateConVar("sm_l4d2_charger_racing_preparation_delay", "10", "How many seconds to delay the preparation period?", FCVAR_NOTIFY, true, 0.0);
	convar_Death_On_Finish = CreateConVar("sm_l4d2_charger_racing_death_on_finish", "1", "Should the Charger actively racing if/once they reach the finish line?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Point_Start_Radius = CreateConVar("sm_l4d2_charger_racing_start_radius", "20.0", "What should the start radius be for path track nodes?", FCVAR_NOTIFY, true, 0.0);
	convar_Point_End_Radius = CreateConVar("sm_l4d2_charger_racing_end_radius", "25.0", "What should the end radius be for path track nodes?", FCVAR_NOTIFY, true, 0.0);
	convar_Point_Start_Color = CreateConVar("sm_l4d2_charger_racing_start_color", "255, 0, 0, 255", "What should the color of the starting node be?", FCVAR_NOTIFY);
	convar_Point_Current_Color = CreateConVar("sm_l4d2_charger_racing_current_color", "255, 255, 255, 255", "What should the color of the current node be?", FCVAR_NOTIFY);
	convar_Point_End_Color = CreateConVar("sm_l4d2_charger_racing_end_color", "0, 0, 255, 255", "What should the color of the end node be?", FCVAR_NOTIFY);
	convar_Skip_Nodes = CreateConVar("sm_l4d2_charger_racing_skip_nodes", "1", "Should we calculate and deduct points for players skipping nodes?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Node_Radius = CreateConVar("sm_l4d2_charger_racing_node_radius", "100", "How many units should nodes be interacted with in terms of size?", FCVAR_NOTIFY, true, 0.0);
	convar_NewRoundState = CreateConVar("sm_l4d2_charger_racing_new_round_state", "1", "Wait for players to type in chat to manually prepare the next race or prepare it automatically?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	AutoExecConfig();

	//ConVar Change Hooks
	convar_Pathing.AddChangeHook(OnPathingChanged);
	convar_Pathing_Rendering.AddChangeHook(OnPathingRenderingChanged);
	convar_Preparation_Timer.AddChangeHook(OnPrepareTimerChanged);
	convar_Racing_Timer.AddChangeHook(OnRacingTimerChanged);
	convar_Charging_Particle.AddChangeHook(OnParticleChanged);
	convar_Spawns_Items.AddChangeHook(OnItemSpawnsChanged);
	convar_Spawns_Doors.AddChangeHook(OnDoorsSpawnsChanged);
	convar_Spawns_Infected.AddChangeHook(OnInfectedSpawnsChanged);

	//Events
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("charger_charge_start", Event_OnChargeStart);
	HookEvent("charger_charge_end", Event_OnChargeEnd);
	HookEvent("charger_pummel_start", Event_OnPummelStart);
	HookEvent("player_bot_replace", Event_OnBotReplacePlayer);
	HookEvent("gameinstructor_nodraw", Event_NoDraw, EventHookMode_PostNoCopy);

	//Player Commands
	RegConsoleCmd2("sm_hud", Command_Hud, "Toggles the gamemodes HUD on or off.");
	RegConsoleCmd2("sm_commands", Command_Commands, "Shows the available commands for the gamemode.");
	RegConsoleCmd2("sm_track", Command_Track, "Prints out to chat which track is currently set.");
	RegConsoleCmd2("sm_stats", Command_Stats, "Shows your current statistics.");
	RegConsoleCmd2("sm_ready", Command_Ready, "Ready up to play the next match.");
	RegConsoleCmd2("sm_preparerace", Command_PrepareRace, "Starts the preparation phase manually.");

	//General Commands
	RegAdminCmd2("sm_survivor", Command_Survivor, ADMFLAG_ROOT, "Spawns a temporary survivor where you're looking.");

	//Track Commands
	RegAdminCmd2("sm_votetrack", Command_VoteTrack, ADMFLAG_ROOT, "Start a vote for which track to be on.");
	RegAdminCmd2("sm_reloadtracks", Command_ReloadTracks, ADMFLAG_ROOT, "Reloads all tracks from the file.");
	RegAdminCmd2("sm_savetracks", Command_SaveTracks, ADMFLAG_ROOT, "Saves all tracks to the file.");
	RegAdminCmd2("sm_createtrack", Command_CreateTrack, ADMFLAG_ROOT, "Create a new track.");
	RegAdminCmd2("sm_deletetrack", Command_DeleteTrack, ADMFLAG_ROOT, "Deletes an existing track.");
	RegAdminCmd2("sm_edittrack", Command_EditTrack, ADMFLAG_ROOT, "Edit an existing track.");
	RegAdminCmd2("sm_settrack", Command_SetTrack, ADMFLAG_ROOT, "Sets the current track.");

	//Race Commands
	RegAdminCmd2("sm_start", Command_StartRace, ADMFLAG_ROOT, "Starts the race manually.");
	RegAdminCmd2("sm_startrace", Command_StartRace, ADMFLAG_ROOT, "Starts the race manually.");
	RegAdminCmd2("sm_end", Command_EndRace, ADMFLAG_ROOT, "Ends the race manually.");
	RegAdminCmd2("sm_endrace", Command_EndRace, ADMFLAG_ROOT, "Ends the race manually.");
	RegAdminCmd2("sm_mode", Command_SetMode, ADMFLAG_ROOT, "Sets the mode manually.");
	RegAdminCmd2("sm_gamemode", Command_SetMode, ADMFLAG_ROOT, "Sets the mode manually.");
	RegAdminCmd2("sm_setmode", Command_SetMode, ADMFLAG_ROOT, "Sets the mode manually.");
	RegAdminCmd2("sm_pause", Command_Pause, ADMFLAG_ROOT, "Pauses and resumes the timer.");

	//Debugging Commands
	RegAdminCmd("sm_state", Command_State, ADMFLAG_ROOT, "Prints out the current state of the game.");
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_ROOT, "Respawns yourself or another player.");
	RegAdminCmd("sm_groups", Command_Groups, ADMFLAG_ROOT, "Shows the current list of groups and players.");

	//General
	g_GameData.Init();
	g_Cookies.Init();
	g_State.Init();
	g_Points.Init();
	g_Groups.Init();

	g_TrackNodes = new ArrayList();
	g_TrackObjects = new ArrayList();

	//Admin Menu
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null)) {
		OnAdminMenuReady(topmenu);
	}

	//Create necessary folders.
	CreateFolders();

	//Second ticker and chat print
	CreateTimer(1.0, Timer_Seconds, _, TIMER_REPEAT);

	PrintToClients("Charger Racing 64 (v.%s) has been loaded.", PLUGIN_VERSION);
}

public void OnSQLConnect(Database db, const char[] error, any data) {
	if (db == null) {
		ThrowError("Error while connecting to database: %s", error);
	}
	
	g_Database = db;
	LogMessage("Connected to database successfully.");

	char driver[32];
	g_Database.Driver.GetIdentifier(driver, sizeof(driver));
	
	if (StrEqual(driver, "sqlite", false)) {
		g_Database.Query(OnCreateTable, "CREATE TABLE IF NOT EXISTS " ... TABLE_STATS ... " ( id INTEGER PRIMARY KEY AUTOINCREMENT, accountid INTEGER NOT NULL, races INTEGER NOT NULL DEFAULT 0, wins INTEGER NOT NULL DEFAULT 0, losses INTEGER NOT NULL DEFAULT 0, totalpoints INTEGER NOT NULL DEFAULT 0);", DBPrio_Low);
	} else {
		g_Database.Query(OnCreateTable, "CREATE TABLE IF NOT EXISTS " ... TABLE_STATS ... " ( id INTEGER PRIMARY KEY AUTO_INCREMENT, accountid INTEGER NOT NULL, races INTEGER NOT NULL DEFAULT 0, wins INTEGER NOT NULL DEFAULT 0, losses INTEGER NOT NULL DEFAULT 0, totalpoints INTEGER NOT NULL DEFAULT 0);", DBPrio_Low);
	}
}

public void OnCreateTable(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while creating table: %s", error);
	}

	if (g_LateLoad2) {
		g_LateLoad2 = false;

		char auth[64];
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientAuthorized(i) && GetClientAuthId(i, AuthId_Engine, auth, sizeof(auth))) {
				OnClientAuthorized(i, auth);
			}
		}
	}
}

public void OnPluginEnd() {
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) {
			continue;
		}

		if (IsPlayerAlive(i)) {
			SetEntityMoveType(i, MOVETYPE_WALK);
		}

		g_NewObjectEnt[i].Delete();
		g_NewObjectEnt[i].Clear();
	}

	ClearPathNodes();
	ClearTrackObjects();
}

public void OnConfigsExecuted() {
	//All of these ConVars are required for the mode to function, otherwise other ConVars are put into configuration files.
	FindConVar("allow_all_bot_survivor_team").BoolValue = true;
	FindConVar("versus_special_respawn_interval").IntValue = 999999;
	FindConVar("mp_gamemode").SetString("versus");
	FindConVar("director_no_survivor_bots").BoolValue = false;
	FindConVar("vs_max_team_switches").IntValue = 9999;
	FindConVar("sv_allow_lobby_connect_only").BoolValue = false;
	FindConVar("motd_enabled").BoolValue = false;
	FindConVar("sb_all_bot_game").BoolValue = true;
	FindConVar("sb_unstick").BoolValue = false;
	FindConVar("sb_dont_shoot").BoolValue = true;
	FindConVar("sb_stop").BoolValue = true;
	FindConVar("z_charge_duration").IntValue = 99999;
	FindConVar("z_common_limit").IntValue = 0;

	char sParticle[64];
	convar_Charging_Particle.GetString(sParticle, sizeof(sParticle));

	if (strlen(sParticle) > 0) {
		Precache_Particle_System(sParticle);
	}

	char sPath[PLATFORM_MAX_PATH];

	FormatEx(sPath, sizeof(sPath), "%spoints.cfg", g_ConfigsFolder);
	ParsePoints(sPath);

	Format(g_TracksPath, sizeof(g_TracksPath), "%stracks/%s.cfg", g_DataFolder, g_CurrentMap);
	ParseTracks(g_TracksPath);

	if (g_LateLoad) {
		g_LateLoad = false;

		//Make sure players are preloaded on live load who are already on the server.
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientConnected(i)) {
				OnClientConnected(i);
			}

			if (AreClientCookiesCached(i)) {
				OnClientCookiesCached(i);
			}

			if (IsClientInGame(i)) {
				OnClientPutInServer(i);
			}
		}

		//Kick the bots on live load if there is any and set the state of the game to preparing.
		DeleteBots();

		//Start the preparing process automatically.
		g_State.Preparing(2);
	}

	L4D_LobbyUnreserve();
}

public void OnMapStart() {
	GetCurrentMap(g_CurrentMap, sizeof(g_CurrentMap));
	GetMapDisplayName(g_CurrentMap, g_CurrentMap, sizeof(g_CurrentMap));

	ModeLog("Loading data for map '%s'...", g_CurrentMap);

	g_ModelIndex = PrecacheModel("sprites/laserbeam.vmt");
	g_HaloIndex = PrecacheModel("sprites/glow01.vmt");

	PrecacheModel(DEFAULT_OBJECT);

	//Since we spawn survivors manually, we have to make sure every model is available otherwise we crash.
	PrecacheModel(MODEL_FRANCIS);
	PrecacheModel(MODEL_LOUIS);
	PrecacheModel(MODEL_ZOEY);
	PrecacheModel(MODEL_BILL);
	PrecacheModel(MODEL_NICK);
	PrecacheModel(MODEL_ROCHELLE);
	PrecacheModel(MODEL_COACH);
	PrecacheModel(MODEL_ELLIS);

	g_MapStarted = true;
}

public void OnMapEnd() {
	g_State.Init();
	ClearTracks();
	ClearPathNodes();
	ClearTrackObjects();
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
				float vAng[3]; vAng = GetEyeAngles(client);

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

	float pos[3]; pos = GetEyePosition(client);

	float cull_distance = convar_Track_Culling.FloatValue;

	//Display the track as tempents to the player who's creating it.
	if (g_CreatingTrack[client].node_origins != null) {
		
		int length = g_CreatingTrack[client].GetTotalNodes();
		float origin[3]; int color[4];
		float origin2[3];

		for (int i = 0; i < length; i++) {
			if ((i + 1) >= length) {
				continue;
			}

			g_CreatingTrack[client].GetNodeOrigin(i, origin);
			g_CreatingTrack[client].GetNode((i+1), origin2, color);

			if (GetVectorDistance(pos, origin) > cull_distance || GetVectorDistance(pos, origin2) > cull_distance) {
				continue;
			}

			TE_SetupBeamPoints(origin, origin2, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, color, Speed);
			TE_SendToClient(client);
		}

		return Plugin_Continue;
	}

	//Display the track as tempents to the player who's editing it.
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

			if (GetVectorDistance(pos, origin) > cull_distance || GetVectorDistance(pos, origin2) > cull_distance) {
				continue;
			}

			TE_SetupBeamPoints(origin, origin2, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, color, Speed);
			TE_SendToClient(client);
		}

		return Plugin_Continue;
	}

	//Display a ring around the currently active node the player is on.
	int track = g_State.track;

	if (track == NO_TRACK) {
		return Plugin_Continue;
	}
	
	float start_radius = convar_Point_Start_Radius.FloatValue;
	float end_radius = convar_Point_End_Radius.FloatValue;
	int current_color[4]; current_color = GetConVarColor(convar_Point_Current_Color);
	
	//We want to mark the node that the player should be moving towards so the next node on the stack.
	int i = g_Player[client].currentnode + 1;
	int max = g_Tracks[track].GetTotalNodes();

	//If the last node is the finish line then don't bother incrementing.
	if (i > max) {
		i = max;
	}

	//Get the origin point of the node to mark.
	float origin[3];
	g_Tracks[track].GetNodeOrigin(i, origin);

	//Check that we're close to the node and if we're ready and/or racing then draw the mark.
	if (GetVectorDistance(pos, origin) <= cull_distance && (g_State.status == STATUS_READY || g_State.status == STATUS_RACING)) {
		TE_SetupBeamRingPoint(origin, start_radius, end_radius, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, current_color, Speed, 0);
		TE_SendToClient(client);
	}
	
	return Plugin_Continue;
}

public void OnGameFrame() {
	int track = g_State.track;

	//No track set so we don't need to do anything.
	if (track == NO_TRACK) {
		return;
	}

	//Track is set but not valid to run, don't tick it.
	if (!g_Tracks[track].Valid()) {
		return;
	}

	//Track nodes are set and valid to run, tick it.
	if (g_Tracks[track].ValidNodes()) {
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

		if (convar_Pathing.BoolValue) {
			int StartFrame = 0;
			int FrameRate = 0;
			float Life = 0.1;
			float Width = convar_Pathing_Width.FloatValue;
			//float EndWidth = convar_Pathing_Width.FloatValue;
			//int FadeLength = 0;
			float Amplitude = 0.0;
			int Speed = 0;
			
			int color[4];
			float origin2[3];

			float start_radius = convar_Point_Start_Radius.FloatValue;
			float end_radius = convar_Point_End_Radius.FloatValue;
			int start_color[4]; start_color = GetConVarColor(convar_Point_Start_Color);
			int end_color[4]; end_color = GetConVarColor(convar_Point_End_Color);

			bool render = convar_Pathing_Rendering.IntValue == 0;

			for (int i = 0; i < length; i++) {
				g_Tracks[track].GetNodeOrigin(i, origin);

				//Show the ring for the start and end of the track.
				if (i == 0) {
					TE_SetupBeamRingPoint(origin, start_radius, end_radius, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, start_color, Speed, 0);
					TE_SendToAllInRange(origin, RangeType_Visibility);
				} else if (i == (length - 1)) {
					TE_SetupBeamRingPoint(origin, start_radius, end_radius, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, Amplitude, end_color, Speed, 0);
					TE_SendToAllInRange(origin, RangeType_Visibility);
				}

				if ((i + 1) >= length) {
					continue;
				}

				g_Tracks[track].GetNode((i+1), origin2, color);

				if (render) {
					//TE_SetupBeamPoints(origin, origin2, g_ModelIndex, g_HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, color, Speed);
					//TE_SendToAllInRange(origin, RangeType_Visibility);
				}
			}
		}
	}
}

public void L4D_OnEnterGhostState(int client) {
	L4D_MaterializeFromGhost(client);
	L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
	TeleportToSurvivorPos(client);
}

public Action Timer_DelaySpawn(Handle timer, any userid) {
	if (!IsModeEnabled()) {
		return Plugin_Stop;
	}

	int client;
	if ((client = GetClientOfUserId(userid)) < 1 || !IsClientInGame(client) || IsFakeClient(client)) {
		return Plugin_Stop;
	}

	//Move the player to the infected team if they're not on there already while spawning into the map.
	if (L4D_GetClientTeam(client) == L4DTeam_Survivor) {
		L4D_ChangeClientTeam(client, L4DTeam_Infected);
	}

	//Respawn the player if they currently aren't alive but on a team.
	if (!IsPlayerAlive(client)) {
		L4D_RespawnPlayer(client);
	}

	//Make sure the player is a charger and no other type of zombie.
	L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));

	//Teleport the player to a survivor position at the start of the map.
	if (g_State.status == STATUS_NONE || g_State.status == STATUS_PREPARING) {
		TeleportToSurvivorPos(client);
	}

	return Plugin_Stop;
}

public Action Timer_DelayChargeEnd(Handle timer, any userid) {
	int client;
	if ((client = GetClientOfUserId(userid)) > 0) {
		L4D2_SetCustomAbilityCooldown(client, 0.2);
	}

	return Plugin_Continue;
}

public Action Timer_Tick(Handle timer) {
	//Gamemode is disabled either through the ConVar or the Status so do nothing.
	if (!IsModeEnabled() || g_State.status == STATUS_NONE) {
		return Plugin_Continue;
	}

	//No players are available so set the Status of the mode to none and wait for players to join.
	if (!IsPlayersAvailable()) {
		g_State.None(1);
		return Plugin_Continue;
	}

	if (g_State.track == NO_TRACK) {
		PrintHintTextToAll("No track is set, please set one.");
		return Plugin_Continue;
	}

	//We're preparing for race so we know players are on the server currently wanting to race.
	if (g_State.status == STATUS_PREPARING) {
		char sName[64];
		GetModeName(g_State.mode, sName, sizeof(sName));
		
		char sTime[64];
		FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", false);

		bool pause;
		char reason[64];

		if (GetReadyPlayers() == 0) {
			pause = true;
			strcopy(reason, sizeof(reason), " (No Ready Players Found)");
		}
		
		if (g_State.mode == MODE_TEAMS || g_State.mode == MODE_GROUPTEAMS) {
			if (GetTeamAliveCount(view_as<int>(L4DTeam_Infected)) < 2) {
				pause = true;
				strcopy(reason, sizeof(reason), " (Waiting for More Players)");
			}
		}

		PrintHintTextToAll("%t", "prepare center hud", sName, sTime, (pause ? reason : g_State.paused ? " (Paused)" : ""));

		if (!g_State.paused && !pause) {
			g_State.timer--;
		}

		if (g_State.timer <= 0.0) {
			g_State.StartRace();
		}
		
		return Plugin_Continue;
	}

	if (g_State.countdown > -1) {
		if (g_State.countdown > 0) {
			PrintToClients("%t", "race starting in print", g_State.countdown);
			PrintHintTextToClients("%t", "race starting in center", g_State.countdown);
		} else {
			PrintToClients("%t", "race starting go print");
			PrintHintTextToClients("%t", "race starting go center");
			
			g_State.Racing();
		}

		g_State.countdown--;

		return Plugin_Continue;
	}

	char sTime[64];
	FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", false);
	PrintHintTextToAll("Race ends in... %s", sTime);

	if (!g_State.paused) {
		g_State.timer--;
	}

	if (g_State.timer <= 0.0) {
		switch (g_State.mode) {
			case MODE_SINGLES, MODE_TEAMS: {
				if (AllPlayersFinished()) {
					PrintToClients("%t", "race times up print");
					//PrintHintTextToAll("%s%t", PLUGIN_TAG_NOCOLOR, "race times up center");

					EndRace(1);
				} else {
					g_State.PopQueue(true, 1);
				}
			}

			case MODE_GROUPS, MODE_GROUPTEAMS: {
				if (g_State.group > g_Groups.GetTotalGroups()) {
					PrintToClients("%t", "race times up print");
					//PrintHintTextToAll("%s%t", PLUGIN_TAG_NOCOLOR, "race times up center");

					EndRace(2);
				} else {
					g_State.PopQueue(true, 2);
				}
			}
		}
	}

	return Plugin_Continue;
}

public void OnClientConnected(int client) {
	if (IsFakeClient(client)) {
		return;
	}

	g_Player[client].Init(client);
}

public void OnClientPutInServer(int client) {
	if (g_iLastSpawnClient == -1) {
		g_iLastSpawnClient = GetClientUserId(client);
	}

	//No players should be taking damage in this mode unless specified.
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype) {
	damage = 0.0;
	return Plugin_Changed;
}

public void OnClientAuthorized(int client, const char[] auth) {
	if (IsFakeClient(client)) {
		return;
	}

	if (g_Database == null) {
		return;
	}

	char query[2048];
	g_Database.Format(query, sizeof(query), "SELECT races, wins, losses, totalpoints FROM %s WHERE accountid = %i;", TABLE_STATS, GetSteamAccountID(client));
	g_Database.Query(OnParseStats, query, GetClientUserId(client), DBPrio_Low);
}

public void OnParseStats(Database db, DBResultSet results, const char[] error, any data) {
	int client;
	if ((client = GetClientOfUserId(data)) == 0) {
		return;
	}

	if (results == null) {
		ThrowError("Error while parsing statistics: %s", error);
	}

	if (results.FetchRow()) {
		g_Player[client].stats.races = results.FetchInt(0);
		g_Player[client].stats.wins = results.FetchInt(1);
		g_Player[client].stats.losses = results.FetchInt(2);
		g_Player[client].stats.totalpoints = results.FetchInt(3);
	} else {
		if (g_Database == null) {
			return;
		}
		
		char query[2048];
		g_Database.Format(query, sizeof(query), "INSERT INTO %s (accountid) VALUES (%i);", TABLE_STATS, GetSteamAccountID(client));
		g_Database.Query(OnSyncPlayer, query, _, DBPrio_Low);
	}
}

public void OnSyncPlayer(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while syncing player: %s", error);
	}
}

public void OnClientDisconnect(int client) {
	//Player disconnected from the game while racing so check if we need to pop queue or end the race since they're the last one.
	if (IsClientInGame(client) && IsPlayerAlive(client) && !g_Player[client].playing && g_State.status == STATUS_RACING && (g_State.mode == MODE_SINGLES || g_State.mode == MODE_GROUPS)) {
		if (AllPlayersFinished()) {
			EndRace(3);
		} else {
			g_State.PopQueue(true, 3);
		}
	}

	//Empty server so set the state to none.
	if (!IsPlayersAvailable()) {
		g_State.None(2);
	}

	g_NewObjectEnt[client].Delete();
}

public void OnClientDisconnect_Post(int client) {
	g_CreatingTrack[client].Delete();

	g_Player[client].Delete();

	g_SettingName[client] = false;
	g_EditingTrack[client] = NO_TRACK;
	g_EditingNode[client] = NO_NODE;
	g_EditingObj[client] = NO_OBJECT;

	g_NewObjectEnt[client].Clear();
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

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrContains(classname, "item_") == 0 || StrContains(classname, "weapon_") == 0) {
		SDKHook(entity, SDKHook_SpawnPost, OnItemSpawned);
	}

	if (StrContains(classname, "func_door") == 0 || StrEqual(classname, "momentary_door") || StrContains(classname, "prop_door") == 0 || StrContains(classname, "prop_wall") == 0) {
		SDKHook(entity, SDKHook_SpawnPost, OnDoorSpawned);
	}

	if (StrEqual(classname, "infected")) {
		SDKHook(entity, SDKHook_SpawnPost, OnInfectedSpawned);
	}
}

public void OnEntityDestroyed(int entity) {
	if (entity < 1) {
		return;
	}

	if (entity < MaxClients) {
		g_IsTemporarySurvivor[entity] = false;
	}
}

public void OnItemSpawned(int entity) {
	CreateTimer(0.5, Timer_DeleteItem, EntIndexToEntRef(entity));
}

public Action Timer_DeleteItem(Handle timer, any data) {
	if (convar_Spawns_Items.BoolValue) {
		int entity = -1;
		if ((entity = EntRefToEntIndex(data)) == -1) {
			return Plugin_Continue;
		}

		int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

		if (owner < 1 || owner > MaxClients) {
			RemoveEntity(entity);
		}
	}

	return Plugin_Continue;
}

public void OnDoorSpawned(int entity) {
	if (convar_Spawns_Doors.BoolValue) {
		RemoveEntity(entity);
	}
}

public void OnInfectedSpawned(int entity) {
	if (convar_Spawns_Infected.BoolValue) {
		RemoveEntity(entity);
	}
}

public void Frame_DelayFinish(any data) {
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		
		g_API.Call_OnPlayerFinish(i);
		g_Player[i].racing = false;
	}
}

public Action Timer_Prepare(Handle timer) {
	if (convar_NewRoundState.BoolValue) {
		g_State.None(3);
		PrintToClients("%t", "must prepare race manually");
	} else {
		g_State.Preparing(4);
	}

	return Plugin_Continue;
}