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

//Defines
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_TAG "{green}[Racing] {default}"
#define PLUGIN_TAG_NOCOLOR "[Racing] "

#define DEBUG

#define MAX_TRACKS 64 	//The total tracks allowed per map.
#define MAX_OBJECTS 128 //The total objects allowed per track and difficulty.
#define MAX_COMMANDS 64 //The total commands in the plugin.
#define NO_TRACK -1 	//This is the corresponding index for data to know that this track either doesn't exist, is invalid, or is not set.
#define NO_NODE -1 		//This is the corresponding index for data to know that this node either doesn't exist, is invalid, or is not set.
#define DEFAULT_OBJECT "models/props_fortifications/orange_cone001_clientside.mdl"
#define MAX_MODELS 256

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

//General
char g_TracksPath[PLATFORM_MAX_PATH];
char g_ConfigsFolder[PLATFORM_MAX_PATH];
bool g_LateLoad;

API g_API;
GameState g_State;
Points g_Points;
Group g_Groups;
Vote g_Vote;

Object g_Objects[MAX_OBJECTS + 1];
int g_TotalObjects;
Object g_SpawningObjects[MAXPLAYERS + 1];

ObjModel g_Model[MAX_MODELS + 1];
int g_TotalModels;

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
int g_EditingNode[MAXPLAYERS + 1] = {NO_NODE, ...};
int g_NewNode[MAXPLAYERS + 1] = {NO_NODE, ...};

Handle g_hSDK_OnPummelEnded;

Cookie g_Cookie_Hud;

//Sub-Plugins
#include "charger-racing/adminmenu.sp"
#include "charger-racing/api.sp"
#include "charger-racing/commands.sp"
#include "charger-racing/gamestate.sp"
#include "charger-racing/groups.sp"
#include "charger-racing/objects.sp"
#include "charger-racing/players.sp"
#include "charger-racing/points.sp"
#include "charger-racing/stocks.sp"
#include "charger-racing/tracks.sp"
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
	return APLRes_Success;
}

public void OnPluginStart() {
	//Translations
	LoadTranslations("common.phrases");
	LoadTranslations("l4d2-charger-racing-64.phrases");

	//ConVars
	CreateConVar("sm_l4d2_charger_racing_64_version", PLUGIN_VERSION, "Version control for this plugin.", FCVAR_DONTRECORD);
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
	convar_Rounds = CreateConVar("sm_l4d2_charger_racing_64_rounds", "5", "How many rounds total before the map automatically changes?", FCVAR_NOTIFY, true, 0.0);
	convar_Ratio = CreateConVar("sm_l4d2_charger_racing_64_ratio", "0.25", "Percentage of players to split into groups?\n(0.25 = 25%, 0.50 = 50%, etc.)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Spawns_Items = CreateConVar("sm_l4d2_charger_racing_64_spawns_items", "1", "Should the items be deleted and stopped from spawning entirely?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Spawns_Doors = CreateConVar("sm_l4d2_charger_racing_64_spawns_doors", "1", "Should the doors be deleted and stopped from spawning entirely?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Spawns_Infected = CreateConVar("sm_l4d2_charger_racing_64_spawns_infected", "1", "Should the common infected be deleted and stopped from spawning entirely?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Track_Culling = CreateConVar("sm_l4d2_charger_racing_64_track_culling", "5000.0", "After what distance from the player should the track no longer draw?", FCVAR_NOTIFY, true, 0.0);
	convar_Preparation_Delay = CreateConVar("sm_l4d2_charger_racing_64_preparation_delay", "10", "How many seconds to delay the preparation period?", FCVAR_NOTIFY, true, 0.0);
	convar_Death_On_Finish = CreateConVar("sm_l4d2_charger_racing_64_death_on_finish", "1", "Should the Charger actively racing if/once they reach the finish line?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Point_Start_Radius = CreateConVar("sm_l4d2_charger_racing_64_start_radius", "20.0", "What should the start radius be for path track nodes?", FCVAR_NOTIFY, true, 0.0);
	convar_Point_End_Radius = CreateConVar("sm_l4d2_charger_racing_64_end_radius", "25.0", "What should the end radius be for path track nodes?", FCVAR_NOTIFY, true, 0.0);
	convar_Point_Start_Color = CreateConVar("sm_l4d2_charger_racing_64_start_color", "255, 0, 0, 255", "What should the color of the starting node be?", FCVAR_NOTIFY);
	convar_Point_Current_Color = CreateConVar("sm_l4d2_charger_racing_64_current_color", "255, 255, 255, 255", "What should the color of the current node be?", FCVAR_NOTIFY);
	convar_Point_End_Color = CreateConVar("sm_l4d2_charger_racing_64_end_color", "0, 0, 255, 255", "What should the color of the end node be?", FCVAR_NOTIFY);
	AutoExecConfig();

	convar_Racing_Timer.AddChangeHook(OnPrepareTimerChanged);
	convar_Racing_Timer.AddChangeHook(OnRacingTimerChanged);
	convar_Charging_Particle.AddChangeHook(OnParticleChanged);
	convar_Spawns_Items.AddChangeHook(OnItemSpawnsChanged);
	convar_Spawns_Doors.AddChangeHook(OnDoorsSpawnsChanged);
	convar_Spawns_Infected.AddChangeHook(OnInfectedSpawnsChanged);
	convar_Preparation_Timer.AddChangeHook(OnPreparationTimeChanged);

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

	//Track Commands
	RegAdminCmd2("sm_votetrack", Command_VoteTrack, ADMFLAG_ROOT, "Start a vote for which track to be on.");
	RegAdminCmd2("sm_reloadtracks", Command_ReloadTracks, ADMFLAG_ROOT, "Reloads all tracks from the file.");
	RegAdminCmd2("sm_savetracks", Command_SaveTracks, ADMFLAG_ROOT, "Saves all tracks to the file.");
	RegAdminCmd2("sm_createtrack", Command_CreateTrack, ADMFLAG_ROOT, "Create a new track.");
	RegAdminCmd2("sm_deletetrack", Command_DeleteTrack, ADMFLAG_ROOT, "Deletes an existing track.");
	RegAdminCmd2("sm_edittrack", Command_EditTrack, ADMFLAG_ROOT, "Edit an existing track.");
	RegAdminCmd2("sm_settrack", Command_SetTrack, ADMFLAG_ROOT, "Sets the current track.");

	//Misc Admin Commands
	RegAdminCmd2("sm_start", Command_StartRace, ADMFLAG_ROOT, "Starts the race manually.");
	RegAdminCmd2("sm_startrace", Command_StartRace, ADMFLAG_ROOT, "Starts the race manually.");
	RegAdminCmd2("sm_end", Command_EndRace, ADMFLAG_ROOT, "Ends the race manually.");
	RegAdminCmd2("sm_endrace", Command_EndRace, ADMFLAG_ROOT, "Ends the race manually.");
	RegAdminCmd2("sm_setmode", Command_SetMode, ADMFLAG_ROOT, "Sets the mode manually.");
	RegAdminCmd2("sm_survivor", Command_SpawnSurvivor, ADMFLAG_ROOT, "Spawns a survivor where you're looking.");
	RegAdminCmd2("sm_spawnprop", Command_SpawnProp, ADMFLAG_ROOT, "Spawns a specific prop at the location you're looking at.");
	RegAdminCmd2("sm_spawnbot", Command_SpawnBot, ADMFLAG_ROOT, "Spawns a specific bot at the location you're looking at.");
	RegAdminCmd2("sm_delete", Command_Delete, ADMFLAG_ROOT, "Delete an object from the track.");
	RegAdminCmd2("sm_pause", Command_Pause, ADMFLAG_ROOT, "Pauses and resumes the timer.");
	RegAdminCmd2("sm_state", Command_State, ADMFLAG_ROOT, "Prints out the current state of the game.");

	//General
	g_State.Init();
	g_Points.Init();
	g_Groups.Init();

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

	g_Cookie_Hud = new Cookie("l4d2-charger-racing-64-hud", "Should the hud be shown or not?", CookieAccess_Public);

	//Second ticker and chat print
	CreateTimer(1.0, Timer_Seconds, _, TIMER_REPEAT);
	CPrintToChatAll("%sCharger Racing 64 has been loaded.", PLUGIN_TAG);

	RegAdminCmd("sm_changeteam", Command_ChangeTeam, ADMFLAG_GENERIC);
}

public Action Command_ChangeTeam(int client, int args) {
	char team[16];
	GetCmdArgString(team, sizeof(team));
	ChangeClientTeam(client, StringToInt(team));
	return Plugin_Handled;
}

public void OnPluginEnd() {
	for (int i = 0; i < g_TotalObjects; i++) {
		g_Objects[i].Delete();
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i)) {
			SetEntityMoveType(i, MOVETYPE_WALK);
		}
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

public void OnConfigsExecuted() {
	//All of these ConVars are required for the mode to function, otherwise other ConVars are put into configuration files.
	FindConVar("sb_all_bot_game").BoolValue = true;
	FindConVar("allow_all_bot_survivor_team").BoolValue = true;
	FindConVar("sb_unstick").BoolValue = false;
	FindConVar("mp_gamemode").SetString("versus");
	FindConVar("z_charge_duration").IntValue = 99999;
	FindConVar("sb_dont_shoot").BoolValue = true;
	FindConVar("director_no_survivor_bots").BoolValue = true;
	FindConVar("vs_max_team_switches").IntValue = 999;

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

		if (g_TotalTracks > 0 && g_State.track == NO_TRACK) {
			SetTrack(0, false);
		}

		//Kick the bots on live load if there is any and set the state of the game to preparing.
		KickBots();

		g_State.Preparing(2);
	}

	char sParticle[64];
	convar_Charging_Particle.GetString(sParticle, sizeof(sParticle));
	if (strlen(sParticle) > 0) {
		Precache_Particle_System(sParticle);
	}

	BuildPath(Path_SM, g_ConfigsFolder, sizeof(g_ConfigsFolder), "configs/charger-racing-64/");
	if (!DirExists(g_ConfigsFolder)) {
		CreateDirectory(g_ConfigsFolder, 511);
	}

	char sPath[PLATFORM_MAX_PATH];

	FormatEx(sPath, sizeof(sPath), "%spoints.cfg", g_ConfigsFolder);
	ParsePoints(sPath);

	FormatEx(sPath, sizeof(sPath), "%smodels.cfg", g_ConfigsFolder);
	ParseModels(sPath);
}

public void OnMapStart() {
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

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (!IsModeEnabled()) {
		return;
	}

	//By default, we don't have a track to pick at the start of the round.
	SetTrack(NO_TRACK);

	//If we have any available tracks on the map, just pick the 1st one.
	if (g_TotalTracks > 0 && g_State.track == NO_TRACK) {
		g_State.track = 0;
		g_API.Call_OnTrackSet(g_State.track);
	}
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

	float pos[3];
	GetClientEyePosition(client, pos);

	float cull_distance = convar_Track_Culling.FloatValue;

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

			if (GetVectorDistance(pos, origin) > cull_distance || GetVectorDistance(pos, origin2) > cull_distance) {
				continue;
			}

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

			if (GetVectorDistance(pos, origin) > cull_distance || GetVectorDistance(pos, origin2) > cull_distance) {
				continue;
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

		float start_radius = convar_Point_Start_Radius.FloatValue;
		float end_radius = convar_Point_End_Radius.FloatValue;
		int start_color[4]; start_color = GetConVarColor(convar_Point_Start_Color);
		int current_color[4]; current_color = GetConVarColor(convar_Point_Current_Color);
		int end_color[4]; end_color = GetConVarColor(convar_Point_End_Color);

		for (int i = 0; i < length; i++) {
			g_Tracks[track].GetNodeOrigin(i, origin);

			if (GetVectorDistance(pos, origin) > cull_distance) {
				continue;
			}

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

			if (GetVectorDistance(pos, origin2) > cull_distance) {
				continue;
			}

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

	//Track is set but not valid to run, don't tick it.
	if (!g_Tracks[track].Valid()) {
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

int GetWinnerForSingles() {
	int winner;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !g_Player[i].playing) {
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
	int winner;
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

bool AllPlayersFinished() {
	for (int i = 1; i <= MaxClients; i++) {
		if (g_Player[i].playing && !g_Player[i].finished) {
			return false;
		}
	}
	return true;
}

public void L4D_OnEnterGhostState(int client) {
	L4D_MaterializeFromGhost(client);

	if (L4D2_GetPlayerZombieClass(client) != L4D2ZombieClass_Charger) {
		L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
	}

	TeleportToSurvivorPos(client);

	if (g_Player[client].spectating) {
		ChangeClientTeam(client, 1);
	}

	#if defined DEBUG
	PrintToServer("%N has had a ghost state occur.", client);
	#endif
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	#if defined DEBUG
	PrintToServer("A player has spawned.");
	#endif

	if (!IsModeEnabled()) {
		return;
	}

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1 || IsFakeClient(client)) {
		return;
	}

	g_Player[client].charging = false;
	CreateTimer(2.0, Timer_DelaySpawn, userid, TIMER_FLAG_NO_MAPCHANGE);

	//If the state is currently set to none when the first player spawns on the server then start the preparation period.
	if (g_State.status == STATUS_NONE) {
		g_State.Preparing(3);
	}
}

public Action Timer_DelaySpawn(Handle timer, any userid) {
	if (!IsModeEnabled()) {
		return Plugin_Stop;
	}

	int client;
	if ((client = GetClientOfUserId(userid)) < 1 || !IsClientInGame(client)) {
		return Plugin_Stop;
	}

	//Move the player to the infected team if they're not on there already while spawning into the map.
	if (L4D_GetClientTeam(client) != L4DTeam_Infected) {
		ChangeClientTeam(client, view_as<int>(L4DTeam_Infected));
	}

	//Respawn the player if they currently aren't alive but on a team.
	if (!IsPlayerAlive(client)) {
		L4D_RespawnPlayer(client);
	}

	//Make sure the player is a charger and no other type of zombie.
	if (L4D2_GetPlayerZombieClass(client) != L4D2ZombieClass_Charger) {
		L4D_SetClass(client, view_as<int>(L4D2ZombieClass_Charger));
	}

	//Hack to kick bots.
	if (!IsFakeClient(client)) {
		FindConVar("director_no_survivor_bots").BoolValue = false;
	}

	//Teleport the player to a survivor position at the start of the map.
	if (g_State.status == STATUS_NONE || g_State.status == STATUS_PREPARING) {
		TeleportToSurvivorPos(client);
	}

	#if defined DEBUG
	PrintToServer("%N has had a delay spawn occur.", client);
	#endif

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
		return;
	}

	int random = positions[GetRandomInt(0, total - 1)];

	if (!IsValidEntity(random)) {
		return;
	}

	float vecOrigin[3];
	GetAbsOrigin(random, vecOrigin);

	TeleportEntity(client, vecOrigin, NULL_VECTOR, NULL_VECTOR);

	#if defined DEBUG
	PrintToServer("Teleporting %N to 'info_survivor_position' at [%.2f/%.2f/%.2f]: %i", client, vecOrigin[0], vecOrigin[1], vecOrigin[2], random);
	#endif
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

	if (g_Player[client].finished) {
		return;
	}

	if (g_State.status == STATUS_RACING && (g_State.mode == MODE_SINGLES || g_State.mode == MODE_GROUPS)) {
		if (AllPlayersFinished()) {
			EndRace();
		} else {
			g_State.PopQueue(true);
		}
	}
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

bool IsModeEnabled() {
	return convar_Enabled.BoolValue;
}

public Action Timer_Tick(Handle timer) {
	//Gamemode is disabled either through the ConVar or the Status so do nothing.
	if (!IsModeEnabled() || g_State.status == STATUS_NONE) {
		return Plugin_Continue;
	}

	//No players are available so set the Status of the mode to none and wait for players to join.
	if (!IsPlayersAvailable()) {
		#if defined DEBUG
		PrintToServer("No players are available, stopping the ticker and setting the state to none.");
		#endif

		g_State.None(1);
		return Plugin_Continue;
	}

	//We're preparing for race so we know players are on the server currently wanting to race.
	if (g_State.status == STATUS_PREPARING) {

		char sTime[64];
		FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", true);
		PrintHintTextToAll("Preparing to race... %s%s", sTime, g_State.paused ? " (Paused)" : "");

		if (!g_State.paused) {
			g_State.timer--;
		}

		if (g_State.timer <= 0.0) {
			g_State.SetupGroups();
			g_State.Ready(true);
		}
		
		return Plugin_Continue;
	}

	if (g_State.countdown > -1) {
		if (g_State.countdown > 0) {
			CPrintToChatAll("%s%t", PLUGIN_TAG, "race starting in print", g_State.countdown);
			PrintHintTextToAll("%s%t", PLUGIN_TAG_NOCOLOR, "race starting in center", g_State.countdown);
		} else {
			CPrintToChatAll("%s%t", PLUGIN_TAG, "race starting go print");
			PrintHintTextToAll("%s%t", PLUGIN_TAG_NOCOLOR, "race starting go center");
			
			g_State.Racing();
			g_API.Call_OnStartRace();

			for (int i = 1; i <= MaxClients; i++) {
				g_Player[i].finished = false;
				g_Player[i].time = GetGameTime();
				g_API.Call_OnPlayerStart(i);
			}
		}

		g_State.countdown--;

		return Plugin_Continue;
	}

	char sTime[64];
	FormatSeconds(g_State.timer, sTime, sizeof(sTime), "%M:%S", true);
	PrintHintTextToAll("Race ends in... %s", sTime);

	if (!g_State.paused) {
		g_State.timer--;
	}

	if (g_State.timer <= 0.0) {
		switch (g_State.mode) {
			case MODE_SINGLES, MODE_TEAMS: {
				if (AllPlayersFinished()) {
					CPrintToChatAll("%s%t", PLUGIN_TAG, "race times up print");
					//PrintHintTextToAll("%s%t", PLUGIN_TAG_NOCOLOR, "race times up center");

					EndRace();
				} else {
					g_State.PopQueue(true);
				}
			}

			case MODE_GROUPS, MODE_GROUPTEAMS: {
				if (g_State.group > g_Groups.GetTotalGroups()) {
					CPrintToChatAll("%s%t", PLUGIN_TAG, "race times up print");
					//PrintHintTextToAll("%s%t", PLUGIN_TAG_NOCOLOR, "race times up center");

					EndRace();
				} else {
					g_State.PopQueue(true);
				}
			}
		}
	}

	return Plugin_Continue;
}

public void OnClientConnected(int client) {
	g_Player[client].Init(client);
}

public void OnClientPutInServer(int client) {
	//No players should be taking damage in this mode unless specified.
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

	if (IsFakeClient(client) && GetClientCount(true) == 1) {
		KickClient(client);
	}
}

public void OnClientCookiesCached(int client) {
	char sValue[16];
	g_Cookie_Hud.Get(client, sValue, sizeof(sValue));

	if (strlen(sValue) == 0) {
		g_Player[client].hud = true;
		g_Cookie_Hud.Set(client, "1");
	} else {
		g_Player[client].hud = StringToBool(sValue);
	}
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype) {
	damage = 0.0;
	return Plugin_Changed;
}

public void OnClientDisconnect(int client) {
	if (IsFakeClient(client)) {
		return;
	}

	//Player disconnected from the game while racing so check if we need to pop queue or end the race since they're the last one.
	if (IsPlayerAlive(client) && !g_Player[client].spectating && g_State.status == STATUS_RACING && (g_State.mode == MODE_SINGLES || g_State.mode == MODE_GROUPS)) {
		if (AllPlayersFinished()) {
			EndRace();
		} else {
			g_State.PopQueue(true);
		}
	}

	//Empty server so set the state to none.
	if (!IsPlayersAvailable()) {
		g_State.None(2);
	}
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

public void Event_OnPummelStart(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	int target = GetClientOfUserId(event.GetInt("victim"));

	DropVictim(client, target);
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
		if (IsClientInGame(i) && IsFakeClient(i)) {
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

stock bool IsPlayersPlaying() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && g_Player[i].playing) {
			return true;
		}
	}
	return false;
}

public void Frame_DelayReady(any data) {
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsFakeClient(i)) {
			continue;
		}
		
		g_Player[i].playing = true;
		g_Player[i].finished = false;
	}
}

public void Frame_DelayFinish(any data) {
	for (int i = 1; i <= MaxClients; i++) {
		g_Player[i].playing = false;
		g_Player[i].finished = false;
		g_Player[i].points = 0;
		g_API.Call_OnPlayerFinish(i);
	}
}

public void Event_OnBotReplacePlayer(Event event, const char[] name, bool dontBroadcast) {
	int bot = GetClientOfUserId(event.GetInt("bot"));

	if (IsValidEntity(bot)) {
		KickClient(bot);
	}
}

public Action Timer_Prepare(Handle timer) {
	g_State.Preparing(4);
	return Plugin_Continue;
}

int GetTotalPlayers() {
	int amount;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsPlayerAlive(i) || L4D_GetClientTeam(i) != L4DTeam_Infected) {
			continue;
		}

		amount++;
	}

	return amount;
}

bool HasGroup(int client) {
	for (int i = 0; i < g_Groups.GetTotalGroups(); i++) {
		if (g_Groups.IsInGroup(i, client)) {
			return true;
		}
	}

	return false;
}

int FindAvailablePlayer() {
	int[] clients = new int[MaxClients];
	int total;

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || HasGroup(i)) {
			continue;
		}

		clients[total++] = i;
	}

	if (total < 1) {
		return -1;
	}

	return clients[GetRandomInt(0, total - 1)];
}

public int MenuAction_Void(Menu menu, MenuAction action, int param1, int param2) {
	return 0;
}

bool IsPlayersAvailable() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && L4D_GetClientTeam(i) == L4DTeam_Infected) {
			return true;
		}
	}

	return false;
}

bool g_bOutput1;
bool g_bOutput2;

public void Event_NoDraw(Event event, const char[] name, bool dontBroadcast) {
	if (L4D_IsFirstMapInScenario()) {
		g_bOutput1 = false;
		g_bOutput2 = false;

		CreateTimer(1.0, TimerStart);
		CreateTimer(5.0, TimerStart);
		CreateTimer(6.0, TimerStart);
		CreateTimer(6.5, TimerStart);
		CreateTimer(7.0, TimerStart);
		CreateTimer(8.0, TimerStart);
	}
}

public Action TimerStart(Handle timer)
{
	int entity = FindEntityByClassname(-1, "info_director");

	if (IsValidEntity(entity))
	{
		char director[32];
		GetEntPropString(entity, Prop_Data, "m_iName", director, sizeof(director));

		char buffer[128];
		for( int i = 0; i < 2; i++ )
		{
			entity = -1;
			while( (entity = FindEntityByClassname(entity, i == 0 ? "point_viewcontrol_survivor" : "point_viewcontrol_multiplayer")) != INVALID_ENT_REFERENCE )
			{
				if ((i == 0 && !g_bOutput1) || (i == 1 && !g_bOutput2))
				{
					FormatEx(buffer, sizeof(buffer), "OnUser1 %s:ReleaseSurvivorPositions::0:-1", director);
					SetVariantString(buffer);
					AcceptEntityInput(entity, "AddOutput");

					FormatEx(buffer, sizeof(buffer), "OnUser1 %s:FinishIntro::0:-1", director);
					SetVariantString(buffer);
					AcceptEntityInput(entity, "AddOutput");

					AcceptEntityInput(entity, "FireUser1");

					if( i == 0 )			g_bOutput1 = true;
					else if( i == 1 )		g_bOutput2 = true;
				} else {
					AcceptEntityInput(entity, "FireUser1");
				}

				SetVariantString("!self");
				AcceptEntityInput(entity, "StartMovement");
			}
		}
	}

	return Plugin_Continue;
}