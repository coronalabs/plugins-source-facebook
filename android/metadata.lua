local metadata =
{
	plugin =
	{
		format = 'jar',
		manifest = 
		{
			permissions = {},
			usesPermissions =
			{
				"android.permission.INTERNET",
			},
			usesFeatures = {},
			applicationChildElements =
			{
				-- Array of strings
				[[
		<activity android:name="com.facebook.LoginActivity"
				  android:theme="@android:style/Theme.NoTitleBar.Fullscreen" 
				  android:configChanges="keyboardHidden|screenSize|orientation"/>
		<activity android:name="facebook.FacebookFragmentActivity"
				  android:theme="@android:style/Theme.NoTitleBar.Fullscreen" 
				  android:configChanges="keyboardHidden|screenSize|orientation"/>]],
			},
		},
	},
}

return metadata