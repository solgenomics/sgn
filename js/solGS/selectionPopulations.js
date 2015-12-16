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
		jQuery("#search_all_selection_pops").show();
		displaySelectionPopulations(response.data);					
            } else { 
		jQuery("#search_all_selection_pops").show();	
            }
	}
    });
    
}

jQuery(document).ready( function () {
    
    jQuery('#population_search_entry').keyup(function(e){
     	
	if(e.keycode == 13) {	    
     	    jQuery('#search_selection_pop').click();
    	}
    });

    jQuery('#search_selection_pop').on('click', function () {
	
	var entry = jQuery('#population_search_entry').val();

	if (entry) {
	    checkSelectionPopulationRelevance(entry);
	}
    });
          
});


// function getSelectionPopulationId (popName) {
        
//     jQuery.ajax({
//         type: 'POST',
//         dataType: 'json',
// 	data: popName,
//         url: '/solgs/get/selection/population/id/',
//         success: function(response) {
//             if (response.selection_pop_id) {
// 		alert('selection pop id: ' + response.selection_pop_id);
// 		return {'selection_pop_id': response.selection_pop_id};
//             } else {
// 		return 0;
// 		jQuery("#search_pops_message")
// 		    .html(popName + " does not exist in the database.")
// 		    .show();	
//             }
// 	}
//     });
    
// }


function checkSelectionPopulationRelevance (popName) {
    
    var trainingPopId  =  getPopulationId();
  
    var combinedPopsId = jQuery("#combo_pops_id").val();
    var dataSetType;
   
    if (combinedPopsId) {
	dataSetType = 'combined populations';
    }

    jQuery("#selection_pops_message")
	.html("Checking if the model can be used on " + popName + "...please wait...")
	.show();

    var popData = {
	'selection_pop_name' : popName, 
	'training_pop_id'    : trainingPopId,
	'data_set_type'      : dataSetType,
    };

    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
	data: popData,
        url: '/solgs/check/selection/population/relevance/',
        success: function(response) {
	    
	    if (response.selection_pop_id) {
		
		if (response.similarity >= 0.5 ) {
		    
		    jQuery("#selection_pops_message").hide();
		    jQuery("#selection_populations").show();
		    
		    displaySelectionPopulations(response.selection_pop_data);				
		} else { 
		    
		    jQuery("#selection_pops_message")
			.html(popName +" is genotyped by a marker set different  " 
			      + "from the one used for the training population. "
			      + "Therefore you can not predict its GEBVs using this model.")
			.show();	
		}
	    } else {
		
		jQuery("#selection_pops_message")
		    .html(popName + " does not exist in the database.")
		    .show();
	    }
	},
	error: function (response) {

	    jQuery("#selection_pops_message")
		    .html("Error occured processing the query.")
		    .show();  
	}
    });
    
}



function searchSelectionPopulations () {
    
    var popId = getPopulationId();
   
    var combinedPopsId = jQuery("#combo_pops_id").val();
    var dataSetType;
   
    if (combinedPopsId) {
	dataSetType = 'combined populations';
    }
    
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
	data: {'data_set_type': dataSetType},
        url: '/solgs/search/selection/populations/' + popId,
        success: function(res) {
            
	    if (res.data) {
		
		jQuery('#selection_populations').show();
		displaySelectionPopulations(res.data);
		jQuery('#search_all_selection_pops').hide();
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
  
    var tableRow = jQuery('#selection_pops_list tr').length;
   
    if (tableRow === 1) {
    
	jQuery('#selection_pops_list').dataTable({
	    'searching' : false,
	    'ordering'  : false,
	    'processing': true,
	    'paging': false,
	    'info': false,
	    "data": data
	});

    } else {
	
	jQuery('#selection_pops_list').dataTable().fnAddData(data);
    }
}


jQuery(document).ready( function() { 

    jQuery("#search_all_selection_pops").click(function() {
        
	searchSelectionPopulations();
	jQuery("#selection_pops_message")
	    .html("<br/><br/>Searching for all selection populations relevant to this model...please wait...");
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







