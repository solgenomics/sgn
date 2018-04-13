/*jslint browser: true, devel: true */

/**

=head1 AddMultipleTrial.js

Dialogs for adding multilocation trials


=head1 AUTHOR

Alex Ogbonna <aco46@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var list = new CXGN.List();

    var design_json;

    $(document).on('focusout', '#select_list_multi_list_select', function() {
        if ($('#select_list_multi_list_select').val()) {
            var stock_list_id = $('#select_list_multi_list_select').val();
            var stock_list = JSON.stringify(list.getList(stock_list_id));
            verify_stock_list(stock_list);
        }
    });

    $(document).on('focusout', '#list_of_checks_section_multi_list_select', function() {
        if ($('#list_of_checks_section_multi_list_select').val()) {
            var stock_list_id = $('#list_of_checks_section_multi_list_select').val();
            var stock_list = JSON.stringify(list.getList(stock_list_id));
            verify_stock_list(stock_list);
        }
    });

    $(document).on('focusout', '#crbd_list_of_checks_section_multi_list_select', function() {
        if ($('#crbd_list_of_checks_section_multi_list_select').val()) {
            var stock_list_id = $('#crbd_list_of_checks_section_multi_list_select').val();
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

  function generate_multi_experimental_design() {
      var name = $('#new_multi_trial_name').val();
      var year = $('#add_multi_project_year').val();
      var desc = $('#add_multi_project_description').val();
      var trial_location = $('#add_multi_project_location').val();
      var block_number = $('#block_number_multi').val();
      var row_number= $('#row_number_multi').val();
      var row_number_per_block=$('#row_number_per_block_multi').val();
      var col_number_per_block=$('#col_number_per_block_multi').val();
      var col_number=$('#col_number_multi').val();
      var location_list_id = $('#select_list_locations_multi_list_select').val();
      var stock_list_id = $('#select_list_multi_list_select').val();
      var control_list_id = $('#list_of_checks_section_multi_list_select').val();
      var control_list_id_crbd = $('#crbd_list_of_checks_section_multi_list_select').val();
      var control_list_crbd;
      if (control_list_id_crbd != ""){
          control_list_crbd = JSON.stringify(list.getList(control_list_id_crbd));
      }
      var location_list;
      if (location_list_id != "") {
          location_list = JSON.stringify(list.getList(location_list_id));
      } else {
        location_list = JSON.stringify(trial_location);
      }

      var stock_list;
      if (stock_list_id != "") {
          stock_list = JSON.stringify(list.getList(stock_list_id));
      }
      var control_list;
      if (control_list_id != "") {
          control_list = JSON.stringify(list.getList(control_list_id));
      }

      var design_type = $('#select_multi-design_method').val();

      var use_same_layout;
      if ($('#use_same_layout').is(':checked')) {
         use_same_layout = $('#use_same_layout').val();
      }
      else {
         use_same_layout = "";
      }

      var rep_count = $('#rep_count_multi').val();
      var block_size = $('#block_size_multi').val();
      var max_block_size = $('#max_block_size_multi').val();
      var plot_prefix = $('#plot_prefix_multi').val();
      var start_number = $('#start_number_multi').val();
      var increment = $('#increment_multi').val();

      $.ajax({
          type: 'POST',
          timeout: 3000000,
          url: '/ajax/trial/generate_experimental_design',
          beforeSend: function(){
              $('#working_modal').modal("show");
          },
          dataType: "json",
          data: {
              'project_name': name,
              'project_description': desc,
              'year': year,
              'trial_location': location_list,
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
              'use_same_layout': use_same_layout,
          },
          success: function (response) {
              if (response.error) {
                  alert(response.error);
                  $('#working_modal').modal("hide");
              } else {
                $('#multi_trial_design_information').html(response.design_info_view_html);
                var layout_view = JSON.parse(response.design_layout_view_html);
                //console.log(layout_view);
                var layout_html = '';
                for (var i=0; i<layout_view.length; i++) {
                  //console.log(layout_view[i]);
                  layout_html += layout_view[i] + '<br>';
                }
                $('#multi_trial_design_view_layout_return').html(layout_html);
                //$('#multi_trial_design_view_layout_return').html(response.design_layout_view_html);

                $('#working_modal').modal("hide");
                $('#multi_trial_design_confirm').modal("show");
                design_json = response.design_json;
              }
          },
          error: function () {
            $('#working_modal').modal("hide");
            alert('An error occurred. sorry.');
          }
     });
  }

  $(document).on('click', '#new_multi_trial_submit', function () {
        var name = $('#new_multi_trial_name').val();
        var year = $('#add_multi-project_year').val();
        var desc = $('textarea#add_multi-project_description').val();
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
            if (method_to_use == "create_with_design_tool") {
              generate_multi_experimental_design();
            }
        } else {
            alert('Accession list is not valid!');
            return;
        }

  });

  $(document).on('change', '#select_multi-design_method', function () {

      var design_method = $("#select_multi-design_method").val();
      if (design_method == "CRD") {
          $("#trial_multi-design_more_info").show();
          $("#show_list_of_checks_section_multi").hide();
          $("#crbd_show_list_of_checks_section_multi").show();
          $("#rep_count_section_multi").show();
          $("#block_number_section_multi").hide();
          $("#block_size_section_multi").hide();
          $("#max_block_section_multi").hide();
          $("#row_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#col_number_per_block_section_multi").hide();
          $("#col_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#other_parameter_section_multi").hide();
          $("#design_info_multi").show();
          $("#greenhouse_num_plants_per_accession_section_multi").hide();
      } else if (design_method == "RCBD") {
          $("#trial_multi-design_more_info").show();
          $("#crbd_show_list_of_checks_section_multi").show();
          $("#show_list_of_checks_section_multi").hide();
          $("#rep_count_section_multi").hide();
          $("#block_number_section_multi").show();
          $("#block_size_section_multi").hide();
          $("#max_block_size_section_multi").hide();
          $("#row_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#col_number_per_block_section_multi").hide();
          $("#col_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#other_parameter_section_multi").hide();
          $("#design_info_multi").show();
          $("#greenhouse_num_plants_per_accession_section_multi").hide();
      } else if (design_method == "Alpha") {
          $("#trial_multi-design_more_info").show();
          $("#crbd_show_list_of_checks_section_multi").show();
          $("#show_list_of_checks_section_multi").hide();
          $("#rep_count_section_multi").show();
          $("#block_number_section_multi").hide();
          $("#block_size_section_multi").show();
          $("#max_block_size_section_multi").hide();
          $("#row_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#col_number_per_block_section_multi").hide();
          $("#col_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#other_parameter_section_multi").hide();
          $("#design_info_multi").show();
          $("#greenhouse_num_plants_per_accession_section_multi").hide();
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
          $("#trial_multi-design_more_info").show();
          $("#show_list_of_checks_section_multi").show();
          $("#crbd_show_list_of_checks_section_multi").hide();
          $("#rep_count_section_multi").hide();
          $("#block_number_section_multi").hide();
          $("#block_size_section_multi").hide();
          $("#max_block_size_section_multi").show();
          $("#row_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#col_number_per_block_section_multi").hide();
          $("#col_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#other_parameter_section_multi").hide();
          $("#design_info_multi").show();
          $("#greenhouse_num_plants_per_accession_section_multi").hide();
      } else if (design_method == "") {
          $("#show_list_of_checks_section_multi").hide();
          $("#crbd_show_list_of_checks_section_multi").hide();
          $("#trial_design_more_info_multi").hide();
          $("#trial_multi-design_more_info_multi").hide();
          $("#rep_count_section_multi").hide();
          $("#block_number_section_multi").hide();
          $("#block_size_section_multi").hide();
          $("#max_block_size_section_multi").hide();
          $("#row_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#col_number_per_block_section_multi").hide();
          $("#col_number_section_multi").hide();
          $("#row_number_per_block_section_multi").show();
          $("#other_parameter_section_multi").hide();
          $("#other_parameter_section_multi").hide();
          $("#design_info_multi").show();
          $("#greenhouse_num_plants_per_accession_section_multi").hide();
      }
      else if (design_method == "MAD") {
          $("#trial_multi-design_more_info").show();
          $("#show_list_of_checks_section_multi").show();
          $("#crbd_show_list_of_checks_section_multi").hide();
          $("#rep_count_section_multi").hide();
          $("#row_number_section_multi").show();
          $("#block_number_section_multi").hide();
          $("#block_size_section_multi").hide();
          $("#row_number_per_block_section_multi").show();
          $("#col_number_per_block_section_multi").show();
          $("#col_number_section_multi").show();
          $("#max_block_size_section_multi").hide();
          $("#row_number_per_block_section_multi").show();
          $("#other_parameter_section_multi").show();
          $("#design_info_multi").show();

          $("#show_other_parameter_options_multi").click(function () {
              if ($('#show_other_parameter_options_multi').is(':checked')) {
                  $("#other_parameter_options_multi").show();
              }
              else {
                  $("#other_parameter_options_multi").hide();
              }
          });
          $("#greenhouse_num_plants_per_accession_section_multi").hide();
      }

      else if (design_method == 'greenhouse') {
          $("#trial_multi-design_more_info").show();
          $("#show_list_of_checks_section_multi").hide();
          $("#rep_count_section_multi").hide();
          $("#block_number_section_multi").hide();
          $("#block_size_section_multi").hide();
          $("#max_block_section_multi").hide();
          $("#row_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#col_number_per_block_section_multi").hide();
          $("#col_number_section_multi").hide();
          $("#row_number_per_block_section_multi").hide();
          $("#other_parameter_section_multi").hide();
          $("#design_info_multi").hide();
          $("#greenhouse_num_plants_per_accession_section_multi").show();
          greenhouse_show_num_plants_section_multi();
      }

      else {
          alert("Unsupported design method");
      }
  });

  $("#show_plot_naming_options_multi").click(function () {
  if ($('#show_plot_naming_options_multi').is(':checked')) {
    $("#plot_naming_options_multi").show();
  }
  else {
    $("#plot_naming_options_multi").hide();
  }

  });


  jQuery(document).on('change', '#select_list_multi_list_select', function() {
      if (jQuery("#select_multi-design_method").val() == 'greenhouse') {
          greenhouse_show_num_plants_section_multi();
      }
  });

  $("#select_list_locations_multi").append(list.listSelect("select_list_locations_multi", [ 'locations' ], "select location list", 'refresh' ));

  function open_multilocation_project_dialog() {
    $('#add_multilocation_project_dialog').modal("show");
    $("#select_list_multi_list_select").remove();
    $("#select_seedlot_list_multi_list_select").remove();
    $("#list_of_checks_section_multi_list_select").remove();
    $("#crbd_list_of_checks_section_multi_list_select").remove();
    $("#select_list_multi").append(list.listSelect("select_list_multi", [ 'accessions' ], '', 'refresh' ));
    $("#select_seedlot_list_multi").append(list.listSelect("select_seedlot_list_multi", [ 'seedlots' ], '', 'refresh'));
    $("#list_of_checks_section_multi").append(list.listSelect("list_of_checks_section_multi", [ 'accessions' ], '', 'refresh'));
    $("#crbd_list_of_checks_section_multi").append(list.listSelect("crbd_list_of_checks_section_multi", [ 'accessions' ], "select optional check list", 'refresh'));

    //add a blank line to location select dropdown that dissappears when dropdown is opened
    $("#add_project_location").prepend("<option value=''></option>").val('');
    $("#add_project_location").one('mousedown', function () {
              $("option:first", this).remove();
    });

    //add a blank line to list select dropdown that dissappears when dropdown is opened
    $("#select_list_multi_list_select").prepend("<option value=''></option>").val('');
    $("#select_list_multi_list_select").one('mousedown', function () {
              $("option:first", this).remove();
    });

    //add a blank line to list select dropdown that dissappears when dropdown is opened
    $("#select_seedlot_list_multi_list_select").prepend("<option value=''></option>").val('');
    $("#select_seedlot_list_multi_list_select").one('mousedown', function () {
              $("option:first", this).remove();
    });

    //add a blank line to list of checks select dropdown that dissappears when dropdown is opened
    $("#list_of_checks_section_multi_list_select").prepend("<option value=''></option>").val('');
    $("#list_of_checks_section_multi_list_select").one('mousedown', function () {
              $("option:first", this).remove();
    });

    $("#crbd_list_of_checks_section_multi_list_select").prepend("<option value=''></option>").val('');
    $("#crbd_list_of_checks_section_multi_list_select").one('mousedown', function () {
              $("option:first", this).remove();
    });

    //add a blank line to design method select dropdown that dissappears when dropdown is opened
    $("#select_multi-design_method").prepend("<option value=''></option>").val('');
    $("#select_multi-design_method").one('mousedown', function () {
              $("option:first", this).remove();
              $("#trial_multi-design_more_info").show();
        //trigger design method change events in case the first one is selected after removal of the first blank select item
        $("#select_multi-design_method").change();
    });

    //reset previous selections
    $("#select_multi-design_method").change();

    var method_to_use = $('.format_type:checked').val();
          if (method_to_use == "empty") {
              $("#trial_multi-design_info").hide();
              $("#trial_multi-design_more_info").hide();
              $("#get_file_upload_data").hide();
          }
          if (method_to_use == "create_with_upload") {
              $("#get_file_upload_data").show();
              $("#trial_multi-design_info").hide();
              $("#trial_multi-design_more_info").hide();
          } else {
              $("#get_file_upload_data").hide();
          }
          if (method_to_use == "create_with_design_tool") {
              $("#trial_multi-design_info").show();
              $("#select_multi-design_method").change();
          } else {
              $("trial_multi-design_info").hide();
          }
  }

  $('#add_multiloc_project_link').click(function () {
      get_select_box('years', 'add_multi_project_year', {'auto_generate': 1 });
      get_select_box('trial_types', 'add_multi_project_type', {'empty':1} );
      open_multilocation_project_dialog();

  });


  function save_experimental_design(design_json) {
  //  var decoded_design = JSON.parse(design_json);

      var list = new CXGN.List();
      var name = jQuery('#new_multi_trial_name').val();
      var year = jQuery('#add_multi_project_year').val();
      var desc = jQuery('#add_multi_project_description').val();
      var trial_location = jQuery('#add_multi_project_location').val();
      //var block_number = jQuery('#block_number_multi').val();
      var stock_list_id = jQuery('#select_list_multi_list_select').val();
      var control_list_id = jQuery('#list_of_checks_section_multi_list_select').val();
      var location_list_id = jQuery('#select_list_locations_multi_list_select').val();
      var location_list;
      var num_plants_per_plot = 0;
      var num_subplots_per_plot = 0;

      var locations;
      var location_list_id = jQuery('#select_list_locations_multi_list_select').val();
      if (location_list_id != "") {
          location_list = JSON.stringify(list.getList(location_list_id));
      } else {
          location_list = JSON.stringify(trial_location);
      }

      var design_type = jQuery('#select_multi-design_method').val();
      var greenhouse_num_plants = [];
      if (stock_list_id != "" && design_type == 'greenhouse') {
          for (var i=0; i<stock_list_array.length; i++) {
              var value = jQuery("input#multi_greenhouse_num_plants_input_" + i).val();
              if (value == '') {
                  value = 1;
              }
              greenhouse_num_plants.push(value);
          }
          //console.log(greenhouse_num_plants);
      }

      var use_same_layout;
      if ($('#use_same_layout').is(':checked')) {
         use_same_layout = $('#use_same_layout').val();
      }
      else {
         use_same_layout = "";
      }

      var breeding_program_name = jQuery('#select_breeding_program_multi').val();
      var trial_type = jQuery('#add_multi_project_type').val();

      //var stock_verified = verify_stock_list(stock_list);
      if (desc == '' || year == '') {
         alert('Year and description are required.');
         return;
      }
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
              'use_same_layout': use_same_layout,
              'year': year,
              'trial_type': trial_type,
              'trial_location': location_list,
              'design_type': design_type,
              'design_json': design_json,
              'breeding_program_name': breeding_program_name,
              'greenhouse_num_plants': JSON.stringify(greenhouse_num_plants),
              'has_plant_entries': num_plants_per_plot,
              'has_subplot_entries': num_subplots_per_plot,
          },
          success: function (response) {
              if (response.error) {
                  jQuery('#working_modal').modal("hide");
                  alert(response.error);
                  jQuery('#multi_trial_design_confirm').modal("hide");
              } else {
                  refreshTrailJsTree(0);
                  //alert('Trial design saved');
                  jQuery('#working_modal').modal("hide");
                  jQuery('#multi_trial_saved_dialog_message').modal("show");
              }
          },
          error: function () {
              jQuery('#trial_saving_dialog').dialog("close");
              alert('An error occurred saving the trial.');
              jQuery('#multi_trial_design_confirm').dialog("close");
          }
      });
  }

  jQuery('#new_multi_trial_confirm_submit').click(function () {
          save_experimental_design(design_json);
  });

  $('#view_multi_trial_layout_button').click(function () {
      $('#trial_multi_design_view_layout').modal("show");
  });

  $('#redo_multiloc_trial_layout_button').click(function () {
      generate_multi_experimental_design();
      $('#trial_multi_design_view_layout').modal("show");
  });

});

function greenhouse_show_num_plants_section_multi(){
    var list = new CXGN.List();
    var stock_list_id = jQuery('#select_list_multi_list_select').val();
    if (stock_list_id != "") {
        stock_list = list.getList(stock_list_id);
        //console.log(stock_list);
        var html = '<form class="form-horizontal">';
        for (var i=0; i<stock_list.length; i++){
            html = html + '<div class="form-group"><label class="col-sm-3 control-label">' + stock_list[i] + ': </label><div class="col-sm-9"><input class="form-control" id="multi_greenhouse_num_plants_input_' + i + '" type="text" placeholder="1" /></div></div>';
        }
        html = html + '</form>';
        jQuery("#greenhouse_num_plants_per_accession_multi").empty().html(html);
    }
}
