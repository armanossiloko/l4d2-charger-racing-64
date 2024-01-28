//#define l4d2_spawnSurvBotsHack_version "1.0.0"

#if defined _l4d2_spawnSurvBotsHack_included
 #endinput
#endif
#define _l4d2_spawnSurvBotsHack_included

#define SURVBOTS_L4D1				(1 << 0) // 1
#define SURVBOTS_L4D2				(1 << 1) // 2
#define SURVBOTS_PASSING_L4D1		(1 << 2) // 4

/**
 * Create a survivor bot using the info_l4d1_survivor_spawn entity.
 *
 * @param origin		Origin to spawn at. Required.
 * @param character		Survivor character to spawn as, or -1 to pick random survivor.
 * @param team			Team to spawn as, or 2. Can only pick the Main (2) or the Passing (4) team.
 * @param survSet		Survivor set mode to base off of. Random survivor as well as 0-3 will be influenced by this.
 * 						SURVBOTS_L4D1 = Spawn playable L4D1 survivors (0-3).
 * 						SURVBOTS_L4D2 = Spawn playable L4D2 survivors (0-3).
 * 						SURVBOTS_PASSING_L4D1 = Spawn Passing L4D1 survivors (4-7).
 * @return				Player index of survivorbot, 0 if not found.
 * @error				No vector provided for origin.
 */
native int L4D2_CreateSurvivorBot_Hack(const float origin[3], 
			/*const float angles[3] = NULL_VECTOR,*/
			int character = -1,
			int team = 2,
			int survSet = SURVBOTS_L4D2);
// @param angles		Angles to spawn with, or NULL_VECTOR.
// Angles don't matter for the bots because they immediately override with their own angle movements
// even on spawn

public SharedPlugin __pl_l4d2_spawnSurvBotsHack = 
{
	name = "l4d2_spawnSurvBotsHack",
	file = "l4d2_spawnSurvBotsHack.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_spawnSurvBotsHack_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2_CreateSurvivorBot_Hack");
}
#endif
