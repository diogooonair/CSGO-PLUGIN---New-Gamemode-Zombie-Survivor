#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <colors_csgo>
#include <addicted>

#pragma semicolon 1

#define HIDE_RADAR_CSGO 1<<12 
#define ZombieModel "models/player/custom_player/kodua/frozen_nazi/frozen_nazi.mdl"
#define DATA "1.0"

#define CS_TEAM_SPEC 1
#define CS_TEAM_T 2 
#define CS_TEAM_CT 3

new Handle:g_Terrorist = INVALID_HANDLE;
new Handle:g_CTerrorist = INVALID_HANDLE;
new Handle:g_hCvarTeamName1  = INVALID_HANDLE;
new Handle:g_hCvarTeamName2 = INVALID_HANDLE;
new Handle:sm_roundend_overlay_team1 		 = INVALID_HANDLE;
new Handle:sm_roundend_overlay_team2		 = INVALID_HANDLE;
new Handle:timers[MAXPLAYERS+1];
Handle cvar_zombies_per_guard;
Handle g_aGuardQueue;


char g_szRestrictedSound[] = "buttons/button11.wav";

bool RevivedAsZombie[MAXPLAYERS+1];
Handle ReviveAsZombieTimer[MAXPLAYERS+1];
ConVar ZombieHealth, ZombieRespawn, ZombieGravity, ZombieSpeed;

public Plugin:myinfo = {
	name = "Minigame Zombie Survivor",
	author = "DiogoOnAir",
	description = "ZombieSurvivor",
	version = "1.2",
	url = "http://www.steamcommunity.com/id/diogo218dv"
}

public void OnPluginStart()
{
    ZombieHealth = CreateConVar("sm_Zombie_health", "150", "Zombie Health", 0, true, 0.0, false, 2.0);
    ZombieRespawn = CreateConVar("sm_Zombie_respawn_time", "25.0", "Time after death for respawn", 0, true, 0.1, false, 1.0);
    ZombieGravity = CreateConVar("sm_Zombie_gravity", "0.8", "0,1 = 100, 0,2 = 200, etc.", 0, true, 0.1, false, 1.0);
    ZombieSpeed = CreateConVar("sm_Zombie_speed", "1.0", "1.0 - normal speed", 0, true, 0.1, false, 1.0);

    HookEvent("player_spawn", PlayerSpawn);
    HookEvent("player_death", PlayerDeath);
    HookEvent("round_end", RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	
	g_Terrorist 	= CreateConVar("sm_teamname_t", "ZOMBIES", "Set your Terrorist team name.", FCVAR_PLUGIN);
	g_CTerrorist 	= CreateConVar("sm_teamname_ct", "GUARDS", "Set your Counter-Terrorist team name.", FCVAR_PLUGIN);
	
	HookConVarChange(g_Terrorist, OnConVarChange);
	HookConVarChange(g_CTerrorist, OnConVarChange);
	
	g_hCvarTeamName1 = FindConVar("mp_teamname_1");
	g_hCvarTeamName2 = FindConVar("mp_teamname_2");
	
	sm_roundend_overlay_team1 = CreateConVar("sm_roundend_overlay_team1", "models/overlays/teamt_win", "Overlay When Zombies Team Wins");
	sm_roundend_overlay_team2 = CreateConVar("sm_roundend_overlay_team2", "models/overlays/teamct_win", "Overlays When Survivors Team Wins");
	
	cvar_zombies_per_guard = CreateConVar("jb_zombies_per_guard", "2", "How many zombies for each guard.", _, true, 1.0);
	
	g_aGuardQueue = CreateArray();
	
	AddCommandListener(OnJoinTeam, "jointeam");
	HookEvent("player_team", Event_PlayerTeam_Post, EventHookMode_Post);
	
	RegConsoleCmd("sm_guard", OnGuardQueue);
	RegConsoleCmd("sm_viewqueue", ViewGuardQueue);
	RegConsoleCmd("sm_vq", ViewGuardQueue);

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i)) OnClientPutInServer(i);
    }
}

public void OnMapStart()
{
    PrecacheModel(ZombieModel);
    AddFileToDownloadsTable("models/player/custom_player/kodua/frozen_nazi/frozen_nazi.mdl");
    AddFileToDownloadsTable("models/player/custom_player/kodua/frozen_nazi/frozen_nazi.phy");
    AddFileToDownloadsTable("models/player/custom_player/kodua/frozen_nazi/frozen_nazi.vvd");
    AddFileToDownloadsTable("models/player/custom_player/kodua/frozen_nazi/frozen_nazi.dx90.vtx");
    AddFileToDownloadsTable("models/player/custom_player/kodua/frozen_nazi/arms.vvd");
    AddFileToDownloadsTable("models/player/custom_player/kodua/frozen_nazi/arms.mdl");
	AddFileToDownloadsTable("models/player/custom_player/kodua/frozen_nazi/arms.dx90.vtx");
	AddFileToDownloadsTable("models/overlays/teamt_win");
	AddFileToDownloadsTable("models/overlays/teamct_win");
	decl String:sBuffer[32];
	GetConVarString(g_Terrorist, sBuffer, sizeof(sBuffer));
	SetConVarString(g_hCvarTeamName2, sBuffer);
	GetConVarString(g_CTerrorist, sBuffer, sizeof(sBuffer));
	SetConVarString(g_hCvarTeamName1, sBuffer);
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	ShowOverlayToAll("");
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	new team = GetClientTeam(client);
	if(GetClientTeam(client) == CS_TEAM_T)
    {
        SetEntityModel(client, ZombieModel);
		SetEntPropString(client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kodua/frozen_nazi/arms.mdl");  
		SetGravity(client, ZombieGravity.FloatValue);
		SetEntityHealth(client, ZombieHealth.IntValue);
		SetSpeed(client, ZombieSpeed.FloatValue);
	}
}

public void OnClientPutInServer(int client)
{
    RevivedAsZombie[client] = false;
}

public void OnClientDisconnect(int client)
{
    if (ReviveAsZombieTimer[client] != null)
    {
        KillTimer(ReviveAsZombieTimer[client]);
        ReviveAsZombieTimer[client] = null;
    }
	RemovePlayerFromGuardQueue(client);
}

public OnConVarChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
	decl String:sBuffer[32];
	GetConVarString(hCvar, sBuffer, sizeof(sBuffer));
	
	if(hCvar == g_Terrorist)
		SetConVarString(g_hCvarTeamName2, sBuffer);
	else if(hCvar == g_CTerrorist)
		SetConVarString(g_hCvarTeamName1, sBuffer);
}

public Action PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (RevivedAsZombie[client])
    {
        SetEntityModel(client, ZombieModel);
		SetEntPropString (client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kodua/frozen_nazi/arms.mdl");
        SetEntityHealth(client, ZombieHealth.IntValue);
        SetGravity(client, ZombieGravity.FloatValue);
        SetSpeed(client, ZombieSpeed.FloatValue);
        FirstPerson(client);
		GivePlayerItem(client, "weapon_taser");
        return Plugin_Handled;
    }
	
    SetGravity(client, 1.0);
    SetSpeed(client, 1.0);
    FirstPerson(client);
    return Plugin_Continue;
}

public Action PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!RevivedAsZombie[client])
    {
        ReviveAsZombieTimer[client] = CreateTimer(ZombieRespawn.FloatValue, RevivePlayerAsZombie, GetClientUserId(client));
    }
	new team = GetClientTeam(client);
	if(GetClientTeam(client) == CS_TEAM_CT)
    {
        ChangeClientTeam(client, CS_TEAM_T);
	}
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && RevivedAsZombie[i])
        {
            RevivedAsZombie[i] = false;
        }

        if (ReviveAsZombieTimer[i] != null)
        {
            KillTimer(ReviveAsZombieTimer[i]);
            ReviveAsZombieTimer[i] = null;
        }
    }
	new winner_team = GetEventInt(event, "winner");
	decl String:overlaypath[PLATFORM_MAX_PATH];

	if (winner_team == 1)
	{
		GetConVarString(sm_roundend_overlay_team1, overlaypath, sizeof(overlaypath));
		ShowOverlayToAll(overlaypath);
	}
	else if (winner_team == 2)
	{
		GetConVarString(sm_roundend_overlay_team2, overlaypath, sizeof(overlaypath));
		ShowOverlayToAll(overlaypath);
	}
	FixTeamRatio();
}

public Action RevivePlayerAsZombie(Handle timer, any userid)
{
   int client = GetClientOfUserId(userid);
   if(client == 0) return;

   RevivedAsZombie[client] = true;
   CS_RespawnPlayer(client);
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool bDontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetClientTeam(client) != 3) 
		return Plugin_Continue;
		
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	return Plugin_Continue;
}

public Action SlayPlayer(Handle hTimer, any iUserId) 
{
	int client = GetClientOfUserId(iUserId);
	
	if (!IsValidClient(client))
		return Plugin_Stop;
		
	if (!IsPlayerAlive(client)) 
		return Plugin_Stop;
		
	if (GetClientTeam(client) != 3) 
		return Plugin_Stop;

	ForcePlayerSuicide(client);
	ChangeClientTeam(client, 2);
	CS_RespawnPlayer(client);
	
	return Plugin_Stop;
}

public void Event_PlayerTeam_Post(Handle hEvent, const char[] szName, bool bDontBroadcast)
{
	if(GetEventInt(hEvent, "team") != 3)
		return;
	
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	RemovePlayerFromGuardQueue(client);
}

public Action OnJoinTeam(int client, const char[] szCommand, int iArgCount)
{
	if(iArgCount < 1)
		return Plugin_Continue;
	
	char szData[2];
	GetCmdArg(1, szData, sizeof(szData));
	int iTeam = StringToInt(szData);
	
	if(!iTeam)
	{
		ClientCommand(client, "play %s", g_szRestrictedSound);
		PrintToChatAndConsole(client, "[{blue}Teams{default}] You cannot use auto select to join a team.");
		return Plugin_Handled;
	}
	
	if(iTeam != CS_TEAM_CT)
		return Plugin_Continue;

	if(!CanClientJoinGuards(client))
	{
		int iIndex = FindValueInArray(g_aGuardQueue, client);
		
		if(iIndex == -1)
			PrintToChatAndConsole(client, "[{blue}Teams{default}] Guards team full. Type !guard to join the queue.");
		else
			PrintToChatAndConsole(client, "[{blue}Teams{default}] Guards team full. You are {green}#%i{default} in the queue.", iIndex + 1);
		
		ClientCommand(client, "play %s", g_szRestrictedSound);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action ViewGuardQueue(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Handled;

	if(GetArraySize(g_aGuardQueue) < 1)
	{
		PrintToChatAndConsole(client, "[{blue}Teams{default}] The queue is currently empty.");
		return Plugin_Handled;
	}
	
	Handle hMenu = CreateMenu(ViewQueueMenuHandle);
	SetMenuTitle(hMenu, "Guard Queue:");

	for (int i; i < GetArraySize(g_aGuardQueue); i++)
	{
		if(!IsValidClient(GetArrayCell(g_aGuardQueue, i)))
			continue;

		char display[120];
		Format(STRING(display), "%N", GetArrayCell(g_aGuardQueue, i));
		AddMenuItem(hMenu, "", display);
	}
	
	DisplayMenu(hMenu, client, 0);
	
	return Plugin_Handled;
}

public int ViewQueueMenuHandle(Handle menu, MenuAction action, int client, int option)
{
	if (action == MenuAction_End)
	{
		CloneHandle(menu);
	}
}

public Action OnGuardQueue(int client, int iArgNum)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(GetClientTeam(client) != CS_TEAM_T)
	{
		ClientCommand(client, "play %s", g_szRestrictedSound);
		PrintToChatAndConsole(client, "[{blue}Teams{default}] You must be a prisoner to join the queue.");
		return Plugin_Handled;
	}
	
	
	int iIndex = FindValueInArray(g_aGuardQueue, client);
	int iQueueSize = GetArraySize(g_aGuardQueue);
	
	if(iIndex == -1)
	{
		if (CheckCommandAccess(client, "", ADMFLAG_RESERVATION, true))
		{
			if (iQueueSize == 0)
				iIndex = PushArrayCell(g_aGuardQueue, client);
			else
			{
				ShiftArrayUp(g_aGuardQueue, 0);
				SetArrayCell(g_aGuardQueue, 0, client);
			}

			PrintToChatAndConsole(client, "[{blue}Teams{default}] Thank you for being a {darkred}VIP{default}! You have been moved to the {green}front of the queue!{default}");
			PrintToChatAndConsole(client, "[{blue}Teams{default}] You are {green}#1{default} in the guard queue.");
			PrintToChatAndConsole(client, "[{blue}Teams{default}] Type !viewqueue to see who else is in the queue.");
			return Plugin_Handled;
		}
		else
		{
			iIndex = PushArrayCell(g_aGuardQueue, client);
			
			PrintToChatAndConsole(client, "[{blue}Teams{default}] You are {green}#%i{default} in the guard queue.", iIndex + 1);
			PrintToChatAndConsole(client, "[{blue}Teams{default}] Get {darkred}VIP{default} to be automatically moved to the front of the queue.");
			PrintToChatAndConsole(client, "[{blue}Teams{default}] Type !viewqueue to see who else is in the queue.");
			
			return Plugin_Handled;
		}
	}
	else
	{
		PrintToChatAndConsole(client, "[{blue}Teams{default}] You are {green}#%i{default} in the guard queue.", iIndex + 1);
		PrintToChatAndConsole(client, "[{blue}Teams{default}] Get {darkred}VIP{default} to be automatically moved to the front of the queue.");
		PrintToChatAndConsole(client, "[{blue}Teams{default}] Type !viewqueue to see who else is in the queue.");
	}
	return Plugin_Continue;
}

ShowOverlayToAll(const String:overlaypath[])
{
	// x = client index.
	for (new x = 1; x <= MaxClients; x++)
	{
		// If client isn't in-game, then stop.
		if (IsClientInGame(x) && !IsFakeClient(x))
		{
			ShowOverlayToClient(x, overlaypath);
		}
	}
}

public void SetSpeed(int client, float speed)
{
    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", speed);
}

public void SetGravity(int client, float amount)
{
    SetEntityGravity(client, amount / GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue"));
}

void FirstPerson(int client)
{
    if (IsValidClient(client) && RevivedAsZombie[client])
    {
        ClientCommand(client, "firstperson");
    }
    else
    {
        ClientCommand(client, "thirdperson");    
    }
}

stock bool RemovePlayerFromGuardQueue(int client)
{
	int iIndex = FindValueInArray(g_aGuardQueue, client);
	if(iIndex == -1)
		return;
	
	RemoveFromArray(g_aGuardQueue, iIndex);
}

ShowOverlayToClient(client, const String:overlaypath[])
{
	ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

stock void FixTeamRatio()
{
	bool bMovedPlayers;
	while(ShouldMovePrisonerToGuard())
	{
		int client;
		if(GetArraySize(g_aGuardQueue))
		{
			client = GetArrayCell(g_aGuardQueue, 0);
			RemovePlayerFromGuardQueue(client);
			
			PrintToChatAndConsoleAll("[{blue}Teams{default}] Finding a new guard from queue. Found %N.", client);
		}
		else
		{
			client = GetRandomClientFromTeam(CS_TEAM_T, true);
			PrintToChatAndConsoleAll("[{blue}Teams{default}] Guard queue is empty. Finding a random new guard. Found %N.", client);
		}
		
		if(!IsValidClient(client))
		{
			PrintToChatAndConsoleAll("[{blue}Teams{default}] Could not find a valid player to switch to guards. Ratio may be fucked.");
			break;
		}
		
		SetClientPendingTeam(client, CS_TEAM_CT);
		bMovedPlayers = true;
	}
	
	if(bMovedPlayers)
		return;
	
	while(ShouldMoveGuardToPrisoner())
	{
		int client = GetRandomClientFromTeam(CS_TEAM_CT, true);
		if(!client)
			break;
		
		SetClientPendingTeam(client, CS_TEAM_T);
	}
}

bool ShouldMoveGuardToPrisoner()
{
	int iNumGuards, iNumPrisoners;
	
	LoopValidPlayers(i)
	{	
		if (GetClientPendingTeam(i) == 2)
			iNumPrisoners++;
		else if (GetClientPendingTeam(i) == 3)
			 iNumGuards++;
	}

	if(iNumGuards <= 1)
		return false;

	if(iNumGuards <= RoundToFloor(float(iNumPrisoners) / GetConVarFloat(cvar_zombies_per_guard)))
		return false;

	return true;
}

stock int GetRandomClientFromTeam(int iTeam, bool bSkipCTBanned=true)
{
	int iNumFound;
	int clients[MAXPLAYERS];
	char szCookie[2];

	LoopValidPlayers(i)
	{
		if(!IsClientInGame(i))
			continue;

		if(GetClientPendingTeam(i) != iTeam)
			continue;

		if(bSkipCTBanned)
		{
			if(!AreClientCookiesCached(i))
				continue;
		}

		clients[iNumFound++] = i;
	}

	if(!iNumFound)
		return 0;

	return clients[GetRandomInt(0, iNumFound-1)];
}

bool ShouldMovePrisonerToGuard()
{
	int iNumGuards, iNumPrisoners;
	
	LoopValidPlayers(i)
	{	
		if (GetClientPendingTeam(i) == 2)
			iNumPrisoners++;
		else if (GetClientPendingTeam(i) == 3)
			 iNumGuards++;
	}
	
	iNumPrisoners--;
	iNumGuards++;
	
	if(iNumPrisoners < 1)
		return false;

	if(float(iNumPrisoners) / float(iNumGuards) < GetConVarFloat(cvar_zombies_per_guard))
		return false;
	
	return true;
}

stock bool CanClientJoinGuards(int client)
{
	int iNumGuards, iNumPrisoners;
	
	LoopValidPlayers(i)
	{	
		if (GetClientPendingTeam(i) == 2)
			iNumPrisoners++;
		else if (GetClientPendingTeam(i) == 3)
			 iNumGuards++;
	}
	
	iNumGuards++;
	if(GetClientPendingTeam(client) == CS_TEAM_T)
		iNumPrisoners--;
	
	if(iNumGuards <= 1)
		return true;
	
	float fNumPrisonersPerGuard = float(iNumPrisoners) / float(iNumGuards);
	if(fNumPrisonersPerGuard < GetConVarFloat(cvar_zombies_per_guard))
		return false;
	
	int iGuardsNeeded = RoundToCeil(fNumPrisonersPerGuard - GetConVarFloat(cvar_zombies_per_guard));
	if(iGuardsNeeded < 1)
		iGuardsNeeded = 1;
	
	int iQueueSize = GetArraySize(g_aGuardQueue);
	if(iGuardsNeeded > iQueueSize)
		return true;
	
	for(int i; i < iGuardsNeeded; i++)
	{
		if (!IsValidClient(i))
			continue;
		
		if(client == GetArrayCell(g_aGuardQueue, i))
			return true;
	}
	
	return false;
}

stock int GetClientPendingTeam(int client)
{
	return GetEntProp(client, Prop_Send, "m_iPendingTeamNum");
}

stock void SetClientPendingTeam(int client, int iTeam)
{
	SetEntProp(client, Prop_Send, "m_iPendingTeamNum", iTeam);
}