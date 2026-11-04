/*jslint browser: true, devel: true */

/**

=head1 FieldBook.js

Dialogs for field book tools


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>
Bryan Ellerbrock <bje24@cornell.edu>

=cut

*/


var fieldBookTraitI18n = window.SGN && window.SGN.i18n || {
    p: function(context, text, vars) {
        return String(text).replace(/%\{([A-Za-z_][A-Za-z0-9_]*)\}/g, function(token, name) {
            return vars && Object.prototype.hasOwnProperty.call(vars, name) ? String(vars[name]) : token;
        });
    }
};
function fieldBookTraitHTML(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, function(c) {
        return {"&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"}[c];
    });
}
function fieldBookTraitLocaleHeaders(url) {
    try {
        var destination = new URL(url, window.location.href);
        if (destination.origin !== window.location.origin) return {};
        var locale = fieldBookTraitI18n.requestedLocale || document.documentElement.getAttribute("data-sgn-locale") || "en";
        return {"X-SGN-Locale": /^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$/.test(locale) ? locale : "en"};
    } catch (error) { return {}; }
}

function fieldBookTableLanguage() {
    return {
        sEmptyTable: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.empty', 'No data available in table')),
        sInfo: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.info', 'Showing %{start} to %{end} of %{total} entries', {start: '_START_', end: '_END_', total: '_TOTAL_'})),
        sInfoEmpty: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.info_empty', 'Showing 0 to 0 of 0 entries')),
        sInfoFiltered: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.filtered', '(filtered from %{maximum} total entries)', {maximum: '_MAX_'})),
        sLengthMenu: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.length', 'Show %{menu} entries', {menu: '_MENU_'})),
        sLoadingRecords: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.loading', 'Loading...')),
        sProcessing: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.processing', 'Processing...')),
        sSearch: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.search', 'Search:')),
        sZeroRecords: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.zero', 'No matching records found')),
        oPaginate: {
            sFirst: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.first', 'First')),
            sLast: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.last', 'Last')),
            sNext: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.next', 'Next')),
            sPrevious: fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.table.previous', 'Previous'))
        },
        oAria: {
            sSortAscending: fieldBookTraitI18n.p('fieldbook.table.sort_ascending', ': activate to sort column ascending'),
            sSortDescending: fieldBookTraitI18n.p('fieldbook.table.sort_descending', ': activate to sort column descending')
        }
    };
}

// DataTables serializes a heading into its ARIA prefix. Restore the literal
// DOM text while preserving the plugin's own next-sort instruction verbatim.
function fieldBookTableAria(settings) {
    settings.aoColumns.forEach(function(column) {
        var heading = column.nTh;
        var label = heading.getAttribute('aria-label');
        var prefix = column.sTitle.replace(/<.*?>/g, '');
        if (label !== null && label.slice(0, prefix.length) === prefix) {
            heading.setAttribute('aria-label', heading.textContent + label.slice(prefix.length));
        }
    });
}

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
        var trait_lists = list.listSelect('select_list', ['traits'], fieldBookTraitI18n.p('fieldbook.trait.client.select_list', 'Select a list'), undefined, undefined);
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
        alert(fieldBookTraitI18n.p('fieldbook.layout.deleted', 'Layout deleted successfully.'));
    });

});

function show_list_counts_fb(count_div, total_count, selected) {
    var html = fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.trait.client.total', 'Traits: %{count}', {count: total_count})) + '<br />';
    if (selected) {
        html += fieldBookTraitHTML(fieldBookTraitI18n.p('fieldbook.trait.client.selected', 'Selected: %{count}', {count: selected}));
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
        alert(fieldBookTraitI18n.p('fieldbook.trait.client.traits_required', 'Traits, from a list or selected individually, are required.'));
        return;
    }

    var include_notes = jQuery('#include_notes_trait').is(':checked');
    var trait_file_name = jQuery('#trait_file_name').val();

    if (trait_file_name == '') {
        alert(fieldBookTraitI18n.p('fieldbook.trait.client.name_required', 'A trait file name is required.'));
        return;
    }
    jQuery.ajax({
        type: 'POST',
        url: '/ajax/fieldbook/traitfile/create',
        headers: fieldBookTraitLocaleHeaders('/ajax/fieldbook/traitfile/create'),
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
            alert(fieldBookTraitI18n.p('fieldbook.trait.client.create_failed', 'An error occurred creating the trait file.'));
            jQuery('#create_trait_file_dialog').modal("hide");
        },
    });
}
