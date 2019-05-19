#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <xenforo_api>

ConVar g_cInterval = null;
ConVar g_cHomepage = null;
ConVar g_cAlerts = null;
ConVar g_cConversations = null;

int g_iAlerts[MAXPLAYERS + 1] = { -1, ... };
int g_iConversations[MAXPLAYERS + 1] = { -1, ... };

Database g_dDB = null;

public Plugin myinfo = 
{
	name = "XenForo - Post unread alerts and conversations",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("xenforo_admins");
	g_cInterval = AutoExecConfig_CreateConVar("xenforo_post_interval", "1", "Check in minutes that post an update of unread stuff.", _, true, 1.0);
	g_cHomepage = AutoExecConfig_CreateConVar("xenforo_post_unread_url", "example.com", "Homepage url to your forum.");
	g_cAlerts = AutoExecConfig_CreateConVar("xenforo_post_unread_alerts", "1", "Print every X minutes a message with the amount of unread alerts", _, true, 0.0, true, 1.0);
	g_cConversations = AutoExecConfig_CreateConVar("xenforo_post_unread_conversations", "1", "Print every X minutes a message with the amount of unread conversations", _, true, 0.0, true, 1.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	CSetPrefix("{darkblue}[XenForo]{default}");
}

public void XF_OnConnected()
{
	g_dDB = XenForo_GetDatabase();
}

public void OnClientPutInServer(int client)
{
	g_iAlerts[client] = -1;
	g_iConversations[client] = -1;
}

public void XF_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups)
{
	CreateTimer(g_cInterval.FloatValue * 60.0, Timer_UpdateUnreadCount, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_UpdateUnreadCount(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (IsClientInGame(client))
	{
		UpdateUnreadCount(client);
	}
}

void UpdateUnreadCount(int client)
{
	int iUserID = XenForo_GetClientID(client);

	char sQuery[512];
	Format(sQuery, sizeof(sQuery), "SELECT conversations_unread, alerts_unread FROM xf_user WHERE user_id = '%d'", iUserID);
	g_dDB.Query(SQL_GetUnreadStuff, sQuery, GetClientUserId(client));
}

public void SQL_GetUnreadStuff(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[XenForo-Unread] (SQL_GetUnreadStuff) Fail at Query: %s", error);
		return;
	}
	else
	{
		int client = GetClientOfUserId(data);
		if (IsClientInGame(client))
		{
			if (results.RowCount > 0 && results.FetchRow())
			{
				g_iAlerts[client] = results.FetchInt(0);
				g_iConversations[client] = results.FetchInt(1);

				PostUnreadStuff(client);
			}
		}
	}
}

void PostUnreadStuff(int client)
{
	if (!IsClientInGame(client))
	{
		return;
	}

	char sURL[64];
	g_cHomepage.GetString(sURL, sizeof(sURL));

	if (g_cAlerts.BoolValue)
	{
		CPrintToChat(client, "You've %d unread alerts on %s", g_iAlerts[client], sURL);
	}

	if (g_cConversations.BoolValue)
	{
		CPrintToChat(client, "You've %d unread conversations on %s", g_iConversations[client], sURL);
	}
}
