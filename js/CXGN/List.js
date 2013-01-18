JSAN.use('jqueryui');

if (!CXGN) CXGN = function () { };

CXGN.List = function () { 
    //alert("CREATE LIST!");
    this.list = [];
};

CXGN.List.prototype = { 

    getList: function(name) { 
	
	var list;

	jQuery.ajax( { 
	    url: '/list/get',
	    async: false,
	    data: 'name='+name,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    list = response;
		}
	    }
	});
	alert('List='+list);
	return list;

    },

    newList: function(name) { 
	jQuery.ajax( { 
	    url: '/list/new',
	    data: 'name='+name,
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

    renderLists: function(div) { 
	var lists = this.availableLists();
	var html = '';
	if (lists.length ==0) { 
	    html = html + "None";
	    jQuery('#'+div).html(html);
	    return;
	}
	
	html = html + '<table>';
	for (var i = 0; i < lists.length; i++) { 
	    html = html + '<tr><td><b>'+lists[i][1]+'</b></td><td>(' + lists.length +' elements) </td><td><a href="">view</a></td><td>|</td><td><a href="">delete</a></td></tr>\n';
	    
	    var items = this.getList(lists[i][1]);

	    //for (var n = 0; n<items.length; n++) { 
	//	html = html + items[n][1] + '<br />\n';
	  //  }
	    	}
	html = html + '</table>';
	jQuery('#'+div).html(html);
    }

};


function pasteListMenu (div_name) { 
    var lo = new CXGN.List();
    var html = '<select id="'+div_name+'_list_select">';
    alert("HTML so far"+html);
    var lists = lo.availableLists();
    for (var n=0; n<lists.length; n++) { 
	html = html + '<option>'+lists[n][1]+'</option>';
    }
    html = html + '</select>';
    html = html + '<input type="button" value="paste" onclick="javascript:pasteList(\''+div_name+'\')" /><br />';
    document.write(html);
}

function pasteList(div_name) { 
    var lo = new CXGN.List();
    
    var list_name = jQuery('#'+div_name+'_list_select').val();
    
    var list_content = lo.getList(list_name);
    
    // textify list
    var list_text = '';
    for (var n=0; n<list_content.length; n++) { 
	list_text = list_text + list_content[n][1]+'\n';
    }
    jQuery('#'+div_name).html(list_text);
}

// add text in a div to a list
function addToList(div_name) { 
    var lo = new CXGN.List();
    
}
