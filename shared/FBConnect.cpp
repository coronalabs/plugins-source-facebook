// ----------------------------------------------------------------------------
// 
// FBConnect.cpp
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#include "FBConnect.h"
#include "FBConnectEvent.h"

#include "CoronaAssert.h"
#include "CoronaEvent.h"
#include "CoronaLog.h"
#include "CoronaLua.h"

#include <string.h>

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

int
FBConnect::SystemEventListener( lua_State *L )
{
	Self *connect = (Self *)lua_touserdata( L, lua_upvalueindex( 1 ) );
	
	if ( lua_istable( L, 1 ) )
	{
		lua_getfield( L, 1, CoronaEventTypeKey() );
		const char *eventType = lua_tostring( L, -1 );

		if ( eventType )
		{
			if ( 0 == strcmp( eventType, "applicationOpen" ) )
			{
				lua_getfield( L, 1, "url" );
				const char *url = lua_tostring( L, -1 );
				connect->Open( url );
				lua_pop( L, 1 );
			}
			else if ( 0 == strcmp( eventType, "applicationResume" ) )
			{
				connect->Resume();
			}
			else if ( 0 == strcmp( eventType, "applicationExit" ) )
			{
				connect->Close();
			}
		}

		lua_pop( L, 1 );
	}

	return 0;
}

// ----------------------------------------------------------------------------

FBConnect::FBConnect( )
:	fListener( NULL )
{
}

FBConnect::~FBConnect()
{
	CORONA_ASSERT( NULL == fListener );
}

bool
FBConnect::Initialize( lua_State *L, int listenerIndex )
{
	bool result = false;

	if ( NULL == fListener
		 && FBConnectEvent::IsListener( L, listenerIndex ) )
	{
		fListener = CoronaLuaNewRef( L, listenerIndex );
		result = true;
	}

	return result;
}

void
FBConnect::Finalize( lua_State *L )
{
	CoronaLuaDeleteRef( L, fListener );
	fListener = NULL;
}

bool
FBConnect::Open( const char *url ) const
{
	return false;
}

void
FBConnect::Resume() const
{
}

void
FBConnect::Close() const
{
}

/*
void
FBConnect::Login( const char *appId, const char *permissions[], int numPermissions ) const
{
	CORONA_LOG_WARNING( "facebook.login() is not supported on this platform." );
}

void
FBConnect::Logout() const
{
	CORONA_LOG_WARNING( "facebook.logout() is not supported on this platform." );
}

void
FBConnect::Request( lua_State *L, const char *path, const char *httpMethod, int index ) const
{
	CORONA_LOG_WARNING( "facebook.request() is not supported on this platform." );
}

void
FBConnect::ShowDialog( lua_State *L, int index ) const
{
	CORONA_LOG_WARNING( "facebook.showDialog() is not supported on this platform." );
}
*/

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

