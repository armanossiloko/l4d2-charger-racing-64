enum struct Group {
	ArrayList groups;

	void Init() {
		this.groups = new ArrayList(MaxClients);
	}

	void AddPlayer(int client) {
		int[] players = new int[MaxClients];
		players[0] = client;
		this.AddGroup(players, MaxClients);
	}

	void AddGroup(int[] players, int totalplayers) {
		this.groups.PushArray(players, totalplayers);
	}

	bool IsInGroup(int group, int client) {
		int[] players = new int[MaxClients];
		this.groups.GetArray(group, players);

		for (int i = 0; i < MaxClients; i++) {
			if (players[i] == client) {
				return true;
			}
		}

		return false;
	}

	bool AddToGroup(int group, int client) {
		if (this.IsInGroup(group, client)) {
			return false;
		}

		int[] players = new int[MaxClients];
		this.groups.GetArray(group, players);

		for (int i = 0; i < MaxClients; i++) {
			if (players[i] == 0) {
				players[i] = client;
				break;
			}
		}

		this.groups.SetArray(group, players);
		return true;
	}

	bool RemoveFromGroup(int group, int client) {
		if (!this.IsInGroup(group, client)) {
			return false;
		}

		int[] players = new int[MaxClients];
		int playerCount = this.groups.GetArray(group, players);

		for (int i = 0; i < playerCount; i++) {
			if (players[i] == client) {
				for (int j = i; j < playerCount - 1; j++) {
					players[j] = players[j + 1];
				}
				
				players[playerCount - 1] = 0;
				break;
			}
		}

		this.groups.SetArray(group, players, playerCount - 1);
		return true;
	}

	int GetGroupMember(int group) {
		int[] players = new int[MaxClients];
		this.groups.GetArray(group, players);
		return players[0];
	}

	int GetGroupMembers(int group, int[] players) {
		return this.groups.GetArray(group, players);
	}

	void RemoveGroup(int group) {
		this.groups.Erase(group);
	}

	int GetTotalGroups() {
		return this.groups.Length;
	}

	void Clear() {
		this.groups.Clear();
	}
}

bool HasGroup(int client) {
	for (int i = 0; i < g_Groups.GetTotalGroups(); i++) {
		if (g_Groups.IsInGroup(i, client)) {
			return true;
		}
	}

	return false;
}

bool IsTeamFinished(int group) {
	PrintToChatAll("IsTeamFinished = %i", group);

	int[] players = new int[MaxClients];
	g_Groups.GetGroupMembers(group, players);

	int client;
	for (int i = 0; i < MaxClients; i++) {
		if ((client = players[i]) < 1) {
			continue;
		}

		if (!g_Player[client].finished) {
			return false;
		}
	}

	return true;
}