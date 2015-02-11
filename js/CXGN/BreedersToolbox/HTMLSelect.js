
function get_select_box(type, div_id, name) { 
    
    jQuery.ajax( { 
	url: '/ajax/html/select/'+type,
	data: { 'name' : name },
	success: function(response) { 
	    alert(response.select);
	    jQuery('#'+div_id).html(response.select);
	},
	error: function(response) { 
	    alert("An error occurred");
	}
    });
}


	
