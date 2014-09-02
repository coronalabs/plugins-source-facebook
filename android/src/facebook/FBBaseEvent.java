package facebook;

import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaLuaEvent;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeTask;

import com.naef.jnlua.LuaState;

public abstract class FBBaseEvent implements CoronaRuntimeTask {
	protected enum FBType {
		session,
		request,
		dialog
	}

	private static final String EVENT_NAME = "fbconnect";

	private FBType mType;
	private String mResponse;
	private boolean mIsError;

	protected FBBaseEvent(FBType type) {
		mType = type;
		mIsError = false;
		mResponse = null;
	}

	protected FBBaseEvent(FBType type, String response, boolean isError) {
		mType = type;
		mResponse = response;
		mIsError = isError;
	}

	public void executeUsing(CoronaRuntime runtime) {
		LuaState L = runtime.getLuaState();
		CoronaLua.newEvent(L, EVENT_NAME);
		
		L.pushString(mType.name());
		L.setField(-2, "type");

		L.pushBoolean(mIsError);
		L.setField(-2, CoronaLuaEvent.ISERROR_KEY);

		String message = mResponse == null ? "" : mResponse;
		L.pushString(message);
		L.setField(-2, CoronaLuaEvent.RESPONSE_KEY);
	}
}
