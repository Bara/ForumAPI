#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <xenforo_api>

ConVar g_cEnable = null;
ConVar g_cDebug = null;

Database g_dDatabase;

Handle g_hOnProcessed;
Handle g_hOnConnected;

bool g_bIsProcessed[MAXPLAYERS + 1];
int g_iUserID[MAXPLAYERS + 1];

bool g_bLateLoad;

public Plugin myinfo = 
{
	name = "XenForo - API",
	author = "Bara (Original Author: Drixevel)",
	description = "1.0.0",
	version = "",
	url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("XenForo_GetClientID", Native_GrabClientID);
	CreateNative("XenForo_IsProcessed", Native_IsProcessed);
	CreateNative("XenForo_TExecute", Native_TExecute);
	CreateNative("XenForo_IsConnected", Native_IsConnected);
	CreateNative("XenForo_GetDatabase", Native_GetDatabase);
	
	g_hOnProcessed = CreateGlobalForward("XF_OnProcessed", ET_Ignore, Param_Cell);
	g_hOnConnected = CreateGlobalForward("XF_OnConnected", ET_Ignore);
	
	RegPluginLibrary("xenforo_api");
	
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("xenforo_api");
	g_cEnable = AutoExecConfig_CreateConVar("xenforo_api_status", "1", "Status of the plugin: (1 = on, 0 = off)", _, true, 0.0, true, 1.0);
	g_cDebug = AutoExecConfig_CreateConVar("xenforo_api_debug", "0", "Enable the debug mode? This will print every sql querie into the log file.", _, true, 0.0, true, 0.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	RegConsoleCmd("sm_xfid", ShowID);
	
	if (SQL_CheckConfig("xenforo"))
	{
		Database.Connect(OnSQLConnect, "xenforo");
	}
	else
	{
		SetFailState("Can't found the entry \"xenforo\" in your databases.cfg!");
		return;
	}

	CSetPrefix("{darkblue}[XenForo]{default}");
}

public Action ShowID(int client, int args)
{
	if (g_iUserID[client] > 0)
	{
		CReplyToCommand(client, "Your XenForo ID is %i.", g_iUserID[client]);
	}
	else
	{
		CReplyToCommand(client, "You don't have a XenForo ID.");
	}
	return Plugin_Handled;
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
	{
		LogError("SQL ERROR: Error connecting to database - '%s'", error);
		SetFailState("Error connecting to \"xenforo\" database, please verify configurations & connections. (Check Error Logs)");
		return;
	}
	
	g_dDatabase = db;
	
	Call_StartForward(g_hOnConnected);
	Call_Finish();
	
	if (g_cDebug.BoolValue)
	{
		LogMessage("XenForo API has connected to SQL successfully.");
	}
	
	if (g_bLateLoad)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i))
			{
				OnClientConnected(i);
			}
			
			if (IsClientAuthorized(i))
			{
				char sAuth[64];
				GetClientAuthId(i, AuthId_Steam2, sAuth, sizeof(sAuth));
				OnClientAuthorized(i, sAuth);
			}
		}
		
		g_bLateLoad = false;
	}
}

public void OnClientConnected(int client)
{
	g_bIsProcessed[client] = false;
	g_iUserID[client] = -1;
}

public void OnClientAuthorized(int client, const char[] sSteamID)
{
	if (!g_cEnable.BoolValue || IsFakeClient(client))
	{
		return;
	}
	
	if (g_cDebug.BoolValue)
	{
		LogMessage("Starting process for user %N...", client);
	}
	
	char sCommunityID[64];
	SteamIDToCommunityID(sSteamID, sCommunityID, sizeof(sCommunityID));
	
	char sQuery[256];
	// For XenForo 1.5(?)
	// Format(sQuery, sizeof(sQuery), "SELECT user_id FROM xf_user_external_auth WHERE provider = 'steam' AND provider_key = '%s'", sCommunityID);
	Format(sQuery, sizeof(sQuery), "SELECT user_id FROM xf_user_connected_account WHERE provider = 'steam' AND provider_key = '%s'", sCommunityID);
	g_dDatabase.Query(SQL_GrabUserID, sQuery, GetClientUserId(client));
	
	if (g_cDebug.BoolValue)
	{
		LogMessage("SQL QUERY: OnClientAuthorized - Query: %s", sQuery);
	}
}

public void SQL_GrabUserID(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientOfUserId(data);
	
	if (client == 0)
	{
		return;
	}
	
	if (!IsClientConnected(client))
	{
		LogError("Error grabbing User Data: (Client is not Connected)");
		return;
	}
	
	if (!IsClientAuthorized(client))
	{
		LogError("Error grabbing User Data: (Client is not Authorized)");
		return;
	}
	
	if (g_cDebug.BoolValue)
	{
		LogMessage("Retrieving data for %N...", client);
	}
	
	if (db == null)
	{
		LogError("SQL ERROR: Error grabbing User Data for '%N': '%s'", client, error);
		return;
	}
	
	if (results.FetchRow())
	{
		if (results.IsFieldNull(0))
		{
			LogError("Error retrieving User Data: (Field is null)");
			return;
		}
		
		g_iUserID[client] = results.FetchInt(0);
		g_bIsProcessed[client] = true;
		
		Call_StartForward(g_hOnProcessed);
		Call_PushCell(client);
		Call_Finish();
		
		if (g_cDebug.BoolValue)
		{
			LogMessage("User '%N' has been processed successfully!", client);
		}
	}
	else
	{
		LogError("Error retrieving User (\"%L\") Data: (Row not fetched)", client);
	}
}

void SQL_TQuery_XenForo(SQLQueryCallback callback, const char[] sQuery, any data = 0, DBPriority prio = DBPrio_Normal)
{
	if (g_dDatabase != null)
	{
		g_dDatabase.Query(callback, sQuery, data, prio);
		
		if (g_cDebug.BoolValue)
		{
			LogMessage("SQL Executed: %s", sQuery);
		}
	}
}

public int Native_GrabClientID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (g_bIsProcessed[client])
	{
		return g_iUserID[client];
	}
	
	return -1;
}

public int Native_IsProcessed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	return g_bIsProcessed[client];
}

public int Native_TExecute(Handle plugin, int numParams)
{
	int size;
	GetNativeStringLength(1, size);
	
	char[] sQuery = new char[size];
	GetNativeString(1, sQuery, size);
	
	DBPriority prio = GetNativeCell(2);
	
	SQL_TQuery_XenForo(SQL_EmptyCallback, sQuery, 0, prio);
	LogError("SQL QUERY: XenForo_TExecute - Query: '%s'", sQuery);
}

public int SQL_EmptyCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("Query error by void: '%s'", error);
		return;
	}
}

public int Native_IsConnected(Handle plugin, int numParams)
{
	return g_dDatabase != null;
}

public int Native_GetDatabase(Handle plugin, int numParams)
{
	return view_as<int>(g_dDatabase);
}
