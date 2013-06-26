// ----------------------------------------------------------------------------
// 
// IOSFBConnect.h
// Copyright (c) 2013 Corona Labs Inc. All rights reserved.
// 
// Reviewers:
// 		Walter
//
// ----------------------------------------------------------------------------

#ifndef _IOSFBConnect_H__
#define _IOSFBConnect_H__

#include "CoronaLua.h"
#include "FBConnect.h"

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

// ----------------------------------------------------------------------------

@class Facebook;
@class FBSession;
@class IOSFBConnectDelegate;
@class NSError;
@class NSString;
@class NSURL;

@protocol CoronaRuntime;

struct lua_State;

namespace Corona
{

class FBConnectEvent;

// ----------------------------------------------------------------------------

class IOSFBConnect : public FBConnect
{
	public:
		typedef FBConnect Super;
		typedef IOSFBConnect Self;

	public:
		IOSFBConnect( id< CoronaRuntime > runtime );
		virtual ~IOSFBConnect();

	protected:
		bool Initialize( NSString *appId );

	protected:
		void SessionChanged( FBSession *session, int state, NSError *error ) const;
		void ReauthorizationCompleted( FBSession *session, NSError *error ) const;

	public:
		void Dispatch( const FBConnectEvent& e ) const;

	public:
		virtual bool Open( const char *url ) const;
		virtual void Resume() const;
		virtual void Close() const;

	public:
		virtual void Login( const char *appId, const char *permissions[], int numPermissions ) const;
		virtual void Logout() const;
		virtual void Request( lua_State *L, const char *path, const char *httpMethod, int x ) const;
		virtual void ShowDialog( lua_State *L, int index ) const;
        virtual void PublishInstall( const char *appId ) const;

	private:
		id< CoronaRuntime > fRuntime;
		mutable FBSession *fSession;
		mutable Facebook *fFacebook; // Need this to support Dialogs
		IOSFBConnectDelegate *fFacebookDelegate;
		id fConnectionDelegate;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

#endif // _IOSFBConnect_H__
