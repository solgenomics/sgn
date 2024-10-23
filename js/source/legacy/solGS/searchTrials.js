/**
* search trials
*
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/



var solGS = solGS || function solGS () {};

solGS.searchTrials = {

msgDiv: "#searched_trials_message",

searchAllTrials: function(url, result) {

    jQuery("#all_trials_search_message").html('Searching for GS trials..').show();

    var traitTrials = jQuery.ajax({
        type: 'POST',
        dataType: "json",
        url: url,
        data: {'show_result': result},
        cache: true,
    });


	return  traitTrials;

    // jQuery("#all_trials_div").on('click', "div.paginate_nav a", function(e) {
    //     var page = jQuery(this).attr('href');

    //     jQuery("#all_trials_div").empty();

    //     jQuery("#all_trials_search_message").html('Searching for more GS trials..').show();

    //     if (page) {
    //         jQuery.ajax({
    //             type: 'POST',
    //             dataType: "json",
    //             url: page,
    //             success: function(res) {
	// 	    solGS.searchTrials.listAllTrials(res.trials)
    //                 var pagination = res.pagination;
    //                 jQuery("#all_trials_search_message").hide();
	// 	    jQuery("#all_trials_div").append(pagination);
    //             },
    //             error: function() {
    //                 jQuery("#all_trials_search_message").html('Error occured fetching the next set of GS trials.').show();
    //             }
    //         });
    //     }

    //     return false;
    // });

},


listAllTrials: function (trials)  {

    if (trials) {
	var tableId = '#all_trials_table';
	var allTrialsDivId   = '#all_trials_div';

	var tableDetails = {
	    'divId'  : allTrialsDivId,
	    'tableId': tableId,
	    'data'   : trials
	};

	jQuery('#searched_trials_div').empty();
	jQuery(allTrialsDivId).empty();

	this.displayTrainingPopulations(tableDetails);

    } else {
		jQuery("#all_trials_search_message").html('No trials to show.').show();
    }

},


checkTrainingPopulation: function(popIds) {
    var protocolId = jQuery('#genotyping_protocol_id').val();

	console.log(`checkTrainingPopulation protocolId: ${protocolId}`)
  	var args = {'population_ids': popIds, 'genotyping_protocol_id': protocolId };
	args = JSON.stringify(args);

    var checkTrainingPop = jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/solgs/check/training/population',
        data: {'arguments': args},
    
    });

	return checkTrainingPop;
	
},

checkPopulationExists: function (name) {
	var msgDiv = this.msgDiv; // "#searched_trials_message";
	var msg = "Checking if trial or training population " + name + " exists...please wait...";
	solGS.showMessage(msgDiv, msg);

	jQuery("#all_trials_div").empty();

	var checkPopExists = jQuery.ajax({
        type: 'POST',
        dataType: 'json',
	    data: {'name': name},
        url: '/solgs/check/population/exists/',
        
	});

	return checkPopExists;
},

createTrialsTable: function (tableId) {
	console.log(`create trials table tableid ${tableId}`)

	tableId = tableId.replace("#", '')
    var table = '<table id="' + tableId +  '" class="table" style="width:100%;text-align:left">';
    table    += '<thead><tr>';
    table    += '<th></th><th>Trial</th><th>Description</th><th>Location</th><th>Year</th><th>More details</th>';
   // table    += '<th id="color_tip" title="You can combine Trials with matching color."><span class="glyphicon glyphicon-question-sign"></span></th>';
    table    += '</tr></thead>';
    table    += '</table>';

    return table;

},

displayTrainingPopulations: function (tableDetails) {

    var divId   = tableDetails.divId;
    var tableId = tableDetails.tableId;
    var data    = tableDetails.data;

    if (data) {
		var tableRows = jQuery(tableId + ' tr').length;

		if (tableRows > 1) {
	   		jQuery( tableId).dataTable().fnAddData(data);
		} else {
			var table = this.createTrialsTable(tableId);
			jQuery(divId).html(table).show();

			jQuery(tableId).dataTable({
				'order'        : [[0, "desc"],  [2, "desc"], [3, "desc"]],
				'searching'    : true,
				'ordering'     : true,
				'processing'   : true,
				'lengthChange' : false,
						"bInfo"        : false,
						"paging"       : false,
						'oLanguage'    : {
								"sSearch": "Filter result by: "
								},
				'data'         : data,
			});
		}
    }
},

}

// jQuery(document).ready( function () {

//     jQuery('#search_all_training_pops').on('click', function () {

// 	jQuery("#searched_trials_div").empty();
// 	jQuery("#all_trials_div").empty();
// 	var url = '/solgs/search/trials';
//         var result = 'all';
// 	solGS.searchTrials.searchAllTrials(url, result);
//     });

// });


jQuery(document).ready( function () {
    jQuery("#color_tip").tooltip();
});

jQuery(document).ready(function(){
	jQuery("#all_trials_div").on('click', "div.paginate_nav a", function(e) {
        jQuery("#all_trials_div").empty();
        jQuery("#all_trials_search_message").html('Searching for more GS trials..').show();

        var page = jQuery(this).attr('href');
        if (page) {
            jQuery.ajax({
                type: 'POST',
                dataType: "json",
                url: page,
                success: function(res) {
		    		solGS.searchTrials.listAllTrials(res.trials)
                    var pagination = res.pagination;
                    jQuery("#all_trials_search_message").hide();
		    		jQuery("#all_trials_div").append(pagination);
                },
                error: function() {
                    jQuery("#all_trials_search_message").html('Error occured fetching the next set of GS trials.').show();
                }
            });
        }
        return false;
    });
});


jQuery(document).ready(function(){

    var url = window.location.pathname;

    if (url.match(/solgs\/search\/trials\/trait\//) != null) {
		var traitId = jQuery("input[name='trait_id']").val();

		var urlStr = url.split(/\/+/);
		var protocolId = urlStr[7];
		jQuery('#genotyping_protocol_id').val(protocolId);

		url = '/solgs/search/result/populations/' + traitId + '/gp/' + protocolId;
		solGS.searchTrials.searchAllTrials(url).done(function(res){
			if (res) {
				jQuery("#all_trials_search_message").hide();	
				solGS.searchTrials.listAllTrials(res.trials)
				var pagination = res.pagination;
				
				jQuery("#all_trials_search_message").hide();
				jQuery("#all_trials_div").append(pagination);
			} else {
				jQuery("#all_trials_search_message").html('No trials phenotyped for the trait were found.').show();
			}
		}).fail(function(){
			jQuery("#all_trials_search_message").html('Error occured fetching the first set of GS trials.').show();
		});
    } 
	
	// else {
	// 	url = '/solgs/search/trials/';
    // }
	// 	searchAllTrials(url);

  
});




jQuery(document).ready( function () {

	var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();
	console.log(`SearchTrials protocolId: ${protocolId}`)
    
	jQuery('#population_search_entry').keyup(function(e) {
	jQuery("#population_search_entry").css('border', 'solid #96d3ec');
	jQuery("#form-feedback-search-trials").empty();

	if (e.keycode == 13) {
    	jQuery('#search_training_pop').click();
    }
    });

    jQuery('#search_training_pop').on('click', function () {

	var entry = jQuery('#population_search_entry').val();
	jQuery("#searched_trials_message").hide();

	var msgDiv = solGS.searchTrials.msgDiv;
	if (entry) {
	    solGS.searchTrials.checkPopulationExists(entry).done(function(res){
			if (res.population_ids) {

				msg = '<p>Checking if the trial or population can be used <br />'
				+ 'as a training population...please wait...</p>';
				solGS.showMessage(msgDiv, msg);

				solGS.searchTrials.checkTrainingPopulation(res.population_ids).done(function(res) {

				if (res.is_training_population) {

					var resultDivId   = '#searched_trials_div';
					var tableId = '#searched_trials_table';
					var msgDiv = solGS.searchTrials.msgDiv; //'#searched_trials_message';
					jQuery(msgDiv).hide();
					jQuery(resultDivId).show();

					var data    = res.training_pop_data;
					var tableDetails = {
						'divId'  : resultDivId,
						'tableId': tableId,
						'data'   : data
					};

					var table = document.querySelector(tableId);
					if (table) {
						var rowsCount = table.rows.length;
						if (rowsCount > 1) {	
							jQuery('#select_trials_div').show();
						}
					}

					solGS.searchTrials.displayTrainingPopulations(tableDetails);

            	} else {
					var msg =  ('<p> Population ' + popIds + ' can not be used as a training population. It has no phenotype or/and genotype data.');
					solGS.showMessage(msgDiv, msg);
					jQuery("#search_all_training_pops").show();
	    	}}).fail(function() {

				var msg = 'Error occured checking for if trial can be used as training population.';
				solGS.showMessage(msgDiv, msg);
			});
			} else {
				msg = '<p>' + entry + ' is not in the database.</p>';
				solGS.showMessage(msgDiv, msg);
			}
		}).fail(function(res){
			msg = 'Error occured checking if the training population exists.';
			solGS.showMessage(msgDiv, msg);
		});

	} else {
	    jQuery("#population_search_entry")
		.css('border', 'solid #FF0000');

	    jQuery("#form-feedback-search-trials")
		.text('Please enter trial name.');
	}
    });

});









