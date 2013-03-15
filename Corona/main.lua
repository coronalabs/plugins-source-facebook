-- 
-- Project: Facebook Connect sample app
--
-- Date: December 24, 2010
--
-- Version: 1.5
--
-- File name: main.lua
--
-- Author: Corona Labs
--
-- Abstract: Presents the Facebook Connect login dialog, and then posts to the user's stream
-- (Also demonstrates the use of external libraries.)
--
-- Demonstrates: webPopup, network, Facebook library
--
-- File dependencies: facebook.lua
--
-- Target devices: Simulator and Device
--
-- Limitations: Requires internet access; no error checking if connection fails
--
-- Update History:
--	v1.1		Layout adapted for Android/iPad/iPhone4
--  v1.2		Modified for new Facebook Connect API (from build #243)
--  v1.3		Added buttons to: Post Message, Post Photo, Show Dialog, Logout
--  v1.4		Added  ...{"publish_stream"} .. permissions setting to facebook.login() calls.
--	v1.5		Added single sign-on support in build.settings (must replace XXXXXXXXX with valid facebook appId)

--
-- Comments:
-- Requires API key and application secret key from Facebook. To begin, log into your Facebook
-- account and add the "Developer" application, from which you can create additional apps.
--
-- IMPORTANT: Please ensure your app is compatible with Facebook Single Sign-On or your
--			  Facebook implementation will fail! See the following blog post for more details:
--			  http://www.coronalabs.com/links/facebook-sso
--
-- Sample code is MIT licensed, see http://www.coronalabs.com/links/code/license
-- Copyright (C) 2010 Corona Labs Inc. All Rights Reserved.
--
---------------------------------------------------------------------------------------

local storyboard = require( "storyboard" )

local TEST_SCRUMPTIOUS = true
local TEST_FBCONNECT = false

if TEST_SCRUMPTIOUS then
	storyboard.userData = {}

	storyboard.navBarGroup = display.newGroup()

	local navBarGradient = graphics.newGradient(
				{ 189, 203, 220, 255 }, 
				{ 89, 116, 152, 255 }, "down" )

	-- Create the navigation bar
	storyboard.navBar = display.newRect( 0, 0, display.contentWidth, 46 )
	storyboard.navBar.x = display.contentCenterX
	storyboard.navBar.y = display.statusBarHeight + storyboard.navBar.contentHeight * 0.5
	storyboard.navBar:setFillColor( navBarGradient )
	storyboard.navBarGroup:insert( storyboard.navBar )

	-- Create the navigation bar text
	storyboard.navBarText = display.newEmbossedText( "Scrumptious", 0, 0, native.systemFontBold, 24 )
	storyboard.navBarText.x = display.contentCenterX
	storyboard.navBarText.y = storyboard.navBar.y
	storyboard.navBarText:setTextColor( 255 )
	storyboard.navBarGroup:insert( storyboard.navBarText )

	-- Set the navBar group as invisible initially
	storyboard.navBarGroup.isVisible = false

	-- Goto the login screen
	storyboard.gotoScene( "loginScreen" )
end

if TEST_FBCONNECT then
	storyboard.gotoScene( "fb" )
end
