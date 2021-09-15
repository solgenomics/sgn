
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





CXGN.List.prototype = {

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
                alert("An error occurred.");
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
                alert('An error occurred. Cannot determine type. ');
            }
        });

        return type;
    },

    setListType: function(list_id, type) {
        jQuery.ajax( {
            url: '/list/type/'+list_id+'/'+type,
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

        return types;
    },

    typesHtmlSelect: function(list_id, html_select_id, selected) {
        var types = this.allListTypes();
        var html = '<select class="form-control" id="'+html_select_id+'" onchange="javascript:changeListType(\''+html_select_id+'\', '+list_id+');" >';
        html += '<option name="null">(none)</option>';
        for (var i=0; i<types.length; i++) {
            var selected_html = '';
            if (types[i][1] == selected) {
                selected_html = ' selected="selected" ';
            }
            html += '<option name="'+types[i][1]+'"'+selected_html+'>'+types[i][1]+'</option>';
        }
        html += '</select>';
        return html;
    },

    newList: function(name, desc) {
        var oldListId = this.existsList(name);
        var newListId = 0;

        if (name == '') {
            alert('Please provide a name for the new list.');
            return 0;
        }

        if (oldListId === null) {
            jQuery.ajax( {
                url: '/list/new',
                async: false,
                data: { 'name': name, 'desc': desc },
                success: function(response) {
                    if (response.error) {
                        alert(response.error);
                    }
                    else {
                        newListId=response.list_id;
                    }
                }
            });
            return newListId;
        }
        else {
            alert('A list with name "'+ name + '" already exists. Please choose another list name.');
            return 0;
        }
        alert("An error occurred. Cannot create new list right now.");
        return 0;
    },

    availableLists: function(list_type) {
        var lists = [];
        jQuery.ajax( {
            url: '/list/available',
            data: { 'type': list_type },
            async: false,
            success: function(response) {
                if (response.error) {
                    //alert(response.error);  //do not alert here
                }
                lists = response;
            },
            error: function(response) {
                alert("An error occurred");
            }
        });
        return lists;
    },

    publicLists: function(list_type) {
        var lists = [];
        jQuery.ajax( {
            url: '/list/available_public',
            data: { 'type': list_type },
            async: false,
            success: function(response) {
                if (response.error) {
                    //alert(response.error); //do not alert here
                }
                lists = response;
            },
            error: function(response) {
                alert("An error occurred");
            }
        });
        return lists;
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
        var elements = items.join("\t");

        var count;
        jQuery.ajax( {
            async: false,
            method: 'POST',
            url: '/list/add/bulk',
            data:  { 'list_id': list_id, 'elements': elements },
            success: function(response) {
                if (response.error) {
                    alert(response.error);
                }
                else {
                    if (response.duplicates) {
                        alert("The following items are already in the list and were not added: "+response.duplicates.join(", "));
                    }
                    count = response.success;
                }
            },
            error: function(response) {
                alert("ERROR: "+response);
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
        var lists = this.availableLists();
        var html = '';
        html = html + '<div class="well well-sm"><form class="form-horizontal"><div class="form-group form-group-sm"><label class="col-sm-3 control-label">Create New List: </label><div class="col-sm-9"><div class="input-group"><input id="add_list_input" type="text" class="form-control" placeholder="Create New List. Type New List Name Here" /><span class="input-group-btn"><button class="btn btn-primary btn-sm" type="button" id="add_list_button" value="new list">New List</button></span></div></div></div><div class="form-group form-group-sm"><label class="col-sm-3 control-label"></label><div class="col-sm-9">';
        html = html + '<input id="add_list_input_description" type="text" class="form-control" placeholder="Description For New List" /></div></div></form></div>';

        if (lists.length===0) {
            html = html + "None";
            jQuery('#'+div+'_div').html(html);
        }

        html += '<div class="well well-sm"><table id="private_list_data_table" class="table table-hover table-condensed">';
        html += '<thead><tr><th>List Name</th><th>Description</th><th>Count</th><th>Type</th><th>Validate</th><th>View</th><th>Delete</th><th>Download</th><th>Share</th><th>Group</th></tr></thead><tbody>';
        for (var i = 0; i < lists.length; i++) {
            html += '<tr><td><a href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')"><b>'+lists[i][1]+'</b></a></td>';
            html += '<td>'+lists[i][2]+'</td>';
            html += '<td>'+lists[i][3]+'</td>';
            html += '<td>'+lists[i][5]+'</td>';
            html += '<td><a onclick="(new CXGN.List()).validate(\''+lists[i][0]+'\',\''+lists[i][5]+'\')"><span class="glyphicon glyphicon-ok"></span></a></td>';
            html += '<td><a title="View" id="view_list_'+lists[i][1]+'" href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></span></td>';
            html += '<td><a title="Delete" id="delete_list_'+lists[i][1]+'" href="javascript:deleteList('+lists[i][0]+')"><span class="glyphicon glyphicon-remove"></span></a></td>';
            html += '<td><a target="_blank" title="Download" id="download_list_'+lists[i][1]+'" href="/list/download?list_id='+lists[i][0]+'"><span class="glyphicon glyphicon-arrow-down"></span></a></td>';
            if (lists[i][6] == 0){
                html += '<td><a title="Make Public" id="share_list_'+lists[i][1]+'" href="javascript:togglePublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-share-alt"></span></a></td>';
            } else if (lists[i][6] == 1){
                html += '<td><a title="Make Private" id="share_list_'+lists[i][1]+'" href="javascript:togglePublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-ban-circle"></span></a></td>';
            }
            html += '<td><input type="checkbox" id="list_select_checkbox_'+lists[i][0]+'" name="list_select_checkbox" value="'+lists[i][0]+'"/></td></tr>';
        }
        html = html + '</tbody></table></div>';
        html += '<div id="list_group_select_action"></div>';

        jQuery('#'+div+'_div').html(html);

        jQuery('#private_list_data_table').DataTable({
            "destroy": true,
            "columnDefs": [   { "orderable": false, "targets": [4,5,6,7,8] }  ]
        });

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

        jQuery("input[name='list_select_checkbox']").click(function() {
            var total=jQuery("input[name='list_select_checkbox']:checked").length;
            var list_group_select_action_html='';
            if (total == 0) {
                list_group_select_action_html += '';
            } else {
                var selected = [];
                jQuery("input[name='list_select_checkbox']:checked").each(function() {
                    selected.push(jQuery(this).attr('value'));
                });

                list_group_select_action_html = '<hr><div class="row well well-sm"><div class="col-sm-4">For Selected Lists:</div><div class="col-sm-8">';
                if (total == 1) {
                    list_group_select_action_html += '<a id="delete_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:deleteSelectedListGroup(['+selected+'])">Delete</a>&nbsp;<a id="make_public_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:makePublicSelectedListGroup(['+selected+'])">Make Public</a>&nbsp;<a id="make_private_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:makePrivateSelectedListGroup(['+selected+'])">Make Private</a>';
                } else if (total > 1) {
                    list_group_select_action_html += '<a id="delete_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:deleteSelectedListGroup(['+selected+'])">Delete</a>&nbsp;<a id="make_public_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:makePublicSelectedListGroup(['+selected+'])">Make Public</a>&nbsp;<a id="make_private_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:makePrivateSelectedListGroup(['+selected+'])">Make Private</a><br/><br/><div class="input-group input-group-sm"><input type="text" class="form-control" id="new_combined_list_name" placeholder="New List Name"><span class="input-group-btn"><a id="combine_selected_list_group" class="btn btn-primary btn-sm" style="color:white" href="javascript:combineSelectedListGroup(['+selected+'])">Combine</a></span></div>';
                }
                list_group_select_action_html += '</div></div>';
            }
            jQuery("#list_group_select_action").html(list_group_select_action_html);
        });
    },

    renderPublicLists: function(div) {
        var lists = this.publicLists();
        var html = '';

        html += '<table id="public_list_data_table" class="table table-hover table-condensed">';
        html += '<thead><tr><th>List Name</th><th>Description</th><th>Count</th><th>Type</th><th>Validate</th><th>View</th><th>Download</th><th>Copy To Your Lists</th><th>Owner</th><th>Make Private</th></tr></thead><tbody>';
        for (var i = 0; i < lists.length; i++) {
            html += '<tr>';
            html += '<td><a href="javascript:showPublicListItems(\'list_item_dialog\','+lists[i][0]+')"><b>'+lists[i][1]+'</b></a></td>';
            html += '<td>'+lists[i][2]+'</td>';
            html += '<td>'+lists[i][3]+'</td>';
            html += '<td>'+lists[i][5]+'</td>';
            html += '<td><a onclick="(new CXGN.List()).validate(\''+lists[i][0]+'\',\''+lists[i][5]+'\')"><span class="glyphicon glyphicon-ok"></span></a></td>';
            html += '<td><a title="View" id="view_public_list_'+lists[i][1]+'" href="javascript:showPublicListItems(\'list_item_dialog\','+lists[i][0]+')"><span class="glyphicon glyphicon-th-list"></span></a></td>';
            html += '<td><a target="_blank" title="Download" id="download_public_list_'+lists[i][1]+'" href="/list/download?list_id='+lists[i][0]+'"><span class="glyphicon glyphicon-arrow-down"></span></a></td>';
            html += '<td><a title="Copy to Your Lists" id="copy_public_list_'+lists[i][1]+'" href="javascript:copyPublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-plus"></span></a></td>';
            html += '<td>'+lists[i][6]+'</td>';
            html += '<td><a title="Make Private" href="javascript:togglePublicList('+lists[i][0]+')"><span class="glyphicon glyphicon-ban-circle"></span></a></td>';
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

        var list_data = this.getListData(list_id);
        var list_description = list_data.description;
        var items = list_data.elements;
        var list_type = list_data.type_name;
        var list_name = this.listNameById(list_id);
        var html = '';

        if (list_type == 'catalog_items') {
            html += '<div class="well well-sm"><table id="list_cart_item_dialog_datatable" class="table table-condensed table-hover table-bordered"><thead style="display: none;"><tr><th><b>List items</b> ('+items.length+')</th><th>&nbsp;</th></tr></thead><tbody>';

            for(var n=0; n<items.length; n++) {
                html = html +'<tr><td>'+ items[n][1] + '</td><td><input id="'+items[n][0]+'" type="button" class="btn btn-default btn-xs" value="Remove" /></td></tr>';
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
        html += '<table class="table"><tr><td>List ID</td><td id="list_id_div">'+list_id+'</td></tr>';
        html += '<tr><td>List name:<br/><input type="button" class="btn btn-primary btn-xs" id="updateNameButton" value="Update" /></td>';
        html += '<td><input class="form-control" type="text" id="updateNameField" size="10" value="'+list_name+'" /></td></tr>';
        html += '<tr><td>Description:<br/><input type="button" class="btn btn-primary btn-xs" id="updateListDescButton" value="Update" /></td>';
        html += '<td><input class="form-control" type="text" id="updateListDescField" size="10" value="'+list_description+'" /></td></tr>';
        html += '<tr><td>Type:<br/><input id="list_item_dialog_validate" type="button" class="btn btn-primary btn-xs" value="Validate" onclick="javascript:validateList('+list_id+',\'type_select\')" title="Validate list. Checks if elements exist with the selected type."/><div id="fuzzySearchStockListDiv"></div><div id="synonymListButtonDiv"></div><div id="availableSeedlotButtonDiv"></div></td><td>'+this.typesHtmlSelect(list_id, 'type_select', list_type)+'</td></tr>';
        html += '<tr><td>Add New Items:<br/><button class="btn btn-primary btn-xs" type="button" id="dialog_add_list_item_button" value="Add">Add</button></td><td><textarea id="dialog_add_list_item" type="text" class="form-control" placeholder="Add Item(s) To List. Separate items using a new line to add many items at once." /></textarea></td></tr></table>';

        html += '<hr><div class="well well-sm"><div class="row"><div class="col-sm-6"><center><button class="btn btn-default" onclick="(new CXGN.List()).sortItems('+list_id+', \'ASC\')" title="Sort items in list in ascending order (e.g. A->Z and/or 0->9)">Sort Ascending <span class="glyphicon glyphicon-sort-by-alphabet"></span></button></center></div><div class="col-sm-6"><center><button class="btn btn-default" onclick="(new CXGN.List()).sortItems('+list_id+', \'DESC\')" title="Sort items in list in descending order (e.g. Z->A and/or 9->0)">Sort Descending <span class="glyphicon glyphicon-sort-by-alphabet-alt"></span></button></center></div></div></div>';
        html += '<div class="well well-sm"><table id="list_item_dialog_datatable" class="table table-condensed table-hover table-bordered"><thead style="display: none;"><tr><th><b>List items</b> ('+items.length+')</th><th>&nbsp;</th></tr></thead><tbody>';

        for(var n=0; n<items.length; n++) {
            html = html +'<tr><td id="list_item_toggle_edit_div_'+items[n][0]+'" ><div name="list_item_toggle_edit" data-listitemdiv="list_item_toggle_edit_div_'+items[n][0]+'" data-listitemid="'+items[n][0]+'" data-listitemname="'+items[n][1]+'" >'+ items[n][1] + '</div></td><td><input id="'+items[n][0]+'" type="button" class="btn btn-default btn-xs" value="Remove" /></td></tr>';
        }
        html += '</tbody></table></div>';

        jQuery('#'+div+'_div').html(html);

        jQuery('#list_item_dialog_datatable').DataTable({
            destroy: true,
            ordering: false,
            scrollY:        '30vh',
            scrollCollapse: true,
            paging:         false,
        });

        }

        if (list_type == 'accessions' || list_type == 'crosses'){
            jQuery('#availableSeedlotButtonDiv').html('<br/><button id="availableSeedlotButton" class="btn btn-primary btn-xs" onclick="(new CXGN.List()).seedlotSearch('+list_id+')" title="Will display seedlots that have contents of an item in your list.">See Available Seedlots</button>');
        }
        if (['seedlots', 'plots', 'accessions', 'vector_constructs', 'crosses', 'populations', 'plants', 'tissue_samples', 'family_names'].indexOf(list_type) >= 0){
            jQuery('#synonymListButtonDiv').html('<br/><button id="synonymListButton" class="btn btn-primary btn-xs" onclick="(new CXGN.List()).synonymSearch('+list_id+')" title="Will display whether the items in your list are synonyms or actual uniquenames.">Find Synonyms</button>');
            jQuery('#fuzzySearchStockListDiv').html('<br/><button id="fuzzySearchStockListButton" class="btn btn-primary btn-xs" onclick="javascript:fuzzySearchList('+list_id+',\''+list_type+'\')" title="Will display if the items in your list are uniquenames in the database or whether they look very similar to other accessions in the database.">Fuzzy Search</button>');
        }
        jQuery(document).on("change", "#type_select", function(){
            if (jQuery('#type_select').val() == 'accessions' || jQuery('#type_select').val() == 'crosses'){
                jQuery('#availableSeedlotButtonDiv').html('<br/><button id="availableSeedlotButton" class="btn btn-primary btn-xs" onclick="(new CXGN.List()).seedlotSearch('+list_id+')" title="Will display seedlots that have contents of an item in your list.">See Available Seedlots</button>');
            } else {
                jQuery('#availableSeedlotButtonDiv').html('');
            }

            if (['seedlots', 'plots', 'accessions', 'vector_constructs', 'crosses', 'populations', 'plants', 'tissue_samples', 'family_names'].indexOf(jQuery('#type_select').val()) >= 0){
                jQuery('#synonymListButtonDiv').html('<br/><button id="synonymListButton" class="btn btn-primary btn-xs" onclick="(new CXGN.List()).synonymSearch('+list_id+')" title="Will display whether the items in your list are synonyms or actual uniquenames.">Find Synonyms</button>');
                jQuery('#fuzzySearchStockListDiv').html('<br/><button id="fuzzySearchStockListButton" class="btn btn-primary btn-xs" onclick="javascript:fuzzySearchList('+list_id+',\''+jQuery('#type_select').val()+'\')" title="Will display if the items in your list are uniquenames in the database or whether they look very similar to other accessions in the database.">Fuzzy Search</button>');
            } else {
                jQuery('#synonymListButtonDiv').html('');
                jQuery('#fuzzySearchStockListDiv').html('');
            }
        });

        for (var n=0; n<items.length; n++) {
            var list_item_id = items[n][0];

            jQuery('#'+items[n][0]).click( function() {
                var lo = new CXGN.List();
                var i = lo.availableLists();

                lo.removeItem(list_id, this.id );
                lo.renderItems(div, list_id);
                lo.renderLists('list_dialog');
            });
        }

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

        jQuery('div[name="list_item_toggle_edit"]').click(function() {
            var list_item_id = jQuery(this).data('listitemid');
            var list_item_name = jQuery(this).data('listitemname');
            var list_item_div = jQuery(this).data('listitemdiv');
            var list_item_edit_html = '<div class="input-group"><input type="text" class="form-control" value="'+list_item_name+'" placeholder="'+list_item_name+'" id="list_item_edit_input_'+list_item_id+'" data-listitemid="'+list_item_id+'" /><span class="input-group-btn"><button class="btn btn-default" type="button" name="list_item_edit_submit" data-inputid="list_item_edit_input_'+list_item_id+'">Ok</button></span></div>';
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
        var list_data = this.getListData(list_id);
        var items = list_data.elements;
        var list_type = list_data.type_name;
        var list_name = this.publicListNameById(list_id);

        var html = '';
        html += '<table class="table"><tr><td>List ID</td><td id="list_id_div">'+list_id+'</td></tr>';
        html += '<tr><td>List name:</td>';
        html += '<td>'+list_name+'</td></tr>';
        html += '<tr><td>Type:</td><td>'+list_type+'</td></tr>';
        html += '</table>';
        html += '<table id="public_list_item_dialog_datatable" class="table table-condensed table-hover table-bordered"><thead style="display: none;"><tr><th><b>List items</b> ('+items.length+')</th></tr></thead><tbody>';
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
        var list_id = 0;
        jQuery.ajax( {
            url: '/list/exists',
            async: false,
            data: { 'name': name },
            success: function(response) {
                list_id = response.list_id;
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

    /* listSelect: Creates an html select with lists of requested types.

       Parameters:
         div_name: The div_name where the select should appear
         types: a list of list types that should be listed in the menu
         add_empty_element: text. if present, add an empty element with the
           provided text as description
    */

    listSelect: function(div_name, types, empty_element, refresh, hide_public_lists) {
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

        var html = '<select class="form-control input-sm" id="'+div_name+'_list_select" name="'+div_name+'_list_select" >';
        if (empty_element) {
            html += '<option value="" >'+empty_element+'</option>\n';
        }
        html += '<option disabled>--------YOUR LISTS BELOW--------</option>';
        for (var n=0; n<lists.length; n++) {
            html += '<option value='+lists[n][0]+'>'+lists[n][1]+'</option>';
        }
        if (hide_public_lists == undefined) {
            html += '<option disabled>--------PUBLIC LISTS BELOW--------</option>';
            for (var n=0; n<public_lists.length; n++) {
                html += '<option value='+public_lists[n][0]+'>'+public_lists[n][1]+'</option>';
            }
        }

        if (refresh) {
            if (types.length > 1) { types = types.join(',') }
            html = '<div class="input-group" id="'+div_name+'_list_select_div">'+html+'</select><span class="input-group-btn"><button class="btn btn-default" type="button" id="'+div_name+'_list_refresh" title="Refresh lists" onclick="refreshListSelect(\''+div_name+'\',\''+types+'\')"><span class="glyphicon glyphicon-refresh" aria-hidden="true"></span></button></span></div>';
            return html;
        }
        else {
            html = html + '</select>';
            return html;
        }
    },

    updateName: function(list_id, new_name) {
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
                    alert("The name of the list was changed to "+new_name);
                }
            },
            error: function(response) { alert("An error occurred."); }
        });
        this.renderLists('list_dialog');
    },

    updateDescription: function(list_id, new_description) {
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
                    alert("The description of the list was changed to "+new_description);
                }
            },
            error: function(response) { alert("An error occurred."); }
        });
        this.renderLists('list_dialog');
    },

    sortItems: function(list_id, sort) {
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
            error: function(response) { alert("An error occurred in sort."); }
        });
        this.renderItems('list_item_dialog', list_id);
    },

    validate: function(list_id, type, non_interactive) {
        var missing = new Array();
	var wrong_case = new Array();
	var multiple_wrong_case = new Array();
	var synonym_matches = new Array();
	var multiple_synonyms = new Array();

        var error = 0;
        jQuery.ajax( {
            url: '/list/validate/'+list_id+'/'+type,
            async: false,
            success: function(response) {
                //console.log(response);
                if (response.error) {
                    alert(response.error);
                } else {
		    //alert(JSON.stringify(response));
                    missing = response.missing;
		    wrong_case = response.wrong_case;
		    multiple_wrong_case = response.multiple_wrong_case;
		    synonym_matches = response.synonyms;
		    multiple_synonyms = response.multiple_synonyms;
                }
            },
            error: function(response) {
                alert("An error occurred while validating the list "+list_id);
                error=1;
            }
        });

        if (error === 1 ) { return; }


        if (type == 'accessions' && missing.length==0 && wrong_case.length==0) {
            if (!non_interactive) { alert("This list passed validation."); }
            return 1;
        } else if (type != 'accessions' && missing.length == 0) {
            if (!non_interactive) { alert("This list passed validation."); }
            return 1;
        } else {
            if (!non_interactive) {
                if (type == 'accessions') {
                    jQuery("#validate_accession_error_display tbody").html('');

                    var missing_accessions_link = "<button class='btn btn-primary' onclick=\"window.location.href='/breeders/accessions?list_id="+list_id+"'\" >Go to Manage Accessions to add these new accessions to database now.</button><br /><br />";

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
				{ title: 'List' },
				{ title: 'DB' },
			    ]
			});


                    jQuery("#validate_stock_add_missing_accessions_for_list").html(missing_accessions_vals_for_list);

                    addToListMenu('validate_stock_add_missing_accessions_for_list_div', 'validate_stock_add_missing_accessions_for_list', {
                        selectText: true,
                        listType: 'accessions'
                    });


		    var wrong_case_accessions_for_list = '';

		    jQuery('#wrong_case_message_div').html('');

		    if (wrong_case.length > 0) {
			//alert(JSON.stringify(wrong_case));
			jQuery('#wrong_case_table').DataTable( {
			    destroy: true,
			    data: wrong_case,
			    sDom: 'lrtip',
			    bInfo: false,
			    paging: false,
			    columns: [
				{ title: 'List' },
				{ title: 'DB'   }
			    ]
			});


			jQuery('#adjust_case_action_button').prop('disabled', false);

		    }
		    else {
			jQuery('#wrong_case_message_div').html('No mismatched cases found.');
		    }

		    if (multiple_wrong_case.length > 0) {
			//alert(JSON.stringify(multiple_wrong_case));
			jQuery('#multiple_wrong_case_table').DataTable( {
			    destroy: true,
			    data: multiple_wrong_case,
			    sDom: 'lrtip',
			    bInfo: false,
			    paging: false,
			    columns: [
				{ title : 'List' },
				{ title : 'DB' }
			    ]
			});
		    }
		    else {
			jQuery('#multiple_case_match_message_div').html('');
		    }

		     jQuery('#adjust_case_action_button').click( function() {
		    	 jQuery.ajax( {
		    	     url : '/ajax/list/adjust_case',
			     data: { 'list_id' : list_id },
		    	     error: function() { alert('An error occurred'); },
		    	     success: function(r) {

				 if (r.error) { alert(r.error); }

				 else {
				     alert('Converted the following ids: '+JSON.stringify(r.mapping));
				     var lo = new CXGN.List();
				     lo.renderItems('list_item_dialog', list_id);

				     jQuery('#adjust_case_div').html("<br /><br /><h3>Mismatched case</h3><b>The case has been successfully adjusted.</b>");
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

		    jQuery('#replace_synonyms_with_uniquenames_button').click( function() {
		    	jQuery.ajax( {
		    	    url : '/ajax/list/adjust_synonyms',
			    data: { 'list_id' : list_id },
		    	    error: function() { alert('An error occurred'); },
		    	    success: function(r) {

				if (r.error) { alert(r.error); }
				else {
				    var lo = new CXGN.List();
				    lo.renderItems('list_item_dialog', list_id);

				    jQuery('#synonym_matches_div').hide();
				    jQuery('#synonym_message').show();
				    jQuery('#synonym_message').html("<br /><br /><h3>Synonyms</h3><b>Synonyms have been successfully replaced with uniquenames.</b>");
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

				{ title : 'List elements matching synonym' },
				{ title : 'Corresponding db names' }
			    ]
			});
		    }
		    else {
			jQuery('#synonym_matches_div').hide();
			jQuery('#synonym_message').html('No synonym matches found.');
		    }

		    if (multiple_synonyms.count > 0) {
			jQuery('#element_matches_multiple_synonyms_table').DataTable( {
			    destroy: true,
			    data: multiple_synonyms,
			    sDom: 'lrtip',
			    bInfo: false,
			    paging: false,
			    columns: [
				{title : 'Item' },
				{title: 'Synonym'}
			    ]
			});
		    }

                    jQuery('#validate_accession_error_display').modal("show");
                    //alert("List validation failed. Elements not found: "+ missing.join(","));
                    //return 0;
		}
		else {
                    alert('List did not pass validation because of these items: '+missing.join(", "));
		}
            }
            return;
	}
    },

    seedlotSearch: function(list_id){
        var self = this;
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
                alert("List \""+form["name"]+"\" created with "+count+" entries.");
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
                    html += "<table class='table table-hover table-bordered'><thead><tr><th>Name in List</th><th>Unique Name</th></tr></thead><tbody>";
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
                                html+="<td><span style='color:red'>&times; Not a Name or Synonym</span></td></tr>";
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
                            alert("List \""+form["name"]+"\" created with "+count+" entries.");
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
                    alert("An error occurred while desynonymizing list ID:"+list_id);
                }
            },
            error: function(response) {
                alert("An error occurred while desynonymizing list ID:"+list_id);
                jQuery('#working_modal').modal('hide');
                error=1;
            }
        });
    },

    fuzzySearch: function(list_id, list_type) {
        var error = 0;
        jQuery.ajax( {
            url: '/list/fuzzysearch/'+list_id+'/'+list_type,
            async: false,
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                //console.log(response);
                var html = "";
                var list_type_name = list_type.charAt(0).toUpperCase() + list_type.slice(1);
                if (response.success) {
                    html += "<h2>"+list_type_name+" that exactly match as uniquenames (not synonyms)</h2>";
                    html += "<table class='table table-hover table-bordered' ><thead><tr><th>Found In Database</th></tr></thead><tbody>";
                    for(var i=0; i<response.found.length; i++){
                        html += "<tr><td>"+response.found[i].unique_name+"</td></tr>";
                    }
                    html += "</tbody></table>";
                    html += "<h2>"+list_type_name+" that are not found in the database, but fuzzy match (names are visibily similar)</h2>";
                    html += "<table class='table table-hover table-bordered' ><thead><tr><th>Name In Your List</th><th>Found In Database</th><th>Distance Score</th></tr></thead><tbody>";
                    for(var i=0; i<response.fuzzy.length; i++){
                        for(j=0; j <response.fuzzy[i].matches.length; j++){
                            if (response.fuzzy[i].matches[j].is_synonym){
                                html += "<tr><td>"+response.fuzzy[i].name+"</td><td>"+response.fuzzy[i].matches[j].name+" (SYNONYM OF: "+response.fuzzy[i].matches[j].synonym_of+") </td><td>"+response.fuzzy[i].matches[j].distance+"</td></tr>";
                            } else {
                                html += "<tr><td>"+response.fuzzy[i].name+"</td><td>"+response.fuzzy[i].matches[j].name+"</td><td>"+response.fuzzy[i].matches[j].distance+"</td></tr>";
                            }
                        }
                    }
                    html += "</tbody></table>";
                    html += "<h2>"+list_type_name+" that are not found in the database and have no match</h2>";
                    html += "<table class='table table-hover table-bordered' ><thead><tr><th>Not Found In Database</th></tr></thead><tbody>";
                    for(var i=0; i<response.absent.length; i++){
                        html += "<tr><td>"+response.absent[i]+"</td></tr>";
                    }
                    html += "</tbody></table>";
                    html += "<form id='fuzzy_search_result_download' method='post' action='/ajax/accession_list/fuzzy_download' target='TheWindow'><input type='hidden' name='fuzzy_response' value='"+JSON.stringify(response.fuzzy)+"' /></form>";
                    jQuery('#fuzzy_search_result_display_html').html(html);
                    jQuery('#fuzzy_search_result_display').modal('show');
                } else {
                    alert("An error occurred while fuzzy searching list "+list_id);
                }
            },
            error: function(response) {
                alert("An error occurred while fuzzy searching the list "+list_id);
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
            error: function(response) { alert("An error occurred while validating the list "+list_id); }
        });
        return ajaxResponse.transform;
    },

    transform2Ids: function(list_id, data) {
        if (data === undefined) var data = this.getListData(list_id);
        //console.log("data ="+JSON.stringify(data));
        var list_type = data.type_name;

        var new_type;
        switch (list_type)
        {
            case "traits":
                new_type = 'traits_2_trait_ids';
                break;
            case "locations":
                new_type = 'locations_2_location_ids';
                break;
            case "trials":
            case "breeding_programs":
                new_type = 'projects_2_project_ids';
                break;
            case "accessions":
                new_type = 'accessions_2_accession_ids';
                break;
            case "plots":
                new_type = 'plots_2_plot_ids';
                break;
            case "seedlots":
                new_type = 'stocks_2_stock_ids';
                break;
            default:
                return { 'error' : "cannot convert the list because of unknown type" };
        }
        //if (window.console) console.log("new type = "+new_type);
        var transformed = this.transform(list_id, new_type);
        //if (window.console) console.log("transformed="+JSON.stringify(transformed));
        return transformed;

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
    document.getElementById(div_name).innerHTML = (lo.listSelect(div_name, types, 'Options refreshed.', 'refresh', undefined));
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

    html = '<div class="row"><div class="col-sm-6" style="margin-right:0px; padding-right:0px;"><input class="form-control input-sm" type="text" id="'+dataDiv+'_new_list_name" placeholder="New list..." value="'+list_name_value+'"/>';
    html += '</div><div class="col-sm-6" style="margin-left:0px; padding-left:0px; margin-right:0px; padding-right:0px;"><input type="hidden" id="'+dataDiv+'_addition_type" value="'+addition_type+'" /><input type="hidden" id="'+dataDiv+'_list_type" value="'+type+'" />';
    html += '<input class="btn btn-primary btn-sm" id="'+dataDiv+'_add_to_new_list" type="button" value="add to new list" /></div></div><br />';

    html += '<div class="row"><div class="col-sm-6" style="margin-right:0px; padding-right:0px;">'+lo.listSelect(dataDiv, [ type ], undefined, undefined, 1);

    html += '</div><div class="col-sm-6" style="margin-left:0px; padding-left:0px; margin-right:0px; padding-right:0px;"><input class="btn btn-primary btn-sm" id="'+dataDiv+'_button" type="button" value="add to list" /></div></div>';

    jQuery('#'+listMenuDiv).html(html);

    var list_id = 0;

    jQuery('#'+dataDiv+'_add_to_new_list').click( function() {
        var lo = new CXGN.List();
        var new_name = jQuery('#'+dataDiv+'_new_list_name').val();
        var type = jQuery('#'+dataDiv+'_list_type').val();
        var addition_type = jQuery('#'+dataDiv+'_addition_type').val();

        var data = getData(dataDiv, selectText);
        list_id = lo.newList(new_name);
        if (list_id > 0) {
            var elementsAdded;
            if (addition_type == 'cross_progeny') {
                elementsAdded = lo.addCrossProgenyToList(list_id, data);
            } else {
                elementsAdded = lo.addToList(list_id, data);
            }
            if (type) {
                lo.setListType(list_id, type);
            }
            alert("Added "+elementsAdded+" list elements to list "+new_name+" and set type to "+type);
        }
    });

    jQuery('#'+dataDiv+'_button').click( function() {
        var data = getData(dataDiv, selectText);
        list_id = jQuery('#'+dataDiv+'_list_select').val();
        var lo = new CXGN.List();
        var elementsAdded = lo.addToList(list_id, data);

        alert("Added "+elementsAdded+" list elements");
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
        if (jQuery.browser.msie) {
            // Note: MS IE unfortunately removes all whitespace
            // in the jQuery().text() call. Program it out...
            //
            var selectbox = document.getElementById(id);
            var datalist = new Array();
            for (var n=0; n<selectbox.length; n++) {
                if (selectbox.options[n].selected) {
                    var x=selectbox.options[n].text;
                    datalist.push(x);
                }
            }
            data = datalist.join("\n");
            //alert("data:"+data);

        }
        else {
            data = jQuery('#'+id+" option:selected").text();
        }

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
    html = html + '<input id="'+div+'_button" type="button" value="add to list" />';

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
    html = html + '<input id="'+div+'_button" type="button" value="add to list" />';

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
    var lo = new CXGN.List();
    var item = jQuery('#'+div).val();
    var id = lo.addItem(list_id, item);
    if (id == 0) {
        alert('Item "'+item+'" was not added because it already exists');
    }
    lo.renderLists('list_dialog');
}

/* deprecated */
function addMultipleItemsToList(div, list_id) {
    var lo = new CXGN.List();
    var content = jQuery('#'+div).val();
    if (content == '') {
        alert("No items - Please enter items to add to the list.");
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
    //	alert("The following items were not added because they are already in the list: "+ duplicates.join(", "));
    //  }
    //lo.renderLists('list_dialog');
}

/* deprecated */
function addArrayToList(items, list_id) {
    var lo = new CXGN.List();
    var duplicates = new Array();
    for (var n=0; n<items.length; n++) {
        var id = lo.addItem(list_id, items[n]);
        if (id == 0) {
            duplicates.push(items[n]);
        }
    }
    if (duplicates.length >0) {
        alert("The following items were not added because they are already in the list: "+ duplicates.join(", "));
    }
}

function deleteList(list_id) {
    var lo = new CXGN.List();
    var list_name = lo.listNameById(list_id);
    if (confirm('Delete list "'+list_name+'"? (ID='+list_id+'). This cannot be undone.')) {
        lo.deleteList(list_id);
        lo.renderLists('list_dialog');
        alert('Deleted list '+list_name);
    }
}

function togglePublicList(list_id) {
    jQuery.ajax({
        "url": "/list/public/toggle",
        "type": "POST",
        "data": {'list_id': list_id},
        success: function(r) {
            var lo = new CXGN.List();
            if (r.error) {
                alert(r.error);
            } else if (r.r == 1) {
                alert("List set to Private");
            } else if (r.r == 0) {
                alert("List set to Public");
            }
            lo.renderLists('list_dialog');
        },
        error: function() {
            alert("Error Setting List to Public! List May Not Exist.");
        }
    });
    var lo = new CXGN.List();
    lo.renderLists('list_dialog');
}

function makePublicList(list_id) {
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
            alert("Error Setting List to Public! List May Not Exist.");
        }
    });
}

function makePrivateList(list_id) {
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
            alert("Error Setting List to Private! List May Not Exist.");
        }
    });
}

function copyPublicList(list_id) {
    jQuery.ajax({
        "url": "/list/public/copy",
        "type": "POST",
        "data": {'list_id': list_id},
        success: function(r) {
            if (r.error) {
                alert(r.error);
            } else if (r.success == 'true') {
                alert("Public List Copied to Your Lists.");
            }
        },
        error: function() {
            alert("Error Copying Public List! List May Not Exist.");
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
    var lo = new CXGN.List();
    var name = jQuery('#'+div_id).val();

    if (name == '') {
        alert("Please specify a name for the list.");
        return;
    }

    var list_id = lo.existsList(name);
    if (list_id > 0) {
        alert('The list '+name+' already exists. Please choose another name.');
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

function validateList(list_id, html_select_id) {
    var lo = new CXGN.List();
    var type = jQuery('#'+html_select_id).val();
    lo.validate(list_id, type);
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
    var arrayLength = list_ids.length;
    if (confirm('Delete the selected lists? This cannot be undone.')) {
        for (var i=0; i<arrayLength; i++) {
            var lo = new CXGN.List();
            lo.deleteList(list_ids[i]);
        }
        lo.renderLists('list_dialog');
    }
}

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
    var arrayLength = list_ids.length;
    if (confirm('Make selected lists public?')) {
        for (var i=0; i<arrayLength; i++) {
            makePublicList(list_ids[i]);
        }
        var lo = new CXGN.List();
        lo.renderLists('list_dialog');
    }
}

function makePrivateSelectedListGroup(list_ids) {
    var arrayLength = list_ids.length;
    if (confirm('Make selected lists private?')) {
        for (var i=0; i<arrayLength; i++) {
            makePrivateList(list_ids[i]);
        }
        var lo = new CXGN.List();
        lo.renderLists('list_dialog');
    }
}

function combineSelectedListGroup(list_ids) {
    var arrayLength = list_ids.length;
    var list_name = jQuery('#new_combined_list_name').val();
    if (confirm('Combine selected lists into a new list called '+list_name+'?')) {
        var arrayItems = [];
        var lo = new CXGN.List();
        var first_list_type = lo.getListType(list_ids[0]);
        var same_list_types = true;
        for (var i=0; i<arrayLength; i++) {
            var list_type = lo.getListType(list_ids[i]);
            if (list_type != first_list_type) {
                same_list_types = false;
                if (!confirm('Are you sure you want to combine these list types: '+first_list_type+' and '+list_type)) {
                    return;
                }
            }
        }
        var new_list_id = lo.newList(list_name);
        if (same_list_types == true) {
            lo.setListType(new_list_id, first_list_type);
        }
        for (var i=0; i<arrayLength; i++) {
            list = lo.getListData(list_ids[i]);
            var numElements = list.elements.length;
            for (var j=0; j<numElements; j++) {
                arrayItems.push(list.elements[j][1]);
            }
        }
        lo.addBulk(new_list_id, arrayItems);
        lo.renderLists('list_dialog');
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
