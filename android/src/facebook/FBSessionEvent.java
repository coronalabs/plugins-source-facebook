package facebook;

import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaLuaEvent;
import com.ansca.corona.CoronaRuntime;

import com.naef.jnlua.LuaState;

public class FBSessionEvent extends FBBaseEvent {
	public enum Phase {
		login,
		loginFailed,
		loginCancelled,
		logout
	}

	private long mExpirationTime;
	private String mToken;
	private Phase mPhase;

	public FBSessionEvent(String token, long expirationTime) {
		super(FBType.session);
		mPhase = Phase.login;
		mToken = token;
		mExpirationTime = expirationTime;
	}

	public FBSessionEvent(Phase phase) {
		super(FBType.session);
		mPhase = phase;
		mToken = null;
		mExpirationTime = 0;
	}

	public FBSessionEvent(Phase phase, String errorMessage) {
		super(FBType.session, errorMessage, true);
		mPhase = phase;
		mToken = null;
		mExpirationTime = 0;
	}

	public void executeUsing(CoronaRuntime runtime) {
		super.executeUsing(runtime);

		LuaState L = runtime.getLuaState();

		L.pushString(mPhase.name());
		L.setField(-2, "phase");

		if (mToken != null) {
			L.pushString(mToken);
			L.setField(-2, "token");

			L.pushNumber((new Long(mExpirationTime).doubleValue()));
			L.setField(-2, "expiration");
		}
	}
}
