/*
Ignore List
By: Chdata

TODO:
sm_ignore
argc < 1 = view a list of usernames
else ignore the name that was typed

Choose a player
1. name
2. name
3. name

USER's ignore status (select to toggle)
1. Chat (ignored)
2. Mic (visible)
3. Voice commands (visible)


sm_block

This is for the cvar determining how people see "You are being ignored"

// Specifies how admin activity should be relayed to users.  Add up the values
// below to get the functionality you want.
// 1: Show admin activity to non-admins anonymously.
// 2: If 1 is specified, admin names will be shown.
// 4: Show admin activity to admins anonymously.
// 8: If 4 is specified, admin names will be shown.
// 16: Always show admin names to root users.
// --
// Default: 13 (1+4+8) 14 for players to see names
sm_show_activity 13

This is for who you can target with the ignore list

// Sets how SourceMod should check immunity levels when administrators target 
// each other.
// 0: Ignore immunity levels (except for specific group immunities).
// 1: Protect from admins of lower access only.
// 2: Protect from admins of equal to or lower access.
// 3: Same as 2, except admins with no immunity can affect each other.
// --
// Default: 1
sm_immunity_mode 1

*/

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <scp>

#define PLUGIN_VERSION "0x03"

public Plugin:myinfo =
{
    name = "Ignore list",
    author = "Chdata",
    description = "Provides a way to ignore communication.",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/groups/tf2data/"
};

enum Targeting
{
    String:arg[MAX_NAME_LENGTH],
    buffer[MAXPLAYERS],
    buffersize,
    String:targetname[MAX_TARGET_LENGTH],
    bool:tn_is_ml
};

static Target[Targeting];

enum IgnoreStatus
{
    bool:Chat,
    bool:Voice
};

static bool:IgnoreMatrix[MAXPLAYERS + 1][MAXPLAYERS + 1][IgnoreStatus];

static bool:g_bEnabled = false;

public OnPluginStart()
{
    CreateConVar(
        "sm_ignorelist_version", PLUGIN_VERSION,
        "Ignore List Version",
        FCVAR_REPLICATED|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY
    );

    LoadTranslations("common.phrases");

    RegConsoleCmd("sm_ignore",   Command_Ignore,   "Usage: sm_ignore <#userid|name> | Set target's communications to be ignored.");
    RegConsoleCmd("sm_block",    Command_Ignore,   "Usage: sm_block <#userid|name> | Set target's communications to be ignored.");
    RegConsoleCmd("sm_unignore", Command_UnIgnore, "Usage: sm_unignore <#userid|name> | Unignore target.");
    RegConsoleCmd("sm_unblock",  Command_UnIgnore, "Usage: sm_unblock <#userid|name> | Unignore target.");

    /*RegConsoleCmd("sm_ignore_chat", Command_IgnoreChat, "Usage: sm_ignorec <#userid|name>\nSet target's chat to be ignored.");
    RegConsoleCmd("sm_ignore_voice", Command_IgnoreVoice, "Usage: sm_ignorev <#userid|name>\nSet target's voice to be ignored.");
    RegConsoleCmd("sm_ignorechat", Command_IgnoreChat, "Usage: sm_ignorec <#userid|name>\nSet target's chat to be ignored.");
    RegConsoleCmd("sm_ignorevoice", Command_IgnoreVoice, "Usage: sm_ignorev <#userid|name>\nSet target's voice to be ignored.");
    RegConsoleCmd("sm_ignore_c", Command_IgnoreChat, "Usage: sm_ignorec <#userid|name>\nSet target's chat to be ignored.");
    RegConsoleCmd("sm_ignore_v", Command_IgnoreVoice, "Usage: sm_ignorev <#userid|name>\nSet target's voice to be ignored.");
    RegConsoleCmd("sm_ignorec", Command_IgnoreChat, "Usage: sm_ignorec <#userid|name>\nSet target's chat to be ignored.");
    RegConsoleCmd("sm_ignorev", Command_IgnoreVoice, "Usage: sm_ignorev <#userid|name>\nSet target's voice to be ignored.");
    RegConsoleCmd("sm_ignore", Command_Ignore, "Usage: sm_ignore <#userid|name>\nSet target's chat and voice to be ignored.");

    RegConsoleCmd("sm_unignore_chat", Command_UnIgnoreChat, "Usage: sm_unignorec <#userid|name>\nUnignore target's chat.");
    RegConsoleCmd("sm_unignore_voice", Command_UnIgnoreVoice, "Usage: sm_unignorev <#userid|name>\nUnignore target's voice.");
    RegConsoleCmd("sm_unignorechat", Command_UnIgnoreChat, "Usage: sm_unignorec <#userid|name>\nUnignore target's chat.");
    RegConsoleCmd("sm_unignorevoice", Command_UnIgnoreVoice, "Usage: sm_unignorev <#userid|name>\nUnignore target's voice.");
    RegConsoleCmd("sm_unignore_c", Command_UnIgnoreChat, "Usage: sm_unignorec <#userid|name>\nUnignore target's chat.");
    RegConsoleCmd("sm_unignore_v", Command_UnIgnoreVoice, "Usage: sm_unignorev <#userid|name>\nUnignore target's voice.");
    RegConsoleCmd("sm_unignorec", Command_UnIgnoreChat, "Usage: sm_unignorec <#userid|name>\nUnignore target's chat.");
    RegConsoleCmd("sm_unignorev", Command_UnIgnoreVoice, "Usage: sm_unignorev <#userid|name>\nUnignore target's voice.");
    RegConsoleCmd("sm_unignore", Command_UnIgnore, "Usage: sm_unignore <#userid|name>\nUnignore target.");*/
}

/*
    Check for necessary plugin dependencies and shut down this plugin if not found.

*/
public OnAllPluginsLoaded()
{
    if (!LibraryExists("scp"))
    {
        SetFailState("Simple Chat Processor is not loaded. It is required for this plugin to work.");
        //g_bEnabled = false; // No real reason to do this because SetFailState pauses the plugin anyway
    }
}

/*
    Enable the plugin if the necessary library is added

*/
public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "scp"))
    {
        g_bEnabled = true;
    }
}

/*
    If a necessary plugin is removed, also shut this one down.

*/
public OnLibraryRemoved(const String:name[])
{
    if (StrEqual(name, "scp"))
    {
        //SetFailState("Simple Chat Processor Unloaded. Plugin Disabled.");     // This is really god damn awful to do because it error logs almost every time the map changes
        //LogMessage("Simple Chat Processor Unloaded. Plugin Disabled.");       // No real reason to play a message though
        g_bEnabled = false;
    }
}

public OnClientDisconnect(client)
{
    for (new i = 0; i <= MAXPLAYERS; i++)
    {
        IgnoreMatrix[client][i][Chat] = false;
        IgnoreMatrix[client][i][Voice] = false;
    }
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[])
{
    if ((author < 0) || (author > MaxClients))
    {
        LogError("[Ignore list] Warning: author is out of bounds: %d", author);
        return Plugin_Continue;
    }
    new i = 0;
    new client;
    while (i < GetArraySize(recipients))
    {
        client = GetArrayCell(recipients, i);
        if ((client < 0) || (client > MaxClients))
        {
            LogError("[Ignore list] Warning: client is out of bounds: %d, Try updating SCP", client);
            i++;
            continue;
        }
        if (IgnoreMatrix[client][author][Chat])
        {
            RemoveFromArray(recipients, i);
        }
        else
        {
            i++;
        }
    }
    return Plugin_Changed;
}

public Action:Command_Ignore(iClient, iArgc)
{
    if (!g_bEnabled || !iClient)
    {
        return Plugin_Handled;
    }

    if (iArgc < 1)
    {
        Menu_PlayerList(iClient);
        return Plugin_Handled;
    }
    
    ProcessIgnore(iClient, true, true, 1|2);

    return Plugin_Handled;
}

public Action:Command_UnIgnore(iClient, iArgc)
{
    if (!g_bEnabled || !iClient)
    {
        return Plugin_Handled;
    }

    if (iArgc < 1)
    {
        Menu_PlayerList(iClient);
        //ReplyToCommand(client, "[SM] Usage: sm_unignore <#userid|name>");
        return Plugin_Handled;
    }
    
    ProcessIgnore(iClient, false, false, 1|2);

    return Plugin_Handled;
}


Menu_PlayerList(iClient)
{
    new Handle:hPlayerListMenu = CreateMenu(MenuHandler_PlayerList);
    SetMenuTitle(hPlayerListMenu, "Choose a player");

    decl String:s[12];
    decl String:n[MAXLENGTH_NAME];

    new iTargets = 0;

    for (new i = 1; i <= MaxClients; i++)
    {
        if (i != iClient && IsClientInGame(i) && !IsFakeClient(i))
        {
            IntToString(GetClientUserId(i), s, sizeof(s)); 
            GetClientName(i, n, sizeof(n));
            AddMenuItem(hPlayerListMenu, s, n); // Userid - Username
            iTargets++;
        }
    }

    if (iTargets)
    {
        DisplayMenu(hPlayerListMenu, iClient, MENU_TIME_FOREVER);
    }
    else
    {
        ReplyToCommand(iClient, "[SM] No players found.");
        CloseHandle(hPlayerListMenu);
    }
}

public MenuHandler_PlayerList(Handle:hMenu, MenuAction:iAction, iClient, iParam)
{
    switch (iAction)
    {
        case MenuAction_Select:
        {
            decl String:szUserid[12]; // Grab the Userid of player to check ignore status
            GetMenuItem(hMenu, iParam, szUserid, sizeof(szUserid));
            new iTarget = GetClientOfUserId(StringToInt(szUserid));

            if (iTarget == 0)
            {
                PrintToChat(iClient, "[SM] Target has disconnected.");
            }
            else
            {
                Menu_IgnoreList(iClient, iTarget);
            }
            //CloseHandle(hMenu);
        }
        case MenuAction_End:
        {
            CloseHandle(hMenu);
        }
    }
}

Menu_IgnoreList(iClient, iTarget)
{
    new Handle:hIgnoreListMenu = CreateMenu(MenuHandler_IgnoreList);
    SetMenuTitle(hIgnoreListMenu, "%N's ignore status (select to toggle)", iTarget);

    decl String:s[12], String:m[64];
    IntToString(GetClientUserId(iTarget), s, sizeof(s)); 

    Format(m, sizeof(m), "Chat (%s)", IgnoreMatrix[iClient][iTarget][Chat] ? "OFF" : "ON");
    AddMenuItem(hIgnoreListMenu, s, m);

    Format(m, sizeof(m),  "Mic (%s)", IgnoreMatrix[iClient][iTarget][Voice] ? "OFF" : "ON");
    AddMenuItem(hIgnoreListMenu, s, m);
    //AddMenuItem(hIgnoreListMenu, "2", "Voice Commands (visible)", );

    // SetMenuExitBackButton(hIgnoreListMenu, true);
    DisplayMenu(hIgnoreListMenu, iClient, MENU_TIME_FOREVER);
}

public MenuHandler_IgnoreList(Handle:hMenu, MenuAction:iAction, iClient, iParam)
{
    switch (iAction)
    {
        case MenuAction_Select:
        {
            decl String:szUserid[12]; // Grab the Userid of player to check ignore status
            GetMenuItem(hMenu, iParam, szUserid, sizeof(szUserid));
            new iTarget = GetClientOfUserId(StringToInt(szUserid));

            if (iTarget == 0)
            {
                PrintToChat(iClient, "[SM] Target has disconnected.");
            }
            else
            {
                new which; // = 0;
                switch (iParam)
                {
                    case 0: which |= 1;
                    case 1: which |= 2;
                }
                ToggleIgnoreStatus(iClient, iTarget, iParam == 0, iParam == 1, which, false);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(hMenu);
        }
    }
}

/*
    client is the person ignoring someone
    the chat/voice bool says what we want to set their status to
    which says whether or not we're actually changing chat 1, voice 2, or both 3

*/
stock ProcessIgnore(client, const bool:chat = false, const bool:voice = false, const which)
{
    GetCmdArg(1, Target[arg], MAX_NAME_LENGTH);

    new bool:bTargetAll = false;

    if (strcmp(Target[arg], "@all", false) == 0)
    {
        bTargetAll = true;
    }

    Target[buffersize] = ProcessTargetString(Target[arg], client, Target[buffer], MAXPLAYERS, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_IMMUNITY, Target[targetname], MAX_TARGET_LENGTH, Target[tn_is_ml]);

    if (Target[buffersize] <= 0)
    {
        ReplyToTargetError(client, Target[buffersize]);
        return;
    }

    for (new i = 0; i < Target[buffersize]; i++)
    {
        ToggleIgnoreStatus(client, Target[buffer][i], chat, voice, which, bTargetAll);      
    }

    if (bTargetAll)
    {
        decl String:s[MAXLENGTH_MESSAGE];

        Format(s, sizeof(s), "[SM] All Players - Chat: %s | Voice: %s",
            !(which & 1) ? "Unchanged" : chat ? "OFF" : "ON",
            !(which & 2) ? "Unchanged" : voice ? "OFF" : "ON"
        );

        ReplyToCommand(client, s);
    }

    return;
}

ToggleIgnoreStatus(const client, const target, const bool:chat, const bool:voice, const which, const bool:bTargetAll)
{
    if (GetUserFlagBits(target) & ADMFLAG_SLAY)
    {
        if (!bTargetAll)
        {
            ReplyToCommand(client, "[SM] You cannot ignore admins.");
        }

        return;
    }

    if (which & 1)
    {
        IgnoreMatrix[client][target][Chat] = chat;
    }

    if (which & 2)
    {
        IgnoreMatrix[client][target][Voice] = voice;

        if (IgnoreMatrix[client][target][Voice])
        {
            SetListenOverride(client, target, Listen_No);
        }
        else
        {
            SetListenOverride(client, target, Listen_Default);
        }
    }

    if (bTargetAll)
    {
        return;
    }

    decl String:s[MAXLENGTH_MESSAGE];

    Format(s, sizeof(s), "[SM] %N - Chat: %s | Voice: %s",
        target,
        IgnoreMatrix[client][target][Chat] ? "OFF" : "ON",
        IgnoreMatrix[client][target][Voice] ? "OFF" : "ON"
    );

    ReplyToCommand(client, s);
    return;
}

stock bool:IsValidClient(iClient)
{
    return (0 < iClient && iClient <= MaxClients && IsClientInGame(iClient));
}

/*
Sets up a native to send whether or not a client is ignoring a specific target's chat

*/
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("GetIgnoreMatrix", Native_GetIgnoreMatrix);

    RegPluginLibrary("ignorematrix");

    return APLRes_Success;
}

/*
The native itself

*/
public Native_GetIgnoreMatrix(Handle:plugin, numParams)
{
    new client = GetNativeCell(1);
    new target = GetNativeCell(2);

    return IgnoreMatrix[client][target][Chat];
}

#endinput

public Action:Command_IgnoreChat(client, argc)
{
    if (argc == 0)
    {
        ReplyToCommand(client, "Usage: sm_ignorec <#userid|name>");
        return Plugin_Handled;
    }
    
    ProcessIgnore(client, true, _, 1);

    return Plugin_Handled;
}

public Action:Command_IgnoreVoice(client, argc)
{
    if (argc == 0)
    {
        ReplyToCommand(client, "Usage: sm_ignorev <#userid|name>");
        return Plugin_Handled;
    }

    ProcessIgnore(client, _, true, 2);

    return Plugin_Handled;
}

public Action:Command_UnIgnore(client, argc)
{
    if (argc == 0)
    {
        ReplyToCommand(client, "Usage: sm_unignore <#userid|name>, sm_unignorec chat only, sm_unignorev voice only");
        return Plugin_Handled;
    }
    
    ProcessIgnore(client, false, false, 3);

    return Plugin_Handled;
}

public Action:Command_UnIgnoreChat(client, argc)
{
    if (argc == 0)
    {
        ReplyToCommand(client, "Usage: sm_unignorec <#userid|name>");
        return Plugin_Handled;
    }
    
    ProcessIgnore(client, false, _, 1);

    return Plugin_Handled;
}

public Action:Command_UnIgnoreVoice(client, argc)
{
    if (argc == 0)
    {
        ReplyToCommand(client, "Usage: sm_unignorev <#userid|name>");
        return Plugin_Handled;
    }

    ProcessIgnore(client, _, false, 2);

    return Plugin_Handled;
}
