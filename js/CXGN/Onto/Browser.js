//
// AJAX-based ontology browser
//
// Lukas Mueller and Naama Menda
//
// Sol Genomics Network (http://solgenomics.net/ )
//
// Spring 2008
// Fall 2010: added better caching for the parent view
/* 

   This browser consists of two objects, Node and Browser. The browsers manages the rendering of the tree and searching. The Node represents a term embedded in a linked DAG data structure. 


 */
JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Logging');
JSAN.use('MochiKit.Async');
JSAN.use('Prototype');
JSAN.use('CXGN.Effects');
JSAN.use('CXGN.Onto.Browser');
JSAN.use('jquery');


if (!CXGN) CXGN = function() {};
if (!CXGN.Onto) CXGN.Onto = function() {};


CXGN.Onto.Browser = function () { 

    this.nodelist = new Array();
    this.resetNodeKey();
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

	document.getElementById("ontology_browser_input").value='';
	document.getElementById("ontology_term_input").value='';
	
	this.initializeBrowser(this.rootNodes);

	this.render();
    },

    setUpBrowser: function() {

	document.write('<table cellpadding="0" summary=""><tr><td><div id="ontology_browser_input" >&nbsp;&nbsp;&nbsp;</div></td>'); // the element for the go id parentage search
	document.write('<td width="*" align="right"><div id="working" style="margin-top:8px" >&nbsp;<img src="/documents/img/throbber.gif" />&nbsp;</div></td></tr></table>');
	document.write('<div id="ontology_term_input" ></div>');     // the element for the search
	document.write('<input id="hide_link" type="button" value="show results" display="none" onClick="MochiKit.Visual.toggle(\'search_results\', \'blind\'); o.toggleSearchResultsVisible(); o.setSearchButtonText();  "><br />');

	document.write('<div id="search_results" ></div>');    
	document.write('<div id="ontology_browser" style="font-size:12px; line-height:10px; font-face:arial,helvetica" >&nbsp;</div>');  // the element for the browser

    },

    initializeBrowser: function(rootNodes) { 
	this.setSelected();
	this.setSearchTerm('');
	this.setSearchValue('');
	this.setSearchResults('');
        this.setRootNodes(rootNodes);
	this.fetchRoots(rootNodes);
	this.fetchMenuItems();
	this.hideSearchButton();
	this.setSearchResponseCount(0);
	this.render();
    },

    getParents: function() {
	return this.parents;
    },

    setRootNodes: function(nodes) {
	this.rootNodes = nodes;
    },

    getRootNodes: function() {
	return this.rootNodes;
    },

    fetchRoots: function(rootNodes) {

	new Ajax.Request("/ajax/onto/roots", {
		parameters:   { nodes: rootNodes },
		asynchronous: false,
		method: 'get',
		on503: function() {
		    alert('An error occurred! The database may currently be unavailable. Please check back later.');
		},
		onSuccess: function(request) {
		    var json = request.responseText;
		    //MochiKit.Logging.log('COMPLETE!');
		    var x = eval("("+json+")");
		    //MochiKit.Logging.log('RESPONSETEXT = ' + x);
		    if (x.error ) { alert(x.error) ; }
		    else {
			o.rootnode = new Node(o);

			o.rootnode.setName('');
			o.rootnode.setAccession('root');
			o.rootnode.openNode();
			o.rootnode.unHide();
			o.rootnode.setHasChildren(true);

			for (var i=0; i<x.length; i++) {

			    var childNode = new Node(o);

			    o.rootnode.addChild(childNode);
			    childNode.json2node(x[i]);
			}
		    }
		}
	    });
    },

    fetchMenuItems: function() { 
		new Ajax.Request("/ajax/onto/menu", {
		parameters:   { },
		asynchronous: false,
		method: 'get',
		on503: function() {
		    alert('An error occurred! The database may currently be unavailable. Please check back later.');
		},
		onSuccess: function(request) {
		    var json = request.responseText;
		    //MochiKit.Logging.log('COMPLETE!');
		    var x = eval("("+json+")");
		    //MochiKit.Logging.log('RESPONSETEXT = ' + x);
		    if (x.error ) { alert(x.error) ; }
		    o.menu = x;

		}
	    });
    },


    workingMessage: function(status) {
	//MochiKit.Logging.log('the working message = ' , status );
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
	//MochiKit.Logging.log('the value of ontology_browser_input is ...', (document.getElementById('ontology_browser_input')).value);
	
	var s = '<form name="search_id_form" style="margin-bottom:0" onSubmit="javascript:o.showParentage(this.ontology_browser_input.value); return false;" >';
	s +=       '<div id="search_by_id" style="width:100%; margin-bottom:0" >';
	s += '<table summary="" cellpadding="5" cellspacing="0" width="100%" ><tr><td>';
	s += 'Find exact ID &nbsp; <input id="ontology_browser_input" name="ontology_browser_input_name" type="text"  size="12" style="margin-bottom:0" /><input id="ontology_browser_submit" value="Find" type="submit" style="margin-bottom:0" />';
	s += '</td><td style="text-align: right; padding-left:10px"><input id="reset_hiliting" type="button" value="clear highlight" onClick="javascript:o.clearHiliting()" style="margin-bottom:0" /> | <input id="reset_tree" type="button" value="reset view" onClick="javascript:o.resetBrowser()" style="margin-bottom:0" /></td></tr></table>';
	s +='</div></form>';
	
	var e = document.getElementById('ontology_browser_input');
	//MochiKit.Logging.log('the value of ontology_browser_input is ...',document.getElementById('ontology_browser_input').value);
	e.innerHTML = s;
	document.getElementById('ontology_browser_input').value=(o.getSearchTerm());
	this.workingMessage(false);
    },

    renderSearchByName: function( nameSpace ) {
        if ( !nameSpace ) {
            var s = '<form style="margin-bottom:0" name="SearchByNameForm" onsubmit="javascript:o.getOntologies(this.cv_select.value, this.ontology_term_input.value); return false;" >';
        }  else {
            var s = '<form style="margin-bottom:0" name="SearchByNameForm" onsubmit="javascript:o.getOntologies(\'' + nameSpace + '\', this.ontology_term_input.value); return false;" >';
        }
        s += '<div id="search_by_name"  style="margin-bottom:0" >';
        s += '<table summary="" cellpadding="5" cellspacing="0"><tr><td align="center" >';
	s += 'Search for text <input id="ontology_term_input" name="ontology_term_input_name" type="text" size="30"  />';

        //print the select drop-down only if you not rendering a specific cv

        if (!nameSpace) {
            // s += '<select id="cv_select" >';
            // s += '<option value="GO" ' + o.isSelected("GO") +'>GO (gene ontology)</option>';
            // s += '<option value="PO" ' + o.isSelected("PO") +'>PO (plant ontology)</option>';
            // s += '<option value="SP" ' + o.isSelected("SP") +'>SP (Solanaceae phenotypes)</option>';
            // s += '<option value="PATO" ' + o.isSelected("PATO") +'>PATO (Phenotype and trait)</option>';
            // s += '<option value="SO" ' + o.isSelected("SO") +'>SO (Sequence ontology)</option>';
            // s += '</select>';

	    s += o.menu;
        } else {
            o.isSelected(nameSpace);
        }
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
	    document.getElementById("hide_link").style.display="inline";
	}

	o.setSearchButtonText();

	document.getElementById("search_results").innerHTML=this.getSearchResults();

        var children = this.rootnode.getChildren();
        for (var i=0; i<children.length; i++) {
            s = s + this.renderLevel(s, children[i], 1);
        }
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
	this.setSearchTerm(accession);
	if (accession.length < 3) { 
	    alert('The search text must be longer than 2 characters');
	    return;
	}
	this.workingMessage(true);

	var pL = this.getParentsList(accession);
        if (pL.length > 0) {
            var cache = this.fetchCachedChildren(accession);
            //MochiKit.Logging.log('Cache length now: '+cache.length);
            this.setCache(cache);
            //MochiKit.Logging.log('Retrieved parents '+ pL.join(' '));
            var c = this.rootnode.getChildren();
            for (var i=0; i<c.length; i++) { 
                this.recursiveParentage(c[i], pL, accession);
                //this.render();
            }
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
	var browser = this;
	new Ajax.Request('/ajax/onto/parents', {
		parameters: { node: accession }, 
		    asynchronous: false,
		    method: 'get',
		    on503: function() { 
		    alert('An error occurred! The database may currently be unavailable. Please check back later.');
		},
		    
		    onSuccess: function(request) {
		    var json = request.responseText;
		    var parents = eval("("+json+")");
		    if ( parents.error ) { alert(parents.error) ; }
		    else {
			for (var i=0; i<parents.length; i++) { 
			    //alert('processing '+parents[i].accession);
			    parentsList.push(parents[i].accession);
			}
			//alert('Now were done!');
		    }
		}
	});
	return parentsList;
    },
    
    fetchCachedChildren:function(accession) { 
	var fetch_response;
	jQuery.ajax( {
                url: '/ajax/onto/cache',
                    async: false,
                    dataType:"json",
                    data: 'node='+accession,
                    success: function(response) {
                    fetch_response = response;
                    if (response.error) { alert(response.error) ; }
                }

                //new Ajax.Request('/ajax/onto/cache', {
                //parameters: { node: accession }, 
                //  asynchronous: false,
                //  method: 'get',
                //  on503: function() { 
                //  alert('An error occurred! The database may currently be unavailable. Please check back later.');
                //},
                //  onSuccess: function(request) {
                //  var json = request.responseText;
                //  cache = eval("("+json+")");
                //  if ( cache.error ) { alert(cache.error) ; }
                //  else {
                //      MochiKit.Logging.log('Cache '+cache.length);
                //  }
                //}
        });
        return fetch_response;
    },


    //Make an ajax response that finds all the ontology terms with names/definitions/synonyms/accessions like the current value of the ontology input
    getOntologies: function(db_name, search_string) {
	this.workingMessage(true);
        o.setSelected(db_name);
	if(search_string.length<3){
	    alert('The search text must be longer than 2 characters');
	}
        else{
	    new Ajax.Request('/ajax/onto/match', {
		    parameters: { term_name: search_string, db_name: db_name },
		    asynchronous: false,
		    method: 'get',
		    on503: function() {
			alert('An error occurred! The database may currently be unavailable. Please check back later.');
		    },
		    onSuccess: function(request) {
			var matchNodes = new Array();
			var json = request.responseText;
                        var x = eval("("+json+")");
			if ( x.error ) { alert(x.error) ; }
                        else {
                            var s='';
			    o.setSearchResponseCount(x.length);
			    //MochiKit.Logging.log('Matched '+responseArray.length+' terms');
			    for (var i=0; i<x.length; i++) {
				matchNodes.push(x.accession); ///
				s +='<a href=javascript:o.searchTermParentage(\''+x[i].accession+'\')>'+x[i].cv_name+' ('+x[i].accession+') '+x[i].cvterm_name+'</a><br />';
			    }
			    //		    MochiKit.Logging.log('the search results:' , s) ;
			    //MochiKit.Logging.log('the search string:' , search_string) ;

			    if (s === '') { s = '(no terms found) '; }
			    o.setSearchResults('<div class="topicbox">Search term: <b>'+search_string+'</b></div><div class="topicdescbox">'+s+'</div>');
			    o.showSearchResults();
			    o.setSearchValue(search_string);
			    o.render();
			}
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

    },

    setCache: function(cache) { 
	// convert to hash
	var hash = new Array();
	for(var i=0; i<cache.length; i++) { 
	    if (typeof(hash[cache[i].parent])=='undefined') { 
		hash[cache[i].parent]=new Array();
	    }
	    hash[cache[i].parent].push(cache[i]);
	}
	this.childrenCache = hash;
	
	//MochiKit.Logging.log('setCache: '+ cache.length + ' entries');

    },

    getCache: function() { 
	if (typeof(this.childrenCache) == 'undefined') { 
	    this.childrenCache = new Array();
	}
	return this.childrenCache;
    },

    getChildrenFromCache: function(accession) { 
	var cache = this.getCache();
	if (typeof(cache[accession]) != 'undefined') { 
	    return cache[accession];
	}
	
	
    },
    
    hasChildrenCache: function(accession) { 
	var cache = this.getCache();

	if (typeof cache[accession] != 'undefined') { 
	    //MochiKit.Logging.log(accession + " has childrenCache");
	    if (cache[accession].length>0) { 
		return 1;	
	    }
	    
	}
	return 0;
    }    
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

   
    /*
      setHasChildren(), hasChildren(): a boolean property if this node has children
    */
    setHasChildren: function(childrenFlag) { 
	this.childrenFlag = childrenFlag;
    },

    hasChildren: function() { 
	return this.childrenFlag;
    },
    
    /*
      addParent(parentNode): add another Node object has a parent to this Node.
    */
    addParent: function (parent) { 
	var p = parent;
	this.parents.push(p);
    },
    
    /*
      getParents() : return all the parents of this Node (remember it's a DAG, 
      there can be multiple parents!
    */
    getParents: function () { 
	if (!this.getParentsFetched()) { 
	    var p = this.fetchParents;
	    this.parents = p;
	}
	return this.parents;
    },

    /*
      renderNode: renders this node to the browser.
    */
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
	var accession = this.getAccession();
	if (o.hasChildrenCache(accession)) { 
	    //MochiKit.Logging.log('retrieving accession from cache '+accession);
	    var children = o.getChildrenFromCache(accession);
	    for(var i=0; i<children.length; i++) { 
		//MochiKit.Logging.log('adding child node '+children[i].accession);
		var childNode = new Node(o);
		childNode.json2node(children[i]);
		childNode.closeNode();
		childNode.unHide();
		parentNode.addChild(childNode);
	    }
	    return;
	}
	new Ajax.Request('/ajax/onto/children', {
		parameters: { node: accession },
		asynchronous: false,
		method: 'get',
		    on503: function() { 
		    alert('An error occurred! The database may currently be unavailable. Please check back later.');
		},
		    onSuccess: function(request) {
		    //MochiKit.Logging.log('HELLO WORLD!');
		    var json = request.responseText;
		    var x = eval("("+json+")");
		    if ( x.error ) { alert(x.error) ; }
		    else {
			for (var i=0; i<x.length; i++) { 
			    var childNode = new Node(o);
			    childNode.json2node(x[i]);
			    childNode.closeNode();
			    childNode.unHide();
			    parentNode.addChild(childNode);
			}
			parentNode.browser.render();
		    }
		}
	});
    },
    fetchParents: function() { 
	//MochiKit.Logging.log('Fetching children for node '+this.getName());
	var childNode = this;
	new Ajax.Request("/ajax/onto/parents", {
		parameters: { node: childNode.getAccession() }, 
		    asynchronous: false,
		    method: 'get',
		    onSuccess: function(request) {
		    var json = request.responseText;
		    var x = eval("("+json+")");
		    if ( x.error ) { alert(x.error) ; }
		    else {
			//MochiKit.Logging.log('Children count ' +  t.length + '<br />');
			for (var i=0; i<x.length; i++) { 

			    var parent = new Node(o);

			    parent.json2node(x[i]);
			    parent.closeNode();
			    parent.unHide();
			    parentList.push(parent);
			    //MochiKit.Logging.log('Child accession: '+childNode.getAccession()+'<br />');
			}
			//MochiKit.Logging.log('Fetched '+parentList.length + ' parents');
                        return parentList;
		    }
		}
	});
    },

    json2node: function(json) { 
	this.setAccession(json.accession);
	this.setName(json.cvterm_name);
	this.setCVtermID(json.cvterm_id);
	this.setRelType(json.relationship);
	//MochiKit.Logging.log('hasChildren = '+j[2]);
	if (json.has_children == 1) { 
	    this.setHasChildren(true);
	}
	else { 
	    this.setHasChildren(false);
	}
    }
};
