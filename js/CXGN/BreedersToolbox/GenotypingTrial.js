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

    get_select_box("locations", "igd_location_select_div");
    get_select_box("breeding_programs", "igd_breeding_program_select_div");
    get_select_box("years", "igd_year_select_div");

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
    
    // $('#genotyping_trial_dialog').dialog( {
    // 	autoOpen: false,
    // 	autoResize:true,
    // 	width: 600,
    // 	position: ['top', 150],
    // 	title: 'Create a genotyping trial',
    // 	buttons: [
    // 	    { 
    // 		text: 'OK', 
    // 		id: 'genotype_trial_submit_button',
    // 		click: function() {
    // 		    submit_genotype_trial();
    // 		},
    // 	    },
    // 	    {
    // 		text: 'Cancel',
    // 		id: 'genotype_trial_cancel_button',
    // 		click: function() { 
    // 		    $('#genotyping_trial_dialog').dialog("close"); 
    // 		}
    // 	    }
    // 	]
    // });
    

    // jQuery('#genotyping_trial_dialog').bind("dialogopen", function displayMenu() { 
    // 	var l = new CXGN.List();
    // 	var html = l.listSelect('accession_select_box', [ 'accessions', 'plots' ]);
    // 	$('#accession_select_box_span').html(html);
    // });
    
    // function open_genotyping_trial_dialog () {
    // 	$('#genotyping_trial_dialog').dialog("open");
    // }

    $('#create_genotyping_trial_link').click(function () {
        open_genotyping_trial_dialog();
    });

    $('#add_igd_geno_trial_submit').click(function () {
	alert("Now submitting trial...");
        submit_igd_genotype_trial();
    });


    // $('#upload_igd_genotyping_trials_form').iframePostForm({
    // 	json: true,
    // 	post: function () {
    // 	    var uploadedGenotypingFile = $("#igd_genotyping_trial_upload_file").val();
    // 	    $('#working_modal').modal("show");
    // 	    if (uploadedGenotypingFile === '') {
    // 		$('#working_modal').modal("hide");
    // 		alert("Please select a file to upload.");
    // 		return;
    // 	    }
    // 	},
    // 	complete: function (response) {
    // 	    //var response_json = JSON.stringify(response);
    // 	    //alert(response_json);
    // 	    $('#working_modal').modal("hide");
    // 	    if (response.error) { 
    // 		var error = response.error;
    // 		$('#working_modal').modal("hide");
    // 		// if (response.error) {
    // 		// 	$("#upload_genotyping_error_display tbody").html('');
    // 		// 	$("#upload_genotyping_error_display tbody").append(response.error_string);
		
		
    // 		// 	$(function () {
    // 		// 	    $("#upload_genotyping_error_display").dialog({
    // 		// 		modal: true,
    // 		// 		autoResize:true,
    // 		// 		width: 650,
    // 		// 		position: ['top', 250],
    // 		// 		title: "Errors in uploaded file",
    // 		// 		buttons: {
    // 		// 		    Ok: function () {
    // 		// 			$(this).dialog("close");
    // 		    // 		    }
    // 		// 		}
    // 		// 	    });
    // 		// 	});
    // 		// 	return;
    // 		// }
    // 		if (response.error) {
    // 		    alert(error);
    // 		    return;
    // 		}
    // 		if (response.success) {
    // 		    //$('#genotyping_upload_success_dialog_message').dialog("open");
    // 		    //alert("File uploaded successfully");
    // 		}
    // 	    }
    // 	    alert("Successfully stored the trial.");
    // 	    window.location.href = "/breeders/trial/"+response.trial_id;

    // 	}
    // });

    $('#igd_genotyping_trial_dialog').on('show.bs.modal', function (e) {
	var l = new CXGN.List();
	var html = l.listSelect('igd_accession_select_box', [ 'accessions', 'plots' ]);
	$('#igd_accession_select_box_span').html(html);
    })
    
//    jQuery('#igd_genotyping_trial_dialog').bind("dialogopen", function displayMenu() { 
//	var l = new CXGN.List();
//	var html = l.listSelect('igd_accession_select_box', [ 'accessions', 'plots' ]);
//	$('#igd_accession_select_box_span').html(html);
//    });

    
    function open_igd_genotyping_trial_dialog () {
	$('#igd_genotyping_trial_dialog').modal("show");
    }

    $('#create_igd_genotyping_trial_link').click(function() {
	alert('You clicked right there!');
        open_igd_genotyping_trial_dialog();
    });

    $('#delete_layout_data_by_trial_id').click(function() { 
	var trial_id = get_trial_id();
	var yes = confirm("Are you sure you want to delete this experiment with id "+trial_id+" ? This action cannot be undone.");
	if (yes) { 
	    jQuery('#working_modal').modal("show");
	    var html = jQuery('#working_msg').html();
	    jQuery('#working_msg').html(html+"Deleting genotyping experiment...<br />");
	    jQuery.ajax( { 
		async: false,
		url: '/ajax/breeders/trial/'+trial_id+'/delete/layout',
		success: function(response) { 
		    if (response.error) { 
			jQuery('#working_modal').modal("hide");
			alert(response.error);
		    }
		    else { 
			//Do nothing, as the process continues...
		    }
		},
		error: function(response) { 
		    jQuery('#working_modal').modal("hide");
		    alert("An error occurred.");
		}
	    });
	    html = jQuery('#working_msg').html();
	    jQuery('#working_msg').html(html+"Removing the project entry...");
	    jQuery.ajax( { 
		async: false,
		url: '/ajax/breeders/trial/'+trial_id+'/delete/entry',
		success: function(response) { 
                    if (response.error) { 
			jQuery('#working_modal').modal("hide");
			alert(response.error);
                    }
                    else { 
			jQuery('#working_modal').modal("hide");
			alert('The project entry has been deleted.'); // to do: give some idea how many items were deleted.
			window.location.href="/breeders/trial/"+trial_id;
                    }
		},
		error: function(response) { 
                    jQuery('#working_modal').modal("hide");
                    alert("An error occurred.");
		}
            });
	    
	}
    });


    function submit_genotype_trial(gdf_username, gdf_password, gdf_host) {
	alert("now submitting it..");
	var plate_data;
	plate_data.breeding_program = $('#breeding_program_select').val();
	plate_data.year = $('#year_select').val();
	plate_data.location = $('#location_select').val();
	plate_data.description = $('#genotyping_trial_description').val();
	plate_data.name = $('#genotyping_trial_name').val();
	plate_data.list_id = $('#accession_select_box_list_select').val();
	
	var auth_data;
	auth_data.username = gdf_username;
	auth_data.password = gdf_password;
	auth_data.host = gdf_host;
	
	if (name == '') { 
	    alert("A name is required and it should be unique in the database. Please try again.");
	    
	    return;
	}
	
	var l = new CXGN.List();
	if (! l.validate(list_id, 'accessions', true)) { 
	    alert('The list contains elements that are not accessions.');
	    
	    return;
	}
	
	var elements = l.getList(list_id);
	if (typeof elements == 'undefined' ) { 
	    alert("There are no elements in the list provided.");
	    
	    return;
	}
	
	if (elements.length > 95) { 
	    $('#working').dialog("close");
	    alert("The list needs to have less than 96 elements (one well is reserved for the BLANK). Please use another list.");
	    
	    return;
	}
	
	$('#working').dialog("open");
	
	// get the genotyping data from GDF
	// login
	//
	$.ajax( { 
	    url: gdf_host+'/api/login',
	    method: 'POST',
	    data: { username: gdf_username,
		    password: gdf_password,
		  },
	    success: function(response) { 
		if (response.metadata.status) { 
		    alert(response.metadata.status);
		}
		else { 
		    alert("Success!");
		    auth_data.access_token = response.result.access_token;
		    submit_plates_to_gdf(auth_data, plate_data);
		}
	    }
	});
    }
    
    function submit_plate_to_gdf(auth_data, plate_data) { 
	
	var formatted_elements;
	
	for(var i=0; i< plate_data.elements.length; i++) { 
	    formatted_elements.push( { name: plate_data.elements[i] });
	}
	
	$.ajax( { 
	    url: gdf_host+'/brapi/v2/plate',
	    method: 'POST',
	    data: { 
		token: access_token,
		plates: [ 
		    { 
			project_id: plate_data.breeding_program,
			plate_name: plate_data.name,
			plate_format: "Plate_96",
			sample_type: 'DNA',
			samples: [
			    formatted_elements
			]
		    }
		]
	    },
	    success: function(response) { 
		if (response.metadata.status) { 
		    alert(response.metadata.status);
		}
		else { 
		    store_plate(auth_data, plate_data);
		    alert("Successfully submitted the plate to GDF.");
		}
	    }
	    
	});						
    }
    
    function load_genotyping_status_info(auth_data, plate_id) { 
	$.ajax( { 
	    url: auth_data.host+'/brapi/v2/plate/'+plate_id,
	    success: function(response) { 
	    }
	});
    }

    function shipping_label_pdfs(plate_ids) { 
	$.ajax( { 
	    url: '/brapi/v2/plate_pdf',
	    data: { 'plate_ids' : plate_ids }
	    success: function(response) { 
		if (response.metadata.status) { 
		    alert(response.metadata.status);
		}
		else { 
		    $('#download_trial_pdf').html(response.results.url)
		}
	    },
	    error: function(response) { 
		alert("An error occurred. Please try again later.");
	    }
	});
    }
    
    function store_plate(auth_data, plate_data) { 
	$.ajax( { 
	    url: '/ajax/breeders/genotypetrial',
	    method: 'POST',
	    data: { location: plate_data.location, 
		    breeding_program: plate_data.breeding_program, 
		    year: plate_data.year, 
		    description: plate_data.description, 
		    name : plate_data.name,
		    list_id : plate_data.list_id,
		  },
	    success : function(response) { 
		if (response.error) { 
		    alert(response.error);
		    $('#working').dialog("close");
		}
		else { 
		    alert(response.message);
		    $('#genotyping_trial_dialog').dialog("close");
		    $('#working').dialog("close");
		    window.location.href = "/breeders/trial/"+response.trial_id;
		}
	    },
	    error: function(response) { 
		alert('An error occurred trying the create the layout.');
		$('#working').dialog("close");
	    }
	});
    }
    
    function submit_igd_genotype_trial() {
	var breeding_program = $('#breeding_program_select').val();
	var year = $('#year_select').val();
	var location = $('#location_select').val();
	var description = $('#genotyping_trial_description').val();
	var name = $('#genotyping_trial_name').val();
	var list_id = $('#igd_accession_select_box_list_select').val();
	
	//if (name == '') { 
	//    alert("A name is required and it should be unique in the database. Please try again.");
	//    return;
	//}
	// note: taking name from file
	
	alert("Checking list...");
	var l = new CXGN.List();
	if (! l.validate(list_id, 'accessions', true)) { 
	    alert('The list contains elements that are not accessions.');
	    return;
	}
	
	var elements = l.getList(list_id);
	if (typeof elements == 'undefined' ) { 
	    alert("There are no elements in the list provided.");
	    return;
	}
	
	if (elements.length > 95) { 
	    $('#working_modal').modal("show");
	    alert("The list needs to have less than 96 elements (one well is reserved for the BLANK). Please use another list.");
	    
	    return;
	}
	
	alert("List passed verification submitting form...");
	$('#working_modal').modal("show");
	
	$('#upload_igd_genotyping_trials_form').append('<input type="hidden" name="list_id" value="'+list_id+'">');
	$('#upload_igd_genotyping_trials_form').append('<input type="hidden" name="year" value="'+year+'">');
	$('#upload_igd_genotyping_trials_form').append('<input type="hidden" name="breeding_program" value="'+breeding_program+'">');
	$('#upload_igd_genotyping_trials_form').append('<input type="hidden" name="location" value="'+location+'">');
	
	$("#upload_igd_genotyping_trials_form").submit();    
    }
    
});
