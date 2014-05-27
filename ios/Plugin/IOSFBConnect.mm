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
#include "CoronaVersion.h"

#import "CoronaLuaIOS.h"
#import "CoronaRuntime.h"

//#import <FacebookSDK/FacebookSDK.h>
#import "Facebook.h"
#import <Accounts/ACAccountStore.h>
#import <Accounts/ACAccountType.h>

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

#ifdef DEBUG_FACEBOOK_ENDPOINT

@interface IOSFBConnectConnectionDelegate : NSObject
{
	NSMutableData *fData;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError*)error;

@end

@implementation IOSFBConnectConnectionDelegate

- (id)init
{
	self = [super init];

	if ( self )
	{
		fData = [[NSMutableData alloc] init];
	}

	return self;
}

- (void)dealloc
{
	[fData release];
	[super dealloc];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	// This method is called incrementally as the server sends data; we must concatenate the data to assemble the response

	[fData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSMutableData *data = fData;
	NSString *filePath = NSTemporaryDirectory();

	// In the original test response, FB's server replied with a 1 pixel image (gif?)
	filePath = [filePath stringByAppendingPathComponent:@"a.gif"];

	if ( filePath )
	{
		[data writeToFile:filePath atomically:YES];
		NSLog( @"Outputing response to: %@.", filePath );
	}
}

- (void)connection:(NSURLConnection *)connection dispatchError:(NSString *)s
{
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response 
{
	// It can be called multiple times, for example in the case of a
	// redirect, so each time we reset the data.
	[fData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error 
{
	NSString *s = [error localizedDescription];
	[self connection:connection dispatchError:s];
}

@end

#endif // DEBUG_FACEBOOK_ENDPOINT

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
	fFacebookDelegate( [[IOSFBConnectDelegate alloc] initWithOwner:this] ),
	fHasObserver( false ),
#ifdef DEBUG_FACEBOOK_ENDPOINT
	fConnectionDelegate( [[IOSFBConnectConnectionDelegate alloc] init] )
#else
	fConnectionDelegate( nil )
#endif
{
}

IOSFBConnect::~IOSFBConnect()
{
	[fConnectionDelegate release];
	[fFacebookDelegate release];
	[fFacebook release];
}

bool
IOSFBConnect::Initialize( NSString *appId )
{
	fSession = FBSession.activeSession;
	
	if ( fSession.appID )
	{
		// Facebook wants us to add a POST so they can track which FB-enabled
		// apps use Corona:
		//	
		//	HTTP POST to:
		//	https://www.facebook.com/impression.php
		//	Parameters:
		//	plugin = "featured_resources"
		//	payload = <JSON_ENCODED_DATA>
		//
		//	JSON_ENCODED_DATA
		//	resource "coronalabs_coronasdk"
		//	appid (Facebook app ID)
		//	version (This is whatever versioning string you attribute to your resource.)
		//
		CORONA_ASSERT( nil == appId || [appId isEqualToString:fSession.appID] );

		NSString *format = @"{\"version\":\"%@\",\"resource\":\"coronalabs_coronasdk\",\"appid\":\"%@\"}";
		NSString *version = [NSString stringWithUTF8String:CoronaVersionBuildString()];
		NSString *json = [NSString stringWithFormat:format, version, fSession.appID];
		NSString *post = [NSString stringWithFormat:@"plugin=featured_resources&payload=%@", json];
		NSString *postEscaped = [post stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSData *postData = [postEscaped dataUsingEncoding:NSUTF8StringEncoding];

		NSString *postLength = [NSString stringWithFormat:@"%ld", [postData length]];

		NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] init] autorelease];
		NSURL *url = [NSURL URLWithString:@"https://www.facebook.com/impression.php"];
		[request setURL:url];
		[request setHTTPMethod:@"POST"];
		[request setValue:postLength forHTTPHeaderField:@"Content-Length"];
		[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
		[request setTimeoutInterval:30];
		[request setHTTPBody:postData];

		NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:fConnectionDelegate];
		[connection start];
		[connection autorelease];
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
	fSession = session;
	switch ( (FBSessionState)state )
	{
		case FBSessionStateOpen:
		case FBSessionStateOpenTokenExtended:
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
			break;
		}
			
		case FBSessionStateClosedLoginFailed:
		{
			FBConnectSessionEvent e( FBConnectSessionEvent::kLoginFailed, [[error localizedDescription] UTF8String] );
			Dispatch( e );
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
	SessionChanged( fSession, ( error ? FBSessionStateClosedLoginFailed : FBSessionStateOpen ), error );
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
	try {
		[FBSession.activeSession handleDidBecomeActive];
	} catch (NSException *e) {
		NSLog(@"%@", e.reason);
	}
}

void
IOSFBConnect::Close() const
{
	[FBSession.activeSession close];
}
	
bool
IOSFBConnect::IsAccessDenied() const
{
	// The constant was introduced in iOS 6 and there is not such setting on iOS 5.
	if ( &ACAccountTypeIdentifierFacebook == NULL )
	{
		return false;
	}
	
	ACAccountStore *accountStore = [[ACAccountStore alloc] init];
	ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
	[accountStore release];
	return !accountType.accessGranted;
}

void
IOSFBConnect::Login( const char *appId, const char *permissions[], int numPermissions ) const
{
	// The read and publish permissions should be requested seperately
	NSMutableArray *readPermissions = nil;
	NSMutableArray *publishPermissions = nil;
	if ( numPermissions )
	{
		readPermissions = [NSMutableArray arrayWithCapacity:numPermissions];
		publishPermissions = [NSMutableArray arrayWithCapacity:numPermissions];
		for ( int i = 0; i < numPermissions; i++ )
		{
			NSString *str = [[NSString alloc] initWithUTF8String:permissions[i]];
			// Don't request the permission again if the session already has it
			if ( fSession && ![fSession.permissions containsObject:str])
			{
				// This might need to change if the sdk is upgraded
				if ( IsPublishPermission(str) )
				{
					[publishPermissions addObject:str];
				}
				else
				{
					[readPermissions addObject:str];
				}
			}
			
			[str release];
		}
	}
	
	if ( ! fSession || ([fSession state] != FBSessionStateOpen && [fSession state] != FBSessionStateOpenTokenExtended) )
	{
		// Callback wrapper
		FBSessionReauthorizeResultHandler handler = ^( FBSession *session, NSError *error )
		{
			SessionChanged(session, [FBSession.activeSession state], error);
		};
		
		// Prevent adding 2 observers which will cause 2 callbacks to happen
		if ( !fHasObserver )
		{
			// This will be called when the session is opened
			NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
			
			[notificationCenter addObserverForName:FBSessionDidBecomeOpenActiveSessionNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
				if ( publishPermissions && publishPermissions.count > 0 )
				{
					// After this is done, it will call back to the lua side with a session changed event
					[FBSession.activeSession reauthorizeWithPublishPermissions:publishPermissions defaultAudience:FBSessionDefaultAudienceEveryone completionHandler:handler];
				}
				else
				{
					SessionChanged(FBSession.activeSession, [FBSession.activeSession state], nil);
				}
			}];
			fHasObserver = true;
		}
		
		
		[FBSession openActiveSessionWithReadPermissions:readPermissions allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
			if ( error )
			{
				SessionChanged(session, [FBSession.activeSession state], error);
			}
		}];
	}
	else
	{
		if ( numPermissions > 0 )
		{
			FBSessionReauthorizeResultHandler publishHandler = ^( FBSession *publishSession, NSError *publishError )
			{
				bool release = false;
				if ( !publishError )
				{
					for ( int i = 0; i < [publishPermissions count]; i++)
					{
						if ( ![publishSession.permissions containsObject:[publishPermissions objectAtIndex:i]] )
						{
							release = true;
							publishError = [[NSError alloc] initWithDomain:@"com.facebook" code:123 userInfo:nil];
							break;
						}
					}
				}
				
				ReauthorizationCompleted(publishSession, publishError);
				
				if ( release )
				{
					[publishError release];
				}
			};
			
			// Callback wrapper
			FBSessionReauthorizeResultHandler handler = ^( FBSession *session, NSError *error )
			{
				if ( publishPermissions && publishPermissions.count > 0 && !error && session )
				{
					// You can't have 2 authorization requests going on at the same time.
					[session reauthorizeWithPublishPermissions:publishPermissions defaultAudience:FBSessionDefaultAudienceEveryone completionHandler:publishHandler];
				}
				else
				{
					bool release = false;
					if ( !error )
					{
						for ( int i = 0; i < [readPermissions count]; i++)
						{
							if ( ![session.permissions containsObject:[readPermissions objectAtIndex:i]] )
							{
								release = true;
								error = [[NSError alloc] initWithDomain:@"com.facebook" code:123 userInfo:nil];
								break;
							}
						}
					}
					
					ReauthorizationCompleted(session, error);
					
					if ( release )
					{
						[error release];
					}
				}
			};
			
			if ( readPermissions && readPermissions.count > 0 )
			{
				[fSession reauthorizeWithReadPermissions:readPermissions completionHandler:handler];
			}
			else if ( publishPermissions && publishPermissions.count > 0 )
			{
				// If there aren't any read permissions and the number of requested permissions is >0 then they have to be publish permissions
				[fSession reauthorizeWithPublishPermissions:publishPermissions defaultAudience:FBSessionDefaultAudienceEveryone completionHandler:publishHandler];
			}
			else
			{
				// Send a login event
				SessionChanged( fSession, FBSessionStateOpen, nil );
			}
		}
		else
		{
			// Send a login event
			SessionChanged( fSession, FBSessionStateOpen, nil );
		}
		
	}
}

void
IOSFBConnect::Logout() const
{
	[fSession closeAndClearTokenInformation];
	fSession = nil;

	[fFacebook autorelease]; // TODO: Figure out better fix for the KVC error msg. Right now we "defer" release via autorelease.
	fFacebook = nil;

	SessionChanged( nil, FBSessionStateClosed, nil);
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
				NSData *jsonObject = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
				NSString *jsonString = [[NSString alloc] initWithData:jsonObject encoding:NSUTF8StringEncoding];
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
IOSFBConnect::PublishInstall(const char *appId) const
{
    NSString *applicationId = [NSString stringWithUTF8String:appId];
    [FBSettings publishInstall:applicationId];
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
		
	const char *chosenOption = luaL_checkstring( L, 1 );

	// Places
	if ( 0 == strcmp( "place", chosenOption ) )
	{
		// A reference to our callback handler
		static int callbackRef = 0;

		// Set reference to onComplete function
		if ( lua_gettop( L ) > 1 )
		{
			// Set the delegates callbackRef to reference the onComplete function (if it exists)
			if ( lua_isfunction( L, lua_gettop( L ) ) )
			{
				callbackRef = luaL_ref( L, LUA_REGISTRYINDEX );
			}
		}
	
		static float longitude = 48.857875;
		static float latitude = 2.294635;
		static const char *chosenTitle;
		static const char *searchText;
		static int resultsLimit = 50;
		static int radiusInMeters = 1000;
	
		NSString *placePickerTitle = [NSString stringWithUTF8String:"Select a Place"];

		// Get the name key
		if ( ! lua_isnoneornil( L, -1 ) )
		{
			// Options table exists, retrieve latitude key
			lua_getfield( L, -1, "longitude" );
			
			// If the key has been specified, is not nil and it is a number then check it.
			if ( ! lua_isnoneornil( L, -1 ) && lua_isnumber( L, -1 ) )
			{
				// Enforce number
				luaL_checktype( L, -1, LUA_TNUMBER );
	
				// Check the string
				longitude = luaL_checknumber( L, -1 );
			}

			// Options table exists, retrieve latitude key
			lua_getfield( L, -2, "latitude" );

			// If the key has been specified, is not nil and it is a number then check it.
			if ( ! lua_isnoneornil( L, -1 ) && lua_isnumber( L, -1 ) )
			{			
				// Enforce number
				luaL_checktype( L, -1, LUA_TNUMBER );
	
				// Check the number
				latitude = luaL_checknumber( L, -1 );
			}
		
			// Options table exists, retrieve title key
			lua_getfield( L, -3, "title" );
		
			// If the key has been specified, is not nil and it is a string then check it.
			if ( ! lua_isnoneornil( L, -1 ) && lua_isstring( L, -1 ) )
			{
				// Enforce string
				luaL_checktype( L, -1, LUA_TSTRING );

				// Check the string
				chosenTitle = luaL_checkstring( L, -1 );
			}
		
			// Set the controller's title
			if ( chosenTitle )
			{
				placePickerTitle = [NSString stringWithUTF8String:chosenTitle];
			}
			
			// Options table exists, retrieve searchText key
			lua_getfield( L, -4, "searchText" );
		
			// If the key has been specified, is not nil and it is a string then check it.
			if ( ! lua_isnoneornil( L, -1 ) && lua_isstring( L, -1 ) )
			{
				// Enforce string
				luaL_checktype( L, -1, LUA_TSTRING );

				// Check the string
				searchText = luaL_checkstring( L, -1 );
			}
			else
			{
				searchText = "restuaruant";
			}
			
			// Options table exists, retrieve resultsLimit key
			lua_getfield( L, -5, "resultsLimit" );
		
			// If the key has been specified, is not nil and it is a string then check it.
			if ( ! lua_isnoneornil( L, -1 ) && lua_isnumber( L, -1 ) )
			{
				// Enforce number
				luaL_checktype( L, -1, LUA_TNUMBER );

				// Check the number
				resultsLimit = luaL_checknumber( L, -1 );
			}
			
			// Options table exists, retrieve radiusInMeters key
			lua_getfield( L, -6, "radiusInMeters" );
		
			// If the key has been specified, is not nil and it is a string then check it.
			if ( ! lua_isnoneornil( L, -1 ) && lua_isnumber( L, -1 ) )
			{
				// Enforce number
				luaL_checktype( L, -1, LUA_TNUMBER );

				// Check the number
				radiusInMeters = luaL_checknumber( L, -1 );
			}
		}
		
		// Set the controller's title
		if ( chosenTitle )
		{
			placePickerTitle = [NSString stringWithUTF8String:chosenTitle];
		}
		
		// Create the place picker view controller
		FBPlacePickerViewController *placePicker = [[FBPlacePickerViewController alloc] init];
		placePicker.title = placePickerTitle;
		placePicker.searchText = [NSString stringWithUTF8String:searchText];
		
		// Set the coordinates
		CLLocationCoordinate2D coordinates =
            CLLocationCoordinate2DMake( longitude, latitude );
		
		// Setup the cache descriptor
		FBCacheDescriptor *placeCacheDescriptor =
            [FBPlacePickerViewController
             cacheDescriptorWithLocationCoordinate:coordinates
             radiusInMeters:radiusInMeters
             searchText:placePicker.searchText
             resultsLimit:resultsLimit
             fieldsForRequest:nil];
        
		// Configure the cache descriptor
		[placePicker configureUsingCachedDescriptor:placeCacheDescriptor];
		// Load the data
		[placePicker loadData];
		
		// Show the view controller
		[placePicker presentModallyFromViewController:fRuntime.appViewController
												animated:YES
												handler:^(FBViewController *sender, BOOL donePressed)
												{
													if (donePressed)
													{
														//NSLog( @"%@", placePicker.selection );
														
														/*
																	List of keys returned
																	
																	"category" - string
																	"id" - number
																	"location" - table ie.
																	location =
																	{
																		"city" - string,
																		"country" - string.
																		"latitude" - string.
																		"longitude" - string.
																		"state" - string.
																		"street" - string.
																		"zip" - string.
																	}
																	
																	"name" - string.
																	
																	"picture" - table. .ie
																	picture = 
																	{
																		data = 
																		{
																			"is_silhouette" - bool
																			"url" - string
																		}
																	}
																	
																	"were_here_count" - number
														
																
																	*/
														
														// If there is a callback to exectute
														if ( 0 != callbackRef )
														{
															// Push the onComplete function onto the stack
															lua_rawgeti( L, LUA_REGISTRYINDEX, callbackRef );
														
															// event table
															lua_newtable( L );
																														
															// event.data table
															lua_newtable( L );
															
															// Get the properties from the graph
														
															const char *placeCategory = [(NSString*) [placePicker.selection objectForKey:@"category"] UTF8String];
															lua_pushstring( L, placeCategory );
															lua_setfield( L, -2, "category" );
															
															const char *placeId = [(NSString*) [placePicker.selection objectForKey:@"id"] UTF8String];
															lua_pushstring( L, placeId );
															lua_setfield( L, -2, "id" );
															
															const char *placeName = [(NSString*) [placePicker.selection objectForKey:@"name"] UTF8String];
															lua_pushstring( L, placeName );
															lua_setfield( L, -2, "name" );
															
															static int placeWereHere = [(NSString*) [placePicker.selection objectForKey:@"were_here_count"] intValue];
															lua_pushnumber( L, placeWereHere );
															lua_setfield( L, -2, "wereHere" );
																														
															const char *placeCity = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"city"] UTF8String];
															lua_pushstring( L, placeCity );
															lua_setfield( L, -2, "city" );
															
															const char *placeCountry = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"country"] UTF8String];
															lua_pushstring( L, placeCountry );
															lua_setfield( L, -2, "country" );
															
															NSDecimalNumber *thelatitude = [[placePicker.selection objectForKey:@"location"] valueForKey:@"latitude"];
															static float placeLatitude = [(NSDecimalNumber*)thelatitude floatValue];
															lua_pushnumber( L, placeLatitude );
															lua_setfield( L, -2, "latitude" );
															
															NSDecimalNumber *thelongitude = [[placePicker.selection objectForKey:@"location"] valueForKey:@"longitude"];
															static float placeLongitude = [(NSDecimalNumber*)thelongitude floatValue];
															lua_pushnumber( L, placeLongitude );
															lua_setfield( L, -2, "longitude" );
															
															const char *placeState = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"state"] UTF8String];
															lua_pushstring( L, placeState );
															lua_setfield( L, -2, "state" );
															
															const char *placeStreet = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"street"] UTF8String];
															lua_pushstring( L, placeStreet );
															lua_setfield( L, -2, "street" );
															
															const char *placeZip = [(NSString*) [[placePicker.selection objectForKey:@"location"] valueForKey:@"zip"] UTF8String];
															lua_pushstring( L, placeZip );
															lua_setfield( L, -2, "zip" );
															
															// Create picture table
															lua_newtable( L );
															// Create picture.data table
															lua_newtable( L );
																	
															// Set the place picture.data 'is_silhouette' property
															bool placeIsSillhouette = (bool)[[[placePicker.selection objectForKey:@"picture"] valueForKey:@"data"] valueForKey:@"is_silhouette"];
															lua_pushboolean( L, placeIsSillhouette );
															lua_setfield( L, -2, "isSilhouette" );
																	
															// Set the place picture.data 'url' property
															const char *placeUrl = [[[[placePicker.selection objectForKey:@"picture"] valueForKey:@"data"] valueForKey:@"url"] UTF8String];
															lua_pushstring( L, placeUrl );
															lua_setfield( L, -2, "url" );
																	
															// Set the data nested table
															lua_setfield(L, -2, "data" );
															// Set the picture outer table
															lua_setfield( L, -2, "picture" );
		
															// Set event.data
															lua_setfield( L, -2, "data" );
															
															// Set event.name property
															lua_pushstring( L, "fbDialog" ); // Value ( name )
															lua_setfield( L, -2, "name" ); // Key
															
															// Set event.type property
															lua_pushstring( L, "place" ); // Value ( name )
															lua_setfield( L, -2, "type" ); // Key
														
															// Call the onComplete function
															Corona::Lua::DoCall( L, 1, 1 );
		
															// Free the refrence
															lua_unref( L, callbackRef );
														}
													}
												}];
												
	}
	// Friends
	else if ( 0 == strcmp( "friends", chosenOption ) )
	{
		// A reference to our callback handler
		static int callbackRef = 0;

		// Set reference to onComplete function
		if ( lua_gettop( L ) > 1 )
		{
			// Set the delegates callbackRef to reference the onComplete function (if it exists)
			if ( lua_isfunction( L, lua_gettop( L ) ) )
			{
				callbackRef = luaL_ref( L, LUA_REGISTRYINDEX );
			}
		}
		
		FBFriendPickerViewController *friendPicker = [[FBFriendPickerViewController alloc] init];
	
		// Set up the friend picker to sort and display names the same way as the
		// iOS Address Book does.
            
		// Need to call ABAddressBookCreate in order for the next two calls to do anything.
		ABAddressBookRef addressBook = ABAddressBookCreate();
		ABPersonSortOrdering sortOrdering = ABPersonGetSortOrdering();
		ABPersonCompositeNameFormat nameFormat = ABPersonGetCompositeNameFormat();
            
		friendPicker.sortOrdering = (sortOrdering == kABPersonSortByFirstName) ? FBFriendSortByFirstName : FBFriendSortByLastName;
		friendPicker.displayOrdering = (nameFormat == kABPersonCompositeNameFormatFirstNameFirst) ? FBFriendDisplayByFirstName : FBFriendDisplayByLastName;
        
		// Load the data
		[friendPicker loadData];
		
		// Show the view controller
		[friendPicker presentModallyFromViewController:fRuntime.appViewController
                                                  animated:YES
                                                   handler:^( FBViewController *sender, BOOL donePressed )
												   {
														if ( donePressed )
														{
															//NSDictionary *value = [friendPicker.selection objectAtIndex:1];
															//NSLog( @"%@", [value objectForKey:@"name"] );
															/*
																	List of keys returned
																	
																	"first_name" - string
																	"last_name" - string
																	"name" - string (full name)
																	"id" - number
																	"picture" - table containing subtable ie
																	picture =
																	{
																		data = 
																		{
																			"is_silhouette" - number 0 false, 1 true
																			"url" - url to friend picture
																		}
																	}
																	*/
																	
																	//NSLog( @"value of data silhouette is %@", [[[items valueForKey:@"picture"] valueForKey:@"data"] valueForKey:@"is_silhouette"] );
															
															// If there is a callback to exectute
															if ( 0 != callbackRef )
															{														
																// Push the onComplete function onto the stack
																lua_rawgeti( L, LUA_REGISTRYINDEX, callbackRef );
																																
																// Event table
																lua_newtable( L );
																
																// event.data table
																lua_newtable( L );
																
																// Total number of items (friends) in the dictionary
																int numOfItems = [friendPicker.selection count];
																																
																// Loop through the dictionary and pass the data back to lua
																for ( int i = 0; i < numOfItems; i ++ )
																{
																	// Create a table to hold the current friend data
																	lua_newtable( L );
																																	
																	// Get the properties from the current dictionary index
																	NSDictionary *items = [friendPicker.selection objectAtIndex:i];
																																																			
																	// Set the friend's first name
																	const char *friendFirstName = [[items objectForKey:@"first_name"] UTF8String];
																	lua_pushstring( L, friendFirstName );
																	lua_setfield( L, -2, "firstName" );
																	
																	// Set the friend's last name
																	const char *friendLastName = [[items objectForKey:@"last_name"] UTF8String];
																	lua_pushstring( L, friendLastName );
																	lua_setfield( L, -2, "lastName" );
																	
																	// Set the friend's full name
																	const char *friendFullName = [[items objectForKey:@"name"] UTF8String];
																	lua_pushstring( L, friendFullName );
																	lua_setfield( L, -2, "fullName" );
																	
																	// Set the friend's id
																	const char *friendId = [[items objectForKey:@"id"] UTF8String];
																	lua_pushstring( L, friendId );
																	lua_setfield( L, -2, "id" );
																															
																	// Create picture table
																	lua_newtable( L );
																	// Create picture.data table
																	lua_newtable( L );																	
																	
																	// Set the friends picture.data 'is_silhouette' property
																	id isSillhouette = [[[items valueForKey:@"picture"] valueForKey:@"data"] valueForKey:@"is_silhouette"];																	
																	BOOL friendIsSillhouette = [(NSNumber*)isSillhouette boolValue];
																	lua_pushboolean( L, friendIsSillhouette );
																	lua_setfield( L, -2, "isSilhouette" );
																	
																	// Set the friends picture.data 'url' property
																	const char *friendUrl = [[[[items valueForKey:@"picture"] valueForKey:@"data"] valueForKey:@"url"] UTF8String];
																	lua_pushstring( L, friendUrl );
																	lua_setfield( L, -2, "url" );
																	
																	// Set the data nested table
																	lua_setfield(L, -2, "data" );
																	// Set the picture outer table
																	lua_setfield( L, -2, "picture" );
																	
																	// Set the main table
																	lua_rawseti( L, -2, i + 1 );																	
																}
																																
																// Set event.data
																lua_setfield( L, -2, "data" );
																
																// Set event.name property
																lua_pushstring( L, "fbDialog" ); // Value ( name )
																lua_setfield( L, -2, "name" ); // Key
																
																// Set event.type property
																lua_pushstring( L, "friends" ); // Value ( name )
																lua_setfield( L, -2, "type" ); // Key

																// Call the onComplete function
																Corona::Lua::DoCall( L, 1, 1 );
		
																// Free the refrence
																lua_unref( L, callbackRef );
															}
														}
                                                   }];

		CFRelease( addressBook );
	}
	
	// Standard facebook.showDialog
	else
	{
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
}
	
bool
IOSFBConnect::IsPublishPermission(NSString *permission)
{
	return [permission hasPrefix:@"publish"] ||
	[permission hasPrefix:@"manage"] ||
	[permission isEqualToString:@"ads_management"] ||
	[permission isEqualToString:@"create_event"] ||
	[permission isEqualToString:@"user_games_activity"] ||
	[permission isEqualToString:@"rsvp_event"];
}

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

