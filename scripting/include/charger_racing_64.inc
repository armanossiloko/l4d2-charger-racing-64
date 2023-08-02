#if defined _charger_racing_64_included
  #endinput
#endif
#define _charger_racing_64_included

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
	MODE_SINGLES,		//All players for themselves one by one and the player with the most points wins.
	MODE_GROUP,			//Same as singles but all at once.
	MODE_TEAMS,			//Players are split into teams and race one by one and the team with the most points wins.
	MODE_GROUPTEAMS		//NOT IMPLEMENTED
}

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
	//MarkNativeAsOptional("");
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
