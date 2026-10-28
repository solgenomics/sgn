
//JSAN.use('jqueryui');

function isLoggedIn() {

    var user_id;

    jQuery.ajax( {
	url: '/user/logged_in',
	headers: {'X-SGN-Locale': document.documentElement.getAttribute('data-sgn-locale') || document.documentElement.lang || 'en'},
	async: false,
	success: function(response) {
	    if (response.error) {
		alert(response.error);
	    }
	    else {
		//alert("LOGGED IN USER: "+response.person_id);
		user_id =  response.user_id;
	    }
	},
	error: function(response) {
	    alert((window.SGN && SGN.i18n ? SGN.i18n.p("auth.legacy.network_error", "An error occurred. %{error}", {error: String(response)}) : 'An error occurred. ' + response));
	}
    }

	       );

    return user_id;
}

function getUserRoles() {

    var roles;

    jQuery.ajax( {
	url: '/user/get_roles',
	headers: {'X-SGN-Locale': document.documentElement.getAttribute('data-sgn-locale') || document.documentElement.lang || 'en'},
	async: false,
	success: function(response) {
	    if (response.error) {
		alert(response.error);
	    }
	    else {
		//alert("LOGGED IN USER ROLES: "+response.roles);
		roles =  response.roles;
	    }
	},
	error: function(response) {
	    alert((window.SGN && SGN.i18n ? SGN.i18n.p("auth.legacy.network_error", "An error occurred. %{error}", {error: String(response)}) : 'An error occurred. ' + response));
	}
    }

	       );

    return roles;
}

function login() {


}

function logout() {


}


function setUpLogin() {

 var loginButtons = [
    { text: (window.SGN && SGN.i18n ? SGN.i18n.p("auth.login.title", "Login") : "Login"), click: function() { login(); } },
    { text: (window.SGN && SGN.i18n ? SGN.i18n.p("auth.legacy.cancel", "Cancel") : "Cancel"), click: function() { jQuery('#login_window').dialog('close'); } }
 ];

 jQuery('#working').dialog( {
    height: 80,
    width: 100,
    modal: true,
    closeText: (window.SGN && SGN.i18n ? SGN.i18n.p("auth.common.close", "Close") : "Close"),
    title: (window.SGN && SGN.i18n ? SGN.i18n.p("auth.legacy.working", "Working...") : "Working..."),
    closeOnEscape: false,
    autoOpen: false
  });

jQuery('#login_window').dialog( {
    height: 180,
    width: 300,
    modal: true,
    closeText: (window.SGN && SGN.i18n ? SGN.i18n.p("auth.common.close", "Close") : "Close"),
    title: (window.SGN && SGN.i18n ? SGN.i18n.p("auth.login.title", "Login") : "Login"),
    autoOpen: false,
    buttons: loginButtons


  });

}
