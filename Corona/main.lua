-- 
-- Project: Facebook Connect scrumptious sample app
--
-- Date: March 14, 2013
--
-- Version: 1.0
--
-- File name: main.lua
--
-- Author: Corona Labs
--
-- Abstract: Presents the Facebook Connect login dialog, and then posts to the user's stream
-- (Also demonstrates the use of external libraries.)
--
-- Demonstrates: Facebook library, widget
--
-- File dependencies: facebook.lua
--
-- Target devices: Simulator and Device (iOS only)

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
-- Supports Graphics 2.0
---------------------------------------------------------------------------------------

local isSimulator = "simulator" == system.getInfo( "environment" )

if isSimulator then
	local warningText = display.newText( "This sample code is not supported in the simulator\n\nPlease build for an Android, iOS device, or Xcode simulator",
		 170, 150, display.contentWidth, 0, native.systemFontBold, 14 )	
end

if not isSimulator then
	local storyboard = require( "storyboard" )

	storyboard.userData = {}
	storyboard.navBarGroup = display.newGroup()

local navBarGradient = {
	type = 'gradient',
	color1 = { 189/255, 203/255, 220/255, 255/255 }, 
	color2 = { 89/255, 116/255, 152/255, 255/255 },
	direction = "down"
}

	-- Create the navigation bar
	storyboard.navBar = display.newRect( 0, 0, display.contentWidth, 46 )
	storyboard.navBar.x = display.contentCenterX
	storyboard.navBar.y = display.screenOriginY + storyboard.navBar.contentHeight * 0.5
	storyboard.navBar:setFillColor( navBarGradient )
	storyboard.navBarGroup:insert( storyboard.navBar )

	-- Create the navigation bar text
	storyboard.navBarText = display.newEmbossedText( "Scrumptious", 0, 0, native.systemFontBold, 24 )
	storyboard.navBarText.x = display.contentCenterX
	storyboard.navBarText.y = storyboard.navBar.y
	storyboard.navBarText:setFillColor( 1 )
	storyboard.navBarGroup:insert( storyboard.navBarText )

	-- Set the navBar group as invisible initially
	storyboard.navBarGroup.isVisible = false

	-- Goto the login screen
	storyboard.gotoScene( "loginScreen" )

end
