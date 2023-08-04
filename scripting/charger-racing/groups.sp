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
		int player = this.groups.GetArray(group, players);

		for (int i = 0; i < player; i++) {
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
		int player = this.groups.GetArray(group, players);

		player++;
		players[player] = client;

		this.groups.SetArray(group, players, player);
		return true;
	}

	bool RemoveFromGroup(int group, int client) {
		if (!this.IsInGroup(group, client)) {
			return false;
		}

		int[] players = new int[MaxClients];
		int player = this.groups.GetArray(group, players);

		for (int i = 0; i < player; i++) {
			if (players[i] == client) {
				players[i] = 0;
				break;
			}
		}

		this.groups.SetArray(group, players, player);
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