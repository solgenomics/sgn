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

    $(document).on('focusout', '#select_list_list_select', function() {
        if ($('#select_list_list_select').val()) {
            var stock_list_id = $('#select_list_list_select').val();
            var stock_list = JSON.stringify(list.getList(stock_list_id));
            verify_stock_list(stock_list);
        }
    });

    $(document).on('focusout', '#list_of_checks_section_list_select', function() {
        if ($('#list_of_checks_section_list_select').val()) {
            var stock_list_id = $('#list_of_checks_section_list_select').val();
            var stock_list = JSON.stringify(list.getList(stock_list_id));
            verify_stock_list(stock_list);
        }
    });

    $(document).on('focusout', '#crbd_list_of_checks_section_list_select', function() {
        if ($('#crbd_list_of_checks_section_list_select').val()) {
            var stock_list_id = $('#crbd_list_of_checks_section_list_select').val();
            var stock_list = JSON.stringify(list.getList(stock_list_id));
            verify_stock_list(stock_list);
        }
    });

    var stock_list_verified = 0;
    function verify_stock_list(stock_list) {
        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/verify_stock_list',
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            dataType: "json",
            data: {
                'stock_list': stock_list,
            },
            success: function (response) {
                //console.log(response);
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(response.error);
                    stock_list_verified = 0;
                }
                if (response.success){
                    stock_list_verified = 1;
                }
            },
            error: function () {
                jQuery('#working_modal').modal('hide');
                alert('An error occurred. sorry');
                stock_list_verified = 0;
            }
       });
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
        var control_list_id_crbd = $('#crbd_list_of_checks_section_list_select').val();

        var control_list_crbd;
        if (control_list_id_crbd != ""){
            control_list_crbd = JSON.stringify(list.getList(control_list_id_crbd));
        }
        var stock_list;
        if (stock_list_id != "") {
            stock_list_array = list.getList(stock_list_id);
            stock_list = JSON.stringify(list.getList(stock_list_id));
        }
        var control_list;
        if (control_list_id != "") {
            control_list = JSON.stringify(list.getList(control_list_id));
        }

        var design_type = $('#select_design_method').val();
        if (design_type == "") {
            var design_type = $('#select_multi-design_method').val();
        }

        var rep_count = $('#rep_count').val();
        var block_size = $('#block_size').val();
        var max_block_size = $('#max_block_size').val();
        var plot_prefix = $('#plot_prefix').val();
        var start_number = $('#start_number').val();
        var increment = $('#increment').val();
        var fieldmap_col_number = $('#fieldMap_col_number').val();
        var fieldmap_row_number = $('#fieldMap_row_number').val();
        var plot_layout_format = $('#plot_layout_format').val();

        var greenhouse_num_plants = [];
        if (stock_list_id != "" && design_type == 'greenhouse') {
            for (var i=0; i<stock_list_array.length; i++) {
                var value = jQuery("input#greenhouse_num_plants_input_" + i).val();
                if (value == '') {
                    value = 1;
                }
                greenhouse_num_plants.push(value);
            }
            //console.log(greenhouse_num_plants);
        }

        //alert(design_type);

        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/generate_experimental_design',
            dataType: "json",
            beforeSend: function() {
                $('#working_modal').modal("show");
            },
            data: {
                'project_name': name,
                'project_description': desc,
                'year': year,
                'trial_location': trial_location,
                'stock_list': stock_list,
                'control_list': control_list,
                'control_list_crbd': control_list_crbd,
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
                'greenhouse_num_plants': JSON.stringify(greenhouse_num_plants),
                'fieldmap_col_number': fieldmap_col_number,
                'fieldmap_row_number': fieldmap_row_number,
                'plot_layout_format': plot_layout_format,
            },
            success: function (response) {
                $('#working_modal').modal("hide");
                if (response.error) {
                    alert(response.error);
                } else {

                    $('#trial_design_information').html(response.design_info_view_html);
                    var layout_view = JSON.parse(response.design_layout_view_html);
                    //console.log(layout_view);
                    var layout_html = '';
                    for (var i=0; i<layout_view.length; i++) {
                        //console.log(layout_view[i]);
                        layout_html += layout_view[i] + '<br>';
                    }
                    $('#trial_design_view_layout_return').html(layout_html);
                    //$('#trial_design_view_layout_return').html(response.design_layout_view_html);

                    $('#working_modal').modal("hide");
                    $('#trial_design_confirm').modal("show");
                    design_json = response.design_json;
                }
            },
            error: function () {
                $('#working_modal').modal("hide");
                alert('An error occurred. sorry.');
            }
       });
    }

    //When the user submits the form, input validation happens here before proceeding to design generation
    $(document).on('click', '#new_trial_submit', function () {
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
        if (stock_list_verified == 1){
            if (method_to_use == "empty") {
                alert('adding a project');
                save_project_info(name, year, desc);
            }
            if (method_to_use == "create_with_design_tool") {
                generate_experimental_design();
            }
        } else {
            alert('Accession list is not valid!');
            return;
        }
    });

    $(document).on('change', '#select_design_method', function () {
        //$("#add_project_dialog").dialog("option", "height","auto");

        var design_method = $("#select_design_method").val();
        if (design_method == "CRD") {
            $("#trial_design_more_info").show();
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            //$("#fieldmap_options").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").hide();
            $("#crbd_show_list_of_checks_section").show();
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
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
        } else if (design_method == "RCBD") {
            $("#trial_design_more_info").show();
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#crbd_show_list_of_checks_section").show();
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
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
        } else if (design_method == "Alpha") {
            $("#FieldMap").show();
            $("#trial_design_more_info").show();
            $("#trial_multi-design_more_info").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#crbd_show_list_of_checks_section").show();
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
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
        } else if (design_method == "Lattice") {
            $("#FieldMap").show();
            $("#trial_design_more_info").show();
            $("#trial_multi-design_more_info").show();
            $("#crbd_show_list_of_checks_section").show();
            $("#show_list_of_checks_section").hide();
            $("#rep_count_section").show();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_size_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
        } else if (design_method == "Augmented") {
            $("#FieldMap").hide();
            $("#trial_design_more_info").show();
            $("#trial_multi-design_more_info").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").show();
            $("#crbd_show_list_of_checks_section").hide();
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
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
        } else if (design_method == "") {
            $("#FieldMap").hide();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").hide();
            $("#crbd_show_list_of_checks_section").hide();
            $("#trial_design_more_info").hide();
            $("#trial_multi-design_more_info").hide();
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
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
        }

        else if (design_method == "MAD") {
            $("#FieldMap").hide();
            $("#trial_design_more_info").show();
            $("#trial_multi-design_more_info").show();
            //$("#add_project_dialog").dialog("option", "height","auto");
            $("#show_list_of_checks_section").show();
            $("#crbd_show_list_of_checks_section").hide();
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
            $("#design_info").show();

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
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
        }

        else if (design_method == 'greenhouse') {
            $("#FieldMap").hide();
            $("#trial_design_more_info").show();
            $("#trial_multi-design_more_info").show();
            $("#show_list_of_checks_section").hide();
            $("#crbd_show_list_of_checks_section").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").hide();
            $("#block_size_section").hide();
            $("#max_block_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").hide();
            $('#greenhouse_default_num_plants_per_accession').show();
            $("#greenhouse_num_plants_per_accession_section").show();
            $('#greenhouse_default_num_plants_per_accession').show();
            greenhouse_show_num_plants_section();
        }

        else {
            alert("Unsupported design method");
        }
    });

    jQuery(document).on('change', '#select_list_list_select', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });
    jQuery(document).on('keyup', '#greenhouse_default_num_plants_per_accession_val', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });

    jQuery(document).on('keyup', '#greenhouse_default_num_plants_per_accession_val', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
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

    $("#show_field_map_options").click(function () {
      if ($('#show_field_map_options').is(':checked')) {
        $("#field_map_options").show();
      }
      else {
        $("#field_map_options").hide();
      }
    });

    function save_experimental_design(design_json) {
        var list = new CXGN.List();
        var name = jQuery('#new_trial_name').val();
        var year = jQuery('#add_project_year').val();
        var desc = jQuery('#add_project_description').val();
        var trial_location = jQuery('#add_project_location').val();
        var block_number = jQuery('#block_number').val();
        var stock_list_id = jQuery('#select_list_list_select').val();
        var control_list_id = jQuery('#list_of_checks_section_list_select').val();
        var stock_list;
        if (stock_list_id != "") {
            stock_list_array = list.getList(stock_list_id);
            stock_list = JSON.stringify(list.getList(stock_list_id));
        }
        var control_list;
        if (control_list_id != "") {
           control_list = JSON.stringify(list.getList(control_list_id));
        }
        var design_type = jQuery('#select_design_method').val();
        if (design_type == "") {
            var design_type = jQuery('#select_multi-design_method').val();
        }
        var greenhouse_num_plants = [];
        if (stock_list_id != "" && design_type == 'greenhouse') {
            for (var i=0; i<stock_list_array.length; i++) {
                var value = jQuery("input#greenhouse_num_plants_input_" + i).val();
                if (value == '') {
                    value = 1;
                }
                greenhouse_num_plants.push(value);
            }
            //console.log(greenhouse_num_plants);
        }

        //alert(design_type);

        var rep_count = jQuery('#rep_count').val();
        var block_size = jQuery('#block_size').val();
        var max_block_size = jQuery('#max_block_size').val();
        var plot_prefix = jQuery('#plot_prefix').val();
        var start_number = jQuery('#start_number').val();
        var increment = jQuery('#increment').val();
        var breeding_program_name = jQuery('#select_breeding_program').val();
        var fieldmap_col_number = jQuery('#fieldMap_col_number').val();
        var fieldmap_row_number = jQuery('#fieldMap_row_number').val();
        var plot_layout_format = jQuery('#plot_layout_format').val();
        var trial_type = jQuery('#add_project_type').val();

        jQuery.ajax({
           type: 'POST',
           timeout: 3000000,
           url: '/ajax/trial/save_experimental_design',
           dataType: "json",
           beforeSend: function() {
               jQuery('#working_modal').modal("show");
           },
           data: {
                'project_name': name,
                'project_description': desc,
                //'trial_name': trial_name,
                'year': year,
                'trial_type': trial_type,
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
                'greenhouse_num_plants': JSON.stringify(greenhouse_num_plants),
                'fieldmap_col_number': fieldmap_col_number,
                'fieldmap_row_number': fieldmap_row_number,
                'plot_layout_format': plot_layout_format,
            },
            success: function (response) {
                if (response.error) {
                    jQuery('#working_modal').modal("hide");
                    alert(response.error);
                    jQuery('#trial_design_confirm').modal("hide");
                } else {
                    //alert('Trial design saved');
                    jQuery('#working_modal').modal("hide");
                    jQuery('#trial_saved_dialog_message').modal("show");
                }
            },
            error: function () {
                jQuery('#trial_saving_dialog').dialog("close");
                alert('An error occurred saving the trial.');
                jQuery('#trial_design_confirm').dialog("close");
            }
        });
    }

    jQuery('#new_trial_confirm_submit').click(function () {
            save_experimental_design(design_json);
    });

    $('#view_trial_layout_button').click(function () {
        $('#trial_design_view_layout').modal("show");
    });

    function open_project_dialog() {
	$('#add_project_dialog').modal("show");

	//removes any old list selects before adding current ones.
	//his is important so that lists that are added and will appear without page refresh
	$("#select_list_list_select").remove();
	$("#list_of_checks_section_list_select").remove();

  $("#select_list_list_select").remove();
	$("#crbd_list_of_checks_section_list_select").remove();

	//add lists to the list select and list of checks select dropdowns.
	$("#select_list").append(list.listSelect("select_list", [ 'accessions' ], '', 'refresh'));
	$("#list_of_checks_section").append(list.listSelect("list_of_checks_section", [ 'accessions' ], '', 'refresh'));

  //add lists to the list select and list of checks select dropdowns for CRBD.
	$("#crbd_list_of_checks_section").append(list.listSelect("crbd_list_of_checks_section", [ 'accessions' ], "select optional check list", 'refresh'));

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

	//add a blank line to list of checks select dropdown that dissappears when dropdown is opened
	$("#list_of_checks_section_list_select").prepend("<option value=''></option>").val('');
	$("#list_of_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
	});

  $("#crbd_list_of_checks_section_list_select").prepend("<option value=''></option>").val('');
  $("#crbd_list_of_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
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
        } else {
            $("trial_design_info").hide();
        }
    }

     $('#add_project_link').click(function () {
         get_select_box('years', 'add_project_year', {'auto_generate': 1 });
         get_select_box('trial_types', 'add_project_type', {'empty':1} );
         open_project_dialog();
     });

});

function greenhouse_show_num_plants_section(){
    var list = new CXGN.List();
    var stock_list_id = jQuery('#select_list_list_select').val();
    var default_num = jQuery('#greenhouse_default_num_plants_per_accession_val').val();
    if (stock_list_id != "") {
        stock_list = list.getList(stock_list_id);
        //console.log(stock_list);
        var html = '<form class="form-horizontal">';
        for (var i=0; i<stock_list.length; i++){
            html = html + '<div class="form-group"><label class="col-sm-9 control-label">' + stock_list[i] + ': </label><div class="col-sm-3"><input class="form-control" id="greenhouse_num_plants_input_' + i + '" type="text" placeholder="'+default_num+'" value="'+default_num+'" /></div></div>';
        }
        html = html + '</form>';
        jQuery("#greenhouse_num_plants_per_accession").empty().html(html);
    }
}
