
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
	    error: alert('An error occurred. Cannot determine type. ')
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
		    alert('Type of list '+list_id+' set to '+type);
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
	var html = '<select id="'+html_select_id+'" onchange="javascript:changeListType(\''+html_select_id+'\', '+list_id+');" >';
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

    newList: function(name) { 
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
		data: { 'name': name },
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
		    //alert(response.error);
		}
		lists = response;
		//alert("LISTS OF TYPE "+list_type+": "+lists.join(","));
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
	html = html + '<input id="add_list_input" type="text" /><input id="add_list_button" type="button" value="new list" /><br />';
	
	if (lists.length===0) { 
	    html = html + "None";
	    jQuery('#'+div).html(html);
	}

	html += '<table border="0" cellpadding="2" title="Available lists">';
	html += '<tr><td><i>list name</i></td><td><i>#</i></td><td><i>type</i></td><td colspan="3"><i>actions</i></td></tr>\n'; 
	for (var i = 0; i < lists.length; i++) { 
	    html += '<tr><td><b>'+lists[i][1]+'</b></td>';
	    html += '<td>'+lists[i][3]+'</td>';
	    html += '<td>'+lists[i][5]+'</td>';
	    html += '<td><a id="view_list_'+lists[i][1]+'" href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')">view</a></td><td>|</td>';
	    html += '<td><a id="delete_list_'+lists[i][1]+'" href="javascript:deleteList('+lists[i][0]+')">delete</a></td><td>|</td>';
	    html += '<td><a id="download_list_'+lists[i][1]+'" href="/list/download?list_id='+lists[i][0]+'">download</a></td></tr>\n';
	}
	html = html + '</table>';

	jQuery('#'+div).html(html);

	jQuery('#add_list_button').click(function() { 
	    var lo = new CXGN.List();
	    
	    var name = jQuery('#add_list_input').val();
	    
	    lo.newList(name);
	    lo.renderLists(div);
	});
    },
    
    listNameById: function(list_id) { 
	lists = this.availableLists();
	for (var n=0; n<lists.length; n++) { 
	    if (lists[n][0] == list_id) { return lists[n][1]; }
	}
    },

    renderItems: function(div, list_id) { 
	var list_data = this.getListData(list_id);
	var items = list_data.elements;
	var list_type = list_data.type_name;
	var list_name = this.listNameById(list_id);
	
	var html = '';
	html += '<table><tr width="100"><td>List name ';
	
	html += '</td><td><input type="text" id="updateNameField" size="10" value="'+list_name+'" /></td>';
        html += '<td><input type="button" id="updateNameButton" value="update"  /></td>';
	html += '<td width="100%" align="right"><font size="1">List ID</td><td><div id="list_id_div" style="font-size:tiny" >'+list_id+'</div></font></td></tr>';

	html += '<tr><td>Type</td><td>'+this.typesHtmlSelect(list_id, 'type_select', list_type)+'</td><td colspan="2"><input type="button" value="validate" onclick="javascript:validateList('+list_id+',\'type_select\')"  /></td></tr></table>';
	html += 'Add new items: <br /><textarea id="dialog_add_list_item" ></textarea><input id="dialog_add_list_item_button" type="submit" value="Add" /><br />';
	html += '<b>List items</b> ('+items.length+')<br />';

	for(var n=0; n<items.length; n++) { 
	    html = html + items[n][1] + '   <input id="'+items[n][0]+'" type="button" value="remove" /><br />';   
	}
	
	jQuery('#'+div).html(html);

	for (var n=0; n<items.length; n++) { 
	    var list_item_id = items[n][0];

	    jQuery('#'+items[n][0]).click(
		function() { 
		    var lo = new CXGN.List();
		    var i = lo.availableLists();
		    
		    lo.removeItem(list_id, this.id );
		    lo.renderItems(div, list_id);
		    lo.renderLists('list_dialog');
		});
	}
    
	
	jQuery('#dialog_add_list_item_button').click(
	    function() { 
                jQuery('#working').dialog("open");
		addMultipleItemsToList('dialog_add_list_item', list_id);
		var lo = new CXGN.List();
		lo.renderItems(div, list_id);
		jQuery('#working').dialog("close");
	    }
	);
	
	jQuery('#updateNameButton').click(
	    function() { 
		var lo = new CXGN.List();
		var new_name =  jQuery('#updateNameField').val();
		var list_id = jQuery('#list_id_div').html();
		lo.updateName(list_id, new_name);
		alert("Changed name to "+new_name+" for list id "+list_id);
	    }
	);
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

    /* listSelect: Creates an html select with lists of requested types.
 
       Parameters: 
         div_name: The div_name where the select should appear
         types: a list of list types that should be listed in the menu
         add_empty_element: text. if present, add an empty element with the
           provided text as description
    */
    
    listSelect: function(div_name, types, empty_element) { 	
	var lists = new Array();

	if (types) {
	    for (var n=0; n<types.length; n++) { 
		var more = this.availableLists(types[n]);
		if (more) { 
		    for (var i=0; i<more.length; i++) { 
			lists.push(more[i]);
		    }
		}
	    }
	}
	else { 
	    lists = this.availableLists();
	}

	var html = '<select id="'+div_name+'_list_select" name="'+div_name+'_list_select" >';
	if (empty_element) { 
	    html += '<option value="">'+empty_element+'</option>\n';
        } 
	for (var n=0; n<lists.length; n++) {
	    html += '<option value='+lists[n][0]+'>'+lists[n][1]+'</option>';
	}
	html = html + '</select>';
	return html;
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

    validate: function(list_id, type, non_interactive) { 
	var missing = new Array();
	var error = 0;
	jQuery.ajax( { 
	    url: '/list/validate/'+list_id+'/'+type,
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    missing = response.missing;
		}
	    },
	    error: function(response) { alert("An error occurred while validating the list "+list_id); error=1; }
	});

	if (error === 1 ) { return; }

	if (missing.length==0) { 
	    if (!non_interactive) { alert("This list passed validation."); } 
	    return 1;
	}
	else { 
	    alert("List validation failed. Elements not found: "+ missing.join(","));
	    return 0;
	}
    },

    transform: function(list_id, transform_name) { 
	var transformed = new CXGN.List();
	jQuery.ajax( { 
	    url: '/list/transform/'+list_id+'/'+transform_name,
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    transformed = response.transform;
		}
	    },
	    error: function(response) { alert("An error occurred while validating the list "+list_id); }
	});
    },

    transform2Ids: function(list_id) { 
	var list_type = this.getListType(list_id);
	var new_type;
	if (list_type == 'traits') { new_type = 'trait_ids'; }
	if (list_type == 'locations') { new_type = 'location_ids'; }
	if (list_type == 'trials') { new_type = 'project_ids'; }
	if (list_type == 'projects') { new_type = 'project_ids'; }
	if (list_type == 'plots') { new_type = 'plot_ids'; }
	if (list_type == 'accessions') { new_type = 'accession_ids'; }
	
	if (! new_type) { 
	    return { 'error' : "cannot convert the list because of unknown type" };
	}

	var transformed = this.transform(list_id, new_type);
	
	return { 'transformed' : transformed };
	    

    }
};

function setUpLists() { 
    jQuery('#list_dialog').dialog( {
	height: 300,
	width: 500,
	autoOpen: false,
	title: 'Available lists',
	buttons: [ { text: "Done",
		   click: function() { 
		       jQuery('#list_dialog').dialog("close"); 
		   },
		   id: 'close_list_dialog_button'
		 }],
	
	modal: true 
    });
       
    jQuery('#list_item_dialog').dialog( { 
	height: 400,
	width: 400,
	autoOpen: false,
	buttons: [{ 
	    text: "Done",
	    click: function() { 
		jQuery('#list_item_dialog').dialog("close"); 
	    },
	    id: 'close_list_item_dialog'
	}],
	modal: true,
      title: 'List contents'
    });
    
    jQuery('#lists_link').click(
	function() { show_lists(); }
    );
}


function show_lists() {     
    jQuery('#list_dialog').dialog("open");
    
    var l = new CXGN.List();
    l.renderLists('list_dialog');
}

/* deprecated */
function pasteListMenu (div_name, menu_div, button_name) { 
    var lo = new CXGN.List();

    var html='';

    if (button_name === undefined) { 
	button_name = 'paste';
    }

    html = lo.listSelect(div_name);
    html = html + '<input type="button" value="'+button_name+'" onclick="javascript:pasteList(\''+div_name+'\')" /><br />';
    
    jQuery('#'+menu_div).html(html);
}

function pasteList(div_name) { 
    var lo = new CXGN.List();
    var list_name = jQuery('#'+div_name+'_list_select').val();
    var list_content = lo.getList(list_name);
    
    // textify list
    var list_text = '';
    for (var n=0; n<list_content.length; n++) { 
	list_text = list_text + list_content[n][1]+"\r\n";
    }
    jQuery('#'+div_name).text(list_text);
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

    if (options) { 
	if (options.selectText) { 
	    selectText = options.selectText;
	}
	if (options.typeSourceDiv) { 
	    type = getData(options.typeSourceDiv, selectText);
	    if (type) { 
		type = type.replace(/(\n|\r)+$/, '');
	    }
	}
	if (options.types) { 
	    type = options.listType;
	}
    }
    html = '<input type="text" id="'+dataDiv+'_new_list_name" size="8" />';
    html += '<input type="hidden" id="'+dataDiv+'_list_type" value="'+type+'" />';
    html += '<input id="'+dataDiv+'_add_to_new_list" type="button" value="add to new list" /><br />';
    html += lo.listSelect(dataDiv, [ type ]);

    html += '<input id="'+dataDiv+'_button" type="button" value="add to list" />';
   
    jQuery('#'+listMenuDiv).html(html);

    var list_id = 0;

    jQuery('#'+dataDiv+'_add_to_new_list').click(
	function() { 
	    var lo = new CXGN.List();
	    var new_name = jQuery('#'+dataDiv+'_new_list_name').val();
	    var type = jQuery('#'+dataDiv+'_list_type').val();
	    	    
	    var data = getData(dataDiv, selectText);
	    
	    list_id = lo.newList(new_name);
	    if (list_id > 0) { 
		var elementsAdded = lo.addToList(list_id, data);
		if (type) { lo.setListType(list_id, type); }
		alert("Added "+elementsAdded+" list elements to list "+new_name+" and set type to "+type);
	    }
	}
    );
	
    jQuery('#'+dataDiv+'_button').click( 
	function() { 
	    var data = getData(dataDiv, selectText);
	    list_id = jQuery('#'+dataDiv+'_list_select').val();
	    var lo = new CXGN.List();
	    var elementsAdded = lo.addToList(list_id, data);

	    alert("Added "+elementsAdded+" list elements");
	    return list_id;
	}
    );
    

   
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
	    alert("data:"+data);
	    
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
    var html = lo.listSelect(div);
    html = html + '<input id="'+div+'_button" type="button" value="add to list" />';
    
    document.write(html);
    
    jQuery('#'+div+'_button').click( 
	function() { 
	    var text = jQuery('textarea#div').val();
	    var list_id = jQuery('#'+div+'_list_select').val();
	    lo.addToList(list_id, text);
	    lo.renderLists('list_dialog');
	}
    );
}

/* deprecated */
function addSelectToListMenu(div) { 
    var lo = new CXGN.List();
    var html = lo.listSelect(div);
    html = html + '<input id="'+div+'_button" type="button" value="add to list" />';
    
    document.write(html);
    
    jQuery('#'+div+'_button').click( 
	function() { 
	    var selected_items = jQuery('#'+div).val();
	    var list_id = jQuery('#'+div+'_list_select').val();
            addArrayToList(selected_items, list_id);
	    lo.renderLists('list_dialog');
	}
    );
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
lo.renderLists('list_dialog');
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
	
function deleteItemLink(list_item_id) { 
    var lo = new CXGN.List();
    lo.deleteItem(list_item_id);
    lo.renderLists('list_dialog');
}
	
function showListItems(div, list_id) { 
    var l = new CXGN.List();
    jQuery('#'+div).dialog("open");
    l.renderItems('list_item_dialog', list_id);
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

