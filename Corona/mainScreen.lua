-- 
-- Project: Facebook Connect scrumptious sample app
--
-- Date: March 14, 2013
--
-- Version: 1.0
--
-- File name: mainScreen.lua
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
	
	local appId = "235285269832478"
	local fbCommand = nil
	local GET_USER_INFO = "getInfo"
	local POST_MSG = "post"
	
	-- Forward references
	local createList = nil
	local items = nil
	
	local postData =
	{
		eating = nil,
		eatingUrl = nil,
		place = nil,
		address = nil,
		with = {},
	}
	
	local mealTypes =
	{
		{ name = "Cheeseburger", url = "http://developer.coronalabs.com/sites/default/files/fbscrumptious/cheeseBurger.html" },
		{ name = "Pizza", url = "http://developer.coronalabs.com/sites/default/files/fbscrumptious/pizza.html" },
		{ name = "Hotdog", url = "http://developer.coronalabs.com/sites/default/files/fbscrumptious/hotdog.html" },
		{ name = "Italian", url = "http://developer.coronalabs.com/sites/default/files/fbscrumptious/italian.html" },
		{ name = "French", url = "http://developer.coronalabs.com/sites/default/files/fbscrumptious/french.html" },
		{ name = "Chinese", url = "http://developer.coronalabs.com/sites/default/files/fbscrumptious/chinese.html" },
		{ name = "Thai", url = "http://developer.coronalabs.com/sites/default/files/fbscrumptious/thai.html" },
		{ name = "Indian", url = "http://developer.coronalabs.com/sites/default/files/fbscrumptious/indian.html" },
	}
	
	local background = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
	background.x = display.contentCenterX
	background.y = display.contentCenterY + display.statusBarHeight
	background:setFillColor( 255, 255, 255 )
	group:insert( background )
	
	-- Settings 
	local function showSettings( event )
		-- Hide the settings button
		transition.to( event.target, { alpha = 0 } )
		
		-- Show the scruptious button & reset it's position on the navbar
		if storyboard.scrumptiousButton then
			storyboard.scrumptiousButton.alpha = 1
			
			-- Reset the position
			storyboard.scrumptiousButton.x = storyboard.scrumptiousButton.contentWidth * 0.5
		end
		
		-- Hide the navbar text
		storyboard.navBarText.isVisible = false
	
		-- Goto the logout screen
		storyboard.gotoScene( "logoutScreen", "slideLeft" )
	end
	
	-- Settings button
	storyboard.settingsButton = widget.newButton
	{
		width = 60,
		height = 30,
		defaultFile = "assets/default.png",
		overFile = "assets/over.png",
		label = "Settings",
		labelColor = 
		{
			default = { 255, 255, 255 },
			over = { 255, 255, 255, 128 },
		},
		fontSize = 12,
		onRelease = showSettings,
	}
	storyboard.settingsButton.x = display.contentWidth - 32
	storyboard.settingsButton.y = storyboard.navBar.y
	storyboard.navBarGroup:insert( storyboard.settingsButton )
	
	-- Profile Pic
	local userPicture = display.newImageRect( storyboard.userData.firstName .. storyboard.userData.lastName .. storyboard.userData.id .. ".png", system.TemporaryDirectory, 80, 80 )
	userPicture.x = 20 + userPicture.contentWidth * 0.5
	userPicture.y = 120
	group:insert( userPicture )
	
	-- User name
	local userName = display.newText( storyboard.userData.firstName .. " " .. storyboard.userData.lastName, 0, 0, native.systemFont, 16 )
	userName.x = userPicture.x + userPicture.contentWidth * 0.5 + userName.contentWidth * 0.5 + 10
	userName.y = userPicture.y - userPicture.contentHeight * 0.5 + userName.contentHeight * 0.5
	userName:setTextColor( 0 )
	group:insert( userName )
	
	
	-- Function to execute on completion of friend choice
	local function onCompleteFriends( event )
		print( "event.name:", event.name )
		
		local friendsSelected = {}
	
		-- If there is event.data print it's key/value pairs
		if event.data then
			print( "event.data: {" );

			if "table" == type( event.data ) then
				for i = 1, #event.data do
					print( "{" )

					for k, v in pairs( event.data[i] ) do
						print( k, ":", v )	
	
						-- Add friend to post data
						if "id" == k then
							postData.with[#postData.with + 1] = v
						elseif "fullName" == k then
							friendsSelected[#friendsSelected + 1] = v
						end
					end

					print( "picture : {" )
					for k, v in pairs( event.data[i].picture.data ) do
						print( k, ":", v )
					end
					print( "}," )

					print( "}," )
				end
			end

			-- Set the with friends string to the first selected friend by default
			local withString = friendsSelected[1]

			-- If there is more than one friend selected, append the id string
			if #postData.with > 1 then
				for i = 2, #postData.with do
					-- postData.with = postData[i-1].with .. "," .. postData[i].with
				end
			end

			-- If there is more than one friend selected, append the string
			if #friendsSelected > 1 then
				withString = friendsSelected[1] .. " and " .. #friendsSelected - 1 .. " others"
			end
			
			-- Set the description
			items[3].description = withString
			
			-- Recreate the list
			createList()

			print( "}" );
		end
	end


	local function onCompletePlaces( event )
		print( "event.name:", event.name )

		if event.data then
			print( "{" )

			for k, v in pairs( event.data ) do
				print( k, ":", v )

				-- Add place to post data
				if "name" == k then
					postData.place = v

					-- Update the description
					items[2].description = postData.place
					-- Recreate the list
					createList()
				end
				
				-- Add place address to post data
				if "street" == k then
					postData.address = v
				elseif "id" == k then
					postData.id = v
				elseif "state" == k or "city" == k then
					if string.len( v ) > 0 then
						postData.address = postData.address .. ", " .. v
					end
				end

				if "picture" == k then
					print( "picture : {" )

					for k, v in pairs( v.data ) do
						print( k, ":", v )
					end
					print( "}," )
				end
			end

			print( "}" )
		end
	end
	
	
	
	local function facebookListener( event )
		if "request" == event.type then		
			native.showAlert( "Result", "Message succesfully posted!", { "Ok" } )
			
			-- Reset the item descriptions
			items[1].description = "Select one"
			items[2].description = "Select one"
			items[3].description = "Select friends"
			-- Recreate the list
			createList()
			
		-- After a successful login event, send the FB command
		-- Note: If the app is already logged in, we will still get a "login" phase
	    elseif "session" == event.type then
	        -- event.phase is one of: "login", "loginFailed", "loginCancelled", "logout"
				
			if event.phase ~= "login" then
				-- Exit if login error
				return
			end
			
			-- This code posts a message to your Facebook Wall
			if fbCommand == POST_MSG then
				local includePlace = false
				local includeWith = false
				
				-- Handle errors
				if type( postData.place ) == "string" and string.len( postData.place ) > 0 then
					includePlace = true
				end
				
				if #postData.with > 0 then
					includeWith = true
				end
								
				if type( postData.eating ) ~= "string" then
					native.showAlert( "Missing selection", "You need to select what food you are eating", { "OK" } )
					return
				end 				

				-- If all is ok, post the message to the users wall
				local friends = ""
				
				-- Set the with friends string accordingly
				if #postData.with > 0 then
					for i = 1, #postData.with do
						if i <= 1 then
							friends = postData.with[i]
						elseif i >= #postData.with then
							friends = friends .. "," .. postData.with[i]
						else
							friends = friends .. "," .. postData.with[i]
						end
					end
				end
				
				-- Message to post to the users wall
				local messageToPost = storyboard.userData.firstName .. " " .. storyboard.userData.lastName
				local placeToPost = ""
				local selectedMeal = postData.eatingUrl
								
				if includePlace then
					placeToPost = postData.id
				end
								
				-- Set the message
				local postMsg = {}
				
				-- Set up the post message
				if "string" == type( selectedMeal ) and string.len( selectedMeal ) > 1 then
					postMsg.meal = selectedMeal
				end
				
				-- Set the friends we selected to be tagged in our timeline post
				if "string" == type( friends ) and string.len( friends ) > 1 then
					postMsg.tags = friends
				end
				
				if "string" == type( placeToPost ) and string.len( placeToPost ) > 1 then
					postMsg.place = placeToPost
				end
		
				-- Post the message
				facebook.request( "me/corona_scrumptious:eat", "POST", postMsg )
			end
			
			return true
	    end
	end
	


	-- Pick place
	local function pickPlace( event ) 
		facebook.showDialog( "place", { title = "Select A Restaurant", longitude = 48.857875, latitude = 2.294635, searchText = "restaurant", resultsLimit = 20, radiusInMeters = 2000 }, onCompletePlaces )
	end

	-- Show friends
	local function pickFriends( event )
		facebook.showDialog( "friends", onCompleteFriends )
	end

	-- Pick meal
	local function pickMeal( event )
		actionSheet:show()
	end
	
	
	-- Setup the items table
	items = 
	{
		{ image = "assets/action-eating.png", title = "What are you eating?", description = "Select one", onTouch = pickMeal },
		{ image = "assets/action-location.png", title = "Where are you?", description = "Select one", onTouch = pickPlace },
		{ image = "assets/action-people.png", title = "With whom?", description = "Select friends", onTouch = pickFriends },
	}


	local function onRowTouch( event )
		local phase = event.phase
		local row = event.target

		if "release" == phase then
			row._touchFunction()
		end

		return true
	end


	local function onRowRender( event )
		local row = event.row

		-- The row's image
		row.image = display.newImageRect( items[row.index].image, 34, 34 )
		row.image.x = row.image.contentWidth * 0.5
		row.image.y = row.contentHeight * 0.5
		row:insert( row.image )

		-- The row's title
		row.title = display.newText( items[row.index].title, 0, 0, native.systemFont, 18 )
		row.title.x = row.image.x + row.image.contentWidth * 0.5 + row.title.contentWidth * 0.5 + 8
		row.title.y = row.contentHeight * 0.5 - row.title.contentHeight * 0.5 + 4
		row.title:setTextColor( 0 )
		row:insert( row.title )

		-- The row's description
		row.description = display.newText( items[row.index].description, 0, 0, native.systemFont, 14 )
		row.description.x = row.image.x + row.image.contentWidth * 0.5 + row.description.contentWidth * 0.5 + 8
		row.description.y = row.contentHeight * 0.5 + row.description.contentHeight * 0.5
		row.description:setTextColor( 100, 139, 237 )
		row:insert( row.description )

		-- Set the rows touch function
		row._touchFunction = items[row.index].onTouch
	end

	-- Function to create a tableView list
	createList = function()
		if list then
			list:deleteAllRows()
			display.remove( list )
			list = nil
		end

		-- Create a list
		list = widget.newTableView
		{
			left = 10,
			top = 200,
			width = display.contentWidth - 20,
			height = 100,
			hideBackground = true,
			isLocked = true,
			onRowRender = onRowRender,
			onRowTouch = onRowTouch,
		}
		group:insert( list )

		for i = 1, #items do
			list:insertRow
			{
				id = items[i],
				rowColor = 
				{
					default = { 255, 255, 255, 255 },
				},
			}
		end
	end

	-- Create the list
	createList()
	

	-- Announce!
	local function postMessage( event )
		fbCommand = POST_MSG
		facebook.login( appId, facebookListener, { "publish_actions" } )
	end

	-- Announce button
	local announceButton = widget.newButton
	{
		width = 180,
		height = 59,
		label = "Announce!",
		onRelease = postMessage,
	}
	announceButton.x = display.contentCenterX
	announceButton.y = display.contentHeight - 80
	group:insert( announceButton )
	
	
	-- Create an action sheet
	local function createActionSheet( rows )
		local group = display.newGroup()

		local underlay = display.newRect( group, 0, 0, display.contentWidth, display.contentHeight )
		underlay:setFillColor( 0, 0, 0, 128 )
		underlay:addEventListener( "touch", function() return true end )

		local title = display.newEmbossedText( group, "Select a meal", 0, 0, native.systemFont, 14 )
		title:setTextColor( 255 )
		title.x = display.contentCenterX
		title.y = storyboard.navBar.y

		local function onRowRender( event )
			local row = event.row

			local rowTitle = display.newText( rows[row.index].name, 0, 0, native.systemFontBold, 24 )
			rowTitle.x = row.contentWidth * 0.5
			rowTitle.y = row.contentHeight * 0.5
			rowTitle:setTextColor( 0 )
			row:insert( rowTitle )
		end

		local function onRowTouch( event )
			local phase = event.phase
			local row = event.target

			if "release" == phase then
				postData.eating = rows[row.index].name
				postData.eatingUrl = rows[row.index].url
				
				actionSheet:hide()
			end

			return true
		end

		-- Create a tableView
		local tableView = widget.newTableView
		{
			left = 20,
			top = display.statusBarHeight + 64,
			width = display.contentWidth - 40,
			height = 300,
			maskFile = "assets/actionSheetMask.png",
			onRowRender = onRowRender,
			onRowTouch = onRowTouch,
		}
		tableView.maskY = 310 * 0.5
		group:insert( tableView )

		-- Create the rows
		for i = 1, #rows do
			tableView:insertRow
			{
				id = rows[i],
				rowHeight = 50,
			}
		end

		-- Apply a gradient on top of the tableView
		local tableViewGradient = graphics.newGradient(
			{ 252, 252, 252 },
			{ 141, 141, 141 }, "down" )

		local gradientRect = display.newRect( 20, display.statusBarHeight + 64, display.contentWidth - 40, 310 )
		gradientRect:setFillColor( tableViewGradient )
		gradientRect.alpha = 0.25
		group:insert( gradientRect )

		local underlayBorder = display.newImageRect( group, "assets/actionSheetBorder.png", 300, 330 )
		underlayBorder.x = gradientRect.x + 1
		underlayBorder.y = gradientRect.y
		underlayBorder:toBack()

		local function hideActionSheet( event )
			transition.to( group, { y = display.contentHeight + group.contentHeight * 0.5, transition = easing.inOutExpo } )
			transition.to( storyboard.navBarText, { alpha = 1 } )
			transition.to( storyboard.settingsButton, { alpha = 1 } )
		end

		local cancelButton = widget.newButton
		{
			width = 298,
			height = 56,
			label = "Cancel",
			onRelease = hideActionSheet,
		}
		cancelButton.x = display.contentCenterX
		cancelButton.y = display.contentHeight - cancelButton.contentHeight * 0.5 - 10
		group:insert( cancelButton )

		-- Show the actionSheet
		function group:show()
			-- Show the group
			transition.to( self, { y = 0, transition = easing.inOutExpo } )
			-- Hide the navbar text
			transition.to( storyboard.navBarText, { alpha = 0 } )
			-- Hide the settings button
			transition.to( storyboard.settingsButton, { alpha = 0 } )
		end

		-- Hide the actionSheet
		function group:hide()
			local function onComplete( event )
				items[1].description = postData.eating
				createList()
			end

			-- Hide the group
			transition.to( self, { y = display.contentHeight + self.contentHeight * 0.5, transition = easing.inOutExpo, onComplete = onComplete } )
			-- Show the navbar text
			transition.to( storyboard.navBarText, { alpha = 1 } )
			-- Show the settings button
			transition.to( storyboard.settingsButton, { alpha = 1 } )
		end

		group.y = display.contentHeight

		return group
	end

	-- Create the actionsheet
	actionSheet = createActionSheet( mealTypes )
end

scene:addEventListener( "createScene", event )

return scene
