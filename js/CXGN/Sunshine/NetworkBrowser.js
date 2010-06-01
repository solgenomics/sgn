
/** 
* @class Browser
* Functions used by System Browser
* @author Lukas Mueller <lam87@cornell.edu>
*
*/


JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Async');

CXGN = function() {};
CXGN.Sunshine = function() {};

CXGN.Sunshine.NetworkBrowser = function() { 
    //alert('In constructor');
    this.fetchRelationships();
    this.setLevel(1);
    //this.setHiddenRelationshipTypes('');
    //alert('Done with constructor');
    
};



CXGN.Sunshine.NetworkBrowser.prototype = { 

    initialize: function() { 
	this.render();
	this.renderLegend();
	this.renderLevels();
    },

    setExcludedNodes: function(nodeList) { 
	this.excludedNodes = nodeList;
    },

    getExcludedNodes: function() { 
	return this.excludedNodes;
    },

    //setHiddenRelationshipTypes: function(rTypeListString) { 
    //	this.rTypeList = rTypeListString.split(' ');
    //},

    getHiddenRelationshipTypes: function() { 
	//return this.rTypeList.join(' ');
	var hidden = new Array();
	for (var n=0; n<this.relationships.length; n++) {
	    
	    var checkbox_id = 'relationship_checkbox_'+this.relationships[n].id;
	    var checkbox = document.getElementById(checkbox_id);
	    //MochiKit.Logging.log('Checkbox ID: ' +checkbox_id + ' RELATIONSHIP: '+this.relationships[n].id);
	    if (checkbox != undefined && !checkbox.checked) { 
	    hidden.push(this.relationships[n].id);
	    }
	}
	return hidden.join(' ');
    },
    
    //addHiddenRelationshipType: function(relationshipId) { 
    //	MochiKit.Logging.log('Adding '+relationshipId+' to the list of hidden relationships');
    //	this.rTypeList.push(relationshipId);
    //},

    //    removeHiddenRelationshipType: function(relationshipId) { 

    //	MochiKit.Logging.log("relationshipId = "+ relationshipId);
    //	var a = new Array();
    //	var old = this.getHiddenRelationshipTypes().split(' ');
    //	for (var i=0; i<old.length; i++) { 
    //	    if (old[i]!=relationshipId) { 
    //		MochiKit.Logging.log('keeping '+ old[i]);
    //		a.push(old[i]);
    //	    }
    //	    else { 
    //		MochiKit.Logging.log('removing ' + old[i]);
    //	    }
    //	}
    //	var new_rs = a.join(' ');
    //	MochiKit.Logging.log('New hidden relationships: '+new_rs);
    //	/this.setHiddenRelationshipTypes(new_rs);
    //	document.getElementById('relationship_checkbox_'+relationshipId).checked=false;
    //},

    //isRelationshipHidden: function(relationshipId) { 
    //	if (this.rTypeList.indexOf(relationshipId) > -1) { 
    //	    MochiKit.Logging.log('The relationship '+relationshipId + ' is currently hidden');
    //	    return true;
    //	    
    //	}
    //	else {
//	    MochiKit.Logging.log('The relationship '+relationshipId + ' is  currently shown');
    //    return false;
	//}
    //}, 

    toggleHideRelationshipType: function(relationshipId) { 
	//	if (this.rTypeList.indexOf(relationshipId) != -1) { 
	//    this.removeHiddenRelationshipType(relationshipId);
	//}
	//else { 
	//   this.addHiddenRelationshipType(relationshipId);
	//}
	//	this.getImage(this.getName(), this.getType(), this.getLevel(), this.getHiddenRelationshipTypes());
	this.render();
    },

    setLevel: function(level) { 
	this.level = level;
    },
    
    getLevel: function() { 
	return this.level;
    },

    setType: function(type) { 
	this.type = type;
    },

    getType: function() { 
	return this.type;
    },

    setName: function(name) { 
	//	alert('Setting name to '+name);
	this.name = name;
    },

    getName: function() { 
	return this.name;
    },

    render: function() { 
	//alert('Hidden relationship types: ' + this.getHiddenRelationshipTypes());
	this.getImage(this.getName(), this.getType(),this.getLevel(), this.getHiddenRelationshipTypes());
	this.renderLevels();
    },

    setHilite: function(hiliteColor) { 
	this.hiliteColor = hiliteColor;
    },

    getHilite: function() { 
	return this.hiliteColor;
    },

    renderLegend: function() { 	
	var s = '';
	MochiKit.Logging.log('renderLegend...');
	for (var n=0; n<this.relationships.length; n++) { 
	    var colors = this.relationships[n].color.split(',');
	    var colorString = '#'+ this.toHex(colors[0]) + this.toHex(colors[1]) +this.toHex(colors[2]);
	    var name = 'relationship_checkbox_'+this.relationships[n].id;
	    var checked = 1; // all the relationships are checked initially
	    //MochiKit.Logging.log('CHECKBOX '+name+' -- '+checked);
	    s += '<input type="checkbox" checked="'+checked+'" id="'+name+'" onClick="javascript:nb.toggleHideRelationshipType(' + this.relationships[n].id + ')" /> <font style="background-color:'+colorString+'">&nbsp;&nbsp;</font>&nbsp;'+this.relationships[n].name +'<br />\n';
	    //MochiKit.Logging.log('Color: '+ this.relationships[n].color + ' gives ' +colorString);
	    //MochiKit.Logging.log('renderLegend: '+ this.relationships[n].name);
	}
	document.getElementById('relationships_legend').innerHTML = "<br /><br /><b>Display relationship types:</b><br />" + s;
    },

	

    //this shouldn't be here...
    toHex: function(n) { 
	var hex = (n * 1).toString(16); //force numerical context
	if (hex.length ==1) { hex = '0'+hex; }
	return hex;
    },

    renderLevels: function() { 
	var s = '<b>Show levels:</b><br />\n';
	s += '<input type="button" onClick="javascript:nb.levelMinusOne()" value="<" />';
	s += '<b>&nbsp;' + this.getLevel() + '&nbsp;</b>';
	s += '<input type="button" onClick="javascript:nb.levelPlusOne()" value=">" />';
	document.getElementById('level_selector').innerHTML = s;
    },
    
    levelMinusOne: function() { 
	if (this.getLevel() >1) { 
	    this.setLevel(this.getLevel()-1);
	}
	this.render();	    
    },

    levelPlusOne: function() { 
	if (this.getLevel() < 10) { 
	    this.setLevel(this.getLevel()+1);
	}
	this.render();
    },

    getImage: function(name, type, level, relationships, hilite) {	
	if (!name && !type) { alert("No name or type supplied. How am I supposed to do anything????"); }
	//	var count = 0;
	var x = MochiKit.DOM.getElement("network_browser");
	this.setName(name);
	this.setLevel(level);
	this.setType(type);
	this.setHilite(hilite);
	//alert('Requesting image for '+name);
	new Ajax.Request("/tools/networkbrowser/ajax_image_request.pl", {
	    parameters: { 
		name: name, 
			  type: type, 
			  level: level,
			hide: relationships,
			hilite: hilite}, 
			  onSuccess: this.processImageResponse
					   });
	
    },
    
    
    processImageResponse: function (request) { 
	var responseText = request.responseText;
	var e = MochiKit.DOM.getElement("network_browser").innerHTML=responseText;
	var r = responseText;
    },

    fetchRelationships: function() { 

	new Ajax.Request("/tools/networkbrowser/ajax_relationship_request.pl", {
	    parameters:   { }, 
	    asynchronous: false,
	    onException: function() { 
		    //alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },

            onSuccess: function(request) { 
		var responseText = request.responseText;
		//alert(responseText);
		nb.relationships = eval( responseText );
		//alert('Found ' + nb.relationships.length + ' relationship types!');
		
	    },
	}
			 );
	
	
    },
    
};

