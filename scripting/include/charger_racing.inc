#if defined _charger_racing_included
  #endinput
#endif
#define _charger_racing_included

//Each status is used to manage the game state.
enum Status {
	STATUS_NONE,		//No racing going on at all currently, mode is basically disabled.
	STATUS_PREPARING,	//Racing is about to start and players should be prepared.
	STATUS_START,		//The start of the race before everything else happens.
	STATUS_READY,		//The ready sequence where it counts down from 3 to GO!
	STATUS_RACING,		//The active race itself where players are participating.
	STATUS_FINISHED		//The finish line has been hit and now we're waiting for the end race call.
}

//Modes consist of how the races are played out for players.
enum Modes {
	MODE_SINGLES,		//All players for themselves one by one and the player with the most points wins.
	MODE_GROUPS,			//Same as singles but all at once.
	MODE_TEAMS,			//Players are split into teams and race one team at a time and the team with the most points wins.
	MODE_GROUPTEAMS		//Same as teams but all at once.
}

//Difficulties for tracks are just tags to help tell players how easy or hard this track is.
enum Difficulty {
	DIFFICULTY_EASY,
	DIFFICULTY_NORMAL,
	DIFFICULTY_HARD,
	DIFFICULTY_EXPERT,
	DIFFICULTY_IMPOSSIBLE	//Send Help.
}

//The action to take when managing tracks through the commands and menus.
enum TrackAction {
	Action_Create,	//We're creating a new track.
	Action_Delete,	//We're deleting this track entirely.
	Action_Edit,	//We're editing this track.
	Action_Set		//We're setting the current track.
}

//How the bot interacts with the play in terms of positive or negative effects.
enum BotType {
	BotType_Buff,
	BotType_Debuff
}

native void ChargerRacing_SetTrack(int track);
native int ChargerRacing_GetTrack();
native void ChargerRacing_SetMode(Modes mode);
native Modes ChargerRacing_GetMode();
native void ChargerRacing_SetStatus(Status status);
native Status ChargerRacing_GetStatus();
native bool ChargerRacing_IsBotTemporary(int bot);
native BotType ChargerRacing_GetBotType(int bot);

forward void ChargerRacing_OnStartRace();
forward void ChargerRacing_OnEndRace();
forward void ChargerRacing_OnPlayerStart(int client);
forward void ChargerRacing_OnPlayerFinish(int client);
forward void ChargerRacing_OnTrackSet(int track);
forward void ChargerRacing_OnModeSet(Modes mode);
forward void ChargerRacing_OnStatusChange(Status status);

#if !defined REQUIRE_PLUGIN
public __pl_charger_racing_64_SetNTVOptional()
{
	MarkNativeAsOptional("ChargerRacing_SetTrack");
	MarkNativeAsOptional("ChargerRacing_GetTrack");
	MarkNativeAsOptional("ChargerRacing_SetMode");
	MarkNativeAsOptional("ChargerRacing_GetMode");
	MarkNativeAsOptional("ChargerRacing_SetStatus");
	MarkNativeAsOptional("ChargerRacing_GetStatus");
	MarkNativeAsOptional("ChargerRacing_IsBotTemporary");
	MarkNativeAsOptional("ChargerRacing_GetBotType");
}
#endif

public SharedPlugin __pl_charger_racing_64 =
{
	name = "charger-racing",
	file = "l4d2-charger-racing-64.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
