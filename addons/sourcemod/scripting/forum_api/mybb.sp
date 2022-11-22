void MyBB_LoadGroups()
{
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT gid, title, usertitle FROM mybb_usergroups");
    g_dDatabase.Query(MyBB_GetForumGroups, sQuery);

    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(MyBB_LoadGroups) Query: %s", sQuery);
    }
}

public void MyBB_GetForumGroups(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[Forum-API] (MyBB_GetForumGroups) Query error by void: '%s'", error);
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
                    Forum_LogMessage("API", "(MyBB_GetForumGroups) GroupID: %d, Name: %s, Banner: %s", groupid, sName, sBanner);
                }

                g_smGroups.SetString(sKey, sName);

                if (strlen(sBanner) > 1)
                {
                    g_smGroupBanner.SetString(sKey, sBanner);
                }
            }
        }

        g_bGroups = true;
        // LoadClients();
        MyBB_LoadUserFields();
    }
}

void MyBB_LoadUserFields()
{
    delete g_smFields;
    g_smFields = new StringMap();

    char sQuery[128];
    Format(sQuery, sizeof(sQuery), "SELECT fid, name FROM mybb_profilefields");
    g_dDatabase.Query(MyBB_Fields, sQuery);

    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(MyBB_LoadUserFields) Query: %s", sQuery);
    }
}

public void MyBB_Fields(Database db, DBResultSet results, const char[] error, any data)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (MyBB_Fields) Fail at Query: %s", error);
        delete g_smFields;
        return;
    }
    else
    {
        if (results.HasResults)
        {
            while (results.FetchRow())
            {
                char sFieldID[32];
                results.FetchString(0, sFieldID, sizeof(sFieldID));

                char sName[64];
                results.FetchString(1, sName, sizeof(sName));
                g_smFields.SetString(sFieldID, sName);

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(MyBB_Fields) Added user_field %s (Name: %s)", sFieldID, sName);
                }
            }

            g_bFields = true;
            LoadClients();
        }
    }
}

void MyBB_LoadClient(int client, const char[] sCommunityID)
{
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT uid FROM mybb_users WHERE loginname = '%s'", sCommunityID);
    g_dDatabase.Query(MyBB_GetUserId, sQuery, GetClientUserId(client));
    
    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(MyBB_LoadClient) Query: %s", sQuery);
    }
}

public void MyBB_GetUserId(Database db, DBResultSet results, const char[] error, any userid)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (MyBB_GetUserId) Fail at Query: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);
        
        if (!IsClientValid(client))
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(MyBB_GetUserId) Error grabbing User Data: Client invalid");
            }
            
            return;
        }
        
        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(MyBB_GetUserId) Retrieving data for %N...", client);
        }
        
        if (results.FetchRow())
        {
            if (results.IsFieldNull(0))
            {
                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(MyBB_GetUserId) Error retrieving User ID. Error: Field is null");
                }

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
                Forum_LogMessage("API", "(MyBB_GetUserId) User '%N' has been processed successfully!", client);
            }

            char sQuery[256];
            Format(sQuery, sizeof(sQuery), "SELECT username, usergroup, additionalgroups, usertitle FROM mybb_users WHERE uid = '%d'", g_iUserID[client]);
            g_dDatabase.Query(MyBB_UserInformations, sQuery, userid);

            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(MyBB_GetUserId) User Informations - Query: %s", sQuery);
            }

            StringMapSnapshot smFields = g_smFields.Snapshot();
            char sKey[32];

            g_iFieldCount[client] = 0;

            delete g_smUserFields[client];
            g_smUserFields[client] = new StringMap();

            for (int i = 0; i < smFields.Length; i++)
            {
                smFields.GetKey(i, sKey, sizeof(sKey));

                char sColumn[32];
                Format(sColumn, sizeof(sColumn), "fid%s", sKey);

                Forum_LogMessage("API", "(MyBB_GetUserId) smFields.Length: %d, g_smFields.Size: %d", smFields.Length, g_smFields.Size);

                Format(sQuery, sizeof(sQuery), "SELECT %s FROM mybb_userfields WHERE ufid = '%d'", sColumn, g_iUserID[client]);
                DataPack pack = new DataPack();
                pack.WriteCell(userid);
                pack.WriteString(sKey);
                g_dDatabase.Query(MyBB_UserFields, sQuery, pack);

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(MyBB_GetUserId) User Fields - Query: %s", sQuery);
                }
            }

            delete smFields;
        }
        else
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(MyBB_GetUserId) Error retrieving User (\"%L\") Data: (Row not fetched)", client);
            }
        }
    }
}

public void MyBB_UserInformations(Database db, DBResultSet results, const char[] error, any userid)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (MyBB_UserInformations) Fail at Query: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);
        
        if (!IsClientValid(client))
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(MyBB_UserInformations) Error grabbing User informations: Client invalid");
            }

            return;
        }
        
        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(MyBB_UserInformations) Retrieving informations for %N...", client);
        }
        
        if (results.FetchRow())
        {
            if (results.IsFieldNull(0))
            {
                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(MyBB_UserInformations) Error retrieving User informations: (Field is null)");
                }

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
                Forum_LogMessage("API", "(MyBB_UserInformations) User informations for'%N' has been processed successfully!", client);
            }
        }
        else
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(MyBB_UserInformations) Error retrieving User (\"%L\") informations: (Row not fetched)", client);
            }
        }
    }
}

public void MyBB_UserFields(Database db, DBResultSet results, const char[] error, any pack)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (MyBB_UserFields) Fail at Query: %s", error);
        delete view_as<DataPack>(pack);
        return;
    }
    else
    {
        view_as<DataPack>(pack).Reset();

        int client = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());

        char sColumn[32];
        view_as<DataPack>(pack).ReadString(sColumn, sizeof(sColumn));

        delete view_as<DataPack>(pack);
        
        if (!IsClientValid(client))
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(MyBB_UserFields) Error grabbing user fields: Client invalid");
            }

            return;
        }

        g_iFieldCount[client]++;
        Forum_LogMessage("API", "(MyBB_UserFields) Field Count: %d", g_iFieldCount[client]);

        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(MyBB_UserFields) Retrieving user field %s for %N...", sColumn, client);
        }
        
        if (results.FetchRow())
        {
            char sValue[128];

            if (results.IsFieldNull(0))
            {
                LogMessage("[Forum-API] (MyBB_UserFields) Can't retrieve user field %s. Error: Field is null", sColumn);
            }
            else
            {
                results.FetchString(0, sValue, sizeof(sValue));
            }

            if (strlen(sValue) > 1)
            {
                g_smUserFields[client].SetString(sColumn, sValue);
            }

            if (g_iFieldCount[client] == g_smFields.Size)
            {
                Call_StartForward(g_hOnUserFieldsProcessed);
                Call_PushCell(client);
                Call_PushCell(g_smUserFields[client]);
                Call_Finish();

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(MyBB_UserFields) user fields for'%N' has been processed successfully!", client);
                }
            }
        }
        else
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(MyBB_UserFields) Error retrieving User (\"%L\") fields: (Row not fetched)", client);
            }
        }
    }
}
