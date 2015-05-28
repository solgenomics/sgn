/** 
* search and display selection populations
* relevant to a training population.
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/



jQuery(document).ready( function () {
    
    checkSelectionPopulations();
          
});


function checkSelectionPopulations () {
    
    var popId =  getPopulationId();
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/solgs/check/selection/populations/' + popId,
        success: function(response) {
            if (response.data) {
		jQuery("#selection_populations").show();
		displaySelectionPopulations(response.data);					
            } else { 
		jQuery("#search_selection_pops").show();	
            }
	}
    });
    
}


function searchSelectionPopulations () {
    var popId = getPopulationId();
  
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/solgs/search/selection/populations/' + popId,
        success: function(res) {
            if (res.data) {
		jQuery('#selection_populations').show();
		displaySelectionPopulations(res.data);
		jQuery('#search_selection_pops').hide();
		jQuery('#selection_pops_message').hide();
            } else { 
		jQuery('#selection_pops_message').html(
		    '<p>There are no relevant selection populations in the database.' 
                    + 'If you have or want to make your own set of selection candidates' 
                    + 'use the form below.</p>');	
            }
	}
    });
}


function displaySelectionPopulations (data) {
    jQuery('#selection_pops_list').dataTable({
	'searching' : false,
	'ordering'  : false,
	'processing': true,
	'paging': false,
	'info': false,
	"data": data
    });
}


jQuery(document).ready( function() { 

    jQuery("#search_selection_pops").click(function() {
        searchSelectionPopulations();
	jQuery("#selection_pops_message").html("<br/><br/>Searching for relevant selection populations...");
    }); 
  
});


function getPopulationId () {

    var populationId = jQuery("#population_id").val();
  
    if (!populationId) {       
        populationId = jQuery("#model_id").val();
    }

    if (!populationId) {
        populationId = jQuery("#combo_pops_id").val();
    }

    return populationId;
        
}







