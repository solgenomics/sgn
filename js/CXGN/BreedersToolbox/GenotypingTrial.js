/*jslint browser: true, devel: true */

/**

=head1 Trial.js

Display for managing genotyping trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    // defined in CXGN.BreedersToolbox.HTMLSelect
    get_select_box("locations", "location_select_div");
    get_select_box("breeding_programs", "breeding_program_select_div");
    get_select_box("years", "year_select_div");

    $(function() {
	$( "#genotyping_trials_accordion" )
	    .accordion({
		header: "> div > h3",
		collapsible: true,
		active: false,
		heightStyle: "content"
	    })
	    .sortable({
		axis: "y",
		handle: "h3",
		stop: function( event, ui ) {
		    // IE doesn't register the blur when sorting
		    // so trigger focusout handlers to remove .ui-state-focus
		    ui.item.children( "h3" ).triggerHandler( "focusout" );
		}
	    });
    });
    
    $('#genotyping_trial_dialog').dialog( {
	autoOpen: false,
	autoResize:true,
	width: 600,
	position: ['top', 150],
	title: 'Create a genotyping trial',
	buttons: {
	    'OK': function() {
		submit_genotype_trial();
	    },
	    'Cancel': function() { $('#genotyping_trial_dialog').dialog("close"); }
	}
    });
    
    function submit_genotype_trial() {
	var breeding_program = $('#breeding_program_select').val();
	var year = $('#year_select').val();
	var location = $('#location_select').val();
	var description = $('#genotyping_trial_description').val();
	var name = $('#genotyping_trial_name').val();
	var list_id = $('#accession_select_box_list_select').val();
	
	if (name == '') { 
	    alert("A name is required and it should be unique in the database. Please try again.");
	    return;
	}
	
	$.ajax( { 
	    url: '/ajax/breeders/genotypetrial',
	    data: { 'location': location, 'breeding_program': breeding_program, 'year': year, 'description': description, 'name': name, 'list_id':list_id },
	    success : function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    alert(response.message);
		    $('#genotyping_trial_dialog').dialog("close");
		    window.location.href = "/breeders/trial/"+response.trial_id;
		}
	    },
	    error: function(response) { 
		alert('An error occurred');
	    }
	});
    }

    jQuery('#genotyping_trial_dialog').bind("dialogopen", function displayMenu() { 
	var l = new CXGN.List();
	var html = l.listSelect('accession_select_box', [ 'accessions', 'plots' ]);
	$('#accession_select_box_span').html(html);
    });
    
    function open_genotyping_trial_dialog () {
	$('#genotyping_trial_dialog').dialog("open");
    }

    $('#create_genotyping_trial_link').click(function () {
        open_genotyping_trial_dialog();
    });

    

});

