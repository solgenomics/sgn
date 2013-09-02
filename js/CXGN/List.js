
/*

=head1 NAME

CXGN.List - a javascript library to implement the lists on the SGN platform

=head1 DESCRIPTION

There are two important list functions in this library, listed below. All other functions should be considered private and/or deprecated.


* addToListMenu(listMenuDiv, dataDiv)

this function will generate a select of all available lists and allow the content to be added to a list (from a search, etc). The first parameter is the id of the div tag where the menu should be drawn. The second parameter is the div that contains the data to be added. This can be a textfield, a div or span tag, or a multiple select tag.

* pasteListMenu(divName, menuDiv)

this will generate an html select box of all the lists, and a "paste" button, to paste into a textarea (typically). The divName is the id of the textarea, the menuDiv is the id where the paste menu should be placed.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

*/


JSAN.use('jqueryui');

if (!CXGN) CXGN = function () { };

CXGN.List = function () { 
    this.list = [];
};

CXGN.List.prototype = { 
    
    getList: function(list_id) { 
	
	var list;
	
	jQuery.ajax( { 
	    url: '/list/get',
	    async: false,
	    data: { 'list_id':list_id },
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

    newList: function(name) { 
	var oldListId = this.existsList(name);
	var newListId = 0;
	
	if (name == '') { 
	    alert('Please enter a name for the new list.');
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
	alert("an error occurred");
	return 0;
    },

    availableLists: function() { 
	var lists = [];
	jQuery.ajax( { 
	    url: '/list/available',
	    async: false,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		lists = response;
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
		data:  { 'list_id': list_id, 'element': item }
	    });
	    var new_list_item_id = this.existsItem(list_id,item);
	    return new_list_item_id;
	}
	else { return 0; }
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

	html = html + '<table border="0" title="Available lists">';
	for (var i = 0; i < lists.length; i++) { 
	    html = html + '<tr><td><b>'+lists[i][1]+'</b></td><td>(' + lists[i][3] +' elements) </td><td><a href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')">view</a></td><td>|</td><td><a href="javascript:deleteList('+lists[i][0]+')">delete</a></td><td>|</td><td><a href="/list/download?list_id='+lists[i][0]+'">download</a></td></tr>\n';
	    
	    //var items = this.getList(lists[i][0]);
	    

	    
	    
	}
	html = html + '</table>';
	jQuery('#'+div).html(html);

	jQuery('#add_list_button').click( 
	    function() { 
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

	var items = this.getList(list_id);
	var list_name = this.listNameById(list_id);

	var html = '<h4>List '+list_name+'</h4>';
	html = html + '<textarea id="dialog_add_list_item" ></textarea><input id="dialog_add_list_item_button" type="submit" value="add" /><br />';
	
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
		addMultipleItemsToList('dialog_add_list_item', list_id);
		var lo = new CXGN.List();
		lo.renderItems(div, list_id);
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
	var list = text.split("\n");
	var duplicates = [];
	for(var n=0; n<list.length; n++) { 
	    var id = this.addItem(list_id, list[n]);
	    if (id == 0) { 
		duplicates.push(list[n]);
	    }
	}

	if (duplicates.length > 0) { 
	    alert('Duplicate items ('+ duplicates.join(",") + ') were not stored');
	}
	return list.length - duplicates.length;
    },

    listSelect: function(div_name) { 
	var lists = this.availableLists();
	var html = '<select id="'+div_name+'_list_select">';
	for (var n=0; n<lists.length; n++) { 
	    html = html + '<option value='+lists[n][0]+'>'+lists[n][1]+'</option>';
	}
	html = html + '</select>';
	return html;
    }
};

function setUpLists() { 
    jQuery('#list_dialog').dialog( {
	height: 300,
	width: 500,
	autoOpen: false,
	title: 'Available lists',
	buttons: { "Done" :  function() { 
	    jQuery('#list_dialog').dialog("close"); }
		 },
	modal: true 
    });
    
    jQuery('#list_item_dialog').dialog( { 
	height: 300,
	width: 300,
	autoOpen: false,
	buttons: { 
		"Done": function() { 
		    jQuery('#list_item_dialog').dialog("close"); }
	},
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


function pasteListMenu (div_name, menu_div) { 
    var lo = new CXGN.List();

    var html='';

    if (jQuery.cookie("sgn_session_id")) {
	html = lo.listSelect(div_name);
	html = html + '<input type="button" value="paste" onclick="javascript:pasteList(\''+div_name+'\')" /><br />';
    }
    else { 
	html = html + 'please log in for lists';
    }
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

function addToListMenu(listMenuDiv, dataDiv) { 
    var lo = new CXGN.List();
    
    var html = '<input type="text" id="'+dataDiv+'_new_list_name" size="8" /><input id="'+dataDiv+'_add_to_new_list" type="button" value="add to new list" /><br />';
    html += lo.listSelect(dataDiv);

    html += '<input id="'+dataDiv+'_button" type="button" value="add to list" />';
    
    jQuery('#'+listMenuDiv).html(html);
    
    var list_id = 0;

    jQuery('#'+dataDiv+'_add_to_new_list').click(
	function() { 
	    var lo = new CXGN.List();
	    var new_name = jQuery('#'+dataDiv+'_new_list_name').val();
	    
	    var data = getData(dataDiv);
	    list_id = lo.newList(new_name);
	    if (list_id > 0) { 
		var elementsAdded = lo.addToList(list_id, data);
		alert("Added "+elementsAdded+" list elements to list "+new_name);
	    }
	}
    );

    jQuery('#'+dataDiv+'_button').click( 
	function() { 
	    var data = getData(dataDiv);
	    list_id = jQuery('#'+dataDiv+'_list_select').val();
	    var elementsAdded = lo.addToList(list_id, data);
	    alert("Added "+elementsAdded+" list elements.");
	}
    );
}

function getData(id) { 
    var divType = jQuery("#"+id).get(0).tagName;

    if (divType == 'DIV' || divType =='SPAN' ||  divType === undefined) { 
	data = jQuery('#'+id).html();
    }
    if (divType == 'SELECT') { 
	data = jQuery('#'+id).val().join("\n");
    }
    if (divType == 'TEXTAREA') { 
	data = jQuery('textarea#'+id).val();
    }
    return data;
}
           
	

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

function addTextToList(div, list_id) { 
    var lo = new CXGN.List();
    var item = jQuery('#'+div).val();
    var id = lo.addItem(list_id, item);
    if (id == 0) { 
	alert('Item "'+item+'" was not added because it already exists');
    }
    lo.renderLists('list_dialog');
}

function addMultipleItemsToList(div, list_id) { 
    var lo = new CXGN.List();
    var content = jQuery('#'+div).val();
    if (content == '') { 
	alert("No items - Please enter items to add to the list.");
return;
    }
    var items = content.split("\n");
    
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
lo.renderLists('list_dialog');
}

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

