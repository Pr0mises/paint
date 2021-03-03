#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#define PLUGIN_VERSION		"1.1"

#define PAINT_DISTANCE_SQ	1.0
#define DEFAULT_FLAG		ADMFLAG_CHAT

public Plugin myinfo = 
{
    name = "Paint!",
    author = "SlidyBat, Promises",
    description = "Allow players to paint on walls",
    version = PLUGIN_VERSION,
    url = ""
}

/* GLOBALS */

int		g_PlayerPaintColour[MAXPLAYERS + 1];
int		g_PlayerPaintSize[MAXPLAYERS + 1];

float	g_fLastPaint[MAXPLAYERS + 1][3];
bool g_bIsPainting[MAXPLAYERS + 1] = { false, ...};



/* COOKIES */
Handle	g_hPlayerPaintColour;
Handle	g_hPlayerPaintSize;

/* COLOURS! */
/* Colour name, file name */
char g_cPaintColours[][][64] = // Modify this to add/change colours
{
	{ "Random", "random" },
	{ "White", "laser_white" },
	{ "Black", "laser_black" },
	{ "Blue", "laser_blue" },
	{ "Light Blue", "laser_lightblue" },
	{ "Brown", "laser_brown" },
	{ "Cyan", "laser_cyan" },
	{ "Green", "laser_green" },
	{ "Dark Green", "laser_darkgreen" },
	{ "Red", "laser_red" },
	{ "Orange", "laser_orange" },
	{ "Yellow", "laser_yellow" },
	{ "Pink", "laser_pink" },
	{ "Light Pink", "laser_lightpink" },
	{ "Purple", "laser_purple" },
};

/* Size name, size suffix */
char g_cPaintSizes[][][64] = // Modify this to add more sizes
{
	{ "Small", "" },
	{ "Medium", "_med" },
	{ "Large", "_large" },
};

int		g_Sprites[ ( sizeof( g_cPaintColours ) - 1 ) * ( sizeof( g_cPaintSizes ) ) ];

public void OnPluginStart()
{
	CreateConVar("paint_version", PLUGIN_VERSION, "Paint plugin version", FCVAR_NOTIFY);
	
	/* Register Cookies */
	g_hPlayerPaintColour = RegClientCookie( "paint_playerpaintcolour", "paint_playerpaintcolour", CookieAccess_Protected );
	g_hPlayerPaintSize = RegClientCookie( "paint_playerpaintsize", "paint_playerpaintsize", CookieAccess_Protected );
	
	/* COMMANDS */
	//RegAdminCmd("sm_paint",SM_Paint, DEFAULT_FLAG);
	RegConsoleCmd("sm_paint",SM_Paint, "Opens Paint Menu");
	RegConsoleCmd( "sm_paintcolour", cmd_PaintColour );
	RegConsoleCmd( "sm_paintcolor", cmd_PaintColour );
	RegConsoleCmd( "sm_paintsize", cmd_PaintSize );
	
	/* Late loading */
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame( i ) )
		{
			OnClientCookiesCached( i );
		}
	}
}

public void OnClientCookiesCached( int client )
{
	char sValue[64];

	
	GetClientCookie( client, g_hPlayerPaintColour, sValue, sizeof( sValue ) );
	g_PlayerPaintColour[client] = StringToInt( sValue );
	
	GetClientCookie( client, g_hPlayerPaintSize, sValue, sizeof( sValue ) );
	g_PlayerPaintSize[client] = StringToInt( sValue );
}

public void OnMapStart()
{
	char buffer[PLATFORM_MAX_PATH];
	
	for( int i = 1; i < sizeof( g_cPaintColours ); i++ )
	{
		Format( buffer, sizeof( buffer ), "decals/paint/%s.vtf", g_cPaintColours[i][1] );
		PrecachePaint( buffer );
	
		int index = (i - 1) * sizeof( g_cPaintSizes ); // i - 1 because starts from [1], [0] is reserved for random
		
		for( int j = 0; j < sizeof( g_cPaintSizes ); j++ )
		{
			Format( buffer, sizeof( buffer ), "decals/paint/%s%s.vmt", g_cPaintColours[i][1], g_cPaintSizes[j][1] );
			g_Sprites[index + j] = PrecachePaint( buffer );
		}
	}
	
	CreateTimer( 0.1, Timer_Paint, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
}

public Action SM_Paint(int client, int args)
{
	OpenPaintMenu(client);
	return Plugin_Handled;
}


public Action cmd_PaintColour( int client, int args )
{
	/*if( CheckCommandAccess( client, "sm_paint", DEFAULT_FLAG ) )
	{
		PaintMenu(client);
	}
	else
	{
		ReplyToCommand( client, "[SM] You do not have access to this command." );
	}*/
	ColourMenu(client);

	
	return Plugin_Handled;
}

public Action cmd_PaintSize( int client, int args )
{
	/*if( CheckCommandAccess( client, "sm_paint", DEFAULT_FLAG ) )
	{
		SizeMenu(client);
	}
	else
	{
		ReplyToCommand( client, "[SM] You do not have access to this command." );
	}*/
	SizeMenu(client);
	
	
	return Plugin_Handled;
}

public Action Timer_Paint( Handle timer )
{
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame( i ) && IsPlayerAlive( i ) && g_bIsPainting[i] )
		{
			static float pos[3];
			TraceEye( i, pos );
			
			if( GetVectorDistance( pos, g_fLastPaint[i], true ) > PAINT_DISTANCE_SQ )
			{
				AddPaint( pos, g_PlayerPaintColour[i], g_PlayerPaintSize[i] );
				
				g_fLastPaint[i] = pos;
			}
		}
	}
}

void AddPaint( float pos[3], int paint = 0, int size = 0 )
{
	if( paint == 0 )
	{
		paint = GetRandomInt( 1, sizeof( g_cPaintColours ) - 1 );
	}
	
	TE_SetupWorldDecal( pos, g_Sprites[(paint - 1)*sizeof( g_cPaintSizes ) + size] );
	TE_SendToAll();
}

int PrecachePaint( char[] filename )
{
	char tmpPath[PLATFORM_MAX_PATH];
	Format( tmpPath, sizeof( tmpPath ), "materials/%s", filename );
	AddFileToDownloadsTable( tmpPath );
	
	return PrecacheDecal( filename, true );
}

OpenPaintMenu(int client)
{
	char sBuffer[128];
	
	Handle panel = CreatePanel();
	SetPanelTitle(panel, "PaintMenu");
	
	FormatEx(sBuffer, sizeof(sBuffer), "Paint - [%s]", (g_bIsPainting[client]) ? "x" : " ");
	DrawPanelItem(panel, sBuffer);
	
	DrawPanelItem(panel, "PaintColour");
	
	DrawPanelItem(panel, "PaintSize");
	
	DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);
	SendPanelToClient(panel, client, PaintMenu, 0);
	CloseHandle(panel);
}

public PaintMenu(Handle menu, MenuAction:action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 1://Paint
				{
					g_bIsPainting[client] = !g_bIsPainting[client];
					OpenPaintMenu(client);
				}
				case 2://PaintColour
				{
					ColourMenu(client);
				}
				case 3: //PaintSize
				{
					SizeMenu(client);
				}
			}
		}
	}
}


ColourMenu(client)
{
	
	Handle menu = CreateMenu(PaintColourMenuHandle);
	
	SetMenuTitle(menu, "Select Paint Colour:" );
	
	for( int i = 0; i < sizeof( g_cPaintColours ); i++ )
	{
		AddMenuItem(menu, g_cPaintColours[i][0], g_cPaintColours[i][0] );
	}
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

SizeMenu(client)
{
	Handle menu = CreateMenu(PaintSizeMenuHandle);
	
	SetMenuTitle(menu, "Select Paint Size:" );
	
	for( int i = 0; i < sizeof( g_cPaintSizes ); i++ )
	{
		AddMenuItem(menu, g_cPaintSizes[i][0], g_cPaintSizes[i][0] );
	}
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	
}

public int PaintColourMenuHandle( Handle menu, MenuAction:action, int param1, int param2 )
{
	switch(action)
	{
		case MenuAction_Select:
		{
			SetClientPaintColour( param1, param2 );
			ColourMenu(param1);
		}
		case MenuAction_Cancel:
		{
			switch (param2)
			{
				case MenuCancel_ExitBack:
                {
                    OpenPaintMenu(param1);
                    return;
                }
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}

}

public int PaintSizeMenuHandle( Handle menu, MenuAction:action, int param1, int param2 )
{
	switch(action)
	{
		case MenuAction_Select:
		{
			SetClientPaintSize( param1, param2 );
			SizeMenu(param1);
		}
		case MenuAction_Cancel:
		{
			switch (param2)
			{
				case MenuCancel_ExitBack:
                {
                    OpenPaintMenu(param1);
                    return;
                }
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}

}


void SetClientPaintColour( int client, int paint )
{
	char sValue[64];
	g_PlayerPaintColour[client] = paint;
	IntToString( paint, sValue, sizeof( sValue ) );
	SetClientCookie( client, g_hPlayerPaintColour, sValue );
	
	PrintToChat( client, "[SM] Paint colour now: \x10%s", g_cPaintColours[paint][0] );
}

void SetClientPaintSize( int client, int size )
{
	char sValue[64];
	g_PlayerPaintSize[client] = size;
	IntToString( size, sValue, sizeof( sValue ) );
	SetClientCookie( client, g_hPlayerPaintSize, sValue );
	
	PrintToChat( client, "[SM] Paint size now: \x10%s", g_cPaintSizes[size][0] );
}

stock void TE_SetupWorldDecal( const float vecOrigin[3], int index )
{    
    TE_Start( "World Decal" );
    TE_WriteVector( "m_vecOrigin", vecOrigin );
    TE_WriteNum( "m_nIndex", index );
}

stock void TraceEye( int client, float pos[3] )
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition( client, vOrigin );
	GetClientEyeAngles( client, vAngles );
	
	TR_TraceRayFilter( vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer );
	
	if( TR_DidHit() )
		TR_GetEndPosition( pos );
}

public bool TraceEntityFilterPlayer( int entity, int contentsMask )
{
	return ( entity > GetMaxClients() || !entity );
}
