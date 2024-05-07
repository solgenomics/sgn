/*jslint browser: true, devel: true */

/**

=head1 FieldBook.js

Dialogs for field book tools


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>
Bryan Ellerbrock <bje24@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function($) {

    get_select_box('traits', 'select_traits_for_trait_file', {
        'name': 'html_select_traits_for_trait_file',
        'id': 'html_select_traits_for_trait_file',
        'empty': 0,
        'multiple': 1,
        'size':10
    });

    jQuery('#create_new_trait_file_link').click(function() {
        var list = new CXGN.List();
        var trait_lists = list.listSelect('select_list', ['traits'], 'Select a list', undefined, undefined);
        jQuery('#select_list_div').html(trait_lists);
        if (document.getElementById("html_select_traits_for_trait_file")) {
            show_list_counts_fb('trait_select_count', document.getElementById("html_select_traits_for_trait_file").length);
        }

        jQuery('#html_select_traits_for_trait_file').change(
            function() {
                jQuery('#select_list_list_select').val('');
                var traits = document.getElementById("html_select_traits_for_trait_file").length;
                var selected = jQuery('#html_select_traits_for_trait_file option:selected').length;
                show_list_counts_fb('trait_select_count', traits, selected);
            });
        jQuery('#create_trait_file_dialog').modal('show');
    });

    jQuery('#create_trait_file_ok_button').on('click', function() {
        generate_trait_file();
    });

    jQuery("#trait_file_close_button").click(function() {
        jQuery("#trait_file_saved_dialog_message").modal("hide");
        location.reload();
    });

    jQuery('#delete_fieldbook_layout_link').click(function() {
        alert('Layout deleted successfully.');
    });

});

function show_list_counts_fb(count_div, total_count, selected) {
    var html = 'Traits: ' + total_count + '<br />';
    if (selected) {
        html += 'Selected: ' + selected;
    }
    jQuery('#' + count_div).html(html);
}

function generate_trait_file() {
    var trait_list_id = jQuery('#select_list_list_select').val();
    var trait_ids = [];
    var trait_list = [];
    var selected_listed = '';
    if (trait_list_id) {
        var list = new CXGN.List();
        trait_list = JSON.stringify(list.getList(trait_list_id));
        var valid_list = JSON.stringify(list.legacy_validate(trait_list_id, 'traits', 1));
        if (!valid_list) { return; }
        trait_ids = JSON.stringify(list.transform(trait_list_id, 'traits_2_trait_ids'));
        selected_listed = 1;
    } else {
        var trait_temp_ids = [];
        jQuery("#html_select_traits_for_trait_file option:selected").each(
            function() {
                var temp_id_value = jQuery('#html_select_traits_for_trait_file').val();
                trait_temp_ids = temp_id_value;
            });
        trait_ids = trait_temp_ids;
        var trait_names = [];
        jQuery("#html_select_traits_for_trait_file option:selected").each(
            function() {
               trait_names.push(jQuery(this).text());
            });

        trait_list = JSON.stringify(trait_names);
    }

    if (trait_ids == '') {
        alert("Traits, from a list or selected individually, are required.");
        return;
    }

    var include_notes = jQuery('#include_notes_trait').is(':checked');
    var trait_file_name = jQuery('#trait_file_name').val();

    if (trait_file_name == '') {
        alert("A trait file name is required.");
        return;
    }
    jQuery.ajax({
        type: 'POST',
        url: '/ajax/fieldbook/traitfile/create',
        dataType: "json",
        data: {
            'trait_list': trait_list,
            'trait_ids': trait_ids,
            'trait_file_name': trait_file_name,
            'include_notes': include_notes,
            'selected_listed': selected_listed,
        },
        beforeSend: function() {
            jQuery("#working_modal").modal("show");
        },
        success: function(response) {
            jQuery("#working_modal").modal("hide");
            if (response.error) {
                alert(response.error);
            } else {
                jQuery('#trait_file_download_link').attr('href', "/fieldbook/trait_file_download/" + response.file_id);
                jQuery("#trait_file_saved_dialog_message").modal("show");
                jQuery('#create_trait_file_dialog').modal("hide");
            }
        },
        error: function() {
            jQuery("#working_modal").modal("hide");
            alert('An error occurred creating the trait file.');
            jQuery('#create_trait_file_dialog').modal("hide");
        },
    });
}
