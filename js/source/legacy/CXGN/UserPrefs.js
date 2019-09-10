/**

=head1 NAME

 CXGN.UserPrefs

=head1 SYNOPSIS

 A javascript module for handling the User Preferences cookie

=head1 AUTHOR

 Christopher Carpita <csc32@cornell.edu>

=cut

*/

JSAN.use("CXGN.Base");
JSAN.use("CXGN.Cookie");
JSAN.use("CXGN.User");
JSAN.use("MochiKit.Logging");

UserPrefs = window.UserPrefs || {};

var UserPrefs = {
	data: new Object,
	_init: function() {
		UserPrefs.parse(Cookie.get('user_prefs'));
	},
/*

=head2 parse( cookie_string )

 Given a cookie_string, parses out key/value relationships and sets
 them to the object (assc. array) UserPrefs.data

=cut

*/
	parse: function(cookie_string) {
		cookie_string = decodeURIComponent(cookie_string);
		var kvps = cookie_string.split(':');
		for(var j = 0; j < kvps.length; j++){
			var kv = kvps[j].split('=');
			var k = kv[0];
			var v = kv[1];
			UserPrefs.data[k] = v;
		}
	},
/*

=head2 build()
 
 Build and returncookie string from UserPrefs.data object (assc. array)

=cut

*/
	build: function() {
		var data = UserPrefs.data;
		var cookie_string = '';
		var i = 0;
		for(key in data){
			if(i>0) cookie_string += ":";
			cookie_string += encodeURIComponent(key) + "=" + encodeURIComponent(data[key])
			i++;
		}
		return encodeURIComponent(cookie_string);
	},
		
/*

=head2 save()

Calls build() and sets this to the cookie

=cut

*/
	save: function() {
		var thisDate = new Date();
 		var base = new Date(0);
   		var skew = base.getTime(); 
		var unix_epoch_time = thisDate.getTime();
     	if (skew > 0)  unix_epoch_time -= skew;  //Steve Jobs had nothing to do with this, apparently
		UserPrefs.setValue('timestamp', unix_epoch_time);
		Cookie.set('user_prefs', UserPrefs.build(), 1000);	
	},
/* 

=head2 getValue(key)

 Gets the current value for the key in the associative array

=cut

*/
    getValue: function(key) {
		return UserPrefs.data[key];
	},
/* 

=head2 setValue(key, value)

 Given a key and value, sets the associative array

=cut

*/
	setValue: function(key,value) {
		UserPrefs.data[key] = value;
	}
}

/**

DEPRECATED CODE that doesn't use double-encoding


var UserPrefs = {
	user_pref_string: '',
	_preferences: new Object,
	_init: function() {
		var user_pref_string = UserPrefs.user_pref_string;
		//the string is initially set server-side, so if we don't get
		//anything, we try the client-side cookie
		if(user_pref_string.length<1) UserPrefs.loadCookie();
	
		if(user_pref_string.length>0 && user_pref_string.indexOf('=') && user_pref_string.indexOf(":")) {
			var pref_array = user_pref_string.split(":");
			for(var n = 0; n < pref_array.length; n++) {
				var key_val = pref_array[n].split("=");
				if(key_val[0].length>0 && key_val[1].length>0){
					UserPrefs._preferences[key_val[0]] = key_val[1];
				}
			}
		}
		UserPrefs.setCookie();

	},	
	setCookie: function() {
		var thisDate = new Date();
 		var base = new Date(0);
   		var skew = base.getTime(); 
		var unix_epoch_time = thisDate.getTime();
     	if (skew > 0)  unix_epoch_time -= skew;  //Steve Jobs had nothing to do with this, apparently
		UserPrefs._preferences.timestamp = unix_epoch_time;
		UserPrefs._preferences.sp_person_id = User.sgn_user_id;
		UserPrefs._preferences.sgn_session_id = User.sgn_session_id;
		UserPrefs._buildString();
		Cookie.set('user_prefs', UserPrefs.user_pref_string, 1000);
	},
	//send will make an AJAX request to the server, writing the cookie string to the database.  neat-o!
	//ONLY use this when you anticipate that the user will set a preference and not load another page.  The page-loading process will update the user_prefs string in the database from the user's cookie.
	send: function() {
		var req = new Request();		
		if(req.isValid()){
			var parameters = "?sgn_session_id=" + User.sgn_session_id + "&user_prefs=" + encodeURIComponent(UserPrefs.user_pref_string); 
			req.sendRequest("/scraps/set_user_prefs.pl", parameters);
			return true;
		}
		return false;
	},
	_response: function(doc) {
		var updated = doc.getElementsByTagName("updated")[0].firstChild.nodeValue;	
		var errmsgtag = doc.getElementsByTagName("errmsg")[0];
		var fatalmsgtag = doc.getElementsByTagName("fatalmsg")[0];
		if(updated) {
			MochiKit.Logging.log("UserPref setting successful");
		}
		else {
			MochiKit.Logging.logError("UserPref setting failed!");
			if(errmsgtag){
				MochiKit.Logging.logError("\n"+errmsgtag.firstChild.nodeValue);
			}
			if(fatalmsgtag){
				MochiKit.Logging.logFatal("\n"+fatalmsgtag.firstChild.nodeValue);
			}
		}
	},

	loadCookie: function() {
		UserPrefs.user_pref_string = Cookie.get('user_prefs');
	},
	_buildString: function() {
		var new_string = '';
		var i = 0;
		for(var name in UserPrefs._preferences){
			if(i>0) new_string += ":";
			new_string += name + "=" + UserPrefs._preferences[name];
			i++;
		}
		UserPrefs.user_pref_string = new_string;
	},
	set: function(name, value) {
		UserPrefs._preferences[name] = value;
	},
	get: function(name) {
		return UserPrefs._preferences[name];
	}
}
UserPrefs._init();

**/


