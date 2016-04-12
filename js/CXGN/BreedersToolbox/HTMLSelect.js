
function get_select_box(type, div_id, options) {

    //alert(JSON.stringify(options));
    jQuery.ajax( {
	url: '/ajax/html/select/'+type,
	data: options ,
	success: function(response) {
	    jQuery('#'+div_id).html(response.select);
	},
	error: function(response) {
	    alert("An error occurred");
	}
    });
}
