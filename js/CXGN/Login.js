
JSAN.use('jqueryui');

function isLoggedIn() { 
    
    var user_id; 

    jQuery.ajax( { 
	url: '/user/logged_in',
	async: false,
	success: function(response) { 
	    if (response.error) { 
		alert(response.error);
	    }
	    else { 
		alert("LOGGED IN USER: "+response.user_id);
		user_id =  response.user_id;
	    }
	},
	error: function(response) { 
	    alert("An error occurred. "+response);
	}
    }
		 
	       );

    return user_id;
}

function login() { 
    
    
}

function logout() { 


}
	    
