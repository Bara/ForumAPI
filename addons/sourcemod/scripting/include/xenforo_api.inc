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
 * NOTE: Don't close/delete this ArrayList
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
 * Returns stringmap with all user fields for the specific client
 *
 * @param client		client index
 *
 * @return				Stringmap with all user fields for the specific client
 **/
native StringMap XenForo_GetClientUserFields(int client);

/**
 * Returns the custom title
 *
 * @param client		client index
 *
 * @return				True custom found found, otherwise false
 **/
native bool XenForo_GetClientCustomTitle(int client, const char[] customtitle);

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
 * Called after user informations was processed
 *
 * @param client			client index
 * @param name				username in forum
 * @param primarygroup		primary group id
 * @param secondarygroups	secondary group id list as arraylist (Don't close this array)
 *
 * @noreturn
 **/
forward void XF_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups);

/**
 * Called after user fields was processed
 *
 * @param client			client index
 * @param userfields		Keyword is the field_id/keyword of user field, value is value for the specific user
							Note: Don't close/delete this stringmap
 *
 * @noreturn
 **/
forward void XF_OnUserFieldsProcessed(int client, StringMap userfields);

/**
 * Called when the plugin connects to the database successfully.
 *
 * @noparam
 *
 * @noreturn
 **/
forward void XF_OnConnected();

/**
 * Returns a stringmap of all xenforo groups.
 * key is the groupid and value (string) name of group
 * Note: You shouldn't close/delete this stringmap
 *
 * @noparam
 *
 * @return			Stringmap or -1 for nothing
 * 
 */
native StringMap XenForo_GetGroupList();

/**
 * Returns a stringmap with all group banners (if exists).
 * key is the groupid and value (string) banner_text of the group.
 * Note 1: No entry = No banner_text
 * Note 2: You shouldn't close/delete this stringmap
 *
 * @noparam
 *
 * @return			Stringmap or -1 for nothing
 */
native StringMap XenForo_GetGroupBannerText();

/**
 * Returns a stringmap with all guser fields.
 * key is the field_id/keyword and value (string) name of the user field.
 * Note 2: You shouldn't close/delete this stringmap
 *
 * @noparam
 *
 * @return			Stringmap or -1 for nothing
 */
native StringMap XenForo_GetUserFields();

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
	MarkNativeAsOptional("XenForo_GetClientPrimaryGroup");
	MarkNativeAsOptional("XenForo_GetClientSecondaryGroups");
	MarkNativeAsOptional("XenForo_GetClientName");
	MarkNativeAsOptional("XenForo_GetClientUserFields");
	MarkNativeAsOptional("XenForo_IsProcessed");
	MarkNativeAsOptional("XenForo_TExecute");
	MarkNativeAsOptional("XenForo_GetDatabase");
	MarkNativeAsOptional("XenForo_IsConnected");
	MarkNativeAsOptional("XenForo_GetGroupList");
	MarkNativeAsOptional("XenForo_GetGroupBannerText");
	MarkNativeAsOptional("XenForo_GetUserFields");
}
#endif
