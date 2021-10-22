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
    var trial_id;
    var stock_list_id;
    var stock_list;
    var check_stock_list_id;
    var check_stock_list;
    var crbd_check_stock_list_id;
    var crbd_check_stock_list;
    var unrep_stock_list_id;
    var unrep_stock_list;
    var rep_stock_list_id;
    var rep_stock_list;
    var seedlot_list_id;
    var seedlot_list;
    var accession_list_seedlot_hash = {};
    var checks_list_seedlot_hash = {};
    var crbd_checks_list_seedlot_hash = {};
    var unrep_list_seedlot_hash = {};
    var rep_list_seedlot_hash = {};
    var plants_per_plot;
    var inherits_plot_treatments;

    jQuery('#create_trial_validate_form_button').click(function(){
        create_trial_validate_form();
    });

    function create_trial_validate_form(){
        var trial_name = $("#new_trial_name").val();
        var breeding_program = $("#select_breeding_program").val();
        var location = $("#add_project_location").val().toString().trim(); // remove whitespace
        var trial_year = $("#add_project_year").val();
        var description = $("#add_project_description").val();
        var design_type = $("#select_design_method").val();
        var stock_type = $("#select_stock_type").val();
        var plot_width = $("#add_project_plot_width").val();
        var plot_length = $("#add_project_plot_length").val();
        plants_per_plot = $("#add_plant_entries").val();
        inherits_plot_treatments = $("trial_create_plants_per_plot_inherit_treatments").val();

        if (trial_name === '') {
            alert("Please supply a trial name");
        }
        else if (breeding_program === '') {
            alert("Please select a breeding program");
        }
        else if (location === '') {
            alert("Please select at least one location");
        }
        else if (trial_year === '') {
            alert("Please select a trial year");
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
            alert("Please supply a description!");
        }
        else if (design_type === '') {
            alert("Please select a design type");
        }
        else if (stock_type === '') {
            alert("Please select a stock type");
        }
        else {
            verify_create_trial_name(trial_name);
        }
    }

    function verify_create_trial_name(trial_name){
        jQuery.ajax( {
            url: '/ajax/trial/verify_trial_name?trial_name='+trial_name,
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                jQuery("#working_modal").modal("hide");
                if (response.error){
                    alert(response.error);
                    jQuery('[name="create_trial_submit"]').attr('disabled', true);
                }
                else {
                    jQuery('[name="create_trial_submit"]').attr('disabled', false);
                }
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred checking trial name');
            }
        });
    }

    $(document).on('focusout', '#select_list_list_select', function() {
        if ($('#select_list_list_select').val()) {
            stock_list_id = $('#select_list_list_select').val();
            stock_list = JSON.stringify(list.getList(stock_list_id));
            verify_stock_list(stock_list);
            if(stock_list && seedlot_list){
                verify_seedlot_list(stock_list, seedlot_list, 'stock_list');
            } else {
                accession_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#select_cross_list_list_select', function() {
        if ($('#select_cross_list_list_select').val()) {
            cross_list_id = $('#select_cross_list_list_select').val();
            cross_list = JSON.stringify(list.getList(cross_list_id));
            verify_cross_list(cross_list);
        }
    });

    $(document).on('focusout', '#select_family_name_list_list_select', function() {
        if ($('#select_family_name_list_list_select').val()) {
            family_name_list_id = $('#select_family_name_list_list_select').val();
            family_name_list = JSON.stringify(list.getList(family_name_list_id));
            verify_family_name_list(family_name_list);
        }
    });

    $(document).on('focusout', '#list_of_checks_section_list_select', function() {
        if ($('#list_of_checks_section_list_select').val()) {
            check_stock_list_id = $('#list_of_checks_section_list_select').val();
            check_stock_list = JSON.stringify(list.getList(check_stock_list_id));
            verify_stock_list(check_stock_list);
            if(check_stock_list && seedlot_list){
                verify_seedlot_list(check_stock_list, seedlot_list, 'check_stock_list');
            } else {
                checks_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#list_of_cross_checks_section_list_select', function() {
        if ($('#list_of_cross_checks_section_list_select').val()) {
            check_cross_list_id = $('#list_of_cross_checks_section_list_select').val();
            check_cross_list = JSON.stringify(list.getList(check_cross_list_id));
            verify_cross_list(check_cross_list);
        }
    });

    $(document).on('focusout', '#list_of_family_name_checks_section_list_select', function() {
        if ($('#list_of_family_name_checks_section_list_select').val()) {
            check_family_name_list_id = $('#list_of_family_name_checks_section_list_select').val();
            check_family_name_list = JSON.stringify(list.getList(check_family_name_list_id));
            verify_family_name_list(check_family_name_list);
        }
    });

    $(document).on('focusout', '#crbd_list_of_checks_section_list_select', function() {
        if ($('#crbd_list_of_checks_section_list_select').val()) {
            crbd_check_stock_list_id = $('#crbd_list_of_checks_section_list_select').val();
            crbd_check_stock_list = JSON.stringify(list.getList(crbd_check_stock_list_id));
            verify_stock_list(crbd_check_stock_list);
            if(crbd_check_stock_list && seedlot_list){
                verify_seedlot_list(crbd_check_stock_list, seedlot_list, 'crbd_check_stock_list');
            } else {
                crbd_checks_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#crbd_list_of_cross_checks_section_list_select', function() {
        if ($('#crbd_list_of_cross_checks_section_list_select').val()) {
            crbd_check_cross_list_id = $('#crbd_list_of_cross_checks_section_list_select').val();
            crbd_check_cross_list = JSON.stringify(list.getList(crbd_check_cross_list_id));
            verify_cross_list(crbd_check_cross_list);
        }
    });

    $(document).on('focusout', '#crbd_list_of_family_name_checks_section_list_select', function() {
        if ($('#crbd_list_of_family_name_checks_section_list_select').val()) {
            crbd_check_family_name_list_id = $('#crbd_list_of_family_name_checks_section_list_select').val();
            crbd_check_family_name_list = JSON.stringify(list.getList(crbd_check_family_name_list_id));
            verify_family_name_list(crbd_check_family_name_list);
        }
    });

    $(document).on('focusout', '#list_of_unrep_accession_list_select', function() {
        if ($('#list_of_unrep_accession_list_select').val()) {
            unrep_stock_list_id = $('#list_of_unrep_accession_list_select').val();
            unrep_stock_list = JSON.stringify(list.getList(unrep_stock_list_id));
            verify_stock_list(unrep_stock_list);
            if(unrep_stock_list && seedlot_list){
                verify_seedlot_list(unrep_stock_list, seedlot_list, 'unrep_stock_list');
            } else {
                unrep_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#list_of_unrep_cross_list_select', function() {
        if ($('#list_of_unrep_cross_list_select').val()) {
            unrep_cross_list_id = $('#list_of_unrep_cross_list_select').val();
            unrep_cross_list = JSON.stringify(list.getList(unrep_cross_list_id));
            verify_cross_list(unrep_cross_list);
        }
    });

    $(document).on('focusout', '#list_of_unrep_family_name_list_select', function() {
        if ($('#list_of_unrep_family_name_list_select').val()) {
            unrep_family_name_list_id = $('#list_of_unrep_family_name_list_select').val();
            unrep_family_name_list = JSON.stringify(list.getList(unrep_family_name_list_id));
            verify_family_name_list(unrep_family_name_list);
        }
    });

    $(document).on('focusout', '#list_of_rep_accession_list_select', function() {
        if ($('#list_of_rep_accession_list_select').val()) {
            rep_stock_list_id = $('#list_of_rep_accession_list_select').val();
            rep_stock_list = JSON.stringify(list.getList(rep_stock_list_id));
            verify_stock_list(rep_stock_list);
            if(rep_stock_list && seedlot_list){
                verify_seedlot_list(rep_stock_list, seedlot_list, 'rep_stock_list');
            } else {
                rep_list_seedlot_hash = {};
            }
        }
    });

    $(document).on('focusout', '#list_of_rep_cross_list_select', function() {
        if ($('#list_of_rep_cross_list_select').val()) {
            rep_cross_list_id = $('#list_of_rep_cross_list_select').val();
            rep_cross_list = JSON.stringify(list.getList(rep_cross_list_id));
            verify_cross_list(rep_cross_list);
        }
    });

    $(document).on('focusout', '#list_of_rep_family_name_list_select', function() {
        if ($('#list_of_rep_family_name_list_select').val()) {
            rep_family_name_list_id = $('#list_of_rep_family_name_list_select').val();
            rep_family_name_list = JSON.stringify(list.getList(rep_family_name_list_id));
            verify_family_name_list(rep_family_name_list);
        }
    });

    $(document).on('focusout', '#select_seedlot_list_list_select', function() {
        if ($('#select_seedlot_list_list_select').val() != '') {
            seedlot_list_id = $('#select_seedlot_list_list_select').val();
            seedlot_list = JSON.stringify(list.getList(seedlot_list_id));
            if(stock_list && seedlot_list){
                verify_seedlot_list(stock_list, seedlot_list, 'stock_list');
            } else {
                alert('Please make sure to select an accession list above!');
            }
            if(check_stock_list && seedlot_list){
                verify_seedlot_list(check_stock_list, seedlot_list, 'check_stock_list');
            }
            if(crbd_check_stock_list && seedlot_list){
                verify_seedlot_list(crbd_check_stock_list, seedlot_list, 'crbd_check_stock_list');
            }
            if(unrep_stock_list && seedlot_list){
                verify_seedlot_list(unrep_stock_list, seedlot_list, 'unrep_stock_list');
            }
            if(rep_stock_list && seedlot_list){
                verify_seedlot_list(rep_stock_list, seedlot_list, 'rep_stock_list');
            }
        } else {
            seedlot_list = undefined;
            seedlot_list_verified = 1;
            if (stock_list){
                verify_stock_list(stock_list);
            }
            accession_list_seedlot_hash = {};
            checks_list_seedlot_hash = {};
            crbd_checks_list_seedlot_hash = {};
            unrep_list_seedlot_hash = {};
            rep_list_seedlot_hash = {};
        }
    });

    $(document).on('click', 'button[name="convert_accessions_to_seedlots"]', function(){
        if (!stock_list_id){
            alert('Please first select a list of accessions above!');
        } else {
            var list = new CXGN.List();
            list.seedlotSearch(stock_list_id);
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

    var seedlot_list_verified = 1;
    function verify_seedlot_list(stock_list, seedlot_list, type) {
        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/verify_seedlot_list',
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            dataType: "json",
            data: {
                'stock_list': stock_list,
                'seedlot_list': seedlot_list,
            },
            success: function (response) {
                //console.log(response);
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(response.error);
                    seedlot_list_verified = 0;
                }
                if (response.success){
                    seedlot_list_verified = 1;
                    if (type == 'stock_list'){
                        accession_list_seedlot_hash = response.seedlot_hash;
                    }
                    if (type = 'check_stock_list'){
                        checks_list_seedlot_hash = response.seedlot_hash;
                    }
                    if (type == 'crbd_check_stock_list'){
                        crbd_checks_list_seedlot_hash = response.seedlot_hash;
                    }
                    if (type == 'unrep_stock_list'){
                        unrep_list_seedlot_hash = response.seedlot_hash;
                    }
                    if (type == 'rep_stock_list'){
                        rep_list_seedlot_hash = response.seedlot_hash;
                    }
                }
            },
            error: function () {
                jQuery('#working_modal').modal('hide');
                alert('An error occurred. sorry');
                seedlot_list_verified = 0;
            }
        });
    }

    var cross_list_verified = 0;
    function verify_cross_list(cross_list) {
        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/verify_cross_list',
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            dataType: "json",
            data: {
                'cross_list': cross_list,
            },
            success: function (response) {
                //console.log(response);
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(response.error);
                    cross_list_verified = 0;
                }
                if (response.success){
                    cross_list_verified = 1;
                }
            },
            error: function () {
                jQuery('#working_modal').modal('hide');
                alert('An error occurred. sorry');
                cross_list_verified = 0;
            }
        });
    }

    var family_name_list_verified = 0;
    function verify_family_name_list(family_name_list) {
        $.ajax({
            type: 'POST',
            timeout: 3000000,
            url: '/ajax/trial/verify_family_name_list',
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            dataType: "json",
            data: {
                'family_name_list': family_name_list,
            },
            success: function (response) {
                //console.log(response);
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert(response.error);
                    family_name_list_verified = 0;
                }
                if (response.success){
                    family_name_list_verified = 1;
                }
            },
            error: function () {
                jQuery('#working_modal').modal('hide');
                alert('An error occurred. sorry');
                family_name_list_verified = 0;
            }
        });
    }

    jQuery('#add_project_trial_sourced').change(function(){
        if(jQuery(this).val() == 'yes'){
            jQuery('#add_trial_source_trial_section').show();
        } else {
            jQuery('#add_trial_source_trial_section').hide();
        }
    });

    jQuery(document).on('click', '#create_trial_with_treatment_additional_treatment_buton', function(){
        var count = jQuery('#create_trial_with_treatment_additional_count').val();
        var new_count = parseInt(count) + 1;
        var return_count = new_count + 4;
        var html = '';
        for (var i=0; i<new_count; i++){
            var display_count = i + 5;
            html = html + '<div class="form-group form-group-sm" ><label class="col-sm-7 control-label">Subplot '+display_count+ 'Treatment Name: </label><div class="col-sm-5" ><input class="form-control" id="create_trial_with_treatment_name_input'+display_count+'" name="create_trial_with_treatment_name_input'+display_count+'" type="text" placeholder="Optional Treatment '+display_count+'"/></div></div>';
        }
        html = html + '<input type="hidden" id="create_trial_with_treatment_additional_count" value='+return_count+'><div class="form-group form-group-sm" ><label class="col-sm-7 control-label">Add Another Treatment: </label><div class="col-sm-5" ><button class="btn btn-info btn-sm" id="create_trial_with_treatment_additional_treatment_buton">+ Treatment</button></div></div>';
        jQuery('#create_trial_with_treatment_additional_treatment').html(html);
        return false;
    });

    var num_plants_per_plot = 0;
    var num_subplots_per_plot = 0;
    function generate_experimental_design() {
        var name = $('#new_trial_name').val();
        var year = $('#add_project_year').val();
        var desc = $('#add_project_description').val();
        var locations = jQuery('#add_project_location').val();
        var trial_location =  JSON.stringify(locations);
        //console.log("Trial location is "+trial_location);
        var trial_stock_type = jQuery('#select_stock_type').val();
        var block_number = $('#block_number').val();
        //alert(block_number);
        var row_number= $('#row_number').val();
        var row_number_per_block=$('#row_number_per_block').val();
        var col_number_per_block=$('#col_number_per_block').val();
        var col_number=$('#col_number').val();
       // alert(row_number);

        var accession_list_id = '';
        var control_accession_list_id = '';
        var control_accession_list_id_crbd = '';
        var cross_list_id = '';
        var control_cross_list_id = '';
        var control_cross_list_id_crbd = '';
        var family_name_list_id = '';
        var control_family_name_list_id = '';
        var control_family_name_list_id_crbd = '';
        var replicated_accession_list_id = '';
        var unreplicated_accession_list_id = '';
        var replicated_cross_list_id = '';
        var unreplicated_cross_list_id = '';
        var replicated_family_name_list_id = '';
        var unreplicated_family_name_list_id = '';

        if (trial_stock_type == "accession"){
            accession_list_id = $('#select_list_list_select').val();
            control_accession_list_id = $('#list_of_checks_section_list_select').val();
            control_accession_list_id_crbd = $('#crbd_list_of_checks_section_list_select').val();
            replicated_accession_list_id = $('#list_of_rep_accession_list_select').val();
            unreplicated_accession_list_id = $('#list_of_unrep_accession_list_select').val();
        } else if (trial_stock_type == "cross") {
            cross_list_id = $('#select_cross_list_list_select').val();
            control_cross_list_id = $('#list_of_cross_checks_section_list_select').val();
            control_cross_list_id_crbd = $('#crbd_list_of_cross_checks_section_list_select').val();
            replicated_cross_list_id = $('#list_of_rep_cross_list_select').val();
            unreplicated_cross_list_id = $('#list_of_unrep_cross_list_select').val();
        } else if (trial_stock_type == "family_name") {
            family_name_list_id = $('#select_family_name_list_list_select').val();
            control_family_name_list_id = $('#list_of_family_name_checks_section_list_select').val();
            control_family_name_list_id_crbd = $('#crbd_list_of_family_name_checks_section_list_select').val();
            replicated_family_name_list_id = $('#list_of_rep_family_name_list_select').val();
            unreplicated_family_name_list_id = $('#list_of_unrep_family_name_list_select').val();
        }

        var stock_list;
        var stock_list_array;

        if (accession_list_id != "") {
            stock_list_array = list.getList(accession_list_id);
            stock_list = JSON.stringify(stock_list_array);
        } else if (cross_list_id != "") {
            stock_list_array = list.getList(cross_list_id);
            stock_list = JSON.stringify(stock_list_array);
        } else if (family_name_list_id != "") {
            stock_list_array = list.getList(family_name_list_id);
            stock_list = JSON.stringify(stock_list_array);
        }

        var control_list;
        var control_list_array;
        if (control_accession_list_id != '') {
            control_list_array = list.getList(control_accession_list_id);
            control_list = JSON.stringify(control_list_array);
        } else if (control_cross_list_id != '') {
            control_list_array = list.getList(control_cross_list_id);
            control_list = JSON.stringify(control_list_array);
        } else if (control_family_name_list_id != '') {
            control_list_array = list.getList(control_family_name_list_id);
            control_list = JSON.stringify(control_list_array);
        }

        var control_list_crbd;
        var control_list_crbd_array;
        if (control_accession_list_id_crbd != '') {
            control_list_crbd_array = list.getList(control_accession_list_id_crbd);
            control_list_crbd = JSON.stringify(control_list_crbd_array);
        } else if (control_cross_list_id_crbd != '') {
            control_list_crbd_array = list.getList(control_cross_list_id_crbd);
            control_list_crbd = JSON.stringify(control_list_crbd_array);
        } else if (control_family_name_list_id_crbd != '') {
            control_list_crbd_array = list.getList(control_family_name_list_id_crbd);
            control_list_crbd = JSON.stringify(control_list_crbd_array);
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
        var row_in_design_number = $('#no_of_row_in_design').val();
        var col_in_design_number = $('#no_of_col_in_design').val();
        var no_of_rep_times = $('#no_of_rep_times').val();
        var no_of_block_sequence = $('#no_of_block_sequence').val();
        var no_of_sub_block_sequence = $('#no_of_sub_block_sequence').val();
        var num_seed_per_plot = $('#num_seed_per_plot').val();
        var westcott_check_1 = $('#westcott_check_1').val();
        var westcott_check_2 = $('#westcott_check_2').val();
        var westcott_col = $('#westcott_col').val();
        var westcott_col_between_check = $('#westcott_col_between_check').val();
        var plot_width = $('#add_project_plot_width').val();
        var plot_length = $('#add_project_plot_length').val();
        var field_size = $('#new_trial_field_size').val();
        var seedlot_hash_combined = {};
        seedlot_hash_combined = extend_obj(accession_list_seedlot_hash, checks_list_seedlot_hash);
        seedlot_hash_combined = extend_obj(seedlot_hash_combined, crbd_checks_list_seedlot_hash);
        seedlot_hash_combined = extend_obj(seedlot_hash_combined, unrep_list_seedlot_hash);
        seedlot_hash_combined = extend_obj(seedlot_hash_combined, rep_list_seedlot_hash);
        if (!jQuery.isEmptyObject(seedlot_hash_combined)){
            if (num_seed_per_plot == ''){
                alert('Number of seeds per plot is required if you have selected a seedlot list!');
                return;
            }
        }

        var unreplicated_stock_list;
        if (unreplicated_accession_list_id != "") {
            unreplicated_stock_list = JSON.stringify(list.getList(unreplicated_accession_list_id));
        } else if (unreplicated_cross_list_id != "") {
            unreplicated_stock_list = JSON.stringify(list.getList(unreplicated_cross_list_id));
        } else if (unreplicated_family_name_list_id != "") {
            unreplicated_stock_list = JSON.stringify(list.getList(unreplicated_family_name_list_id));
        }

        var replicated_stock_list;
        if (replicated_accession_list_id != "") {
            replicated_stock_list = JSON.stringify(list.getList(replicated_accession_list_id));
        } else if (replicated_cross_list_id != "") {
            replicated_stock_list = JSON.stringify(list.getList(replicated_cross_list_id));
        } else if (replicated_family_name_list_id != "") {
            replicated_stock_list = JSON.stringify(list.getList(replicated_family_name_list_id));
        }

        var treatments = []
        if (design_type == 'splitplot'){
            var count = jQuery('#create_trial_with_treatment_additional_count').val();
            if (count == 0) {
                count = 4; //Interface starts with 4 inputs and user can add additional ones..
            }
            var int_count = parseInt(count);
            for(var i=1; i<=int_count; i++){
                var treatment_value = jQuery('#create_trial_with_treatment_name_input'+i).val();
                if(treatment_value != ''){
                    treatments.push(treatment_value);
                }
            }
            var num_plants_per_treatment = $('#num_plants_per_treatment').val();
            num_plants_per_plot = 0;
            if (num_plants_per_treatment){
                num_plants_per_plot = num_plants_per_treatment*treatments.length;
            }
            num_subplots_per_plot = treatments.length;
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

        var use_same_layout;
        if ($('#use_same_layout').is(':checked')) {
           use_same_layout = $('#use_same_layout').val();
        }
        else {
           use_same_layout = "";
        }

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
                'trial_stock_type': trial_stock_type,
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
                'treatments':treatments,
                'num_plants_per_plot':num_plants_per_plot,
                'row_in_design_number': row_in_design_number,
                'col_in_design_number': col_in_design_number,
                'no_of_rep_times': no_of_rep_times,
                'no_of_block_sequence': no_of_block_sequence,
                'unreplicated_stock_list': unreplicated_stock_list,
                'replicated_stock_list': replicated_stock_list,
                'no_of_sub_block_sequence': no_of_sub_block_sequence,
                'seedlot_hash': JSON.stringify(seedlot_hash_combined),
                'num_seed_per_plot': num_seed_per_plot,
                'westcott_check_1': westcott_check_1,
                'westcott_check_2': westcott_check_2,
                'westcott_col': westcott_col,
                'westcott_col_between_check': westcott_col_between_check,
                'field_size': field_size,
                'plot_width': plot_width,
                'plot_length': plot_length,
                'use_same_layout' : use_same_layout
            },
            success: function (response) {
                $('#working_modal').modal("hide");
                if (response.error) {
                    alert(response.error);
                } else {

                    Workflow.focus("#trial_design_workflow", 6); //Go to review page

                    if(response.warning_message){
                        jQuery('#trial_design_warning_message').html("<center><div class='well'><h4 class='text-warning'>Warning: "+response.warning_message+"</h4></div></center>");
                    } else {
                        jQuery('#trial_design_warning_message').html('');
                    }

                    $('#trial_design_information').html(response.design_info_view_html);
                    var layout_view = JSON.parse(response.design_layout_view_html);
                    //console.log(layout_view);
                    var layout_html = '';
                    for (var i=0; i<layout_view.length; i++) {
                        //console.log(layout_view[i]);
                        layout_html += layout_view[i] + '<br>';
                    }
                    $('#trial_design_view_layout_return').html(layout_html);

                    $('#working_modal').modal("hide");
                    design_json = response.design_json;

                    var col_length = response.design_map_view.coord_col[0];
                    var row_length = response.design_map_view.coord_row[0];
                    var block_max = response.design_map_view.max_block;
                    var rep_max = response.design_map_view.max_rep;
                    var col_max =  response.design_map_view.max_col;
                    var row_max =  response.design_map_view.max_row;
                    var controls = response.design_map_view.controls;
                    var false_coord = response.design_map_view.false_coord;

                    var dataset = [];
                    if (design_type == 'splitplot'){
                        row_length = response.design_map_view.coord_row[1];
                        dataset = response.design_map_view.result;
                        dataset.shift();
                    }else {
                        dataset = response.design_map_view.result;
                    }

                    if (col_length && row_length) {
                        jQuery("#container_field_map_view").css({"display": "inline-block", "overflow": "auto"});
                        jQuery("#d3_legend").css("display", "inline-block");

                      var margin = { top: 50, right: 0, bottom: 100, left: 30 },
                          width = 50 * col_max + 30 - margin.left - margin.right,
                          height = 50 * row_max + 100 - margin.top - margin.bottom,
                          gridSize = 50,
                          legendElementWidth = gridSize*2,
                          rows = response.design_map_view.unique_row,
                          columns = response.design_map_view.unique_col;
                          //datasets = response.design_map_view.result;
                          datasets = dataset;

                      var svg = d3.select("#container_field_map_view").append("svg")
                          .attr("width", width + margin.left + margin.right)
                          .attr("height", height + margin.top + margin.bottom)
                          .append("g")
                          .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

                      var rowLabels = svg.selectAll(".rowLabel")
                          .data(rows)
                          .enter().append("text")
                            .text(function (d) { return d; })
                            .attr("x", 0 )
                            .attr("y", function (d, i) { return i * gridSize; })
                            .style("text-anchor", "end")
                            .attr("transform", "translate(-6," + gridSize / 1.5 + ")")
                            .attr("class", function (d, i) { return ((i >= 0 && i <= 4) ? "rowLabel mono axis axis-workweek" : "rowLabel mono axis"); });

                      var columnLabels = svg.selectAll(".columnLabel")
                          .data(columns)
                          .enter().append("text")
                            .text(function(d) { return d; })
                            .attr("x", function(d, i) { return i * gridSize; })
                            .attr("y", 0 )
                            .style("text-anchor", "middle")
                            .attr("transform", "translate(" + gridSize / 2 + ", -6)")
                            .attr("class", function(d, i) { return ((i >= 7 && i <= 16) ? "columnLabel mono axis axis-worktime" : "columnLabel mono axis"); });

                      var heatmapChart = function(datasets) {

                        datasets.forEach(function(d) {

                            d.row = +d.row;
                            d.col = +d.col;
                            d.blkn = +d.blkn;
                        });

                          var cards = svg.selectAll(".col")
                              .data(datasets, function(d) {return d.row+':'+d.col;});

                          cards.append("title");

                          var colors = function (d, i){
                              if (block_max == 1){
                                color = '#41b6c4';
                              }
                              else if (block_max > 1){
                                if (d.blkn % 2 == 0){
                                    color = '#c7e9b4';
                                }
                                else{
                                    color = '#41b6c4'
                                }
                              }
                              else{
                                color = '#c7e9b4';
                              }
                              if (controls) {
                                for (var i = 0; i < controls.length; i++) {
                                  if ( controls[i] == d.stock) {
                                    color = '#081d58';
                                  }
                                }
                              }
                              return color;
                            }

                            var strokes = function (d, i){
                                var stroke;
                                if (rep_max == 1){
                                  stroke = 'green';
                                }
                                else if (rep_max > 1){
                                  if (d.rep % 2 == 0){
                                      stroke = 'red';
                                  }
                                  else{
                                      stroke = 'green'
                                  }
                                }
                                else{
                                  stroke = 'red';
                                }
                                return stroke;
                              }

                          cards.enter().append("rect")
                              .attr("x", function(d) { return (d.col - 1) * gridSize; })
                              .attr("y", function(d) { return (d.row - 1) * gridSize; })
                              .attr("rx", 4)
                              .attr("ry", 4)
                              .attr("class", "col bordered")
                              .attr("width", gridSize)
                              .attr("height", gridSize)
                              .style("stroke-width", 2)
                              .style("stroke", strokes)
                              .style("fill", colors)
                              .on("mouseover", function(d) { d3.select(this).style('fill', 'green'); })
                              .on("mouseout", function(d) {
                                                              var cards = svg.selectAll(".col")
                                                                  .data(datasets, function(d) {return d.row+':'+d.col;});

                                                              cards.append("title");

                                                              cards.enter().append("rect")
                                                                .attr("x", function(d) { return (d.col - 1) * gridSize; })
                                                                .attr("y", function(d) { return (d.row - 1) * gridSize; })
                                                                .attr("rx", 4)
                                                                .attr("ry", 4)
                                                                .attr("class", "col bordered")
                                                                .attr("width", gridSize)
                                                                .attr("height", gridSize)
                                                                .style("stroke-width", 2)
                                                                .style("stroke", strokes)
                                                                .style("fill", colors);

                                                                cards.style("fill", colors) ;

                                                                cards.select("title").text(function(d) { return d.plot_msg; }) ;

                                                                cards.exit().remove();
                                                                //console.log('out');
                                                            });


                          cards.style("fill", colors) ;

                          cards.select("title").text(function(d) { return d.plot_msg; }) ;

                          cards.append("text");
                          cards.enter().append("text")
                            .attr("x", function(d) { return (d.col - 1) * gridSize + 10; })
                            .attr("y", function(d) { return (d.row - 1) * gridSize + 20 ; })
                            .text(function(d) { return d.plotn; });

                          cards.select("text").text(function(d) { return d.plotn; }) ;

                          cards.exit().remove();

                        // });
                        } ;

                      heatmapChart(datasets);
                      if (false_coord){
                          alert("Row and column numbers were generated on the fly for displaying the physical layout or map. The plots are displayed in zigzag format. These row and column numbers will not be saved in the database. Click 'ok' to continue...");
                      }
                  }else {
                      jQuery("#d3_legend").css("display", "none");
                      jQuery("#container_field_map_view").css("display", "none");
                      jQuery("#no_map_view_MSG").css("display", "inline-block");
                  }

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
        d3.selectAll("#container_field_map_view > *").remove();
        jQuery("#container_field_map_view").css("display", "none");
        var name = $('#new_trial_name').val();
        var year = $('#add_project_year').val();
        var desc = $('textarea#add_project_description').val();
        if (name == '') {
            alert('Trial name required');
            return;
        }
        if (year === '' || desc === '') {
            alert('Year and description are required.');
            return;
        }
        if (stock_list_verified == 1 && seedlot_list_verified == 1){
            generate_experimental_design();
        } else if (cross_list_verified == 1 && stock_list_verified == 0 && family_name_list_verified == 0){
            generate_experimental_design();
        } else if (family_name_list_verified == 1 && cross_list_verified == 0 && stock_list_verified == 0){
            generate_experimental_design();
        } else {
            alert('Accession list, seedlot list, cross list or family name list is not valid!');
            return;
        }
    });

    $(document).on('change', '#select_stock_type', function () {

        var stock_type = jQuery('#select_stock_type').val();

        //add lists to the list select and list of checks select dropdowns based on stock type.
        if (stock_type == "accession"){
            document.getElementById("select_list").innerHTML = list.listSelect("select_list", [ 'accessions' ], '', 'refresh', undefined);
            document.getElementById("select_seedlot_list").innerHTML = list.listSelect("select_seedlot_list", [ 'seedlots' ], 'none', 'refresh', undefined);
            document.getElementById("list_of_checks_section").innerHTML = list.listSelect("list_of_checks_section", [ 'accessions' ], '', 'refresh', undefined);
            document.getElementById("crbd_list_of_checks_section").innerHTML = list.listSelect("crbd_list_of_checks_section", [ 'accessions' ], "select optional check list", 'refresh', undefined);
            document.getElementById("list_of_unrep_accession").innerHTML = list.listSelect("list_of_unrep_accession", [ 'accessions' ], "Required: e.g. 200", 'refresh', undefined);
            document.getElementById("list_of_rep_accession").innerHTML = list.listSelect("list_of_rep_accession", [ 'accessions' ], "Required: e.g. 119", 'refresh', undefined);
        } else if (stock_type == "cross") {
            document.getElementById("select_cross_list").innerHTML = list.listSelect("select_cross_list", [ 'crosses' ], '', 'refresh', undefined);
            document.getElementById("list_of_cross_checks_section").innerHTML = list.listSelect("list_of_cross_checks_section", [ 'accessions' ], '', 'refresh', undefined);
            document.getElementById("crbd_list_of_cross_checks_section").innerHTML = list.listSelect("crbd_list_of_cross_checks_section", [ 'accessions' ], "select optional check list", 'refresh', undefined);
            document.getElementById("list_of_unrep_cross").innerHTML = list.listSelect("list_of_unrep_cross", [ 'crosses' ], "Required: e.g. 200", 'refresh', undefined);
            document.getElementById("list_of_rep_cross").innerHTML = list.listSelect("list_of_rep_cross", [ 'crosses' ], "Required: e.g. 119", 'refresh', undefined);
        } else if (stock_type == "family_name") {
            document.getElementById("select_family_name_list").innerHTML = list.listSelect("select_family_name_list", [ 'family_names' ], '', 'refresh', undefined);
            document.getElementById("list_of_family_name_checks_section").innerHTML = list.listSelect("list_of_family_name_checks_section", [ 'accessions' ], '', 'refresh', undefined);
            document.getElementById("crbd_list_of_family_name_checks_section").innerHTML = list.listSelect("crbd_list_of_family_name_checks_section", [ 'accessions' ], "select optional check list", 'refresh', undefined);
            document.getElementById("list_of_unrep_family_name").innerHTML = list.listSelect("list_of_unrep_family_name", [ 'family_names' ], "Required: e.g. 200", 'refresh', undefined);
            document.getElementById("list_of_rep_family_name").innerHTML = list.listSelect("list_of_rep_family_name", [ 'family_names' ], "Required: e.g. 119", 'refresh', undefined);
        }

    });

    $(document).on('change', '#select_design_method', function () {

        var design_method = $("#select_design_method").val();
        var stock_type = jQuery('#select_stock_type').val();

        if (design_method == "CRD"){
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Generates completely a randomized design with equal or different repetition, using the methods of random number generation in R. Creates plot entities in the database.</p></div>');
        } else if (design_method == "RCBD") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Generates Randomized Complete Block Design, using the methods of random number generation in R. Creates plot entities in the database.</p></div>');
        } else if (design_method == "Alpha") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Creates alpha designs starting from the alpha design fixing under the 4 series formulated by Patterson and Williams. Creates plot entities in the database.</p></div>');
        } else if (design_method == "Lattice") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>SIMPLE and TRIPLE lattice designs. It randomizes treatments in K x K lattice. Creates plot entities in the database.</p></div>');
        } else if (design_method == "Augmented") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Some  treatments  (checks)  are  replicate  r  times  and  other  treatments  (new)  are replicated once. Creates plot entities in the database.</p></div>');
        } else if (design_method == "MAD") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Adjustments are calculated using data from all checks. Creates plot entities in the database.</p></div>');
        } else if (design_method == "greenhouse") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>A greenhouse/nursery houses plants in no particular layout design. The plants can be of named accessions or in the case of seedling nurseries from crosses, the plants can be of named crosses. Creates plot entities with plant entities in the database.</p></div>');
        } else if (design_method == "splitplot") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Split plot designs are useful for applying treatments to subplots of a plot. If you give three treatments, there will be three subplots with the treatment(s) distributed randomly among them. Creates plot entities with subplot entities with plant entities in the database.</p></div>');
        } else if (design_method == "p-rep") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Have some treatments that are unreplicated and rely on replicated treatments to make the trial analysable. It is recommended that at least 20% of the experimental units are occupied by replicated treatments. Creates plot entities in the database.</p></div>');
        } else if (design_method == "Westcott") {
            jQuery('#create_trial_design_description_div').html('<br/><div class="well"><p>Generates fieldplan for an unreplicated design with genotypes randomly allocated on a field with checks following the method described on Westcott (1981).</p></div>');
        } else {
            jQuery('#create_trial_design_description_div').html('');
        }


        if (design_method == "CRD") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "RCBD") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#trial_multi-design_more_info").show();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "Alpha") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "Lattice") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").show();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").show();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").show();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "Augmented") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").show();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").show();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").show();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#field_map_row_aug").hide();
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        } else if (design_method == "") {
            $("#FieldMap").hide();
            $("#prephelp").hide();
            $("#show_list_of_checks_section").hide();
            $("#crbd_show_list_of_checks_section").hide();
            $("#show_list_of_accession_section").hide();
            $("#show_list_of_unrep_accession").hide();
            $("#show_list_of_rep_accession").hide();
            $("#show_list_of_cross_checks_section").hide();
            $("#crbd_show_list_of_cross_checks_section").hide();
            $("#show_list_of_cross_section").hide();
            $("#show_list_of_unrep_cross").hide();
            $("#show_list_of_rep_cross").hide();
            $("#show_list_of_family_name_checks_section").hide();
            $("#crbd_show_list_of_family_name_checks_section").hide();
            $("#show_list_of_family_name_section").hide();
            $("#show_list_of_unrep_family_name").hide();
            $("#show_list_of_rep_family_name").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
            $("#design_info").show();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == "MAD") {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").show();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").show();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").show();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").hide();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
                }
                else {
                    $("#other_parameter_options").hide();
                }
            });
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == 'greenhouse') {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").hide();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
            greenhouse_show_num_plants_section();
        }
        else if (design_method == 'splitplot') {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").show();
            $("#prephelp").hide();
            $("#trial_multi-design_more_info").show();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
            $("#rep_count_section").hide();
            $("#block_number_section").show();
            $("#block_size_section").hide();
            $("#max_block_section").hide();
            $("#row_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#col_number_per_block_section").hide();
            $("#col_number_section").hide();
            $("#row_number_per_block_section").hide();
            $("#other_parameter_section").hide();
            $("#design_info").show();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").show();
            $("#num_plants_per_plot_section").show();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == 'p-rep') {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").show();
                $("#show_list_of_rep_accession").show();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").show();
                $("#show_list_of_rep_cross").show();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").show();
                $("#show_list_of_rep_family_name").show();
            }
            $("#FieldMap").hide();
            $("#trial_multi-design_more_info").show();
            $("#prephelp").show();
            $("#show_no_of_row_in_design").show();
            $("#show_no_of_col_in_design").show();
            $("#show_no_of_rep_times").show();
            $("#show_no_of_block_sequence").show();
            $("#show_no_of_sub_block_sequence").show();
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
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").hide();
            $("#westcott_num_col_between_check_section").hide();
            $("#westcott_check_1_section").hide();
            $("#westcott_check_2_section").hide();
            $("#FieldMap_westcott").hide();
        }
        else if (design_method == 'Westcott') {
            if (stock_type == "accession") {
                $("#show_list_of_accession_section").show();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "cross") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").show();
                $("#show_list_of_family_name_section").hide();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            } else if (stock_type == "family_name") {
                $("#show_list_of_accession_section").hide();
                $("#show_list_of_cross_section").hide();
                $("#show_list_of_family_name_section").show();
                $("#show_list_of_checks_section").hide();
                $("#show_list_of_cross_checks_section").hide();
                $("#show_list_of_family_name_checks_section").hide();
                $("#crbd_show_list_of_checks_section").hide();
                $("#crbd_show_list_of_cross_checks_section").hide();
                $("#crbd_show_list_of_family_name_checks_section").hide();
                $("#show_list_of_unrep_accession").hide();
                $("#show_list_of_rep_accession").hide();
                $("#show_list_of_unrep_cross").hide();
                $("#show_list_of_rep_cross").hide();
                $("#show_list_of_unrep_family_name").hide();
                $("#show_list_of_rep_family_name").hide();
            }
            $("#FieldMap").hide();
            $("#trial_multi-design_more_info").show();
            $("#prephelp").hide();
            $("#show_no_of_row_in_design").hide();
            $("#show_no_of_col_in_design").hide();
            $("#show_no_of_rep_times").hide();
            $("#show_no_of_block_sequence").hide();
            $("#show_no_of_sub_block_sequence").hide();
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
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#greenhouse_num_plants_per_accession_section").hide();
            $('#greenhouse_default_num_plants_per_accession').hide();
            $("#create_trial_with_treatment_section").hide();
            $("#num_plants_per_plot_section").hide();
            $("#westcott_num_col_section").show();
            $("#westcott_num_col_between_check_section").show();
            $("#westcott_check_1_section").show();
            $("#westcott_check_2_section").show();
            $("#FieldMap_westcott").show();
            $("#field_map_options").hide();
        }

        else {
            alert("Unsupported design method");
        }
    });

    jQuery("#westcott_check_1").autocomplete({
        appendTo: "#add_project_dialog",
        source: '/ajax/stock/accession_autocomplete',
    });

    jQuery("#westcott_check_2").autocomplete({
        appendTo: "#add_project_dialog",
        source: '/ajax/stock/accession_autocomplete',
    });

    jQuery(document).on('change', '#select_list_list_select', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });

    jQuery(document).on('change', '#select_cross_list_list_select', function() {
        if (jQuery("#select_design_method").val() == 'greenhouse') {
            greenhouse_show_num_plants_section();
        }
    });

    jQuery(document).on('change', '#select_family_name_list_list_select', function() {
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
	}
	else {
	    $("#plot_naming_options").hide();
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

    function save_experimental_design(design_json) {
        var list = new CXGN.List();
        var name = jQuery('#new_trial_name').val();
        var year = jQuery('#add_project_year').val();
        var desc = jQuery('#add_project_description').val();
        var locations = jQuery('#add_project_location').val();
        var trial_location =  JSON.stringify(locations);
        var trial_stock_type = jQuery('#select_stock_type').val();

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
        var westcott_check_1 = $('#westcott_check_1').val();
        var westcott_check_2 = $('#westcott_check_2').val();
        var westcott_col = $('#westcott_col').val();
        var westcott_col_between_check = $('#westcott_col_between_check').val();

        var plot_width = $('#add_project_plot_width').val();
        var plot_length = $('#add_project_plot_length').val();
        var field_size = $('#new_trial_field_size').val();
        var field_trial_is_planned_to_be_genotyped = $('#add_project_trial_will_be_genotyped').val();
        var field_trial_is_planned_to_cross = $('#add_project_trial_will_be_crossed').val();
        var selectedTrials = [];
        jQuery('#add_project_trial_source_select :selected').each(function(i, selectedElement) {
            selectedTrials.push(jQuery(selectedElement).val());
        });

        var use_same_layout;
        if ($('#use_same_layout').is(':checked')) {
           use_same_layout = $('#use_same_layout').val();
        }
        else {
           use_same_layout = "";
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
                //'trial_name': trial_name,
                'year': year,
                'trial_type': trial_type,
                'trial_location': trial_location,
                'trial_stock_type': trial_stock_type,
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
                'has_plant_entries': num_plants_per_plot,
                'has_subplot_entries': num_subplots_per_plot,
                'westcott_check_1': westcott_check_1,
                'westcott_check_2': westcott_check_2,
                'westcott_col': westcott_col,
                'westcott_col_between_check': westcott_col_between_check,
                'field_size': field_size,
                'plot_width': plot_width,
                'plot_length': plot_length,
                'field_trial_is_planned_to_be_genotyped': field_trial_is_planned_to_be_genotyped,
                'field_trial_is_planned_to_cross': field_trial_is_planned_to_cross,
                'add_project_trial_source': selectedTrials,
                'use_same_layout' : use_same_layout
            },
            success: function (response) {
                trial_id = response.trial_id;
                jQuery('#working_modal').modal("hide");
                if (response.error) {
                    alert(response.error);
                } else {
                    //alert('Trial design saved');
                    refreshTrailJsTree(0);
                    Workflow.complete('#new_trial_confirm_submit');
                    Workflow.focus("#trial_design_workflow", -1); //Go to success page
                    Workflow.check_complete("#trial_design_workflow");
                    add_plants_per_plot();
                }
            },
            error: function () {
                jQuery('#working_modal').modal("hide");
                alert('An error occurred saving the trial.');
            }
        });
    }

    jQuery(document).on('click', '[name="create_trial_success_complete_button"]', function(){
        jQuery('#add_project_dialog').modal('hide');
        window.location.href = '/breeders/trials';
        return false;
    });

    jQuery('#new_trial_confirm_submit').click(function () {
        save_experimental_design(design_json);
    });

    $('#redo_trial_layout_button').click(function () {
        generate_experimental_design();
        return false;
    });

    function open_project_dialog() {
        $('#add_project_dialog').modal("show");

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

        $("#select_cross_list_list_select").prepend("<option value=''></option>").val('');
        $("#select_cross_list_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#select_family_name_list_list_select").prepend("<option value=''></option>").val('');
        $("#select_family_name_list_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        //add a blank line to list select dropdown that dissappears when dropdown is opened
        $("#select_seedlot_list_list_select").prepend("<option value=''></option>").val('');
        $("#select_seedlot_list_list_select").one('mousedown', function () {
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

        $("#list_of_cross_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#list_of_cross_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#crbd_list_of_cross_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#crbd_list_of_cross_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#list_of_family_name_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#list_of_family_name_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        $("#crbd_list_of_family_name_checks_section_list_select").prepend("<option value=''></option>").val('');
        $("#crbd_list_of_family_name_checks_section_list_select").one('mousedown', function () {
            $("option:first", this).remove();
        });

        //add a blank line to design method select dropdown that dissappears when dropdown is opened
        $("#select_design_method").prepend("<option value=''></option>").val('');
        $("#select_design_method").one('mousedown', function () {
            $("option:first", this).remove();
            //trigger design method change events in case the first one is selected after removal of the first blank select item
            $("#select_design_method").change();
        });

        //reset previous selections
        $("#select_design_method").change();
    }

    $('#add_project_link').click(function () {
        get_select_box('years', 'add_project_year', {'auto_generate': 1 });
        get_select_box('trial_types', 'add_project_type', {'empty':1} );
        populate_trial_linkage_selects();

        // preselect user's program and filter locations

        open_project_dialog();
    });

    jQuery('#select_breeding_program').change(function(){
        populate_trial_linkage_selects();
    });

    function populate_trial_linkage_selects(){
        get_select_box('trials', 'add_project_trial_source', {'id':'add_project_trial_source_select', 'name':'add_project_trial_source_select', 'breeding_program_name':jQuery('#select_breeding_program').val(), 'multiple':1, 'empty':1} );
    }

    jQuery('button[name="new_trial_add_treatments"]').click(function(){
        jQuery('#trial_design_add_treatments').modal('show');
    });

    jQuery('#new_trial_add_treatments_continue').click(function(){
        var treatment_name = jQuery('#new_treatment_name').val();
        var html = "";
        var design_array = JSON.parse(design_json);
        for (var i=0; i<design_array.length; i++){
            html += "<table class='table table-hover'><thead><tr><th>plot_name</th><th>accession</th><th>plot_number</th><th>block_number</th><th>rep_number</th><th>is_a_control</th><th>row_number</th><th>col_number</th><th class='table-success'>"+treatment_name+" [Select all <input type='checkbox' name='add_trial_treatment_select_all' />]</th></tr></thead><tbody>";
            var design_hash = JSON.parse(design_array[i]);
            //console.log(design_hash);
            for (var key in design_hash){
                if (key != 'treatments'){
                    var plot_obj = design_hash[key];
                    html += "<tr><td>"+plot_obj.plot_name+"</td><td>"+plot_obj.stock_name+"</td><td>"+plot_obj.plot_number+"</td><td>"+plot_obj.block_number+"</td><td>"+plot_obj.rep_number+"</td><td>"+plot_obj.is_a_control+"</td><td>"+plot_obj.row_number+"</td><td>"+plot_obj.col_number+"</td><td><input data-plot_name='"+plot_obj.plot_name+"' data-trial_index='"+i+"' data-trial_treatment='"+treatment_name+"'  data-plant_names='"+JSON.stringify(plot_obj.plant_names)+"' data-subplot_names='"+JSON.stringify(plot_obj.subplots_names)+"' type='checkbox' name='add_trial_treatment_input'/></td></tr>";
                }
            }
            html += "</tbody></table>";
        }
        html += "<br/><br/>";
        jQuery('#trial_design_add_treatment_select_html').html(html);
        jQuery('#trial_design_add_treatment_select').modal('show');
    });

    jQuery(document).on('change', 'input[name="add_trial_treatment_select_all"]', function(){
        if(jQuery(this).is(":checked")){
            jQuery('input[name="add_trial_treatment_input"]').each(function(){
                jQuery(this).prop("checked", true);
            });
        } else {
            jQuery('input[name="add_trial_treatment_input"]').each(function(){
                jQuery(this).prop("checked", false);
            });
        }
    });

    jQuery('#new_trial_add_treatments_submit').click(function(){
        var new_treatment_year = jQuery('#new_treatment_year').val();
        var new_treatment_date = jQuery('#new_treatment_date').val();
        var new_treatment_type = jQuery('#new_treatment_type').val();
        new_treatment_date = moment(new_treatment_date).format('YYYY/MM/DD HH:mm:ss')

        var trial_treatments = [];
        jQuery('input[name="add_trial_treatment_input"]').each(function() {
            if (this.checked){
                var plot_name = jQuery(this).data('plot_name');
                var plant_names = jQuery(this).data('plant_names');
                var subplot_names = jQuery(this).data('subplot_names');
                var trial_index = jQuery(this).data('trial_index');
                var trial_treatment = jQuery(this).data('trial_treatment');
                if (trial_index in trial_treatments){
                    var trial = trial_treatments[trial_index];
                    if (trial_treatment in trial){
                        trial[trial_treatment]['new_treatment_stocks'].push(plot_name);
                    } else {
                        trial[trial_treatment]['new_treatment_stocks'] = [plot_name];
                    }
                    if (plant_names != 'undefined'){
                        for(var i=0; i<plant_names.length; i++){
                            trial[trial_treatment]['new_treatment_stocks'].push(plant_names[i]);
                        }
                    }
                    if (subplot_names != 'undefined'){
                        for(var i=0; i<subplot_names.length; i++){
                            trial[trial_treatment]['new_treatment_stocks'].push(subplot_names[i]);
                        }
                    }
                    trial[trial_treatment]["new_treatment_type"] = new_treatment_type;
                    trial[trial_treatment]["new_treatment_date"] = new_treatment_date;
                    trial[trial_treatment]["new_treatment_year"] = new_treatment_year;

                    trial_treatments[trial_index] = trial;
                } else {
                    obj = {};
                    obj[trial_treatment] = {};
                    obj[trial_treatment]['new_treatment_stocks'] = [plot_name];
                    if (plant_names != 'undefined'){
                        for(var i=0; i<plant_names.length; i++){
                            obj[trial_treatment]['new_treatment_stocks'].push(plant_names[i]);
                        }
                    }
                    if (subplot_names != 'undefined'){
                        for(var i=0; i<subplot_names.length; i++){
                            obj[trial_treatment]['new_treatment_stocks'].push(subplot_names[i]);
                        }
                    }
                    trial_treatments[trial_index] = obj;
                }
            }
        });

        var new_design_array = [];
        var design_array = JSON.parse(design_json);
        for (var i=0; i<design_array.length; i++){
            var design_hash = JSON.parse(design_array[i]);
            if ('treatments' in design_hash){
                treatment_obj = design_hash['treatments'];
                new_treatments = trial_treatments[i];
                for (var key in new_treatments){
                    treatment_obj[key] = new_treatments[key];
                }
                design_hash['treatments'] = treatment_obj;
            } else {
                design_hash['treatments'] = trial_treatments[i];
            }
            new_design_array[i] = JSON.stringify(design_hash);
        }
        design_json = JSON.stringify(new_design_array);

        var html = '';
        for (var i=0; i<new_design_array.length; i++){
            var design_hash = JSON.parse(new_design_array[i]);
            var treatments = design_hash['treatments'];
            //html += "Trial "+i+"<br/>";
            for (var key in treatments){
                html += "Treatment: <b>"+key+"</b> Plots: ";
                var plot_array = treatments[key]['new_treatment_stocks'];
                html += plot_array.join(', ') + "<br/>";
            }
        }
        jQuery('#trial_design_confirm_treatments').html(html);
        jQuery('#trial_design_add_treatment_select').modal('hide');
        jQuery('#trial_design_add_treatments').modal('hide');
    });

});

function greenhouse_show_num_plants_section(){
    var list = new CXGN.List();

    var accession_list_id = jQuery('#select_list_list_select').val();
    var cross_list_id = jQuery('#select_cross_list_list_select').val();
    var family_name_list_id = jQuery('#select_family_name_list_list_select').val();

    var default_num = jQuery('#greenhouse_default_num_plants_per_accession_val').val();
    if (accession_list_id != "") {
        var accession_list = list.getList(accession_list_id);
        var html = '<form class="form-horizontal">';
        for (var i=0; i<accession_list.length; i++){
            html = html + '<div class="form-group"><label class="col-sm-9 control-label">' + accession_list[i] + ': </label><div class="col-sm-3"><input class="form-control" id="greenhouse_num_plants_input_' + i + '" type="text" placeholder="'+default_num+'" value="'+default_num+'" /></div></div>';
        }
        html = html + '</form>';
        jQuery("#greenhouse_num_plants_per_accession").empty().html(html);
    } else if (cross_list_id != "") {
        var cross_list = list.getList(cross_list_id);
        var html = '<form class="form-horizontal">';
        for (var i=0; i<cross_list.length; i++){
            html = html + '<div class="form-group"><label class="col-sm-9 control-label">' + cross_list[i] + ': </label><div class="col-sm-3"><input class="form-control" id="greenhouse_num_plants_input_' + i + '" type="text" placeholder="'+default_num+'" value="'+default_num+'" /></div></div>';
        }
        html = html + '</form>';
        jQuery("#greenhouse_num_plants_per_accession").empty().html(html);
    } else if (family_name_list_id != "") {
        var family_name_list = list.getList(family_name_list_id);
        var html = '<form class="form-horizontal">';
        for (var i=0; i<family_name_list.length; i++){
            html = html + '<div class="form-group"><label class="col-sm-9 control-label">' + family_name_list[i] + ': </label><div class="col-sm-3"><input class="form-control" id="greenhouse_num_plants_input_' + i + '" type="text" placeholder="'+default_num+'" value="'+default_num+'" /></div></div>';
        }
        html = html + '</form>';
        jQuery("#greenhouse_num_plants_per_accession").empty().html(html);
    }
}

function extend_obj(obj, src) {
    for (var key in src) {
        if (src.hasOwnProperty(key)) obj[key] = src[key];
    }
    return obj;
}
