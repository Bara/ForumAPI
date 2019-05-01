#if defined _xenforo_api_included
	#endinput
#endif
#define _xenforo_api_included

///////////////
//Natives

/**
 * Returns the user index of the client for Xenforo.
 *
 * @param client		client index
 *
 * @return				UserID of the client index.
 **/
native int XenForo_GetClientID(int client);

/**
 * Returns true or false based on if they are processed or not.
 * Being processed means they have a UserID, credits, etc.
 *
 * @param client		client index
 *
 * @return				True if processed, false otherwise.
 **/
native bool XenForo_IsProcessed(int client);

/**
 * Executes a query into the Xenforo database tables.
 * Does not use any callbacks or retrieves any responses.
 *
 * @param sQuery		String buffer to execute.
 * @param prio			Priority to execute the query.
 *
 * @noreturn
 **/
native void XenForo_TExecute(const char[] sQuery, DBPriority prio = DBPrio_Normal);

/**
 * Returns the database handle
 *
 * @noparams
 *
 * @return				Returns the database handle
 **/
native Database XenForo_GetDatabase();

/**
 * Returns if the plugin is connected successfully to the database for Xenforo.
 *
 * @noparams
 *
 * @return				True if connected, false otherwise.
 **/
native bool XenForo_IsConnected();

///////////////
//Forwards

/**
 * Called when a user is processed by the plugin and receives a User ID.
 *
 * @param client		client index
 *
 * @noreturn
 **/
forward void XF_OnProcessed(int client);

/**
 * Called when the plugin connects to the database successfully.
 *
 * @noparam
 *
 * @noreturn
 **/
forward void XF_OnConnected();

////////////////
//Stocks

stock bool SteamIDToCommunityID(const char[] sSteamID, char[] sCommunityID, int size)
{
		if(strlen(sSteamID) < 11 || sSteamID[0]!='S' || sSteamID[6]=='I')
		{
				sCommunityID[0] = 0;
				return false;
		}

		int iUpper = 765611979;
		int iFriendID = StringToInt(sSteamID[10])*2 + 60265728 + sSteamID[8]-48;

		int iDiv = iFriendID / 100000000;
		int tt = iDiv / 10 + 1;
		int iIdx = 9 - (iDiv ? tt : 0);
		iUpper += iDiv;
		
		IntToString(iFriendID, sCommunityID[iIdx], size-iIdx);
		iIdx = sCommunityID[9];
		IntToString(iUpper, sCommunityID, size);
		sCommunityID[9] = iIdx;

		return true;
}

public SharedPlugin __pl_xenforo_api = 
{
	name = "xenforo_api",
	file = "xenforo_api.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_xenforo_api_SetNTVOptional()
{
	MarkNativeAsOptional("XenForo_GetClientID");
	MarkNativeAsOptional("XenForo_IsProcessed");
	MarkNativeAsOptional("XenForo_TExecute");
	MarkNativeAsOptional("XenForo_IsConnected");
	MarkNativeAsOptional("XenForo_GetDatabase");
}
#endif