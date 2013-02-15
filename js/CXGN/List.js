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
	    data: { 'list_id':list_id },
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
	var oldListId = this.existsList(name);
	alert("OLD LIST ID = "+oldListId);
	if (oldListId == null) { 
	    jQuery.ajax( { 
		url: '/list/new',
		async: false,
		data: { 'name': name },
		success: function(response) { 
		    if (response.error) { 
			alert(response.error);
		    }
		}
	    });
	    alert("stored list");
	    return 1;
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
	if (exists_item_id ==0 ) { 
	    jQuery.ajax( { 
		async: false,
		url: '/list/item/add',
		data:  { 'list_id': list_id, 'element': item },
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
	    url: 'list/delete',
	    data: { 'list_id': list_id }
	});
    },

    renderLists: function(div) { 
	//alert("render lists...");
	var lists = this.availableLists();
	var html = '';
	html = html + '<input id="add_list_input" type="text" /><input id="add_list_button" type="button" value="add list" /><br />';

	if (lists.length==0) { 
	    html = html + "None";
	    jQuery('#'+div).html(html);
	    return;
	}

	html = html + '<table border="0" title="Available lists">';
	for (var i = 0; i < lists.length; i++) { 
	    html = html + '<tr><td><b>'+lists[i][1]+'</b></td><td>(' + lists[i][3] +' elements) </td><td><a href="javascript:showListItems(\'list_item_dialog\','+lists[i][0]+')">view</a></td><td>|</td><td><a href="javascript:deleteList('+lists[i][0]+')">delete</a></td></tr>\n';
	    
	    var items = this.getList(lists[i][0]);
	    

	    

	}
		    html = html + '</table>';
	jQuery('#'+div).html(html);
	
	jQuery('#add_list_button').click( 
	    function() { 
		var lo = new CXGN.List();
		alert("click");
		var name = jQuery('#add_list_input').val();
		alert("here "+name);
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
	html = html + '<input type="text" id="dialog_add_list_item" /><input id="dialog_add_list_item_button" type="submit" value="add" /><br />';
	
	for(var n=0; n<items.length; n++) { 
	    html = html + items[n][1] + '   <input id="delete_'+items[n][0]+'" type="button" value="remove" /><br />';
	    
	}
	
	jQuery('#'+div).html(html);


	for (var n=0; n<items.length; n++) { 
	    var list_item_id = items[n][0];
	    alert('constructing button '+list_item_id);
	    jQuery('#delete_'+items[n][0]).click(
		function() { 
		    alert("ID = "+this.id);
		    var lo = new CXGN.List();
		    var i = lo.availableLists();
		    
		    alert(i.join(",")); //+'removing n= '+n+' item '+ i[n][0] + ' ' + i[n][1]);
		    lo.removeItem(list_id, this.id );
		    lo.renderItems(div, list_id);
		});
	}
	
	jQuery('#dialog_add_list_item_button').click(
	    function() { 
		addTextToList('dialog_add_list_item', list_id);
		var lo = new CXGN.List();
		lo.renderItems(div, list_id);
	    }
	);

	
	
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
	//alert('start addToList'+list_id+", "+text);
	var list = text.split("\n");
	var duplicates = [];
	for(var n=0; n<list.length; n++) { 
	    //alert('adding '+list[n]);
	    var id = this.addItem(list_id, list[n]);
	    if (id == 0) { 
		duplicates.push(list[n]);
	    }
	}
	alert('Duplicate items ('+ duplicates.join(",") + ') were not stored');
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
    
    jQuery('#confirm_delete_dialog').dialog( { 
	height: 300,
	width:  300,
	autoOpen: false,
	buttons: { 
            "Yes" : function() {
	        jQuery('#confirm_delete_dialog').dialog("close"); 
	    }, 
            "No"  : function() {
		jQuery('#confirm_delete_dialog').dialog("close"); 
	    }
	},
	modal: true,
	title: 'Delete?'
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


function pasteListMenu (div_name) { 
    var lo = new CXGN.List();

    var html = lo.listSelect(div_name);

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
    jQuery('#'+div_name).html(list_text);
}

function addToListMenu(div) { 
    var lo = new CXGN.List();
    var html = lo.listSelect(div);
    html = html + '<input id="'+div+'_button" type="button" value="add to list" />';
    
    document.write(html);
    
    jQuery('#'+div+'_button').click( 
	function() { 
	    var text = jQuery('textarea#'+div).val();
	    var list_id = jQuery('#'+div+'_list_select').val();
	    lo.addToList(list_id, text);
	}
    );
}

// add the text in a div to a list
function addDivToList(div_name) { 
    //alert('start addDivToList');
    var list_id = jQuery('#'+div_name+'_list_select').val();
    var lo = new CXGN.List();
    var list = jQuery('#'+div_name).val();
    //alert('list-id: '+list_id+' list= '+list);
    var items = list.split("\n");

    for(var n=0; n<items.length; n++) { 
	var added = lo.addItem(list_id, items[n]);
	if (added > 0) { }
    }
    //alert('added text to list');
}

function addTextToList(div, list_id) { 
    var lo = new CXGN.List();
    var item = jQuery('#'+div).val();
    var id = lo.addItem(list_id, item);
    if (id == 0) { 
	alert('Item "'+item+'" was not added because it already exists');
    }
}

function deleteList(list_id) { 
    //alert("deleting list...");
    jQuery('#confirm_delete_dialog').dialog("open");
}
	
function deleteItemLink(list_item_id) { 
    var lo = new CXGN.List();
    lo.deleteItem(list_item_id);
    //alert('Deleted '+list_item_id);
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
    //alert('this list name has id '+list_id);
    if (list_id > 0) {
	alert('The list '+name+' already exists. Please choose another name.');
	return;
    }
    lo.newList(name);
    lo.renderLists('list_item_dialog');
}

