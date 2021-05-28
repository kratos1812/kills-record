#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLAYER_DEATH 'p'
#define ROUND_START 'r'

#pragma newdecls required

/* Hashmap to store the records in, even when a player leaves the server */
/* All the entries are alway deleted when a new map starts */
StringMap g_hRecords;

/* Variable to store the count of kills for each client */
int g_iKills[MAXPLAYERS + 1];

/* Console Variables */
ConVar g_cvShowMode; 

/* Too lazy to use real translations so I'm using this */
/* Feel free to modify by your wish but these should always be a string! */
#define __ANNOUNCE_BROKE_RECORD__ "You broke your kills record of\x09 %i kills\x01. New record:\x05 %i"
#define __ANNOUNCE_KILLS_RECORD__ "Player\x04 %N\x01 has a record of\x09 %i kills\x01 in a single round this map!"

/* Variable for client with no kills record. Used in formating. */
/* Should not be modified */
#define __NO_KILLS_RECORD__ 0

public Plugin myinfo = 
{
	name = "Kills Record",
	author = "kRatoss"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_record", Command_ShowRecord);
	RegConsoleCmd("sm_records", Command_ShowRecords);
	
	HookEvent("player_death", HookEvent_Callback);
	HookEvent("round_start", HookEvent_Callback);
	
	g_hRecords = new StringMap();
	
	g_cvShowMode = CreateConVar("sm_killsrecord_show_to_all", "1", "Should the plugin print the output of \"!record\" to everyone or just the player that used the command?", _, true, 0.0, true, 1.0);

	AutoExecConfig(true, "killsrecord");
}

public Action Command_ShowRecord(int iClient, int iArgs)
{
	if(iClient == 0 || !IsClientInGame(iClient))
	{
		ReplyToCommand(iClient, "[SM] This command is in-game only!");
		return Plugin_Handled;
	}
	
	static char sKey[PLATFORM_MAX_PATH];
	FormatEx(sKey, sizeof(sKey), "%i", GetSteamAccountID(iClient));
	
	static int iRecord;
	if(g_hRecords.GetValue(sKey, iRecord) && iRecord > 0)
	{
		switch(g_cvShowMode.IntValue)
		{
			case 1:PrintToChatAll(__ANNOUNCE_KILLS_RECORD__, iClient, iRecord);
			case 0:PrintToChat(iClient, __ANNOUNCE_KILLS_RECORD__, iClient, iRecord);
		}
	}
	else
	{
		switch(g_cvShowMode.IntValue)
		{
			case 1:PrintToChatAll(__ANNOUNCE_KILLS_RECORD__, iClient, __NO_KILLS_RECORD__);
			case 0:PrintToChat(iClient, __ANNOUNCE_KILLS_RECORD__, iClient, __NO_KILLS_RECORD__);
		}
	}

	return Plugin_Handled;
}

public Action Command_ShowRecords(int iClient, int iArgs)
{
	if(iClient == 0 || !IsClientInGame(iClient))
	{
		ReplyToCommand(iClient, "[SM] This command is in-game only!");
		return Plugin_Handled;
	}
	
	static char sKey[PLATFORM_MAX_PATH];
	static char sAcc[PLATFORM_MAX_PATH];
	static char sItem[PLATFORM_MAX_PATH];
	
	static int iRecord;
	
	static StringMapSnapshot hSnapshot;
	
	hSnapshot = g_hRecords.Snapshot();
	
	Menu hMenu = new Menu(__MenuHandler__);
	
	for (int iIter = 0; iIter < hSnapshot.Length; iIter++)
	{
		hSnapshot.GetKey(iIter, sKey, sizeof(sKey));
		g_hRecords.GetValue(sKey, iRecord);
		
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if(IsClientInGame(iPlayer))
			{
				FormatEx(sAcc, sizeof(sAcc), "%d", GetSteamAccountID(iPlayer));
				
				if(strcmp(sAcc, sKey) == 0)
				{
					FormatEx(sItem, sizeof(sItem), "%N | Record: %i", iPlayer, iRecord);
					hMenu.AddItem("", sItem, ITEMDRAW_DISABLED);
					
					break;
				}
			}
		}
	}
	
	hMenu.Display(iClient, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public int __MenuHandler__(Menu hMenu, MenuAction iAction, int iParam1, int iParam2)
{
	switch(iAction)
	{
		case MenuAction_End : delete hMenu;
	}
}

public void HookEvent_Callback(Event hEvent, const char[] sName, bool dontBroadcast)
{
	switch(sName[0])
	{
		case PLAYER_DEATH:
		{
			static char sKey[PLATFORM_MAX_PATH];
			
			static int iClient;
			static int iRecord;
			
			iClient = GetClientOfUserId(hEvent.GetInt("attacker"));
			
			if(IsClientInGame(iClient) && !IsFakeClient(iClient))
			{
				FormatEx(sKey, sizeof(sKey), "%i", GetSteamAccountID(iClient));
				
				if(g_hRecords.GetValue(sKey, iRecord))
				{
					if(++g_iKills[iClient] > iRecord)
					{
						g_hRecords.SetValue(sKey, g_iKills[iClient], true);
						PrintToChat(iClient, __ANNOUNCE_BROKE_RECORD__, g_iKills[iClient] - 1, g_iKills[iClient]);
					}
				}
				else
				{
					g_hRecords.SetValue(sKey, ++g_iKills[iClient], true);
				}		
			}
			
		}
		case ROUND_START:
		{
			for (int iId = 1; iId <= MaxClients; iId++)
			{
				g_iKills[iId] = 0;
			}
		}
	}
}

public void OnMapStart() { g_hRecords.Clear(); }
public void OnMapEnd() 	{ g_hRecords.Clear(); }