void XenForo_LoadGroups()
{
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT user_group_id, title, banner_text FROM xf_user_group");
    g_dDatabase.Query(XenForo_GetForumGroups, sQuery);

    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(XenForo_LoadGroups) Query: %s", sQuery);
    }
}

public int XenForo_GetForumGroups(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        LogError("[Forum-API] (XenForo_GetForumGroups) Query error by void: '%s'", error);
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
                    Forum_LogMessage("API", "(XenForo_GetForumGroups) GroupID: %d, Name: %s, Banner: %s", groupid, sName, sBanner);
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
        XenForo_LoadUserFields();
    }
}

void XenForo_LoadUserFields()
{
    delete g_smFields;
    g_smFields = new StringMap();

    char sQuery[128];
    Format(sQuery, sizeof(sQuery), "SELECT field_id FROM xf_user_field");
    g_dDatabase.Query(XenForo_Fields, sQuery);

    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(XenForo_LoadUserFields) Query: %s", sQuery);
    }
}

public void XenForo_Fields(Database db, DBResultSet results, const char[] error, int userid)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (XenForo_Fields) Fail at Query: %s", error);
        delete g_smFields;
        return;
    }
    else
    {
        if (results.HasResults)
        {
            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(XenForo_Fields) Row Count: %d", results.RowCount);
            }

            g_iFieldsRowCount = results.RowCount;

            while (results.FetchRow())
            {
                char sField[64];
                results.FetchString(0, sField, sizeof(sField));

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(XenForo_Fields) Field ID: %s", sField);
                }

                char sTitle[128];
                Format(sTitle, sizeof(sTitle), "user_field_title.%s", sField);

                char sQuery[512];
                Format(sQuery, sizeof(sQuery), "SELECT phrase_text FROM xf_phrase WHERE title = \"%s\"", sTitle);
                DataPack pack = new DataPack();
                pack.WriteString(sField);
                g_dDatabase.Query(XenForo_FieldsPhrase, sQuery, pack);

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(XenForo_Fields) Query: %s", sQuery);
                }
            }

            g_bFields = true;
            LoadClients();
        }
    }
}

public void XenForo_FieldsPhrase(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (XenForo_FieldsPhrase) Fail at Query: %s", error);
        delete pack;
        return;
    }
    else
    {
        pack.Reset();

        char sField[32];
        pack.ReadString(sField, sizeof(sField));

        delete pack;

        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(XenForo_FieldsPhrase) Retrieving phrase for user_field %s...", sField);
        }
        
        if (results.FetchRow())
        {
            g_iFieldsRowCount--;

            if (results.IsFieldNull(0))
            {
                LogError("[Forum-API] (XenForo_FieldsPhrase) Error retrieving user_field phrase (%s): (Field is null)", sField);
                return;
            }

            char sPhrase[64];
            results.FetchString(0, sPhrase, sizeof(sPhrase));

            g_smFields.SetString(sField, sPhrase);

            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(XenForo_FieldsPhrase) Added user_field %s (Name: %s)", sField, sPhrase);
            }

            if (g_iFieldsRowCount == 0)
            {
                g_bFields = true;
                LoadClients();
            }
        }
    }
}

void XenForo_LoadClient(int client, const char[] sCommunityID)
{
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT user_id FROM xf_user_connected_account WHERE provider = 'steam' AND provider_key = '%s'", sCommunityID);
    g_dDatabase.Query(XenForo_GetUserId, sQuery, GetClientUserId(client));
    
    if (g_cDebug.BoolValue)
    {
        Forum_LogMessage("API", "(XenForo_LoadClient) Query: %s", sQuery);
    }
}

public void XenForo_GetUserId(Database db, DBResultSet results, const char[] error, int userid)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (XenForo_GetUserId) Fail at Query: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);
        
        if (!IsClientValid(client))
        {
            LogError("[Forum-API] (XenForo_GetUserId) Error grabbing User Data: Client invalid");
            return;
        }
        
        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(XenForo_GetUserId) Retrieving data for %N...", client);
        }
        
        if (results.FetchRow())
        {
            if (results.IsFieldNull(0))
            {
                LogError("[Forum-API] (XenForo_GetUserId) Error retrieving User Data: (Field is null)");
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
                Forum_LogMessage("API", "(XenForo_GetUserId) User '%N' has been processed successfully!", client);
            }

            char sQuery[256];
            Format(sQuery, sizeof(sQuery), "SELECT username, user_group_id, secondary_group_ids, custom_title FROM xf_user WHERE user_id = '%d'", g_iUserID[client]);
            g_dDatabase.Query(XenForo_UserInformations, sQuery, userid);

            if (g_cDebug.BoolValue)
            {
                Forum_LogMessage("API", "(XenForo_GetUserId) User Informations - Query: %s", sQuery);
            }

            StringMapSnapshot smFields = g_smFields.Snapshot();
            char sKey[32];

            g_iFieldCount[client] = 0;

            delete g_smUserFields[client];
            g_smUserFields[client] = new StringMap();

            for (int i = 0; i < smFields.Length; i++)
            {
                smFields.GetKey(i, sKey, sizeof(sKey));

                Forum_LogMessage("API", "(XenForo_GetUserId) smFields.Length: %d, g_smFields.Size: %d", smFields.Length, g_smFields.Size);

                Format(sQuery, sizeof(sQuery), "SELECT field_value FROM xf_user_field_value WHERE user_id = '%d' AND field_id = \"%s\"", g_iUserID[client], sKey);
                DataPack pack = new DataPack();
                pack.WriteCell(userid);
                pack.WriteString(sKey);
                g_dDatabase.Query(XenForo_UserFields, sQuery, pack);

                if (g_cDebug.BoolValue)
                {
                    Forum_LogMessage("API", "(XenForo_GetUserId) User Fields - Query: %s", sQuery);
                }
            }

            delete smFields;
        }
        else
        {
            LogError("[Forum-API] (XenForo_GetUserId) Error retrieving User (\"%L\") Data: (Row not fetched)", client);
        }
    }
}

public void XenForo_UserInformations(Database db, DBResultSet results, const char[] error, int userid)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (XenForo_UserInformations) Fail at Query: %s", error);
        return;
    }
    else
    {
        int client = GetClientOfUserId(userid);
        
        if (!IsClientValid(client))
        {
            LogError("[Forum-API] (XenForo_UserInformations) Error grabbing User informations: Client invalid");
            return;
        }
        
        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(XenForo_UserInformations) Retrieving informations for %N...", client);
        }
        
        if (results.FetchRow())
        {
            if (results.IsFieldNull(0))
            {
                LogError("[Forum-API] (XenForo_UserInformations) Error retrieving User informations: (Field is null)");
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
                Forum_LogMessage("API", "(XenForo_UserInformations) User informations for'%N' has been processed successfully!", client);
            }
        }
        else
        {
            LogError("[Forum-API] (XenForo_UserInformations) Error retrieving User (\"%L\") informations: (Row not fetched)", client);
        }
    }
}

public void XenForo_UserFields(Database db, DBResultSet results, const char[] error, DataPack pack)
{
    if(db == null || strlen(error) > 0)
    {
        SetFailState("[Forum-API] (XenForo_UserFields) Fail at Query: %s", error);
        delete pack;
        return;
    }
    else
    {
        pack.Reset();

        int client = GetClientOfUserId(pack.ReadCell());

        char sKey[32];
        pack.ReadString(sKey, sizeof(sKey));

        delete pack;
        
        if (!IsClientValid(client))
        {
            LogError("[Forum-API] (XenForo_UserFields) Error grabbing user fields: Client invalid");
            return;
        }

        g_iFieldCount[client]++;
        Forum_LogMessage("API", "(XenForo_UserFields) Field Count: %d", g_iFieldCount[client]);

        if (g_cDebug.BoolValue)
        {
            Forum_LogMessage("API", "(XenForo_UserFields) Retrieving user field %s for %N...", sKey, client);
        }
        
        if (results.FetchRow())
        {
            if (results.IsFieldNull(0))
            {
                LogError("[Forum-API] (XenForo_UserFields) Error retrieving user fields: (Field is null)");
                return;
            }

            char sValue[128];
            results.FetchString(0, sValue, sizeof(sValue));

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
                    Forum_LogMessage("API", "(XenForo_UserFields) user fields for'%N' has been processed successfully!", client);
                }
            }
        }
        else
        {
            LogError("[Forum-API] (XenForo_UserFields) Error retrieving User (\"%L\") fields: (Row not fetched)", client);
        }
    }
}
