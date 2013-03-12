

local M = {}


function M.new()
	local widget = require( "widget" )
	local facebook = require("facebook")
	local json = require("json")
	
	--
	display.setDefault( "background", 255, 255, 255 )

	--
	local staticGroup = display.newGroup()
	local settingsGroup = display.newGroup()
	local mainGroup = display.newGroup()
	local loginGroup = display.newGroup()
	local items = nil
	local createList = nil
	local list = nil
	local actionSheet = nil
	local appId = "235285269832478"
	local fbCommand = nil
	local userPicture = nil
	local userName = nil
	local currentScreen = "mainWindow"
	local settingsButton = nil
	local userData = {}
	local postData =
	{
		eating = nil,
		place = nil,
		with = {},
	}
	
	local mealTypes =
	{
		"Pizza",
		"Chicken",
		"Steak",
		"Pasta",
		"Noodles",
		"French Fries",
		"Sausage",
		"Beef",
		"Stir Fry",
	}
	
	local POST_MSG = "post"
	local GET_USER_INFO = "getInfo"

	
	local function onCompleteFriends( event )	
		-- event.data is either a table or nil depending on the option chosen
		print ( "event.data is a :", event.data );
			
		print( "num of elements in event.data", #event.data )

		-- If there is event.data print it's key/value pairs
		if event.data then
			print( "event.data: {" );
			
			if "table" == type( event.data ) then
				for i = 1, #event.data do
					print( "{" )
					
					for k, v in pairs( event.data[i] ) do
						print( k, ":", v )	
						
						-- Add friend to post data
						if "fullName" == k then
							postData.with[#postData.with + 1] = v
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
			
			--
			local withString = postData.with[1]

			if #postData.with > 1 then
				withString = postData.with[1] .. " and " .. #postData.with - 1 .. " others"
			end
			
			items[3].description = withString
			createList()

			print( "}" );
		end
	end
	
	
	local function onCompletePlaces( event )
		if event.data then
			print( "{" )
			
			for k, v in pairs( event.data ) do
				print( k, ":", v )
				
				-- Add place to post data
				if "name" == k then
					postData.place = v

					items[2].description = postData.place
					createList()
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


	-- Pick place
	local function pickPlace( event ) 
		facebook.show( "place", { title = "Select A Restaurant", searchText = "restaurant", resultsLimit = 20, radiusInMeters = 2000 }, onCompletePlaces )
		
		--facebook.show( "place", { longitude = 3.455, latitude = 1.024, title = "Hello World!" }, onCompletePlaces )
	end

	-- Show friends
	local function pickFriends( event )
		facebook.show( "friends", onCompleteFriends )
	end
	
	-- Pick meal
	local function pickMeal( event )
		actionSheet:show()
	end
	
	-- New Facebook Connection listener
	--
	local function listener( event )
		--- Debug Event parameters printout --------------------------------------------------
		--- Prints Events received up to 20 characters. Prints "..." and total count if longer
		--- print( "Facebook Listener events:" )
	
		local maxStr = 20		-- set maximum string length
		local endStr
	
		for k,v in pairs( event ) do
			local valueString = tostring(v)
			if string.len(valueString) > maxStr then
				endStr = " ... #" .. tostring(string.len(valueString)) .. ")"
			else
				endStr = ")"
			end
			print( "   " .. tostring( k ) .. "(" .. tostring( string.sub(valueString, 1, maxStr ) ) .. endStr )
		end
		--- End of debug Event routine -------------------------------------------------------

	    print( "event.name", event.name ) -- "fbconnect"
	    print( "event.type:", event.type ) -- type is either "session" or "request" or "dialog"
		print( "isError: " .. tostring( event.isError ) )
		print( "didComplete: " .. tostring( event.didComplete) )
		-----------------------------------------------------------------------------------------
		
		if "request" == event.type then
			local response = json.decode( event.response )

			if response then
				userData.firstName = response.first_name
				userData.lastName = response.last_name
				userData.id = response.id
			end

			-- 
			local function networkListener( event )
				if event.isError then
					print( "Network error: Download of profile picture failed" )
				else
					print( "Profile picture downloaded successfully" )
					
					display.remove( userPicture )
					display.remove( userText )

					userPicture = display.newImageRect( userData.firstName .. userData.lastName .. userData.id .. ".png", system.TemporaryDirectory, 80, 80 )
					
					if currentScreen == "mainWindow" then
						userPicture.x = 20 + userPicture.contentWidth * 0.5
						userPicture.y = 120
						mainGroup:insert( userPicture )
						
						userName = display.newText( userData.firstName .. " " .. userData.lastName, 0, 0, native.systemFont, 16 )
						userName.x = userPicture.x + userPicture.contentWidth * 0.5 + userName.contentWidth * 0.5 + 10
						userName.y = userPicture.y - userPicture.contentHeight * 0.5 + userName.contentHeight * 0.5
						userName:setTextColor( 0 )
						mainGroup:insert( userName )
					end
				end
			end
			
			-- Download the profile picture
			local path = system.pathForFile( userData.firstName .. userData.lastName .. userData.id .. ".png", system.TemporaryDirectory )
			local picDownloaded = io.open( path )

			if not picDownloaded then
				network.download( "http://graph.facebook.com/" .. userData.id .. "/picture", "GET", networkListener, userData.firstName .. userData.lastName .. userData.id .. ".png", system.TemporaryDirectory )
			else
				if currentScreen == "mainWindow" then
					display.remove( userPicture )
					display.remove( userName )

					userPicture = display.newImageRect( userData.firstName .. userData.lastName .. userData.id .. ".png", system.TemporaryDirectory, 80, 80 )
					userPicture.x = 20 + userPicture.contentWidth * 0.5
					userPicture.y = 120
					mainGroup:insert( userPicture )
					
					userName = display.newText( userData.firstName .. " " .. userData.lastName, 0, 0, native.systemFont, 16 )
					userName.x = userPicture.x + userPicture.contentWidth * 0.5 + userName.contentWidth * 0.5 + 10
					userName.y = userPicture.y - userPicture.contentHeight * 0.5 + userName.contentHeight * 0.5
					userName:setTextColor( 0 )
					mainGroup:insert( userName )
				end
			end

		-- After a successful login event, send the FB command
		-- Note: If the app is already logged in, we will still get a "login" phase
		--
	    elseif ( "session" == event.type ) then
	        -- event.phase is one of: "login", "loginFailed", "loginCancelled", "logout"
		
			--print( "Session Status: " .. event.phase )
		
			if event.phase ~= "login" then
				-- Exit if login error
				return
			end
			
			-- This code posts a message to your Facebook Wall
			if fbCommand == POST_MSG then
				print( "fbCommand is: ", fbCommand )

				-- Handle errors
				if type( postData.place ) ~= "string" then
					native.showAlert( "Missing selection", "You need to select the place were you are currently eating", { "OK" } )
					return
				end
				
				if type( postData.eating ) ~= "string" then
					native.showAlert( "Missing selection", "You need to select what food you are eating", { "OK" } )
					return
				end 
				
				if 0 == #postData.with then
					native.showAlert( "Missing selection", "You need to select who you are eating with", { "OK" } )
					return
				end

				-- If all is ok, post the message to the users wall
				local friends = ""
				
				for i = 1, #postData.with do
					if i <= 1 then
						friends = postData.with[i]
					elseif i >= #postData.with then
						friends = friends .. " & " .. postData.with[i]
					else
						friends = friends .. ", " .. postData.with[i]
					end
				end

				local postMsg = 
				{
					message = "I am eating: " .. postData.eating .. ", at: " .. postData.place .. " with: " .. friends .. ". Posted from Corona SDK!"
				}
		
				facebook.request( "me/feed", "POST", postMsg )		-- posting the message
				
				return true
			end
			
			-- Request the current logged in user's info
			if fbCommand == GET_USER_INFO then
				--print( 'GET_USER_INFO', '> facebook.request( "me" )' )
				facebook.request( "me" )
				
				-- hide the login window
				transition.to( loginGroup, { alpha = 0 } )

				return true
			end
	    end
	end
	

	-- Login
	local function loginUser( event )
		-- call the login method of the FB session object, passing in a handler
		-- to be called upon successful login.
		fbCommand = GET_USER_INFO
		facebook.login( appId, listener, {"publish_stream"}  )
	end
	
	-- Logout
	local function logoutUser( event )
		facebook.logout()

		
		local function restoreMainWindow()
			settingsGroup.x =  display.contentWidth + settingsGroup.contentWidth * 0.5
			mainGroup.x = display.contentCenterX
			settingsButton.alpha = 1
			
			currentScreen = "mainWindow"
		end

		-- Show the login window
		transition.to( loginGroup, { alpha = 1, onComplete = restoreMainWindow } )
	end
	
	-- Announce!
	local function postMessage( event )
		fbCommand = POST_MSG
		facebook.login( appId, listener, {"publish_stream"}  )
	end
	
	-- Show settings
	local function showSettings( event )
		currentScreen = "settings"
		transition.to( mainGroup, { x = - display.contentWidth, transition = easing.outQuad } )
		transition.to( settingsGroup, { x = display.contentCenterX, transition = easing.outQuad } )
		transition.to( event.target, { alpha = 0 } )
		
		userPicture.x = display.contentCenterX
		userPicture.y = display.contentCenterY
		settingsGroup:insert( userPicture )
		
		display.remove( userName )

		userName = display.newEmbossedText( userData.firstName .. " " .. userData.lastName, 0, 0, native.systemFont, 16 )
		userName.x = userPicture.x
		userName.y = userPicture.y + userPicture.contentHeight * 0.5 + userName.contentHeight
		userName:setTextColor( 255 )
		settingsGroup:insert( userName )
	end

	-- Back to scrumptious main screen
	local function backToScrumptious( event )
		currentScreen = "mainWindow"
		transition.to( settingsGroup, { x = display.contentWidth + settingsGroup.contentWidth * 0.5, transition = easing.outQuad } )
		transition.to( mainGroup, { x = display.contentCenterX, transition = easing.outQuad } )
		transition.to( settingsButton, { alpha = 1 } )
		
		display.remove( userPicture )
		display.remove( userText )
		
		userPicture = display.newImageRect( userData.firstName .. userData.lastName .. userData.id .. ".png", system.TemporaryDirectory, 80, 80 )
		userPicture.x = 20 + userPicture.contentWidth * 0.5
		userPicture.y = 120
		mainGroup:insert( userPicture )
		
		userName = display.newText( userData.firstName .. " " .. userData.lastName, 0, 0, native.systemFont, 18 )
		userName.x = userPicture.x + userPicture.contentWidth * 0.5 + userName.contentWidth * 0.5 + 10
		userName.y = userPicture.y - userPicture.contentHeight * 0.5 + userName.contentHeight * 0.5
		userName:setTextColor( 0 )
		mainGroup:insert( userName )
	end
	

	--------------------
	--- VISUAL SET UP
	--------------------
	
	-- LOGIN PAGE >>>>>
	
	local background = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
	background.x = display.contentCenterX
	background.y = display.contentCenterY
	background:setFillColor( 73, 103, 165 )
	loginGroup:insert( background ) 

	local scrumptiousLogo = display.newImageRect( "scrumptious_logo_large.png", 100, 100 )
	scrumptiousLogo.x = 20 + scrumptiousLogo.contentWidth * 0.5
	scrumptiousLogo.y = 50 + scrumptiousLogo.contentHeight * 0.5
	loginGroup:insert( scrumptiousLogo )
	
	local scrumptiousLabel = display.newText( "Scrumptious", 0, 0, native.systemFontBold, 24 )
	scrumptiousLabel.x = scrumptiousLogo.x + scrumptiousLogo.contentWidth * 0.5 + scrumptiousLabel.contentWidth * 0.5 + 20
	scrumptiousLabel.y = scrumptiousLogo.y - 20
	scrumptiousLabel:setTextColor( 138, 215, 255 )
	loginGroup:insert( scrumptiousLabel )
	
	local getStartedText = display.newText( "To get started, login\n using Facebook", 0, 0, display.contentWidth, 0, native.systemFont, 18 )
	getStartedText.x = 240
	getStartedText.y = 220
	loginGroup:insert( getStartedText )
	
	local loginButton = widget.newButton
	{
		width = 120,
		height = 59,
		label = "Login",
		onRelease = loginUser,
	}
	loginButton.x = display.contentCenterX
	loginButton.y = display.contentCenterY + 80
	loginGroup:insert( loginButton )
	
	-- >>
	
	local navBarGradient = graphics.newGradient(
		{ 189, 203, 220, 255 }, 
		{ 89, 116, 152, 255 }, "down" )
	
	local navBar = display.newRect( 0, 0, display.contentWidth, 46 )
	navBar.x = display.contentCenterX
	navBar.y = display.statusBarHeight + navBar.contentHeight * 0.5
	navBar:setFillColor( navBarGradient )
	staticGroup:insert( navBar )
	
	local navBarText = display.newEmbossedText( "Scrumptious", 0, 0, native.systemFontBold, 24 )
	navBarText.x = display.contentCenterX
	navBarText.y = navBar.y
	navBarText:setTextColor( 255 )
	mainGroup:insert( navBarText )
	
	
	
	-- Setup the settings page
	local background = display.newRect( 0, 0, display.contentWidth, display.contentHeight - ( navBar.contentHeight + display.statusBarHeight )  )
	background.x = display.contentCenterX
	background.y = display.contentHeight - background.contentHeight * 0.5
	background:setFillColor( 73, 103, 165 )
	settingsGroup:insert( background )
	
	-- Show facebook logo
	local facebookLogo = display.newImageRect( "facebook.png", 196, 40 )
	facebookLogo.x = display.contentCenterX
	facebookLogo.y = navBar.y + navBar.contentHeight * 0.5 + facebookLogo.contentHeight + 10
	settingsGroup:insert( facebookLogo )

	
	-- Position the settings group offscreen (to the right)
	settingsGroup:setReferencePoint( display.CenterReferencePoint )
	settingsGroup.x = display.contentWidth + settingsGroup.contentWidth * 0.5
	
	
	
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
	mainGroup:insert( announceButton )

	
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
	settingsGroup:insert( logoutButton )
	

	-- Settings button
	settingsButton = widget.newButton
	{
		width = 60,
		height = 30,
		defaultFile = "default.png",
		overFile = "over.png",
		label = "Settings",
		labelColor = 
		{
			default = { 255, 255, 255 },
			over = { 255, 255, 255, 128 },
		},
		fontSize = 12,
		onRelease = showSettings,
	}
	settingsButton.x = display.contentWidth - settingsButton.contentWidth * 0.5 - 2
	settingsButton.y = navBar.y
	staticGroup:insert( settingsButton )

	-- Scrumptious button
	local scrumptiousButton = widget.newButton
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
	scrumptiousButton.x = scrumptiousButton.contentWidth * 0.5
	scrumptiousButton.y = navBar.y
	settingsGroup:insert( scrumptiousButton )
	
	--
	items = 
	{
		{ image = "action-eating.png", title = "What are you eating?", description = "Select one", onTouch = pickMeal },
		{ image = "action-location.png", title = "Where are you?", description = "Select one", onTouch = pickPlace },
		{ image = "action-people.png", title = "With whom?", description = "Select friends", onTouch = pickFriends },
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
		
		row._touchFunction = items[row.index].onTouch
	end
	
	--
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
			isHorizontalScrollDisabled = true,
			isVerticalScrollDisabled = true,
			onRowRender = onRowRender,
			onRowTouch = onRowTouch,
		}
		mainGroup:insert( list )

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
	
	createList()

	
	-- Create an action sheet
	local function createActionSheet( rows )
		local group = display.newGroup()
		
		local underlay = display.newRect( group, 0, 0, display.contentWidth, display.contentHeight )
		underlay:setFillColor( 0, 0, 0, 128 )
		underlay:addEventListener( "touch", function() return true end )
		
		local title = display.newEmbossedText( group, "Select a meal", 0, 0, native.systemFont, 14 )
		title:setTextColor( 255 )
		title.x = display.contentCenterX
		title.y = navBar.y
		
		
		local function onRowRender( event )
			local row = event.row
					
			local rowTitle = display.newText( rows[row.index], 0, 0, native.systemFontBold, 24 )
			rowTitle.x = row.contentWidth * 0.5
			rowTitle.y = row.contentHeight * 0.5
			rowTitle:setTextColor( 0 )
			row:insert( rowTitle )
		end

		local function onRowTouch( event )
			local phase = event.phase
			local row = event.target
			
			if "release" == phase then
				postData.eating = row.id

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
			maskFile = "actionSheetMask.png",
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
		
		local underlayBorder = display.newImageRect( group, "actionSheetBorder.png", 300, 330 )
		underlayBorder.x = gradientRect.x + 1
		underlayBorder.y = gradientRect.y
		underlayBorder:toBack()
		
		local function hideActionSheet( event )
			transition.to( group, { y = display.contentHeight + group.contentHeight * 0.5, transition = easing.inOutExpo } )
			transition.to( navBarText, { alpha = 1 } )
			transition.to( settingsButton, { alpha = 1 } )
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
			transition.to( self, { y = 0, transition = easing.inOutExpo } )
			
			transition.to( navBarText, { alpha = 0 } )
			transition.to( settingsButton, { alpha = 0 } )
		end
		
		-- Hide the actionSheet
		function group:hide()
			local function onComplete( event )
				items[1].description = postData.eating
				createList()
			end
			
			transition.to( self, { y = display.contentHeight + self.contentHeight * 0.5, transition = easing.inOutExpo, onComplete = onComplete } )
			
			transition.to( navBarText, { alpha = 1 } )
			transition.to( settingsButton, { alpha = 1 } )
		end
		
		group.y = display.contentHeight
		
		return group
	end
	
	--
	actionSheet = createActionSheet( mealTypes )
	
	mainGroup:setReferencePoint( display.CenterReferencePoint )
end

return M
