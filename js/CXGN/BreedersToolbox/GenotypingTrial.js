/*jslint browser: true, devel: true */

/**

=head1 Trial.js

Display for managing genotyping trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>
Lukas Mueller <lam87@cornell.edu> 

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    // defined in CXGN.BreedersToolbox.HTMLSelect
    get_select_box("locations", "location_select_div", {});
    get_select_box("breeding_programs", "breeding_program_select_div", {});
    get_select_box("years", "year_select_div", {});

    get_select_box("locations", "location_select_div", {});
    get_select_box("breeding_programs", "breeding_program_select_div", {});
    get_select_box("years", "year_select_div", {});

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
    
    $('#create_genotyping_trial_link').click(function () {
        open_genotyping_trial_dialog();
    });

    $('#add_geno_trial_submit').click(function () {
        submit_genotype_trial();
    });

//    $('#genotyping_trial_dialog').dialog( {
//	width: 400,
//	height: 400,
//	autoOpen: false
//    });

    $('#genotyping_trial_dialog').on('show.bs.modal', function (e) {
	var l = new CXGN.List();
	var html = l.listSelect('accession_select_box', [ 'accessions', 'plots' ]);
	$('#accession_select_box_span').html(html);
    })
    
    function open_genotyping_trial_dialog () {
	$('#genotyping_trial_dialog').modal("show");
    }

    $('#create_genotyping_trial_link').click(function() {
        open_genotyping_trial_dialog();
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


    function submit_genotype_trial(gdf_username, gdf_password, host) {
	var plate_data = new Object();
	plate_data.breeding_program = $('#breeding_program_select').val();
	plate_data.year = $('#year_select').val();
	plate_data.location = $('#location_select').val();
	plate_data.description = $('#genotyping_trial_description').val();
	plate_data.name = $('#genotyping_trial_name').val();
	plate_data.list_id = $('#accession_select_box_list_select').val();
	
	if (plate_data.name == '') { 
	    alert("A name is required and it should be unique in the database. Please try again.");
	    jQuery('#working_modal').modal("hide");
	    return;
	}
	
	var l = new CXGN.List();
	if (! l.validate(plate_data.list_id, 'accessions', true)) { 
	    alert('The list contains elements that are not accessions.');
	    jQuery('#working_modal').modal("hide");
	    return;
	}
	
	var elements = l.getList(plate_data.list_id);
	if (typeof elements == 'undefined' ) { 
	    alert("There are no elements in the list provided.");
	    jQuery('#working_modal').modal("hide");
	    return;
	}
	
	if (elements.length > 95) { 
	    $('#working').dialog("close");
	    alert("The list needs to have less than 96 elements (one well is reserved for the BLANK). Please use another list.");
	    jQuery('#working_modal').modal("hide");
	    return;
	}
	
	plate_data.elements = elements;

	//$('#working').dialog("open");
	
	// get the genotyping data from GDF
	// login
	//
	var auth_data = new Object();
	auth_data = get_genotyping_server_credentials();

	if (auth_data.error) { 
	    alert("Genotyping server credentials are not available. Stop.");
	    return;
	}
	
	alert("Click to login at gdf using "+auth_data.host+" "+auth_data.username);
	
	var access_token = genotyping_facility_login(auth_data);
	if (access_token) { 
	    auth_data.access_token = access_token;
	    alert('token='+auth_data.access_token);
	    submit_plate_to_gdf(auth_data, plate_data);	
	}
    }

    function genotyping_facility_login(auth_data) { 
	var access_token;
	$.ajax( { 
	    url: auth_data.host+'/brapi/v2/token',
	    method: 'POST',
	    async: false,
	    data: { username: auth_data.username,
		    password: auth_data.password,
		  },
	    success: function(response) { 
		if (response.metadata.status[0].message) { 
		    alert('Login failed. '+JSON.stringify(response.metadata.status[0].message));
		}
		else { 
		    alert("Success!"+ JSON.stringify(response)+" which is "+response.result.access_token);

		    access_token = response.result.access_token;
		}
	    },
	    error: function(response) { 
		alert("An error occurred trying to log into the sequencing facility server. Please try again later.");
	    }
	});
	return access_token;
    }

    
    function submit_plate_to_gdf(auth_data, plate_data) { 
	
	var formatted_elements = new Array(); 

	for(var i=0; i< plate_data.elements.length; i++) { 
	    formatted_elements.push( { name: plate_data.elements[i] });
	}
	
	alert("Creating genotyping experiment entry...");

	store_plate(auth_data, plate_data);
	alert("Now submitting the plate..."+JSON.stringify(formatted_elements)+" to "+auth_data.host);
	$.ajax( { 
	    url: auth_data.host+'/brapi/v2/plate-register',
	    method: 'POST',
	    data: { 
		token: auth_data.access_token,
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
		    //store_plate(auth_data, plate_data);
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
	    data: { 'plate_ids' : plate_ids },
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
		    
		    list_id : plate_data.list_id,
		    plate_json: { trial_name : plate_data.name }
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
    
    function get_genotyping_server_credentials() { 
	var auth_data;
	jQuery.ajax( { 
	    url: '/ajax/breeders/genotyping_credentials',
	    async: false,
	    success: function(response) { 
		auth_data =  { 
		    host : response.host,
		    username : response.username,
		    password : response.password
		};

	    },
	    error: function(response) { 
		return { 
		    error : "An error occurred",
		};
	    }
	});
	return auth_data;
    }
});
