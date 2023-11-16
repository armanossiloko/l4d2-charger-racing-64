enum struct GameDataHandlers {
	Handle OnPummelEnded;

	void Init() {
		GameData gamedata = new GameData("l4d2-charger-racing.games");

		if (gamedata == null) {
			SetFailState("Failed to load game data file: l4d2-charger-racing.games.txt");
			return;
		}

		StartPrepSDKCall(SDKCall_Player);
		
		if (PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTerrorPlayer::OnPummelEnded")) {
			PrepSDKCall_AddParameter(SDKType_String, SDKPass_ByRef);
			PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
			this.OnPummelEnded = EndPrepSDKCall();
			
			if ((this.OnPummelEnded = EndPrepSDKCall()) == null) {
				SetFailState("Failed to create SDKCall: CTerrorPlayer::OnPummelEnded");
			}
		} else {
			SetFailState("Failed to find signature: CTerrorPlayer::OnPummelEnded");
		}

		delete gamedata;
	}
}