/*jslint browser: true, devel: true */

/**

=head1 Crosses.js

Dialogs for adding and uploading crosses

=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();

jQuery(document).ready(function($) {

    $("#create_cross_link").click(function() {

        $("#cross_type_info").click(function() {
            $("#cross_type_dialog").modal("show");
        });

        get_select_box('folders', 'add_cross_folder_select_div', {
            'name': 'add_cross_folder_id',
            'id': 'add_cross_folder_id',
            'folder_for_crosses' : 1,
            'empty': 1
        });

        var lo = new CXGN.List();
        $('#polycross_accession_list').html(lo.listSelect('polycross_accessions', ['accessions'], 'select'));
        $('#reciprocal_accession_list').html(lo.listSelect('reciprocal_accessions', ['accessions'], 'select'));
        $('#maternal_accession_list').html(lo.listSelect('maternal_accessions', ['accessions'], 'select'));
        $('#paternal_accession_list').html(lo.listSelect('paternal_accessions', ['accessions'], 'select'));

        $("#create_cross").modal("show");

        $("#cross_type").change(function() { // show cross_type specific inputs depending on cross type selected
            $("#get_maternal_parent").toggle($("#cross_type").val() == "biparental");
            $("#get_paternal_parent").toggle($("#cross_type").val() == "biparental");
            $("#get_selfed_parent").toggle($("#cross_type").val() == "self");
            $("#get_open_maternal_parent").toggle($("#cross_type").val() == "open");
            $("#get_open_paternal_population").toggle($("#cross_type").val() == "open");
            $("#get_bulk_maternal_population").toggle($("#cross_type").val() == "bulk");
            $("#get_bulk_paternal_parent").toggle($("#cross_type").val() == "bulk");
            $("#get_bulk_selfed_population").toggle($("#cross_type").val() == "bulk_self");
            $("#get_bulk_open_maternal_population").toggle($("#cross_type").val() == "bulk_open");
            $("#get_bulk_open_paternal_population").toggle($("#cross_type").val() == "bulk_open");
            $("#get_doubled_haploid_parent").toggle($("#cross_type").val() == "doubled_haploid");
            $("#polycross_accessions").toggle($("#cross_type").val() == "polycross");
            $("#reciprocal_accessions").toggle($("#cross_type").val() == "reciprocal");
            $("#maternal_accessions").toggle($("#cross_type").val() == "multicross");
            $("#paternal_accessions").toggle($("#cross_type").val() == "multicross");
        });

        $('input[id*="_parent"]').autocomplete({
            source: '/ajax/stock/accession_autocomplete'
        });

        $('input[id*="_population"]').autocomplete({
            source: '/ajax/stock/stock_autocomplete'
        });

        $("#flower_number_checkbox").change(function() {
            $("#get_flower_number").toggle(this.checked); // show if it is checked, otherwise hide
        });

        $("#fruit_number_checkbox").change(function() {
            $("#get_fruit_number").toggle(this.checked); // show if it is checked, otherwise hide
        });

        $("#use_folders_checkbox").change(function() {
            $("#folder_section").toggle(this.checked); // show if it is checked, otherwise hide
        });

        $("#seed_number_checkbox").change(function() {
            $("#get_seed_number").toggle(this.checked); // show if it is checked, otherwise hide
        });

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
        if (!crossName) {
            alert("A cross name is required");
            return;
        }

        var breeding_program_id = $("#program").val();
        if (!breeding_program_id) {
            alert("A breeding program is required");
            return;
        }

        var visibleToRole = $("#visible_to_role").val();
        var location = $("#location").val();
        var folder_name = $("#add_cross_folder_name").val();
        var folder_id;
        if (folder_name) {  // get id if folder with this name already exisits
            folder_id = $('#add_cross_folder_id option').filter(function () { return $(this).html() == folder_name; }).val();
        }
        else {
            folder_id = $("#add_cross_folder_id").val();
        }
        add_cross(crossType, crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id);

    });

    $("#upload_crosses_link").click(function() {

        $("#cross_upload_spreadsheet_format_info").click(function() {
            $("#cross_upload_spreadsheet_info_dialog").modal("show");
        });

        get_select_box('folders', 'cross_folder_select_div', {
            'name': 'upload_folder_id',
            'id': 'upload_folder_id',
            'folder_for_crosses': 1,
            'empty': 1
        });
        $("#upload_crosses_dialog").modal("show");
    });

    $("#upload_crosses_submit").click(function() {
        $("#upload_crosses_dialog").modal("hide");
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
                $('#cross_saved_dialog_message').modal("show");
            }
        }
    });

    jQuery("#refresh_crosstree_button").click(function() {
        jQuery.ajax({
            url: '/ajax/breeders/get_crosses_with_folders',
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                jQuery("#working_modal").modal("hide");
                location.reload();
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred refreshing crosses jstree html');
            }
        });
    });

    function add_cross(crossType, crossName, breeding_program_id, visibleToRole, location, folder_name, folder_id) {

        var progenyNumber = $("#progeny_number").val();
        var flowerNumber = $("#flower_number").val();
        var fruitNumber = $("#fruit_number").val();
        var seedNumber = $("#seed_number").val();
        var prefix = $("#prefix").val();
        var suffix = $("#suffix").val();
        var maternal;
        var paternal;
        var maternal_parents;
        var paternal_parents;

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
        }

        $.ajax({
            url: '/ajax/cross/add_cross',
            timeout: 3000000,
            dataType: "json",
            type: 'POST',
            data: 'cross_name=' + crossName + '&cross_type=' + crossType + '&maternal=' + maternal + '&paternal=' + paternal + '&maternal_parents=' + maternal_parents + '&paternal_parents=' + paternal_parents + '&progeny_number=' + progenyNumber + '&flower_number=' + flowerNumber + '&fruit_number=' + fruitNumber + '&seed_number=' + seedNumber + '&prefix=' + prefix + '&suffix=' + suffix + '&visible_to_role' + visibleToRole + '&breeding_program_id=' + breeding_program_id + '&location=' + location + '&folder_name=' + folder_name + '&folder_id=' + folder_id,
            beforeSend: function() {
                jQuery("#create_cross").modal("hide");
                jQuery("#working_modal").modal("show");
            },
            error: function(response) {
                alert("An error occurred. Please try again later!" + JSON.stringify(response));
            },
            parseerror: function(response) {
                alert("A parse error occurred. Please try again." + response);
            },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                } else {
                    jQuery("#working_modal").modal("hide");
                    $('#cross_saved_dialog_message').modal("show");
                }
            },
        });

    }

    function upload_crosses_file() {
        var uploadFile = $("#crosses_upload_file").val();
        $('#upload_crosses_form').attr("action", "/ajax/cross/upload_crosses_file");
        if (uploadFile === '') {
            alert("Please select a file");
            return;
        }
        $("#upload_crosses_form").submit();
    }

    function get_accession_names(accession_select_id) {

        var accession_list_id = $('#' + accession_select_id).val();
        var lo = new CXGN.List();
        var accession_validation = 1;
        if (accession_list_id) {
            accession_validation = lo.validate(accession_list_id, 'accessions', true);
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
        for (i = 0; i < accessions.length; i++) {
            names.push(accessions[i][1]);
        }
        return names;
    }
});
