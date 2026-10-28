// Optional locale assets never block the native crossing workflow.
var crossI18n = (window.SGN && window.SGN.i18n) || {
    p: function (context, source, variables) {
        return source.replace(/%\{([A-Za-z0-9_]+)\}/g, function (match, name) {
            return variables && Object.prototype.hasOwnProperty.call(variables, name) ? String(variables[name]) : match;
        });
    },
    np: function (context, one, many, count, variables) {
        return this.p(context, count === 1 ? one : many, variables);
    }
};
// Presentation language belongs only to these reviewed same-origin crossing actions.
function crossLocaleTag() {
    var root = typeof document !== 'undefined' && document.documentElement;
    var runtime = window.SGN && window.SGN.i18n;
    var requested = root && typeof root.getAttribute === 'function' && root.getAttribute('data-sgn-locale');
    var tag = requested || (runtime && runtime.requestedLocale) || (root && root.lang) || (runtime && runtime.locale) || 'en';
    return typeof tag === 'string' && /^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{2,8})*$/.test(tag) ? tag : 'en';
}
function crossLocaleTarget(url) {
    try {
        var target = new URL(url, window.location.href);
        if (target.origin !== window.location.origin) return null;
        var admitted = /^\/ajax\/cross\/(?:add_cross|add_crossingtrial|upload_crosses_file|delete|(?:membership|accession_plot_plant_parents|properties|transactions|additional_info|tissue_culture_summary)\/[0-9]+)$/.test(target.pathname)
            || /^\/cross\/(?:ajax\/relationships|progeny\/add|property\/(?:check|save))\/[0-9]+$/.test(target.pathname)
            || /^\/ajax\/pedigrees\/(?:upload_verify|upload_store|get_full|get_relationships)$/.test(target.pathname);
        return admitted ? target : null;
    } catch (error) {
        return null;
    }
}
function crossLocaleHeaders(url) {
    return crossLocaleTarget(url) ? {'X-SGN-Locale': crossLocaleTag()} : {};
}
function crossLocaleUploadURL(url) {
    var target = crossLocaleTarget(url);
    if (!target || !/^\/ajax\/(?:cross\/upload_crosses_file|pedigrees\/upload_verify)$/.test(target.pathname)) return url;
    // Native iframe forms cannot emit custom HTTP headers. Keep their payload intact.
    target.searchParams.set('lang', crossLocaleTag());
    return target.pathname + target.search + target.hash;
}

function crossHTML(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (character) {
        return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[character];
    });
}

function crossTableLanguage() {
    return {
        sEmptyTable: crossHTML(crossI18n.p("accessions.table.empty", "No data available in table")),
        sInfo: crossHTML(crossI18n.p("accessions.table.info", "Showing %{start} to %{end} of %{total} entries", {start: '_START_', end: '_END_', total: '_TOTAL_'})),
        sInfoEmpty: crossHTML(crossI18n.p("accessions.table.info_empty", "Showing 0 to 0 of 0 entries")),
        sInfoFiltered: crossHTML(crossI18n.p("accessions.table.filtered", "(filtered from %{maximum} total entries)", {maximum: '_MAX_'})),
        sLengthMenu: crossHTML(crossI18n.p("accessions.table.length", "Show %{menu} entries", {menu: '_MENU_'})),
        sLoadingRecords: crossHTML(crossI18n.p("accessions.table.loading", "Loading...")),
        sProcessing: crossHTML(crossI18n.p("accessions.table.processing", "Processing...")),
        sSearch: crossHTML(crossI18n.p("accessions.table.search", "Search:")),
        oPaginate: {sFirst: crossHTML(crossI18n.p("accessions.table.first", "First")), sLast: crossHTML(crossI18n.p("accessions.table.last", "Last")), sNext: crossHTML(crossI18n.p("accessions.table.next", "Next")), sPrevious: crossHTML(crossI18n.p("accessions.table.previous", "Previous"))},
    };
}

jQuery(document).ready(function() {

    display_parents(get_cross_id());

    display_progeny(get_cross_id());

    get_properties(get_cross_id());

    display_membership(get_cross_id());

    display_transactions(get_cross_id());

    display_cross_additional_info(get_cross_id());

    function get_cross_id() {
        var cross_id = jQuery('#cross_id').html();
        var regex = /\n|\r/g;
        cross_id = cross_id.replace(regex, "");
        return cross_id;
    }

    function get_cross_name() {
        var cross_name = jQuery('#cross_name').html();
        var regex = /\n|\r/g;
        cross_name = cross_name.replace(regex, "");
        return cross_name;
    }

    function display_progeny(cross_id) {
        jQuery.ajax( {
            type: 'POST',
            url: '/cross/ajax/relationships/'+cross_id,
            headers: crossLocaleHeaders('/cross/ajax/relationships/'+cross_id),
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                    return;
                }
                if (response.progeny) {
                    var html = '<table class="table borderless" alt="breeder search" border="0" ><tr><td><select multiple class="form-control" id="progeny_data" name="1" size="10" style="min-width: 200px;overflow:auto;"></select></td></tr>'
                    html += "<tr><td><button class=\"btn btn-default btn-sm\" id=\"progeny_select_all\" name=\"1\">" + crossHTML(crossI18n.p("cross.ui.select_all", "Select All")) + "</button><br><br>"
                    html += "<div class=\"well well-sm\"><div id=\"progeny_data_count\" name=\"1\">" + crossHTML(crossI18n.p("cross.ui.no_selection", "No Selection")) + "</div></div>"
                    html += '<div id="progeny_to_list_menu"></div><td><tr></table>'

                    jQuery('#progeny_information_div').html(html);

                    var progeny = response.progeny.sort() || [];

                    progeny.forEach(function(accession_info_array) { // swap position of id and uniquename for each progeny array
                        accession_info_array.reverse();
                    });

                    progeny_html = format_options_list(progeny);
                    jQuery('#progeny_data').html(progeny_html);

                    var data = jQuery('#progeny_data').val() || [];;
                    show_list_counts('progeny_data_count', progeny.length, data.length);

                    if (jQuery('#progeny_data').length) {
                        addToListMenu('progeny_to_list_menu', 'progeny_data', {
                            selectText: true,
                            listType: 'accessions'
                        });
                    }

                    jQuery('#progeny_select_all').click( function() { // select all progeny
                        var data_id = "progeny_data";
                        selectAllOptions(document.getElementById(data_id));

                        var data = jQuery("#"+data_id).val() || [];;
                        var count_id = "progeny_data_count";
                        show_list_counts(count_id, jQuery('#'+data_id).text().split("\n").length-1, data.length);
                    });

                    jQuery('#progeny_data').change( function() { // update count when data selections change
                        var data_id = jQuery(this).attr('id');
                        var data = jQuery('#'+data_id).val() || [];;
                        var count_id = "progeny_data_count";
                        show_list_counts(count_id, jQuery('#'+data_id).text().split("\n").length-1, data.length);
                    });

                    jQuery('select').dblclick( function() { // open progeny detail page in new window or tab on double-click
                        window.open("../../stock/"+this.value+"/view");
                    });
                } // close if (response.progeny)
            },
            error: function(response, a, b) {
                jQuery('#progeny_information_div').html(crossHTML(crossI18n.p("cross.ui.an_error_occurred_code_detail", "An error occurred. %{code} %{detail}", {code: a, detail: b})));
            }
	    });
    }

    function display_membership(cross_id){
        var membership_table = jQuery('#membership_table').DataTable({
            language: crossTableLanguage(),
            'ajax': {url: '/ajax/cross/membership/'+cross_id, headers: crossLocaleHeaders('/ajax/cross/membership/'+cross_id)},
            'paging' : false,
            'searching' : false,
        });
        return;
    }

    function display_parents(cross_id){
        var parents_table = jQuery('#parent_information').DataTable({
            language: crossTableLanguage(),
            'ajax': {url: '/ajax/cross/accession_plot_plant_parents/'+cross_id, headers: crossLocaleHeaders('/ajax/cross/accession_plot_plant_parents/'+cross_id)},
            'paging' : false,
            'searching' : false,
            'bInfo' : false,
        });
        return;
    }

    jQuery('#add_more_progeny_link').click( function() {
        jQuery('#add_more_progeny_dialog').dialog("open");
        jQuery('#progeny_count').focus();
    });

    jQuery('#add_more_progeny_dialog').dialog( {
        height: 250,
        width: 500,
        buttons: { 'OK':
            {
                id: 'add_more_progeny_dialog_ok_button',
                click: function() {
                    jQuery('#working').dialog("open");
                    add_more_progeny(get_cross_id(), get_cross_name(), jQuery('#basename').val(), jQuery('#start_number').val(), jQuery('#progeny_count').val());
                },
                text: crossI18n.p("cross.ui.ok", "OK")
            } ,
            'Cancel': {
                id: 'add_more_progeny_dialog_cancel_button',
                click:  function() { jQuery('#add_more_progeny_dialog').dialog("close") },
                text: crossI18n.p("cross.ui.cancel", "Cancel")
            }
        },
        autoOpen: false,
        title: crossI18n.p("cross.ui.add_more_progeny", "Add more progeny")
    });

    function add_more_progeny(cross_id, cross_name, basename, start_number, progeny_count) {

        jQuery.ajax({
            url: '/cross/progeny/add/'+cross_id,
            headers: crossLocaleHeaders('/cross/progeny/add/'+cross_id),
            data: { 'cross_name': cross_name, 'basename': basename, 'start_number': start_number, 'progeny_count': progeny_count },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                else { alert(crossI18n.p("cross.ui.added_count_new_progeny", "Added %{count} new progeny", {count: progeny_count}));
                    jQuery('#working').dialog("close");
                    display_progeny(get_cross_id());
                    jQuery('#add_more_progeny_dialog').dialog("close");
                }
            },
            error: function(response, code, error) { alert(crossI18n.p("cross.ui.error_detail", "error: %{detail}", {detail: error})); }
        });
    }

    jQuery('#edit_properties_dialog').dialog( {
        height: 250,
        width: 500,
        buttons: {
	        'Done': {
                id: 'edit_properties_dialog_done_button',
                click:  function() { jQuery('#edit_properties_dialog').dialog("close") },
                text: crossI18n.p("cross.ui.done", "Done"),
            }
        },
        autoOpen: false,
        title: crossI18n.p("cross.ui.edit_field_crossing_data", "Edit Field Crossing Data")
    });

    jQuery('#edit_properties_link').click( function() {
        jQuery('#edit_properties_dialog').dialog("open");
        get_properties(get_cross_id(), draw_properties_dialog);
    });

    jQuery('#property_submit').click( function() {
        jQuery('#working').dialog("open");
        check_property(get_cross_id(), jQuery('#properties_select').val(), jQuery('#property_value').val());
        jQuery('#working').dialog("close");
    });

    function draw_properties_dialog(response) {
        // The native endpoint and select share the configured column order.
        // Read the same raw scalar shown by the table; do not reinterpret JSON.
        var column = jQuery('#properties_select').prop('selectedIndex');
        var row = response && Array.isArray(response.data) && response.data[0];
        var value = Array.isArray(row) && column >= 0 ? row[column] : null;
        jQuery('#property_value').val(value == null ? '' : value);
    }

    jQuery('#properties_select').change( function() {
        var value = jQuery('#properties_select').val();
        get_properties(get_cross_id(), draw_properties_dialog);
    });

    function set_properties_select(type) {
        jQuery('#properties_select').val(type);
    }

    function set_property_value(value) {
        jQuery('#property_value').val(value);
    }

    var property_table;
    var property_editor_load_version = 0;
    function get_properties(cross_id, on_loaded){
        var editor_request = typeof on_loaded === 'function' ? ++property_editor_load_version : null;
        var editor_controls = jQuery('#properties_select, #property_value, #property_submit');
        if (editor_request !== null) editor_controls.prop('disabled', true);
        property_table = jQuery('#cross_properties').DataTable({
            language: crossTableLanguage(),
            'ajax': {
                url: '/ajax/cross/properties/'+cross_id,
                headers: crossLocaleHeaders('/ajax/cross/properties/'+cross_id),
                dataSrc: function(response) {
                    if (editor_request !== null && editor_request === property_editor_load_version) on_loaded(response);
                    return response.data;
                },
                complete: function() {
                    if (editor_request !== null && editor_request === property_editor_load_version) editor_controls.prop('disabled', false);
                }
            },
            'paging' : false,
            'searching' : false,
            'bInfo' : false,
            'destroy' : true,
        });
        return;
    }

    function check_property(cross_id, type, value) {
        return jQuery.ajax( {
            url: '/cross/property/check/'+cross_id,
            headers: crossLocaleHeaders('/cross/property/check/'+cross_id),
            data: { 'cross_id' : cross_id, 'type': type, 'value': value },
        }).done( function(response) {
            if (response.error) { alert(response.error); }
            var yes;
            if (response.message) {
                yes = confirm(crossI18n.p('cross.property.continue_confirm', '%{message} Continue? ', {message: response.message}));
                if (yes) {
                    alert(crossI18n.p("cross.ui.saving_it", "Saving it."));
                    save_property(cross_id, type, value);
                }
                else {
                    alert(crossI18n.p("cross.ui.not_saving", "Not saving."));
                }
            }
            if (response.success) {
                save_property(cross_id, type, value);
            }
        }).fail( function() {
            alert(crossI18n.p("cross.ui.the_request_for_checking_the_parameters_failed_please_try_agai", "The request for checking the parameters failed. Please try again."));
        });
    }

    function save_property(cross_id, type, value) {
        return jQuery.ajax( {
            url: '/cross/property/save/'+cross_id,
            headers: crossLocaleHeaders('/cross/property/save/'+cross_id),
            data: { 'cross_id' : cross_id, 'type': type, 'value': value, 'data_type': 'crossing_metadata_json' }
        }).done( function(response) {
            get_properties(get_cross_id());
            save_confirm(response);
        }).fail( function(response, x, y) {
            alert(crossI18n.p("cross.ui.an_error_occurred_saving_the_property", "An error occurred saving the property. ")+y);
        });
    }

    function save_confirm(response) {
        if (response.error) {
            alert(response.error);
            return;
        }
        else {
            alert(crossI18n.p("cross.ui.the_property_was_successfully_saved", "The property was successfully saved."));
        }
    }

    jQuery('#tissue_culture_summary_section_onswitch').click(function(){
        display_summary_table(get_cross_id());
    });

    function display_summary_table(cross_id){
        var summary_table = jQuery('#tissue_culture_summary_table').DataTable({
            language: crossTableLanguage(),
            'ajax': {url: '/ajax/cross/tissue_culture_summary/'+cross_id, headers: crossLocaleHeaders('/ajax/cross/tissue_culture_summary/'+cross_id)},
            'order': false,
        });

        return;
    }

    function display_transactions(cross_id){
        var transaction_table = jQuery('#cross_transactions').DataTable({
            language: crossTableLanguage(),
            'ajax': {url: '/ajax/cross/transactions/'+cross_id, headers: crossLocaleHeaders('/ajax/cross/transactions/'+cross_id)},
        });
        return;
    }

    function display_cross_additional_info(cross_id){
        var additional_info_table = jQuery('#cross_additional_info').DataTable({
            language: crossTableLanguage(),
            'ajax': {url: '/ajax/cross/additional_info/'+cross_id, headers: crossLocaleHeaders('/ajax/cross/additional_info/'+cross_id)},
            'paging' : false,
            'searching' : false,
            'bInfo' : false,
            'destroy' : true,
        });
        return;
    }

    jQuery('#edit_additional_info_dialog').dialog( {
        height: 150,
        width: 500,
        buttons: {
	        'Done': {
                id: 'edit_additional_info_dialog_done_button',
                click:  function() { jQuery('#edit_additional_info_dialog').dialog("close") },
                text: crossI18n.p("cross.ui.done", "Done"),
            }
        },
        autoOpen: false,
        title: crossI18n.p("cross.ui.edit_additional_parent_info", "Edit Additional Parent Info")
    });

    jQuery('#edit_additional_info_link').click( function() {
        jQuery('#edit_additional_info_dialog').dialog("open");
        display_cross_additional_info(get_cross_id(), draw_additional_info_dialog);
    });

    function draw_additional_info_dialog(response) {
        var type = jQuery('#additional_info_select').val();
        var info = response.props[type];
        if (info instanceof Array) {
            for (var n=0; n<info.length; n++) {
                jQuery('#additional_info_value').val(info[n][0]);
            }
        }
        else {
            jQuery('#additional_info_value').val('');
        }
    }

    function set_additional_info_select(type) {
        jQuery('#additional_info_select').val(type);
    }

    function set_additional_info_value(value) {
        jQuery('#additional_info_value').val(value);
    }

    function save_additional_info(cross_id, type, value) {
        return jQuery.ajax( {
            url: '/cross/property/save/'+cross_id,
            headers: crossLocaleHeaders('/cross/property/save/'+cross_id),
            data: { 'cross_id' : cross_id, 'type': type, 'value': value, 'data_type': 'cross_additional_info' }
        }).done( function(response) {
            display_cross_additional_info(get_cross_id());
            save_confirm(response);
        }).fail( function(response, x, y) {
            alert(crossI18n.p("cross.ui.an_error_occurred_saving_the_property", "An error occurred saving the property. ")+y);
        });
    }

    jQuery('#edit_additional_info_submit').click( function() {
        jQuery('#working').dialog("open");
        save_additional_info(get_cross_id(), jQuery('#additional_info_select').val(), jQuery('#additional_info_value').val());
        jQuery('#working').dialog("close");
    });


});
