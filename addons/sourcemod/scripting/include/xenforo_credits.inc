#if defined _xenforo_credits_included
	#endinput
#endif
#define _xenforo_credits_included

native int XenForo_GetUserCredits(int client);
native bool XenForo_AddUserCredits(int client, int credits);
native bool XenForo_RemoveUserCredits(int client, int credits);

/*
 * If add is true, then the amount of credits was added.
 * newCredits is the new value g_iCredits.
 * If credits = -1, then it's the forum sync forward (every 30 seconds by default)
 * 
 */
forward void XF_OnCreditsUpdate(int client, bool add, int credits, int newCredits);

public SharedPlugin __pl_xenforo_credits = 
{
	name = "xenforo_vip",
	file = "xenforo_vip.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_xenforo_credits_SetNTVOptional()
{
	MarkNativeAsOptional("XenForo_GetUserCredits");
	MarkNativeAsOptional("XenForo_AddUserCredits");
	MarkNativeAsOptional("XenForo_RemoveUserCredits");
}
#endif
