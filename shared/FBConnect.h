// ----------------------------------------------------------------------------
// 
// FBConnect.h
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#ifndef _FBConnect_H__
#define _FBConnect_H__

#include "CoronaLua.h"

// ----------------------------------------------------------------------------

struct lua_State;

namespace Corona
{

// ----------------------------------------------------------------------------

class FBConnect
{
	public:
		typedef FBConnect Self;

	public:
		// Implement this per-platform
		static FBConnect *New( lua_State *L );
		static void Delete( FBConnect *instance );

	public:
		static int SystemEventListener( lua_State *L );

	protected:
		FBConnect();
		virtual ~FBConnect();

	public:
		bool Initialize( lua_State *L, int listenerIndex );
		void Finalize( lua_State *L );

	protected:
		CoronaLuaRef GetListener() const { return fListener; }

	public:
		virtual bool Open( const char *url ) const;
		virtual void Resume() const;
		virtual void Close() const;

	public:
		virtual void Login( const char *appId, const char *permissions[], int numPermissions ) const = 0;
		virtual void Logout() const = 0;
		virtual void Request( lua_State *L, const char *path, const char *httpMethod, int x ) const = 0;
		virtual void ShowDialog( lua_State *L, int index ) const = 0;

	private:
		CoronaLuaRef fListener;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

#endif // _FBConnect_H__
