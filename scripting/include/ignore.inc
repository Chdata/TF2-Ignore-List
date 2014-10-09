#if defined _IGNOREMATRIX_included
 #endinput
#endif
#define _IGNOREMATRIX_included

/**
 * Input a client and chat target
 *
 * @return The ignore matrix with these parameters
 */
native bool:GetIgnoreMatrix(client, target);

public SharedPlugin:__pl_IGNOREMATRIX = 
{
    name = "ignorematrix",
    file = "ignore.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_IGNOREMATRIX_SetNTVOptional()
{
    MarkNativeAsOptional("GetIgnoreMatrix");
}
#endif