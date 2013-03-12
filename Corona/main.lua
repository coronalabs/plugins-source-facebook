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

-- DANNY > Go straight to the scrumptious sample
require( "scrumptious" ).new()

--[[

--]]
