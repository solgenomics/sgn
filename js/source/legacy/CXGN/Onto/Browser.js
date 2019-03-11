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
   This browser consists of two objects, Node and Browser. 
   The browsers manages the rendering of the tree and searching. 
   The Node represents a term embedded in a linked DAG data structure. 
 */

//JSAN.use('MochiKit.DOM');
//JSAN.use('MochiKit.Visual');
//JSAN.use('MochiKit.Logging');
//JSAN.use('MochiKit.Async');
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
	this.rootnode = new Node(this);
	this.rootnode.setName('ROOT');
	this.rootnode.openNode();
	var p2;
	for (var i=0; i<5; i++) { 
	    var n = new Node(this);

	    var nodeName = 'node';
	    n.setName(nodeName);
	    n.openNode();
	    if (i==2) { 
		p2=n; 
		p2.openNode();
		p2.unHide();
	    }
	    this.rootnode.addChild(n);
	    
	}

	for (i=0; i<3; i++) { 
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

	jQuery.ajax({ 
	    url: "/ajax/onto/roots",
	    data:  { 'nodes' : rootNodes },
	    async: false,
	    method: 'get',
	    error: function() {
		alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },
	    success: function(response) {
		if (response.error ) { alert(response.error) ; }
		else {
		    var o = this.o;
		    o.rootnode = new Node(o);
		    o.rootnode.setName('');
		    o.rootnode.setAccession('root');
		    o.rootnode.openNode();
		    o.rootnode.unHide();
		    o.rootnode.setHasChildren(true);

		    for (var i=0; i<response.length; i++) {
			var childNode = new Node(o);
			
			o.rootnode.addChild(childNode);
			childNode.json2node(response[i]);
		    }
		}
	    },
	    context: { o : this }
	});
    },
    
    fetchMenuItems: function() { 
	jQuery.ajax({ 
	    url: "/ajax/onto/menu",
	    data: { },
	    async: false,
	    method: 'get',
	    error: function() {
		alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },
	    success: function(response) {
		var o = this.o;

		if (response.error ) { alert(response.error) ; }
		o.menu = response;		
	    },
	    context: { o : this }
	});
    },
    
    workingMessage: function(status) {
	if (status) { jQuery('#working').dialog("open"); }
	else { jQuery('#working').dialog("close");}
    },
    
    renderSearchById: function() {
	var s = '<form name="search_id_form" style="margin-bottom:0" onSubmit="javascript:o.showParentage(this.ontology_browser_input.value); return false;" >';
	s +=       '<div id="search_by_id" style="width:100%; margin-bottom:0" >';
	s += '<table summary="" cellpadding="5" cellspacing="0" width="100%" ><tr><td>';
	s += 'Find exact ID &nbsp; <input id="ontology_browser_input" name="ontology_browser_input_name" type="text"  size="12" style="margin-bottom:0" /><input id="ontology_browser_submit" value="Find" type="submit" style="margin-bottom:0" />';
	s += '</td><td style="text-align: right; padding-left:10px"><input id="reset_hiliting" type="button" value="clear highlight" onClick="javascript:o.clearHiliting()" style="margin-bottom:0" /> | <input id="reset_tree" type="button" value="reset view" onClick="javascript:o.resetBrowser()" style="margin-bottom:0" /></td></tr></table>';
	s +='</div></form>';
	
	var e = document.getElementById('ontology_browser_input');

	e.innerHTML = s;
	document.getElementById('ontology_browser_input').value=(this.getSearchTerm());
	this.workingMessage(false);
    },
    
    renderSearchByName: function( nameSpace ) {
        if ( !nameSpace ) {
            var s = '<form style="margin-bottom:0" name="SearchByNameForm" onsubmit="javascript:o.getOntologies(this.cv_select.value, this.ontology_term_input.value); return false;" >';
        }  else {
            var s = '<form style="margin-bottom:0" name="SearchByNameForm" onsubmit="javascript:o.getOntologies(\'' + nameSpace + '\', this.ontology_term_input.value); return false;" >';
        }
        s += '<div id="search_by_name"  style="margin-bottom:0" >';
        s += '<table summary="" cellpadding="5" cellspacing="0"><tr><td >';
	s += 'Search for text <input id="ontology_term_input" name="ontology_term_input_name" type="text" size="20"  />';
	
        // print the select drop-down only if you not rendering a specific cv
	
        if (!nameSpace) {
	    s += this.menu;
        } else {
            this.isSelected(nameSpace);
        }
        s += '<input id="term_search" type="submit" value="Search"  />';
	s += '</td></tr></table>';
	s += '</div></form>';
	
	var e = document.getElementById('ontology_term_input');
	e.innerHTML = s;
	document.getElementById('ontology_term_input').value=(this.getSearchValue());
    },
    
    render: function() {
	var s = '';

	if (this.searchResults) {
	    document.getElementById("hide_link").style.display="inline";
	}

	this.setSearchButtonText();

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
	var t = '';

	if ((node == undefined) || (node.isHidden())) { 
	}
	else { 
            for (var i=0; i<level-1; i++) { 
		t += '<img src="/documents/img/tree_bar.png" border="0" />';
	    }
	    if (node.hasChildren()) { 
		var key = node.getNodeKey();

		if (node.getOpenNode()) {
		    t +=  '<a id="close_cvterm_'+node.getCVtermID()+'" href="javascript:o.closeNode('+key+')"><img src="/documents/img/tree_exp.png" border="0" /></a>';

		}
		else { 

		    if (last) { 
			t += '<a id="open_cvterm_'+node.getCVtermID()+'" href="javascript:o.openNode('+key+')"><img src="/documents/img/tree_col_end.png" border="0" /></a>';
		    }
		    else { 

			t +=  '<b><a id="open_cvterm_'+node.getCVtermID()+'" href="javascript:o.openNode('+key+')"><img src="/documents/img/tree_col.png" border="0" /></a></b>';
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
		
                for(var i=0; i<c.length; i++) { 		    
		    last = (i==c.length-1);
		    t = t + this.renderLevel(t, c[i], level, last);   
		}	
	    }	    
	}
	return t;
    },
    
    addNode: function(node) { 
	var key = this.newNodeKey();
	node.setNodeKey(key);
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
            this.setCache(cache);
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
	this.hideSearchResults();
	this.showParentage(accession);
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

	    currentNode.unHide();
	    currentNode.setHilite(true);
	}
	else {
	    
	    if (this.hasMatch(parentsList, currentNode.getAccession())) { // indexOf does not seem to be implemented widely.

		currentNode.openNode();
		currentNode.unHide();
	    }
	    else { 

		currentNode.hide();
	    }
	    
	    var c = currentNode.getChildren();
	    for (var i=0; i<c.length; i++) { 
		this.recursiveParentage(c[i], parentsList, accession);
	    }
	}
    },

    // check if a list contains a certain member
    //
    hasMatch: function(list, value) { 
	for (var i=0; i<list.length; i++) { 
	    if (list[i] == value) { 
		return true;
	    }
	}
	return false;
    },
    
    // clears all hiliting in the tree.
    //
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
	var parentsList = new Array();
	var browser = this;
	jQuery.ajax( {
	    url: '/ajax/onto/parents',
	    data: { 'node' : accession }, 
	    async: false,
	    method: 'get',
	    error: function() { 
		    alert('An error occurred! The database may currently be unavailable. Please check back later.');
		},
		    
	    success: function(response) {
		if ( response.error ) { alert(response.error) ; }
		else {
		    for (var i=0; i<response.length; i++) { 
			parentsList.push(response[i].accession);
		    }
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
            data: { 'node' : accession },
            success: function(response) {
                fetch_response = response;
                if (response.error) { alert(response.error) ; }
            }	    
        });
        return fetch_response;
    },


    // Make an ajax response that finds all the ontology terms with 
    // names/definitions/synonyms/accessions like the current value 
    // of the ontology input
    //
    getOntologies: function(db_name, search_string) {
	this.workingMessage(true);
        this.setSelected(db_name);
	if(search_string.length<3){
	    alert('The search text must be longer than 2 characters');
	}
        else{
	    jQuery.ajax({
		url: '/ajax/onto/match',
		data: { 'term_name' : search_string, 'db_name' : db_name },
		async: false,
		method: 'get',
		error: function() {
		    alert('An error occurred! The database may currently be unavailable. Please check back later.');
		},
		success: function(response) {
		    var matchNodes = new Array();
		    var o = this.o;
		    if ( response.error ) { alert(response.error) ; }
                    else {
                        var s='';
			o.setSearchResponseCount(response.length);
			    for (var i=0; i<response.length; i++) {
				matchNodes.push(response.accession); ///
				s +='<a href=javascript:o.searchTermParentage(\''+response[i].accession+'\')>'+response[i].cv_name+' ('+response[i].accession+') '+response[i].cvterm_name+'</a><br />';
			    }

			
			if (s === '') { s = '(no terms found) '; }
			o.setSearchResults('<div class="topicbox">Search term: <b>'+search_string+'</b></div><div class="topicdescbox">'+s+'</div>');
			o.showSearchResults();
			o.setSearchValue(search_string);
			o.render();
		    }
		},
		context: { o : this }
		
	    });
	}
	this.workingMessage(false);
    },
    
    getSearchResults: function() { 
	return this.searchResults || '';
    },
    
    setSearchResults: function(searchResults) {
	this.searchResults = searchResults;
    },
    
    // showSearchResults(), hideSearchResults()
    //
    // hides the result section of the search but keeps the 
    // the un/hide toggle button visible
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
    
    // accessor setSearchResponseCount(), getSearchResponseCount()
    // property defines how many items were found in the search
    // used to display that number in the un/hide toggle button
    //
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
	var selected_db_name=this.getSelected();
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
	    if (cache[accession].length>0) { 
		return 1;	
	    }	    
	}
	return 0;
    }    
};

Node = function(browser) { 
    this.children = new Array();
    this.parents = new Array();
    this.browser = browser;
    this.browser.addNode(this);
    this.nodeId=0;
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
	return relType + ' <span style="'+hiliteStyle+'"><a id="cvterm_id_'+this.getCVtermID()+'" href="/cvterm/'+this.getCVtermID()+'/view">'+this.getAccession() + '</a> ' + this.getName() + ' ' + link +'</span><br />';
    },

    setHilite: function(h) { 
	this.hilite=h;
    },

    isHilited: function() { 
	return this.hilite;
    },

    fetchChildren: function () { 
	var parentNode = this;
	var accession = this.getAccession();
	if (this.getBrowser().hasChildrenCache(accession)) { 
	    var children = this.getBrowser().getChildrenFromCache(accession);
	    for(var i=0; i<children.length; i++) { 
		var childNode = new Node(o);
		childNode.json2node(children[i]);
		childNode.closeNode();
		childNode.unHide();
		parentNode.addChild(childNode);
	    }
	    return;
	}
	jQuery.ajax({
	    url: '/ajax/onto/children',
	    data: { 'node' : accession },
	    async: false,
	    method: 'get',
	    error: function() { 
		alert('An error occurred! The database may currently be unavailable. Please check back later.');
	    },
	    success: function(response) {
		if ( response.error ) { alert(response.error) ; }
		else {
		    for (var i=0; i<response.length; i++) { 
			var childNode = new Node(o);
			childNode.json2node(response[i]);
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
	var childNode = this;
	jQuery.ajax({
	    url: "/ajax/onto/parents",
	    data: { node: childNode.getAccession() }, 
	    async: false,
	    method: 'get',
	    success: function(response) {
		if ( response.error ) { alert(response.error) ; }
		else {
		    for (var i=0; i<response.length; i++) { 
			var parent = new Node(o);
			
			parent.json2node(response[i]);
			parent.closeNode();
			parent.unHide();
			parentList.push(parent);
		    }
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

	if (json.has_children == 1) { 
	    this.setHasChildren(true);
	}
	else { 
	    this.setHasChildren(false);
	}
    }
};
