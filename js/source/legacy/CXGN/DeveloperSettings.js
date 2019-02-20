/*

=head1 CXGN.DeveloperSettings

 Manages the cookie and key/values for developer settings, on the client side
 This is a singleton object

=head1 Functions

=cut

*/

JSAN.use('CXGN.Cookie');

DeveloperSettings = window.DeveloperSettings || {};

var DeveloperSettings = {
	data: new Object,
	_init: function() {
		DeveloperSettings.parse(Cookie.get('developer_settings'));
	},
/*

=head2 parse( cookie_string )

 Given a cookie_string, parses out key/value relationships and sets
 them to the object (assc. array) DeveloperSettings.data

=cut

*/
	parse: function(cookie_string) {
		cookie_string = decodeURIComponent(cookie_string);
		var kvps = cookie_string.split(':');
		for(var j = 0; j < kvps.length; j++){
			var kv = kvps[j].split('=');
			var k = kv[0];
			var v = kv[1];
			DeveloperSettings.data[k] = v;
		}
	},
/*

=head2 build()
 
 Build and returncookie string from DeveloperSettings.data object (assc. array)

=cut

*/
	build: function() {
		var data = DeveloperSettings.data;
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
		Cookie.set('developer_settings', DeveloperSettings.build(), 1000);	
	},
/* 

=head2 getValue(key)

 Gets the current value for the key in the associative array

=cut

*/
    getValue: function(key) {
		return DeveloperSettings.data[key];
	},
/* 

=head2 setValue(key, value)

 Given a key and value, sets the associative array

=cut

*/
	setValue: function(key,value) {
		DeveloperSettings.data[key] = value;
	}
}

DeveloperSettings._init();
