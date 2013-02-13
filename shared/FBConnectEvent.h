// ----------------------------------------------------------------------------
// 
// FBConnectEvent.h
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#ifndef _FBConnectEvent_H__
#define _FBConnectEvent_H__

#include "CoronaLua.h"

#include <sys/types.h>

// ----------------------------------------------------------------------------

struct lua_State;

namespace Corona
{

// ----------------------------------------------------------------------------

class FBConnectEvent
{
	public:
		typedef FBConnectEvent Self;

	public:
		static const char kName[];
		static bool IsListener( lua_State *L, int listenerIndex );

	public:
		typedef enum Type
		{
			kSessionType = 0,
			kRequestType,
			kDialogType,

			kNumTypes
		}
		Type;

		static const char *StringForType( Type t );

	protected:
		FBConnectEvent( Type t );
		FBConnectEvent( Type t, const char *response, bool isError );

	public:
		void Dispatch( lua_State *L, CoronaLuaRef listener ) const;

	protected:
		virtual void Push( lua_State *L ) const;

	private:
		const char *fResponse;
		int fType;
		bool fIsError;
};

class FBConnectSessionEvent : public FBConnectEvent
{
	public:
		typedef FBConnectEvent Super;

	public:
		typedef enum Phase
		{
			kLogin = 0,
			kLoginFailed,
			kLoginCancelled,
			kLogout,

			kNumPhases
		}
		Phase;

		static const char *StringForPhase( Phase phase );

	public:
		FBConnectSessionEvent( const char *token, time_t tokenExpiration ); // For kLogin phase (token should be available on successful login)
		FBConnectSessionEvent( Phase phase, const char *errorMsg );

	protected:
		virtual void Push( lua_State *L ) const;

	private:
		int fPhase;
		const char *fToken;
		time_t fTokenExpiration; // UNIX timestamp in seconds
};

class FBConnectRequestEvent : public FBConnectEvent
{
	public:
		typedef FBConnectEvent Super;

	public:
		FBConnectRequestEvent( const char *response, bool isError );
};

class FBConnectDialogEvent : public FBConnectEvent
{
	public:
		typedef FBConnectEvent Super;

	public:
		FBConnectDialogEvent( const char *response, bool isError, bool didComplete );

	protected:
		virtual void Push( lua_State *L ) const;

	private:
		bool fDidComplete;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

#endif // _FBConnectEvent_H__
