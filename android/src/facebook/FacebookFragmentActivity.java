package facebook;

import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeTask;
import com.ansca.corona.ViewManager;

import android.location.Location;
import android.location.LocationManager;
import android.widget.FrameLayout;
import android.view.ViewGroup.LayoutParams;
import android.os.Bundle;
import android.view.inputmethod.InputMethodManager;
import android.content.Context;
import android.view.ViewGroup;

import java.util.Iterator;
import java.util.List;

import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentActivity;
import android.support.v4.app.FragmentTransaction;

import com.facebook.widget.PlacePickerFragment;
import com.facebook.widget.UserSettingsFragment;
import com.facebook.widget.PickerFragment;
import com.facebook.widget.FriendPickerFragment;

import com.facebook.model.GraphPlace;
import com.facebook.model.GraphLocation;
import com.facebook.model.GraphUser;

import com.naef.jnlua.LuaState;
import com.ansca.corona.Controller;

public class FacebookFragmentActivity extends FragmentActivity {
	public static final String FRAGMENT_NAME = "fragment_name";
	public static final String FRAGMENT_LISTENER = "fragment_listener";
	public static final String FRAGMENT_EXTRAS = "fragment_extras";

	private static final int CONTENT_VIEW_ID = 192875;
	private PickerFragment mFragment;
	private int mListener;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		FrameLayout frame = new FrameLayout(this);
		frame.setId(CONTENT_VIEW_ID);
		setContentView(frame, new LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));

		String fragmentToLaunch = getIntent().getExtras().getString(FRAGMENT_NAME);
		mListener = getIntent().getExtras().getInt(FRAGMENT_LISTENER);

		Bundle extraInfo = getIntent().getBundleExtra(FRAGMENT_EXTRAS);

		mFragment = null;
		if (fragmentToLaunch.equals("place")) {
			PlacePickerFragment placePicker = new PlacePickerFragment();
			mFragment = placePicker;
			
			String titleText = extraInfo.getString("title");
			if (titleText != null) {
				placePicker.setTitleText(titleText);
			}

			String searchText = extraInfo.getString("searchText");
			if (searchText != null) {
				placePicker.setSearchText(searchText);
			}

			String latitude = extraInfo.getString("latitude");
			String longitude = extraInfo.getString("longitude");
			if (latitude != null && longitude != null) {
				Location location = new Location(LocationManager.PASSIVE_PROVIDER);
				try {
					location.setLatitude(Double.parseDouble(latitude));
					location.setLongitude(Double.parseDouble(longitude));
					placePicker.setLocation(location);
				} catch (NumberFormatException e) {

				}
			}

			String resultsLimit = extraInfo.getString("resultsLimit");
			if (resultsLimit != null) {
				try {
					placePicker.setResultsLimit(Double.valueOf(resultsLimit).intValue());
				} catch (NumberFormatException e) {
				}
			}

			String radiusInMeters = extraInfo.getString("radiusInMeters");
			if (radiusInMeters != null) {
				try {
					placePicker.setRadiusInMeters(Double.valueOf(radiusInMeters).intValue());
				} catch (NumberFormatException e) {
				}
			}

			placePicker.setOnSelectionChangedListener(new PickerFragment.OnSelectionChangedListener() {
				@Override
				//You can only pick 1 location so we can finish right after its picked
				public void onSelectionChanged(PickerFragment<?> fragment) {
					GraphPlace graphPlace = ((PlacePickerFragment)fragment).getSelection();
					if ( graphPlace != null) {
						pushPlaceSelection(graphPlace);
					}

					InputMethodManager imm = (InputMethodManager)getSystemService(Context.INPUT_METHOD_SERVICE);
					imm.hideSoftInputFromWindow(((ViewGroup)fragment.getActivity().getWindow().getDecorView()).getApplicationWindowToken(), 0);

					finish();
				}
			});
			placePicker.setOnDoneButtonClickedListener(new PickerFragment.OnDoneButtonClickedListener() {
				@Override
				public void onDoneButtonClicked(PickerFragment<?> fragment) {
					GraphPlace graphPlace = ((PlacePickerFragment)fragment).getSelection();
					if (graphPlace != null) {
						pushPlaceSelection(graphPlace);
					}

					InputMethodManager imm = (InputMethodManager)getSystemService(Context.INPUT_METHOD_SERVICE);
					imm.hideSoftInputFromWindow(((ViewGroup)fragment.getActivity().getWindow().getDecorView()).getApplicationWindowToken(), 0);

					finish();
				}
			});
			
		} else if (fragmentToLaunch.equals("friends")) {
			Bundle args = new Bundle();
			mFragment = new FriendPickerFragment(args);
			((FriendPickerFragment)mFragment).setOnDoneButtonClickedListener(new PickerFragment.OnDoneButtonClickedListener() {
				@Override
				public void onDoneButtonClicked(PickerFragment<?> fragment) {
					//Does not return null so no need to do a null check
					List<GraphUser> friendsSelection = ((FriendPickerFragment)fragment).getSelection();
					
					pushFriendSelection(friendsSelection);
					
					finish();
				}
			});
		}

		FragmentTransaction fragmentTransaction = getSupportFragmentManager().beginTransaction();
		fragmentTransaction.add(CONTENT_VIEW_ID, mFragment).commit();
	}

	private void pushFriendSelection(final List<GraphUser> friendsSelection) {
		CoronaRuntimeTask task = new CoronaRuntimeTask() {
			@Override
			public void executeUsing(CoronaRuntime runtime) {
				if (runtime != null && friendsSelection != null && mListener>0) {
					LuaState L = runtime.getLuaState();
					if (L != null) {
						CoronaLua.newEvent( L, "friends");
						Iterator<GraphUser> iterator = friendsSelection.iterator();
						
						//event.data
						L.newTable(0, friendsSelection.size());

						GraphUser graphUser;
						int index = 1;
						while(iterator.hasNext()) {
							graphUser = iterator.next();
							pushGraphUser(L, graphUser, index);
							index++;
						}
						
						L.setField(-2, "data");

						try {
							CoronaLua.dispatchEvent( L, mListener, 0 );
							CoronaLua.deleteRef(L, mListener);	
						} catch (Exception e) {

						}
					}
				}
			}

			private void pushGraphUser(LuaState L, GraphUser graphUser, int index) {
				L.newTable(0, 4);

				pushStringIfNotNull(L, graphUser.getFirstName(), "firstName");

				pushStringIfNotNull(L, graphUser.getLastName(), "lastName");

				pushStringIfNotNull(L, graphUser.getName(), "fullName");

				pushStringIfNotNull(L, graphUser.getId(), "id");

				L.rawSet(-2, index);
			}
		};
		com.ansca.corona.CoronaEnvironment.getCoronaActivity().getRuntimeTaskDispatcher().send(task);
	}

	private void pushPlaceSelection(final GraphPlace placeSelection) {
		CoronaRuntimeTask task = new CoronaRuntimeTask() {
			@Override
			public void executeUsing(CoronaRuntime runtime) {
				if (runtime != null && placeSelection != null && mListener>0) {
					LuaState L = runtime.getLuaState();
					if (L != null) {
						CoronaLua.newEvent( L, "place");

						//event.data
						L.newTable(0, 11);

						pushStringIfNotNull(L, placeSelection.getCategory(), "category");
						
						pushStringIfNotNull(L, placeSelection.getId(), "id");
						
						pushStringIfNotNull(L, placeSelection.getName(), "name");
						
						GraphLocation graphLocation = placeSelection.getLocation();
						if (graphLocation != null) {
							pushStringIfNotNull(L, graphLocation.getCity(), "city");
							
							pushStringIfNotNull(L, graphLocation.getCountry(), "country");
							
							pushStringIfNotNull(L, graphLocation.getState(), "state");
							
							pushStringIfNotNull(L, graphLocation.getStreet(), "street");
							
							pushStringIfNotNull(L, graphLocation.getZip(), "zip");

							L.pushNumber(graphLocation.getLatitude());
							L.setField(-2, "latitude");

							L.pushNumber(graphLocation.getLongitude());
							L.setField(-2, "longitude");							
						}
						
						L.setField(-2, "data");

						try {
							CoronaLua.dispatchEvent( L, mListener, 0 );
							CoronaLua.deleteRef(L, mListener);	
						} catch (Exception e) {

						}
					}
				}
			}
		};
		com.ansca.corona.CoronaEnvironment.getCoronaActivity().getRuntimeTaskDispatcher().send(task);
	}

	private void pushStringIfNotNull(LuaState L, String pushString, String field) {
		if (pushString != null) {
			L.pushString(pushString);
			L.setField(-2, field);
		}
	}

	@Override
	protected void onStart() {
		super.onStart();
		try {
			// Load data, unless a query has already taken place.
			mFragment.loadData(false);
		} catch (Exception ex) {
			
		}
	}
}
