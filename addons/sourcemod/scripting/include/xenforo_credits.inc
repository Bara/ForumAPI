#if defined _xenforo_credits_included
	#endinput
#endif
#define _xenforo_credits_included

native int XenForo_GetClientCredits(int client);
native bool XenForo_AddClientCredits(int client, int credits);
native bool XenForo_RemoveClientCredits(int client, int credits);

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
	MarkNativeAsOptional("XenForo_GetClientCredits");
	MarkNativeAsOptional("XenForo_AddClientCredits");
	MarkNativeAsOptional("XenForo_RemoveClientCredits");
}
#endif
