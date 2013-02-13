// ----------------------------------------------------------------------------
// 
// SimulatorFBConnect.cpp
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#include "SimulatorFBConnect.h"

#include "CoronaLog.h"

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

FBConnect *
FBConnect::New( lua_State *L )
{
	return new SimulatorFBConnect;
}

void
FBConnect::Delete( FBConnect *instance )
{
	delete instance;
}

// ----------------------------------------------------------------------------

void
SimulatorFBConnect::Login( const char *appId, const char *permissions[], int numPermissions ) const
{
	CORONA_LOG_WARNING( "facebook.login() is not supported on the simulator." );
}

void
SimulatorFBConnect::Logout() const
{
	CORONA_LOG_WARNING( "facebook.logout() is not supported on the simulator." );
}

void
SimulatorFBConnect::Request( lua_State *L, const char *path, const char *httpMethod, int index ) const
{
	CORONA_LOG_WARNING( "facebook.request() is not supported on the simulator." );
}

void
SimulatorFBConnect::ShowDialog( lua_State *L, int index ) const
{
	CORONA_LOG_WARNING( "facebook.showDialog() is not supported on the simulator." );
}


// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

