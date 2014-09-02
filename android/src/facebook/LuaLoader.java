//
//  LuaLoader.java
//  AdsProvider Plugin
//
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

// TODO: Rename 'myAdsProvider' to the name of the actual provider
package facebook;

import com.naef.jnlua.LuaState;
import com.naef.jnlua.LuaType;
import com.naef.jnlua.JavaFunction;
import com.naef.jnlua.NamedJavaFunction;

import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaLuaEvent;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeListener;
import com.ansca.corona.CoronaRuntimeTaskDispatcher;
import com.ansca.corona.CoronaRuntimeProvider;

import java.util.ArrayList;
import java.util.Hashtable;

public class LuaLoader implements JavaFunction {
	private CoronaRuntime mRuntime;

	/**
	 * Creates a new object for displaying banner ads on the CoronaActivity
	 */
	public LuaLoader() {
		CoronaActivity activity = CoronaEnvironment.getCoronaActivity();

		// Validate.
		if (activity == null) {
			throw new IllegalArgumentException("Activity cannot be null.");
		}
	}

	/**
	 * Warning! This method is not called on the main UI thread.
	 */
	@Override
	public int invoke(LuaState L) {
		mRuntime = CoronaRuntimeProvider.getRuntimeByLuaState(L);

		NamedJavaFunction[] luaFunctions = new NamedJavaFunction[] {
			new LoginWrapper(),
			new LogoutWrapper(),
			new PublishInstallWrapper(),
			new RequestWrapper(),
			new ShowDialogWrapper(),
		};

		String libName = L.toString( 1 );
		L.register(libName, luaFunctions);

		return 1;
	}

	private class LoginWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "login";
		}
		
		@Override
		public int invoke(LuaState L) {
			int index = 1;

			String appId = L.toString(index);
			index++;

			int listener = CoronaLua.REFNIL;
			if (CoronaLua.isListener(L, 2, "fbconnect")) {
				listener = CoronaLua.newRef( L, 2 );
			}
			index++;

			ArrayList<String> permissions = new ArrayList<String>();
			if (L.type(index) == LuaType.TABLE) {
				int arrayLength = L.length(index);
				for (int i = 1; i <= arrayLength; i++) {
					L.rawGet(index, i);
					permissions.add(L.toString(-1));
					L.pop(1);
				}
			}

			FacebookController.facebookLogin(mRuntime, appId, listener, permissions.toArray(new String[1]));
			return 0;
		}
	}

	private class LogoutWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "logout";
		}
		
		@Override
		public int invoke(LuaState L) {
			FacebookController.facebookLogout();
			return 0;
		}
	}

	private class PublishInstallWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "publishInstall";
		}
		
		@Override
		public int invoke(LuaState L) {
			String appId = L.toString(-1);
			FacebookController.publishInstall(appId);
			return 0;
		}
	}

	private class RequestWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "request";
		}
		
		@Override
		public int invoke(LuaState L) {
			int index = 1;

			String path = L.toString(index);
			index++;

			String method = "GET";
			if (L.type(index) == LuaType.STRING) {
				method = L.toString(index);
			}
			index++;

			Hashtable params = null;
			if (L.type(index) == LuaType.TABLE) {
				params = CoronaLua.toHashtable(L, index);
			} else {
				params = new Hashtable();
			}
			index++;

			FacebookController.facebookRequest(mRuntime, path, method, params);

			return 0;
		}
	}

	private class  ShowDialogWrapper implements NamedJavaFunction {
		@Override
		public String getName() {
			return "showDialog";
		}
		
		@Override
		public int invoke(LuaState L) {
			CoronaActivity activity = CoronaEnvironment.getCoronaActivity();
			if (activity == null) {
				throw new IllegalArgumentException("Activity cannot be null.");
			}

			int index = 1;

			String action = L.toString(index);
			index++;

			Hashtable params = null;
			if (L.type(index) == LuaType.TABLE) {
				params = CoronaLua.toHashtable(L, index);
			}
			index++;

			FacebookController.facebookDialog(mRuntime, activity, action, params);

			return 0;
		}
	}
}