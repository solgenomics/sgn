
/*

=head1 NAME

CXGN.List - a javascript library to implement the lists on the SGN platform

=head1 DESCRIPTION

There are two important list functions in this library, listed below. All other functions should be considered private and/or deprecated.


* addToListMenu(listMenuDiv, dataDiv)

this function will generate a select of all available lists and allow the content to be added to a list (from a search, etc). The first parameter is the id of the div tag where the menu should be drawn. The second parameter is the div that contains the data to be added. This can be a textfield, a div or span tag, or a multiple select tag.

* pasteListMenu(divName, menuDiv, buttonName)

this will generate an html select box of all the lists, and a "paste" button, to paste into a textarea (typically). The divName is the id of the textarea, the menuDiv is the id where the paste menu should be placed.


Public List object functions

* listSelect(divName, types)

will create an html select with id and name 'divName'. Optionally, a list of types can be specified that will limit the menu to the respective types.

Usage:
You have to instantiate the list object first:

var lo = new CXGN.List(); var s = lo.listSelect('myseldiv', [ 'trials' ]);


* validate(list_id, type, non_interactive)

* transform(list_id, new_type)


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

*/

//JSAN.use('jqueryui');

if (!CXGN) CXGN = function () { };

CXGN.List = function () {
    this.list = [];
};

// Presentation fallback only. Never translate or re-encode stored list data.
function _sgnListFormatSource(source, vars) {
    vars = vars || {};
    return source.replace(/%\{([A-Za-z_][A-Za-z0-9_]*)\}/g, function (marker, name) {
        return Object.prototype.hasOwnProperty.call(vars, name) ? String(vars[name]) : marker;
    });
}

function _sgnListEscapeHTML(value) {
    return String(value).replace(/[&<>"']/g, function (character) {
        return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[character];
    });
}

function _sgnListItemsCaptionHTML() {
    var runtime = window.SGN && window.SGN.i18n;
    return _sgnListEscapeHTML(runtime ? runtime.p('lists.dialog.items', 'List items') : 'List items');
}

function _sgnListValidAddedCount(value) {
    return typeof value === 'number' && isFinite(value) && value >= 0 && Math.floor(value) === value && value <= 9007199254740991;
}

// Carry the page's requested language only to reviewed local List endpoints.
// This is per request; it never changes global AJAX defaults or foreign URLs.
function _sgnListLocaleHeaders(url) {
    try {
        var target = new URL(url, window.location.href);
        var reviewedPath = /^\/list\/(?:available|available_public|exists|new|add\/bulk|add_cross_progeny)$/.test(target.pathname)
            || /^\/list\/type\/[^/]+\/[^/]+$/.test(target.pathname);
        if (target.origin !== window.location.origin || !reviewedPath) return {};
        var runtime = window.SGN && window.SGN.i18n;
        var root = typeof document !== 'undefined' && document.documentElement;
        var requested = root && typeof root.getAttribute === 'function' && root.getAttribute('data-sgn-locale');
        return {'X-SGN-Locale': requested || (runtime && runtime.requestedLocale)
            || (root && root.lang) || (runtime && runtime.locale) || 'en'};
    } catch (error) {
        return {};
    }
}


// Keep track of the rendered lists page number and sort column between refreshes
var render_lists_page = 0;  // first page
var render_lists_order = [[3, "desc"], [2, "desc"]];  // sort by date modified and created, newest first


CXGN.List.prototype = {

    // CXGN::List::Transform Plugin names for list types
    transform_keys: {
        "traits": 'traits_2_trait_ids',
        "locations": 'locations_2_location_ids',
        "trials": 'projects_2_project_ids',
        "breeding_programs": 'projects_2_project_ids',
        "accessions": 'accessions_2_accession_ids',
        "plots": 'plots_2_plot_ids',
        "seedlots": 'stocks_2_stock_ids',
        "crosses": 'stocks_2_stock_ids',
        "genotyping_projects": 'projects_2_project_ids',
        "genotyping_plates": 'projects_2_project_ids'
    },

    // Return the data as a straight list
    //
    getList: function(list_id) {
        var list;

        jQuery.ajax( {
            url: '/list/contents/'+list_id,
            async: false,
            success: function(response) {
                if (response.error) {
                    //document.write(response.error);
                }
                else {
                    list = response;
                }
            },
            error: function(response) {
                alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("lists.get.failed", "An error occurred.") : "An error occurred."));
            }
        });
        return list;

    },


    // this function also returns some metadata about
    // list, namely its type.
    //
    getListData: function(list_id) {
        var list;

        jQuery.ajax( {
            url: '/list/data',
            async: false,
            data: { 'list_id': list_id },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                else {
                    list = response;
                }
            }
        });

        return list;
    },

    getListType: function(list_id) {
        var type;

        jQuery.ajax( {
            url: '/list/type/'+list_id,
            async: false,
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                else {
                    type = response.list_type;
                    return type;
                }
            },
            error: function () {
                alert((window.SGN && SGN.i18n ? SGN.i18n.p('lists.error.cannot_determine_type', 'An error occurred. Cannot determine type. ') : 'An error occurred. Cannot determine type. '));
            }
        });

        return type;
    },

    setListType: function(list_id, type) {
        jQuery.ajax( {
            url: '/list/type/'+list_id+'/'+type,
            headers: _sgnListLocaleHeaders('/list/type/'+list_id+'/'+type),
            async: false,
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                else {
                    //alert('Type of list '+list_id+' set to '+type);
                }
            }
        });
    },


    allListTypes: function() {
        var types;
        jQuery.ajax( {
            url: '/list/alltypes',
            async: false,
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                else {
                    types = response;
                }
            }
        });
        types.sort((a,b) => a[1].toUpperCase().localeCompare(b[1].toUpperCase())); //alphabetize list type options
        return types;
    },

    typesHtmlSelect: function(list_id, html_select_id, selected) {
        var types = this.allListTypes();
        var html = '<select class="form-control" id="'+html_select_id+'" onchange="javascript:changeListType(\''+html_select_id+'\', '+list_id+');" >';
        html += '<option name="null" value="(none)">' + _sgnListEscapeHTML((window.SGN && SGN.i18n ? SGN.i18n.p('lists.render.none_type', '(none)') : '(none)')) + '</option>';
        for (var i=0; i<types.length; i++) {
            var selected_html = '';
            if (types[i][1] == selected) {
                selected_html = ' selected="selected" ';
            }
            html += '<option name="'+_sgnListEscapeHTML(types[i][1])+'" value="'+_sgnListEscapeHTML(types[i][1])+'"'+selected_html+'>'+_sgnListEscapeHTML(types[i][1])+'</option>';
        }
        html += '</select>';
        return html;
    },

    newList: function(name, desc) {
        var listNewI18n = (window.SGN && window.SGN.i18n) || {
            p: function (context, source, vars) { return _sgnListFormatSource(source, vars); }
        };
        var oldListId = this.existsList(name);
        var newListId = 0;

        if (name == '') {
            alert(listNewI18n.p('lists.new.name_required', 'Please provide a name for the new list.'));
            return 0;
        }
        if (oldListId === undefined) return 0;

        if (oldListId === null) {
            jQuery.ajax( {
                url: '/list/new',
                headers: _sgnListLocaleHeaders('/list/new'),
                async: false,
                data: { 'name': name, 'desc': desc },
                success: function(response) {
                    if (response.error) {
                        alert(response.error);
                    }
                    else {
                        newListId=response.list_id;
                    }
                },
                error: function() {
                    alert(listNewI18n.p('lists.new.failed', 'An error occurred. Cannot create new list right now.'));
                }
            });
            return newListId;
        }
        else {
            alert(listNewI18n.p('lists.new.name_exists', 'A list with name "%{name}" already exists. Please choose another list name.', {name: name}));
            return 0;
        }
    },

    availableLists: function(list_type) {
        var listLoadI18n = (window.SGN && window.SGN.i18n) || {
            p: function (context, source, vars) { return _sgnListFormatSource(source, vars); }
        };
        var lists = [];
        jQuery.ajax( {
            url: '/list/available',
            headers: _sgnListLocaleHeaders('/list/available'),
            data: { 'type': list_type },
            async: false,
            success: function(response) {
                if (response.error) {
                    //alert(response.error);  //do not alert here
                }
                lists = response;
            },
            error: function(response) {
                alert(listLoadI18n.p('lists.load.failed', 'An error occurred. Cannot load lists.'));
            }
        });
        return lists;
    },

    publicLists: function(list_type) {
        var listLoadI18n = (window.SGN && window.SGN.i18n) || {
            p: function (context, source, vars) { return _sgnListFormatSource(source, vars); }
        };
        var lists = [];
        jQuery.ajax( {
            url: '/list/available_public',
            headers: _sgnListLocaleHeaders('/list/available_public'),
            data: { 'type': list_type },
            async: false,
            success: function(response) {
                if (response.error) {
                    //alert(response.error); //do not alert here
                }
                lists = response;
            },
            error: function(response) {
                alert(listLoadI18n.p('lists.load.failed', 'An error occurred. Cannot load lists.'));
            }
        });
        return lists;
    },

    compareLists: function(list_ids) {
        return jQuery.ajax({
            url: '/list/compare',
            data: { 'list_ids': list_ids.join(',') },
            method: 'GET',
            success: function(response){
                if (response.error) {
                    alert(response.error);
                }
            }
        });
    },


    //return the newly created list_item_id or 0 if nothing was added
    //(due to duplicates)
    addItem: function(list_id, item) {
        var exists_item_id = this.existsItem(list_id,item);
        if (exists_item_id ===0 ) {
            jQuery.ajax( {
                async: false,
                url: '/list/item/add',
                data:  { 'list_id': list_id, 'element': item },
                success: function(response) {
                    if (response.error) {
                        alert(response.error);
                        return 0;
                    }
                }
            });
            var new_list_item_id = this.existsItem(list_id,item);
            return new_list_item_id;
        }
        else { return 0; }
    },

    addBulk: function(list_id, items) {
        var listBulkI18n = (window.SGN && window.SGN.i18n) || {
            p: function (context, source, vars) { return _sgnListFormatSource(source, vars); },
            np: function (context, singular, plural, count, vars) { return _sgnListFormatSource(count === 1 ? singular : plural, vars); }
        };
        var elements = items.join("\t");

        var count;
        jQuery.ajax( {
            async: false,
            method: 'POST',
            url: '/list/add/bulk',
            headers: _sgnListLocaleHeaders('/list/add/bulk'),
            data:  { 'list_id': list_id, 'elements': elements },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                else {
                    if (response.duplicates) {
                        // Native newline input can include an empty last item.
                        // Omit only that empty display item, leaving API data intact.
                        var duplicateNames = response.duplicates.filter(function (name) { return name !== ''; });
                        if (duplicateNames.length) alert(listBulkI18n.np('lists.bulk.duplicates',
                            'The following item is already in the list and was not added: %{items}.',
                            'The following items are already in the list and were not added: %{items}.',
                            duplicateNames.length, {items: duplicateNames.join(', ')}));
                    }
                    count = response.success;
                }
            },
            error: function(response) {
                alert(listBulkI18n.p('lists.bulk.failed', 'An error occurred. Cannot add items to the list.'));
            }
        });
        return count;
    },

    removeItem: function(list_id, item_id) {
        jQuery.ajax( {
            async: false,
            url: '/list/item/remove',
            data: { 'list_id': list_id, 'item_id': item_id }
        });
    },

    updateItem: function(list_id, item_id, content) {
        var trimmed_content = content.trim();
        jQuery.ajax( {
            async: false,
            url: '/list/item/update',
            data: { 'list_id': list_id, 'item_id': item_id, 'content': trimmed_content }
        });
    },

    deleteList: function(list_id) {
        jQuery.ajax( {
            url: '/list/delete',
            async: false,
            data: { 'list_id': list_id }
        });
    },

    renderLists: function(div) {
        var listRenderI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        var type = jQuery('#render_lists_type').val();
        var autocreated = jQuery("#render_lists_autocreated").is(":checked");
        var lists = this.availableLists();
        var types = this.allListTypes();

        var html = '';
        html = html + '<div class="well well-sm"><form class="form-horizontal"><div class="form-group form-group-sm"><label class="col-sm-3 control-label">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.create_list_label', 'Create New List: ')) + '</label><div class="col-sm-9"><div class="input-group"><input id="add_list_input" type="text" class="form-control" placeholder="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.new_list_name_placeholder', 'Create New List. Type New List Name Here')) + '" /><span class="input-group-btn"><button class="btn btn-primary btn-sm" type="button" id="add_list_button" value="new list">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.new_list_button', 'New List')) + '</button></span></div></div></div><div class="form-group form-group-sm"><label class="col-sm-3 control-label"></label><div class="col-sm-9">';
        html = html + '<input id="add_list_input_description" type="text" class="form-control" placeholder="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.new_list_description_placeholder', 'Description For New List')) + '" /></div></div></form></div>';

        if (lists.length===0) {
            html = html + _sgnListEscapeHTML(listRenderI18n.p('lists.render.none', 'None'));
            jQuery('#'+div+'_div').html(html);
        }

        // List Table Container
        html += "<div class='well'>";

        // Table Header
        html += "<div style='display: flex; flex-wrap: wrap; column-gap: 30px; justify-content: space-between; margin-bottom: 15px'>";

        // Filter Container
        html += "<div style='display: flex; flex-direction: column; row-gap: 15px'>"

        // Filter by List Type
        html += "<div style='display: flex; align-items: baseline; column-gap: 15px;'>"
        html += "<p style='white-space: nowrap'><strong>" + _sgnListEscapeHTML(listRenderI18n.p('lists.render.filter_lists_by_type', 'Filter Lists by Type')) + "</strong>:</p>";
        html += "<select id='render_lists_type' class='render_lists_filter form-control' style='max-width: 200px'>";
        html += "<option value=''>" + _sgnListEscapeHTML(listRenderI18n.p('lists.render.any_type', 'Any')) + "</option>";
        for ( let i = 0; i < types.length; i++ ) {
            let selected = type && type === types[i][1] ? 'selected' : '';
            html += "<option value='" + types[i][1] + "' " + selected + ">"+types[i][1]+"</option>";
        }
        html += "</select>";
        html += "</div>";

        // Autocreated filter
        html += "<div style='display: flex; align-items: baseline; column-gap: 15px;'>";
        html += "<p style='white-space: nowrap'><strong>" + _sgnListEscapeHTML(listRenderI18n.p('lists.render.include_autocreated', 'Include Autocreated Lists')) + "</strong>:</p>";
        let checked = autocreated ? 'checked' : ''
        html += "<input id='render_lists_autocreated' class='render_lists_filter' type='checkbox' " + checked + " />";
        html += "</div>";

        // End Filter Container
        html += "</div>";

        // Multiple List Container
        html += "<div id='list_group_select_action' style='flex-grow: 1; width: min-content; min-width: 500px;'></div>";

        // End Header
        html += "</div>";

        // List Table
        html += '<table id="private_list_data_table" class="table table-hover table-condensed">';
        html += '<thead><tr><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.list_name', 'List Name')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.description', 'Description')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.date_created', 'Date Created')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.date_modified', 'Date Modified')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.count', 'Count')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.type', 'Type')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.validate', 'Validate')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.view', 'View')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.delete', 'Delete')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.download', 'Download')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.share', 'Share')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.header.group', 'Group')) + '</th></tr></thead><tbody>';
        for (var i = 0; i < lists.length; i++) {
            if ( (!type || type === lists[i][5]) && (autocreated || !(lists[i][2] || '').startsWith("Autocreated")) ) {
                html += '<tr><td><a href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')"><b>'+lists[i][1]+'</b></a></td>';
                html += '<td>'+(lists[i][2] ? lists[i][2] : '')+'</td>';
                html += '<td>'+(lists[i][7] ? new Date(lists[i][7]).toLocaleDateString('en-CA') : '')+'</td>';
                html += '<td>'+(lists[i][8] ? new Date(lists[i][8]).toLocaleDateString('en-CA') : '')+'</td>';
                html += '<td>'+(lists[i][3] ? lists[i][3] : '0')+'</td>';
                html += '<td>'+(lists[i][5] ? lists[i][5] : '&lt;NOT SET&gt;')+'</td>';
                html += '<td><a onclick="javascript:validateList(\''+lists[i][0]+'\',\''+lists[i][5]+'\')"><span class="glyphicon glyphicon-ok"></span></a></td>';
                html += '<td><a title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.view', 'View')) + '" id="view_list_'+lists[i][1]+'" href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></span></td>';
                html += '<td><a title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.delete', 'Delete')) + '" id="delete_list_'+lists[i][1]+'" href="javascript:deleteList('+lists[i][0]+')"><span class="glyphicon glyphicon-remove"></span></a></td>';
                html += '<td><a target="_blank" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.download', 'Download')) + '" id="download_list_'+lists[i][1]+'" href="/list/download?list_id='+lists[i][0]+'"><span class="glyphicon glyphicon-arrow-down"></span></a></td>';
                if (lists[i][6] == 0){
                    html += '<td><a title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.make_public', 'Make Public')) + '" id="share_list_'+lists[i][1]+'" href="javascript:togglePublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-share-alt"></span></a></td>';
                } else if (lists[i][6] == 1){
                    html += '<td><a title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.make_private', 'Make Private')) + '" id="share_list_'+lists[i][1]+'" href="javascript:togglePublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-ban-circle"></span></a></td>';
                }
                html += '<td><input type="checkbox" id="list_select_checkbox_'+lists[i][0]+'" name="list_select_checkbox" value="'+lists[i][0]+'"/></td></tr>';
            }
        }
        html += '</tbody></table>';
        html += '</div>';

        jQuery('#'+div+'_div').html(html);

        var table = jQuery('#private_list_data_table').DataTable({
            "destroy": true,
            "columnDefs": [{ "orderable": false, "targets": [6,7,8,9,10,11] }],
            "order": render_lists_order
        });
        table.page(render_lists_page).draw('page');
        table.on('order', () => render_lists_order = table.order());
        table.on('page', () => render_lists_page = table.page.info().page);

        jQuery('#add_list_button').click(function() {
            var lo = new CXGN.List();

            var name = jQuery('#add_list_input').val();
            var description = jQuery('#add_list_input_description').val();

            lo.newList(name, description);
            lo.renderLists(div);
        });

        jQuery('#view_public_lists_button').click(function() {
            jQuery('#public_list_dialog').modal('show');
            var lo = new CXGN.List();
            lo.renderPublicLists('public_list_dialog_div');
        });

        function render_selected_lists_container() {
            var total=jQuery("input[name='list_select_checkbox']:checked").length;
            var list_group_select_action_html='';
            if (total > 1) {
                var selected = [];
                jQuery("input[name='list_select_checkbox']:checked").each(function() {
                    selected.push(jQuery(this).attr('value'));
                });

                // Delete / Public / Private Functions
                list_group_select_action_html += '<div class="row">';
                list_group_select_action_html += '<div class="col-sm-4"><p><strong>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.modify_selected_lists', 'Modify Selected Lists:')) + '</strong></p></div>';
                list_group_select_action_html += '<div class="col-sm-8">';
                var compare_disabled = (total === 2)? '' : 'disabled style="opacity:0.6;cursor:not-allowed;"';
                list_group_select_action_html += '<a id="delete_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:deleteSelectedListGroup(['+selected+'])">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.delete', 'Delete')) + '</a>&nbsp;<a id="make_public_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:makePublicSelectedListGroup(['+selected+'])">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.make_public', 'Make Public')) + '</a>&nbsp;<a id="make_private_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:makePrivateSelectedListGroup(['+selected+'])">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.make_private', 'Make Private')) + '</a>&nbsp<a id="compare_selected_list_group" class="btn btn-primary btn-sm" style="color:white" '+compare_disabled+' href="javascript:createThreeColumnDiff(['+selected+'])">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.compare_selected_lists', 'Compare Selected Lists')) + '</a>';
                list_group_select_action_html += '</div>';  // end column
                list_group_select_action_html += '</div>';  // end row

                // Union / Intersection Icons
                var unionIcon = '<svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" viewBox="0 0 256 256"><path fill="currentColor" d="M172.91 83.09a78 78 0 1 0-89.82 89.82a78 78 0 1 0 89.82-89.82M226 160a65 65 0 0 1-.62 8.9l-53.76-53.77A77.8 77.8 0 0 0 174 96v-.49A66.1 66.1 0 0 1 226 160M45.31 53.79l55.5 55.5a77.9 77.9 0 0 0-12 19L34 73.48a66 66 0 0 1 11.31-19.69m88.92 96l-28-28a66.5 66.5 0 0 1 15.52-15.52l28 28a66.5 66.5 0 0 1-15.52 15.48ZM162 96a65.6 65.6 0 0 1-6 27.49L132.51 100A65.6 65.6 0 0 1 160 94h1.95c.05.7.05 1.35.05 2m-52.71 4.81l-55.5-55.5A66 66 0 0 1 73.48 34l54.8 54.81a77.9 77.9 0 0 0-18.99 12M94 160a65.6 65.6 0 0 1 6-27.49L123.49 156A65.6 65.6 0 0 1 96 162c-.65 0-1.3 0-2-.05zm52.71-4.81l55.5 55.5A66 66 0 0 1 182.52 222l-54.8-54.81a77.9 77.9 0 0 0 18.99-12m8.48-8.48a77.9 77.9 0 0 0 12-19L222 182.52a66 66 0 0 1-11.35 19.69Zm5.3-64.7H160a77.8 77.8 0 0 0-19.13 2.38L87.1 30.62A65 65 0 0 1 96 30a66.1 66.1 0 0 1 64.49 52ZM30 96a65 65 0 0 1 .62-8.9l53.76 53.77A77.8 77.8 0 0 0 82 160v.49A66.1 66.1 0 0 1 30 96m65.51 78H96a77.8 77.8 0 0 0 19.13-2.38l53.77 53.76a65 65 0 0 1-8.9.62a66.1 66.1 0 0 1-64.49-52"/></svg>';
                var intersectionIcon = '<svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" viewBox="0 0 256 256"><path fill="currentColor" d="M174.63 81.37a80 80 0 1 0-93.26 93.26a80 80 0 1 0 93.26-93.26M100.69 136L120 155.31A63.5 63.5 0 0 1 96 160a63.5 63.5 0 0 1 4.69-24m33.75 11.13l-25.57-25.57a64.7 64.7 0 0 1 12.69-12.69l25.57 25.57a64.7 64.7 0 0 1-12.69 12.69M155.31 120L136 100.69A63.5 63.5 0 0 1 160 96a63.5 63.5 0 0 1-4.69 24M32 96a64 64 0 0 1 126-16a80.08 80.08 0 0 0-77.95 78A64.11 64.11 0 0 1 32 96m128 128a64.11 64.11 0 0 1-62-48a80.08 80.08 0 0 0 78-78a64 64 0 0 1-16 126"/></svg>';

                // Union / Intersection Functions
                list_group_select_action_html += '<div class="row" style="margin-top: 15px">';
                list_group_select_action_html += '<div class="col-sm-4"><p><strong>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.combine_selected_lists', 'Combine List Items From Selected Lists to a New List:')) + '</strong></p></div>';
                list_group_select_action_html += '<div class="col-sm-8">';
                list_group_select_action_html += '<div class="input-group input-group-sm">'
                list_group_select_action_html += '<input type="text" class="form-control" id="new_combined_list_name" placeholder="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.combined_list_name', 'New List Name')) + '"><span class="input-group-btn">';
                list_group_select_action_html += '<button id="combine_selected_list_group_union" class="btn btn-primary btn-sm" style="color:white; display: inline-flex; align-items: center; gap: 5px;" onclick="javascript:combineSelectedListGroup(['+selected+'], \'union\')">' + unionIcon + _sgnListEscapeHTML(listRenderI18n.p('lists.render.union', 'Union')) + '</button>';
                list_group_select_action_html += '<button id="combine_selected_list_group_intersection" class="btn btn-primary btn-sm" style="color:white; display: inline-flex; align-items: center; gap: 5px;" onclick="javascript:combineSelectedListGroup(['+selected+'], \'intersection\')">' + intersectionIcon + _sgnListEscapeHTML(listRenderI18n.p('lists.render.intersection', 'Intersection')) + '</button>';
                list_group_select_action_html += '</input></span>';
                list_group_select_action_html += '</div>';  // End input group
                list_group_select_action_html += '</div>';  // end column
                list_group_select_action_html += '</div>';  // end row
            }
            else {
                list_group_select_action_html += '<div style="width: 100%; text-align: right">';
                list_group_select_action_html += '<p><em>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.select_multiple_hint', 'Select 2 or more lists in the %{group} column to modify or combine them', {group: '__SGN_GROUP__'})).replace('__SGN_GROUP__', '<strong>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.group', 'Group')) + '</strong>') + '</em></p>';
                list_group_select_action_html += '</div>';
            }
            jQuery("#list_group_select_action").html(list_group_select_action_html);
        }
        jQuery('body').on("click", "input[name='list_select_checkbox']", render_selected_lists_container);
        render_selected_lists_container();

        jQuery('#compare_selected_lists').off('click').on('click', function() {
            if (selected.length === 2) {
                createThreeColumnDiff(selected[0], selected[1]);
            }
        });

        jQuery(".render_lists_filter").on("change", function() {
            render_lists_page = 0;
            var lo = new CXGN.List();
            lo.renderLists('list_dialog');
        });
    },

    renderPublicLists: function(div) {
        var listRenderI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        var lists = this.publicLists();
        var html = '';

        html += '<table id="public_list_data_table" class="table table-hover table-condensed">';
        html += '<thead><tr><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.list_name', 'List Name')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.description', 'Description')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.date_created', 'Date Created')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.date_modified', 'Date Modified')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.count', 'Count')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.type', 'Type')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.validate', 'Validate')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.view', 'View')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.download', 'Download')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.copy', 'Copy To Your Lists')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.owner', 'Owner')) + '</th><th>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.public_header.make_private', 'Make Private')) + '</th></tr></thead><tbody>';
        for (var i = 0; i < lists.length; i++) {
            html += '<tr>';
            html += '<td><a href="javascript:showPublicListItems(\'list_item_dialog\','+lists[i][0]+')"><b>'+lists[i][1]+'</b></a></td>';
            html += '<td>'+lists[i][2]+'</td>';
            html += '<td>'+lists[i][7]+'</td>';
            html += '<td>'+lists[i][8]+'</td>';
            html += '<td>'+lists[i][3]+'</td>';
            html += '<td>'+lists[i][5]+'</td>';
            html += '<td><a onclick="(new CXGN.List()).validate(\''+lists[i][0]+'\',\''+lists[i][5]+'\')"><span class="glyphicon glyphicon-ok"></span></a></td>';
            html += '<td><a title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.view', 'View')) + '" id="view_public_list_'+lists[i][1]+'" href="javascript:showPublicListItems(\'list_item_dialog\','+lists[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></a></td>';
            html += '<td><a target="_blank" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.download', 'Download')) + '" id="download_public_list_'+lists[i][1]+'" href="/list/download?list_id='+lists[i][0]+'"><span class="glyphicon glyphicon-arrow-down"></span></a></td>';
            html += '<td><a title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.copy_to_your_lists', 'Copy to Your Lists')) + '" id="copy_public_list_'+lists[i][1]+'" href="javascript:copyPublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-plus"></span></a></td>';
            html += '<td>'+lists[i][6]+'</td>';
            html += '<td><a title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.action.make_private', 'Make Private')) + '" href="javascript:togglePublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-ban-circle"></span></a></td>';
            html += '</tr>';
        }
        html = html + '</tbody></table>';

        jQuery('#'+div).html(html);

        jQuery('#public_list_data_table').DataTable({
            "destroy": true,
            "columnDefs": [   { "orderable": false, "targets": [3,4,5,6] }  ]
        });
    },

    listNameById: function(list_id) {
        lists = this.availableLists();
        for (var n=0; n<lists.length; n++) {
            if (lists[n][0] == list_id) { return lists[n][1]; }
        }
    },

    publicListNameById: function(list_id) {
        lists = this.publicLists();
        for (var n=0; n<lists.length; n++) {
            if (lists[n][0] == list_id) { return lists[n][1]; }
        }
    },

    renderItems: function(div, list_id) {
        var listRenderI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };

        var list_data = this.getListData(list_id);
        var list_description = list_data.description;
        var items = list_data.elements;
        var list_type = list_data.type_name;
        var list_name = this.listNameById(list_id);
        var type_select_id = 'type_select';
        var html = '';
        var enable_details_link = !!this.getListItemUrl(list_type);

        if (list_type == 'catalog_items') {
            html += '<div class="well well-sm"><table id="list_cart_item_dialog_datatable" class="table table-condensed table-hover table-bordered"><thead style="display: none;"><tr><th><b>'+_sgnListItemsCaptionHTML()+'</b> ('+items.length+')</th><th>&nbsp;</th></tr></thead><tbody>';

            for(var n=0; n<items.length; n++) {
                html = html +'<tr><td>'+ items[n][1] + '</td><td><input id="'+items[n][0]+'" type="button" class="btn btn-default btn-xs" value="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.remove', 'Remove')) + '" /></td></tr>';
            }
            html += '</tbody></table></div>';
            jQuery('#'+div+'_div').html(html);

            jQuery('#list_cart_item_dialog_datatable').DataTable({
                destroy: true,
                ordering: false,
                scrollY:        '30vh',
                scrollCollapse: true,
                paging:         false,
            });

        } else {
        html += '<table class="table">';
        if (list_type == 'seedlots') {
            html += '<a href="/list/details?list_id='+list_id+'">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.details_page', 'Go to List Details Page')) + '</a>';
        }
        html += '<tr><td>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.list_id', 'List ID')) + '</td><td id="list_id_div">'+list_id+'</td></tr>'
        html += '<tr><td>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.list_name', 'List name:')) + '<br/><input type="button" class="btn btn-primary btn-xs" id="updateNameButton" value="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.update', 'Update')) + '" /></td>';
        html += '<td><input class="form-control" type="text" id="updateNameField" size="10" value="'+list_name+'" /></td></tr>';
        html += '<tr><td>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.description', 'Description:')) + '<br/><input type="button" class="btn btn-primary btn-xs" id="updateListDescButton" value="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.update', 'Update')) + '" /></td>';
        html += '<td><input class="form-control" type="text" id="updateListDescField" size="10" value="'+list_description+'" /></td></tr>';
        html += '<tr><td>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.type', 'Type:')) + '<br/><input id="list_item_dialog_validate" type="button" class="btn btn-primary btn-xs" value="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.validate', 'Validate')) + '" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.validate_title', 'Validate list. Checks if elements exist with the selected type.')) + '"/><div id="fuzzySearchStockListDiv"></div><div id="synonymListButtonDiv"></div><div id="availableSeedlotButtonDiv"></div></td><td>'+this.typesHtmlSelect(list_id, 'type_select', list_type)+'</td></tr>';
        html += '<tr><td>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.add_new_items', 'Add New Items:')) + '<br/><button class="btn btn-primary btn-xs" type="button" id="dialog_add_list_item_button" value="Add">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.add', 'Add')) + '</button></td><td><textarea id="dialog_add_list_item" type="text" class="form-control" placeholder="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.add_items_placeholder', 'Add Item(s) To List. Separate items using a new line to add many items at once.')) + '" /></textarea><p style="font-size:80%;text-align:right">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.revalidate_note', 'After adding new items, you may want to consider re-validating your list.')) + '</p></td></tr></table>';

        html += '<hr><div class="well well-sm"><div class="row"><div class="col-sm-4"><center><button class="btn btn-default" onclick="(new CXGN.List()).sortItems('+list_id+', \'ASC\')" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.sort_ascending_title', 'Sort items in list in ascending order (e.g. A->Z and/or 0->9)')) + '">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.sort_ascending', 'Sort Ascending')) + ' <span class="glyphicon glyphicon-sort-by-alphabet"></span></button></center></div><div class="col-sm-4"><center><button class="btn btn-default" onclick="(new CXGN.List()).sortItems('+list_id+', \'DESC\')" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.sort_descending_title', 'Sort items in list in descending order (e.g. Z->A and/or 9->0)')) + '">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.sort_descending', 'Sort Descending')) + ' <span class="glyphicon glyphicon-sort-by-alphabet-alt"></span></button></center></div><div class="col-sm-4"><center><button class="btn btn-default type="button" id="copy_items_button" value="Copy">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.copy_item_names', 'Copy Item Names')) + '</button></center></div></div></div>';
        html += '<div class="well well-sm"><table id="list_item_dialog_datatable" class="table table-condensed table-hover table-bordered"><thead style="display: none;"><tr><th><b>'+_sgnListItemsCaptionHTML()+'</b> ('+items.length+')</th><th>&nbsp;</th></tr></thead><tbody>';

        for(var n=0; n<items.length; n++) {
            html = html +'<tr>';
            html += '<td id="list_item_toggle_edit_div_'+items[n][0]+'" >';
            html += '<div name="list_item_toggle_edit" data-listitemdiv="list_item_toggle_edit_div_'+items[n][0]+'" data-listitemid="'+items[n][0]+'" data-listitemname="'+items[n][1]+'" >'+ items[n][1] + '</div>';
            html += '</td>'
            html += '<td>';
            html += '<span data-list-item-id="'+items[n][0]+'" class="list_item_remove btn btn-danger btn-xs"><span class="glyphicon glyphicon-trash"></span>&nbsp;&nbsp;' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.remove', 'Remove')) + '</span>'
            if ( enable_details_link ) html += '<span data-list-item-name="'+items[n][1]+'" class="list_item_details btn btn-default btn-xs" style="margin-left: 15px"><span class="glyphicon glyphicon-new-window"></span>&nbsp;&nbsp;' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.details', 'Details')) + '</span>';
            html += '</td>';
            html += '</tr>';
        }
        html += '</tbody></table></div>';

        jQuery('#'+div+'_div').html(html);

        var listTable = jQuery('#list_item_dialog_datatable').DataTable({
            destroy: true,
            ordering: false,
            scrollY:        '30vh',
            scrollCollapse: true,
            paging:         false,
        });

        jQuery('#copy_items_button').on('click', function () {
            var columnData = listTable.column(0, { search: 'applied' }).data().toArray().map(function (cell) {return jQuery('<div>').html(cell).text().trim();});
            console.log("column data", columnData);
            var textToCopy = columnData.join('\n');

            navigator.clipboard.writeText(textToCopy).then(function () {
                alert(listRenderI18n.p('lists.render.item_names_copied', 'Item names copied'));
            }).catch(function (err) {
                console.error('Copy failed', err);
            });
        });

        }

        if (list_type == 'accessions' || list_type == 'crosses'){
            jQuery('#availableSeedlotButtonDiv').html('<br/><button id="availableSeedlotButton" class="btn btn-primary btn-xs" onclick="(new CXGN.List()).seedlotSearch('+list_id+')" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.available_seedlots_title', 'Will display seedlots that have contents of an item in your list.')) + '">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.available_seedlots', 'See Available Seedlots')) + '</button>');
        }
        if (['seedlots', 'plots', 'accessions', 'vector_constructs', 'crosses', 'populations', 'plants', 'tissue_samples', 'family_names'].indexOf(list_type) >= 0){
            jQuery('#synonymListButtonDiv').html('<br/><button id="synonymListButton" class="btn btn-primary btn-xs" onclick="(new CXGN.List()).synonymSearch('+list_id+')" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.find_synonyms_title', 'Will display whether the items in your list are synonyms or actual uniquenames.')) + '">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.find_synonyms', 'Find Synonyms')) + '</button>');
            jQuery('#fuzzySearchStockListDiv').html('<br/><button id="fuzzySearchStockListButton" class="btn btn-primary btn-xs" onclick="javascript: working_modal_show(); fuzzySearchList('+list_id+',\''+list_type+'\')" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.fuzzy_search_title', 'Will display if the items in your list are uniquenames in the database or whether they look very similar to other accessions in the database.')) + '">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.fuzzy_search', 'Fuzzy Search')) + '</button>');
        }
        jQuery(document).on("change", "#type_select", function(){
            if (jQuery('#type_select').val() == 'accessions' || jQuery('#type_select').val() == 'crosses'){
                jQuery('#availableSeedlotButtonDiv').html('<br/><button id="availableSeedlotButton" class="btn btn-primary btn-xs" onclick="(new CXGN.List()).seedlotSearch('+list_id+')" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.available_seedlots_title', 'Will display seedlots that have contents of an item in your list.')) + '">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.available_seedlots', 'See Available Seedlots')) + '</button>');
            } else {
                jQuery('#availableSeedlotButtonDiv').html('');
            }

            if (['seedlots', 'plots', 'accessions', 'vector_constructs', 'crosses', 'populations', 'plants', 'tissue_samples', 'family_names'].indexOf(jQuery('#type_select').val()) >= 0){
                jQuery('#synonymListButtonDiv').html('<br/><button id="synonymListButton" class="btn btn-primary btn-xs" onclick="(new CXGN.List()).synonymSearch('+list_id+')" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.find_synonyms_title', 'Will display whether the items in your list are synonyms or actual uniquenames.')) + '">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.find_synonyms', 'Find Synonyms')) + '</button>');
                jQuery('#fuzzySearchStockListDiv').html('<br/><button id="fuzzySearchStockListButton" class="btn btn-primary btn-xs" onclick="javascript: working_modal_show(); fuzzySearchList('+list_id+',\''+jQuery('#type_select').val()+'\')" title="' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.fuzzy_search_title', 'Will display if the items in your list are uniquenames in the database or whether they look very similar to other accessions in the database.')) + '">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.fuzzy_search', 'Fuzzy Search')) + '</button>');
            } else {
                jQuery('#synonymListButtonDiv').html('');
                jQuery('#fuzzySearchStockListDiv').html('');
            }
        });

        jQuery('.list_item_remove').click( function() {
            var id = jQuery(this).data("list-item-id");
            jQuery(this).attr("disabled", true);

            var lo = new CXGN.List();
            lo.removeItem(list_id, id);
            lo.renderItems(div, list_id);
            lo.renderLists('list_dialog');
        });
        jQuery('.list_item_details').click( function() {
            var el = this;
            var name = jQuery(el).data("list-item-name");
            jQuery(el).attr("disabled", true);

            var lo = new CXGN.List();
            lo.getListItemDbId(list_type, name).then((list_item_db_id) => {
                jQuery(el).attr("disabled", false);
                var url = lo.getListItemUrl(list_type, list_item_db_id);
                window.open(url, '_blank');
            }).catch((err) => {
                alert(err);
            });
        });

        jQuery('#dialog_add_list_item_button').click( function() {
            addMultipleItemsToList('dialog_add_list_item', list_id);
            var lo = new CXGN.List();
            lo.renderItems(div, list_id);
        });

        jQuery('#updateNameButton').click( function() {
            var lo = new CXGN.List();
            var new_name =  jQuery('#updateNameField').val();
            var list_id = jQuery('#list_id_div').html();
            lo.updateName(list_id, new_name);
        });

        jQuery('#updateListDescButton').click( function() {
            var lo = new CXGN.List();
            var new_desc =  jQuery('#updateListDescField').val();
            var list_id = jQuery('#list_id_div').html();
            lo.updateDescription(list_id, new_desc);
        });

        jQuery('#list_item_dialog_validate').click( function() {
            if (jQuery('#dialog_add_list_item').val()) {
                if (confirm(listRenderI18n.p('lists.render.confirm_validate_unadded_items', "There is content in the 'Add New Items' field that has not yet been added to the list. Do you want to proceed with validation?"))) {
                    validateList(list_id,undefined,type_select_id);
                }
            } else {
                validateList(list_id,undefined,type_select_id);
            }
        });

        jQuery('div[name="list_item_toggle_edit"]').click(function() {
            var list_item_id = jQuery(this).data('listitemid');
            var list_item_name = jQuery(this).data('listitemname');
            var list_item_div = jQuery(this).data('listitemdiv');
            var list_item_edit_html = '<div class="input-group"><input type="text" class="form-control" value="'+list_item_name+'" placeholder="'+list_item_name+'" id="list_item_edit_input_'+list_item_id+'" data-listitemid="'+list_item_id+'" /><span class="input-group-btn"><button class="btn btn-default" type="button" name="list_item_edit_submit" data-inputid="list_item_edit_input_'+list_item_id+'">' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.ok', 'Ok')) + '</button></span></div>';
            jQuery("#"+list_item_div).empty().html(list_item_edit_html);
        });

        jQuery(document).on('click', 'button[name="list_item_edit_submit"]', function() {
            var lo = new CXGN.List();
            var list_id = jQuery('#list_id_div').html();
            var input_id = jQuery(this).data('inputid');
            lo.updateItem(list_id, jQuery("#"+input_id).data('listitemid'), jQuery("#"+input_id).val());
            lo.renderItems(div, list_id);
        });

    },

    renderPublicItems: function(div, list_id) {
        var listRenderI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        var list_data = this.getListData(list_id);
        var items = list_data.elements;
        var list_type = list_data.type_name;
        var list_name = this.publicListNameById(list_id);

        var html = '';
        html += '<table class="table"><tr><td>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.list_id', 'List ID')) + '</td><td id="list_id_div">'+list_id+'</td></tr>';
        html += '<tr><td>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.list_name', 'List name:')) + '</td>';
        html += '<td>'+list_name+'</td></tr>';
        html += '<tr><td>' + _sgnListEscapeHTML(listRenderI18n.p('lists.render.type', 'Type:')) + '</td><td>'+list_type+'</td></tr>';
        html += '</table>';
        html += '<table id="public_list_item_dialog_datatable" class="table table-condensed table-hover table-bordered"><thead style="display: none;"><tr><th><b>'+_sgnListItemsCaptionHTML()+'</b> ('+items.length+')</th></tr></thead><tbody>';
        for(var n=0; n<items.length; n++) {
            html = html +'<tr><td>'+ items[n][1] + '</td></tr>';
        }
        html += '</tbody></table>';

        jQuery('#'+div+'_div').html(html);

        jQuery('#public_list_item_dialog_datatable').DataTable({
            destroy: true,
            ordering: false,
            scrollY:        '30vh',
            scrollCollapse: true,
            paging:         false,
        });
    },

    existsList: function(name) {
        var listExistsI18n = (window.SGN && window.SGN.i18n) || {
            p: function (context, source, vars) { return _sgnListFormatSource(source, vars); }
        };
        var list_id;
        jQuery.ajax( {
            url: '/list/exists',
            headers: _sgnListLocaleHeaders('/list/exists'),
            async: false,
            data: { 'name': name },
            success: function(response) {
                if (response.error) alert(response.error);
                else list_id = response.list_id;
            },
            error: function() {
                alert(listExistsI18n.p('lists.exists.failed', 'An error occurred. Cannot check whether the list exists.'));
            }
        });
        return list_id;
    },

    existsItem: function(list_id, name) {
        var list_item_id =0;
        jQuery.ajax( {
            url: '/list/exists_item',
            async: false,
            data: { 'list_id' : list_id, 'name':name },
            success: function(response) {
                list_item_id = response.list_item_id;
            }
        });
        return list_item_id;
    },

    addToList: function(list_id, text) {
        if (! text) {
            var listAddI18n = (window.SGN && window.SGN.i18n) || {
                p: function (context, source, vars) { return _sgnListFormatSource(source, vars); }
            };
            alert(listAddI18n.p('lists.copy.no_items', 'There are no items to add to the list.'));
            return;
        }
        var list = text.split("\n");
        var duplicates = [];

        var info = this.addBulk(list_id, list);

        return info;
    },

    addCrossProgenyToList: function(list_id, text) {
        if (! text) {
            return;
        }
        var list = text.split("\n");
        list = list.filter(function(n){ return n != '' });
        //console.log(list);
        var addeditems;
        jQuery.ajax( {
            url: '/list/add_cross_progeny',
            headers: _sgnListLocaleHeaders('/list/add_cross_progeny'),
            async: false,
            data: { 'list_id':list_id, 'cross_id_list' : JSON.stringify(list) },
            success: function(response) {
                //console.log(response);
                addeditems = response.success.count;
            }
        });
        //var info = this.addBulk(list_id, list);

        return addeditems;
    },


    /* getLists: Creates a js object with private and public  lists of the requested list types.

       Parameters:
        types: a list of list types e.g. ['accessions', 'trials']
      Returns:
       a js object with 'private_lists' and public_lists, each with arrays of the requested list types
    */
    getLists: function(types) {
        var lists = new Array();
        var public_lists = new Array();

        if (types) {
            for (var n=0; n<types.length; n++) {
                var more = this.availableLists(types[n]);
                var more_public_lists = this.publicLists(types[n]);
                if (more) {
                    for (var i=0; i<more.length; i++) {
                        lists.push(more[i]);
                    }
                }
                if (more_public_lists) {
                    for (var i=0; i<more_public_lists.length; i++) {
                        public_lists.push(more_public_lists[i]);
                    }
                }
            }
        }
        else {
            lists = this.availableLists();
            public_lists = this.publicLists();
        }

        return {
            'private_lists': lists,
            'public_lists': public_lists
        }
    },

    /*
    converts an array of list data arrays into an array of list data objects (named values)
    */
    convertArrayToJson: function (listsArray) {

        var jsonArray = [];
        if (listsArray) {
            listsArray.forEach(function (array) {

                var listObj = {
                    id: array[0],
                    name: array[1],
                    type:array[5],
                    count: array[3]
                }

                jsonArray.push(listObj);
            });
        }

        return jsonArray;
    },

    /* listSelect: Creates an html select with lists of requested types.

       Parameters:
         div_name: The div_name where the select should appear
         types: a list of list types that should be listed in the menu
         add_empty_element: text. if present, add an empty element with the
           provided text as description
    */

    listSelect: function(div_name, types, empty_element, refresh, hide_public_lists) {

        // The selector owns escaping for caller labels and original list names.
        // Optional translation assets must never block native list selection.
        var listSelectI18n = (window.SGN && window.SGN.i18n) || {
            p: function (context, source) { return source; }
        };
        function escapeListSelectHTML(value) {
            return String(value).replace(/[&<>"']/g, function (character) {
                return {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'}[character];
            });
        }
        var allLists = this.getLists(types);
        var lists = allLists.private_lists;
        var public_lists = allLists.public_lists;

        var html = '<select class="form-control input-sm" id="'+escapeListSelectHTML(div_name)+'_list_select" name="'+escapeListSelectHTML(div_name)+'_list_select" >';
        if (empty_element) {
            html += '<option value="" >'+escapeListSelectHTML(empty_element)+'</option>\n';
        }
        html += '<option disabled value="--------YOUR LISTS BELOW--------">'+escapeListSelectHTML(listSelectI18n.p('lists.selector.private_group', '--------YOUR LISTS BELOW--------'))+'</option>';
        for (var n=0; n<lists.length; n++) {
            html += '<option value="'+escapeListSelectHTML(lists[n][0])+'">'+escapeListSelectHTML(lists[n][1])+'</option>';
        }
        if (hide_public_lists == undefined) {
            html += '<option disabled value="--------PUBLIC LISTS BELOW--------">'+escapeListSelectHTML(listSelectI18n.p('lists.selector.public_group', '--------PUBLIC LISTS BELOW--------'))+'</option>';
            for (var n=0; n<public_lists.length; n++) {
                html += '<option value="'+escapeListSelectHTML(public_lists[n][0])+'">'+escapeListSelectHTML(public_lists[n][1])+'</option>';
            }
        }

        if (refresh) {
            if (types.length > 1) { types = types.join(',') }
            html = '<div class="input-group" id="'+escapeListSelectHTML(div_name)+'_list_select_div">'+html+'</select><span class="input-group-btn"><button class="btn btn-default" type="button" id="'+escapeListSelectHTML(div_name)+'_list_refresh" title="'+escapeListSelectHTML(listSelectI18n.p('lists.selector.refresh', 'Refresh lists'))+'" onclick="refreshListSelect(\''+escapeListSelectHTML(div_name)+'\',\''+escapeListSelectHTML(types)+'\')"><span class="glyphicon glyphicon-refresh" aria-hidden="true"></span></button></span></div>';
            return html;
        }
        else {
            html = html + '</select>';
            return html;
        }
    },

    updateName: function(list_id, new_name) {
        var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        jQuery.ajax( {
            url: '/list/name/update',
            async: false,
            data: { 'name' : new_name, 'list_id' : list_id },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                    return;
                }
                else {
                    alert(listActionI18n.p('lists.actions.name_updated', 'The name of the list was changed to %{name}', {name: new_name}));
                }
            },
            error: function(response) { alert(listActionI18n.p('lists.actions.update_failed', 'An error occurred.')); }
        });
        this.renderLists('list_dialog');
    },

    updateDescription: function(list_id, new_description) {
        var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        jQuery.ajax({
            url: '/list/description/update',
            async: false,
            data: { 'description' : new_description, 'list_id' : list_id },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                    return;
                }
                else {
                    alert(listActionI18n.p('lists.actions.description_updated', 'The description of the list was changed to %{description}', {description: new_description}));
                }
            },
            error: function(response) { alert(listActionI18n.p('lists.actions.update_failed', 'An error occurred.')); }
        });
        this.renderLists('list_dialog');
    },

    sortItems: function(list_id, sort) {
        var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        jQuery.ajax({
            url: '/list/sort',
            async: false,
            data: { 'sort' : sort, 'list_id' : list_id },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                    return;
                }
            },
            error: function(response) { alert(listActionI18n.p('lists.actions.sort_failed', 'An error occurred in sort.')); }
        });
        this.renderItems('list_item_dialog', list_id);
    },


    validate: function(list_id, type, non_interactive) {
        var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
	//alert("validate: "+list_id +" "+type+" "+ non_interactive);
        return jQuery.ajax( {
            url: '/list/validate/'+list_id+'/'+type,
	}).then(
	    function(r) {
		//alert("now="+JSON.stringify(r));
		if (r.error) {
		    if (non_interactive) {
			return r;
		    }
		    alert(r.error);
		    return;
		}
		if (!non_interactive) {
		    return validate_interactive(r, type, list_id)
		}
		else {
		    return r;
		}
	    });
    },

    legacy_validate: function(list_id, type, non_interactive) {
        var listLegacyValidationI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };

	var valid = 0;

	jQuery.ajax( {
	    url: '/list/validate/'+list_id+'/'+type,
	    async: false,
	    success: function(r) {
		if (r.error) {
		    alert(r.error);
		}
		else {
		    if (type == 'accessions' && r.valid ==1) {
			valid= 1;
		    }
		    else if (type != 'accessions' && r.missing == 0) {
			valid= 1;
		    }
		    else {
			//alert('Please provide a valid list');
			valid = 0;
		    }
		    if (type != 'accessions' && r.warning !== undefined && r.warning != 0) {
                        alert(r.warning.join(", "));
                    }
		}
	    },
	    error: function(e) { alert(listLegacyValidationI18n.p('lists.validation.request_failed', 'An error occurred validating the list %{id} (type=%{type})', {id: list_id, type: type})); }
	});
	return valid;
    },


    seedlotSearch: function(list_id){
        var self = this;
        var listUiI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        jQuery('#availible_seedlots_modal').modal('show');
        var accessions = this.getList(list_id);
        var list_type = this.getListType(list_id);
        if (window.available_seedlots){
            window.available_seedlots.build_table(accessions, list_type);
        } else {
            throw "avalilible_seedlots.mas not included";
        }
        jQuery('#new-list-from-seedlots').unbind('submit');
        jQuery("#new-list-from-seedlots").submit(function(){
            jQuery('#working_modal').modal('show');
            try {
                var form = jQuery(this).serializeArray().reduce(function(map,obj){
                    map[obj.name] = obj.value;
                    return map;
                }, {});
                //console.log(form);
                var list = new CXGN.List();
                var names = window.available_seedlots.get_selected().map(function(d){
                    return d.name;
                });
                var newListID = list.newList(form["name"]);
                if (!newListID) throw "List creation failed.";
                list.setListType(newListID,"seedlots");
                var count = list.addBulk(newListID, names);
                if (!count) throw "Added nothing to list or addition failed.";
                jQuery('#working_modal').modal('hide');
                alert(listUiI18n.p('lists.new.created', 'List "%{name}" created with %{count} entries.', {name: form["name"], count: count}));
                self.renderLists('list_dialog');
            }
            catch(err) {
                setTimeout(function(){throw err;});
            }
            finally {
                jQuery('#working_modal').modal('hide');
                return false;
            }
        });
    },

    synonymSearch: function(list_id){
        var self = this;
        var listUiI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        jQuery.ajax( {
            url: '/list/desynonymize?list_id='+list_id,
            async: false,
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                //console.log(response);
                if (response.success) {
                    html = "";
                    jQuery('#synonym_search_result_display').modal('show');
                    html += "<table class='table table-hover table-bordered'><thead><tr><th>" + _sgnListEscapeHTML(listUiI18n.p('lists.synonyms.name_in_list', 'Name in List')) + "</th><th>" + _sgnListEscapeHTML(listUiI18n.p('lists.synonyms.unique_name', 'Unique Name')) + "</th></tr></thead><tbody>";
                    for (var i = 0; i < response.previous_list.length; i++) {
                        if (response.synonyms && response.previous_list[i] in response.synonyms){
                            html+="<tr><td>"+response.previous_list[i]+"</td><td>&harr; "+response.previous_list[i]+"</td></tr>";
                        } else {
                            var match = false;
                            for (var uniquename in response.synonyms) {
                                if (!match && response.synonyms.hasOwnProperty(uniquename)) {
                                    if (response.synonyms[uniquename].indexOf(response.previous_list[i])>=0){
                                        match = true;
                                        html+="<tr><td><span style='color:blue'>"+response.previous_list[i]+"</span></td>";
                                        html+="<td><span style='color:blue'>&rarr; "+uniquename+"</span></td></tr>";
                                    }
                                }
                            }
                            if (!match){
                                html+="<tr><td><span style='color:red'>"+response.previous_list[i]+"</span></td>";
                                html+="<td><span style='color:red'>&times; " + _sgnListEscapeHTML(listUiI18n.p('lists.synonyms.not_a_name_or_synonym', 'Not a Name or Synonym')) + "</span></td></tr>";
                            }
                        }
                    }
                    html += "</tbody></table>";
                    jQuery('#synonym_search_result_display_html').html(html);
                    jQuery('#new-list-from-unames').unbind('submit');
                    jQuery('#new-list-from-unames').submit(function () {
                        jQuery('#working_modal').modal('show');
                        try {
                            var form = jQuery(this).serializeArray().reduce(function(map,obj){
                                map[obj.name] = obj.value;
                                return map;
                            }, {});
                            //console.log(form);
                            var list = new CXGN.List();
                            var newListID = list.newList(form["name"]);
                            if (!newListID) throw "List creation failed.";
                            list.setListType(newListID,response.list_type);
                            var count = list.addBulk(newListID,response.list);
                            if (!count) throw "Added nothing to list or addition failed.";
                            jQuery('#working_modal').modal('hide');
                            alert(listUiI18n.p('lists.new.created', 'List "%{name}" created with %{count} entries.', {name: form["name"], count: count}));
                            self.renderLists('list_dialog');
                        }
                        catch(err) {
                            setTimeout(function(){throw err;});
                        }
                        finally {
                            jQuery('#working_modal').modal('hide');
                            return false;
                        }
                    });
                } else {
                    alert(listUiI18n.p('lists.synonyms.error', 'An error occurred while desynonymizing list ID:%{id}', {id: list_id}));
                }
            },
            error: function(response) {
                alert(listUiI18n.p('lists.synonyms.error', 'An error occurred while desynonymizing list ID:%{id}', {id: list_id}));
                jQuery('#working_modal').modal('hide');
                error=1;
            }
        });
    },

    fuzzySearch: function(list_id, list_type) {
        var listUiI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
        var error = 0;
        jQuery.ajax( {
            url: '/list/fuzzysearch/'+list_id+'/'+list_type,
            async: true,
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                //console.log(response);
                var html = "";
                var list_type_name = list_type.charAt(0).toUpperCase() + list_type.slice(1);
                if (response.success) {
                    html += "<h2>" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.exact_match_heading', '%{type} that exactly match as uniquenames (not synonyms)', {type: list_type_name})) + "</h2>";
                    html += "<table class='table table-hover table-bordered' ><thead><tr><th>" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.found_in_database', 'Found In Database')) + "</th></tr></thead><tbody>";
                    for(var i=0; i<response.found.length; i++){
                        html += "<tr><td>"+response.found[i].unique_name+"</td></tr>";
                    }
                    html += "</tbody></table>";
                    html += "<h2>" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.similar_heading', '%{type} that are not found in the database, but fuzzy match (names are visibly similar)', {type: list_type_name})) + "</h2>";
                    html += "<table class='table table-hover table-bordered' ><thead><tr><th>" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.name_in_your_list', 'Name In Your List')) + "</th><th>" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.found_in_database', 'Found In Database')) + "</th><th>" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.distance_score', 'Distance Score')) + " <span style='position: relative; top: 0: right: 0; cursor: help;' title='" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.distance_help', 'The closer the score is to 1.0, the more similar the match')) + "'>(?)</span></th></tr></thead><tbody>";
                    for(var i=0; i<response.fuzzy.length; i++){
                        for(j=0; j <response.fuzzy[i].matches.length; j++){
                            if (response.fuzzy[i].matches[j].is_synonym){
                                html += "<tr><td>"+response.fuzzy[i].name+"</td><td>"+response.fuzzy[i].matches[j].name+" (" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.synonym_of', 'SYNONYM OF: %{name}', {name: response.fuzzy[i].matches[j].synonym_of})) + ") </td><td>"+response.fuzzy[i].matches[j].distance+"</td></tr>";
                            } else {
                                html += "<tr><td>"+response.fuzzy[i].name+"</td><td>"+response.fuzzy[i].matches[j].name+"</td><td>"+response.fuzzy[i].matches[j].distance+"</td></tr>";
                            }
                        }
                    }
                    html += "</tbody></table>";
                    html += "<h2>" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.no_match_heading', '%{type} that are not found in the database and have no match', {type: list_type_name})) + "</h2>";
                    html += "<table class='table table-hover table-bordered' ><thead><tr><th>" + _sgnListEscapeHTML(listUiI18n.p('lists.fuzzy.not_found_in_database', 'Not Found In Database')) + "</th></tr></thead><tbody>";
                    for(var i=0; i<response.absent.length; i++){
                        html += "<tr><td>"+response.absent[i]+"</td></tr>";
                    }
                    html += "</tbody></table>";
                    html += "<form id='fuzzy_search_result_download' method='post' action='/ajax/accession_list/fuzzy_download' target='TheWindow'><input type='hidden' name='fuzzy_response' value='"+JSON.stringify(response.fuzzy)+"' /></form>";
                    jQuery('#fuzzy_search_result_display_html').html(html);
                    jQuery('#fuzzy_search_result_display').modal('show');
                } else {
                    alert(listUiI18n.p('lists.fuzzy.error_searching_list', 'An error occurred while fuzzy searching list %{id}', {id: list_id}));
                }
            },
            error: function(response) {
                alert(listUiI18n.p('lists.fuzzy.error_searching_the_list', 'An error occurred while fuzzy searching the list %{id}', {id: list_id}));
                error=1;
            }
        });

        if (error === 1 ) { return; }
    },

    transform: function(list_id, transform_name) {
        var transformed = new CXGN.List();
        var ajaxResponse = [];
        jQuery.ajax( {
            url: '/list/transform/'+list_id+'/'+transform_name,
            async: false,
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                else {
                    ajaxResponse = response;
                    //console.log("transformed="+ajaxResponse);
                }
            },
            error: function(response) { alert((window.SGN && SGN.i18n ? SGN.i18n.p('lists.error.validating_list', 'An error occurred while validating the list %{id}', {id: list_id}) : _sgnListFormatSource('An error occurred while validating the list %{id}', {id: list_id}))); }
        });
        return ajaxResponse.transform;
    },

    transform2Ids: function(list_id, data) {
        if (data === undefined) var data = this.getListData(list_id);
        //console.log("data ="+JSON.stringify(data));
        var list_type = data.type_name;

        var new_type = this.transform_keys[list_type];
        if ( !new_type ) return { 'error' : "cannot convert the list because of unknown type" };
        //if (window.console) console.log("new type = "+new_type);
        var transformed = this.transform(list_id, new_type);
        //if (window.console) console.log("transformed="+JSON.stringify(transformed));
        return transformed;
    },

    getListItemDbId: function(list_type, list_item_name) {
        return new Promise((resolve, reject) => {
            var new_type = this.transform_keys[list_type];
            if ( !new_type ) return reject('Unsupported list type');

            jQuery.ajax({
                url: '/list/transform/temp',
                method: 'GET',
                data: {
                    type: new_type,
                    items: JSON.stringify([list_item_name])
                },
                success: (resp) => {
                    if ( resp && resp.missing && resp.transform ) {
                        if ( resp.missing.length > 0 ) {
                            return reject(`The list item ${list_item_name} is not in the database`);
                        }
                        else if ( resp.transform.length === 1 ) {
                            return resolve(resp.transform[0]);
                        }
                    }
                    return reject(`Could not get list item db id`);
                },
                error: (resp) => {
                    return reject(`Could not get list item db id [${resp}]`);
                }
            });
        });
    },

    getListItemUrl: function(list_type, list_item_db_id) {
        switch (list_type) {
            case "accessions":
            case "plants":
            case "plots":
                return document.location.origin + `/stock/${list_item_db_id}/view`;
            case "seedlots":
                return document.location.origin + `/breeders/seedlot/${list_item_db_id}`;
            case "crosses":
                return document.location.origin + `/cross/${list_item_db_id}`;
            case "breeding_programs":
                return document.location.origin + `/breeders/manage_programs`;
            case "locations":
                return document.location.origin + `/breeders/locations`;
            case "traits":
            case "trait_components":
                return document.location.origin + `/cvterm/${list_item_db_id}/view`;
            case "trials":
                return document.location.origin + `/breeders/trial/${list_item_db_id}`;
            case "genotyping_protocols":
                return document.location.origin + `/breeders_toolbox/protocol/${list_item_db_id}`;
            case "genotyping_projects":
                return document.location.origin + `/breeders/trial/${list_item_db_id}`;
            default:
                return null;
        }
    }

};

function setUpLists() {
    jQuery("button[name='lists_link']").click(
        function() { show_lists(); }
    );
}


function show_lists() {
   jQuery('#list_dialog').modal("show");

    var l = new CXGN.List();
    l.renderLists('list_dialog');
}

/* deprecated */
function pasteListMenu (div_name, menu_div, button_name, list_type) {
    var lo = new CXGN.List();

    var html='';

    if (button_name === undefined) {
        button_name = 'paste';
    }
    if (list_type){
        html = lo.listSelect(div_name, [list_type], undefined, undefined, undefined);
    }else {
        html = lo.listSelect(div_name, undefined, undefined, undefined, undefined);
    }
    html = html + '<button class="btn btn-info btn-sm" type="button" value="'+button_name+'" onclick="javascript:pasteList(\''+div_name+'\')" >'+button_name+'</button>';

    jQuery('#'+menu_div).html(html);
}

function pasteList(div_name) {
    var lo = new CXGN.List();
    var list_id = jQuery('#'+div_name+'_list_select').val();
    var list = lo.getList(list_id);
    // textify list
    var list_text = '';
    for (var n=0; n<list.length; n++) {
        list_text = list_text + list[n]+"\r\n";
    }
    //console.log(list_text);
    jQuery('#'+div_name).val(list_text);
}

/* refreshListSelect: refreshes an html select with lists of requested types.

 Parameters:
   div_name: The div_name where the select should appear
   types: a list of list types that should be listed in the menu
*/

function refreshListSelect(div_name, types) {
    var lo = new CXGN.List();
    var types = types.split(",");
    document.getElementById(div_name).innerHTML = (lo.listSelect(div_name, types, window.SGN && SGN.i18n ? SGN.i18n.p('lists.selector.refreshed', 'Options refreshed.') : 'Options refreshed.', 'refresh', undefined));
    //console.log("List options refreshed!");
}

/*
  addToListMenu

  Parameters:
  * listMenuDiv - the name of the div where the menu will be displayed
  * dataDiv - the div from which the data will be copied (can be a div, textarea, or html select
  * options - optional hash with the following keys:
    - selectText: if the dataDiv is an html select and selectText is true, the text and not the value will be copied into the list
    - listType: the type of lists to display in the menu
    - typesSourceDiv: obtain the type from this source div


*/

function addToListMenu(listMenuDiv, dataDiv, options) {
    var lo = new CXGN.List();
    var listCopyI18n = (window.SGN && window.SGN.i18n) || {
        p: function (context, source, vars) { return _sgnListFormatSource(source, vars); },
        np: function (context, singular, plural, count, vars) { return _sgnListFormatSource(count === 1 ? singular : plural, vars); }
    };

    var html;
    var selectText;
    var listType;
    var typeSourceDiv;
    var type;
    var addition_type;
    var list_name_value = "";

    if (options) {
        if (options.selectText) {
            selectText = options.selectText;
        }
        if (options.typeSourceDiv) {
            var sourcetype = getData(options.typeSourceDiv, selectText);
            if (sourcetype) {
                type = sourcetype.replace(/(\n|\r)+$/, '');
            }
        }
        if (options.listType) {
            type = options.listType;
        }
        if (options.additionType) {
            addition_type = options.additionType;
        }
        if (options.listName){
            list_name_value = options.listName;
        }
    }

    html = '<div class="row"><div class="col-sm-6" style="margin-right:0px; padding-right:0px;"><input class="form-control input-sm" type="text" id="'+_sgnListEscapeHTML(dataDiv)+'_new_list_name" placeholder="'+_sgnListEscapeHTML(listCopyI18n.p('lists.copy.new_name', 'New list...'))+'" value="'+_sgnListEscapeHTML(list_name_value)+'"/>';
    html += '</div><div class="col-sm-6" style="margin-left:0px; padding-left:0px; margin-right:0px; padding-right:0px;"><input type="hidden" id="'+_sgnListEscapeHTML(dataDiv)+'_addition_type" value="'+_sgnListEscapeHTML(addition_type)+'" /><input type="hidden" id="'+_sgnListEscapeHTML(dataDiv)+'_list_type" value="'+_sgnListEscapeHTML(type)+'" />';
    html += '<button class="btn btn-primary btn-sm" style="width:100%;white-space:normal;" id="'+_sgnListEscapeHTML(dataDiv)+'_add_to_new_list" type="button">'+_sgnListEscapeHTML(listCopyI18n.p('lists.copy.add_new', 'add to new list'))+'</button></div></div><br />';

    html += '<div class="row"><div class="col-sm-6" style="margin-right:0px; padding-right:0px;">'+lo.listSelect(dataDiv, [ type ], undefined, undefined, 1);

    html += '</div><div class="col-sm-6" style="margin-left:0px; padding-left:0px; margin-right:0px; padding-right:0px;"><button class="btn btn-primary btn-sm" style="width:100%;white-space:normal;" id="'+_sgnListEscapeHTML(dataDiv)+'_button" type="button">'+_sgnListEscapeHTML(listCopyI18n.p('lists.copy.add_existing', 'add to list'))+'</button></div></div>';

    jQuery('#'+listMenuDiv).html(html);

    var list_id = 0;

    jQuery('#' + dataDiv + '_add_to_new_list').click(function () {
        var lo = new CXGN.List();
        var new_name = jQuery('#' + dataDiv + '_new_list_name').val();
        var type = jQuery('#' + dataDiv + '_list_type').val();
        var addition_type = jQuery('#' + dataDiv + '_addition_type').val();

        if (dataDiv === 'trial_tissue_samples_data') {
            type = 'tissue_samples';
        }

        var data = getData(dataDiv, selectText);
        var list_id = lo.newList(new_name);
        if (list_id > 0) {
            var elementsAdded;
            if (addition_type === 'cross_progeny') {
                elementsAdded = lo.addCrossProgenyToList(list_id, data);
            } else {
                elementsAdded = lo.addToList(list_id, data);
            }
            if (type) {
                lo.setListType(list_id, type);
            }
            if (_sgnListValidAddedCount(elementsAdded)) alert(listCopyI18n.np('lists.copy.added_new',
                'Added %{count} list element to the new list "%{name}".',
                'Added %{count} list elements to the new list "%{name}".',
                elementsAdded, {count: elementsAdded, name: new_name}));
        }
    });


    jQuery('#'+dataDiv+'_button').click( function() {
        var data = getData(dataDiv, selectText);
        list_id = jQuery('#'+dataDiv+'_list_select').val();
        var lo = new CXGN.List();
        var elementsAdded = lo.addToList(list_id, data);

        if (_sgnListValidAddedCount(elementsAdded)) alert(listCopyI18n.np('lists.copy.added_existing',
            'Added %{count} list element.', 'Added %{count} list elements.',
            elementsAdded, {count: elementsAdded}));
        return list_id;
    });

}

function getData(id, selectText) {
    var divType = jQuery("#"+id).get(0).tagName;
    var data;

    if (divType == 'DIV' || divType =='SPAN' || divType === undefined) {
        data = jQuery('#'+id).html();
    }
    if (divType == 'SELECT' && selectText) {
        //if (jQuery.browser.msie) {
        //    // Note: MS IE unfortunately removes all whitespace
        //    // in the jQuery().text() call. Program it out...
        //    //
        //    var selectbox = document.getElementById(id);
        //    var datalist = new Array();
        //    for (var n=0; n<selectbox.length; n++) {
        //         if (selectbox.options[n].selected) {
        //             var x=selectbox.options[n].text;
        //             datalist.push(x);
        //         }
        //     }
        //     data = datalist.join("\n");
        //     //alert("data:"+data);

        // }
        // else {
            data = jQuery('#'+id+" option:selected").text();
        //}

    }
    if (divType == 'SELECT' && ! selectText) {
        var return_data = jQuery('#'+id).val();

        if (return_data instanceof Array) {
            data = return_data.join("\n");
        }
        else {
            data = return_data;
        }
    }
    if (divType == 'TEXTAREA') {
        data = jQuery('textarea#'+id).val();
    }
    return data;
}


/* deprecated */
function addTextToListMenu(div) {
    var lo = new CXGN.List();
    var html = lo.listSelect(div, undefined, undefined, undefined, undefined);
    html = html + '<input id="'+div+'_button" type="button" value="' + _sgnListEscapeHTML((window.SGN && SGN.i18n ? SGN.i18n.p('lists.copy.add_existing', 'add to list') : 'add to list')) + '" />';

    document.write(html);

    jQuery('#'+div+'_button').click( function() {
        var text = jQuery('textarea#div').val();
        var list_id = jQuery('#'+div+'_list_select').val();
        lo.addToList(list_id, text);
        lo.renderLists('list_dialog');
    });
}

/* deprecated */
function addSelectToListMenu(div) {
    var lo = new CXGN.List();
    var html = lo.listSelect(div, undefined, undefined, undefined, undefined);
    html = html + '<input id="'+div+'_button" type="button" value="' + _sgnListEscapeHTML((window.SGN && SGN.i18n ? SGN.i18n.p('lists.copy.add_existing', 'add to list') : 'add to list')) + '" />';

    document.write(html);

    jQuery('#'+div+'_button').click( function() {
        var selected_items = jQuery('#'+div).val();
        var list_id = jQuery('#'+div+'_list_select').val();
        addArrayToList(selected_items, list_id);
        lo.renderLists('list_dialog');
    });
}


/* deprecated */
// add the text in a div to a list
function addDivToList(div_name) {
    var list_id = jQuery('#'+div_name+'_list_select').val();
    var lo = new CXGN.List();
    var list = jQuery('#'+div_name).val();
    var items = list.split("\n");

    for(var n=0; n<items.length; n++) {
        var added = lo.addItem(list_id, items[n]);
        if (added > 0) { }
    }
}

/* deprecated */
function addTextToList(div, list_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var lo = new CXGN.List();
    var item = jQuery('#'+div).val();
    var id = lo.addItem(list_id, item);
    if (id == 0) {
        alert(listActionI18n.p('lists.add.duplicate_item', 'Item "%{item}" was not added because it already exists', {item: item}));
    }
    lo.renderLists('list_dialog');
}

/* deprecated */
function addMultipleItemsToList(div, list_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var lo = new CXGN.List();
    var content = jQuery('#'+div).val();
    if (content == '') {
        alert(listActionI18n.p('lists.add.no_items', 'No items - Please enter items to add to the list.'));
        return;
    }
    //    var items = content.split("\n");

    //  var duplicates = new Array();
    var items = content.split("\n");
    lo.addBulk(list_id, items);
    // for (var n=0; n<items.length; n++) {
    //	var id = lo.addItem(list_id, items[n]);
    //	if (id == 0) {
    //	    duplicates.push(items[n]);
    //	}
    //  }
    //if (duplicates.length >0) {
    //	alert(listActionI18n.p('lists.add.duplicate_items', 'The following items were not added because they are already in the list: %{items}', {items: duplicates.join(', ')}));
    //  }
    //lo.renderLists('list_dialog');
}

/* deprecated */
function addArrayToList(items, list_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var lo = new CXGN.List();
    var duplicates = new Array();
    for (var n=0; n<items.length; n++) {
        var id = lo.addItem(list_id, items[n]);
        if (id == 0) {
            duplicates.push(items[n]);
        }
    }
    if (duplicates.length >0) {
        alert(listActionI18n.p('lists.add.duplicate_items', 'The following items were not added because they are already in the list: %{items}', {items: duplicates.join(', ')}));
    }
}

function deleteList(list_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var lo = new CXGN.List();
    var list_name = lo.listNameById(list_id);
    if (confirm(listActionI18n.p('lists.actions.confirm_delete', 'Delete list "%{name}"? (ID=%{id}). This cannot be undone.', {name: list_name, id: list_id}))) {
        lo.deleteList(list_id);
        lo.renderLists('list_dialog');
        alert(listActionI18n.p('lists.actions.deleted', 'Deleted list %{name}', {name: list_name}));
    }
}

function togglePublicList(list_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    jQuery.ajax({
        "url": "/list/public/toggle",
        "type": "POST",
        "data": {'list_id': list_id},
        success: function(r) {
            var lo = new CXGN.List();
            if (r.error) {
                alert(r.error);
            } else if (r.r == 1) {
                alert(listActionI18n.p('lists.actions.set_private', 'List set to Private'));
            } else if (r.r == 0) {
                alert(listActionI18n.p('lists.actions.set_public', 'List set to Public'));
            }
            lo.renderLists('list_dialog');
        },
        error: function() {
            alert(listActionI18n.p('lists.actions.set_public_failed', 'Error Setting List to Public! List May Not Exist.'));
        }
    });
    var lo = new CXGN.List();
    lo.renderLists('list_dialog');
}

function makePublicList(list_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    jQuery.ajax({
        "url": "/list/public/true",
        "type": "POST",
        "data": {'list_id': list_id},
        success: function(r) {
            var lo = new CXGN.List();
            if (r.error) {
                alert(r.error);
            }
        },
        error: function() {
            alert(listActionI18n.p('lists.actions.set_public_failed', 'Error Setting List to Public! List May Not Exist.'));
        }
    });
}

function makePrivateList(list_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    jQuery.ajax({
        "url": "/list/public/false",
        "type": "POST",
        "data": {'list_id': list_id},
        success: function(r) {
            var lo = new CXGN.List();
            if (r.error) {
                alert(r.error);
            }
        },
        error: function() {
            alert(listActionI18n.p('lists.actions.set_private_failed', 'Error Setting List to Private! List May Not Exist.'));
        }
    });
}

function copyPublicList(list_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    jQuery.ajax({
        "url": "/list/public/copy",
        "type": "POST",
        "data": {'list_id': list_id},
        success: function(r) {
            if (r.error) {
                alert(r.error);
            } else if (r.success == 'true') {
                alert(listActionI18n.p('lists.actions.public_list_copied', 'Public List Copied to Your Lists.'));
            }
        },
        error: function() {
            alert(listActionI18n.p('lists.actions.copy_public_failed', 'Error Copying Public List! List May Not Exist.'));
        }
    });
    var lo = new CXGN.List();
    lo.renderLists('list_dialog');
}

function deleteItemLink(list_item_id) {
    var lo = new CXGN.List();
    lo.deleteItem(list_item_id);
    lo.renderLists('list_dialog');
}

function working_modal_show() {
    jQuery("#working_modal").modal('show');
}

function working_modal_hide() {
    jQuery("#working_modal").modal('hide');
}

function showListItems(div, list_id) {
    working_modal_show();
    var l = new CXGN.List();
    l.renderItems(div, list_id);
    jQuery('#'+div).modal("show");
    working_modal_hide();
}

function showPublicListItems(div, list_id) {
    var l = new CXGN.List();
    jQuery('#'+div).modal("show");
    l.renderPublicItems(div, list_id);
}

function addNewList(div_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var lo = new CXGN.List();
    var name = jQuery('#'+div_id).val();

    if (name == '') {
        alert(listActionI18n.p('lists.new.name_required_short', 'Please specify a name for the list.'));
        return;
    }

    var list_id = lo.existsList(name);
    if (list_id > 0) {
        alert(listActionI18n.p('lists.new.name_exists_short', 'The list %{name} already exists. Please choose another name.', {name: name}));
        return;
    }
    lo.newList(name);
    lo.renderLists('list_item_dialog');
}

function changeListType(html_select_id, list_id) {
    var type = jQuery('#'+html_select_id).val();
    var l = new CXGN.List();
    l.setListType(list_id, type);
    l.renderLists('list_dialog');
}

/*
   validateList - check if all the elements in a list are of the correct type

   Parameters:
   * list_id: the id of the list
   * html_select_id: the id of the html select containing the type list

*/

function validateList(list_id, list_type, html_select_id) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    if (!list_type) {
        list_type = jQuery('#'+html_select_id).val();
    }
    if ( !list_type || list_type === '' || list_type === '(none)' ) {
        alert((window.SGN && SGN.i18n ? SGN.i18n.p('lists.validation.type_required', 'You must select the list type before validating') : 'You must select the list type before validating'));
        return;
    }

    jQuery('#working_modal').modal('show');
    var lo = new CXGN.List();
    var validate = lo.validate(list_id, list_type);
    validate.then(function(response) {
        jQuery('#working_modal').modal('hide');
    }).catch(function(err) {
        jQuery('#working_modal').modal('hide');
        let msg = listActionI18n.p('lists.validation.unexpected_error', 'There was an error validating your list. ');
        if ( err && err.responseText ) msg += `\n\n${err.responseText}`;
        alert(msg);
    });
}

/*
    validateLists - check a list of list ids and a list of types
*/


function validateLists(list_ids, types) {

    return jQuery.ajax( {
	url: '/ajax/list/validate_lists?list_ids='+list_ids.join(",")+'&amp;list_types='+types.join(",")
    });

}


/*
   fuzzySearchList - perform a fuzzy search over the items in the list and return the match results of this search

   Parameters:
   * list_id: the id of the list
   * list_type: the type of the list

*/

function fuzzySearchList(list_id, list_type) {
    var lo = new CXGN.List();
    lo.fuzzySearch(list_id, list_type);
}

function deleteSelectedListGroup(list_ids) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var arrayLength = list_ids.length;
    if (confirm(listActionI18n.p('lists.actions.confirm_delete_selected', 'Delete the selected lists? This cannot be undone.'))) {
        for (var i=0; i<arrayLength; i++) {
            var lo = new CXGN.List();
            lo.deleteList(list_ids[i]);
        }
        lo.renderLists('list_dialog');
    }
}

function downloadSelectedListGroup(list_ids) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    jQuery.ajax({
        url: '/list/download_multiple',
        contentType: 'application/json',
        data: { 'list_ids' : JSON.stringify(list_ids) },
        success: function(data) {
            const url = window.URL.createObjectURL(data);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'lists.zip';
            document.body.appendChild(a);
            a.click();
            a.remove();
            window.URL.revokeObjectURL(url);
        },
        xhrFields: {
            responseType: 'blob'
        },
        error: function(xhr, status, error) {
            alert(listActionI18n.p('lists.download.failed', 'An error occurred.'));
        }
    })
}

function createThreeColumnDiff(list_ids) {
    if (list_ids.length > 2) {
        return;
    }
    var lo = new CXGN.List();
    var list_name1 = lo.listNameById(list_ids[0]);
    var list_name2 = lo.listNameById(list_ids[1]);

    lo.compareLists(list_ids).then(function(result) {
        window._listComparisonResult = result;

        // Find max column length for balanced table
        const maxRows = Math.max(
            result.only_in_list1.length,
            result.only_in_list2.length,
            result.in_both.length
        );
        let rows = [];
        for (let i = 0; i < maxRows; i++) {
            let cell1 = result.only_in_list1[i] || "";
            let cell2 = result.only_in_list2[i] || "";
            let cell3 = result.in_both[i] || "";
            rows.push(
              `<tr>
                <td>${cell1}</td>
                <td>${cell2}</td>
                <td style="background:#eeeeee">${cell3}</td>
              </tr>`
            );
        }

        let html = `
          <table id="list_comparison_table" class="table table-bordered">
            <thead>
              <tr>
                <th style="width: 40%">Only in ${list_name1}</th>
                <th style="width: 40%">Only in ${list_name2}</th>
                <th style="width: 40%; background:#eeeeee">In Both</th>
              </tr>
            </thead>
            <tbody>
              ${rows.join("\n")}
            </tbody>
          </table>
        `;

        jQuery('#list_comparison_modal_div').html(html);

        let columnNames = { [`Only in ${list_name1}`]: "only_in_list1", [`Only in ${list_name2}`] : "only_in_list2", "In Both" : "in_both"};
        window._columnNames = columnNames;

        const $dropdown = jQuery('#comparison_column_select');
        $dropdown.empty();
        jQuery('#list_comparison_modal_div table thead th').each(function(i) {
            const title = jQuery(this).text().trim();
            $dropdown.append(`<option value"${i}">${title}</option>`);

        });
        jQuery('#list_comparison_modal').modal('show');
    });

}

jQuery(document).on('click', '#download_comparison_column', function() {
    var listComparisonI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };

    let tableHeader = jQuery('#comparison_column_select').val();
    let columnNames = window._columnNames;
    const selected = columnNames[tableHeader];

    const result = window._listComparisonResult;
    const values = result[selected];
    const headerKeys = Object.keys(columnNames);

    if (values.length === 0) {
        alert(listComparisonI18n.p('lists.comparison.no_data', 'No data found in column: %{column}', {column: tableHeader}));
        return;
    }

    const textContent = values.join('\n');
    const blob = new Blob([textContent], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;

    let downloadName;
    if (tableHeader === "In Both") {
        const listName1 = headerKeys[0].replace("Only in", "");
        const listName2 = headerKeys[1].replace("Only in", "");
        downloadName = `In both ${listName1} and ${listName2}`;
    } else {
        downloadName = tableHeader;
    }

    a.download = `${downloadName}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
});

function pasteTraitList(div_name) {
    var lo = new CXGN.List();
    var list_id = jQuery('#'+div_name+'_list_select').val();
    console.log(list_id);
    var list = lo.getList(list_id);
    console.log(list);

    var list_text = '<select class="form-control" id="select_traits_for_trait_file_2"  >';
    for (var n=0; n<list.length; n++) {
        list_text = list_text + '<option value="' + list[n] + '">' + list[n] + '</option>\n';
    }
    list_text = list_text + '</select>';
    console.log(list_text);
    jQuery('#'+div_name).html(list_text);
}

function makePublicSelectedListGroup(list_ids) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var arrayLength = list_ids.length;
    if (confirm(listActionI18n.p('lists.actions.confirm_make_public_selected', 'Make selected lists public?'))) {
        for (var i=0; i<arrayLength; i++) {
            makePublicList(list_ids[i]);
        }
        var lo = new CXGN.List();
        lo.renderLists('list_dialog');
    }
}

function makePrivateSelectedListGroup(list_ids) {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var arrayLength = list_ids.length;
    if (confirm(listActionI18n.p('lists.actions.confirm_make_private_selected', 'Make selected lists private?'))) {
        for (var i=0; i<arrayLength; i++) {
            makePrivateList(list_ids[i]);
        }
        var lo = new CXGN.List();
        lo.renderLists('list_dialog');
    }
}

/**
 * Combine the items from the selected lists and create a new list
 * The items can be combined either using a union method or intersection method
 * @param {Array[Integer]} list_ids Array of List IDs of Lists to combine
 * @param {String} type Method of combining lists (either 'union' or 'intersection', union is default)
 */
function combineSelectedListGroup(list_ids, type = 'union') {
    var listActionI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    var arrayLength = list_ids.length;
    var list_name = jQuery('#new_combined_list_name').val();
    if ( !list_name || list_name === '' ) return alert(listActionI18n.p('lists.actions.new_name_required', 'You must enter a new list name first'));

    if ( confirm(listActionI18n.p('lists.actions.confirm_combine', 'Combine selected lists into a new list called %{name}?', {name: list_name})) ) {
        var lo = new CXGN.List();

        // Check if the selected lists are the same list type
        var list_types = [];
        for ( var i=0; i<arrayLength; i++ ) {
            var list_type = lo.getListType(list_ids[i]);
            if ( !list_types.includes(list_type) ) list_types.push(list_type);
        }
        if ( list_types.length > 1 && !confirm(listActionI18n.p('lists.actions.confirm_combine_types', 'Are you sure you want to combine these list types: %{types}', {types: list_types.join(', ')})) ) return;

        // Combine list items
        var arrayItems = [];

        // INTERSECTION
        if ( type === 'intersection' ) {
            var allListItems = [];
            for ( var i=0; i<arrayLength; i++ ) {
                list = lo.getListData(list_ids[i]);
                var listItems = [];
                for ( var j=0; j<list.elements.length; j++ ) {
                    listItems.push(list.elements[j][1]);
                }
                allListItems.push(listItems);
            }
            arrayItems = allListItems.reduce((result, array) => result.filter(value => array.includes(value)));
        }

        // UNION
        else {
            for ( var i=0; i<arrayLength; i++ ) {
                list = lo.getListData(list_ids[i]);
                for ( var j=0; j<list.elements.length; j++ ) {
                    arrayItems.push(list.elements[j][1]);
                }
            }
        }

        // Get unique set of items
        arrayItems = [...new Set(arrayItems)];
        if ( !arrayItems || arrayItems.length === 0 ) {
            return alert(listActionI18n.p('lists.actions.no_common_items', "The selected lists don't have any list items in common.  New list not created."));
        }

        // Add combined items to new list
        var new_list_id = lo.newList(list_name);
        if ( list_types.length === 1 ) {
            lo.setListType(new_list_id, list_types[0]);
        }
        lo.addBulk(new_list_id, arrayItems);
        lo.renderLists('list_dialog');
        alert(listActionI18n.p('lists.actions.items_added_to_new_list', 'Added %{count} items to the new List %{name}', {count: arrayItems.length, name: list_name}));
    }
}

function downloadFuzzyResponse(){
    var f = document.getElementById('fuzzy_search_result_download');
    window.open('', 'TheWindow');
    f.submit();
}

jQuery(document).ready(function() {
    jQuery("#list_item_dialog").draggable();
    jQuery("#list_dialog").draggable();
    jQuery("#public_list_dialog").draggable();
});


function validate_interactive(response, type, list_id) {
    var listUiI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, vars) { return _sgnListFormatSource(source, vars); } };
    missing = response.missing;
    warning = response.warning;
    wrong_case = response.wrong_case;
    multiple_wrong_case = response.multiple_wrong_case;
    synonym_matches = response.synonyms;
    multiple_synonym_matches = response.multiple_synonyms;
    valid = response.valid;

    //alert("validate_interactive: "+JSON.stringify(response));
    if (warning !== undefined && type != 'accessions' && warning.length != 0) {
	alert(warning.join(", "));
    }
    if (type == 'accessions' && valid == 1) {
	alert(listUiI18n.p('lists.validation.passed', 'This list passed validation.'));
	return;
    }
    else if (missing !== undefined  && type != 'accessions' && missing.length == 0) {
        alert(listUiI18n.p('lists.validation.passed', 'This list passed validation.'));
        return;
    } else {
        if (type == 'accessions') {
	    //alert(JSON.stringify(response));
            jQuery("#validate_accession_error_display tbody").html('');
            var missingAccessionsText = _sgnListEscapeHTML(listUiI18n.p('lists.validation.manage_accessions_note', 'Go to Manage Accessions to add these new accessions to database now.'));
            var missing_accessions_link = "<button class='btn btn-primary' onclick=\"window.location.href='/breeders/accessions?list_id="+list_id+"'\" >" + missingAccessionsText + "</button><br /><br />";

            jQuery("#validate_stock_add_missing_accessions").html(missing_accessions_link);

            var missing_accessions_vals = '';
            var missing_accessions_vals_for_list = '';
    	    var missing_accessions_for_table = new Array();

            for(var i=0; i<missing.length; i++) {
    		missing_accessions_for_table.push( [ missing[i], '(not&nbsp;present)' ] );
                missing_accessions_vals = missing_accessions_vals + missing[i] + '<br/>';
                missing_accessions_vals_for_list = missing_accessions_vals_for_list + missing[i] + '\n';
            }

    	    jQuery('#missing_accessions_table').DataTable( {
    		destroy: true,
    		data: missing_accessions_for_table,
    		sDom: 'lrtip',
    		bInfo: false,
    		paging: false,
    		columns: [
                { title: _sgnListEscapeHTML(listUiI18n.p('lists.validation.list_column', 'List')) },
                { title: _sgnListEscapeHTML(listUiI18n.p('lists.validation.database_column', 'DB')) },
    		]
    	    });


            jQuery("#validate_stock_add_missing_accessions_for_list").html(missing_accessions_vals_for_list);

            addToListMenu('validate_stock_add_missing_accessions_for_list_div', 'validate_stock_add_missing_accessions_for_list', {
                selectText: true,
                listType: 'accessions'
            });


    	    var wrong_case_accessions_for_list = '';

    	    jQuery('#wrong_case_message_div').html('');

    	    if (wrong_case !== undefined && wrong_case.length > 0) {
    		//alert(JSON.stringify(wrong_case));
    		jQuery('#wrong_case_table').DataTable( {
    		    destroy: true,
    		    data: wrong_case,
    		    sDom: 'lrtip',
    		    bInfo: false,
    		    paging: false,
    		    columns: [
                { title: _sgnListEscapeHTML(listUiI18n.p('lists.validation.list_column', 'List')) },
                { title: _sgnListEscapeHTML(listUiI18n.p('lists.validation.database_column', 'DB'))   }
    		    ]
    		});


    		jQuery('#adjust_case_action_button').prop('disabled', false);

    	    }
    	    else {
            jQuery('#wrong_case_message_div').text(listUiI18n.p('lists.validation.no_mismatched_cases', 'No mismatched cases found.'));
    	    }

    	    if (multiple_wrong_case !== undefined && multiple_wrong_case.length > 0) {
    		//alert(JSON.stringify(multiple_wrong_case));
    		jQuery('#multiple_wrong_case_table').DataTable( {
    		    destroy: true,
    		    data: multiple_wrong_case,
    		    sDom: 'lrtip',
    		    bInfo: false,
    		    paging: false,
    		    columns: [
                { title : _sgnListEscapeHTML(listUiI18n.p('lists.validation.list_column', 'List')) },
                { title : _sgnListEscapeHTML(listUiI18n.p('lists.validation.database_column', 'DB')) }
    		    ]
    		});
    	    }
    	    else {
    		jQuery('#multiple_case_match_message_div').html('');
    	    }

    	    jQuery('#adjust_case_action_button').off('click').on('click', function() {
    		jQuery.ajax( {
    		    url : '/ajax/list/adjust_case',
    		    data: { 'list_id' : list_id },
                error: function() { alert(listUiI18n.p('lists.validation.request_error', 'An error occurred')); },
    		    success: function(r) {

    			if (r.error) { alert(r.error); }

    			else {
                    alert(listUiI18n.p('lists.validation.converted_ids', 'Converted the following ids: %{ids}', {ids: JSON.stringify(r.mapping)}));
    			    var lo = new CXGN.List();
    			    lo.renderItems('list_item_dialog', list_id);

                    jQuery('#adjust_case_div').html("<br /><br /><h3>" + _sgnListEscapeHTML(listUiI18n.p('lists.validation.mismatched_case', 'Mismatched case')) + "</h3><b>" + _sgnListEscapeHTML(listUiI18n.p('lists.validation.case_adjusted', 'The case has been successfully adjusted.')) + "</b>");
    			    jQuery('#adjust_case_action_button').prop('disabled', true);
    			}
    		    }
    		});
    	    });

    	    var synonym_matches_table = new Array();

    	    for(var i=0; i<synonym_matches.length; i++) {
    		synonym_matches_table.push( [ synonym_matches[i]['synonym'], synonym_matches[i]['uniquename'] ] );
    	    }

    	    //alert(JSON.stringify(synonym_matches_table));

    	    jQuery('#replace_synonyms_with_uniquenames_button').off('click').on('click', function() {
    		jQuery.ajax( {
    		    url : '/ajax/list/adjust_synonyms',
    		    data: { 'list_id' : list_id },
                error: function() { alert(listUiI18n.p('lists.validation.request_error', 'An error occurred')); },
    		    success: function(r) {

    			if (r.error) { alert(r.error); return 1; }
    			else {
    			    var lo = new CXGN.List();
    			    lo.renderItems('list_item_dialog', list_id);

    			    jQuery('#synonym_matches_div').hide();
    			    jQuery('#synonym_message').show();
                    jQuery('#synonym_message').html("<br /><br /><h3>" + _sgnListEscapeHTML(listUiI18n.p('lists.validation.synonyms_heading', 'Synonyms')) + "</h3><b>" + _sgnListEscapeHTML(listUiI18n.p('lists.validation.synonyms_replaced', 'Synonyms have been successfully replaced with uniquenames.')) + "</b>");
    			    jQuery('#replace_synonyms_with_uniquenames_button').prop('disabled', true);
    			}
    		    }
    		});
    	    });

    	    if (synonym_matches.length > 0) {
    		jQuery('#synonym_matches_div').show();
    		jQuery('#synonym_message').html('');

    		jQuery('#element_matches_synonym').DataTable( {
    		    destroy: true,
    		    data: synonym_matches_table,
    		    sDom: 'lrtip',
    		    bInfo: false,
    		    paging: false,
    		    columns: [

                { title : _sgnListEscapeHTML(listUiI18n.p('lists.validation.synonym_list_column', 'List elements matching synonym')) },
                { title : _sgnListEscapeHTML(listUiI18n.p('lists.validation.synonym_db_column', 'Corresponding db names')) }
    		    ]
    		});
    	    }
    	    else {
    		jQuery('#synonym_matches_div').hide();
            jQuery('#synonym_message').text(listUiI18n.p('lists.validation.no_synonym_matches', 'No synonym matches found.'));
    	    }

	    var multiple_synonym_matches_table = new Array();

    	    for(var i=0; i< multiple_synonym_matches.length; i++) {
    		multiple_synonym_matches_table.push( [ multiple_synonym_matches[i][0], multiple_synonym_matches[i][1] ] );
    	    }

	    if (multiple_synonym_matches_table.length > 0) {
		jQuery('#multiple_synonym_matches_div').show();
		jQuery('#element_matches_multiple_synonyms_table').DataTable( {
    		    destroy: true,
    		    data: multiple_synonym_matches_table,
    		    sDom: 'lrtip',
    		    bInfo: false,
    		    paging: false,
    		    columns: [
                {title : _sgnListEscapeHTML(listUiI18n.p('lists.validation.item_column', 'Item')) },
                {title: _sgnListEscapeHTML(listUiI18n.p('lists.validation.synonym_column', 'Synonym'))}
    		    ]
    		});
    	    }


            jQuery('#validate_accession_error_display').modal("show");
            //alert("List validation failed. Elements not found: "+ missing.join(","));
            //return 0;
    	}
    	else {
	    var wc  = wrong_case || [];
	    var mwc = multiple_wrong_case || [];

	    // build lookups so we can split "missing" into real vs. case problems
	    var wc_map = {};
	    wc.forEach(function(p) { wc_map[p[0]] = p[1]; });

	    var mwc_map = {};
	    mwc.forEach(function(p) {
		(mwc_map[p[0]] = mwc_map[p[0]] || []).push(p[1]);
	    });

	    var truly_missing = missing.filter(function(m) {
		return !wc_map[m] && !mwc_map[m];
	    });

	    var msg = listUiI18n.p('lists.validation.failed_heading', 'List did not pass validation.') + '\n\n';

	    if (truly_missing.length > 0) {
		msg += listUiI18n.p('lists.validation.missing_heading', 'Not found in the database:') + '\n    ' + truly_missing.join(', ') + '\n\n';
	    }
	    if (wc.length > 0) {
		msg += listUiI18n.p('lists.validation.wrong_case_heading', 'Wrong case - change these in your list to match the database exactly:') + '\n';
		wc.forEach(function(p) {
		    msg += listUiI18n.p('lists.validation.wrong_case_pair', '    %{input}  to  %{database}', {input: p[0], database: p[1]}) + '\n';
		});
		msg += '\n';
	    }
	    if (mwc.length > 0) {
		msg += listUiI18n.p('lists.validation.multiple_case_heading', 'Matches more than one entry by case - fix the spelling manually:') + '\n';
		Object.keys(mwc_map).forEach(function(k) {
		    msg += listUiI18n.p('lists.validation.multiple_case_pair', '    %{input}  to  %{matches}', {input: k, matches: mwc_map[k].join(' / ')}) + '\n';
		});
	    }

	    alert(msg);
	    return 1;
    	}
    }
}
