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

	var urlStr = url.split(/\/+/);
	var protocolId = urlStr[7];
	jQuery('#genotyping_protocol_id').val(protocolId);

	url = '/solgs/search/result/populations/' + traitId + '/gp/' + protocolId;
	searchAllTrials(url);
    } else {
	url = '/solgs/search/trials/';
    }

  //  searchAllTrials(url);
});


function searchAllTrials(url, result) {

    jQuery("#all_trials_search_message").html('Searching for GS trials..').show();

    jQuery.ajax({
        type: 'POST',
        dataType: "json",
        url: url,
        data: {'show_result': result},
        cache: true,
        success: function(res) {

            jQuery("#all_trials_search_message").hide();

            listAllTrials(res.trials)
            var pagination = res.pagination;

            jQuery("#all_trials_search_message").hide();
	   jQuery("#all_trials_div").append(pagination);
        },
        error: function() {
            jQuery("#all_trials_search_message").html('Error occured fetching the first set of GS trials.').show();
        }

    });


    jQuery("#all_trials_div").on('click', "div.paginate_nav a", function(e) {
        var page = jQuery(this).attr('href');

        jQuery("#all_trials_div").empty();

        jQuery("#all_trials_search_message").html('Searching for more GS trials..').show();

        if (page) {
            jQuery.ajax({
                type: 'POST',
                dataType: "json",
                url: page,
                success: function(res) {
		    listAllTrials(res.trials)
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

}


function listAllTrials (trials)  {

    if (trials) {
	var tableId = 'all_trials_table';
	var divId   = 'all_trials_div';

	var tableDetails = {
	    'divId'  : divId,
	    'tableId': tableId,
	    'data'   : trials
	};

	jQuery('#searched_trials_div').empty();
	jQuery('#all_trials_div').empty();

	displayTrainingPopulations(tableDetails);

    } else {
	jQuery("#all_trials_search_message").html('No trials to show.').show();
    }

}


function checkTrainingPopulation (popIds) {

    var protocolId = jQuery('#genotyping_protocol_id').val();

    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/solgs/check/training/population',
        data: {'population_ids' : popIds, 'genotyping_protocol_id': protocolId},
        success: function(response) {
            if (response.is_training_population) {
			jQuery("#searched_trials_message").hide();
			jQuery("#searched_trials_div").show();

			var divId   = 'searched_trials_div';
			var tableId = 'searched_trials_table';
			var data    = response.training_pop_data;

			var tableDetails = {
			    'divId'  : divId,
			    'tableId': tableId,
			    'data'   : data
			};

			displayTrainingPopulations(tableDetails);
                jQuery('#done_selecting_div').show();

            } else {
		jQuery("#searched_trials_message").html('<p> Population ' + popId + ' can not be used as a training population.');
		jQuery("#search_all_training_pops").show();

		// jQuery("#searched_trials_message")
		// 	.delay(4000)
		// 	.fadeOut('slow', function () {
		// 	    searchAllTrials('/solgs/search/trials');
		// 	});
	    }
	},
	error: function(response) {
            jQuery("#searched_trials_message")
		.html('Error occured checking for if trial can be used as training population.');

	    jQuery("#searched_trials_message")
		.delay(4000)
		.fadeOut('slow', function () {
		    // searchAllTrials('/solgs/search/trials');
		});
        }

    });

}


jQuery(document).ready( function () {

    jQuery('#population_search_entry').keyup(function(e) {

	jQuery("#population_search_entry")
		.css('border', 'solid #96d3ec');

	jQuery("#form-feedback-search-trials")
	    .empty();

	if(e.keycode == 13) {

     	    jQuery('#search_training_pop').click();
    	}
    });

    jQuery('#search_training_pop').on('click', function () {

	var entry = jQuery('#population_search_entry').val();
	jQuery("#searched_trials_message").hide();

	if (entry) {

	    checkPopulationExists(entry);
	} else {
	    jQuery("#population_search_entry")
		.css('border', 'solid #FF0000');

	    jQuery("#form-feedback-search-trials")
		.text('Please enter trial name.');
	}
    });

});


jQuery(document).ready( function () {

    jQuery('#search_all_training_pops').on('click', function () {

	jQuery("#searched_trials_div").empty();
	jQuery("#all_trials_div").empty();
	var url = '/solgs/search/trials';
        var result = 'all';
	searchAllTrials(url, result);
    });

});


jQuery(document).ready( function () {
    jQuery("#color_tip").tooltip();
});


function checkPopulationExists (name) {
    jQuery("#searched_trials_message")
	.html("Checking if trial or training population " + name + " exists...please wait...")
	.show();

	jQuery("#all_trials_div").empty();

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
	    data: {'name': name},
            url: '/solgs/check/population/exists/',
            success: function(res) {

		if (res.population_ids) {

		    checkTrainingPopulation(res.population_ids);

		    jQuery('#searched_trials_message').html(
			'<p>Checking if the trial or population can be used <br />'
			    + 'as a training population...please wait...</p>');

		} else {
		    jQuery('#searched_trials_message')
			.html('<p>' + name + ' is not in the database.</p>');

		    jQuery("#searched_trials_message")
			.delay(4000)
			.fadeOut('slow', function () {
			   // searchAllTrials('/solgs/search/trials');
			});
		}
	    },
	    error: function(res) {
		jQuery("#searched_trials_message")
		    .html('Error occured checking if the training population exists.');

		jQuery("#searched_trials_message")
		    .delay(4000)
		    .fadeOut('slow', function () {
			// searchAllTrials('/solgs/search/trials');
		    });
            }
	});

}


function createTrialsTable (tableId) {

    var table = '<table id="' + tableId +  '" class="table" style="width:100%;text-align:left">';
    table    += '<thead><tr>';
    table    += '<th></th><th>Trial</th><th>Description</th><th>Location</th><th>Year</th>';
   // table    += '<th id="color_tip" title="You can combine Trials with matching color."><span class="glyphicon glyphicon-question-sign"></span></th>';
    table    += '</tr></thead>';
    table    += '</table>';

    return table;

}


function displayTrainingPopulations (tableDetails) {

    var divId   = tableDetails.divId;
    var tableId = tableDetails.tableId;
    var data    = tableDetails.data;

    if (data) {

	var tableRows = jQuery('#' + tableId + ' tr').length;

	if (tableRows > 1) {
	    jQuery('#' + tableId).dataTable().fnAddData(data);
	} else {

	    var table = createTrialsTable(tableId);

	    jQuery('#' + divId).html(table).show();

	    jQuery('#' + tableId).dataTable({
                    'order'        : [[1, "desc"], [4, "desc"]],
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

}
