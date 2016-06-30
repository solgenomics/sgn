// Depends on CXGN.BreedersToolbox.HTMLSelect

function delete_phenotype_data_by_trial_id(trial_id) {
    var yes = confirm("Are you sure you want to delete all phenotypic data associated with trial "+trial_id+" ? This action cannot be undone.");
    if (yes) {
	jQuery('#working').dialog("open");
	jQuery.ajax( {
            url: '/ajax/breeders/trial/'+trial_id+'/delete/phenotypes',
            success: function(response) {
		if (response.error) {
		    jQuery('#working').dialog("close");
		    alert(response.error);
		}
		else {
		    jQuery('#working').dialog("close");
		    alert('The phenotypic data has been deleted.'); // to do: give some idea how many items were deleted.
		    window.location.href="/breeders/trial/"+trial_id;
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
            url: '/ajax/breeders/trial/'+trial_id+'/delete/layout',
            success: function(response) {
		if (response.error) {
		    jQuery('#working').dialog("close");
		    alert(response.error);
		}
		else {
		    jQuery('#working').dialog("close");
		    alert('The layout data has been deleted.'); // to do: give some idea how many items were deleted.
		    window.location.href="/breeders/trial/"+trial_id;
		}
            },
            error: function(response) {
		jQuery('#working').dialog("close");
		alert("An error occurred.");
            }
	});
    }
}

function delete_project_entry_by_trial_id(trial_id) {
       var yes = confirm("Are you sure you want to delete the trial entry for trial "+trial_id+" ? This action cannot be undone.");
    if (yes) {
	jQuery('#working').dialog("open");

	jQuery.ajax( {
            url: '/ajax/breeders/trial/'+trial_id+'/delete/entry',
            success: function(response) {
		if (response.error) {
		    jQuery('#working').dialog("close");
		    alert(response.error);
		}
		else {
		    jQuery('#working').dialog("close");
		    alert('The project entry has been deleted.'); // to do: give some idea how many items were deleted.
		    window.location.href="/breeders/trial/"+trial_id;
		}
            },
            error: function(response) {
		jQuery('#working').dialog("close");
		alert("An error occurred.");
            }
	});
    }

}

function open_create_spreadsheet_dialog() {
    //jQuery('#working').dialog("open");
    jQuery('#working_modal').modal("show");
    var list = new CXGN.List();
    jQuery("#trait_list").html(list.listSelect("trait_list", [ 'traits' ]));
    //jQuery('#working').dialog("close");
    jQuery('#working_modal').modal("hide");
    jQuery('#create_spreadsheet_dialog').dialog("open");
}

function create_spreadsheet() {
    //jQuery('#working').dialog("open");
    jQuery('#working_modal').modal("show");
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
	    // jQuery('#working').dialog("close");
	     jQuery('#working_modal').modal("hide");
             if (response.error) {
		 alert(response.error);
		 jQuery('#open_create_spreadsheet_dialog').dialog("close");
             } else {
		 //alert(response.filename);
		 jQuery('#open_create_spreadsheet_dialog').dialog("close");
		 jQuery('#working_modal').modal("hide");
		 window.location.href = "/download/"+response.filename;
             }
	 },
	 error: function () {
	     //jQuery('#working').dialog("close");
	     jQuery('#working_modal').modal("hide");
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
	beforeSend: function() {
		jQuery("#working_modal").modal("show");
	},
	success: function (response) {
		jQuery("#working_modal").modal("hide");
            if (response.error) {
		alert(response.error);
		jQuery('#open_create_fieldbook_dialog').dialog("close");
            } else {
		jQuery('#tablet_layout_download_link').attr('href',"/fieldbook");
		jQuery("#tablet_field_layout_saved_dialog_message").dialog("open");
		//alert(response.file);
		jQuery('#open_create_fieldbook_dialog').dialog("close");
            }
	},
	error: function () {
		jQuery("#working_modal").modal("hide");
            alert('An error occurred creating the field book.');
            jQuery('#open_create_fieldbook_dialog').dialog("close");
	}
    });
}

function open_create_DataCollector_dialog() {
    //jQuery('#working').dialog("open");
    jQuery('#working_modal').modal("show");
    var list = new CXGN.List();
    jQuery("#trait_list_dc").html(list.listSelect("trait_list", [ 'traits' ]));
    //jQuery('#working').dialog("close");
    jQuery('#working_modal').modal("hide");
    jQuery('#create_DataCollector_dialog').dialog("open");
}


function create_DataCollector() {
    //jQuery('#working').dialog("open");
    jQuery('#working_modal').modal("show");
    var trialID = parseInt(jQuery('#trialIDDiv').text());
    var list = new CXGN.List();
    var trait_list_id = jQuery('#trait_list_list_select').val();
    var trait_list;
    if (! trait_list_id == "") {
	trait_list = JSON.stringify(list.getList(trait_list_id));
    }
     new jQuery.ajax({
	 type: 'POST',
	 url: '/ajax/phenotype/create_DataCollector',
	 dataType: "json",
	 data: {
             'trial_id': trialID,
             'trait_list': trait_list,
	 },

	 success: function (response) {
     //console.log("success "+JSON.stringify(response));
     jQuery('#working_modal').modal("hide");

     if (response.error) {
       console.log("error: "+response.error);
       alert("error: "+response.error);
       jQuery('#open_create_DataCollector_dialog').dialog("close");
     } else {
       //alert("success: "+response.filename);
       jQuery('#open_create_DataCollector_dialog').dialog("close");
       jQuery('#working_modal').modal("hide");
       window.location.href = "/download/"+response.filename;
     }
	 },
	 error: function () {
	     //jQuery('#working').dialog("close");
	     jQuery('#working_modal').modal("hide");
             alert('An error occurred creating a DataCollector file.');
             jQuery('#open_download_DataCollector_dialog').dialog("close");
	 }
     });
}

function open_derived_trait_dialog() {
    jQuery('#working_modal').modal("show");
    jQuery('#compute_derived_trait_dialog').dialog("open");
    var trait = jQuery('#sel1').val();
    jQuery("#test_xyz").html(trait);
    jQuery('#working_modal').modal("hide");

}

function compute_derived_trait() {
    jQuery('#working_modal').modal("show");
    var trait = jQuery('#derived_trait_select').val();
    var trialID = parseInt(jQuery('#trialIDDiv').text());
    if (trait === '') {
		alert("No trait selected");
	    }

     new jQuery.ajax({
	 type: 'POST',
	 url: '/ajax/phenotype/create_derived_trait',
	 dataType: "json",
	 data: {
             'trial_id': trialID,
             'trait': trait,
	 },

	 success: function (response) {
	     jQuery('#working_modal').modal("hide");

             if (response.error) {
		 alert("Computation stopped: "+response.error);
		 //alert("Computation for "+trait+" stopped: "+response.error);
		 jQuery('#open_derived_trait_dialog').dialog("close");

             } else {
		 jQuery('#open_derived_trait_dialog').dialog("close");
		 jQuery('#working_modal').modal("hide");
		 jQuery('derived_trait_saved_dialog_message');
		 alert("Successfully derived and uploaded phenotype");
		// alert("Successfully derived and uploaded ' "+trait+" ' values for this trial");
             }
	 },
	 error: function () {
	     jQuery('#working_modal').modal("hide");
             alert('An error occurred creating trait.');
	 }
     });
}


function trial_detail_page_setup_dialogs() {

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

    jQuery( "#data_collector_saved_dialog_message" ).dialog({
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
	    Create: {text: "Ok", id:"create_phenotyping_ok_button", click:function() {
		create_spreadsheet();
		//save_experimental_design(design_json);
		jQuery( this ).dialog( "close" );
	       },
	    },
	},
    });

    jQuery('#create_DataCollector_dialog').dialog({
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
	    Create: {text: "Create", id:"create_DataCollector_submit_button", click:function() {
		create_DataCollector();
		//save_experimental_design(design_json);
		jQuery( this ).dialog( "close" );
		}
	    },
	},
    });

     jQuery('#compute_derived_trait_dialog').dialog({
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
	    Create: {text: "Create", id:"create_derived_trait_submit_button", click:function() {
		compute_derived_trait();
		jQuery( this ).dialog( "close" );
		}
	    },
	},
    });

    jQuery('#edit_trial_details').click(function () {
        // set up handlers
        jQuery('#clear_planting_date').click(function () {
          jQuery('#edit_trial_planting_date').val('');
          highlight_changed_details('edit_trial_planting_date');
        });

        jQuery('#clear_harvest_date').click(function () {
          jQuery('#edit_trial_harvest_date').val('');
          highlight_changed_details('edit_trial_harvest_date');
        });

        jQuery('[id^="edit_trial_"]').change(function () {
          highlight_changed_details(jQuery( this ).attr('id'));
        });

        //save dialog body html for resetting on close
        var edit_details_body_html = document.getElementById('trial_details_edit_body').innerHTML;

        //populate breeding_programs, locations, years, and types dropdowns, and save defaults
        var default_bp = document.getElementById("edit_trial_breeding_program").getAttribute("value");
        get_select_box('breeding_programs', 'edit_trial_breeding_program', { 'default' : default_bp });
        jQuery('#edit_trial_breeding_program').data("originalValue", default_bp);

        var default_loc = document.getElementById("edit_trial_location").getAttribute("value");
        get_select_box('locations', 'edit_trial_location', { 'default' : default_loc });
        jQuery('#edit_trial_location').data("originalValue", default_loc);

        var default_year = document.getElementById("edit_trial_year").getAttribute("value");
        get_select_box('years', 'edit_trial_year', { 'default' : default_year });
        jQuery('#edit_trial_year').data("originalValue", default_year);

        var default_type = document.getElementById("edit_trial_type").getAttribute("value");
        get_select_box('trial_types', 'edit_trial_type', { 'default' : default_type });
        jQuery('#edit_trial_type').data("originalValue", default_type);

        //create bootstrap daterangepickers for planting and harvest dates
        var plantingDate;
        planting_date_element = document.getElementById("edit_trial_planting_date");
        var planting_date = planting_date_element.getAttribute("value") || '';
        if (planting_date) { planting_date = moment(planting_date, 'YYYY-MMMM-DD').format('MM/DD/YYYY'); }
        planting_date_element.setAttribute("value", planting_date)
        jQuery("#edit_trial_planting_date").daterangepicker(
          {"singleDatePicker": true, "autoUpdateInput": false,},
          function(start) {
            plantingDate = start.format('YYYY/MM/DD HH:mm:ss');
            jQuery('#edit_trial_planting_date').val(start.format('MM/DD/YYYY'));
            highlight_changed_details('edit_trial_planting_date');
          }
        );
        set_daterangepicker_default(planting_date_element, planting_date);

        var harvestDate;
        harvest_date_element = document.getElementById("edit_trial_harvest_date");
        var harvest_date = harvest_date_element.getAttribute("value") || '';
        if (harvest_date) { harvest_date = moment(harvest_date, 'YYYY-MMMM-DD').format('MM/DD/YYYY'); }
        harvest_date_element.setAttribute("value", harvest_date)
        jQuery('#edit_trial_harvest_date').daterangepicker(
          {"singleDatePicker": true, "autoUpdateInput": false,},
          function(start) {
            harvestDate = start.format('YYYY/MM/DD HH:mm:ss');
            jQuery('#edit_trial_harvest_date').val(start.format('MM/DD/YYYY'));
            highlight_changed_details('edit_trial_harvest_date');
          }
        );
        set_daterangepicker_default(harvest_date_element, harvest_date);

        //show dialog
        jQuery('#trial_details_edit_dialog').modal("show");

        //handle cancel and save
        jQuery('#edit_trial_details_cancel_button').click(function () {
            reset_dialog_body('trial_details_edit_body', edit_details_body_html);
        });

        jQuery('#save_trial_details').click(function () {
          // get all changed (highlighted) options
          var changed_elements = document.getElementsByName("changed");
          var categories = [];
          var new_details = {};
          var success_message = '';
          console.log("changed elements =" + changed_elements);
          for(var i=0; i<changed_elements.length; i++) {
            var id = changed_elements[i].id;
            var type = changed_elements[i].title;
            var new_value = changed_elements[i].value;
            if (type === 'planting_date') { new_value = plantingDate || 'remove' ;}
            if (type === 'harvest_date') { new_value = harvestDate || 'remove' ;}
            categories.push(type);
            new_details[type] = new_value;
            if(jQuery('#'+id).is("select")) {
              new_value = changed_elements[i].options[changed_elements[i].selectedIndex].text
            }
            success_message += "<li class='list-group-item list-group-item-success'> Changed "+type+" to: <b>"+new_value+"</b></li>";
          }

          jQuery('#trial_details_edit_dialog').modal("hide");
          save_trial_details(categories, new_details, success_message);
        //  reset_dialog_body('trial_details_edit_body', edit_details_body_html);
        });

    });

  jQuery('#trial_details_error_close_button').click( function() {
    document.getElementById('trial_details_error_message').innerHTML = "";
  });

  jQuery('#trial_details_saved_close_button').click( function() {
    location.reload();
  });

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

    jQuery('#delete_trial_entry_by_trial_id').click(
	function() {
	    var trial_id = get_trial_id();
	    delete_project_entry_by_trial_id(trial_id);
	});


    jQuery('#create_spreadsheet_link').click(function () {
	open_create_spreadsheet_dialog();
    });

    jQuery('#create_fieldbook_link').click(function () {
	open_create_fieldbook_dialog();
    });

    jQuery('#create_DataCollector_link').click(function () {
	open_create_DataCollector_dialog();
    });

    jQuery('#compute_derived_trait_link').click( function () {
	jQuery('#compute_derived_trait_dialog').dialog("open");
	jQuery.ajax( {
		url: '/ajax/breeders/trial/trait_formula',
		success: function(response) {
		//console.log(response);
		if (response.error) {
		    alert(response.error);
		}
		else {
		    var html = "";
		    if (response.derived_traits) {
			var selected = 'selected="selected"';
			for(var n=0; n<response.derived_traits.length; n++) {
			    //alert("derived trait: +derived_traits"+response.derived_traits[n]);
			    html += '<option value="'+response.derived_traits[n]+'" title="'+response.formula[n]+'" >'+response.derived_traits[n]+' </option> ';
			}

		    }
		    else {
			html = '<option active="false">No derived trait available</option>';
		    }
		}
		jQuery('#derived_trait_select').html(html);
	    },
	    error: function(response) {
		alert("An error occurred trying to retrieve derived traits.");
	    }
	});

});

}

function set_daterangepicker_default (date_element, value) {
  var jquery_element = jQuery(date_element);
  jquery_element.attr({ val: value, name: "" });
  jquery_element.parent().parent().removeClass("has-success has-feedback");
  jquery_element.parent().siblings('#change_indicator').remove();
}

function highlight_changed_details (id) { // compare changed value to default. If different, add class and feedback span, if same, remove them
  var detail_element = document.getElementById(id);
  console.log("detail element id = "+console.log(detail_element));
  var current_value = detail_element.value;
  var default_value = detail_element.defaultValue;
  if ( !default_value ) {
    default_value = jQuery('#'+id).data("originalValue");
  }
  console.log("id="+id+" and val="+current_value+" and default_val="+default_value);
  if ((current_value || default_value) && current_value !== default_value) {
    console.log("giving feedback for changed detail element . . .");
    jQuery('#'+id).parent().siblings('#change_indicator').remove();
    jQuery('#'+id).attr( "name", "changed" );
    jQuery('#'+id).parent().parent().addClass("has-success has-feedback");
    jQuery('#'+id).parent().after('<span class="glyphicon glyphicon-pencil form-control-feedback" id="change_indicator" aria-hidden="true" style="right: -20px;"></span>');
  }
  else {
    console.log("resetting element that has been changed back to default_value. . .");
    jQuery('#'+id).attr( "name", "" );
    jQuery('#'+id).parent().parent().removeClass("has-success has-feedback");
    jQuery('#'+id).parent().siblings('#change_indicator').remove();
  }
}

function reset_dialog_body (body_id, body_html) {
  document.getElementById(body_id).innerHTML = body_html;
}

function save_trial_details (categories, details, success_message) {
  var trial_id = get_trial_id();
  jQuery.ajax( {
    url: '/ajax/breeders/trial/'+trial_id+'/details/',
    type: 'POST',
    data: { 'categories' : categories, 'details' : details },
    beforeSend: function(){
      disable_ui();
    },
    complete : function(){
      enable_ui();
    },
    success: function(response) {
      if (response.success) {
        document.getElementById('trial_details_saved_message').innerHTML = success_message;
        jQuery('#trial_details_saved_dialog').modal("show");
        return;
      }
      else {
        document.getElementById('trial_details_error_message').innerHTML = "<li class='list-group-item list-group-item-danger'>"+response.error+"</li>";
        jQuery('#trial_details_error_dialog').modal("show");
      }
    },
    error: function(response) {
      document.getElementById('trial_details_error_message').innerHTML = "<li class='list-group-item list-group-item-danger'> Trial detail update AJAX request failed. Update not completed.</li>";
      jQuery('#trial_details_error_dialog').modal("show");
    },
  });
}

function trial_folder_dialog() {
    jQuery('#set_folder_dialog').dialog("open");

}


function get_trial_id() {
    var trial_id = parseInt(jQuery('#trialIDDiv').text());
    return trial_id;
}


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {


    $('#upload_trial_coords_link').click(function () {
        open_upload_trial_coord_dialog();
    });

    jQuery("#upload_trial_coord_dialog").dialog({
	autoOpen: false,
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 75],
	buttons: {
            "Cancel": function () {
                jQuery('#upload_trial_coord_dialog').dialog("close");
            },
	    "Ok": {text: "Ok", id:"upload_trial_coords_ok_button", click:function () {
		upload_trial_coord_file();
                jQuery('#upload_trial_coord_dialog').dialog("close");
	      }
	    }
	}
    });


    $("#trial_coord_upload_spreadsheet_info_dialog").dialog( {
	autoOpen: false,
	buttons: { "OK" :  function() { $("#trial_coord_upload_spreadsheet_info_dialog").dialog("close"); },},
	modal: true,
	position: ['top', 75],
	width: 900,
	autoResize:true
    });

     $("#trial_coordinates_upload_spreadsheet_format_info").click( function () {
	$("#trial_coord_upload_spreadsheet_info_dialog" ).dialog("open");

    });

    $("#trial_coord_upload_success_dialog_message").dialog({
	autoOpen: false,
	modal: true,
	buttons: {
            Ok: { id: "dismiss_trial_coord_upload_dialog",
                  click: function() {
		      //$("#upload_trial_form").dialog("close");
		      //$( this ).dialog( "close" );
		      location.reload();
                  },
                  text: "OK"
                }
        }

    });


     $('#upload_trial_coordinates_form').iframePostForm({
	json: true,
	post: function () {
            var uploadedtrialcoordFile = $("#trial_coordinates_uploaded_file").val();
	    $('#working_modal').modal("show");
            if (uploadedtrialcoordFile === '') {
		$('#working_modal').modal("hide");
		alert("No file selected");
            }
	},
	complete: function (response) {
	    $('#working_modal').modal("hide");
            if (response.error_string) {
		$("#upload_trial_coord_error_display tbody").html('');
		$("#upload_trial_coord_error_display tbody").append(response.error_string);


		$(function () {
                    $("#upload_trial_coord_error_display").dialog({
			modal: true,
			autoResize:true,
			width: 650,
			position: ['top', 250],
			title: "Errors in uploaded file",
			buttons: {
                            Ok: function () {
				$(this).dialog("close");
                            }
			}
                    });
		});
		return;
            }
            if (response.error) {
		alert(response.error);
		return;
            }
            if (response.success) {
		$('#trial_coord_upload_success_dialog_message').dialog("open");
		//alert("File uploaded successfully");
            }
	}
    });

	function upload_trial_coord_file() {
        var uploadFile = $("#trial_coordinates_uploaded_file").val();
        $('#upload_trial_coordinates_form').attr("action", "/ajax/breeders/trial/coordsupload");
        if (uploadFile === '') {
	    alert("Please select a file");
	    return;
        }
        $("#upload_trial_coordinates_form").submit();
    }

    function open_upload_trial_coord_dialog() {
	$('#upload_trial_coord_dialog').dialog("open");

    }

});
