/*jslint browser: true, devel: true */

/**

=head1 Crosses.js

Dialogs for adding and uploading crosses

=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>
Titima Tantikanjana <tt15@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();

jQuery(document).ready(function($) {

    $("[name='create_crossingtrial_link']").click(function() {
        var lo = new CXGN.List();
        get_select_box('years', 'crosses_add_project_year', {'id':'crosses_add_project_year_select', 'name':'crosses_add_project_year_select', 'auto_generate':1});
        $("#create_crossingtrial_dialog").modal("show");
    });

    $('#create_crossingtrial_submit').click(function() {
        var crossingtrial_name = $("#crossingtrial_name").val();
        if (!crossingtrial_name) {
            alert("Crossing Experiment name is required");
            return;
        }

        var selectedProgram = $("#crossingtrial_program").val();
        if (!selectedProgram) {
            alert("Breeding program is required");
            return;
        }

        var crossingtrial_location = $("#crossingtrial_location").val();
        if (!crossingtrial_location) {
            alert ("Location is required");
            return;
        }

        var year = $("#crosses_add_project_year_select").val();
        if (!year) {
            alert ("Year is required");
            return;
        }

        var project_description = $('textarea#crosses_add_project_description').val();
        if (!project_description) {
            alert ("Description is required");
            return;
        }

        add_crossingtrial(crossingtrial_name, selectedProgram, crossingtrial_location, year, project_description);

    });

    $("[name='create_cross_link']").click(function() {
        $("#cross_type_info").click(function() {
            $("#cross_type_dialog").modal("show");
        });

        var lo = new CXGN.List();
        $('#polycross_accession_list').html(lo.listSelect('polycross_accessions', ['accessions'], 'select', undefined, undefined));
        $('#reciprocal_accession_list').html(lo.listSelect('reciprocal_accessions', ['accessions'], 'select', undefined, undefined));
        $('#maternal_accession_list').html(lo.listSelect('maternal_accessions', ['accessions'], 'select', undefined, undefined));
        $('#paternal_accession_list').html(lo.listSelect('paternal_accessions', ['accessions'], 'select', undefined, undefined));

        get_select_box('breeding_programs', 'add_cross_breeding_program_select_div', {'name' : 'add_cross_breeding_program_id', 'id' : 'add_cross_breeding_program_id', 'empty': 1  });
        jQuery("#add_cross_breeding_program_select_div").change(function() {
            var breeding_program_id = jQuery("#add_cross_breeding_program_id").val();
            get_select_box('projects', 'add_cross_crossing_experiment_select_div', { 'name' : 'add_cross_crossing_experiment_id', 'id' : 'add_cross_crossing_experiment_id', 'breeding_program_id' : breeding_program_id, 'get_crossing_trials': '1', 'empty':1});
        });

        $("#create_cross").modal("show");

        $("#cross_type").change(function() { // show cross_type specific inputs depending on cross type selected
            $("#get_maternal_parent").toggle(($("#cross_type").val() == "biparental") || ($("#cross_type").val() == "backcross") || ($("#cross_type").val() == "sib"));
            $("#get_paternal_parent").toggle(($("#cross_type").val() == "biparental") || ($("#cross_type").val() == "backcross") || ($("#cross_type").val() == "sib"));
            $("#exact_parents").toggle(($("#cross_type").val() == "biparental") || ($("#cross_type").val() == "backcross") || ($("#cross_type").val() == "sib"));
            $("#exact_female").toggle($("#cross_type").val() == "open");
            $("#get_selfed_parent").toggle($("#cross_type").val() == "self");
            $("#get_open_maternal_parent").toggle($("#cross_type").val() == "open");
            $("#get_open_paternal_population").toggle($("#cross_type").val() == "open");
            $("#get_bulk_maternal_population").toggle($("#cross_type").val() == "bulk");
            $("#get_bulk_paternal_parent").toggle($("#cross_type").val() == "bulk");
            $("#get_bulk_selfed_population").toggle($("#cross_type").val() == "bulk_self");
            $("#get_bulk_open_maternal_population").toggle($("#cross_type").val() == "bulk_open");
            $("#get_bulk_open_paternal_population").toggle($("#cross_type").val() == "bulk_open");
            $("#get_doubled_haploid_parent").toggle($("#cross_type").val() == "doubled_haploid");
            $("#get_dihaploid_induction_parent").toggle($("#cross_type").val() == "dihaploid_induction");
            $("#polycross_accessions").toggle($("#cross_type").val() == "polycross");
            $("#reciprocal_accessions").toggle($("#cross_type").val() == "reciprocal");
            $("#maternal_accessions").toggle($("#cross_type").val() == "multicross");
            $("#paternal_accessions").toggle($("#cross_type").val() == "multicross");
        });

        $('input[id*="_parent"]').autocomplete({
            source: '/ajax/stock/accession_or_cross_autocomplete'
        });

        $('input[id*="_population"]').autocomplete({
            source: '/ajax/stock/stock_autocomplete'
        });

//        $("#pollination_date_checkbox").change(function() {
//            $("#get_pollination_date").toggle(this.checked); // show if it is checked, otherwise hide
//        });

//        $("#flower_number_checkbox").change(function() {
//            $("#get_flower_number").toggle(this.checked); // show if it is checked, otherwise hide
//        });

//        $("#fruit_number_checkbox").change(function() {
//            $("#get_fruit_number").toggle(this.checked); // show if it is checked, otherwise hide
//        });

        $("#use_folders_checkbox").change(function() {
            $("#folder_section").toggle(this.checked); // show if it is checked, otherwise hide
        });

//        $("#seed_number_checkbox").change(function() {
//            $("#get_seed_number").toggle(this.checked); // show if it is checked, otherwise hide
//        });

        $("#create_progeny_checkbox").change(function() {
            $("#create_progeny_number").toggle(this.checked); // show if it is checked, otherwise hide
            $("#use_prefix_suffix").toggle(this.checked); // show if it is checked, otherwise hide
            $("#get_prefix_suffix").toggle(this.checked); // show if it is checked, otherwise hide
        });

        $("#use_prefix_suffix_checkbox").change(function() {
            $("#get_prefix_suffix").toggle(this.checked); // show if it is checked, otherwise hide
        });

        //    $("#data_access_checkbox").change(function() {
        //        $("#show_visible_to_role_selection").toggle(this.checked); // show if it is checked, otherwise hide
        //    });

    });

    $('#create_cross_submit').click(function() {

        var crossType = $("#cross_type").val();
        if (!crossType) {
            alert("No type was selected, please select a type before saving a cross/crosses");
            return;
        }

        var crossName = $("#cross_name").val();
        crossName = crossName.trim();
        if (!crossName) {
            alert("A cross unique id is required");
            return;
        }

        var crossing_trial_id = $("#add_cross_crossing_experiment_id").val();
        if (!crossing_trial_id) {
            alert("A crossing experiment is required");
            return;
        }

        var visibleToRole = $("#visible_to_role").val();
        let female_plot_plant;
        if (crossType == 'open') {
            female_plot_plant = jQuery("#open_female_plot_plant").val();
        } else {
            female_plot_plant = jQuery("#female_plot_plant").val();
        }
        const male_plot_plant = $("#male_plot_plant").val();
        const cross_combination = $("#dialog_cross_combination").val();

        add_cross(crossType, crossName, crossing_trial_id, visibleToRole, female_plot_plant, male_plot_plant, cross_combination);

    });

    $("[name='upload_crosses_link']").click(function() {

        get_select_box('breeding_programs', 'upload_crosses_breeding_program_select_div', { 'name' : 'upload_crosses_breeding_program_id', 'id' : 'upload_crosses_breeding_program_id', 'empty': 1 });

        $("#upload_crosses_dialog").modal("show");

        jQuery('#manage_page_section_1').modal("show");
        jQuery('#crossing_experiment_page_section_1').modal("hide");

        jQuery('#manage_page_section_2').modal("show");
        jQuery('#crossing_experiment_page_section_2').modal("hide");

    });

    jQuery("#upload_crosses_breeding_program_select_div").change(function() {
        var breeding_program_id = jQuery("#upload_crosses_breeding_program_id").val();
        jQuery('#manage_page_crossing_experiment').modal("show");
        get_select_box('projects', 'upload_crosses_crossing_experiment_select_div', { 'name' : 'upload_crosses_crossing_experiment_id', 'id' : 'upload_crosses_crossing_experiment_id', 'breeding_program_id' : breeding_program_id, 'get_crossing_trials': '1', 'empty':1});
    });

    jQuery("#upload_crosses_spreadsheet_format_info").click(function() {
        jQuery("#cross_spreadsheet_info_dialog").modal("show");
    });

    $("#upload_crosses_submit").click(function() {
        upload_crosses_file();
    });

    $('#upload_crosses_form').iframePostForm({
        json: true,
        post: function() {
            var uploadFile = $("#crosses_upload_file").val();
            if (uploadFile === '') {
                alert("No file selected");
            }
            jQuery("#working_modal").modal("show");
        },
        complete: function(response) {
            jQuery("#working_modal").modal("hide");
            if (response.error_string) {
                $("#upload_cross_error_display tbody").html('');
                $("#upload_cross_error_display tbody").append(response.error_string);
                $("#upload_cross_error_display").modal("show");

                return;
            }
            if (response.error) {
                alert(response.error);
                return;
            }
            if (response.success) {
                Workflow.focus("#crosses_upload_workflow", -1); //Go to success page
                Workflow.check_complete("#crosses_upload_workflow");
            }
        }
    });

    jQuery(document).on('click', '[name="upload_crosses_success_complete_button"]', function(){
        jQuery('#upload_crosses_dialog').modal('hide');
        location.reload();
    });

    jQuery(document).on('click', '[name="upload_crosses_dismiss_button"]', function(){
        jQuery('#upload_crosses_dialog').modal('hide');
        jQuery(".modal-backdrop").remove();
    });


    function add_cross(crossType, crossName, crossing_trial_id, visibleToRole, female_plot_plant, male_plot_plant, cross_combination) {

        var progenyNumber = $("#progeny_number").val();
        var prefix = $("#prefix").val();
        var suffix = $("#suffix").val();
        var maternal;
        var paternal;
        var maternal_parents;
        var paternal_parents;
        var maternal_parents_string;
        var paternal_parents_string;

        switch (crossType) {
            case 'biparental':
                maternal = $("#maternal_parent").val();
                paternal = $("#paternal_parent").val();
                break;
            case 'self':
                var selfedParent = $("#selfed_parent").val();
                maternal = selfedParent;
                paternal = selfedParent;
                break;
            case 'open':
                maternal = $("#open_maternal_parent").val();
                paternal = $("#open_paternal_population").val();
                break;
            case 'sib':
                maternal = $("#maternal_parent").val();
                paternal = $("#paternal_parent").val();
                break;
            case 'bulk':
                maternal = $("#bulk_maternal_population").val();
                paternal = $("#bulk_paternal_parent").val();
                break;
            case 'bulk_self':
                var bulkedSelfedPopulation = $("#bulk_selfed_population").val();
                maternal = bulkedSelfedPopulation;
                paternal = bulkedSelfedPopulation;
                break;
            case 'bulk_open':
                maternal = $("#bulk_open_maternal_population").val();
                paternal = $("#bulk_open_paternal_population").val();
                break;
            case 'doubled_haploid':
                var doubledHaploidParent = $("#doubled_haploid_parent").val();
                maternal = doubledHaploidParent;
                paternal = doubledHaploidParent;
                break;
            case 'dihaploid_induction':
                var dihaploidInductionParent = $("#dihaploid_induction_parent").val();
                maternal = dihaploidInductionParent;
                paternal = dihaploidInductionParent;
                break;

            case 'polycross':
                maternal_parents = get_accession_names('polycross_accessions_list_select');
                if (!Array.isArray(maternal_parents)) { alert(maternal_parents); return; }
                break;
            case 'reciprocal':
                maternal_parents = get_accession_names('reciprocal_accessions_list_select');
                if (!Array.isArray(maternal_parents)) { alert(maternal_parents); return; }
                break;
            case 'multicross':
                maternal_parents = get_accession_names('maternal_accessions_list_select');
                if (!Array.isArray(maternal_parents)) { alert(maternal_parents); return; }
                paternal_parents = get_accession_names('paternal_accessions_list_select');
                if (!Array.isArray(paternal_parents)) { alert(paternal_parents); return; }
                break;
            case 'backcross':
                maternal = $("#maternal_parent").val();
                paternal = $("#paternal_parent").val();
                break;
        }

        if (maternal_parents) {
            maternal_parents_string = maternal_parents.toString();
        }

        if (paternal_parents) {
            paternal_parents_string = paternal_parents.toString();
        }

        $.ajax({
            url: '/ajax/cross/add_cross',
            timeout: 3000000,
            dataType: "json",
            type: 'POST',
            data:{
                'cross_name': crossName,
                'cross_type': crossType,
                'maternal': maternal,
                'paternal': paternal,
                'maternal_parents': maternal_parents_string,
                'paternal_parents': paternal_parents_string,
                'progeny_number': progenyNumber,
                'prefix': prefix,
                'suffix': suffix,
                'visible_to_role': visibleToRole,
                'crossing_trial_id': crossing_trial_id,
                'female_plot_plant': female_plot_plant,
                'male_plot_plant': male_plot_plant,
                'cross_combination': cross_combination,
            },
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            error: function(response) {
                alert("An error occurred. Please try again later!" + JSON.stringify(response));
            },
            parseerror: function(response) {
                alert("A parse error occurred. Please try again." + response);
            },
            success: function(response) {
                jQuery("#working_modal").modal("hide");
                if (response.error) {
                    alert(response.error);
                } else {
                    Workflow.focus("#add_cross_workflow", -1); //Go to success page
                    Workflow.check_complete("#add_cross_workflow");
                }
            },
        });

    }

    function upload_crosses_file() {
        const breeding_program = jQuery("#upload_crosses_breeding_program_id").val();
        if (!breeding_program) {
            alert("Please select your breeding program");
            return;
        }

        const crossing_trial_id = jQuery("#upload_crosses_crossing_experiment_id").val();
        const experiment_id = jQuery("#experiment_id").val();
        if (!crossing_trial_id && !experiment_id) {
            alert("A crossing experiment is required");
            return;
        }

        const uploadFile = jQuery("#upload_crosses_file").val();
        if (!uploadFile) {
            alert("Please select a file");
            return;
        }

        jQuery('#upload_crosses_form').attr("action", "/ajax/cross/upload_crosses_file");

        jQuery("#upload_crosses_form").submit();
    }

    function get_accession_names(accession_select_id) {

        var accession_list_id = $('#' + accession_select_id).val();
        var lo = new CXGN.List();
        var accession_validation = 1;
        if (accession_list_id) {
            accession_validation = lo.legacy_validate(accession_list_id, 'accessions', true);
        }

        if (!accession_list_id) {
            //alert("You need to select an accession list!");
            return "You need to select an accession list!";
        }

        if (accession_validation != 1) {
            //alert("The accession list did not pass validation. Please correct the list and try again");
            return "The accession list did not pass validation. Please correct the list and try again";
        }

        var list_data = lo.getListData(accession_list_id);
        var accessions = list_data.elements;
        var names = [];

        if (accessions.length == 0) {
            return "The selected list is empty";
        } else {
            for (i = 0; i < accessions.length; i++) {
                names.push(accessions[i][1]);
            }
        }
        return names;
    }

    function add_crossingtrial(crossingtrial_name, selectedProgram, crossingtrial_location, year, project_description, crossingtrial_folder_name, crossingtrial_folder_id) {
        $.ajax({
            url: '/ajax/cross/add_crossingtrial',
            timeout: 3000000,
            dataType: "json",
            type: 'POST',
            data:{
                'crossingtrial_name': crossingtrial_name,
                'crossingtrial_program_id': selectedProgram,
                'crossingtrial_location': crossingtrial_location,
                'year': year,
                'project_description': project_description,
            },
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            error: function(response) {
                alert("An error occurred!" + JSON.stringify(response));
                return;
            },
            parseerror: function(response) {
                alert("A parse error occurred!" + response);
                return;
            },
            success: function(response) {
                if (response.error) {
                    jQuery("#working_modal").modal("hide");
                    alert(response.error);

                } else {
                    refreshCrossJsTree(0);
                    Workflow.focus("#add_crossing_trial_workflow", -1); //Go to success page
                    Workflow.check_complete("#add_crossing_trial_workflow");
                    jQuery("#working_modal").modal("hide");
                }
            },
        });

  }

});
