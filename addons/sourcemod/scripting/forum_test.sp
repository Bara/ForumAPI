#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <forum_api>

#undef REQUIRE_PLUGIN
#include <forum_credits>

bool g_bCredits = false;

public Plugin myinfo = 
{
    name = "Forum - Test",
    author = "Bara", 
    description = "",
    version = "1.0.0", 
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_forumtest", Command_ForumTest);

    g_bCredits = LibraryExists("forum_credits");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "forum_credits"))
    {
        g_bCredits = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "forum_credits"))
    {
        g_bCredits = false;
    }
}

public void Forum_OnConnected()
{
    PrintToChatAll("Forum_OnConnected executed");
}

public void Forum_OnProcessed(int client, int forum_userid)
{
    PrintToChat(client, "Your Forum UserID: %d", forum_userid);
}

public void Forum_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups)
{
    PrintToChat(client, "Your Forum UserID: %d", Forum_GetClientID(client));
    PrintToChat(client, "Your Forum Name: %s", name);
    PrintToChat(client, "Your Forum Primary Group: %d", primarygroup);

    char sList[64];

    for (int i = 0; i < secondarygroups.Length; i++)
    {
        Format(sList, sizeof(sList), "%d, %s", secondarygroups.Get(i), sList);

        PrintToChat(client, "Secondary Group added: %d", secondarygroups.Get(i));
    }

    PrintToChat(client, "Your Forum Secondary Groups: %s", sList);
}

public void Forum_OnUserFieldsProcessed(int client, StringMap userfields)
{
    StringMapSnapshot smSnapshot = userfields.Snapshot();
    StringMap smFields = Forum_GetUserFields();
    char sKey[32], sValue[128], sPhrase[64];

    for (int i = 0; i < smSnapshot.Length; i++)
    {
        smSnapshot.GetKey(i, sKey, sizeof(sKey));
        userfields.GetString(sKey, sValue, sizeof(sValue));
        smFields.GetString(sKey, sPhrase, sizeof(sPhrase));

        PrintToChat(client, "Key: %s (id: %s), Value: %s", sPhrase, sKey, sValue);
    }

    delete smSnapshot;
}

public void Forum_OnCreditsUpdate(int client, bool add, int credits, int newCredits)
{
    PrintToChat(client, "Your Forum Credits: %d", newCredits);
}

public Action Command_ForumTest(int client, int args)
{
    PrintToChat(client, "Your Forum UserID: %d", Forum_GetClientID(client));

    char sName[128];
    Forum_GetClientName(client, sName);
    PrintToChat(client, "Your Forum Name: %s", sName);

    ArrayList aArray = Forum_GetClientSecondaryGroups(client);

    char sList[64];

    StringMap smGroups = Forum_GetGroupList();
    StringMap smGroupbanner = Forum_GetGroupBannerText();

    char sGroup[64], sBanner[32], sKey[12];
    IntToString(Forum_GetClientPrimaryGroup(client), sKey, sizeof(sKey));
    smGroups.GetString(sKey, sGroup, sizeof(sGroup));
    smGroupbanner.GetString(sKey, sBanner, sizeof(sBanner));

    PrintToChat(client, "Your Forum Primary Group: %d (Name: %s, Banner: %s)", Forum_GetClientPrimaryGroup(client), sGroup, sBanner);

    for (int i = 0; i < aArray.Length; i++)
    {
        Format(sList, sizeof(sList), "%d, %s", aArray.Get(i), sList);

        IntToString(aArray.Get(i), sKey, sizeof(sKey));
        smGroups.GetString(sKey, sGroup, sizeof(sGroup));
        smGroupbanner.GetString(sKey, sBanner, sizeof(sBanner));

        PrintToChat(client, "Secondary Group added: %d (Name: %s, Banner: %s)", aArray.Get(i), sGroup, sBanner);
    }

    PrintToChat(client, "Your Forum Secondary Groups: %s", sList);
    
    if (g_bCredits)
    {
        PrintToChat(client, "Your Forum Credits: %d", Forum_GetClientCredits(client));
    }

    StringMap smFields = Forum_GetUserFields();
    StringMap smUserFields = Forum_GetClientUserFields(client);
    StringMapSnapshot smSnapshot = smUserFields.Snapshot();
    
    char sFieldKey[32], sFieldValue[128], sFieldPhrase[64];

    for (int i = 0; i < smSnapshot.Length; i++)
    {
        smSnapshot.GetKey(i, sFieldKey, sizeof(sFieldKey));
        smUserFields.GetString(sFieldKey, sFieldValue, sizeof(sFieldValue));
        smFields.GetString(sFieldKey, sFieldPhrase, sizeof(sFieldPhrase));

        PrintToChat(client, "Key: %s (id: %s), Value: %s", sFieldPhrase, sFieldKey, sFieldValue);
    }

    delete smSnapshot;
}
