// ----------------------------------------------------------------------------
// 
// IOSFBConnect.cpp
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#include "IOSFBConnect.h"

#include "FBConnectEvent.h"
#include "CoronaAssert.h"
#include "CoronaLua.h"

#import "CoronaLuaIOS.h"
#import "CoronaRuntime.h"

//#import <FacebookSDK/FacebookSDK.h>
#import "Facebook.h"

#import "FBSBJSON.h"

// ----------------------------------------------------------------------------

static const char kFBConnectEventName[] = "fbconnect";

// ----------------------------------------------------------------------------

@interface IOSFBConnectDelegate : NSObject< FBDialogDelegate >
{
	Corona::IOSFBConnect *fOwner;
	FBRequest *fUidRequest;
}

- (id)initWithOwner:(Corona::IOSFBConnect*)owner;

@end


@implementation IOSFBConnectDelegate

- (id)initWithOwner:(Corona::IOSFBConnect*)owner
{
	self = [super init];
	if ( self )
	{
		fOwner = owner;
		fUidRequest = nil;
	}
	return self;
}

// FBDialogDelegate
// ----------------------------------------------------------------------------

- (void)dialogDidComplete:(FBDialog *)dialog
{
}

- (void)dialogCompleteWithUrl:(NSURL *)url
{
	Corona::FBConnectDialogEvent e( [[url absoluteString] UTF8String], false, true );
	fOwner->Dispatch( e );
}

- (void)dialogDidNotCompleteWithUrl:(NSURL *)url
{
	Corona::FBConnectDialogEvent e( [[url absoluteString] UTF8String], false, false );
	fOwner->Dispatch( e );
}

- (void)dialogDidNotComplete:(FBDialog *)dialog
{
}

- (void)dialog:(FBDialog*)dialog didFailWithError:(NSError *)error
{
	Corona::FBConnectDialogEvent e( [[error localizedDescription] UTF8String], true, false );
	fOwner->Dispatch( e );
}

- (BOOL)dialog:(FBDialog*)dialog shouldOpenURLInExternalBrowser:(NSURL *)url
{
	// TODO: Figure out the use case for returning YES.
	return NO;
}

@end

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

FBConnect *
FBConnect::New( lua_State *L )
{
	void *platformContext = CoronaLuaGetContext( L ); // lua_touserdata( L, lua_upvalueindex( 1 ) );
	id<CoronaRuntime> runtime = (id<CoronaRuntime>)platformContext;

	return new IOSFBConnect( runtime );
}

void
FBConnect::Delete( FBConnect *instance )
{
	delete instance;
}

// ----------------------------------------------------------------------------

static NSString *
GetUrlScheme()
{
	NSString *result = nil;

	id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
	if ( [value isKindOfClass:[NSArray class]] )
	{
		NSString *prefix = @"fb";

		for ( id item in value )
		{
			if ( [item isKindOfClass:[NSDictionary class]] )
			{
				NSArray *schemes = [item objectForKey:@"CFBundleURLSchemes"];
				if ( [schemes isKindOfClass:[NSArray class]] )
				{
					for ( id o in schemes )
					{
						if ( [o isKindOfClass:[NSString class]] )
						{
							// TODO: We should use a regular expression of the form: "fb[0-9]+\\w*"
							NSString *str = (NSString*)o;
							if ( [str hasPrefix:prefix] )
							{
								result = str;
								goto exit_gracefully;
							}
						}
					}
				}
			}
		}
	}

exit_gracefully:
	return result;
}

static NSString *
GetAppId( NSString *scheme )
{
	NSString *result = nil;

	if ( scheme )
	{
		NSRegularExpression *regEx = [NSRegularExpression regularExpressionWithPattern:@"fb([0-9]+)\\w*" options:0 error:NULL];
		NSTextCheckingResult *match = [regEx firstMatchInString:scheme options:0 range:NSMakeRange( 0, [scheme length] )];
		NSRange r = [match rangeAtIndex:1]; // want the capture in parens, 0 is index for entire match

		if ( NSNotFound != r.location )
		{
			result = [scheme substringWithRange:r];
		}
	}

	return result;
}

static NSString *
GetUrlSchemeSuffix( NSString *scheme, NSString *appId )
{
	NSString *prefix = [NSString stringWithFormat:@"fb%@", appId];

	// We only want the suffix
	NSString *result = nil;
	if ( [scheme length] > [prefix length] )
	{
		result = [scheme substringFromIndex:[prefix length]];
	}
	return result;
}

// ----------------------------------------------------------------------------

IOSFBConnect::IOSFBConnect( id< CoronaRuntime > runtime )
:	Super(),
	fRuntime( runtime ),
	fSession( nil ),
	fFacebook( nil ),
	fFacebookDelegate( [[IOSFBConnectDelegate alloc] initWithOwner:this] )
{
}

IOSFBConnect::~IOSFBConnect()
{
	[fFacebookDelegate release];
	[fFacebook release];
}

bool
IOSFBConnect::Initialize( NSString *appId )
{
	if ( nil == fSession )
	{
		fSession = FBSession.activeSession;
	}

	return ( nil != fSession );
/*
	NSString *scheme = GetUrlScheme();
	NSString *message = nil;

///	if ( ! fFacebook )
	{
		if ( ! appId )
		{
			appId = GetAppId( scheme );
		}

		if ( CORONA_VERIFY( appId ) )
		{
			NSString *urlSchemeSuffix = GetUrlSchemeSuffix( scheme, appId );

			if ( urlSchemeSuffix )
			{
				fFacebook = [[Facebook alloc] initWithAppId:appId urlSchemeSuffix:urlSchemeSuffix andDelegate:fDelegate];
			}
			else
			{
				fFacebook = [[Facebook alloc] initWithAppId:appId andDelegate:fDelegate];
			}

			fAppId = [appId copy];

			fFacebook.sessionDelegate = fDelegate;
		}
		else
		{
			message = [NSString stringWithFormat:@"Facebook could not be initialized. No valid appId was found."];
		}
	}
	else if ( appId )
	{
		if ( ! Rtt_VERIFY( [appId isEqualToString:fAppId] ) )
		{
			scheme = ( scheme ? scheme : @"" );
			message = [NSString stringWithFormat:@"Facebook appId(%@) does not match the URL scheme in Info.plist(%@)", appId, scheme];
		}
	}

	if ( message )
	{
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
							message:message
							delegate:nil
							cancelButtonTitle:@"OK"
							otherButtonTitles:nil];
		[alertView show];
		[alertView autorelease];
	}
	else
	{
///		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
///		if ( [defaults objectForKey:@"FBAccessTokenKey"]
///			 && [defaults objectForKey:@"FBExpirationDateKey"] )
///		{
///			fFacebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
///			fFacebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
///		}
	}

	return ( nil != fFacebook );
*/
}

void
IOSFBConnect::SessionChanged( FBSession *session, int state, NSError *error ) const
{
	switch ( (FBSessionState)state )
	{
		case FBSessionStateOpen:
		{
			const_cast< Self * >( this )->Initialize( session.appID );

			// Handle the logged in scenario
			// You may wish to show a logged in view
			NSString *token = session.accessToken;
			NSDate *expiration = session.expirationDate;
			FBConnectSessionEvent e( [token UTF8String], [expiration timeIntervalSince1970] );
			Dispatch( e );
			break;
		}

		case FBSessionStateClosed:
		{
			FBConnectSessionEvent e( FBConnectSessionEvent::kLogout, NULL );
			Dispatch( e );
			[session closeAndClearTokenInformation];
			break;
		}

		case FBSessionStateClosedLoginFailed:
		{
			FBConnectSessionEvent e( FBConnectSessionEvent::kLoginFailed, [[error localizedDescription] UTF8String] );
			Dispatch( e );
			[session closeAndClearTokenInformation];
			break;
		}

		default:
		{
			break;
		}
	}

	if (error)
	{
		// Handle authentication errors
	}
}

void
IOSFBConnect::ReauthorizationCompleted( FBSession *session, NSError *error ) const
{
	// TODO: We need a new event type ("permission") that lets them know
	// if they succeeded to get the permission.
	// SessionChanged( fSession, ( error ? FBSessionStateClosedLoginFailed : FBSessionStateOpen ), error );
}

void
IOSFBConnect::Dispatch( const FBConnectEvent& e ) const
{
	e.Dispatch( fRuntime.L, GetListener() );
}

bool
IOSFBConnect::Open( const char *url ) const
{
	bool result = false;

	NSString *s = [NSString stringWithUTF8String:url];
	if ( [s hasPrefix:@"fb"] )
	{
		NSString *regEx = @"fb([0-9]+)";
		NSRange r = [s rangeOfString:regEx options:NSRegularExpressionSearch];

		if ( NSNotFound != r.location )
		{
			if ( const_cast< Self * >( this )->Initialize( nil ) )
			{
				NSURL *nsUrl = [NSURL URLWithString:s];
				result = [fSession handleOpenURL:nsUrl];
			}
		}
	}

	return result;
}

void
IOSFBConnect::Resume() const
{
	[FBSession.activeSession handleDidBecomeActive];
}

void
IOSFBConnect::Close() const
{
	[FBSession.activeSession close];
}

void
IOSFBConnect::Login( const char *appId, const char *permissions[], int numPermissions ) const
{
	NSMutableArray *permissionsValue = nil;
	if ( numPermissions )
	{
		permissionsValue = [NSMutableArray arrayWithCapacity:numPermissions];
		for ( int i = 0; i < numPermissions; i++ )
		{
			NSString *str = [[NSString alloc] initWithUTF8String:permissions[i]];
			[permissionsValue addObject:str];
			[str release];
		}
	}

	if ( ! fSession )
	{
		// Callback wrapper
		FBSessionStateHandler handler = ^( FBSession *session, FBSessionState state, NSError *error )
		{
			SessionChanged( session, state, error );
		};

		[FBSession openActiveSessionWithPermissions:permissionsValue
			allowLoginUI:YES
			completionHandler:handler];
	}
	else
	{
		if ( numPermissions > 0 )
		{
			FBSessionReauthorizeResultHandler handler = ^( FBSession *session, NSError *error )
			{
				ReauthorizationCompleted( session, error );
			};

			// TODO: We need to a new API to deal with permissions correctly,
			// e.g. separating read from publish. For now, we stick to the old workflow.
			@try {
				// [fSession reauthorizeWithReadPermissions:permissionsValue completionHandler:handler];
				[fSession reauthorizeWithPermissions:permissionsValue behavior:FBSessionLoginBehaviorUseSystemAccountIfPresent completionHandler:handler];
			}
			@catch (NSException *exception) {
				// NSLog( @"%@", exception );
			}
		}

		// Send a login event
		SessionChanged( fSession, FBSessionStateOpen, nil );
	}
}

void
IOSFBConnect::Logout() const
{
	[fSession close];
	fSession = nil;

	[fFacebook autorelease]; // TODO: Figure out better fix for the KVC error msg. Right now we "defer" release via autorelease.
	fFacebook = nil;
}

void
IOSFBConnect::Request( lua_State *L, const char *path, const char *httpMethod, int index ) const
{
	if ( fSession.isOpen )
	{
		// Convert common params
		NSString *pathString = [NSString stringWithUTF8String:path];
		NSString *httpMethodString = [NSString stringWithUTF8String:httpMethod];

		NSDictionary *params = nil;
		if ( LUA_TTABLE == lua_type( L, index ) )
		{
			params = CoronaLuaCreateDictionary( L, index );
		}
		else
		{
			params = [NSDictionary dictionary];
		}

		FBRequestHandler handler = ^( FBRequestConnection *connection, id result, NSError *error )
		{
			if ( ! error )
			{
				FBSBJSON *converter = [[[FBSBJSON alloc] init] autorelease];
				NSString *jsonString = [converter stringWithObject:result];
				FBConnectRequestEvent e( [jsonString UTF8String], false );
				Dispatch( e );
			}
			else
			{
				FBConnectRequestEvent e( [[error localizedDescription] UTF8String], true );
				Dispatch( e );
			}
		};

		FBRequestConnection *connection = [FBRequestConnection startWithGraphPath:pathString parameters:params HTTPMethod:httpMethodString completionHandler:handler];
	}
}

void
IOSFBConnect::ShowDialog( lua_State *L, int index ) const
{
	if ( ! fSession )
	{
		CORONA_LOG_WARNING( "facebook.showDialog() requires a valid session. Make sure to call facebook.login() first." );
		return;
	}

	if ( ! fFacebook )
	{
		fFacebook = [[Facebook alloc] initWithAppId:fSession.appID andDelegate:nil];
		fFacebook.accessToken = fSession.accessToken;
		fFacebook.expirationDate = fSession.expirationDate;
	}

	NSString *action = nil;
	NSDictionary *dict = nil;

	if ( lua_isstring( L, 1 ) )
	{
		// New API
		const char *str = lua_tostring( L, 1 );
		if ( LUA_TSTRING == lua_type( L, 1 ) && str )
		{
			action = [NSString stringWithUTF8String:str];
		}

		if ( LUA_TTABLE == lua_type( L, 2 ) )
		{
			dict = CoronaLuaCreateDictionary( L, 2 );
		}
	}
	else if ( lua_istable( L, 1 ) )
	{
		// Old API
		CORONA_LOG_WARNING( "facebook.showDialog( { action= } ) has been deprecated in favor of facebook.showDialog( action [, params] )" );

		// Convert common params
		lua_getfield( L, index, "action" );
		const char *str = lua_tostring( L, -1 );
		if ( LUA_TSTRING == lua_type( L, -1 ) && str )
		{
			action = [NSString stringWithUTF8String:str];
		}
		lua_pop( L, 1 );

		lua_getfield( L, index, "params" );
		if ( LUA_TTABLE == lua_type( L, -1 ) )
		{
			int t = lua_gettop( L ); // get index of table

			dict = CoronaLuaCreateDictionary( L, t );
		}
		lua_pop( L, 1 );
	}
	else
	{
		CORONA_LOG_WARNING( "Invalid parameters passed to facebook.showDialog( action [, params] )" );
	}
	
	if ( CORONA_VERIFY( action ) )
	{
		if ( dict )
		{
			NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:dict];
			[fFacebook dialog:action andParams:params andDelegate:fFacebookDelegate];
		}
		else
		{
			[fFacebook dialog:action andDelegate:fFacebookDelegate];
		}

	}
}

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

