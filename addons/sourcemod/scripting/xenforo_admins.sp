#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#include <autoexecconfig>
#include <xenforo_api>

bool g_bLoaded = false;

StringMap g_smGroupIndex = null;

ConVar g_cDebug = null;

public Plugin myinfo = 
{
	name = "XenForo - Admins",
	author = "Bara (Original Author: Drixevel, KyleS)",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("xenforo_admins");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	AutoExecConfig_SetCreateDirectory(true);
	AutoExecConfig_SetCreateFile(true);
	AutoExecConfig_SetFile("xenforo_admins");
	// Configs...
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	CSetPrefix("{darkblue}[XenForo]{default}");

	RegAdminCmd("sm_reloadgroups", Command_ReloadGroups, ADMFLAG_CONFIG);
}

public void OnConfigsExecuted()
{
	g_bLoaded = LoadGroups();

	g_cDebug = FindConVar("xenforo_api_debug");
}

public void XF_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups)
{
	SetAdmin(client);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if (part == AdminCache_Groups)
	{
		g_bLoaded = LoadGroups();
	}
	else if (part == AdminCache_Admins)
	{
		SetAllAdmin();
	}

	if (g_bLoaded) {}
}

void SetAllAdmin()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && XenForo_IsProcessed(i))
		{
			SetAdmin(i);
		}
	}
}

void SetAdmin(int client)
{
	if (!g_bLoaded)
	{
		LogError("[Xenforo-Admins] (SetAdmin) Admin groups not loaded!");
		LateLoadAdminCall(client);
		return;
	}

	char sAuth[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sAuth, sizeof(sAuth)))
	{
		LogError("[XenForo-Admins] (SetAdmin) Can't get auth id for client: %d", client);
		LateLoadAdminCall(client);
		return;
	}

	AdminId aAdmin = FindAdminByIdentity(sAuth, AUTHMETHOD_STEAM);

	if (aAdmin == INVALID_ADMIN_ID)
	{
		if (g_cDebug.BoolValue)
		{
			LogMessage("[Xenforo-Admins] (SetAdmin) Admin ID was invalid, let's create admin...");
		}

		char sName[MAX_NAME_LENGTH];

		if (!GetClientName(client, sName, sizeof(sName)))
		{
			LogError("[XenForo-Admins] (SetAdmin) Can't get name for client: %d", client);
			LateLoadAdminCall(client);
			return;
		}

		TrimString(sName);
		StripQuotes(sName);

		aAdmin = CreateAdmin(sName);
		BindAdminIdentity(aAdmin, AUTHMETHOD_STEAM, sAuth);
		if (g_cDebug.BoolValue)
		{
			LogMessage("[Xenforo-Admins] (SetAdmin) Admin created. (Admin ID: %d, Auth: %s)", aAdmin, sAuth);
		}
	}

	int iXFGroup = XenForo_GetClientPrimaryGroup(client);

	char sXFGroup[12], sGName[32];
	StringMap smGroup = XenForo_GetGroupList();
	IntToString(iXFGroup, sXFGroup, sizeof(sXFGroup));

	GroupId gGroup = INVALID_GROUP_ID;

	if (g_smGroupIndex.GetValue(sXFGroup, gGroup))
	{
		AdminInheritGroup(aAdmin, gGroup);
		smGroup.GetString(sXFGroup, sGName, sizeof(sGName));
		if (g_cDebug.BoolValue)
		{
			LogMessage("[Xenforo-Admins] (SetAdmin) - Primary- Added \"%N\" to group: %s (Group ID: %d)", client, sGName, gGroup);
		}
	}

	ArrayList aSecondary = XenForo_GetClientSecondaryGroups(client);

	for (int i = 0; i < aSecondary.Length; i++)
	{
		iXFGroup = aSecondary.Get(i);
		IntToString(iXFGroup, sXFGroup, sizeof(sXFGroup));

		if (g_smGroupIndex.GetValue(sXFGroup, gGroup))
		{
			AdminInheritGroup(aAdmin, gGroup);
			smGroup.GetString(sXFGroup, sGName, sizeof(sGName));
			if (g_cDebug.BoolValue)
			{
				LogMessage("[Xenforo-Admins] (SetAdmin) - Secondary - Added \"%N\" to group: %s (Group ID: %d)", client, sGName, gGroup);
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
	LoadGroups();
}

bool LoadGroups()
{
	if (!XenForo_IsConnected())
	{
		return false;
	}

	char sFile[PLATFORM_MAX_PATH + 1];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/xenforo_admins.cfg");

	if (!FileExists(sFile))
	{
		LogError("[Xenforo-Admins] (LoadGroups) \"%s\" doesn't exists.", sFile);
		return false;
	}

	KeyValues kvConfig = new KeyValues("xenforo_admins");

	if (!kvConfig.ImportFromFile(sFile))
	{
		LogError("[Xenforo-Admins] (LoadGroups) Can't import from file: \"%s\"", sFile);
		delete kvConfig;
		return false;
	}

	if (!kvConfig.GotoFirstSubKey(false))
	{
		LogError("[Xenforo-Admins] (LoadGroups) GotoFirstSubKey failed!");
		delete kvConfig;
		return false;
	}

	delete g_smGroupIndex;
	g_smGroupIndex = new StringMap();

	StringMap smGroups = XenForo_GetGroupList();
	GroupId gGroup = INVALID_GROUP_ID;
	// int gGroup = -1;
	char sGroupID[12], sName[32], sFlags[18];

	do
	{
		kvConfig.GetSectionName(sGroupID, sizeof(sGroupID));

		if (g_cDebug.BoolValue)
		{
			LogMessage("[Xenforo-Admin] (LoadGroups) SectionName: %s", sGroupID);
		}

		if(!g_smGroupIndex.GetValue(sGroupID, gGroup))
		{
			if (!smGroups.GetString(sGroupID, sName, sizeof(sName)))
			{
				LogError("[Xenforo-Admin] (LoadGroups) Can't find the group name of %s...", sGroupID);
				continue;
			}

			if (g_cDebug.BoolValue)
			{
				LogMessage("[Xenforo-Admin] (LoadGroups) Can't find %s in group index stringmap", sName);
			}

			gGroup = CreateAdmGroup(sName);

			if (gGroup == INVALID_GROUP_ID)
			{
				if (g_cDebug.BoolValue)
				{
					LogMessage("[Xenforo-Admin] (LoadGroups) Can't create admin group %s", sName);
				}
				gGroup = FindAdmGroup(sName);

				if (gGroup == INVALID_GROUP_ID)
				{
					LogError("[Xenforo-Admin] (LoadGroups) Can't create or find the admin group: %s", sName);
					continue;
				}
			}
		}

		g_smGroupIndex.SetValue(sGroupID, gGroup);
		if (g_cDebug.BoolValue)
		{
			LogMessage("[Xenforo-Admin] (LoadGroups) Saved group %s to group index (%d)", sName, gGroup);
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
						LogMessage("[Xenforo-Admin] (LoadGroups) Add flag %c (%d) to %s", sFlags[i], iFlag, sName);
					}
					SetAdmGroupAddFlag(gGroup, iFlag, true);
				}
			}
		}

		int iImmunity = kvConfig.GetNum("immunity", 0);
		if (g_cDebug.BoolValue)
		{
			LogMessage("[Xenforo-Admin] (LoadGroups) Set immunity level for %s to %d", sName, iImmunity);
		}
		SetAdmGroupImmunityLevel(gGroup, iImmunity);

		gGroup = INVALID_GROUP_ID;

	} while (kvConfig.GotoNextKey(false));

	return true;
}
