#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <forum_api>

bool g_bLoaded = false;

StringMap g_smGroupIndex = null;

ConVar g_cDebug = null;

public Plugin myinfo = 
{
	name = "Forum - Admins",
	author = "Bara (Original Author: Drixevel, KyleS)",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("forum_admins");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("forum_admins");
	g_cDebug = AutoExecConfig_CreateConVar("forum_admins_debug", "0", "Enable debug mode?", _, true, 0.0, true, 1.0);
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	CSetPrefix("{darkblue}[Forum]{default}");

	RegAdminCmd("sm_reloadgroupsp", Command_ReloadGroups, ADMFLAG_CONFIG);
}

public void OnMapStart()
{
	g_bLoaded = false;

	SetAllAdmin();
}

public void OnConfigsExecuted()
{
	if (!g_bLoaded)
	{
		g_bLoaded = LoadGroups(true);
	}
}

public void Forum_OnConnected()
{
	if (!g_bLoaded)
	{
		g_bLoaded = LoadGroups(true);
	}
}

public void Forum_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups)
{
	SetAdmin(client, primarygroup, secondarygroups);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if (!Forum_IsLoaded())
	{
		Forum_LogMessage("Admins", "(OnRebuildAdminCache) Forum_IsLoaded is false.");
		return;
	}

	if (part == AdminCache_Groups)
	{
		g_bLoaded = LoadGroups();
	}
	else if (part == AdminCache_Admins)
	{
		SetAllAdmin();
	}
}

void SetAllAdmin()
{
	if (!g_bLoaded)
	{
		return;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && Forum_IsProcessed(i))
		{
			SetAdmin(i);
		}
	}
}

void SetAdmin(int client, int primarygroup = -1, ArrayList secondarygroups = null)
{
	if (!g_bLoaded || (primarygroup == -1 && secondarygroups == null))
	{
		LogError("[Forum-Admins] (SetAdmin) Admin groups not loaded! Loaded: %d, primrary: %d, secondary: %d", g_bLoaded, primarygroup, secondarygroups);
		LateLoadAdminCall(client);
		return;
	}

	AdminId aAdmin = GetUserAdmin(client);

	if (aAdmin == INVALID_ADMIN_ID)
	{
		if (g_cDebug.BoolValue)
		{
			Forum_LogMessage("Admins", "(SetAdmin) Admin ID was invalid, let's create admin...");
		}

		aAdmin = CreateAdmin();
		SetUserAdmin(client, aAdmin);

		if (g_cDebug.BoolValue)
		{
			Forum_LogMessage("Admins", "(SetAdmin) Admin created. (Admin ID: %d)", aAdmin);
		}
	}

	int iForumGroup = primarygroup;

	if (primarygroup == -1)
	{
		iForumGroup = Forum_GetClientPrimaryGroup(client);
	}

	char sForumGroup[12], sGName[32];
	StringMap smGroup = Forum_GetGroupList();
	IntToString(iForumGroup, sForumGroup, sizeof(sForumGroup));

	GroupId gGroup = INVALID_GROUP_ID;

	if (g_smGroupIndex.GetValue(sForumGroup, gGroup))
	{
		AdminInheritGroup(aAdmin, gGroup);
		smGroup.GetString(sForumGroup, sGName, sizeof(sGName));
		if (g_cDebug.BoolValue)
		{
			Forum_LogMessage("Admins", "(SetAdmin) - Primary - Added \"%N\" to group: %s (Group ID: %d)", client, sGName, gGroup);
		}
	}

	ArrayList aSecondary = secondarygroups;

	if (aSecondary == null)
	{
		aSecondary = Forum_GetClientSecondaryGroups(client);
	}

	for (int i = 0; i < aSecondary.Length; i++)
	{
		iForumGroup = aSecondary.Get(i);
		IntToString(iForumGroup, sForumGroup, sizeof(sForumGroup));

		if (g_smGroupIndex.GetValue(sForumGroup, gGroup))
		{
			AdminInheritGroup(aAdmin, gGroup);
			smGroup.GetString(sForumGroup, sGName, sizeof(sGName));
			if (g_cDebug.BoolValue)
			{
				Forum_LogMessage("Admins", "(SetAdmin) - Secondary - Added \"%N\" to group: %s (Group ID: %d)", client, sGName, gGroup);
			}
		}
	}

	LateLoadAdminCall(client);
}

void LateLoadAdminCall(int client)
{
	RunAdminCacheChecks(client);
	NotifyPostAdminCheck(client);
}

public Action Command_ReloadGroups(int client, int args)
{
	LoadGroups(true);

	return Plugin_Continue;
}

bool LoadGroups(bool reloadPlayers = false)
{
	if (!Forum_IsConnected())
	{
		LogError("[Forum-Admins] (LoadGroups) Forum is not connected...");
		return false;
	}

	char sFile[PLATFORM_MAX_PATH + 1];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/forum_admins.cfg");

	if (!FileExists(sFile))
	{
		LogError("[Forum-Admins] (LoadGroups) \"%s\" doesn't exists.", sFile);
		return false;
	}

	KeyValues kvConfig = new KeyValues("forum_admins");

	if (!kvConfig.ImportFromFile(sFile))
	{
		LogError("[Forum-Admins] (LoadGroups) Can't import from file: \"%s\"", sFile);
		delete kvConfig;
		return false;
	}

	if (!kvConfig.GotoFirstSubKey(false))
	{
		LogError("[Forum-Admins] (LoadGroups) GotoFirstSubKey failed!");
		delete kvConfig;
		return false;
	}

	delete g_smGroupIndex;
	g_smGroupIndex = new StringMap();

	StringMap smGroups = Forum_GetGroupList();
	GroupId gGroup = INVALID_GROUP_ID;
	// int gGroup = -1;
	char sGroupID[12], sName[32], sFlags[18];

	do
	{
		kvConfig.GetSectionName(sGroupID, sizeof(sGroupID));

		if (g_cDebug.BoolValue)
		{
			Forum_LogMessage("Admins", "(LoadGroups) SectionName: %s", sGroupID);
		}

		kvConfig.GetString("group", sName, sizeof(sName), "");

		if (strlen(sName) > 1)
		{
			gGroup = FindAdmGroup(sName);

			if (gGroup != INVALID_GROUP_ID)
			{
				g_smGroupIndex.SetValue(sGroupID, gGroup);

				if (g_cDebug.BoolValue)
				{
					Forum_LogMessage("Admins", "(LoadGroups) Admin Group \"%s\" (%d) found.", sName, gGroup);
				}

				continue;
			}

			if (g_cDebug.BoolValue)
			{
				Forum_LogMessage("Admins", "(LoadGroups) Admin Group \"%s\" not found.", sName);
			}
		}

		if(!g_smGroupIndex.GetValue(sGroupID, gGroup))
		{
			if (!smGroups.GetString(sGroupID, sName, sizeof(sName)))
			{
				LogError("[Forum-Admins] (LoadGroups) Can't find the group name of %s...", sGroupID);
				continue;
			}

			if (g_cDebug.BoolValue)
			{
				Forum_LogMessage("Admins", "(LoadGroups) Can't find %s in group index stringmap", sName);
			}

			gGroup = CreateAdmGroup(sName);

			if (gGroup == INVALID_GROUP_ID)
			{
				if (g_cDebug.BoolValue)
				{
					Forum_LogMessage("Admins", "(LoadGroups) Can't create admin group %s", sName);
				}
				gGroup = FindAdmGroup(sName);

				if (gGroup == INVALID_GROUP_ID)
				{
					LogError("[Forum-Admins] (LoadGroups) Can't create or find the admin group: %s", sName);
					continue;
				}
			}
		}

		g_smGroupIndex.SetValue(sGroupID, gGroup);
		if (g_cDebug.BoolValue)
		{
			Forum_LogMessage("Admins", "(LoadGroups) Saved group %s to group index (%d)", sName, gGroup);
		}

		if (kvConfig.GetString("flags", sFlags, sizeof(sFlags)))
		{
			AdminFlag iFlag;

			for (int i = 0; i < strlen(sFlags); i++)
			{
				if (FindFlagByChar(sFlags[i], iFlag))
				{
					if (g_cDebug.BoolValue)
					{
						Forum_LogMessage("Admins", "(LoadGroups) Add flag %c (%d) to %s", sFlags[i], iFlag, sName);
					}
					SetAdmGroupAddFlag(gGroup, iFlag, true);
				}
			}
		}

		int iImmunity = kvConfig.GetNum("immunity", 0);
		if (g_cDebug.BoolValue)
		{
			Forum_LogMessage("Admins", "(LoadGroups) Set immunity level for %s to %d", sName, iImmunity);
		}
		SetAdmGroupImmunityLevel(gGroup, iImmunity);

		gGroup = INVALID_GROUP_ID;

	} while (kvConfig.GotoNextKey(false));

	if (reloadPlayers)
	{
		SetAllAdmin();
	}

	return true;
}
