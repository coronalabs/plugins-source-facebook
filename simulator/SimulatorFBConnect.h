// ----------------------------------------------------------------------------
// 
// SimulatorFBConnect.h
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#ifndef _SimulatorFBConnect_H__
#define _SimulatorFBConnect_H__

#include "FBConnect.h"

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

class SimulatorFBConnect : public FBConnect
{
	public:
		typedef FBConnect Super;
		typedef SimulatorFBConnect Self;

	public:
		virtual void Login( const char *appId, const char *permissions[], int numPermissions ) const;
		virtual void Logout() const;
		virtual void Request( lua_State *L, const char *path, const char *httpMethod, int x ) const;
		virtual void ShowDialog( lua_State *L, int index ) const;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

#endif // _SimulatorFBConnect_H__
