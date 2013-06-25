/** 
* @class Locus
** DEPRECATED - this is used only on the locus page.
* The individual page is deprecated, and future pages should use
* CXGN.AJAX.Ontology which is more generic
* Function used in locus page
* @author Naama Menda <nm249@cornell.edu>
*
*/

JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');


JSAN.use('CXGN.Effects');
JSAN.use('CXGN.Phenome.Tools');
JSAN.use('Prototype');


JSAN.use('jquery');
JSAN.use('jqueryui');
JSAN.use('popup');


var Locus = {
    //update the registry input box when an option is selected. Not sure if we should do this or not
    updateRegistryInput:  function() {
	var select_box = $('registry_select');
	for (i=0; i < select_box.length; i++){
	    if(select_box.options[i].selected) {
		$('associate_registry_button').disabled = false;
	    }
	}
    },
    
    //Make an ajax response that finds all the registries with names or symbols like the current value of the registry input
    getRegistries: function(str)  {
	if(str.length==0){
	    var select = $('registry_select');
	    select.length=0;
	    $('associate_registry_button').disabled = true;
	} else{
	    new Ajax.Request("/phenome/registry_browser.pl", { //move to controller
		    parameters: { registry_name: str },
		    onSuccess: this.updateRegistrySelect
		});
	}
    },
    
    //Parse the ajax response and update the registry select box accordingly
    updateRegistrySelect: function(request) {
	var select =  $('registry_select');
	$('associate_registry_button').disabled = true;
	var responseText = request.responseText;
	var responseArray = responseText.split("|");
	
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    var registryObject = responseArray[i].split("*");
	    select[i].value = registryObject[0];
	    if (typeof(registryObject[1]) != "undefined"){
		select[i].text = registryObject[1];
	    }
	}
    },

    //Make an ajax response that adds a registry to the database and associates it with this locus
    addRegistry: function(locus_id, sp_person_id) {
	var registry_name = $('registry_name').value;
	var registry_symbol = $('registry_symbol').value;
	var registry_description = $('registry_description').value;
	
	if(registry_symbol == ""){
	    $("add_registry_button").disabled=false;	    
	    alert("You must enter a symbol for the new registry");
	    return false;
	}else if(registry_name == ""){
	    $("add_registry_button").disabled=false;
	    alert("You must enter a name for the new registry");
	    return false;
	}
	new Ajax.Request("/phenome/add_registry.pl", { // move to controller
		parameters: { registry_symbol: registry_symbol, registry_name: registry_name, registry_description: registry_description, sp_person_id: sp_person_id, locus_id: locus_id},
		
		onSuccess: function(response) {
		    //create an alert if the ajax request for adding a registry finds that the registry already exists
		    if (response.responseText == "already exists") {
			alert('That registry already exists');
		    } else{
			this.associateRegistry(locus_id, sp_person_id);
		    }
		}
	    });
    },

//Make an ajax response that associates the selected registry with this locus
    associateRegistry: function(locus_id, sp_person_id) {
	var registry_id =  $('registry_select').value;
	new Ajax.Request("/phenome/associate_registry.pl", { //move to controller
		parameters: { registry_id: registry_id, locus_id: locus_id, sp_person_id: sp_person_id },
		    onSuccess: Tools.reloadPage() //change this to
		    //onSuccess: function(response) {
		    //var json = response.responseText;
		    //var x =eval ("("+json+")");
		    //var e = $("locus_registry").innerHTML=x.response;
		    //if ( x.error ) { alert(x.error) ; }
		    //}
		    });
    },
    
    addRegistryView: function()  {	
	Effects.hideElement('registry_search');
	Effects.showElement('registry_add');
    },
    
    searchRegistries: function() {
	Effects.showElement('registry_search');
	Effects.hideElement('registry_add');
    },
    
    //Logic on when to enable the add registry button
    //move to Tools.enableButton
    enableButton: function() {
	var registry_name = $('registry_name').value;
	var registry_symbol = $('registry_symbol').value;
	if(registry_symbol != "" && registry_name != ""){
	    $("add_registry_button").disabled=false;	    
	} 
	else{
	    $("add_registry_button").disabled=true;
	}
    },

    //Make an ajax request that finds all the alleles related to the currently selected stock
    getAlleles: function(locus_id) {
	$("associate_stock_button").disabled=false;
	var stock_id = $('stock_select').value;
        new Ajax.Request("/phenome/allele_browser.pl", { //move to controller
		parameters: { locus_id: locus_id, stock_id: stock_id },
		    onSuccess: this.updateAlleleSelect } );
    },
    
    //Parse the ajax response to update the allele select box
    updateAlleleSelect: function(request) {
	var select = $('allele_select');
	var responseText = request.responseText;
	var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	select.length = 0;
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    var registryObject = responseArray[i].split("*");
	    select[i].value = registryObject[0];
	    if (typeof(registryObject[1]) != "undefined"){
		select[i].text = registryObject[1];
	    }
	    else{
		select[i].text = registryObject[0];
		select[i].value = null;
	    }
	}
	if(responseArray.length > 1){
	    Effects.showElement('alleleSelect');
	}
	else{
	    Effects.hideElement('alleleSelect');
	}
    },

    associateAllele: function(sp_person_id, allele_id) {
	// locus page does not call this function with an allele_id
	// allele page calls the function with the page object_id 
	if (!allele_id) {  allele_id = $('allele_select').value; } 
	var stock_id = $('stock_select').value;

	new Ajax.Request("/phenome/associate_allele.pl", { //move to controller
		parameters: {allele_id: allele_id, stock_id: stock_id, sp_person_id: sp_person_id}, 
		    onSuccess: function(response) {
                    var json = response.responseText;
                    MochiKit.Logging.log("associateAllele response:  " , json);
                    var x = eval ("("+json+")");
                    MochiKit.Logging.log("associateAllele response:  " , json);
                    if (x.error) { alert(x.error); }
                    else { Tools.reloadPage(); }
		},
		    });
    },

    //Make an ajax request to find all the stocks with a name like the current value of of the accession name input box
    getStocks: function(str, locus_id) {
	var type = 'browse';
	if(str.length==0){
	    var select = $('stock_select');
	    select.length=0;
	    $('associate_stock_button').disabled = true;
	}
        else{
            new Ajax.Request("/phenome/individual_browser.pl", { //move to controller
                    parameters: {stock_name: str,  type: type}, 
                    onSuccess: this.updateStockSelect});
	}
    },

    //Make an ajax request to find all the stock with a name like the current value of of the accession name input box

    
    //Parse the ajax response to update the individuals select box
    updateStockSelect: function(request) {
        var select = $('stock_select');
	$('associate_stock_button').disabled = true;
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//last element of array is empty. dont want this in select box
	responseArray.pop();
        select.length = 0;
        select.length = responseArray.length;
        for (i=0; i < responseArray.length; i++) {
	    var individualObject = responseArray[i].split("*");
	    select[i].value = individualObject[0];
	    if (typeof(individualObject[1]) != "undefined"){
		select[i].text = individualObject[1];
	    }
	    else{
		select[i].text = individualObject[0];
		select[i].value = null;
	    }
	}
    },

    //Make an ajax response that finds all loci  with names/synonyms/symbols like the current value of the locus input
    getMergeLocus: function(str, object_id) {
	if(str.length == 0){
	    var select = $('locus_merge');
	    select.length=0;
	    $('associate_locus_button').disabled = true;
	}else{
	    var type = 'browse locus';
	    var organism = $('common_name').value;
	    new Ajax.Request("/phenome/locus_browser.pl", {parameters: 
		    {type: type, locus_name: str,object_id: object_id, organism: organism}, onSuccess: this.updateLocusSelect });		}
    },

    //Parse the ajax response and update the locus select box accordingly
    updateLocusSelect: function(request) {
	var select = $('locus_list');
	$('merge_locus_button').disabled = true;

	var responseText = request.responseText;
	var responseArray = responseText.split("|");

	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();

	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    var locusObject = responseArray[i].split("*");

	    select[i].value = locusObject[0];
	    if (typeof(locusObject[1]) != "undefined"){
		select[i].text = locusObject[1];
	    }
	}
    },

    //Logic on when to enable the merge locus button
    enableMergeButton: function() {
	$("merge_locus_button").disabled=false;
    },

    //make an ajax response to merge locus x with the current locus
    mergeLocus: function(locus_id) {
	var merged_locus_id = $('locus_list').value;
	new Ajax.Request('/phenome/merge_locus.pl', {
		parameters: { merged_locus_id: merged_locus_id, locus_id: locus_id}, 
		    onSuccess: function(response) {
		    var json  = response.responseText;
		    var x = eval ("("+json+")"); 
		    MochiKit.Logging.log("mergeLocus response:  " , json);
		    if (x.error) { alert(x.error); }
		    else {  window.location.reload() ; } 
		},
		    });
    },

    makeVisible: function(elem) {
        MochiKit.DOM.removeElementClass(elem, "invisible");
	MochiKit.DOM.addElementClass(elem, "visible");

    },

    makeInvisible: function(elem) {
	MochiKit.DOM.removeElementClass(elem, "visible");
        MochiKit.DOM.addElementClass(elem, "invisible");
    },

    searchCvterms: function()  {
	Effects.showElement('ontology_search');
	Effects.hideElement('cvterm_list');
	this.makeVisible('ontology_search');
	this.makeInvisible('cvterm_list');
    },

    getCvtermsList: function(locus_id) {
	Effects.showElement('cvterm_list');
	Effects.hideElement('ontology_search');
	this.makeInvisible('ontology_search');
	this.makeVisible('cvterm_list');

	new Ajax.Request("/phenome/locus_page/get_locus_cvterms.pl", {
		parameters: {locus_id: locus_id }, 
		    onSuccess: function(response) {
		    var json = response.responseText;
		    var x = eval ("("+json+")"); 
		    MochiKit.Logging.log("getCvtermsList response:  " , json);
		    if (x.error) { alert(x.error); }
		    else { 
			var select = $('cvterm_list_select');
			var keyCount=0;
			//first count the # of hash keys. Need to declare first the length of the select menu 
			for (key in x) keyCount++; 
			select.length = keyCount;

			//now populate the select list from the hash. Need to iterate over the hash keys again...
			var i=0;
			for (dbxref_id in x) {
			    select[i].value = dbxref_id;
			    select[i].text =  x[dbxref_id];
			    i++;
			}
		    }
		}
	});
    },

    //make an ajax response to add a dbxref to the locus
    addLocusDbxref: function(locus_id, dbxref_id) {
	//var dbxref_id = $('dbxref_id').value;
	var type = 'locus';
	var validate = $(dbxref_id).value;
	if (validate) {
	    new Ajax.Request('/phenome/add_dbxref.pl', {parameters:
		    { type: type, object_id: locus_id, dbxref_id: dbxref_id, validate: validate}, onSuccess:Tools.reloadPage} );
	}
    },
    /////////////////////////////////////
    /// locus network
    /////////////////////////////////////
    printLocusNetwork: function(locus_id, div_id) {
        if (!div_id) div_id = 'locus_network';
        jQuery.ajax( { url: "/locus/"+locus_id+"/network/" , dataType: "json",
                       success: function(response) {
                    var json = response;
                    jQuery("#"+div_id).html(response.html);
                    if ( response.error ) { alert(response.error) ; }
                }
            });
    },

    ////////////////////////////////////////////////////////////////////////////////////
    //Make an ajax response that associates the selected locus with this locus
    associateLocus: function(locus_id) {
        var div_id = 'locus_network';
        var locus_info = jQuery('#loci').val();
        var locus_relationship_id = jQuery('#locus_relationship_select').val();
        var locus_reference_id = jQuery('#locus_reference_select').val();
        var locus_evidence_code_id = jQuery('#locus_evidence_code_select').val();
        jQuery.ajax( {
                type: 'POST',
                    url: "/ajax/locus/associate_locus",
                    dataType: "json",
                    /// make asynchronous since it takes long to finish the ajax request
                    /// and we want to refresh the locus_network div only after the request is done
                    async: false,
                    data: 'locus_info='+locus_info+'&locus_relationship_id='+locus_relationship_id+'&locus_evidence_code_id='+locus_evidence_code_id+'&locus_reference_id='+locus_reference_id+'&locus_id='+locus_id ,
                    success: function(response) {
                      var json = response;
                      if ( response.error ) { alert(response.error) ; }
                   },
                    });
        this.printLocusNetwork(locus_id, div_id);
        Effects.hideElement('associateLocusForm');
    },
    ////////////////////////////////////////////////
    obsoleteLocusgroupMember: function(lgm_id, locus_id, obsolete_url)  {
        jQuery.ajax( { url: obsolete_url ,
                       dataType: "json" ,
                       type: 'POST',
                       data: 'lgm_id='+lgm_id+'&locus_id'+locus_id,
                       success: function(response) {
                    if ( response.error ) { alert(response.error) ; }
                }
            });
        this.printLocusNetwork(locus_id);
    },
    ///////////////////////////////////////////////
    ////locus unigenes
    /////////////////////////////////////////////
     printLocusUnigenes: function(locus_id) {
        jQuery.ajax( {
                url: '/locus/'+locus_id+'/unigenes',
                dataType: "json",
                success: function(response) {
                    jQuery("#unigenes").html(response.unigenes);
                    jQuery("#solcyc").html(response.solcyc);
                    if ( response.error ) { alert(response.error) ; }
                },
            } );
    },

    //Make an ajax response that obsoletes the selected unigene-locus association
    obsoleteLocusUnigene: function(locus_unigene_id, locus_id)  {
        jQuery.ajax( { url: '/ajax/locus/obsolete_locus_unigene' ,
                       dataType: "json" ,
                       type: 'POST',
                       data: 'locus_unigene_id='+locus_unigene_id+'&locus_id='+locus_id,
                       success: function(response) {
                    if ( response.error ) { alert(response.error) ; }
                }
            });
        this.printLocusUnigenes(locus_id);
    },
  //Make an ajax response that associates the selected unigene  with this locus
    associateUnigene: function(locus_id) {
	var unigene_input = $('unigene_input').value; // get this from autocomplete?
        jQuery.ajax( {
                type: 'POST',
                    url: "/locus/"+locus_id+"/associate_unigene",
                    dataType: "json",
                    /// make asynchronous since it takes long to finish the ajax request
                    /// and we want to refresh the locus_unigenes div only after the request is done
                    async: false,
                    data: 'locus_id='+locus_id+'&unigene_input='+unigene_input ,
                    success: function(response) {
                    if ( response.error ) { alert(response.error) ; }
                },
                    });
        this.printLocusUnigenes(locus_id);
        Effects.hideElement('associateUnigeneForm');
    },

    //Make an ajax response that finds all the unigenes with unigene ids 
    //like the current value of the unigene id input
    getUnigenes: function(unigene_id, organism, current) {
	if(unigene_id.length==0){
            $('associate_unigene_button').disabled = true;
        } else {
            jQuery(function() {
                    jQuery("#unigene_input").autocomplete({
                            source: '/ajax/transcript/autocomplete' + "?organism="+organism+"&current="+current,
                            change: $('associate_unigene_button').disabled = false
                        });
                });
        }
    },

    displayMembers: function (div, locusgroup_id) {
        jQuery.ajax( { url: "/genefamily/manual/" + locusgroup_id + "/members",
                       dataType: "json",
                       success: function(response) {
                            jQuery("#"+div).html(response.html);
                       }
            } );
    },

};//
