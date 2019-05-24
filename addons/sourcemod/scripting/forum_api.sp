#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <forum_api>

ConVar g_cForum = null;
ConVar g_cDebug = null;

Database g_dDatabase = null;

Handle g_hOnGrabProcessed = null;
Handle g_hOnInfoProcessed = null;
Handle g_hOnUserFieldsProcessed = null;
Handle g_hOnConnected = null;

char g_sName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
int g_iPrimaryGroup[MAXPLAYERS + 1] = { -1, ... };
ArrayList g_aSecondaryGroups[MAXPLAYERS + 1] = { null, ... };
char g_sCustomTitle[MAXPLAYERS + 1];
StringMap g_smUserFields[MAXPLAYERS + 1] = { null, ... };
int g_iFieldCount[MAXPLAYERS + 1] = { -1, ... };

StringMap g_smGroups = null;
StringMap g_smGroupBanner = null;
StringMap g_smFields = null;

bool g_bGroups = false;
bool g_bFields = false;

bool g_bIsProcessed[MAXPLAYERS + 1] = { false, ... };
int g_iUserID[MAXPLAYERS + 1] = { -1, ... };

#include "forum_api/xenforo.sp"

public Plugin myinfo = 
{
    name = "Forum - API",
    author = "Bara (Original Author: Drixevel)",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Forum_GetClientID", Native_GetClientID);
    CreateNative("Forum_GetClientName", Native_GetClientName);
    CreateNative("Forum_GetClientCustomTitle", Native_GetClientCustomTitle);
    CreateNative("Forum_GetClientPrimaryGroup", Native_GetClientPrimaryGroup);
    CreateNative("Forum_GetClientSecondaryGroups", Native_GetClientSecondaryGroups);
    CreateNative("Forum_IsProcessed", Native_IsProcessed);
    CreateNative("Forum_TExecute", Native_TExecute);
    CreateNative("Forum_IsConnected", Native_IsConnected);
    CreateNative("Forum_GetDatabase", Native_GetDatabase);
    CreateNative("Forum_GetGroupList", Native_GetGroupList);
    CreateNative("Forum_GetGroupBannerText", Native_GetGroupBannerText);
    CreateNative("Forum_GetUserFields", Native_GetUserFields);
    CreateNative("Forum_GetClientUserFields", Native_GetClientUserFields);

    g_hOnGrabProcessed = CreateGlobalForward("Forum_OnProcessed", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnInfoProcessed = CreateGlobalForward("Forum_OnInfoProcessed", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
    g_hOnUserFieldsProcessed = CreateGlobalForward("Forum_OnUserFieldsProcessed", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnConnected = CreateGlobalForward("Forum_OnConnected", ET_Ignore);
    
    RegPluginLibrary("forum_api");
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("forum_api");
    g_cForum = AutoExecConfig_CreateConVar("forum_api_software", "0", "Which forum software do you run? (0 - Disabled, 1 - XenForo, 2 - Invision)", _, true, 0.0, true, 2.0);
    g_cDebug = AutoExecConfig_CreateConVar("forum_api_debug", "1", "Enable the debug mode? This will print every sql querie into the log file.", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    RegConsoleCmd("sm_forumid", Command_ForumID);

    CSetPrefix("{darkblue}[Forum]{default}");
}

public Action Command_ForumID(int client, int args)
{
    if (g_iUserID[client] > 0)
    {
        CReplyToCommand(client, "Your Forum ID is %d.", g_iUserID[client]);
    }
    else
    {
        CReplyToCommand(client, "You don't have a Forum ID.");
    }
    return Plugin_Handled;
}

public void OnConfigsExecuted()
{
    if (SQL_CheckConfig("forum") && g_cForum.IntValue > 1)
    {
        Database.Connect(OnSQLConnect, "forum");
    }
    else if (g_cForum.IntValue == 0)
    {
        SetFailState("forum_api_software is 0. Please choose your forum software and update forum_api_software.");
        return;
    }
    else
    {
        SetFailState("Can't found the entry \"forum\" in your databases.cfg!");
        return;
    }
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
    if (db == null)
    {
        LogError("[Forum-API] (OnSQLConnect) SQL ERROR: Error connecting to database - '%s'", error);
        SetFailState("[Forum-API] (OnSQLConnect) Error connecting to \"forum\" database, please verify configurations & connections. (Check Error Logs)");
        return;
    }
    
    g_dDatabase = db;

    g_bGroups = false;
    g_bFields = false;

    if (g_cForum.IntValue == 1)
    {
        XenForo_LoadForumGroups();
        XenForo_LoadForumUserFields();
    }
    else
    {
        SetFailState("forum_api_software has an unknown value (%d). Please choose your forum software and update forum_api_software.", g_cForum.IntValue);
        return;
    }
    
    if (g_cDebug.BoolValue)
    {
        LogMessage("Forum API has connected to SQL successfully.");
    }
}

void LoadClients()
{
    if (!g_bGroups || !g_bFields)
    {
        return;
    }

    Call_StartForward(g_hOnConnected);
    Call_Finish();

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
    g_iFieldCount[client] = -1;
    delete g_aSecondaryGroups[client];
    delete g_smUserFields[client];
}

public void OnClientPostAdminCheck(int client)
{
    if (!IsClientValid(client))
    {
        return;
    }
    
    if (g_cDebug.BoolValue)
    {
        LogMessage("Starting process for user %N...", client);
    }
    
    char sCommunityID[32];
    GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID));
    
    if(g_cForum.IntValue == 1)
    {
        XenForo_LoadClient(client, sCommunityID);
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
    LogError("[Forum-API] (Native_TExecute) SQL QUERY: Forum_TExecute - Query: '%s'", sQuery);
}

public int SQL_EmptyCallback(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        LogError("[Forum-API] (SQL_EmptyCallback) Query error by void: '%s'", error);
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

public int Native_GetUserFields(Handle plugin, int numParams)
{
    if (g_smFields != null)
    {
        return view_as<int>(g_smFields);
    }

    return -1;
}


public int Native_GetClientUserFields(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (g_smUserFields[client] != null)
    {
        return view_as<int>(g_smUserFields[client]);
    }

    return -1;
}
