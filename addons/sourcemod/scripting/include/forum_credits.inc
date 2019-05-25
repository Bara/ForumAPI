#if defined _forum_credits_included
	#endinput
#endif
#define _forum_credits_included

native int Forum_GetClientCredits(int client);
native bool Forum_AddClientCredits(int client, int credits);
native bool Forum_RemoveClientCredits(int client, int credits);

/*
 * If add is true, then the amount of credits was added.
 * newCredits is the new value g_iCredits.
 * If credits = -1, then it's the forum sync forward (every 30 seconds by default)
 * 
 */
forward void Forum_OnCreditsUpdate(int client, bool add, int credits, int newCredits);

public SharedPlugin __pl_forum_credits = 
{
	name = "forum_credits",
	file = "forum_credits.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_forum_credits_SetNTVOptional()
{
	MarkNativeAsOptional("Forum_GetClientCredits");
	MarkNativeAsOptional("Forum_AddClientCredits");
	MarkNativeAsOptional("Forum_RemoveClientCredits");
}
#endif
