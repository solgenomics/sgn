/** 
* search traits
*
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


jQuery(document).ready( function () {
    
     jQuery('#search_trait_entry').keyup(function(e) {     	
     	 if(e.keycode == 13) {	    
      	     jQuery('#search_trait').click();
    	 }
     });

    jQuery('#search_trait').on('click', function () {
	var entry = jQuery('#search_trait_entry').val();

	if (entry) {
	    searchTraits(entry);
	}
    });
          
});


function searchTraits (name) {

    var protocolId = jQuery('#genotyping_protocol_id').val();
  
	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
	    data: {'name': name},
            url: '/solgs/search/traits/' + name,
	    success: function (res) {	
		
		if (res.status) {		
		    window.location = '/solgs/search/result/traits/' + name + '/gp/' + protocolId;
		} else {		    
		    jQuery("#search_trait_message")
			.html('There are no entries for trait: ' + name)
			.show()
			.fadeOut(5000);
		}
	    },	    
	    error: function () {
		jQuery("#search_trait_message")
	    	    .html('Error occured searching for trait ' + name)
	    	    .show()
		    .fadeOut(5000);
		
	    },
	});
    
}
