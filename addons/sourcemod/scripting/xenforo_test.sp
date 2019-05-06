#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <xenforo_api>
#include <xenforo_credits>

public Plugin myinfo = 
{
    name = "Xenforo - Test",
    author = "Bara", 
    description = "",
    version = "1.0.0", 
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_xftest", Command_XFTest);
}

public void XF_OnProcessed(int client, int xf_userid)
{
    PrintToChat(client, "Your XF UserID: %d", xf_userid);
}

public void XF_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups)
{
    PrintToChat(client, "Your XF UserID: %d", XenForo_GetClientID(client));
    PrintToChat(client, "Your XF Name: %s", name);
    PrintToChat(client, "Your XF Primary Group: %d", primarygroup);

    char sList[64];

    for (int i = 0; i < secondarygroups.Length; i++)
    {
        Format(sList, sizeof(sList), "%d, %s", secondarygroups.Get(i), sList);

        PrintToChat(client, "Secondary Group added: %d", secondarygroups.Get(i));
    }

    PrintToChat(client, "Your XF Secondary Groups: %s", sList);
}

public void XF_OnCreditsUpdate(int client, bool add, int credits, int newCredits)
{
    PrintToChat(client, "Your XF Credits: %d", newCredits);
}

public Action Command_XFTest(int client, int args)
{
    PrintToChat(client, "Your XF UserID: %d", XenForo_GetClientID(client));

    char sName[128];
    XenForo_GetClientName(client, sName);
    PrintToChat(client, "Your XF Name: %s", sName);

    PrintToChat(client, "Your XF Primary Group: %d", XenForo_GetClientPrimaryGroup(client));

    ArrayList aArray = XenForo_GetClientSecondaryGroups(client);

    char sList[64];

    for (int i = 0; i < aArray.Length; i++)
    {
        Format(sList, sizeof(sList), "%d, %s", aArray.Get(i), sList);

        PrintToChat(client, "Secondary Group added: %d", aArray.Get(i));
    }

    delete aArray;

    PrintToChat(client, "Your XF Secondary Groups: %s", sList);
    PrintToChat(client, "Your XF Credits: %d", XenForo_GetClientCredits(client));
}
