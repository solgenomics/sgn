

function get_breeding_select() { 
    var programs = new Array();
    jQuery.ajax( { 
	url: '/ajax/breeders/all_programs',
	success: function(response) { 
            programs = response;
            var html = "";
	    
            for (var i=0; i< programs.length; i++) {  
		html += '<option value='+programs[i][0]+'>'+programs[i][1]+'</a>';
            }
            jQuery('#change_breeding_program_select').html(html);	
	},
	error: function(response){ 
            alert("An error occurred.");
	}
    });
}

function delete_phenotype_data_by_trial_id(trial_id) { 
    var yes = confirm("Are you sure you want to delete all phenotypic data associated with trial "+trial_id+" ? This action cannot be undone.");
    if (yes) { 
	jQuery('#working').dialog("open");
	jQuery.ajax( { 
            url: '/breeders/trial/phenotype/delete/id/'+trial_id,
            success: function(response) { 
		if (response.error) { 
		    jQuery('#working').dialog("close");
		    alert(response.error);
		}
		else { 
		    jQuery('#working').dialog("close");
		    alert('The phenotypic data has been deleted.'); // to do: give some idea how many items were deleted.
		}
            },
            error: function(response) { 
		jQuery('#working').dialog("close");
		alert("An error occurred.");
            }
	});
    }
}

function delete_layout_data_by_trial_id(trial_id) { 
    var yes = confirm("Are you sure you want to delete the layout data associated with trial "+trial_id+" ? This action cannot be undone.");
    if (yes) { 
	jQuery('#working').dialog("open");
	
	jQuery.ajax( { 
            url: '/breeders/trial/layout/delete/id/'+trial_id,
            success: function(response) { 
		if (response.error) { 
		    jQuery('#working').dialog("close");
		    alert(response.error);
		}
		else { 
		    jQuery('#working').dialog("close");
		    alert('The layout data has been deleted.'); // to do: give some idea how many items were deleted.
		}
            },
            error: function(response) { 
		jQuery('#working').dialog("close");
		alert("An error occurred.");
            }
	});
    }
}

function associate_breeding_program() { 
    var program = jQuery('#change_breeding_program_select').val();
    var trial_id = get_trial_id();
    jQuery.ajax( { 
	url: '/breeders/program/associate/'+program+'/'+ trial_id,
	async: false,
	success: function(response) { 
            alert("Associated program with id "+program + " to trial with id "+ trial_id);
	    
	}
    });
}

function load_breeding_program_info(trial_id) { 
    jQuery.ajax( {
	url:'/breeders/programs_by_trial/'+trial_id,
	success: function(response) { 
            if (response.error) { 
		alert(response.error);
            }
            else { 
		var programs = response.projects;
		for (var i=0; i< programs.length; i++) {  
		    var html =  programs[0][1] + ' (' + programs[0][2] + ') ';
		}
		if (programs.length == 0) { html = "(none)"; }		    
		jQuery('#breeding_programs').html(html); 
            }
	},
	error: function() { alert("An error occurred."); }
    });  
}

function open_create_spreadsheet_dialog() {
    var list = new CXGN.List();
    jQuery("#trait_list").html(list.listSelect("trait_list", [ 'traits' ]));
    jQuery('#create_spreadsheet_dialog').dialog("open");
}

function create_spreadsheet() {
    var trialID = parseInt(jQuery('#trialIDDiv').text());
    var list = new CXGN.List();
    var trait_list_id = jQuery('#trait_list_list_select').val();
    var trait_list;
    if (! trait_list_id == "") {
	trait_list = JSON.stringify(list.getList(trait_list_id));
    }
     new jQuery.ajax({
	 type: 'POST',
	 url: '/ajax/phenotype/create_spreadsheet',
	 dataType: "json",
	 data: {
             'trial_id': trialID,
             'trait_list': trait_list,
	 },
	 success: function (response) {
             if (response.error) {
		 alert(response.error);
		 jQuery('#open_create_spreadsheet_dialog').dialog("close");
             } else {
		 alert('success');
             }
	 },
	 error: function () {
             alert('An error occurred creating a phenotype file.');
             jQuery('#open_download_spreadsheet_dialog').dialog("close");
	 }
     });
}

function open_create_fieldbook_dialog() {
    var trialID = parseInt(jQuery('#trialIDDiv').text());
    new jQuery.ajax({
	type: 'POST',
	url: '/ajax/fieldbook/create',
	dataType: "json",
	data: {
            'trial_id': trialID,
	},
	success: function (response) {
            if (response.error) {
		alert(response.error);
		jQuery('#open_create_fieldbook_dialog').dialog("close");
            } else {
		jQuery('#tablet_layout_download_link').attr('href',response.file);
		jQuery("#tablet_field_layout_saved_dialog_message").dialog("open");
		//alert(response.file);
		jQuery('#open_create_fieldbook_dialog').dialog("close");
            }
	},
	error: function () {
            alert('An error occurred creating the field book.');
            jQuery('#open_create_fieldbook_dialog').dialog("close");
	}
    });
}

function trial_detail_page_setup_dialogs() { 

    jQuery('#change_breeding_program_dialog').dialog( {
	height: 150,
	width: 300,
	title: 'Select Breeding Program',
	autoOpen: false,
	buttons: {
	    'OK': function() {
		associate_breeding_program();
		jQuery('#change_breeding_program_dialog').dialog("close"); 
		var trial_id = get_trial_id();
		load_breeding_program_info(trial_id);
	    },
	    'Cancel': function() { jQuery('#change_breeding_program_dialog').dialog("close"); }
	}
    });
    
    jQuery( "#tablet_field_layout_saved_dialog_message" ).dialog({
	autoOpen: false,
	modal: true,
	buttons: {
	    Ok: function() {
		jQuery( this ).dialog( "close" );
		location.reload();
	    }
	}
    });
    
    jQuery('#create_spreadsheet_dialog').dialog({
	autoOpen: false,
	modal: true,
	autoResize:true,
	width: 500,
	position: ['top', 75],
	modal: true,
	buttons: {
	    Cancel: function() {
		jQuery( this ).dialog( "close" );
		return;
	    },
	    Create: function() {
		create_spreadsheet();
		//save_experimental_design(design_json);
		//jQuery( this ).dialog( "close" );
		//jQuery('#add_project_dialog').dialog("close");
	    },
	},
    });
    
    jQuery('#show_change_breeding_program_link').click(
	function() {
	    jQuery('#change_breeding_program_dialog').dialog("open");
	    get_breeding_select();
	}
    );
    
    jQuery('#delete_phenotype_data_by_trial_id').click(
	function() { 
	    var trial_id = get_trial_id();
	    delete_phenotype_data_by_trial_id(trial_id);
	}
    );
    
    jQuery('#delete_layout_data_by_trial_id').click( 
	function() { 
	    var trial_id = get_trial_id();
	    delete_layout_data_by_trial_id(trial_id);
	});
    
    jQuery('#create_spreadsheet_link').click(function () {
	open_create_spreadsheet_dialog();
    });
    
    jQuery('#create_fieldbook_link').click(function () {
	open_create_fieldbook_dialog();
    });
    
    jQuery('#trial_design_view_layout').dialog({
	autoOpen: false,
	height: 500,
	width: 800,
	modal: true,
	buttons: {
	    Close: function() {
		jQuery( this ).dialog( "close" );
	    }
	}
    }); 
    
    jQuery('#view_layout_link').click(function () {
	jQuery('#trial_design_view_layout').dialog("open");
    });
    
    jQuery('#edit_trial_description').click( function () { 
	jQuery('#edit_trial_description_dialog').dialog("open");
	
    });
    
    jQuery('#edit_trial_description_dialog').dialog( { 
	autoOpen: false,
	height: 500,
	width: 800,
	modal: true,
	buttons: {
	    cancel: { text: "Cancel",
                      click: function() { jQuery( this ).dialog("close"); },
                      id: "edit_description_cancel_button"
		    },
	    save:   { text: "Save", 
                      click: function() { save_trial_description(); },
                      id: "edit_description_save_button"
		    }          
	}
	
    });

    jQuery('#edit_trial_type').click( function () { 
	jQuery('#edit_trial_type_dialog').dialog("open");
	jQuery.ajax( { 
	    url: '/ajax/breeders/trial/alltypes',
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    var html = "";
		    if (response.types) { 
			var selected = 'selected="selected"';
			for(var n=0; n<response.types.length; n++) { 
			    
			    html += '<option value="'+response.types[n][1]+'" >'+response.types[n][1]+'</option>';
			}
		    }
		    else { 
			html = '<option active="false">No trial types available</option>';
		    }
		}
		jQuery('#trial_type_select').html(html);
	    },
	    error: function(response) { 
		alert("An error occurred trying to retrieve trial types.");
	    }
	});
    });

    jQuery('#trial_type_select').change( { 
	
    });
    
    jQuery('#edit_trial_type_dialog').dialog( { 
	autoOpen: false,
	height: 200,
	width: 300,
	modal: true,
	buttons: {
	    cancel: { text: "Cancel",
                      click: function() { jQuery( this ).dialog("close"); },
                      id: "edit_type_cancel_button"
		    },
	    save:   { text: "Save", 
                      click: function() { 
			  var type = jQuery('#trial_type_select').val();
			  save_trial_type(type); 
			  display_trial_type(type);
			  jQuery('#edit_trial_type_dialog').dialog("close");

		      },
                      id: "edit_type_save_button"
		    }          
	}	
    });   
}

function save_trial_type(type) { 
    var trial_id = get_trial_id();
    jQuery.ajax( { 
	url: '/ajax/breeders/trial/settype/'+trial_id,
	async: false, //async=false because it needs to finish before page is updated again.
	data: { 'type' : type },
	success: function(response) { 
	    if (response.error) { 
		alert(response.error);
	    }
	    else { 
		alert('New trial type set successfully');
	    }
	},
	error: function(response) { 
	    alert('An error occurred setting the trial type.');
	}
    });
    

}


function display_trial_description(trial_id) { 
    jQuery.ajax( { 
	url: '/ajax/breeders/trial/description/get/'+trial_id,
	success: function(response) { 
            if (response.error) { alert(response.error); }
            else { 
		jQuery('#trial_description').html(response.description);
		jQuery('#trial_description_input').html(response.description);
            }
	},
	error: function(response) { alert('An error occurred trying to display the description.'); }
    });
}

function save_trial_description() { 
    var trial_id = parseInt(jQuery('#trialIDDiv').text());
    var description = jQuery('#trial_description_input').val();
    alert('New description = '+description);
    jQuery.ajax( { 
	url: '/ajax/breeders/trial/description/save/'+trial_id,
	data: { 'description': description },
	success: function(response) { 
            if (response.error) { 
		alert(response.error);
            } 
            else { 
		
		alert("Successfully updated description");
		jQuery('#edit_trial_description_dialog').dialog("close");
		display_trial_description(trial_id);
            }
	},
	error: function(response) { 
            alert("An error occurred updating the trial description");
	},
    });





}

function get_all_locations() { 
    jQuery.ajax( { 
	url: '/ajax/breeders/location/all',
	success: function(response) { 
	    if (response.error) { 
		alert(response.error);
	    }
	    else { 
		var locations = response.locations;
		var html = '';
		for (var n=0; n<locations.length; n++) { 
		    html += '<option value="'+locations[n][0]+'">'+locations[n][1]+'</option>';
		}
	    }
	},
    });
}

function display_trial_location(trial_id) { 
    jQuery.ajax( { 
	url: '/ajax/breeders/trial/location/'+trial_id,
	success: function(response) { 
	    if (response.error) { 
		alert(response.error);
	    }
	    else { 
		var html = "";
		if (response.location[1]) { 
		    html = response.location[1];
		}
		jQuery('#trial_location').html(html);
	    }
	},
	error: function(response) { 
	    alert('An error occurred trying to display the location.');
	}
    });
}
	
function get_trial_type(trial_id) {
    //alert("display type");
    jQuery.ajax( { 
	url: '/ajax/breeders/trial/type/'+trial_id,
	success: function(response) { 
	    if (response.error) { 
		alert(response.error);
	    }
	    else { 
		var type = "[type not set]";
		if (response.type) { 
		    type = response.type[1];
		}
		display_trial_type(type);
		return type;
	    }
	},
	error: function(response) { 
	    alert('An error occurred trying to display the trial type.');
	}
    });
}

function display_trial_type(type) { 
    jQuery('#trial_type').html(type);   
}

function get_trial_id() { 
    var trial_id = parseInt(jQuery('#trialIDDiv').text());
    return trial_id;
}
