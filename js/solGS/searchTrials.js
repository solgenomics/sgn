/** 
* search trials
*
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/




jQuery(document).ready(function(){ 
 
    var url = window.location.pathname;
    
    if (url.match(/solgs\/search\/trials\/trait\//) != null) {
	var traitId = jQuery("input[name='trait_id']").val();
	url = '/solgs/search/result/populations/' + traitId;
    } else {
	url = '/solgs/search/trials/';
    }

    searchAllTrials(url);               
});


function searchAllTrials(url) {
    
    jQuery("#homepage_message").html('Searching for GS trials..').show();
    
    jQuery.ajax({
        type: 'POST',
        dataType: "json",
        url: url,
        success: function(res) { 
 
            var trialsList = listTrials(res.trials);
            var pagination = res.pagination;
            jQuery("#homepage_message").hide();
            jQuery("#homepage_trials_list").html(trialsList + pagination).show();           
        },
        error: function() {               
            jQuery("#homepage_message").html('Error occured fetching the first set of GS trials.').show();
          
        }

    });
    
  
    jQuery("#homepage_trials_list").on('click', "div.paginate_nav a", function(e) { 
        var page = jQuery(this).attr('href');
       
        jQuery("#homepage_trials_list").empty();
    
        jQuery("#homepage_message").html('Searching for more GS trials..').show(); 
 
        if (page) {
            jQuery.ajax({ 
                type: 'POST',
                dataType: "json",
                url: page,
                success: function(res) {                                                                                 
                    var trialsList = listTrials(res.trials);
                    var pagination = res.pagination;
                    jQuery("#homepage_trials_list").empty();
                    jQuery("#homepage_message").hide(); 
                    jQuery("#homepage_trials_list").html(trialsList + pagination).show();
                  
                },               
                error: function() {
                    jQuery("#homepage_message").html('Error occured fetching the next set of GS trials.').show();
                }                    
            });                
        }

        return false;
    });                

}


function listTrials (trials)  {
    
    jQuery(function() { 
        jQuery("#color_tip")
            .css({display: "inline-block", width: "5em"})
            .tooltip();
    });

    var table = '<table class="table" style="width:100%;text-align:left">';
    table    += '<thead>'
    table    += '<tr>';
    table    += '<th></th><th>Trial</th><th>Description</th><th>Location</th>'
             +  '<th>Year</th><th id="color_tip" title="You can combine trials sharing the same color.">'
             +  'Tip(?)</th>';
    table    += '</tr></thead>';
  
    for (var i=0; i < trials.length; i++) {
      
        if (trials[i]) {
            table += '<tr>';
            table += '<td>' + trials[i][0] + '</td>' 
                +  '<td>' + trials[i][1] + '</td>'
                +  '<td>' + trials[i][2] + '</td>'
                +  '<td>' + trials[i][3] + '</td>'
                +  '<td>' + trials[i][4] + '</td>'
                +  '<td>' + trials[i][5] + '</td>';
		+  '</tr>';
        }
    }
    table += '</table>';
    return table;

}

function checkTrainingPopulation (popId) {

    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/solgs/check/training/population/' + popId,
        success: function(response) {
            if (response.is_training_population) {
		jQuery("#training_pops_message").hide();
		jQuery("#searched_training_pops_list").show();
	
		displayTrainingPopulations(response.training_pop_data);					
            } else {
		jQuery("#training_pops_message").html('<p> Population ' + popId + 'can not be used as a training population.');
		jQuery("#search_all_training_pops").show();	
            }
	}
    });
    
}


jQuery(document).ready( function () {
    
    jQuery('#population_search_entry').keyup(function(e){
     	
	if(e.keycode == 13) {	    
     	    jQuery('#search_training_pop').click();
    	}
    });

    jQuery('#search_training_pop').on('click', function () {
	
	jQuery("#training_pops_message").hide();

	var entry = jQuery('#population_search_entry').val();

	if (entry) {
	    checkPopulationExists(entry);
	}
    });
          
});


function checkPopulationExists (name) {
    
    jQuery("#training_pops_message")
	.html("Checking if trial or training population " + name + " exists...please wait...")
	.show();
    

	jQuery("#homepage_trials_list").empty();
	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
	    data: {'name': name},
            url: '/solgs/check/population/exists/',
            success: function(res) {
            
		if (res.population_id) {
		    checkTrainingPopulation(res.population_id);
		    
		    jQuery('#training_pops_message').html(
			'<p>Checking if the trial or population can be used <br />' 
			    + 'as a training population...please wait...</p>');	
		} else { 		
		    jQuery('#training_pops_message').html(
			'<p>There are no trials or training populations with the name <br />'
			    + 'you searched in the database. <br />' 
			    + 'If you have or want to make a training population ' 
			    + 'using the search wizard, use the form below.</p>'); 			
		}
	    }
	});
    
}




function createTable (tableId) {
    
    var table = '<table id="' + tableId +  '" class="table" style="width:100%;text-align:left">';
    table    += '<thead>'
    table    += '<tr>';
    table    += '<th></th><th>Trial</th><th>Description</th><th>Location</th>'
             +  '<th>Year</th><th id="color_tip" title="You can combine trials sharing the same color.">'
             +  'Tip(?)</th>';
    table    += '</tr></thead></table>';

    return table;

}


function displayTrainingPopulations (data) {
  
    var tableId = 'searched_trials_list'; 
    var tableRows = jQuery('#' + tableId + ' tr').length;
   
    if (tableRows > 1) {
	jQuery('#' + tableId).dataTable().fnAddData(data);
    } else {
	var table = createTable(tableId);
	jQuery('#searched_training_pops_list').html(table).show();
	
	jQuery('#' + tableId).dataTable({
	    'searching' : false,
	    'ordering'  : false,
	    'processing': true,
	    'paging': false,
	    'info': false,
	    'data': data,
	});

    }

}
