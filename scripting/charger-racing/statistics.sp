void OpenStatsPanel(int client) {
	Panel panel = new Panel();
	panel.SetTitle("Your Statistics");

	char text[64];

	FormatEx(text, sizeof(text), "Races: %i", g_Player[client].stats.races);
	panel.DrawText(text);

	FormatEx(text, sizeof(text), "Wins: %i", g_Player[client].stats.wins);
	panel.DrawText(text);

	FormatEx(text, sizeof(text), "Losses: %i", g_Player[client].stats.losses);
	panel.DrawText(text);

	FormatEx(text, sizeof(text), "Total Points: %i", g_Player[client].stats.totalpoints);
	panel.DrawText(text);

	panel.DrawItem("Exit");

	panel.Send(client, MenuAction_Void, MENU_TIME_FOREVER);
}

bool IncrementStat(int client, const char[] field, int amount = 1) {
	if (!IsClientAuthorized(client) || IsFakeClient(client) || strlen(field) == 0) {
		return false;
	}

	if (amount < 1) {
		return false;
	}

	char query[2048];
	g_Database.Format(query, sizeof(query), "UPDATE %s SET %s = %s + %i WHERE accountid = %i;", TABLE_STATS, field, field, amount, GetSteamAccountID(client));
	g_Database.Query(OnIncrementStat, query, _, DBPrio_Low);

	return true;
}

public void OnIncrementStat(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while incrementing stat: %s", error);
	}
}