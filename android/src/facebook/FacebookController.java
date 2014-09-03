package facebook;

import com.ansca.corona.Controller;
import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;

import com.ansca.corona.events.EventManager;

import java.util.Arrays; 
import java.util.Hashtable;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.naef.jnlua.LuaState;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.net.Uri;

import com.facebook.HttpMethod;
import com.facebook.Settings;
import com.facebook.Session;
import com.facebook.SessionLoginBehavior;
import com.facebook.SessionState;
import com.facebook.Request;
import com.facebook.Response;
import com.facebook.widget.WebDialog;
import com.facebook.FacebookOperationCanceledException;
import com.facebook.FacebookException;

public class FacebookController {
	private static int mListener;

	private static class FacebookEventHandler implements Session.StatusCallback{
		private String mPermissions[];
		private CoronaRuntime mCoronaRuntime;

		public FacebookEventHandler( CoronaRuntime runtime, String permissions[] ) {
			mPermissions = permissions;
			mCoronaRuntime = runtime;
		}

		@Override
		public void call(Session session, SessionState state, Exception exception) {
			//The session was successfully opened
			if (state == SessionState.OPENED || state == SessionState.OPENED_TOKEN_UPDATED) {
				List<String> permissions = new LinkedList<String>();
				boolean readPermissions = false;

				// Look for read permissions so we can request them
				if (mPermissions != null) {
					for(int i = 0; i<mPermissions.length; i++) {
						//Changed this in the facebook sdk from default to public so we can use it here
						if(!Session.isPublishPermission(mPermissions[i]) && mPermissions[i] != null) {
							permissions.add(mPermissions[i]);
							mPermissions[i] = null;
							readPermissions = true;
						}
					}

					// If there are no read permissions then we move on to publish permissions so we can request them
					if (permissions.isEmpty()) {
						for(int i = 0; i<mPermissions.length; i++) {
							//Changed this in the facebook sdk from default to public so we can use it here
							if(Session.isPublishPermission(mPermissions[i]) && mPermissions[i] != null) {
								permissions.add(mPermissions[i]);
								mPermissions[i] = null;
							}
						}
					}
				}

				CoronaActivity myActivity = com.ansca.corona.CoronaEnvironment.getCoronaActivity();
				if (myActivity == null) {
					return;
				}

				// If there are some permissions we haven't requested yet then we request them and set this object as the callback so we can request the next set of permissions
				if (!permissions.isEmpty()) {
					// This part is to request additional permissions
					Session.NewPermissionsRequest permissionRequest = new Session.NewPermissionsRequest(myActivity, permissions);
					permissionRequest.setLoginBehavior(SessionLoginBehavior.SSO_WITH_FALLBACK);
					permissionRequest.setCallback(this);

					int requestCode = myActivity.registerActivityResultHandler(new FacebookLoginActivityResultHandler());
					permissionRequest.setRequestCode(requestCode);

					if (readPermissions) {
						session.requestNewReadPermissions(permissionRequest);
					} else {
						session.requestNewPublishPermissions(permissionRequest);
					}

					// Since we're still requesting permissions then we don't want to go back to the lua side yet
					return;
				}

				// When we reach here we're done with requesting permissions so we can go back to the lua side
				mCoronaRuntime.getTaskDispatcher().send(new FBConnectTask(
									mListener,
									FBSessionEvent.Phase.login,
									session.getAccessToken(),
									session.getExpirationDate().getTime()));

			} else if (state == SessionState.CLOSED) { //The session was closed from a logout
				mCoronaRuntime.getTaskDispatcher().send(new FBConnectTask(mListener, FBSessionEvent.Phase.logout, null, 0));

			} else if (state == SessionState.CLOSED_LOGIN_FAILED && //The login failed because it was cancelled
					   exception != null && 
					   exception.getClass().equals(FacebookOperationCanceledException.class)) {

				mCoronaRuntime.getTaskDispatcher().send(new FBConnectTask(mListener,FBSessionEvent.Phase.loginCancelled, null, 0));

			} else if (exception != null) {//Something bad happend
				mCoronaRuntime.getTaskDispatcher().send(new FBConnectTask(mListener,exception.getLocalizedMessage()));
			}
		}
	}

	public static void facebookLogin(CoronaRuntime runtime, final String appId, int listener, final String permissions[])
	{
		CoronaActivity myActivity = com.ansca.corona.CoronaEnvironment.getCoronaActivity();
		if (myActivity == null) {
			return;
		}

		mListener = listener;

		// Throw an exception if this application does not have the internet permission.  Without it the webdialogs won't show.
		android.content.Context context = CoronaEnvironment.getApplicationContext();
		if (context != null) {
			context.enforceCallingOrSelfPermission(android.Manifest.permission.INTERNET, null);
		}
		
		if (Session.getActiveSession() == null || Session.getActiveSession().isClosed()) 
		{
			Session mySession = new Session.Builder(myActivity).setApplicationId(appId).build();
			Session.setActiveSession(mySession);
			Session.OpenRequest request = new Session.OpenRequest(myActivity);
			
			request.setLoginBehavior(SessionLoginBehavior.SSO_WITH_FALLBACK);

			int requestCode = myActivity.registerActivityResultHandler(new FacebookLoginActivityResultHandler());
			request.setRequestCode(requestCode);

			mySession.addCallback(new FacebookEventHandler(runtime, permissions));

			mySession.openForRead(request);

		}
		else
		{
			Session mySession = Session.getActiveSession();

			//Remove the permissions we already have access to so that we don't try to get access to them again
			//causing constant flashes on the screen
			List<String> grantedPermissions = mySession.getPermissions();
			for (int i = 0; i < permissions.length; i++) {
				if (grantedPermissions.contains(permissions[i])) {
					permissions[i] = null;
				}
			}

			new FacebookEventHandler(runtime, permissions).call(mySession, mySession.getState(), null);
		}
	}
	
	private static class FacebookLoginActivityResultHandler implements CoronaActivity.OnActivityResultHandler {
		@Override
		public void onHandleActivityResult(CoronaActivity activity, int responseCode, int resultCode, Intent data) 
		{
			activity.unregisterActivityResultHandler(this);
			Session mySession = Session.getActiveSession();
			if (mySession != null) {
				mySession.onActivityResult(activity, responseCode, resultCode, data);
			}
			
		}
	}

	public static void facebookLogout()
	{
		Session mySession = Session.getActiveSession();
		if (mySession != null) {
			mySession.closeAndClearTokenInformation();
		}
	}

	public static void facebookRequest( CoronaRuntime runtime, String path, String method, Hashtable params )
	{
		CoronaActivity myActivity = com.ansca.corona.CoronaEnvironment.getCoronaActivity();
		if (myActivity == null) {
			return;
		}

		Session mySession = Session.getActiveSession();
		Request myRequest = new Request(mySession, path, createFacebookBundle(params), HttpMethod.valueOf(method));
		myRequest.setCallback(new FacebookRequestCallbackListener(runtime));

		final Request finalRequest = myRequest;

		//The facebook documentation says this should only be run on the UI thread
		myActivity.runOnUiThread( new Runnable() {
			@Override
			public void run() {
				finalRequest.executeAsync();
			}
		});
	}

	private static class FacebookRequestCallbackListener implements Request.Callback 
	{
		CoronaRuntime fCoronaRuntime;

		FacebookRequestCallbackListener(CoronaRuntime runtime) {
			fCoronaRuntime = runtime;
		}

		@Override
		public void onCompleted(Response response)
		{
			if (fCoronaRuntime.isRunning() && response != null) {
				if (response.getError() != null) {
					fCoronaRuntime.getTaskDispatcher().send(new FBConnectTask(mListener, response.getError().getErrorMessage(), true));
				} else {
					String message = "";

					if (response.getGraphObject() != null && 
						response.getGraphObject().getInnerJSONObject() != null && 
						response.getGraphObject().getInnerJSONObject().toString() != null) {
						
						message = response.getGraphObject().getInnerJSONObject().toString();
					}
					fCoronaRuntime.getTaskDispatcher().send(new FBConnectTask(mListener, message, false));
				}
				
			}
		}
	}

	private static class FacebookWebDialogOnCompleteListener implements WebDialog.OnCompleteListener
	{
		CoronaRuntime fCoronaRuntime;

		FacebookWebDialogOnCompleteListener(CoronaRuntime runtime) {
			fCoronaRuntime = runtime;
		}

		public void onComplete(Bundle bundle, FacebookException error)
		{
			if (fCoronaRuntime.isRunning()) {
				if (error == null) {
					Uri.Builder builder = new Uri.Builder();
					builder.authority("success");
					builder.scheme("fbconnect");
					for(String bundleKey : bundle.keySet()) {
						String value = bundle.getString(bundleKey);
						value = value == null ? "" : value;
						builder.appendQueryParameter(bundleKey, value);
					}

					fCoronaRuntime.getTaskDispatcher().send(new FBConnectTask(mListener, builder.build().toString(), false, true));
				} else {
					fCoronaRuntime.getTaskDispatcher().send(new FBConnectTask(mListener, error.getLocalizedMessage(), true, false));
				}
			}
		}
	}
	
	public static void facebookDialog( final CoronaRuntime runtime, final android.content.Context context, final String action, final Hashtable params )
	{
		//This is out here so that the listener won't disappear while on the other thread
		int listener = -1;
		if (runtime != null) {
			LuaState L = runtime.getLuaState();
			if (L != null && CoronaLua.isListener(L, -1, "")) {
				listener = CoronaLua.newRef(L, -1);
			}
		}

		final int finalListener = listener;

		Handler myHandler = new Handler(Looper.getMainLooper());

		myHandler.post( new Runnable() {
			@Override
			public void run() {
				Session mySession = Session.getActiveSession();
				WebDialog dialog = null;
				//Facebook sdk has a special webdialog builder for feed action
				if(action.equals("feed")) {
					WebDialog.FeedDialogBuilder feedBuilder = new WebDialog.FeedDialogBuilder(context, mySession, createFacebookBundle(params));
					String param = (String)params.get("caption");
					if (param != null) {
						feedBuilder.setCaption(param);
					}
					
					param = (String)params.get("description");
					if (param != null) {
						feedBuilder.setDescription(param);
					}

					param = (String)params.get("from");
					if (param != null) {
						feedBuilder.setFrom(param);
					}

					param = (String)params.get("link");
					if (param != null) {
						feedBuilder.setLink(param);
					}

					param = (String)params.get("name");
					if (param != null) {
						feedBuilder.setName(param);
					}

					param = (String)params.get("picture");
					if (param != null) {
						feedBuilder.setPicture(param);
					}

					param = (String)params.get("source");
					if (param != null) {
						feedBuilder.setSource(param);
					}

					param = (String)params.get("to");
					if (param != null) {
						feedBuilder.setTo(param);
					}

					dialog = feedBuilder.build();
					
				} else if(action.equals("requests") || action.equals("apprequests")) {
					//Facebook sdk has a special webdialog builder for requests action
					WebDialog.RequestsDialogBuilder requestBuilder = new WebDialog.RequestsDialogBuilder(context, mySession, createFacebookBundle(params));
					String param = (String)params.get("data");
					if (param != null) {
						requestBuilder.setData(param);
					}

					param = (String)params.get("message");
					if (param != null) {
						requestBuilder.setMessage(param);
					}

					param = (String)params.get("title");
					if (param != null) {
						requestBuilder.setTitle(param);
					}


					param = (String)params.get("to");
					if (param != null) {
						requestBuilder.setTo(param);
					}
					dialog = requestBuilder.build();
				} else if(action.equals("place") || action.equals("friends")) {
					//There are no webdialog for these
					android.content.Intent intent = new android.content.Intent(context, FacebookFragmentActivity.class);
					intent.putExtra(FacebookFragmentActivity.FRAGMENT_NAME, action);
					intent.putExtra(FacebookFragmentActivity.FRAGMENT_LISTENER, finalListener);
					intent.putExtra(FacebookFragmentActivity.FRAGMENT_EXTRAS, createFacebookBundle(params));
					context.startActivity(intent);
				} else {
					WebDialog.Builder builder = new WebDialog.Builder(context, mySession, action, createFacebookBundle(params));
					dialog = builder.build();
				}

				if (dialog != null) {
					dialog.setOnCompleteListener(new FacebookWebDialogOnCompleteListener(runtime));
					dialog.show();
				}
			}
		});
		
		
	}

	protected static Bundle createFacebookBundle( Hashtable map )
	{
		Bundle result = new Bundle();

		if ( null != map ) {
			Hashtable< String, Object > m = (Hashtable< String, Object >)map;
			Set< Map.Entry< String, Object > > s = m.entrySet();
			if ( null != s ) {
				android.content.Context context = com.ansca.corona.CoronaEnvironment.getApplicationContext();
				com.ansca.corona.storage.FileServices fileServices;
				fileServices = new com.ansca.corona.storage.FileServices(context);
				for ( Map.Entry< String, Object > entry : s ) {
					String key = entry.getKey();
					Object value = entry.getValue();

					if (value instanceof java.io.File) {
						byte[] bytes = fileServices.getBytesFromFile(((java.io.File)value).getPath());
						if (bytes != null) {
							result.putByteArray( key, bytes );
						}
					}
					else if (value instanceof byte[]) {
						result.putByteArray( key, (byte[])value );
					}
					else if (value instanceof String[]) {
						result.putStringArray( key, (String[])value );
					}
					else if (value != null) {
						result.putString( key, value.toString() );
					}
				}
			}
		}
		return result;
	}

	public static void publishInstall( String appId )
	{
		Settings.publishInstallAsync(CoronaEnvironment.getApplicationContext(), appId);
	}
}
