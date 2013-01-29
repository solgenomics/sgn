JSAN.use('jqueryui');

if (!CXGN) CXGN = function () { };

CXGN.List = function () { 
    //alert("CREATE LIST!");
    this.list = [];
};

CXGN.List.prototype = { 

    getList: function(list_id) { 
	
	var list;

	jQuery.ajax( { 
	    url: '/list/get',
	    async: false,
	    data: 'list_id='+list_id,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    //alert('Response = '+response);
		    list = response;
		}
	    }
	});
	//alert('List='+list);
	return list;

    },

    newList: function(name) { 
	jQuery.ajax( { 
	    url: '/list/new',
	    data: { 'name': name },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
	    }
	});
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

    addItem: function(list_id, item) { 
	jQuery.ajax( { 
	    url: 'list/item/add',
	    data:  { 'list_id': list_id, 'item': item },
	});
    },

    removeItem: function(item_id) {
	jQuery.ajax( {
	    url: 'list/item/remove',
	    data: { 'item_id': item_id }
	});
    },


    deleteList: function(list_id) { 
	jQuery.ajax( { 
	    url: 'list/delete',
	    data: { 'list_id': list_id }
	});
    },

    renderLists: function(div) { 
	var lists = this.availableLists();
	var html = '';
	if (lists.length ==0) { 
	    html = html + "None";
	    jQuery('#'+div).html(html);
	    return;
	}
	html = html + '<input type="text" /><input type="submit" value="add list" /><br />';
	html = html + '<table>';
	for (var i = 0; i < lists.length; i++) { 
	    html = html + '<tr><td><b>'+lists[i][1]+'</b></td><td>(' + lists[i][3] +' elements) </td><td><a href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')">view</a></td><td>|</td><td><a href="javascript:deleteList('+lists[i][0]+')">delete</a></td></tr>\n';
	    
	    var items = this.getList(lists[i][0]);

	    //for (var n = 0; n<items.length; n++) { 
	//	html = html + items[n][1] + '<br />\n';
	  //  }
	    	}
	html = html + '</table>';
	jQuery('#'+div).html(html);
    },

    renderItems: function(div, list_id) { 
	var lists = this.availableLists();
	//alert('rendering items for list with id '+list_id);
	var items = this.getList(list_id);
	
	var html = '<h4>List</h4> '; //+lists[list_id][1]+'</h4>';
	html = html + '<input type="text" id="dialog_add_list_item" /><input type="submit" value="add" onclick="javascript:addTextToList(\"dialog_add_list_item\", '+list_id+')" />';
	
	for(var n=0; n<items.length; n++) { 
	    html = html + items[n][1] + '   <a href="/list/item/remove?item='+items[n][0]+'">remove</a><br />';

	}
	
	jQuery('#'+div).html(html);
	//alert("DONE renderItems " + div);
    },
    
    existsList: function(name) { 
	var list_id = 0;
	jQuery.ajax( { 
	    url: '/list/exists',
	    async: false,
	    data: { 'name': name },
	    success: function(response) { 
		list_id = response.list_id;
		//alert('List ID='+list_id);
	    }
	});
	//alert('"exists"='+list_id);
	return list_id;
    }

    

};

function listSelect(div_name) { 
    var lo = new CXGN.List();
    var lists = lo.availableLists();
    var html = '<select id="'+div_name+'_list_select">';
    for (var n=0; n<lists.length; n++) { 
	html = html + '<option value='+lists[n][0]+'>'+lists[n][1]+'</option>';
    }
    html = html + '</select>';
    return html;
}
function pasteListMenu (div_name) { 
    var html = listSelect(div_name);

    html = html + '<input type="button" value="paste" onclick="javascript:pasteList(\''+div_name+'\')" /><br />';
    document.write(html);
}

function pasteList(div_name) { 
    var lo = new CXGN.List();
    
    var list_name = jQuery('#'+div_name+'_list_select').val();

    //alert('paste list '+list_name);

    var list_content = lo.getList(list_name);
    
    // textify list
    var list_text = '';
    for (var n=0; n<list_content.length; n++) { 
	list_text = list_text + list_content[n][1]+'\n';
    }
    //alert('List content'+list_text);
    jQuery('#'+div_name).html(list_text);
}

function addToListMenu(div) { 
    var html = listSelect();
    html = html + '<input id="add_to_list_button" type="button" value="add to list" />';
    document.write(html);
}

// add the text in a div to a list
function addDivToList(div_name, list_id) { 
    var lo = new CXGN.List();
    var list = jQuery('#'+div_name).html();
    var items = list.split("\n");
    
    for(var n=0; n<items.length; n++) { 
	lo.addItem(list_id, items[n]);
    }
}

function addTextToList(id, list_name) { 
    var lo = new CXGN.List();
    alert('adding element');
    var item = jQuery('#'+id).val();
    lo.addItem(list_id, list_name);
}

function deleteList(list_id) { 
    alert("deleting list...");
    jQuery('#confirm_delete_dialog').dialog("open");
    alert("done.");
}
	
	
function showListItems(div, list_id) { 
    var l = new CXGN.List();
    jQuery('#'+div).dialog("open");
    l.renderItems('list_item_dialog', list_id);
}

function addNewList(div_id) { 
    var l = new CXGN.List();
    var name = jQuery('#'+div_id).val();
    
    if (name == '') { 
	alert("Please specify a name for the list.");
	return;
    }
    
    var list_id = l.existsList(name);
    alert('this list name has id '+list_id);
    if (list_id > 0) {
	alert('The list '+name+' already exists. Please choose another name.');
	return;
    }
    l.newList(name);
    l.renderLists('list_item_dialog');
}
