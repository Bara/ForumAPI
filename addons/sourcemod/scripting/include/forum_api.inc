#if defined _forum_api_included
	#endinput
#endif
#define _forum_api_included

///////////////
//Natives

/**
 * Returns the user id of the client.
 *
 * @param client		client index
 *
 * @return				UserID of the client index.
 **/
native int Forum_GetClientID(int client);

/**
 * Returns the primary group
 *
 * @param client		client index
 *
 * @return				primary group id
 **/
native int Forum_GetClientPrimaryGroup(int client);

/**
 * Returns the secondary groups as arraylist
 * NOTE: Don't close/delete this ArrayList
 *
 * @param client		client index
 *
 * @return				secondary group ids as arraylist
 **/
native ArrayList Forum_GetClientSecondaryGroups(int client);

/**
 * Returns the user name
 *
 * @param client		client index
 *
 * @return				True user name found, otherwise false
 **/
native bool Forum_GetClientName(int client, const char[] name);

/**
 * Returns stringmap with all user fields for the specific client
 *
 * @param client		client index
 *
 * @return				Stringmap with all user fields for the specific client
 **/
native StringMap Forum_GetClientUserFields(int client);

/**
 * Returns the custom title
 *
 * @param client		client index
 *
 * @return				True custom found found, otherwise false
 **/
native bool Forum_GetClientCustomTitle(int client, const char[] customtitle);

/**
 * Returns true or false based on if they are processed or not.
 * Being processed means they have a UserID, credits, etc.
 *
 * @param client		client index
 *
 * @return				True if processed, false otherwise.
 **/
native bool Forum_IsProcessed(int client);

/**
 * Executes a query into the forum database tables.
 * Does not use any callbacks or retrieves any responses.
 *
 * @param sQuery		String buffer to execute.
 * @param prio			Priority to execute the query.
 *
 * @noreturn
 **/
native void Forum_TExecute(const char[] sQuery, DBPriority prio = DBPrio_Normal);

/**
 * Returns the database handle
 *
 * @noparams
 *
 * @return				Returns the database handle
 **/
native Database Forum_GetDatabase();

/**
 * Returns if the plugin is connected successfully to the forum database.
 *
 * @noparams
 *
 * @return				True if connected, false otherwise.
 **/
native bool Forum_IsConnected();

///////////////
//Forwards

/**
 * Called when a user is processed by the plugin and receives a User ID.
 *
 * @param client		client index
 * @param forum_userid	forum user_id
 *
 * @noreturn
 **/
forward void Forum_OnProcessed(int client, int forum_userid);

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
forward void Forum_OnInfoProcessed(int client, const char[] name, int primarygroup, ArrayList secondarygroups);

/**
 * Called after user fields was processed
 *
 * @param client			client index
 * @param userfields		Keyword is the field_id/keyword of user field, value is value for the specific user
							Note: Don't close/delete this stringmap
 *
 * @noreturn
 **/
forward void Forum_OnUserFieldsProcessed(int client, StringMap userfields);

/**
 * Called when the plugin connects to the database successfully.
 *
 * @noparam
 *
 * @noreturn
 **/
forward void Forum_OnConnected();

/**
 * Returns a stringmap of all forum groups.
 * key is the groupid and value (string) name of group
 * Note: You shouldn't close/delete this stringmap
 *
 * @noparam
 *
 * @return			Stringmap or -1 for nothing
 * 
 */
native StringMap Forum_GetGroupList();

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
native StringMap Forum_GetGroupBannerText();

/**
 * Returns a stringmap with all guser fields.
 * key is the field_id/keyword and value (string) name of the user field.
 * Note 2: You shouldn't close/delete this stringmap
 *
 * @noparam
 *
 * @return			Stringmap or -1 for nothing
 */
native StringMap Forum_GetUserFields();

native void Forum_LogMessage(const char[] tag, const char[] message, any ...);

public SharedPlugin __pl_forum_api = 
{
	name = "forum_api",
	file = "forum_api.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_forum_api_SetNTVOptional()
{
	MarkNativeAsOptional("Forum_GetClientID");
	MarkNativeAsOptional("Forum_GetClientPrimaryGroup");
	MarkNativeAsOptional("Forum_GetClientSecondaryGroups");
	MarkNativeAsOptional("Forum_GetClientName");
	MarkNativeAsOptional("Forum_GetClientUserFields");
	MarkNativeAsOptional("Forum_IsProcessed");
	MarkNativeAsOptional("Forum_TExecute");
	MarkNativeAsOptional("Forum_GetDatabase");
	MarkNativeAsOptional("Forum_IsConnected");
	MarkNativeAsOptional("Forum_GetGroupList");
	MarkNativeAsOptional("Forum_GetGroupBannerText");
	MarkNativeAsOptional("Forum_GetUserFields");
	MarkNativeAsOptional("Forum_LogMessage");
}
#endif
