/*jslint browser: true, devel: true */

/**

=head1 UploadTrial.js

Dialogs for uploading trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var trial_id;
    var plants_per_plot;
    var inherits_plot_treatments;
    jQuery('#upload_trial_trial_sourced').change(function(){
        if(jQuery(this).val() == 'yes'){
            jQuery('#upload_trial_source_trial_section').show();
        } else {
            jQuery('#upload_trial_source_trial_section').hide();
        }
    });

    jQuery('#trial_upload_breeding_program').change(function(){
        populate_upload_trial_linkage_selects();
    });

    function populate_upload_trial_linkage_selects(){
        get_select_box('trials', 'upload_trial_trial_source', {'id':'upload_trial_trial_source_select', 'name':'upload_trial_trial_source_select', 'breeding_program_name':jQuery('#trial_upload_breeding_program').val(), 'multiple':1, 'empty':1} );
    }

    function upload_trial_validate_form(){
        var trial_name = $("#trial_upload_name").val();
        var breeding_program = $("#trial_upload_breeding_program").val();
        var location = $("#trial_upload_location").val();
        var trial_year = $("#trial_upload_year").val();
        var description = $("#trial_upload_description").val();
        var design_type = $("#trial_upload_design_method").val();
        var uploadFile = $("#trial_uploaded_file").val();
        var trial_stock_type = $("#trial_upload_trial_stock_type").val();
        var plot_width = $("#trial_upload_plot_width").val();
        var plot_length = $("#trial_upload_plot_length").val();
        plants_per_plot = $("#trial_upload_plant_entries").val();
        inherits_plot_treatments = $('#trial_upload_plants_per_plot_inherit_treatments').val();


        if (trial_name === '') {
            alert("Please give a trial name");
        }
        else if (breeding_program === '') {
            alert("Please give a breeding program");
        }
        else if (location === '') {
            alert("Please give a location");
        }
        else if (trial_year === '') {
            alert("Please give a trial year");
        }
        else if (plot_width < 0 ){
            alert("Please check the plot width");
        }
        else if (plot_width > 13){
            alert("Please check the plot width is too high");
        }
        else if (plot_length < 0){
            alert("Please check the plot length");
        }
        else if (plot_length > 13){
            alert("Please check the plot length is too high");
        }
        else if (plants_per_plot > 500) {
            alert("Please no more than 500 plants per plot.");
        }
        else if (description === '') {
            alert("Please give a description");
        }
        else if (trial_stock_type === '') {
            alert("Please select stock type being evaluated in trial");
        }
        else if (design_type === '') {
            alert("Please give a design type");
        }
        else if (uploadFile === '') {
            alert("Please select a file");
        }
        else {
            verify_upload_trial_name(trial_name);
        }
    }

    function verify_upload_trial_name(trial_name){
        jQuery.ajax( {
            url: '/ajax/trial/verify_trial_name?trial_name='+trial_name,
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                console.log(response);
                jQuery("#working_modal").modal("hide");
                if (response.error){
                    alert(response.error);
                    jQuery('[name="upload_trial_submit_first"]').attr('disabled', true);
                    jQuery('[name="upload_trial_submit_second"]').attr('disabled', true);
                }
                else {
                    jQuery('[name="upload_trial_submit_first"]').attr('disabled', false);
                    jQuery('[name="upload_trial_submit_second"]').attr('disabled', false);
                }
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred checking trial name');
            }
        });
    }

    function upload_trial_file() {
        $('#upload_trial_form').attr("action", "/ajax/trial/upload_trial_file");
        $("#upload_trial_form").submit();
    }

    function upload_multiple_trial_designs_file() {
      $("#upload_multiple_trials_warning_messages").html('');
      $("#upload_multiple_trials_error_messages").html('');
      $("#upload_multiple_trials_success_messages").html('');
      $('#upload_multiple_trial_designs_form').attr("action", "/ajax/trial/upload_multiple_trial_designs_file");
      $("#upload_multiple_trial_designs_form").submit();
  }


    function open_upload_trial_dialog() {
        $('#upload_trial_dialog').modal("show");
        //add a blank line to design method select dropdown that dissappears when dropdown is opened
        $("#trial_upload_design_method").prepend("<option value=''></option>").val('');
        $("#trial_upload_design_method").one('mousedown', function () {
            $("option:first", this).remove();
            $("#trial_design_more_info").show();
            //trigger design method change events in case the first one is selected after removal of the first blank select item
            $("#trial_upload_design_method").change();
        });

        //reset previous selections
        $("#trial_upload_design_method").change();
    }

    function add_plants_per_plot() {
        if (plants_per_plot && plants_per_plot != 0) {
            jQuery.ajax( {
                url: '/ajax/breeders/trial/'+trial_id+'/create_plant_entries/',
                type: 'POST',
                data: {
                    'plants_per_plot' : plants_per_plot,
                    'inherits_plot_treatments' : inherits_plot_treatments,
                },
                success: function(response) {
                    console.log(response);
                    if (response.error) {
                    alert(response.error);
                    }
                    else {
                    jQuery('#add_plants_dialog').modal("hide");
                    }
                },
                error: function(response) {
                    alert(response);
                },
                });
        }
    }


    $('[name="upload_trial_link"]').click(function () {
        get_select_box('years', 'trial_upload_year', {'auto_generate': 1 });
        get_select_box('trial_types', 'trial_upload_trial_type', {'empty': 1 });
        populate_upload_trial_linkage_selects();
        open_upload_trial_dialog();
    });

    $('#upload_trial_validate_form_button').click(function(){
        upload_trial_validate_form();
    });

    $('[name="upload_trial_submit_first"]').click(function () {
        upload_trial_file();
    });

    $('[name="upload_trial_submit_second"]').click(function () {
        upload_trial_file();
    });

    $('#multiple_trial_designs_upload_submit').click(function () {
      console.log("Registered click on multiple_trial_designs_upload_submit button");
        upload_multiple_trial_designs_file();
    });

    $("#upload_single_trial_design_format_info").click( function () {
        $("#trial_upload_spreadsheet_info_dialog" ).modal("show");
    });

    $("#upload_multiple_trial_designs_format_info").click( function () {
        $("#multiple_trial_upload_spreadsheet_info_dialog" ).modal("show");
    });

    $('#upload_trial_form').iframePostForm({
        json: true,
        post: function () {
            var uploadedTrialLayoutFile = $("#trial_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedTrialLayoutFile === '') {
                $('#working_modal').modal("hide");
                alert("No file selected");
                return;
            }
        },
        complete: function (response) {
            trial_id = response.trial_id;
            console.log(response);

            $('#working_modal').modal("hide");
            if (response.error) {
                alert(response.error);
                return;
            }
            else if (response.error_string) {

                if (response.missing_accessions) {
                    jQuery('#upload_trial_missing_accessions_div').show();
                    var missing_accessions_html = "<div class='well well-sm'><h3>Add the missing accessions to a list</h3><div id='upload_trial_missing_accessions' style='display:none'></div><div id='upload_trial_add_missing_accessions'></div></div><br/>";
                    $("#upload_trial_add_missing_accessions_html").html(missing_accessions_html);

                    var missing_accessions_vals = '';
                    for(var i=0; i<response.missing_accessions.length; i++) {
                        missing_accessions_vals = missing_accessions_vals + response.missing_accessions[i] + '\n';
                    }
                    $("#upload_trial_missing_accessions").html(missing_accessions_vals);
                    addToListMenu('upload_trial_add_missing_accessions', 'upload_trial_missing_accessions', {
                        selectText: true,
                        listType: 'accessions'
                    });
                } else {
                    jQuery('#upload_trial_missing_accessions_div').hide();
                    var no_missing_accessions_html = '<button class="btn btn-primary" onclick="Workflow.skip(this);">There were no errors regarding missing accessions Click Here</button><br/><br/>';
                    jQuery('#upload_trial_no_error_messages_html').html(no_missing_accessions_html);
                    Workflow.skip('#upload_trial_missing_accessions_div', false);
                }

                if (response.missing_seedlots) {
                    jQuery('#upload_trial_missing_seedlots_div').show();
                } else {
                    jQuery('#upload_trial_missing_seedlots_div').hide();
                    var no_missing_seedlot_html = '<button class="btn btn-primary" onclick="Workflow.skip(this);">There were no errors regarding missing seedlots Click Here</button><br/><br/>';
                    jQuery('#upload_trial_no_error_messages_seedlot_html').html(no_missing_seedlot_html);
                    Workflow.skip('#upload_trial_missing_seedlots_div', false);
                }

                $("#upload_trial_error_display tbody").html(response.error_string);
                //$("#upload_trial_error_display_seedlot tbody").html(response.error_string);
                $("#upload_trial_error_display_second_try").show();
                $("#upload_trial_error_display_second_try tbody").html(response.error_string);
            }
            if (response.missing_accessions){
                Workflow.focus("#trial_upload_workflow", 4);
            } else if(response.missing_seedlots){
                Workflow.focus("#trial_upload_workflow", 5);
            } else if(response.error_string){
                Workflow.focus("#trial_upload_workflow", 6);
                $("#upload_trial_error_display_second_try").show();
            }
            if (response.warnings) {
                alert(response.warnings);
            }
            if (response.success) {
                refreshTrailJsTree(0);
                jQuery("#upload_trial_error_display_second_try").hide();
                jQuery('#trial_upload_show_repeat_upload_button').hide();
                jQuery('[name="upload_trial_completed_message"]').html('<button class="btn btn-primary" name="upload_trial_success_complete_button">The trial was saved to the database with no errors! Congrats Click Here</button><br/><br/>');
                Workflow.skip('#upload_trial_missing_accessions_div', false);
                Workflow.skip('#upload_trial_missing_seedlots_div', false);
                Workflow.skip('#upload_trial_error_display_second_try', false);
                Workflow.focus("#trial_upload_workflow", -1); //Go to success page
                Workflow.check_complete("#trial_upload_workflow");
                add_plants_per_plot();
            }
        }
    });

    $('#upload_multiple_trial_designs_form').iframePostForm({
        json: true,
        post: function () {
            var uploadedTrialLayoutFile = $("#multiple_trial_designs_upload_file").val();
            $('#working_modal').modal("show");
            if (uploadedTrialLayoutFile === '') {
                $('#working_modal').modal("hide");
                alert("No file selected");
                return;
            }
        },
        complete: function(response) {
            console.log(response);
            $('#working_modal').modal("hide");

            if (response.warnings) {
                warnings = response.warnings;
                warning_html = "<li>"+warnings.join("</li><li>")+"</li>"
                $("#upload_multiple_trials_warning_messages").show();
                $("#upload_multiple_trials_warning_messages").html('<b>Warnings. Fix or ignore the following warnings and try again.</b><br><br>'+warning_html);
                return;
            }
            if (response.errors) {
                errors = response.errors;
                if (Array.isArray(errors)) {
                    error_html = "<li>"+errors.join("</li><li>")+"</li>";
                } else {
                    error_html = "<li>"+errors+"</li>";
                }
                $("#upload_multiple_trials_error_messages").show();
                $("#upload_multiple_trials_error_messages").html('<b>Errors found. Fix the following problems and try again.</b><br><br>'+error_html);
                return;
            }
            if (response.success) {
                console.log("Success!!");
                refreshTrailJsTree(0);
                $("#upload_multiple_trials_success_messages").show();
                $("#upload_multiple_trials_success_messages").html("Success! All trials successfully loaded.");
                $("#multiple_trial_designs_upload_submit").hide();
                $("#upload_multiple_trials_success_button").show();
                return;
            }
        },
        error: function(response) {
            jQuery("#working_modal").modal("hide");
            $("#upload_multiple_trials_error_messages").html("An error occurred while trying to upload this file. Please check the formatting and try again");
            return;
        }
    });

    jQuery('#upload_multiple_trials_success_button').on('click', function(){
        //alert('Trial was saved in the database');
        jQuery('#upload_trial_dialog').modal('hide');
        location.reload();
    });

    jQuery(document).on('click', 'button[name="upload_trial_success_complete_button"]', function(){
        //alert('Trial was saved in the database');
        jQuery('#upload_trial_dialog').modal('hide');
        location.reload();
    });

});
