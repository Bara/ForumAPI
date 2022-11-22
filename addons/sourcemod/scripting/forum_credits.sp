#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <forum_api>

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))

Database g_dDB = null;

int g_iCredits[MAXPLAYERS + 1] = { -1, ... };

Handle g_hOnCreditsUpdate = null;

ConVar g_cTable = null;
ConVar g_cColumn = null;
ConVar g_cUserColumn = null;

char g_sTable[64];
char g_sColumn[64];
char g_sUserColumn[64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Forum_GetClientCredits", Native_GetClientCredits);
	CreateNative("Forum_AddClientCredits", Native_AddClientCredits);
	CreateNative("Forum_RemoveClientCredits", Native_RemoveClientCredits);

	g_hOnCreditsUpdate = CreateGlobalForward("Forum_OnCreditsUpdate", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	
	RegPluginLibrary("forum_credits");

	return APLRes_Success;
}

public Plugin myinfo = 
{
	name = "Forum - Credits",
	author = "Bara", 
	description = "",
	version = "1.0.0", 
	url = "github.com/Bara"
};

public void OnPluginStart()
{
	CreateTimer(30.0, Timer_GetAllClientCredits, _, TIMER_REPEAT);

	if (Forum_IsConnected())
	{
		g_dDB = Forum_GetDatabase();
	}

	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("forum_credits");
	g_cTable = AutoExecConfig_CreateConVar("forum_credits_table", "xf_user", "Name of the table, where the credits are saved.");
	g_cColumn = AutoExecConfig_CreateConVar("forum_credits_column", "dbtech_credits", "Name of the column for reading and writing the players credits.");
	g_cUserColumn = AutoExecConfig_CreateConVar("forum_credits_user_column", "user_id", "Name of the column to find the correct member/user id.");
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_cTable.AddChangeHook(CVar_OnChange);
	g_cColumn.AddChangeHook(CVar_OnChange);
	g_cUserColumn.AddChangeHook(CVar_OnChange);

	CSetPrefix("{darkblue}[Forum]{default}");

	RegConsoleCmd("sm_forumcredits", Command_ForumCredits);
}

public void OnClientDisconnect(int client)
{
	ResetSettings(client);
}

public void CVar_OnChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cTable)
	{
		g_cTable.GetString(g_sTable, sizeof(g_sTable));
	}
	else if (convar == g_cColumn)
	{
		g_cColumn.GetString(g_sColumn, sizeof(g_sColumn));
	}
	else if (convar == g_cUserColumn)
	{
		g_cUserColumn.GetString(g_sUserColumn, sizeof(g_sUserColumn));
	}
}

public void OnMapEnd()
{
	LoopClients(client)
	{
		ResetSettings(client);
	}
}

public Action Command_ForumCredits(int client, int args)
{
	if (Forum_GetClientID(client) > 0)
	{
		CReplyToCommand(client, "You have %d Credits.", g_iCredits[client]);
	}
	else
	{
		CReplyToCommand(client, "You don't have a Forum ID.");
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
		if (Forum_IsProcessed(i))
		{
			if (Forum_GetClientID(i) > 0)
			{
				GetClientCredits(i);
			}
		}
	}

	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	g_cTable.GetString(g_sTable, sizeof(g_sTable));
	g_cColumn.GetString(g_sColumn, sizeof(g_sColumn));
	g_cUserColumn.GetString(g_sUserColumn, sizeof(g_sUserColumn));
	
	if (Forum_IsConnected())
	{
		Forum_OnConnected();
	}
}

#if defined _stamm_included
public int STAMM_OnClientReady(int client)
{
	if (Forum_IsConnected())
	{
		Forum_OnConnected();
	}
}
#endif

public void Forum_OnConnected()
{
	g_dDB = Forum_GetDatabase();

	GetAllClientCredits();
}

void GetAllClientCredits()
{
	LoopClients(i)
	{
		GetClientCredits(i);
	}
}

public void Forum_OnProcessed(int client, int forum_userid)
{
	GetClientCredits(client);
}

void GetClientCredits(int client)
{
	int iUserID = Forum_GetClientID(client);
	
	if (iUserID > 0)
	{
		char sQuery[256];
		Format(sQuery, sizeof(sQuery), "SELECT \"%s\" FROM \"%s\" WHERE \"%s\" = %d;", g_sColumn, g_sTable, g_sUserColumn, iUserID);
		g_dDB.Query(SQL_GetClientCredits, sQuery, GetClientUserId(client));
	}
}

public void SQL_GetClientCredits(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[Forum-Credits] (SQL_GetClientCredits) Fail at Query: %s", error);
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

	int iUserID = Forum_GetClientID(client);

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

	int iUserID = Forum_GetClientID(client);

	if (iUserID == -1)
	{
		return false;
	}

	char sQuery[512];
	g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE \"%s\" SET \"%s\" = \"%s\" + '%d' WHERE \"%s\" = '%d';", g_sTable, g_sColumn, g_sColumn, g_sUserColumn, iUserID);

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

	int iUserID = Forum_GetClientID(client);

	if (iUserID == -1)
	{
		return false;
	}

	char sQuery[512];
	g_dDB.Format(sQuery, sizeof(sQuery), "UPDATE \"%s\" SET \"%s\" = \"%s\" - '%d' WHERE \"%s\" = '%d';", g_sTable, g_sColumn, g_sColumn, g_sUserColumn, iUserID);

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(false);
	pack.WriteCell(GetNativeCell(2));
	g_dDB.Query(SQL_UpdateCredits, sQuery, pack);

	return true;
}

public void SQL_UpdateCredits(Database db, DBResultSet results, const char[] error, any pack)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[Forum-Credits] (SQL_UpdateCredits) Fail at Query: %s", error);
		delete view_as<DataPack>(pack);
		return;
	}
	else
	{
		view_as<DataPack>(pack).Reset();
		int client = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());

		if (!IsClientValid(client))
		{
			delete view_as<DataPack>(pack);
			return;
		}

		bool bAdd = view_as<bool>(view_as<DataPack>(pack).ReadCell());
		int credits = view_as<DataPack>(pack).ReadCell();

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

	delete view_as<DataPack>(pack);
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
