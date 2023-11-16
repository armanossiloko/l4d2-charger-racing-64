enum struct Cookies {
	Cookie hud;

	void Init() {
		this.hud = new Cookie("l4d2-charger-racing-hud", "Should the hud be shown or not?", CookieAccess_Public);
	}
}

public void OnClientCookiesCached(int client) {
	char sValue[16];
	g_Cookies.hud.Get(client, sValue, sizeof(sValue));

	if (strlen(sValue) == 0) {
		g_Player[client].hud = true;
		g_Cookies.hud.Set(client, "1");
	} else {
		g_Player[client].hud = StringToBool(sValue);
	}
}