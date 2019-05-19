#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <xenforo_api>

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

Database g_dDB = null;

int g_iCredits[MAXPLAYERS + 1] = { -1, ... };

Handle g_hOnCreditsUpdate = null;

ConVar g_cColumn = null;

char g_sColumn[64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("XenForo_GetClientCredits", Native_GetClientCredits);
	CreateNative("XenForo_AddClientCredits", Native_AddClientCredits);
	CreateNative("XenForo_RemoveClientCredits", Native_RemoveClientCredits);

	g_hOnCreditsUpdate = CreateGlobalForward("XF_OnCreditsUpdate", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	
	RegPluginLibrary("xenforo_credits");

	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "Xenforo - Credits",
	author = "Bara", 
	description = "",
	version = "1.0.0", 
	url = "github.com/Bara"
};

public void OnPluginStart()
{
	CreateTimer(30.0, Timer_GetAllClientCredits, _, TIMER_REPEAT);

	if (XenForo_IsConnected())
	{
		g_dDB = XenForo_GetDatabase();
	}

	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("xenforo_credits");
	g_cColumn = AutoExecConfig_CreateConVar("xenforo_credits_column", "dbtech_credits", "Name of the column for reading and writing the players credits.");
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_cColumn.GetString(g_sColumn, sizeof(g_sColumn));
	g_cColumn.AddChangeHook(CVar_OnChange);

	CSetPrefix("{darkblue}[XenForo]{default}");

	RegConsoleCmd("sm_xfcredits", Command_XFCredits);
}

public void OnClientDisconnect(int client)
{
	ResetSettings(client);
}

public void CVar_OnChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cColumn)
	{
		g_cColumn.GetString(g_sColumn, sizeof(g_sColumn));
	}
}

public void OnMapEnd()
{
	LoopClients(client)
	{
		ResetSettings(client);
	}
}

public Action Command_XFCredits(int client, int args)
{
	if (XenForo_GetClientID(client) > 0)
	{
		CReplyToCommand(client, "You have %d Credits.", g_iCredits[client]);
	}
	else
	{
		CReplyToCommand(client, "You don't have a XenForo ID.");
	}
	return Plugin_Handled;
}

void ResetSettings(int client)
{
	g_iCredits[client] = -1;
}

public Action Timer_GetAllClientCredits(Handle timer)
{
	LoopClients(i)
	{
		if (XenForo_IsProcessed(i))
		{
			if (XenForo_GetClientID(i) > 0)
			{
				GetClientCredits(i);
			}
		}
	}
}

public void OnConfigsExecuted()
{
	if (XenForo_IsConnected())
	{
		XF_OnConnected();
	}
}

#if defined _stamm_included
public int STAMM_OnClientReady(int client)
{
	if (XenForo_IsConnected())
	{
		XF_OnConnected();
	}
}
#endif

public void XF_OnConnected()
{
	g_dDB = XenForo_GetDatabase();

	GetAllClientCredits();
}

void GetAllClientCredits()
{
	LoopClients(i)
	{
		GetClientCredits(i);
	}
}

public void XF_OnProcessed(int client, int xf_userid)
{
	GetClientCredits(client);
}

void GetClientCredits(int client)
{
	int iUserID = XenForo_GetClientID(client);
	
	if (iUserID > 0)
	{
		char sQuery[256];
		Format(sQuery, sizeof(sQuery), "SELECT %s FROM xf_user WHERE user_id = %d;", g_sColumn, iUserID);
		g_dDB.Query(SQL_GetClientCredits, sQuery, GetClientUserId(client));
	}
}

public void SQL_GetClientCredits(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[XenForo-Credits] (SQL_GetClientCredits) Fail at Query: %s", error);
		return;
	}
	else
	{
		int client = GetClientOfUserId(data);
		if (IsClientValid(client))
		{
			if (results.RowCount > 0 && results.FetchRow())
			{
				g_iCredits[client] = results.FetchInt(0);

				Call_StartForward(g_hOnCreditsUpdate);
				Call_PushCell(client);
				Call_PushCell(true);
				Call_PushCell(-1);
				Call_PushCell(g_iCredits[client]);
				Call_Finish();
			}
		}
	}
}

public int Native_GetClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client))
	{
		return -1;
	}

	int iUserID = XenForo_GetClientID(client);

	if (iUserID == -1)
	{
		return -1;
	}

	return g_iCredits[client];
}

public int Native_AddClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client))
	{
		return false;
	}

	int iUserID = XenForo_GetClientID(client);

	if (iUserID == -1)
	{
		return false;
	}

	char sQuery[512];
	g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE xf_user SET %s = %s + '%d' WHERE user_id = '%d';", g_sColumn, g_sColumn, iUserID);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(true);
	pack.WriteCell(GetNativeCell(2));
	g_dDB.Query(SQL_UpdateCredits, sQuery, pack);

	return true;
}

public int Native_RemoveClientCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientValid(client))
	{
		return false;
	}

	int iUserID = XenForo_GetClientID(client);

	if (iUserID == -1)
	{
		return false;
	}

	char sQuery[512];
	g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE xf_user SET %s = %s - '%d' WHERE user_id = '%d';", g_sColumn, g_sColumn, iUserID);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(false);
	pack.WriteCell(GetNativeCell(2));
	g_dDB.Query(SQL_UpdateCredits, sQuery, pack);

	return true;
}

public void SQL_UpdateCredits(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[XenForo-Credits] (SQL_UpdateCredits) Fail at Query: %s", error);
		delete pack;
		return;
	}
	else
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());

		if (!IsClientValid(client))
		{
			delete pack;
			return;
		}

		bool bAdd = view_as<bool>(pack.ReadCell());
		int credits = pack.ReadCell();

		if (bAdd)
		{
			g_iCredits[client] += credits;
		}
		else
		{
			g_iCredits[client] -= credits;
		}

		Call_StartForward(g_hOnCreditsUpdate);
		Call_PushCell(client);
		Call_PushCell(view_as<bool>(bAdd));
		Call_PushCell(credits);
		Call_PushCell(g_iCredits[client]);
		Call_Finish();
	}

	delete pack;
}

stock bool IsClientValid(int client, bool bots = false)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && (bots || !IsFakeClient(client)) && !IsClientSourceTV(client))
		{
			return true;
		}
	}
	
	return false;
}
