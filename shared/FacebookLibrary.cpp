// ----------------------------------------------------------------------------
// 
// FacebookLibrary.cpp
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// ----------------------------------------------------------------------------

#include "FacebookLibrary.h"

#include "CoronaLibrary.h"
#include "CoronaLua.h"
#include "FBConnect.h"
#include "FBConnectEvent.h"
#include <string.h>
#include <stdlib.h>

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

class FacebookLibrary
{
	public:
		typedef FacebookLibrary Self;

	public:
		static const char kName[];
		static const char kEvent[];

	protected:
		FacebookLibrary( lua_State *L );
		~FacebookLibrary();

	public:
		FBConnect *GetFBConnect() { return fFBConnect; }
		const FBConnect *GetFBConnect() const { return fFBConnect; }

	public:
		static int Open( lua_State *L );

	protected:
		static int Initialize( lua_State *L );
		static int Finalizer( lua_State *L );

	public:
		static Self *ToLibrary( lua_State *L );

	public:
		static int login( lua_State *L );
		static int logout( lua_State *L );
		static int request( lua_State *L );
		static int showDialog( lua_State *L );
		static int show( lua_State *L );
        static int publishInstall( lua_State *L );

	private:
		static int ValueForKey( lua_State *L );
		FBConnect *fFBConnect;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------




// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
const char FacebookLibrary::kName[] = "facebook";

// This corresponds to the event name, e.g. [Lua] event.name
const char FacebookLibrary::kEvent[] = "fbconnect";

FacebookLibrary::FacebookLibrary( lua_State *L )
:	fFBConnect( FBConnect::New( L ) )
{
}

FacebookLibrary::~FacebookLibrary()
{
	FBConnect::Delete( fFBConnect );
}
	
int
FacebookLibrary::ValueForKey( lua_State *L )
{
	int result = 1;

	Self *library = ToLibrary( L );
	const char *key = luaL_checkstring( L, 2 );
	
	if ( 0 == strcmp( "accessDenied", key ) )
	{
		lua_pushboolean( L, library->GetFBConnect()->IsAccessDenied() );
	}
	else
	{
		result = 0;
	}
	
	return result;
}

int
FacebookLibrary::Open( lua_State *L )
{
	// Register __gc callback
	const char kMetatableName[] = __FILE__; // Globally unique string to prevent collision
	CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );

	// Functions in library
	const luaL_Reg kVTable[] =
	{
		{ "login", login },
		{ "logout", logout },
		{ "request", request },
		{ "showDialog", showDialog },
        { "publishInstall", publishInstall },

		{ NULL, NULL }
	};

	// Set library as upvalue for each library function
	Self *library = new Self( L );

	// Store the library singleton in the registry so it persists
	// using kMetatableName as the unique key.
	CoronaLuaPushUserdata( L, library, kMetatableName );
	lua_pushstring( L, kMetatableName );
	lua_settable( L, LUA_REGISTRYINDEX );

	// Does the equivalent of the following Lua code:
	//   Runtime:addEventListener( "system", ProcessSystemEvent )
	// which is equivalent to:
	//   local f = Runtime.addEventListener
	//   f( Runtime, "system", ProcessSystemEvent )
	CoronaLuaPushRuntime( L ); // push 'Runtime'
	lua_getfield( L, -1, "addEventListener" ); // push 'f', i.e. Runtime.addEventListener
	lua_insert( L, -2 ); // swap so 'f' is below 'Runtime'
	lua_pushstring( L, "system" );

	// Push SystemEventListener as closure so it has access to 'fFBConnect'
	lua_pushlightuserdata( L, library->GetFBConnect() ); // Assumes fFBConnect lives for lifetime of plugin
	lua_pushcclosure( L, & FBConnect::SystemEventListener, 1 );

	// Lua stack order (from lowest index to highest):
	// f
	// Runtime
	// "system"
	// ProcessSystemEvent (closure)
	CoronaLuaDoCall( L, 3, 0 );
	CoronaLuaPushRuntime( L );
	lua_getfield( L, -1, "addEventListener" );
	

	// Leave "library" on top of stack
	// Set library as upvalue for each library function
	int result = CoronaLibraryNew( L, kName, "com.coronalabs", 1, 1, kVTable, library );
	{
		lua_pushlightuserdata( L, library );
		lua_pushcclosure( L, ValueForKey, 1 ); // pop ud
		CoronaLibrarySetExtension( L, -2 ); // pop closure
	}
	
	return result;
}

int
FacebookLibrary::Finalizer( lua_State *L )
{
	Self *library = (Self *)CoronaLuaToUserdata( L, 1 );

	library->GetFBConnect()->Finalize( L );

	delete library;

	return 0;
}

FacebookLibrary *
FacebookLibrary::ToLibrary( lua_State *L )
{
	// library is pushed as part of the closure
	Self *library = (Self *)lua_touserdata( L, lua_upvalueindex( 1 ) );
	return library;
}

// [Lua] facebook.login( appId, listener [, permissions] )
int
FacebookLibrary::login( lua_State *L )
{
	if ( LUA_TSTRING == lua_type( L, 1 ) )
	{
		const char *appId = lua_tostring( L, 1 );

		const char **permissions = NULL;
		int numPermissions = 0;
		if ( lua_istable( L, 3 ) )
		{
			numPermissions = lua_objlen( L, 3 );
			permissions = (const char **)malloc( sizeof( char*) * numPermissions );

			for ( int i = 0; i < numPermissions; i++ )
			{
				// Lua arrays are 1-based, so add 1 to index passed to lua_rawgeti()
				lua_rawgeti( L, 3, i + 1 ); // push permissions[i]

// TODO: This is broken. Cannot store pointer to value that will be popped???
				const char *value = lua_tostring( L, -1 );
				permissions[i] = value;
				lua_pop( L, 1 );
			}
		}

		if ( appId )
		{
			Self *library = ToLibrary( L );
			FBConnect *connect = library->GetFBConnect();
			if ( FBConnectEvent::IsListener( L, 2 ) )
			{
				connect->SetListener( L, 2 );
				connect->Login( appId, permissions, numPermissions );
			}
			else
			{
				CORONA_LOG_ERROR( "Second argument to facebook.login() should be an 'fbconnect' listener." );
			}
		}

		if ( permissions )
		{
			free( permissions );
		}
	}
	else
	{
		CORONA_LOG_ERROR( "First argument to facebook.login() should be a string." );
	}

	return 0;
}

// [Lua] facebook.logout()
int
FacebookLibrary::logout( lua_State *L )
{
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();

	connect->Logout();

	return 0;
}

// [Lua] facebook.request( path [, httpMethod, params] )
int
FacebookLibrary::request( lua_State *L )
{
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();

	const char *path = luaL_checkstring( L, 1 );
	const char *httpMethod = ( lua_isstring( L, 2 ) ? lua_tostring( L, 2 ) : "GET" );
	connect->Request( L, path, httpMethod, 3 );

	return 0;
}

// [Lua] facebook.showDialog( action [, params] )
int
FacebookLibrary::showDialog( lua_State *L )
{
	Self *library = ToLibrary( L );
	FBConnect *connect = library->GetFBConnect();

	connect->ShowDialog( L, 1 );

	return 0;
}

int
FacebookLibrary::publishInstall( lua_State *L )
{
    if ( LUA_TSTRING == lua_type( L, 1 ) )
	{
		const char *appId = lua_tostring( L, 1 );
        
		if ( appId )
		{
			Self *library = ToLibrary( L );
			FBConnect *connect = library->GetFBConnect();
			
			connect->PublishInstall( appId );
		}
	}
	else
	{
		CORONA_LOG_ERROR( "First argument to facebook.publishInstall() should be a string." );
	}
    
    return 0;
}
    
// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_facebook( lua_State *L )
{
	return Corona::FacebookLibrary::Open( L );
}
