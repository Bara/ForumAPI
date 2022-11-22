#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <forum_api>

ConVar g_cInterval = null;
ConVar g_cHomepage = null;
ConVar g_cAlerts = null;
ConVar g_cConversations = null;

int g_iAlerts[MAXPLAYERS + 1] = { -1, ... };
int g_iConversations[MAXPLAYERS + 1] = { -1, ... };

Database g_dDB = null;

ConVar g_cDebug = null;
ConVar g_cForum = null;

public Plugin myinfo = 
{
	name = "Forum - Post unread alerts and conversations",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara"
};

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	if (Forum_IsConnected())
	{
		g_dDB = Forum_GetDatabase();
	}
	
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("forum_unread");
	g_cInterval = AutoExecConfig_CreateConVar("forum_post_interval", "1", "Check in minutes that post an update of unread stuff.", _, true, 1.0);
	g_cHomepage = AutoExecConfig_CreateConVar("forum_post_unread_url", "example.com", "Homepage url to your forum.");
	g_cAlerts = AutoExecConfig_CreateConVar("forum_post_unread_alerts", "1", "Print every X minutes a message with the amount of unread alerts", _, true, 0.0, true, 1.0);
	g_cConversations = AutoExecConfig_CreateConVar("forum_post_unread_conversations", "1", "Print every X minutes a message with the amount of unread conversations", _, true, 0.0, true, 1.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	CSetPrefix("{darkblue}[Forum]{default}");
}

public void Forum_OnConnected()
{
	g_dDB = Forum_GetDatabase();

	g_cDebug = FindConVar("forum_api_debug");
	g_cForum = FindConVar("forum_api_software");

	if (g_cForum != null && g_cForum.IntValue == 4)
	{
		SetFailState("Flarum doesn't contains the function of private messages. Please remove/disable \"forum_unread.sm\"");
		return;
	}
}

public void OnClientPutInServer(int client)
{
	g_iAlerts[client] = -1;
	g_iConversations[client] = -1;
}

public void Forum_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups)
{
	if (g_cDebug.BoolValue)
	{
		Forum_LogMessage("Unread", "(Forum_OnInfoProcessed) Executed");
	}

	CreateTimer(g_cInterval.FloatValue * 60.0, Timer_UpdateUnreadCount, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_UpdateUnreadCount(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (client > 0 && !IsFakeClient(client) && IsClientInGame(client))
	{
		if (g_cDebug.BoolValue)
		{
			Forum_LogMessage("Unread", "(Forum_OnInfoProcessed) Timer_UpdateUnreadCount and valid Client");
		}
	
		UpdateUnreadCount(client);
	}

	return Plugin_Continue;
}

void UpdateUnreadCount(int client)
{
	int iUserID = Forum_GetClientID(client);

	char sQuery[512];

	if (g_cDebug.BoolValue)
	{
		Forum_LogMessage("Unread", "(UpdateUnreadCount) g_cForum: %d", g_cForum.IntValue);
	}

	if (g_cForum != null && g_cForum.IntValue > 0)
	{
		if (g_cForum.IntValue == 1)
		{
			Format(sQuery, sizeof(sQuery), "SELECT conversations_unread, alerts_unread FROM xf_user WHERE user_id = '%d'", iUserID);
		}
		else if (g_cForum.IntValue == 2)
		{
			Format(sQuery, sizeof(sQuery), "SELECT msg_count_new, notification_cnt FROM core_members WHERE member_id = '%d'", iUserID);
		}
		else if (g_cForum.IntValue == 3)
		{
			Format(sQuery, sizeof(sQuery), "SELECT unreadpms FROM mybb_users WHERE uid = '%d'", iUserID);
		}
		else
		{
			SetFailState("[Forum-Unread] forum_api_software has an invalid value or unsupported forum software");
			return;
		}

		g_dDB.Query(SQL_GetUnreadStuff, sQuery, GetClientUserId(client));
	}
}

public void SQL_GetUnreadStuff(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == null || strlen(error) > 0)
	{
		SetFailState("[Forum-Unread] (SQL_GetUnreadStuff) Fail at Query: %s", error);
		return;
	}
	else
	{
		int client = GetClientOfUserId(data);
		if (client > 0 && !IsFakeClient(client) && IsClientInGame(client))
		{
			if (results.RowCount > 0 && results.FetchRow())
			{
				g_iConversations[client] = results.FetchInt(0);
				
				if (g_cForum.IntValue != 3)
				{
					g_iAlerts[client] = results.FetchInt(1);
				}

				PostUnreadStuff(client);
			}
		}
	}
}

void PostUnreadStuff(int client)
{
	if (client > 0 && !IsFakeClient(client) && !IsClientInGame(client))
	{
		return;
	}

	char sURL[64];
	g_cHomepage.GetString(sURL, sizeof(sURL));

	if (g_cAlerts.BoolValue && g_iAlerts[client] > 0)
	{
		CPrintToChat(client, "You've %d unread alerts on %s", g_iAlerts[client], sURL);
	}

	if (g_cConversations.BoolValue && g_iConversations[client] > 0)
	{
		CPrintToChat(client, "You've %d unread conversations on %s", g_iConversations[client], sURL);
	}
}
