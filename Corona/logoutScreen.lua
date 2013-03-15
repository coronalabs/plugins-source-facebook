-- 
-- Project: Facebook Connect scrumptious sample app
--
-- Date: March 14, 2013
--
-- Version: 1.0
--
-- File name: logoutScreen.lua
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
---------------------------------------------------------------------------------------

local facebook = require( "facebook" )
local widget = require( "widget" )
local storyboard = require( "storyboard" )
local scene = storyboard.newScene()

function scene:createScene( event )
	local group = self.view
	
	local background = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
	background.x = display.contentCenterX
	background.y = display.contentCenterY + display.statusBarHeight
	background:setFillColor( 73, 103, 165 )
	group:insert( background )
	
	-- Show facebook logo
	local facebookLogo = display.newImageRect( "facebook.png", 196, 40 )
	facebookLogo.x = display.contentCenterX
	facebookLogo.y = storyboard.navBar.y + storyboard.navBar.contentHeight * 0.5 + facebookLogo.contentHeight + 10
	group:insert( facebookLogo )
	
	-- Profile Pic
	local userPicture = display.newImageRect( storyboard.userData.firstName .. storyboard.userData.lastName .. storyboard.userData.id .. ".png", system.TemporaryDirectory, 80, 80 )
	userPicture.x = display.contentCenterX
	userPicture.y = display.contentCenterY
	group:insert( userPicture )
	
	-- User name
	local userName = display.newEmbossedText( storyboard.userData.firstName .. " " .. storyboard.userData.lastName, 0, 0, native.systemFont, 16 )
	userName.x = userPicture.x
	userName.y = userPicture.y + userPicture.contentHeight * 0.5 + userName.contentHeight
	userName:setTextColor( 255 )
	group:insert( userName )
	
	-- Back to scrumptious main screen
	local function backToScrumptious( event )
		-- Hide the scrumptious button
		transition.to( event.target, { x = display.contentCenterX, alpha = 0 } )
		
		-- Show the settings button again
		transition.to( storyboard.settingsButton, { alpha = 1 } )
		
		-- Show the navbar text again
		storyboard.navBarText.isVisible = true
		
		-- Goto the scrumptious screen
		storyboard.gotoScene( "mainScreen", "slideRight" )
	end
	
	
	-- Scrumptious button
	storyboard.scrumptiousButton = widget.newButton
	{
		width = 90,
		height = 30,
		defaultFile = "back.png",
		overFile = "backOver.png",
		label = "Scrumptious",
		labelColor = 
		{
			default = { 255, 255, 255 },
			over = { 255, 255, 255, 128 },
		},
		labelXOffset = 2.5,
		fontSize = 12,
		onRelease = backToScrumptious
	}
	storyboard.scrumptiousButton.x = storyboard.scrumptiousButton.contentWidth * 0.5
	storyboard.scrumptiousButton.y = storyboard.navBar.y
	storyboard.navBarGroup:insert( storyboard.scrumptiousButton )
	
	-- Logout
	local function logoutUser( event )
		-- Log the user out
		facebook.logout()
		
		-- Hide the navigation bar
		storyboard.navBarGroup.isVisible = false
		
		-- Show the settings button again
		storyboard.settingsButton.alpha = 1
		
		-- Show the navbar text again
		storyboard.navBarText.isVisible = true
		
		-- Goto the login screen
		storyboard.gotoScene( "loginScreen", "crossFade" )
	end
	
	-- Logout button
	local logoutButton = widget.newButton
	{
		width = 298,
		height = 56,
		label = "Logout",
		onRelease = logoutUser,
	}
	logoutButton.x = display.contentCenterX
	logoutButton.y = display.contentCenterY + logoutButton.contentHeight * 2 + 20
	group:insert( logoutButton )
end

scene:addEventListener( "createScene", event )

return scene
