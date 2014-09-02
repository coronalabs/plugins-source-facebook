package facebook;

import com.ansca.corona.CoronaLua;
import com.naef.jnlua.LuaState;

public class FBConnectTask implements com.ansca.corona.CoronaRuntimeTask {
	private static final int SESSION = 0;
	private static final int SESSION_ERROR= 1;
	private static final int REQUEST = 2;

	private int myListener;
	private int myType; 
	private FBSessionEvent.Phase myPhase;
	private String myAccessToken;
	private long myTokenExpiration;
	private String myMsg;
	private boolean myIsError;
	private boolean myDidComplete;
	private boolean myIsDialog;
	
	FBConnectTask( int listener, FBSessionEvent.Phase phase, String accessToken, long tokenExpiration )
	{
		myType = SESSION;
		myPhase = phase;
		myAccessToken = accessToken;

		// On Android, FB provides UNIX timestamp in milliseconds
		// We want it in seconds:
		myTokenExpiration = tokenExpiration / 1000;
		myListener = listener;
		myIsDialog = false;
	}

	FBConnectTask( int listener, String msg )
	{
		myType = SESSION_ERROR;
		myAccessToken = "";
		myMsg = msg;
		myTokenExpiration = 0;
		myListener = listener;
		myIsDialog = false;
	}

	FBConnectTask( int listener, String msg, boolean isError )
	{
		myType = REQUEST;
		myAccessToken = "";
		myTokenExpiration = 0;
		myMsg = msg;
		myIsError = isError;
		myDidComplete = false;
		myListener = listener;
		myIsDialog = false;
	}

	FBConnectTask( int listener, String msg, boolean isError, boolean didComplete )
	{
		myType = REQUEST;
		myAccessToken = "";
		myTokenExpiration = 0;
		myMsg = msg;
		myIsError = isError;
		myDidComplete = didComplete;
		myListener = listener;
		myIsDialog = true;
	}

	@Override
	public void executeUsing(com.ansca.corona.CoronaRuntime runtime) {
		switch ( myType ) {
			case SESSION:
				if (myAccessToken != null) {
					(new FBSessionEvent(myAccessToken, myTokenExpiration)).executeUsing(runtime);
				} else {
					(new FBSessionEvent(myPhase)).executeUsing(runtime);
				}
				break;
			case SESSION_ERROR:
				(new FBSessionEvent(FBSessionEvent.Phase.loginFailed, myMsg)).executeUsing(runtime);
		    	break;
			case REQUEST:
				if (myIsDialog) {
					(new FBDialogEvent(myMsg, myIsError, myDidComplete)).executeUsing(runtime);
				} else {
					(new FBRequestEvent(myMsg, myIsError, myDidComplete)).executeUsing(runtime);
				}
				
				break;
			default:
				break;
		}

		try {
			LuaState L = runtime.getLuaState();
			CoronaLua.dispatchEvent( L, myListener, 0 );
		} catch (Exception e) {

		}
	}

}
