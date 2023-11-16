
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