
function get_select_box(type, div_id, name) { 
    
    jQuery.ajax( { 
	url: '/ajax/html/select/'+type,
	data: { 'name' : name },
	success: function(response) { 
	    jQuery('#'+div_id).html(response.select);
	},
	error: function(response) { 
	    alert("An error occurred");
	}
    });
}


	
