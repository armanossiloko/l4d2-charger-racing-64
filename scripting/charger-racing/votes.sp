enum struct Vote {
	int track;	//The track we're voting on.
	Menu menu;	//The menu handle itself.
}

enum VoteStats {
	VoteState_InProgress,
	VoteState_Active,
	VoteState_Empty
}

VoteStats CallTrackVote(int track = NO_TRACK) {
	if (IsVoteInProgress()) {
		return VoteState_InProgress;
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
			IntToString(i, sID, sizeof(sID));
			g_Vote.menu.AddItem(sID, g_Tracks[i].name);
		}

		if (g_Vote.menu.ItemCount == 0) {
			delete g_Vote.menu;
			return VoteState_Empty;
		}
	}

	g_Vote.menu.ExitButton = false;
	g_Vote.menu.DisplayVoteToAll(20);

	return VoteState_Active;
}

public int MenuHandler_VoteCallback(Menu menu, MenuAction action, int param1, int param2) {
	char sInfo[64]; char sDisplay[64];
	menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));
	
	switch (action) {
		case MenuAction_Select: {
			if (!IsModeEnabled()) {
				return 0;
			}

			if (g_Vote.track != NO_TRACK) {
				PrintToClients("%t", "voted for track", param1, g_Tracks[g_Vote.track].name);
			} else {
				PrintToClients("%t", "voted for next track", param1, sDisplay);
			}
		}

		case MenuAction_VoteEnd: {
			if (!IsModeEnabled()) {
				return 0;
			}

			PrintToClients("%t", "vote has ended");

			int winningvotes, totalvotes;
			GetMenuVoteInfo(param2, winningvotes, totalvotes);

			if (g_Vote.track != NO_TRACK) {
				//0 = yes, 1 = no
				if (param1 == 0) {
					if (g_State.status != STATUS_PREPARING) { 
						SetNextTrack(g_Vote.track);
						PrintToClients("%t", "vote results next track selected", g_Tracks[g_Vote.track].name, winningvotes, totalvotes);
					} else {
						SetTrack(g_Vote.track);
						PrintToClients("%t", "vote results track selected", g_Tracks[g_Vote.track].name, winningvotes, totalvotes);
					}
				} else {
					PrintToClients("%t", "vote results track not selected", g_Tracks[g_Vote.track].name, winningvotes, totalvotes);
				}

			} else {
				char sWinner[64]; char sName[64];
				menu.GetItem(param1, sWinner, sizeof(sWinner), _, sName, sizeof(sName));

				if (g_State.status != STATUS_PREPARING) {
					SetNextTrack(StringToInt(sWinner));
					PrintToClients("%t", "vote results next track selected", sName, winningvotes, totalvotes);
				} else {
					SetTrack(StringToInt(sWinner));
					PrintToClients("%t", "vote results track selected", sName, winningvotes, totalvotes);
				}
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