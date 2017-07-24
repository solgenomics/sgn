
function get_select_box(type, div_id, options) {

    //alert(JSON.stringify(options));
    jQuery.ajax( {
	url: '/ajax/html/select/'+type,
	data: options ,
    beforeSend: function(){
        var html = '<div class="well well-sm"><center><img src="/img/wheel.gif" /></center></div>';
        jQuery('#'+div_id).html(html);
    },
	success: function(response) {
      jQuery('#'+div_id).empty();
	    jQuery('#'+div_id).html(response.select);
	},
	error: function(response) {
	    alert("An error occurred");
	}
    });
}
