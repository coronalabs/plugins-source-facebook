// ----------------------------------------------------------------------------
// 
// FBConnectEvent.cpp
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

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

const char FBConnectEvent::kName[] = "fbconnect";

// ----------------------------------------------------------------------------

const char *
FBConnectEvent::StringForType( Type t )
{
	const char *result = NULL;
	static const char kSessionString[] = "session";
	static const char kRequestString[] = "request";
	static const char kDialogString[] = "dialog";

	switch( t )
	{
		case kSessionType:
			result = kSessionString;
			break;
		case kRequestType:
			result = kRequestString;
			break;
		case kDialogType:
			result = kDialogString;
			break;
		default:
			CORONA_ASSERT_NOT_REACHED();
			break;
	}

	return result;
}

bool
FBConnectEvent::IsListener( lua_State *L, int listenerIndex )
{
	return CoronaLuaIsListener( L, listenerIndex, kName );
}

FBConnectEvent::FBConnectEvent( Type t )
:	fResponse( NULL ),
	fType( t ),
	fIsError( false )
{
}

FBConnectEvent::FBConnectEvent( Type t, const char *response, bool isError )
:	fResponse( response ),
	fType( t ),
	fIsError( isError )
{
}

void
FBConnectEvent::Dispatch( lua_State *L, CoronaLuaRef listener ) const
{
	if ( CORONA_VERIFY( listener ) )
	{
		Push( L );
		CoronaLuaDispatchEvent( L, listener, 0 );
	}
}

void
FBConnectEvent::Push( lua_State *L ) const
{
	CoronaLuaNewEvent( L, kName ); CORONA_ASSERT( lua_istable( L, -1 ) );

	const char *message = fResponse ? fResponse : "";
	lua_pushstring( L, message );
	lua_setfield( L, -2, CoronaEventResponseKey() );

	const char *value = StringForType( (Type)fType ); CORONA_ASSERT( value );
	lua_pushstring( L, value );
	lua_setfield( L, -2, CoronaEventTypeKey() );

	lua_pushboolean( L, fIsError );
	lua_setfield( L, -2, CoronaEventIsErrorKey() );
}

// ----------------------------------------------------------------------------

const char *
FBConnectSessionEvent::StringForPhase( Phase phase )
{
	const char *result = NULL;
	static const char kLoginString[] = "login";
	static const char kLoginFailedString[] = "loginFailed";
	static const char kLoginCancelledString[] = "loginCancelled";
	static const char kLogoutString[] = "logout";

	switch( phase )
	{
		case kLogin:
			result = kLoginString;
			break;
		case kLoginFailed:
			result = kLoginFailedString;
			break;
		case kLoginCancelled:
			result = kLoginCancelledString;
			break;
		case kLogout:
			result = kLogoutString;
			break;
		default:
			CORONA_ASSERT_NOT_REACHED();
			break;
	}

	return result;
}

FBConnectSessionEvent::FBConnectSessionEvent( const char *token, time_t tokenExpiration )
:	Super( Super::kSessionType ),
	fPhase( kLogin ),
	fToken( token ),
	fTokenExpiration( tokenExpiration )
{
}

FBConnectSessionEvent::FBConnectSessionEvent( Phase phase, const char *errorMsg )
:	Super( Super::kSessionType, errorMsg, ( NULL != errorMsg ) ),
	fPhase( phase ),
	fToken( NULL ),
	fTokenExpiration( 0 )
{
}

void
FBConnectSessionEvent::Push( lua_State *L ) const
{
	Super::Push( L ); CORONA_ASSERT( lua_istable( L, -1 ) );

	const char *value = StringForPhase( (Phase)fPhase ); CORONA_ASSERT( value );
	lua_pushstring( L, value );
	lua_setfield( L, -2, CoronaEventPhaseKey() );

	if ( fToken )
	{
		CORONA_ASSERT( kLogin == fPhase );
		lua_pushstring( L, fToken );
		lua_setfield( L, -2, "token" );

		lua_pushnumber( L, fTokenExpiration );
		lua_setfield( L, -2, "expiration" );
	}
}

// ----------------------------------------------------------------------------

FBConnectRequestEvent::FBConnectRequestEvent( const char *response, bool isError )
:	Super( Super::kRequestType, response, isError )
{
}

// ----------------------------------------------------------------------------

FBConnectDialogEvent::FBConnectDialogEvent( const char *response, bool isError, bool didComplete )
:	Super( Super::kDialogType, response, isError ),
	fDidComplete( didComplete )
{
}

void
FBConnectDialogEvent::Push( lua_State *L ) const
{
	Super::Push( L ); CORONA_ASSERT( lua_istable( L, -1 ) );

	lua_pushboolean( L, fDidComplete );
	lua_setfield( L, -2, "didComplete" );
}

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

