package facebook;

import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaLuaEvent;
import com.ansca.corona.CoronaRuntime;

import com.naef.jnlua.LuaState;

public class FBDialogEvent extends FBBaseEvent {

	private boolean mDidComplete;

	public FBDialogEvent(String response, boolean isError, boolean didComplete) {
		super(FBType.dialog, response, isError);
		mDidComplete = didComplete;
	}

	public void executeUsing(CoronaRuntime runtime) {
		super.executeUsing(runtime);

		LuaState L = runtime.getLuaState();

		L.pushBoolean(mDidComplete);
		L.setField(-2, "didComplete");
	}
}
