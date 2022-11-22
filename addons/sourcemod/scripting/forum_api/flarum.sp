void Flarum_LoadGroups()
{
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT id, name_singular FROM %sgroups", g_sPrefix);
    g_dDatabase.Query(Flarum_GetForumGroups, sQuery);

    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(Flarum_LoadGroups) Query: %s", sQuery);
    }
}

public void Flarum_GetForumGroups(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        Forum_LogMessage("API", "(Flarum_GetForumGroups) Query error by void: '%s'", error);
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

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(Flarum_GetForumGroups) GroupID: %d, Name: %s", groupid, sName);
                }

                g_smGroups.SetString(sKey, sName);

                if (strlen(sName) > 1)
                {
                    g_smGroupBanner.SetString(sKey, sName);
                }
            }
        }

        g_bGroups = true;
        // LoadClients();
        Flarum_LoadUserFields();
    }
}

void Flarum_LoadUserFields()
{
    delete g_smFields;
    g_smFields = new StringMap();

    char sQuery[128];
    Format(sQuery, sizeof(sQuery), "SELECT id, name FROM %sfof_masquerade_fields", g_sPrefix);
    g_dDatabase.Query(Flarum_Fields, sQuery);

    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(Flarum_LoadUserFields) Query: %s", sQuery);
    }
}

public void Flarum_Fields(Database db, DBResultSet results, const char[] error, any data)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (Flarum_Fields) Fail at Query: %s", error);
        delete g_smFields;
        return;
    }
    else
    {
        if (results.HasResults)
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(Flarum_Fields) Row Count: %d", results.RowCount);
            }

            g_iFieldsRowCount = results.RowCount;

            while (results.FetchRow())
            {
                g_iFieldsRowCount--;

                char sField[64];
                results.FetchString(0, sField, sizeof(sField));

                char sPhrase[64];
                results.FetchString(1, sPhrase, sizeof(sPhrase));

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(Flarum_Fields) Field ID: %s, Name: %s", sField, sPhrase);
                }

                g_smFields.SetString(sField, sPhrase);

                if (g_iFieldsRowCount == 0)
                {
                    g_bFields = true;
                    LoadClients();

                    return;
                }
            }

            g_bFields = true;
            LoadClients();
        }
    }
}

void Flarum_LoadClient(int client, const char[] sCommunityID)
{
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT user_id FROM %slogin_providers WHERE provider = 'steam' AND identifier = '%s'", g_sPrefix, sCommunityID);
    g_dDatabase.Query(Flarum_GetUserId, sQuery, GetClientUserId(client));
    
    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(Flarum_LoadClient) Query: %s", sQuery);
    }
}

public void Flarum_GetUserId(Database db, DBResultSet results, const char[] error, any userid)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (Flarum_GetUserId) Fail at Query: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);
        
        if (!IsClientValid(client))
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(Flarum_GetUserId) Error grabbing User Data: Client invalid");
            }

            return;
        }
        
        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(Flarum_GetUserId) Retrieving data for %N...", client);
        }
        
        if (results.FetchRow())
        {
            if (results.IsFieldNull(0))
            {
                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(Flarum_GetUserId) Error retrieving User ID. Error: Field is null");
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
                Forum_LogMessage("API", "(Flarum_GetUserId) User '%N' has been processed successfully!", client);
            }

            char sQuery[256];
            Format(sQuery, sizeof(sQuery), "SELECT %susers.username, %sgroup_user.group_id FROM %susers JOIN %sgroup_user WHERE %susers.id = '%d' AND %sgroup_user.user_id = '%d';", g_sPrefix, g_sPrefix, g_sPrefix, g_sPrefix, g_sPrefix, g_iUserID[client], g_sPrefix, g_iUserID[client]);
            g_dDatabase.Query(Flarum_UserInformations, sQuery, userid);

            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(Flarum_GetUserId) User Informations - Query: %s", sQuery);
            }

            StringMapSnapshot smFields = g_smFields.Snapshot();
            char sKey[32];

            g_iFieldCount[client] = 0;

            delete g_smUserFields[client];
            g_smUserFields[client] = new StringMap();

            for (int i = 0; i < smFields.Length; i++)
            {
                smFields.GetKey(i, sKey, sizeof(sKey));

                Forum_LogMessage("API", "(Flarum_GetUserId) smFields.Length: %d, g_smFields.Size: %d", smFields.Length, g_smFields.Size);

                Format(sQuery, sizeof(sQuery), "SELECT content FROM %sfof_masquerade_answers WHERE user_id = '%d' AND field_id = \"%s\"", g_sPrefix, g_iUserID[client], sKey);
                DataPack pack = new DataPack();
                pack.WriteCell(userid);
                pack.WriteString(sKey);
                g_dDatabase.Query(Flarum_UserFields, sQuery, pack);

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(Flarum_GetUserId) User Fields - Query: %s", sQuery);
                }
            }

            delete smFields;
        }
        else
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(Flarum_GetUserId) Error retrieving User (\"%L\") Data: (Row not fetched)", client);
            }
        }
    }
}

public void Flarum_UserInformations(Database db, DBResultSet results, const char[] error, any userid)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (Flarum_UserInformations) Fail at Query: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);
        
        if (!IsClientValid(client))
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(Flarum_UserInformations) Error grabbing User informations: Client invalid");
            }

            return;
        }
        
        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(Flarum_UserInformations) Retrieving informations for %N...", client);
        }

        delete g_aSecondaryGroups[client];
        
        while (results.FetchRow())
        {
            if (results.IsFieldNull(0))
            {
                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(Flarum_UserInformations) Error retrieving User informations: (Field is null)");
                }

                return;
            }

            results.FetchString(0, g_sName[client], sizeof(g_sName[]));
            int iGroup = results.FetchInt(1);

            if (g_iPrimaryGroup[client] == -1 || g_iPrimaryGroup[client] > iGroup)
            {
                g_iPrimaryGroup[client] = iGroup;
            }

            if (g_aSecondaryGroups[client] == null)
            {
                g_aSecondaryGroups[client] = new ArrayList();
            }

            g_aSecondaryGroups[client].Push(iGroup);

            Format(g_sCustomTitle[client], sizeof(g_sCustomTitle[]), "N/A");
            
            Call_StartForward(g_hOnInfoProcessed);
            Call_PushCell(client);
            Call_PushString(g_sName[client]);
            Call_PushCell(g_iPrimaryGroup[client]);
            Call_PushCell(g_aSecondaryGroups[client]);
            Call_Finish();
            
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(Flarum_UserInformations) User informations for'%N' has been processed successfully!", client);
            }
        }
    }
}

public void Flarum_UserFields(Database db, DBResultSet results, const char[] error, any pack)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (Flarum_UserFields) Fail at Query: %s", error);
        delete view_as<DataPack>(pack);
        return;
    }
    else
    {
        view_as<DataPack>(pack).Reset();

        int client = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());

        char sKey[32];
        view_as<DataPack>(pack).ReadString(sKey, sizeof(sKey));

        delete view_as<DataPack>(pack);
        
        if (!IsClientValid(client))
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(Flarum_UserFields) Error grabbing user fields: Client invalid");
            }

            return;
        }

        g_iFieldCount[client]++;
        Forum_LogMessage("API", "(Flarum_UserFields) Field Count: %d", g_iFieldCount[client]);

        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(Flarum_UserFields) Retrieving user field %s for %N...", sKey, client);
        }
        
        if (results.FetchRow())
        {
            char sValue[128];

            if (results.IsFieldNull(0))
            {
                LogMessage("[Forum-API] (Flarum_UserFields) Can't retrieve user field %s. Error: Field is null", sKey);
            }
            else
            {
                results.FetchString(0, sValue, sizeof(sValue));
            }

            if (strlen(sValue) > 1)
            {
                g_smUserFields[client].SetString(sKey, sValue);
            }

            if (g_iFieldCount[client] == g_smFields.Size)
            {
                Call_StartForward(g_hOnUserFieldsProcessed);
                Call_PushCell(client);
                Call_PushCell(g_smUserFields[client]);
                Call_Finish();

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(Flarum_UserFields) user fields for'%N' has been processed successfully!", client);
                }
            }
        }
        else
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(Flarum_UserFields) Error retrieving User (\"%L\") fields: (Row not fetched)", client);
            }
        }
    }
}
