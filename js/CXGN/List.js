JSAN.use('jqueryui');

if (!CXGN) CXGN = function () { };

CXGN.List = function () { 
    alert("CREATE LIST!");
    
}

CXGN.List.prototype = { 

    getList: function(name) { 
	
	var list;

	jQuery.ajax( { 
	    url: '/list/get',
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

	alert("GOT LIST "+list);
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
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		lists = response;
	    }
	});
	alert("LISTS = "+lists);
	return lists;
    },


    renderLists: function(div) { 
	var lists = this.availableLists();
	var html = '';
	
	for (var i = 0; i < lists.length; i++) { 
	    html = html + '<h4>'+lists[i][1]+'</h4>\n';
	    
	    alert("And now..."+lists);
	    var items = this.getList(lists[i][1]);

	    alert("ITEMS IN LIST="+items[i]);
	    for (var n = 0; n<items.length; n++) { 
		html = html + items[n][1] + '<br />\n';
	    }
	    alert("DIV "+div+" HTML " +html);
	}
	jQuery('#'+div).html(html);
    }

}
