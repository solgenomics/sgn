//
// AJAX-based ontology browser
//
// Lukas Mueller and Naama Menda
//
// Sol Genomics Network (http://sgn.cornell.edu/ )
//
// Spring 2008
//

JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Logging');
JSAN.use('MochiKit.Async');
JSAN.use('Prototype');
JSAN.use('CXGN.Effects');
//JSAN.use('CXGN');
//JSAN.use('CXGN.Onto');
JSAN.use('CXGN.Onto.Browser');
//JSAN.use('CXGN.Phenome.Tools');


CXGN = function () {};
CXGN.Onto = function () {};

CXGN.Onto.Browser = function () { 

    this.nodelist = new Array();
    this.resetNodeKey();
    //this.workingMessage(false);
    //document.write('<p id="ontology_browser">&nbsp;</p>');
    //var dom = MochiKit.DOM.getElement('ontology_browser');
    //MochiKit.Logging.log('DOM: '+dom);
    //this.setDOMElement(dom);
    
    //MochiKit.Logging.log('In browser constructor.');

};

CXGN.Onto.Browser.prototype = {
    
    fetchTestRoots: function() { 
	//MochiKit.Logging.log('creating root node.');
	this.rootnode = new Node(this);
	this.rootnode.setName('ROOT');
	this.rootnode.openNode();
	var p2;
	for (var i=0; i<5; i++) { 
	    //MochiKit.Logging.log('adding child node '+i);
	    var n = new Node(this);

	    var nodeName = 'node';
	    n.setName(nodeName);
	    n.openNode();
	    if (i==2) { 
		p2=n; 
		p2.openNode();
		p2.unHide();
		//MochiKit.Logging.log('p2 is now ' + p2.getName());
	    }
	    this.rootnode.addChild(n);
	    
	}

	for (i=0; i<3; i++) { 
	    //MochiKit.Logging.log('adding second level child nodes...');
	    n = new Node(this);
	    nodeName = 'subnode';
	    n.setName(nodeName);
	    n.openNode();
	    p2.addChild(n);
	}
	
    },		

    resetBrowser: function() {

	//this.setSearchTerm();
	//this.setSearchValue();
	document.getElementById("ontology_browser_input").value='';
	document.getElementById("ontology_term_input").value='';
	//this.setSearchResults(); //this works
	
	this.initializeBrowser();

	this.render();
    },
    
    setUpBrowser: function() { 
	document.write('<div id="ontology_browser_input" >&nbsp;&nbsp;&nbsp;</div><div id="working"></div> '); // the element for the go id parentage search
	document.write('<div id="ontology_term_input" ></div>');     // the element for the search
	document.write('<input id="hide_link" type="button" value="show results" display="none" onClick="MochiKit.Visual.toggle(\'search_results\', \'blind\'); o.toggleSearchResultsVisible(); o.setSearchButtonText();  "><br />');
	
	document.write('<div id="search_results" ></div>');    
	document.write('<div id="ontology_browser" style="font-size:12px; line-height:10px; font-face:arial,helvetica" >&nbsp;</div>');  // the element for the browser
	


    },

    initializeBrowser: function() { 
	this.setSelected();
	this.setSearchTerm('');
	this.setSearchValue('');
	this.setSearchResults('');
	this.fetchRoots();
	this.hideSearchButton();
	this.setSearchResponseCount(0);
	this.render();
    },

    fetchRoots: function() { 
	//MochiKit.Logging.log('THis in fetchRoots: ' + this);
	
	new Ajax.Request("/chado/ajax_ontology_browser.pl", {
	    parameters:   { action: 'roots' }, 
	    asynchronous: false,
	    on503: function() { 
	    	alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },
            onSuccess: function(request) { 
		
		//MochiKit.Logging.log('COMPLETE!');
		
		var responseText = request.responseText;
		
		//MochiKit.Logging.log('RESPONSETEXT = ' + responseText);
		
		//MochiKit.Logging.log('This = ' + this);
		
		o.rootnode = new Node(o);
		
		//MochiKit.Logging.log('Created root node. Yay!');
		o.rootnode.setName('');
		o.rootnode.setAccession('root');
		o.rootnode.openNode();
		o.rootnode.unHide();
		o.rootnode.setHasChildren(true);
		//MochiKit.Logging.log('root: ' + o.rootnode + ' ---- ' + o.rootnode.name);
		
		//MochiKit.Logging.log('fetching roots...');
		
		var t = responseText.split('#');
		
		//MochiKit.Logging.log('Children count ' +  t.length + '<br />');
		
		for (var i=0; i<t.length; i++) { 
		    var j = t[i].split('*');
		    //  MochiKit.Logging.log(i + '. Child: ID: '+ j[0] + ' Name: ' + j[1] +  ' <br />');
		    
		    
		    //MochiKit.Logging.log('Processing '+j[0]);
		    
		    
		    var childNode = new Node(o);
		    
		    o.rootnode.addChild(childNode);
		    childNode.setAccession(j[0]);
		    //childNode.setHilite(true);
		    childNode.closeNode();
		    childNode.unHide();
		    childNode.setName(j[1]);
		    childNode.setCVtermID(j[2]);
		    childNode.setRelType(j[4]);
		    //MochiKit.Logging.log('hasChildren = '+j[2]);
		    if (j[3]==1) { 
			childNode.setHasChildren(true);
		    }
		    else { 
			childNode.setHasChildren(false);
		    }
		    
		    //MochiKit.Logging.log('Root node name: '+o.rootnode.getName()+'<br />');
		    //MochiKit.Logging.log('Child accession: '+childNode.getAccession()+'<br />');
		    
		}
	    }
	});
    },
    
    workingMessage: function(status) {
	MochiKit.Logging.log('the working message = ' , status );
	var w = document.getElementById('working');

	if (status) {
	    //	    MochiKit.Logging.log('status is true! ' , status);
	    w.style.visibility='visible';
	}
	else { 
	    w.style.visibility='hidden'; 
	}
    },
    
    renderSearchById: function() {
	//this.workingMessage(false);
	//MochiKit.Logging.log('the value of ontology_browser_input is ...', (document.getElementById('ontology_browser_input')).value);
	
	var s = '<form name="search_id_form" style="margin-bottom:0" onSubmit="javascript:o.showParentage(this.ontology_browser_input.value); return false;" >';
	s += '<div id="search_by_id" style="width:700" style="margin-bottom:0" >';
	s += '<table summary="" cellpadding="5" cellspacing="0" ><tr><td align="center">';
	s += 'Ontology id&nbsp;&nbsp;&nbsp;&nbsp; <input id="ontology_browser_input" name="ontology_browser_input_name" type="text"  size="12" style="margin-bottom:0" /><input id="ontology_browser_submit" type="submit" style="margin-bottom:0" />';
	s += '&nbsp;|&nbsp;<input id="reset_hiliting" type="button" value="clear hiliting" onClick="javascript:o.clearHiliting()" style="margin-bottom:0" /> | <input id="reset_tree" type="button" value="reset" onClick="javascript:o.resetBrowser()" style="margin-bottom:0" />';
		s += '</td><td align="right" width="*" ></td></tr></table>';
	s +='</div></form>';
	
	var e = document.getElementById('ontology_browser_input');
	//MochiKit.Logging.log('the value of ontology_browser_input is ...',document.getElementById('ontology_browser_input').value);
	e.innerHTML = s;
	document.getElementById('ontology_browser_input').value=(o.getSearchTerm());
		this.workingMessage(false);
    },
    
    renderSearchByName: function() {
	//this.workingMessage(false);
	var s = '<form style="margin-bottom:0" name="SearchByNameForm" onsubmit="javascript:o.getOntologies(this.cv_select.value, this.ontology_term_input.value); return false;" >';
	s += '<div id="search_by_name"  style="margin-bottom:0" >';
	//s += '<form name="search_name_form" style="margin-bottom:0" >';
	s += '<table summary="" cellpadding="5" cellspacing="0"><tr><td align="center" >';
	s += 'Ontology term <input id="ontology_term_input" name="ontology_term_input_name" type="text" size="30"  />';
	s += '<select id="cv_select" >';
	s += '<option value="GO" ' + o.isSelected("GO") +'>GO (gene ontology)</option>';
	s += '<option value="PO" ' + o.isSelected("PO") +'>PO (plant ontology)</option>';
	s += '<option value="SP" ' + o.isSelected("SP") +'>SP (Solanaceae phenotypes)</option>';
	s += '<option value="PATO" ' + o.isSelected("PATO") +'>PATO (Phenotype and trait)</option>';
	s += '<option value="SO" ' + o.isSelected("SO") +'>SO (Sequence ontology)</option>';
	
	s += '</select>';
	s += '<input id="term_search" type="submit" value="Search"  />';
	s += '</td></tr></table>';
	s += '</div></form>';
	
	var e = document.getElementById('ontology_term_input');
	e.innerHTML = s;
	document.getElementById('ontology_term_input').value=(o.getSearchValue());
    },
    

    render: function() {
	
	var s = '';	
	
	if (o.searchResults) {
	    //s +='<input id="hide_link" type="button" value="'+o.getSearchButtonText()+'" onClick="MochiKit.Visual.toggle(\'search_results\', \'blind\'); o.toggleSearchResultsVisible(); o.setSearchButtonText(); "><br />';
	    document.getElementById("hide_link").style.display="inline";
	    
	}

	o.setSearchButtonText();

	document.getElementById("search_results").innerHTML=this.getSearchResults();
	//	s +='<div id="search_results" >' + this.getSearchResults() + '</div>';

	//s += '<div style="font-size:9pt; line-height:10px; font-face:arial,helvetica" >';
	
	s = s + this.renderLevel(s, this.rootnode, 0);
	var e = document.getElementById('ontology_browser');
	s += '</div>';
	e.innerHTML = s;


	
    },
    
    renderLevel: function (s, node, level, last) { 
	//MochiKit.Logging.log('renderLevel: ' + node.getName() + ', '+level);
	
	var t = '';
	
	if ((node == undefined) || (node.isHidden())) { 
	    //MochiKit.Logging.log('undefined or hidden node!');  
	}
	else { 
	    
	    //MochiKit.Logging.log('level '+level);
	    //for (var l=0; l<level; l++) { 
	    //		    MochiKit.Logging.log('.');
	    //}
	    
	    
	    for (var i=0; i<level-1; i++) { 
		t += '<img src="/documents/img/tree_bar.png" border="0" />';
	    }
	    
	    if (node.hasChildren()) { 
		var key = node.getNodeKey();
		if (node.getOpenNode()) {
		    
		    t +=  '<a href="javascript:o.closeNode('+key+')"><img src="/documents/img/tree_exp.png" border="0" /></a>';
		    
		}
		else { 
		    
		    if (last) { 
			t += '<a href="javascript:o.openNode('+key+')"><img src="/documents/img/tree_col_end.png" border="0" /></a>';
		    }
		    else { 
			
			t +=  '<b><a href="javascript:o.openNode('+key+')"><img src="/documents/img/tree_col.png" border="0" /></a></b>';
		    }
		}
	    }
	    else { 
		if (last) { 
		    t +=  '<img src="/documents/img/tree_end.png" border="0" />';
		}
		else { 
		    t +=  '<img src="/documents/img/tree_bar_con.png" border="0" />';
		}
	    }
	    
	    
	    t +=  node.renderNode(level);
	    
	    level++;
	    
	    if (node.getOpenNode()) {
		
		var c = node.children;
		
		//MochiKit.Logging.log('now processing node '+node.name + ', with '+c.length+' children nodes');	    
		
		var cs = new Array();
		for(var i=0; i<c.length; i++) { 		    
		    last = (i==c.length-1);
		    //MochiKit.Logging.log('<p>', c[i].accession, '</p>');
		    t = t + this.renderLevel(t, c[i], level, last);
		    
		}
		
	    }
	    
	}
	return t;
	//MochiKit.Logging.log('renderLevel end'); 
    },
    
    addNode: function(node) { 
	//MochiKit.Logging.log('addNode: adding node ' + node.getName());
	var key = this.newNodeKey();
	node.setNodeKey(key);
	//MochiKit.Logging.log('generated node key '+key);
	this.nodelist[key]=node;
    },
    
    getNode: function(key) { 
	return this.nodelist[key];
    },
    
    
    closeNode: function(key) { 
	var n = this.getNode(key);
	n.closeNode();
	this.render();
    },
    
    openNode: function(key) { 
	//MochiKit.Logging.log('opening node ' + key);
	this.workingMessage(true);
	var n = this.getNode(key);
	n.openNode();
	var c = n.getChildren();
	for (var i=0; i<c.length; i++) { 
	    c[i].unHide();
	}
       	this.render();
	this.workingMessage(false);
    },
    
    hideNode: function(key) { 
	var n = this.getNode(key);
	n.hide();
	this.render();
    },
    
    unHideNode: function(key) { 
	this.getNode().unHide();
	this.render();
    },
    
    findNode: function(node) { 
    },
    
    newNodeKey: function() { 
	this.nodeKey++;
	return this.nodeKey;
    },
    
    resetNodeKey: function() { 
	this.nodeKey=0;
    },
    
    showParentage: function(accession) {
	MochiKit.Logging.log('the accession is :', accession );
	this.setSearchTerm(accession);
	if (accession.length < 5) { 
	    alert('The search text must be longer than 4 characters');
	    return;
	}
	this.workingMessage(true);
	var pL = this.getParentsList(accession);
	
	MochiKit.Logging.log('Retrieved parents '+pL.join(' '));
	
	var c = this.rootnode.getChildren();
	for (var i=0; i<c.length; i++) { 
	    this.recursiveParentage(c[i], pL, accession);
	    this.render();
	}
	this.workingMessage(false);
    },	

    //this is called when a search term is clicked from the search results list.
    //we explicitly hide the search results.
    searchTermParentage: function(accession) { 
	o.hideSearchResults();
	o.showParentage(accession);
    },

    getSearchTerm: function() { 
	return this.searchTerm;
    },
    
    setSearchTerm: function(searchTerm) { 
	this.searchTerm = searchTerm;
    },
    getSearchValue: function() { 
	return this.searchValue;
    },
    
    setSearchValue: function(searchValue) { 
	this.searchValue = searchValue;
    },
    
    recursiveParentage: function(currentNode, parentsList, accession) { 
	
	if (currentNode.getAccession() == accession) {
	    //MochiKit.Logging.log('unHiding '+currentNode.getAccession() + ' ' + accession);
	    currentNode.unHide();
	    currentNode.setHilite(true);
	}
	else {
	    
	    //MochiKit.Logging.log('node is ' + currentNode.getAccession() + ' accession= ' , accession);
	    if (this.hasMatch(parentsList, currentNode.getAccession())) { // indexOf does not seem to be implemented widely.
		//MochiKit.Logging.log('Opening node '+ currentNode.getName());
		currentNode.openNode();
		currentNode.unHide();
	    }
	    else { 
		//MochiKit.Logging.log('Current node '+currentNode.getAccession()+' does not match parent list ' + parentsList.join(' '));
		currentNode.hide();
	    }
	    
	    var c = currentNode.getChildren();
	    for (var i=0; i<c.length; i++) { 
		this.recursiveParentage(c[i], parentsList, accession);
	    }
	}
    },

    //check if a list contains a certain member
    hasMatch: function(list, value) { 
	for (var i=0; i<list.length; i++) { 
	    if (list[i] == value) { 
		return true;
	    }
	}
	return false;
    },
    
    //clears all hiliting in the tree.
    clearHiliting: function() { 
	this.recursiveHiliteClearing(this.rootnode);
	this.render();
    },
    
    recursiveHiliteClearing: function(node) { 
	node.setHilite(false);
	var c = node.getChildren();
	for (var i=0; i<c.length; i++) { 
	    this.recursiveHiliteClearing(c[i]);
	}
    },
    
    getParentsList: function(accession) { 
	//MochiKit.Logging.log('Fetching children for node '+this.getName());
	
	var parentsList = new Array();
	

	new Ajax.Request('/chado/ajax_ontology_browser.pl', {
	    parameters: { node: accession, action: 'parents' }, 
	    asynchronous: false,
			      on503: function() { 
	    	alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },

	    onSuccess: function(request) {
		
		var responseText = request.responseText;
		
		var t = responseText.split('#');
		
		//MochiKit.Logging.log('Children count ' +  t.length);
		
		for (var i=0; i<=t.length; i++) { 
		    var j = t[i].split('*');
		    //MochiKit.Logging.log(i + '. Parent: ID: '+ j[0] + ' Name: ' + j[1], '' );
		    
		    //MochiKit.Logging.log('Processing '+j[0]);
		    parentsList.push(j[0]);
		    
		    //MochiKit.Logging.log('Child accession: '+childNode.getAccession());
		    
		}
		
		//MochiKit.Logging.log('Rendering again...');
		//parentNode.browser.render();      
		
	    }
			      
			      });
	return parentsList;
    },
    
    //Make an ajax response that finds all the ontology terms with names/definitions/synonyms/accessions like the current value of the ontology input
    getOntologies: function(db_name, search_string) {
	this.workingMessage(true);
	//	var search_string= document.getElementById('ontology_term_input').value;
	//	var db_name = document.getElementById('cv_select').value;
	o.setSelected(db_name);
	if(search_string.length<4){
	    alert('The search text must be longer than 4 characters');
	}
        else{
	    new Ajax.Request('/chado/ajax_ontology_browser.pl', {
		parameters: {action: 'match', term_name: search_string, db_name: db_name },
		asynchronous: false,
			    on503: function() { 
	    	alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },

		onSuccess: function(request) {
		    var matchNodes = new Array();
		    var responseText = request.responseText;
		    
		    var responseArray = responseText.split('|');
		    responseArray.pop();
		    
		    var s='';
		    o.setSearchResponseCount(responseArray.length);
		    MochiKit.Logging.log('Matched '+responseArray.length+' terms');
		    for (var i=0; i<responseArray.length; i++) { 
			var ontologyObject = responseArray[i].split('--');
			var searchResults= responseArray[i].split('*');
			MochiKit.Logging.log('getOntologies found term ',  ontologyObject[1] );
			MochiKit.Logging.log('search term ', search_string);
			matchNodes.push(ontologyObject[0]); ///
			s +='<a href=javascript:o.searchTermParentage(\''+ontologyObject[1]+'\')>'+searchResults[1]+'</a><br />';
		    }
	//		    MochiKit.Logging.log('the search results:' , s) ;
		    MochiKit.Logging.log('the search string:' , search_string) ;
		    
		    if (s === '') { s = '(no terms found) '; }
		    o.setSearchResults('<div class="topicbox">Search term: <b>'+search_string+'</b></div><div class="topicdescbox">'+s+'</div>');
		    o.showSearchResults();
		    o.setSearchValue(search_string);
		    
		    o.render();
		}
	    });
	}
	this.workingMessage(false);
	
    },

    getSearchResults: function() { 
	return this.searchResults || '';
    },
    
    setSearchResults: function(searchResults) {
	//MochiKit.Logging.log('searh results= ',searchResults);
	this.searchResults = searchResults;
    },
    
    //showSearchResults, hideSearchResults
    //
    //hides the result section of the search but keeps the 
    //the un/hide toggle button visible
    //
    showSearchResults: function() { 
	this.showResults = true;
	this.showSearchButton();
	this.setSearchButtonText();
	document.getElementById('search_results').style.display='inline';
    },

    hideSearchResults: function() { 
	this.showResults = false;
	this.setSearchButtonText();
	document.getElementById('search_results').style.display='none';
    },
    
    //accessor setSearchResponseCount, getSearchResponseCount
    //property defines how many items were found in the search
    //used to display that number in the un/hide toggle button
    setSearchResponseCount: function(c) { 
	this.searchCount = c;
    },

    getSearchResponseCount: function() { 
	return this.searchCount || 0;
    },

    toggleSearchResultsVisible: function() { 
	if (this.isSearchResultsVisible() === true) { this.hideSearchResults(); }
	else { 
	    this.showSearchResults();
	}
    },

    isSearchResultsVisible: function() { 
	return this.showResults;
    },


    hideSearchButton: function() { 
	document.getElementById("hide_link").style.display="none";
    },

    showSearchButton: function() { 
	document.getElementById("hide_link").style.display="inline";
    },





    setSearchButtonText: function() { 

	if (this.getSearchResponseCount() === 0) { 
	    this.hideSearchButton();
	}
	else { 
	    this.showSearchButton();
	}


	if (this.isSearchResultsVisible()) { 
	    this.searchButtonText = 'hide ' + this.getSearchResponseCount() + ' results';
	}
	else { 
	    this.searchButtonText = 'show '+this.getSearchResponseCount()+ ' results'; 
	}


	if (document.getElementById('hide_link')) { 
	    document.getElementById('hide_link').value=this.searchButtonText;
	}
	return this.searchButtonText;
    },
    
    getSelected: function() { 
	return this.selected || '';
    },
    
    setSelected: function(selected) {
	this.selected = selected;
    },
    
    isSelected: function(db_name) {
	var selected_db_name=o.getSelected();
	if (selected_db_name == db_name) {
	    return 'SELECTED' ;
	}else { return '' ; }
    },


    // the following function is deprecated.
    //
    fetchMatches: function (searchText) { 
	
	//MochiKit.Logging.log('Fetching children for node '+this.getName());
	
	new Ajax.Request('/chado/ajax_ontology_browser.pl', {
	    parameters: { node: searchText, action: 'match' }, 
	    asynchronous: false,
	    	    on503: function() { 
	    	alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },

	    onSuccess: function(request) {
		
		//MochiKit.Logging.log('HELLO WORLD!');
		var matchNodes = new Array();
		var responseText = request.responseText;
		
		var t = responseText.split('#');
		
		//	       t.pop(); //remove last element from the array
		
		//MochiKit.Logging.log('Matched '+t.length+' nodes');
		for (var i=0; i<t.length; i++) { 
		    var j = t[i].split('*');
		    
		    //MochiKit.Logging.log('matching node: '+ j[0]);
		    matchNodes.push(j[0]); ///
		}
		
		return matchNodes;
	    }
	});
	
    },

    setLinkToTextField: function(linkToTextField) { 
	this.linkToTextField=linkToTextField;
    },

    setShowSelectTermButtons: function(showLinks) { 
	this.showLinks = showLinks;
    },

    getShowSelectTermButtons: function() { 
	return this.showLinks;
    },
    
    copySelectedToTextField: function(node) { 
	var copyToElement = document.getElementById(node.linkToTextField);
	if (copyToElement != undefined) { 
	    copyToElement.setValue(node.getName());
	}

    }
    
//     submitFormWithEnter: function(myfield,e) {
// 	var keycode;
// 	if (window.event) keycode = window.event.keyCode;
// 	else if (e) keycode = e.which;
// 	else return true;
	
// 	if (keycode == 13)
// 	{
// 	    myfield.form.submit();
// 	    return false;
// 	}
// 	else
// 	return true;
//     }

};



Node = function(browser) { 
    //MochiKit.Logging.log('Node constructor...');
    this.children = new Array();
    this.parents = new Array();
    this.browser = browser;
    //MochiKit.Logging.log('adding node to the browser...');
    
    this.browser.addNode(this);
    //MochiKit.Logging.log('done...');
    this.nodeId=0;
    
    //MochiKit.Logging.log('Node constructor: Created node.');
};

Node.prototype = { 
    
    setName: function(name) { 
	this.name=name;
    },
    
    getName: function() { 
	return this.name;
    },
    
    setAccession: function(accession) { 
	this.accession=accession;
    },
    
    getAccession: function() { 
	return this.accession;
    },
    
    setCVtermID: function(cvtermid) { 
	this.cvtermid=cvtermid;
    },
    
    getCVtermID: function() { 
	return this.cvtermid;
    },
    
    setNodeKey: function(key) { 
	this.nodeKey = key;
    },
    
    getNodeKey: function() { 
	return this.nodeKey;
    },
    
    setBrowser: function(browser) { 
	this.browser = browser;
    },
    
    getBrowser: function() { 
	return this.browser;
    },
    
    setOpenNode: function(status) { 
	this.nodeOpen = status;
    },
    
    getOpenNode: function() { 
	return this.nodeOpen;
    },
    setRelType: function(reltype) { 
	this.reltype=reltype;
    },
    
    getRelType: function() { 
	return this.reltype;
    },
    openNode: function() { 
	this.setOpenNode(true); 
	if (this.hasChildren() && !this.getChildrenFetched()) { 
	    this.fetchChildren(this);
	    this.setChildrenFetched(true);
	}
    },
    
    closeNode: function() { 
	this.setOpenNode(false);
    },
    
    hide: function() { 
	this.hidden = true;
    },
    
    unHide: function() { 
	this.hidden = false;
    },
    
    isHidden: function() { 
	return this.hidden;
    }, 
    
    setChildrenFetched: function(fetched) { 
	this.childrenFetched=fetched;
    },
    
    getChildrenFetched: function() { 
	return this.childrenFetched;
    },
    
    setParentsFetched: function(fetched) { 
	this.parentsFetched = fetched;
    },
    
    getParentsFetched: function() { 
	return this.parentsFetched;
    },
    
    addChild: function (child) { 
	//MochiKit.Logging.log('Adding child '+child.name + ' to '+ this.name);
	var c = child;
	var p = this;
	this.children.push(c);
	child.parents.push(p);
    },
    
    getChildren: function () { 
	return this.children;
    },
    
    setParents: function(p) { 
	this.parents = p;
    },
    
    getParents: function() { 
	return this.parents;
    },
    
    setHasChildren: function(childrenFlag) { 
	this.childrenFlag = childrenFlag;
    },
    
    hasChildren: function() { 
	//MochiKit.Logging.log('Number of children for node '+this.getName()+' is ' +this.children.length);
	//if (this.children.length > 0) { 
	//    return true;
	//	}
	//else { 
	//    return false;
	//}
	return this.childrenFlag;
    },
    
    addParent: function (parent) { 
	var p = parent;
	this.parents.push(p);
    },
    
    getParents: function () { 
	if (!this.getParentsFetched()) { 
	    var p = this.fetchParents;
	    this.parents = p;
	}
	return this.parents;
    },
    
    renderNode: function (level) { 
	//MochiKit.Logging.log('Rendering node '+this.getName());
	
	//      if (this.getOpenNode()) { 
	//create indent
	
	//write out link
	
	var hiliteStyle = 'background-color:white';
	if (this.isHilited()) { 
	    hiliteStyle = 'background-color:yellow';
	}
	
	// add a button to select this node and fill it into a textfield
	// as provided by linkToTextField
	var link = "";
	//	if (this.getBrowser().linkToTextField==true) { 
	if (this.getBrowser().getShowSelectTermButtons()) { 
	    link = '<a href="javascript:o.copySelectedToTextField(this)"><img src="/documents/img/select.png" border="0" /></a>';
	}
	   
	var relType=this.getRelType() || '';
	return relType + ' <span style="'+hiliteStyle+'"><a href="/chado/cvterm.pl?action=view&amp;cvterm_id='+this.getCVtermID()+'">'+this.getAccession() + '</a> ' + this.getName() + ' ' + link +'</span><br />';
    },
    
    setHilite: function(h) { 
	this.hilite=h;
    },
    
    
    isHilited: function() { 
	return this.hilite;
    },
    
    fetchChildren: function () { 
	
	//MochiKit.Logging.log('Fetching children for node '+this.getName());
	
	var parentNode = this;
	new Ajax.Request('/chado/ajax_ontology_browser.pl', {
	    parameters: { node: parentNode.getAccession(), action: 'children' }, 
			  asynchronous: false,
	    on503: function() { 
	    	alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },

	   onSuccess: function(request) {
			      
			      
			      //MochiKit.Logging.log('HELLO WORLD!');
			      
			      var responseText = request.responseText;
			      
			      var t = responseText.split('#');
			      
			      //MochiKit.Logging.log('Children count ' +  t.length + '<br />');
			      
			      for (var i=0; i<t.length; i++) { 
				  var j = t[i].split('*');
				  //MochiKit.Logging.log(i + '. Child: ID: '+ j[0] + ' Name: ' + j[1] +  ' <br />');
				  
				  //MochiKit.Logging.log('Processing '+j[0]);
				  
				  var childNode = new Node(o);
				  
				  childNode.setAccession(j[0]);
				  childNode.closeNode();
				  childNode.unHide();
				  childNode.setName(j[1]);
				  childNode.setCVtermID(j[2]);
				  childNode.setRelType(j[4]);
				  //MochiKit.Logging.log('hasChildren = '+j[2]);
				  if (j[3]==1) { 
				      childNode.setHasChildren(true);
				  }
				  else { 
				      childNode.setHasChildren(false);
				  }
				  
				  parentNode.addChild(childNode);
				  
				  //MochiKit.Logging.log('Child accession: '+childNode.getAccession()+'<br />');
				  
			      }
			      //MochiKit.Logging.log('Rendering again...');
			      parentNode.browser.render();      
			      
			  }
					    });
    },
    
    
    fetchParents: function() { 
	//MochiKit.Logging.log('Fetching children for node '+this.getName());
	
	var childNode = this;
	
	new Ajax.Request("/chado/ajax_ontology_browser.pl", {
	    parameters: { node: childNode.getAccession(), action: 'parents' }, 
	      asynchronous: false,
	      onSuccess: function(request) {
		  
		  //MochiKit.Logging.log('HELLO WORLD!');
		  
		  var responseText = request.responseText;
		  
		  var t = responseText.split('#');
		  
		  //MochiKit.Logging.log('Children count ' +  t.length + '<br />');
		  
		  for (var i=0; i<t.length; i++) { 
		      var j = t[i].split('*');
		      //MochiKit.Logging.log(i + '. Child: ID: '+ j[0] + ' Name: ' + j[1] +  ' <br />');
		      
		      //MochiKit.Logging.log('Processing '+j[0]);
		      var parent = new Node(o);
		      
		      parent.setAccession(j[0]);
		      parent.closeNode();
		      parent.unHide();
		      parent.setName(j[1]);
		      parent.setCVtermID(j[2]);
		      parent.setRelType(j[4]);
		      //MochiKit.Logging.log('hasChildren = '+j[1]);
		      if (j[3]==1) { 
			  parent.setHasChildren(true);
		      }
		      else { 
			  parent.setHasChildren(false);
		      }
		      
		      parentList.push(parent);
		      
		      //MochiKit.Logging.log('Child accession: '+childNode.getAccession()+'<br />');
		      
		  }
		  //MochiKit.Logging.log('Rendering again...');
		  //parentNode.browser.render();      
		  return parentList;
	      }
				});
    }

    
};	
