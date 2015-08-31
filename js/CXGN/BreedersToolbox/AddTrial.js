/*jslint browser: true, devel: true */

/**

=head1 AddTrial.js

Dialogs for adding trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var list = new CXGN.List();

    var design_json;

    function save_project_info(name, year, desc) {
        alert('data = ' + name + ' ' + year + ' ' + desc);
        $.ajax({
            type: 'GET',
            async: false,
            url: '/ajax/breeders/project/insert',
            data: {
                'project_name': name,
                'project_description': desc,
                'year': year
            },
            success: function (response) {
                if (response.error) {
                    alert(response.error);
                } else {
                    alert('The trial information was saved.');
                }
            },
            error: function () {
                alert('An error occurred. sorry');
            }
        });
    }

    function verify_stock_list(stock_list) {
	var return_val = 0;
	$.ajax({
            type: 'POST',
	    timeout: 3000000,
            url: '/ajax/trial/verify_stock_list',
	    dataType: "json",
            data: {
                //'stock_list': stock_list.join(","),
                'stock_list': stock_list,
            },
            success: function (response) {
                if (response.error) {
                    alert(response.error);
		    verify_stock_list.return_val = 0;
                } else {
		    verify_stock_list.return_val = 1;
                }
            },
            error: function () {
                alert('An error occurred. sorry');
	    verify_stock_list.return_val = 0;
            }
	});
	return return_val;
    }

    function generate_experimental_design() {
        var name = $('#new_trial_name').val();
        var year = $('#add_project_year').val();
        var desc = $('#add_project_description').val();
        var trial_location = $('#add_project_location').val();
        var block_number = $('#block_number').val();
        
        //alert(block_number);
 
        var row_number= $('#row_number').val();
	var row_number_per_block=$('#row_number_per_block').val();
	var col_number_per_block=$('#col_number_per_block').val();
	var col_number=$('#col_number').val();


       // alert(row_number);

        var stock_list_id = $('#select_list_list_select').val();
        var control_list_id = $('#list_of_checks_section_list_select').val();
	var stock_list;
	if (stock_list_id != "") {
            stock_list = JSON.stringify(list.getList(stock_list_id));
	}
	var control_list;
	if (control_list_id != "") {
            control_list = JSON.stringify(list.getList(control_list_id));
	}
        var design_type = $('#select_design_method').val();
	var rep_count = $('#rep_count').val();
	var block_size = $('#block_size').val();
	var max_block_size = $('#max_block_size').val();
	var plot_prefix = $('#plot_prefix').val();
	var start_number = $('#start_number').val();
	var increment = $('#increment').val();
	//var stock_verified = verify_stock_list(stock_list);
    
        //alert(design_type);

       if (name == '') {
            alert('Trial name required');
            return;
        }

        if (desc == '' || year == '') {
            alert('Year and description are required.');
            return;
        }

	$('#working_modal').modal("show");

        $.ajax({
            type: 'POST',
	    timeout: 3000000,
            url: '/ajax/trial/generate_experimental_design',
	    dataType: "json",
            data: {
                'project_name': name,
                'project_description': desc,
                'year': year,
                'trial_location': trial_location,
                'stock_list': stock_list,
		'control_list': control_list,
		'design_type': design_type,
		'rep_count': rep_count,
		'block_number': block_number,
                'row_number': row_number,
		'row_number_per_block': row_number_per_block,
		'col_number_per_block': col_number_per_block,
		'col_number': col_number,
		'block_size': block_size,
		'max_block_size': max_block_size,
		'plot_prefix': plot_prefix,
		'start_number': start_number,
		'increment': increment,
            },
            success: function (response) {
                if (response.error) {
                    alert(response.error);
		    $('#working_modal').modal("hide");
                } else {
		    $('#trial_design_information').html(response.design_info_view_html);
                    $('#trial_design_view_layout_return').html(response.design_layout_view_html);

		    $('#working_modal').modal("hide");
                    $('#trial_design_confirm').modal("show");
		    design_json = response.design_json;
                }
            },
            error: function () {
		$('#working_modal').modal("hide");
                alert('An error occurred. sorry. test');
            }
       });
    }

    $('#new_trial_submit').click(function () {
          var name = $('#new_trial_name').val();
          var year = $('#add_project_year').val();
          var desc = $('textarea#add_project_description').val();
          var method_to_use = $('.format_type:checked').val();
	  if (name == '') {
	    alert('Trial name required');
	    return;
	  }
          if (year === '' || desc === '') {
	    alert('Year and description are required.');
	    return;
          }
          if (method_to_use == "empty") {
	    alert('adding a project');
	    save_project_info(name, year, desc);
          }
          if (method_to_use == "create_with_upload") {
	    var uploadFile = $("#trial_upload_file").val();
	    $('#create_new_trial_form').attr("action", "/trial/upload_trial_layout");
	    if (uploadFile === '') {
              alert("Please select a file");
              return;
	    }
	    $("#create_new_trial_form").submit();
          }
          if (method_to_use == "create_with_design_tool") {
	    //generate_experimental_design(name,year,desc);
	    generate_experimental_design();
	  }
          //$( this).dialog("close"); 
          //location.reload();
    });

//    $('#add_project_dialog').dialog({
//	autoOpen: false,
//        modal: true,
//	autoResize:true,
//        width: 500,
//        position: ['top', 75],
//        title: "Add new trial",
//        buttons: {
//            "Cancel": {
//                id : "cancel_add_trial",
//                click: function () {
//                   $('#add_project_dialog').dialog("close");
//                },
//                text: "Cancel"
//            },
//            "Add": { 
//		id : "add_trial_button",
//		click: 
//                  function () {
//                      var name = $('#new_trial_name').val();
//                      var year = $('#add_project_year').val();
//                      var desc = $('textarea#add_project_description').val();
//                      var method_to_use = $('.format_type:checked').val();
//		      if (name == '') {
//			  alert('Trial name required');
//			  return;
//		      }
//                      if (year === '' || desc === '') {
//			  alert('Year and description are required.');
//			  return;
//                      }
//                      if (method_to_use == "empty") {
//			  alert('adding a project');
//			  save_project_info(name, year, desc);
//                      }
//                      if (method_to_use == "create_with_upload") {
//			  var uploadFile = $("#trial_upload_file").val();
//			  $('#create_new_trial_form').attr("action", "/trial/upload_trial_layout");
//			  if (uploadFile === '') {
//                              alert("Please select a file");
//                              return;
//			  }
//			  $("#create_new_trial_form").submit();
//                      }
//                      if (method_to_use == "create_with_design_tool") {
//			  //generate_experimental_design(name,year,desc);
//			  generate_experimental_design();
//		      }
//                      //$( this).dialog("close"); 
//                      //location.reload();
//		  },
//		text: "Add"
//	    }
//        }
//    });

//    $("#format_type_radio").change(function () {
//        var method_to_use = $('.format_type:checked').val();
//        if (method_to_use == "empty") {
//            //$("#add_project_dialog").dialog("option", "height","auto");
//            $("#trial_design_info").hide();
//            $("#trial_design_more_info").hide();
//            $("#get_file_upload_data").hide();
//        }
//        if (method_to_use == "create_with_upload") {
//            $("#get_file_upload_data").show();
//            //$("#add_project_dialog").dialog("option", "height","auto");
//            $("#trial_design_info").hide();
//            $("#trial_design_more_info").hide();
//        } else {
//            $("#get_file_upload_data").hide();
//        }
//        if (method_to_use == "create_with_design_tool") {
//            $("#trial_design_info").collapse('show');
//            //$("#add_project_dialog").dialog("option", "height","auto");
//	    $("#select_design_method").change();
//        } else {
//            $("trial_design_info").hide();
//        }
//    });

    $("#format_type_radio").change();


    $("#select_design_method").change(function () {
	//$("#add_project_dialog").dialog("option", "height","auto");
        
	var design_method = $("#select_design_method").val();
        if (design_method == "CRD") {
            $("#trial_design_more_info").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").hide();
            $("#rep_count_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_section").hide();
	    $("#row_number_section").hide();
	    $("#row_number_per_block_section").hide();
	    $("#col_number_per_block_section").hide();
	    $("#col_number_section").hide();
	    $("#row_number_per_block_section").hide();
	    $("#other_parameter_section").hide();
        } else if (design_method == "RCBD") {
            $("#trial_design_more_info").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").show();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
	    $("#row_number_section").hide();
	    $("#row_number_per_block_section").hide();
	    $("#col_number_per_block_section").hide();
	    $("#col_number_section").hide();
	    $("#row_number_per_block_section").hide();
	    $("#other_parameter_section").hide();
        } else if (design_method == "Alpha") {
            $("#trial_design_more_info").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").hide();
            $("#rep_count_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").show();
            $("#max_block_size_section").hide();
	    $("#row_number_section").hide();
	    $("#row_number_per_block_section").hide();
	    $("#col_number_per_block_section").hide();
	    $("#col_number_section").hide();
	    $("#row_number_per_block_section").hide();
	    $("#other_parameter_section").hide();
        } else if (design_method == "Augmented") {
            $("#trial_design_more_info").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").show();
            $("#rep_count_section").hide();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_size_section").show();
	    $("#row_number_section").hide(); 
	    $("#row_number_per_block_section").hide();
	    $("#col_number_per_block_section").hide();
	    $("#col_number_section").hide();
	    $("#row_number_per_block_section").hide();
	    $("#other_parameter_section").hide();
        } else if (design_method == "") {
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").hide();
            $("#trial_design_more_info").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
	    $("#row_number_section").hide();
	    $("#row_number_per_block_section").hide();
	    $("#col_number_per_block_section").hide();
	    $("#col_number_section").hide();
	    $("#row_number_per_block_section").show();
	    $("#other_parameter_section").hide();
	    $("#other_parameter_section2").hide();
        } 
//	else if (design_method == "MADII") {
//	    $("#trial_design_more_info").show();
//	    $("#add_project_dialog").dialog("option", "height","auto");
//            $("#list_of_checks_section").show();
//            $("#rep_count_section").hide();
//	    $("#row_number_section").show();
//            $("#block_number_section").hide();
//            $("#block_size_section").hide();
//            $("#max_block_size_section").hide();
//	    $("#row_number_per_block_section").hide();
//	    $("#col_number_per_block_section").hide();
//	    $("#col_number_section").hide();
//            $("#other_parameter_section").hide();
//	} 
	else if (design_method == "MAD") {
	    $("#trial_design_more_info").show();
	    //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").show();
            $("#rep_count_section").hide();
	    $("#row_number_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#row_number_per_block_section").show();
	    $("#col_number_per_block_section").show();
            $("#col_number_section").show();
            $("#max_block_size_section").hide();
	    $("#row_number_per_block_section").show();
            $("#other_parameter_section").show();

             $("#show_other_parameter_options").click(function () {
		 if ($('#show_other_parameter_options').is(':checked')) {
		     $("#other_parameter_options").show();
		     //$("#add_project_dialog").dialog("option", "height","auto");
		 }
		 else {
		     $("#other_parameter_options").hide();
		     //$("#add_project_dialog").dialog("option", "height","auto");
		 }
	     });

	} 
//	else if (design_method == "MADIV") {
//	    $("#trial_design_more_info").show();
//	    $("#add_project_dialog").dialog("option", "height","auto");
//            $("#list_of_checks_section").show();
//            $("#rep_count_section").hide();
//	    $("#row_number_section").show();
//            $("#block_number_section").hide();
//            $("#block_size_section").hide();
//            $("#max_block_size_section").hide();	   
//	    $("#other_parameter_section").hide();
//	    $("#row_number_per_block_section").show();
//	} 
else {
            alert("Unsupported design method");
        }
    });

    $("#show_plot_naming_options").click(function () {
	if ($('#show_plot_naming_options').is(':checked')) {
	    $("#plot_naming_options").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
	}
	else {
	    $("#plot_naming_options").hide();
            //$("#add_project_dialog").dialog("option", "height","auto");
	}
    });

 function save_experimental_design(design_json) {
     $('#working_modal').modal("show");
        var name = $('#new_trial_name').val();
        var year = $('#add_project_year').val();
        var desc = $('#add_project_description').val();
        var trial_location = $('#add_project_location').val();
        var block_number = $('#block_number').val();
        var stock_list_id = $('#select_list_list_select').val();
        var control_list_id = $('#list_of_checks_section_list_select').val();
	var stock_list;
	if (stock_list_id != "") {
            stock_list = JSON.stringify(list.getList(stock_list_id));
	}
	var control_list;
	if (control_list_id != "") {
            control_list = JSON.stringify(list.getList(control_list_id));
	}
        var design_type = $('#select_design_method').val();


     //alert(design_type);

	var rep_count = $('#rep_count').val();
	var block_size = $('#block_size').val();
	var max_block_size = $('#max_block_size').val();
	var plot_prefix = $('#plot_prefix').val();
	var start_number = $('#start_number').val();
	var increment = $('#increment').val();
	var breeding_program_name = $('#select_breeding_program').val();

	//var stock_verified = verify_stock_list(stock_list);
        if (desc == '' || year == '') {
            alert('Year and description are required.');
            return;
        }
        $.ajax({
            type: 'POST',
	    timeout: 3000000,
            url: '/ajax/trial/save_experimental_design',
	    dataType: "json",
            data: {
                'project_name': name,
                'project_description': desc,
                //'trial_name': trial_name,
                'year': year,
                'trial_location': trial_location,
                'stock_list': stock_list,
		'control_list': control_list,
		'design_type': design_type,
		'rep_count': rep_count,
		'block_number': block_number,
		'block_size': block_size,
		'max_block_size': max_block_size,
		'plot_prefix': plot_prefix,
		'start_number': start_number,
		'increment': increment,
		'design_json': design_json,
                'breeding_program_name': breeding_program_name,
            },
            success: function (response) {
                if (response.error) {
		    $('#working_modal').modal("hide");
                    alert(response.error);
                    $('#trial_design_confirm').modal("hide");
                } else {
		    //alert('Trial design saved');
		    $('#working_modal').modal("hide");
		    $('#trial_saved_dialog_message').modal("show");
                }
            },
            error: function () {
                $('#trial_saving_dialog').dialog("close");
                alert('An error occurred saving the trial.');
                $('#trial_design_confirm').dialog("close");
            }
       });
    }

//    $( "#trial_saving_dialog" ).dialog({
//	autoOpen: false,
//	modal: true,
//    });

//    $( "#trial_saved_dialog_message" ).dialog({
//	autoOpen: false,
//	modal: true,
//	buttons: {
//            Ok: { id : "trial_saved_dialog_message_ok_button",
//		  click: function() {
//		      $( this ).dialog( "close" );
//		      location.reload();
//		  },
//		  text: "Ok"
//		}
//        }
//    });

    $('#new_trial_confirm_submit').click(function () {
	save_experimental_design(design_json);
    });

//    $('#trial_design_confirm').dialog({
//	autoOpen: false,
//        height: 400,
//	width: 450,
//        modal: true,
//        buttons: {
//	    Confirm: {
//		id : "confirm_trial_save_button",
//		click: function() {
//		    save_experimental_design(design_json);
//		    //$( this ).dialog( "close" );
//		    //$('#add_project_dialog').dialog("close");
//		},
//		text: "Confirm"
//	    },
//	    Cancel: { 
//		id : "cancel_trial_save_button",
//		click: function() {
//		    //$('#add_project_dialog').dialog("close");
//		    $( this ).dialog( "close" );
//		    return;
//		},
//		text: "Cancel"
//	    }
//        }
//    });

    $('#view_trial_layout_button').click(function () {
	$('#trial_design_view_layout').modal("show");
    });

//    $('#trial_design_view_layout').dialog({
//	autoOpen: false,
//	height: 500,
//	width: 400,
//        modal: true,
//        buttons: {
//        Close: function() {
//	    $( this ).dialog( "close" );
//	}
//      }
//    }); 

    $('#create_new_trial_form').iframePostForm({
	json: true,
	post: function () {
            var uploadTrialLayoutFile = $("#trial_upload_file").val();
            if (uploadTrialLayoutFile === '') {
		alert("No file selected");
            }
	},
	complete: function (response) {
            if (response.error_string) {
		$("#upload_trial_error_display tbody").html('');
		$("#upload_trial_error_display tbody").append(response.error_string);
		$("#upload_trial_error_display").modal("show");
		//$(function () {
                //    $("#upload_trial_error_display").dialog({
		//	modal: true,
		//	title: "Errors in uploaded file",
		//	buttons: {
                //            Ok: function () {
		//		$(this).dialog("close");
                //           }
		//	}
                //    });
		//});
		return;
            }
            if (response.error) {
		alert(response.error);
		return;
            }
            if (response.success) {
		alert("File uploaded successfully");
            }
	}
    });

    function open_project_dialog() {
	$('#add_project_dialog').modal("show");

	//removes any old list selects before adding current ones.
	//his is important so that lists that are added and will appear without page refresh
	$("#select_list_list_select").remove();
	$("#list_of_checks_section_list_select").remove();

	//add lists to the list select and list of checks select dropdowns.  
	$("#select_list").append(list.listSelect("select_list", [ 'accessions' ] ));
	$("#list_of_checks_section").append(list.listSelect("list_of_checks_section", [ 'accessions' ]));

	//add a blank line to location select dropdown that dissappears when dropdown is opened 
	$("#add_project_location").prepend("<option value=''></option>").val('');
	$("#add_project_location").one('mousedown', function () {
            $("option:first", this).remove();
	});

	//add a blank line to list select dropdown that dissappears when dropdown is opened 
	$("#select_list_list_select").prepend("<option value=''></option>").val('');
	$("#select_list_list_select").one('mousedown', function () {
            $("option:first", this).remove();
	});

	$("#select_list_list_select").focusout(function() {
	    var stock_list_id = $('#select_list_list_select').val();
	    var stock_list;
	    if (stock_list_id != "") {
		stock_list = JSON.stringify(list.getList(stock_list_id));
	    }
	    verify_stock_list(stock_list);
	});

	//add a blank line to list of checks select dropdown that dissappears when dropdown is opened 
	$("#list_of_checks_section_list_select").prepend("<option value=''></option>").val('');
	$("#list_of_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
	});

	$("#list_of_checks_section_list_select").focusout(function() {
	    var stock_list_id = $('#list_of_checks_section_list_select').val();
	    var stock_list;
	    if (stock_list_id != "") {
		stock_list = JSON.stringify(list.getList(stock_list_id));
	    }
	    verify_stock_list(stock_list);
	});

	//add a blank line to design method select dropdown that dissappears when dropdown is opened 
	$("#select_design_method").prepend("<option value=''></option>").val('');
	$("#select_design_method").one('mousedown', function () {
            $("option:first", this).remove();
            $("#trial_design_more_info").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
	    //trigger design method change events in case the first one is selected after removal of the first blank select item
	    $("#select_design_method").change();
	});
	
	//reset previous selections
	$("#select_design_method").change();

	var method_to_use = $('.format_type:checked').val();
        if (method_to_use == "empty") {
            $("#trial_design_info").hide();
            $("#trial_design_more_info").hide();
            $("#get_file_upload_data").hide();
        }
        if (method_to_use == "create_with_upload") {
            $("#get_file_upload_data").show();
            $("#trial_design_info").hide();
            $("#trial_design_more_info").hide();
        } else {
            $("#get_file_upload_data").hide();
        }
        if (method_to_use == "create_with_design_tool") {
            $("#trial_design_info").show();
	    $("#select_design_method").change();
        } else {
            $("trial_design_info").hide();
        }
    }

    $('#add_project_link').click(function () {
        open_project_dialog();
    });

});
