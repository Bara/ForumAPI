#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <xenforo_api>

ConVar g_cEnable = null;
ConVar g_cDebug = null;

Database g_dDatabase;

Handle g_hOnGrabProcessed;
Handle g_hOnInfoProcessed;
Handle g_hOnConnected;

char g_sName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
int g_iPrimaryGroup[MAXPLAYERS + 1] = { -1, ... };
ArrayList g_aSecondaryGroups[MAXPLAYERS + 1] = { null, ... };
char g_sCustomTitle[MAXPLAYERS + 1];

StringMap g_smGroups = null;
StringMap g_smGroupBanner = null;
StringMap g_smUserFields = null;

bool g_bIsProcessed[MAXPLAYERS + 1] = { false, ... };
int g_iUserID[MAXPLAYERS + 1] = { -1, ... };

public Plugin myinfo = 
{
	name = "XenForo - API",
	author = "Bara (Original Author: Drixevel)",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("XenForo_GetClientID", Native_GetClientID);
	CreateNative("XenForo_GetClientName", Native_GetClientName);
	CreateNative("XenForo_GetClientCustomTitle", Native_GetClientCustomTitle);
	CreateNative("XenForo_GetClientPrimaryGroup", Native_GetClientPrimaryGroup);
	CreateNative("XenForo_GetClientSecondaryGroups", Native_GetClientSecondaryGroups);
	CreateNative("XenForo_IsProcessed", Native_IsProcessed);
	CreateNative("XenForo_TExecute", Native_TExecute);
	CreateNative("XenForo_IsConnected", Native_IsConnected);
	CreateNative("XenForo_GetDatabase", Native_GetDatabase);
	CreateNative("XenForo_GetGroupList", Native_GetGroupList);
	CreateNative("XenForo_GetGroupBannerText", Native_GetGroupBannerText);

	g_hOnGrabProcessed = CreateGlobalForward("XF_OnProcessed", ET_Ignore, Param_Cell, Param_Cell);
	g_hOnInfoProcessed = CreateGlobalForward("XF_OnInfoProcessed", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
	g_hOnConnected = CreateGlobalForward("XF_OnConnected", ET_Ignore);
	
	RegPluginLibrary("xenforo_api");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("xenforo_api");
	g_cEnable = AutoExecConfig_CreateConVar("xenforo_api_status", "1", "Status of the plugin: (1 = on, 0 = off)", _, true, 0.0, true, 1.0);
	g_cDebug = AutoExecConfig_CreateConVar("xenforo_api_debug", "1", "Enable the debug mode? This will print every sql querie into the log file.", _, true, 0.0, true, 1.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	RegConsoleCmd("sm_xfid", Command_XFID);
	
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

public Action Command_XFID(int client, int args)
{
	if (g_iUserID[client] > 0)
	{
		CReplyToCommand(client, "Your XenForo ID is %d.", g_iUserID[client]);
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
		LogError("[XenForo-API] (OnSQLConnect) SQL ERROR: Error connecting to database - '%s'", error);
		SetFailState("[XenForo-API] (OnSQLConnect) Error connecting to \"xenforo\" database, please verify configurations & connections. (Check Error Logs)");
		return;
	}
	
	g_dDatabase = db;
	
	Call_StartForward(g_hOnConnected);
	Call_Finish();

	LoadXenForoGroups();
	LoadXenForoUserFields();
	
	if (g_cDebug.BoolValue)
	{
		LogMessage("XenForo API has connected to SQL successfully.");
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			OnClientConnected(i);
		}
		
		if (IsClientValid(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
}

public void OnClientConnected(int client)
{
	g_bIsProcessed[client] = false;
	g_iUserID[client] = -1;
	g_iPrimaryGroup[client] = -1;
	delete g_aSecondaryGroups[client];
}

public void OnClientPostAdminCheck(int client)
{
	if (!g_cEnable.BoolValue || !IsClientValid(client))
	{
		return;
	}
	
	if (g_cDebug.BoolValue)
	{
		LogMessage("Starting process for user %N...", client);
	}
	
	char sCommunityID[64];
	GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID));
	
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "SELECT user_id FROM xf_user_connected_account WHERE provider = 'steam' AND provider_key = '%s'", sCommunityID);
	g_dDatabase.Query(SQL_GrabUserID, sQuery, GetClientUserId(client));
	
	if (g_cDebug.BoolValue)
	{
		LogMessage("SQL QUERY: OnClientPostAdminCheck - Query: %s", sQuery);
	}
}

public void SQL_GrabUserID(Database db, DBResultSet results, const char[] error, int userid)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[XenForo-API] (SQL_GrabUserID) Fail at Query: %s", error);
		return;
	}
	else
	{
		int client = GetClientOfUserId(userid);
		
		if (client > 0 && !IsClientValid(client))
		{
			LogError("[XenForo-API] (SQL_GrabUserID) Error grabbing User Data: Client invalid");
			return;
		}
		
		if (g_cDebug.BoolValue)
		{
			LogMessage("[XenForo-API] (SQL_GrabUserID) Retrieving data for %N...", client);
		}
		
		if (results.FetchRow())
		{
			if (results.IsFieldNull(0))
			{
				LogError("[XenForo-API] (SQL_GrabUserID) Error retrieving User Data: (Field is null)");
				return;
			}
			
			g_iUserID[client] = results.FetchInt(0);
			g_bIsProcessed[client] = true;
			
			Call_StartForward(g_hOnGrabProcessed);
			Call_PushCell(client);
			Call_PushCell(g_iUserID[client]);
			Call_Finish();
			
			if (g_cDebug.BoolValue)
			{
				LogMessage("[XenForo-API] (SQL_GrabUserID) User '%N' has been processed successfully!", client);
			}

			char sQuery[256];
			Format(sQuery, sizeof(sQuery), "SELECT username, user_group_id, secondary_group_ids, custom_title FROM xf_user WHERE user_id = '%d'", g_iUserID[client]);
			g_dDatabase.Query(SQL_UserInformations, sQuery, userid);
		}
		else
		{
			LogError("[XenForo-API] (SQL_GrabUserID) Error retrieving User (\"%L\") Data: (Row not fetched)", client);
		}
	}
}

public void SQL_UserInformations(Database db, DBResultSet results, const char[] error, int userid)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[XenForo-API] (SQL_UserInformations) Fail at Query: %s", error);
		return;
	}
	else
	{
		int client = GetClientOfUserId(userid);
		
		if (!IsClientValid(client))
		{
			LogError("[XenForo-API] (SQL_UserInformations) Error grabbing User informations: Client invalid");
			return;
		}
		
		if (g_cDebug.BoolValue)
		{
			LogMessage("[XenForo-API] (SQL_UserInformations) Retrieving informations for %N...", client);
		}
		
		if (results.FetchRow())
		{
			if (results.IsFieldNull(0))
			{
				LogError("[XenForo-API] (SQL_UserInformations) Error retrieving User informations: (Field is null)");
				return;
			}

			results.FetchString(0, g_sName[client], sizeof(g_sName[]));

			g_iPrimaryGroup[client] = results.FetchInt(1);

			char sSecondaryIDs[64];
			results.FetchString(2, sSecondaryIDs, sizeof(sSecondaryIDs));

			char sSecondaryGroups[12][12];
			int iSecondaryCount = ExplodeString(sSecondaryIDs, ",", sSecondaryGroups, sizeof(sSecondaryGroups), sizeof(sSecondaryGroups[]));

			delete g_aSecondaryGroups[client];
			g_aSecondaryGroups[client] = new ArrayList();

			for (int i = 0; i < iSecondaryCount; i++)
			{
				g_aSecondaryGroups[client].Push(StringToInt(sSecondaryGroups[i]));
			}

			results.FetchString(3, g_sCustomTitle[client], sizeof(g_sCustomTitle[]));
			
			Call_StartForward(g_hOnInfoProcessed);
			Call_PushCell(client);
			Call_PushString(g_sName[client]);
			Call_PushCell(g_iPrimaryGroup[client]);
			Call_PushCell(g_aSecondaryGroups[client]);
			Call_Finish();
			
			if (g_cDebug.BoolValue)
			{
				LogMessage("[XenForo-API] (SQL_UserInformations) User informations for'%N' has been processed successfully!", client);
			}
		}
		else
		{
			LogError("[XenForo-API] (SQL_UserInformations) Error retrieving User (\"%L\") informations: (Row not fetched)", client);
		}
	}
}

void LoadXenForoUserFields()
{
	char sQuery[128];
	Format(sQuery, sizeof(sQuery), "SELECT field_id FROM xf_user_field");
	g_dDatabase.Query(SQL_UserFields, sQuery);
}

public void SQL_UserFields(Database db, DBResultSet results, const char[] error, int userid)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[XenForo-API] (SQL_UserFields) Fail at Query: %s", error);
		return;
	}
	else
	{
		if (results.HasResults)
		{
			while (results.FetchRow())
			{
				char sField[64];
				results.FetchString(0, sField, sizeof(sField));

				if (g_cDebug.BoolValue)
				{
					LogMessage("[XenForo-API] (SQL_UserFields) Field ID: %s", sField);
				}

				char sTitle[128];
				Format(sTitle, sizeof(sTitle), "user_field_title.%s", sField);

				char sQuery[512];
				Format(sQuery, sizeof(sQuery), "SELECT phrase_text FROM xf_phrase WHERE title = \"%s\"", sTitle);
				DataPack pack = new DataPack();
				pack.WriteString(sField);
				g_dDatabase.Query(SQL_GetUserFieldPhrase, sQuery, pack);
			}
		}
	}
}

public void SQL_GetUserFieldPhrase(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[XenForo-API] (SQL_GetUserFieldPhrase) Fail at Query: %s", error);
		delete pack;
		return;
	}
	else
	{
		pack.Reset();

		char sField[32];
		pack.ReadString(sField, sizeof(sField));

		delete pack;

		if (g_cDebug.BoolValue)
		{
			LogMessage("[XenForo-API] (SQL_GetUserFieldPhrase) Retrieving phrase for user_field %s...", sField);
		}
		
		if (results.FetchRow())
		{
			if (results.IsFieldNull(0))
			{
				LogError("[XenForo-API] (SQL_GetUserFieldPhrase) Error retrieving user_field phrase (%s): (Field is null)", sField);
				return;
			}

			char sPhrase[64];
			results.FetchString(0, sPhrase, sizeof(sPhrase));

			delete g_smUserFields;
			g_smUserFields = new StringMap();
			g_smUserFields.SetString(sField, sPhrase);

			if (g_cDebug.BoolValue)
			{
				LogMessage("[XenForo-API] (SQL_GetUserFieldPhrase) Added user_field %s (Name: %s)", sField, sPhrase);
			}
		}
	}
}

void LoadXenForoGroups()
{
	char sQuery[256];
	Format(sQuery, sizeof(sQuery), "SELECT user_group_id, title, banner_text FROM xf_user_group");
	g_dDatabase.Query(SQL_GetXenForoGroups, sQuery);
}

public int SQL_GetXenForoGroups(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		LogError("[XenForo-API] (SQL_GetXenForoGroups) Query error by void: '%s'", error);
		return;
	}
	else
	{
		if (results.HasResults)
		{
			delete g_smGroups;
			g_smGroups = new StringMap();

			delete g_smGroupBanner;
			g_smGroupBanner = new StringMap();

			while (results.FetchRow())
			{
				int groupid = results.FetchInt(0);

				char sKey[12];
				IntToString(groupid, sKey, sizeof(sKey));

				char sName[64];
				results.FetchString(1, sName, sizeof(sName));

				char sBanner[32];
				results.FetchString(2, sBanner, sizeof(sBanner));

				if (g_cDebug.BoolValue)
				{
					LogMessage("[XenForo-API] (SQL_GetXenForoGroups) GroupID: %d, Name: %s, Banner: %s", groupid, sName, sBanner);
				}

				g_smGroups.SetString(sKey, sName);

				if (strlen(sBanner) > 1)
				{
					g_smGroupBanner.SetString(sKey, sBanner);
				}
			}
		}
	}
}

public int Native_GetClientID(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (g_bIsProcessed[client])
	{
		return g_iUserID[client];
	}
	
	return -1;
}

public int Native_GetClientPrimaryGroup(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (g_bIsProcessed[client])
	{
		return g_iPrimaryGroup[client];
	}
	
	return -1;
}

public int Native_GetClientSecondaryGroups(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (g_bIsProcessed[client] && g_aSecondaryGroups[client] != null)
	{
		return view_as<int>(g_aSecondaryGroups[client]);
	}
	
	return -1;
}

public int Native_GetClientName(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (g_bIsProcessed[client])
	{
		SetNativeString(2, g_sName[client], sizeof(g_sName[]));
		return true;
	}
	
	return false;
}

public int Native_GetClientCustomTitle(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (g_bIsProcessed[client])
	{
		SetNativeString(2, g_sCustomTitle[client], sizeof(g_sCustomTitle[]));
		return true;
	}
	
	return false;
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
	
	g_dDatabase.Query(SQL_EmptyCallback, sQuery, 0, prio);
	LogError("[XenForo-API] (Native_TExecute) SQL QUERY: XenForo_TExecute - Query: '%s'", sQuery);
}

public int SQL_EmptyCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
	{
		LogError("[XenForo-API] (SQL_EmptyCallback) Query error by void: '%s'", error);
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

stock bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
		{
			return true;
		}
	}
	
	return false;
}

public int Native_GetGroupList(Handle plugin, int numParams)
{
	if (g_smGroups != null)
	{
		return view_as<int>(g_smGroups);
	}

	return -1;
}

public int Native_GetGroupBannerText(Handle plugin, int numParams)
{
	if (g_smGroupBanner != null)
	{
		return view_as<int>(g_smGroupBanner);
	}

	return -1;
}
