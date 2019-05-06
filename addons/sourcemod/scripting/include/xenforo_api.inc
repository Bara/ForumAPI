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
 * Returns the primary group
 *
 * @param client		client index
 *
 * @return				primary group id
 **/
native int XenForo_GetClientPrimaryGroup(int client);

/**
 * Returns the secondary groups as arraylist
 * NOTE: This ArrayList must be closed
 *
 * @param client		client index
 *
 * @return				secondary group ids as arraylist
 **/
native ArrayList XenForo_GetClientSecondaryGroups(int client);

/**
 * Returns the user name
 *
 * @param client		client index
 *
 * @return				True user name found, otherwise false
 **/
native bool XenForo_GetClientName(int client, const char[] name);

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
 * @param xf_userid			xenforo user_id
 *
 * @noreturn
 **/
forward void XF_OnProcessed(int client, int xf_userid);

/**
 * Called after user was processed
 *
 * @param client			client index
 * @param name				username in forum
 * @param primarygroup		primary group id
 * @param secondarygroups	secondary group id list as arraylist
 *
 * @noreturn
 **/
forward void XF_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups);

/**
 * Called when the plugin connects to the database successfully.
 *
 * @noparam
 *
 * @noreturn
 **/
forward void XF_OnConnected();

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