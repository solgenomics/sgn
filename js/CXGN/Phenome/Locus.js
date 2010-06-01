/** 
* @class Locus
* Function used in locus_display.pl
* @author Naama Menda <nm249@cornell.edu>
*
*/

JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Async');

JSAN.use('CXGN.Effects');
JSAN.use('CXGN.Phenome.Tools');


var Locus = {
    //update the registry input box when an option is selected. Not sure if we should do this or not
    updateRegistryInput:  function() {
	var select_box = MochiKit.DOM.getElement('registry_select');
	for (i=0; i < select_box.length; i++){
	    if(select_box.options[i].selected) {
		MochiKit.DOM.getElement('associate_registry_button').disabled = false;
	    }
	}
    },
    
    //Make an ajax response that finds all the registries with names or symbols like the current value of the registry input
    getRegistries: function(str)  {
	if(str.length==0){
	    var select = MochiKit.DOM.getElement('registry_select');
	    select.length=0;
	    MochiKit.DOM.getElement('associate_registry_button').disabled = true;
	} else{
	    var d = new MochiKit.Async.doSimpleXMLHttpRequest("registry_browser.pl", {registry_name: str});
	    d.addCallbacks(this.updateRegistrySelect);
	}	
    },
    
    //Parse the ajax response and update the registry select box accordingly
    updateRegistrySelect: function(request) {
	var select =  MochiKit.DOM.getElement('registry_select');
	MochiKit.DOM.getElement('associate_registry_button').disabled = true;
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
    
    //Make an ajax response that associates the selected registry with this locus
    associateRegistry: function(locus_id, sp_person_id) {
	var registry_id =  MochiKit.DOM.getElement('registry_select').value;
	var d = new MochiKit.Async.doSimpleXMLHttpRequest("associate_registry.pl", {registry_id: registry_id, locus_id: locus_id, sp_person_id: sp_person_id});
	d.addCallbacks(Tools.reloadPage);
    },
    
    
    //Make an ajax response that adds a registry to the database and associates it with this locus
    addRegistry: function(locus_id, sp_person_id) {
	var registry_name = MochiKit.DOM.getElement('registry_name').value;
	var registry_symbol = MochiKit.DOM.getElement('registry_symbol').value;
	var registry_description = MochiKit.DOM.getElement('registry_description').value;
	
	if(registry_symbol == ""){
	    MochiKit.DOM.getElement("add_registry_button").disabled=false;	    
	    alert("You must enter a symbol for the new registry");
	    return false;
	}else if(registry_name == ""){
	    MochiKit.DOM.getElement("add_registry_button").disabled=false;
	    alert("You must enter a name for the new registry");
	    return false;
	}
	var d = new MochiKit.Async.doSimpleXMLHttpRequest("add_registry.pl", {registry_symbol: registry_symbol, registry_name: registry_name, registry_description: registry_description, sp_person_id: sp_person_id, locus_id: locus_id});
	d.addCallbacks(this.registry_exists);
    },
    
    //create an alert if the ajax request for adding a registry finds that the registry already exists
    registry_exists: function(request) {
	if(request.responseText == "already exists"){
	    alert('That registry already exists');
	} else{
	    this.associateRegistry();
	}
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
    enableButton: function() {
	var registry_name = MochiKit.DOM.getElement('registry_name').value;
	var registry_symbol = MochiKit.DOM.getElement('registry_symbol').value;
	if(registry_symbol != "" && registry_name != ""){
	    MochiKit.DOM.getElement("add_registry_button").disabled=false;	    
	} 
	else{
	    MochiKit.DOM.getElement("add_registry_button").disabled=true;
	}
    },
    
    //Make an ajax request that finds all the alleles related to the currently selected individual
    getAlleles: function(locus_id) {
	MochiKit.DOM.getElement("associate_individual_button").disabled=false;
	var individual_id = MochiKit.DOM.getElement('individual_select').value;
	var d = new MochiKit.Async.doSimpleXMLHttpRequest("allele_browser.pl", {locus_id: locus_id, individual_id: individual_id});
	d.addCallbacks(this.updateAlleleSelect);
    },
    
    //Parse the ajax response to update the allele select box
    updateAlleleSelect: function(request) {
	var select = MochiKit.DOM.getElement('allele_select');
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
	var individual_id = $('individual_select').value;
	
	new Ajax.Request("associate_allele.pl", {
		parameters: {allele_id: allele_id, individual_id: individual_id, sp_person_id: sp_person_id}, 
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
    
    
    //Make an ajax request to find all the individuals with a name like the current value of of the accession name input box
    getIndividuals: function(str, locus_id) {
	var type = 'browse';
	if(str.length==0){
	    var select = MochiKit.DOM.getElement('individual_select');
	    select.length=0;
	    MochiKit.DOM.getElement('associate_individual_button').disabled = true;
	}
        else{
	    var d = new MochiKit.Async.doSimpleXMLHttpRequest("individual_browser.pl", {individual_name: str, locus_id: locus_id, type: type});
	    d.addCallbacks(this.updateIndividualsSelect);
	}
    },
    
 //Make an ajax request to find all the individuals with a name like the current value of of the accession name input box
    getAlleleIndividuals: function(str, allele_id) {
	var type = 'browse_allele';
	if(str.length==0){
	    var select = $('individual_select');
	    select.length=0;
	    $('associate_individual_button').disabled = true;
	}
        else{
	    new Ajax.Request("individual_browser.pl", {parameters: {individual_name: str, allele_id: allele_id, type: type}, onSuccess: this.updateIndividualsSelect});
	}
    },
    
    //Parse the ajax response to update the individuals select box
    updateIndividualsSelect: function(request) {
        var select = MochiKit.DOM.getElement('individual_select');
	MochiKit.DOM.getElement('associate_individual_button').disabled = true;
	
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
    
    

    getEvidenceWith: function(locus_id)  {
	var type = 'evidence_with';
	var evidence_with_id = $('evidence_with_select').value;
	new Ajax.Request('evidence_browser.pl', {parameters:
    {type: type, locus_id: locus_id}, onSuccess:this.updateEvidenceWithSelect});
    },
    
    updateEvidenceWithSelect: function(request) {
	var select = $('evidence_with_select');
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	responseArray.unshift("*--Optional: select an evidence identifier--");

        select.length = 0;    
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    var evidenceWithObject = responseArray[i].split("*");
	    select[i].value = evidenceWithObject[0];
	    select[i].text = evidenceWithObject[1];
	}
    },
    
    
    getReference: function(locus_id) {
	
	var type = 'reference';
	var reference_id = $('reference_select').value;
	new Ajax.Request('evidence_browser.pl', { parameters:
    {type: type, locus_id: locus_id}, onSuccess: this.updateReferenceSelect });
	MochiKit.Logging.log("Locus.js getReference is calling UpdateReferenceSelect with locus_id", locus_id);
    },
    
    updateReferenceSelect: function(request) {
	var select = $('reference_select');
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	responseArray.unshift("*--Optional: select supporting reference --");
	
        select.length = 0;    
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    var referenceObject = responseArray[i].split("*");
	    select[i].value = referenceObject[0];
	    select[i].text = referenceObject[1];
	}
    },
    /////////////////////////
    //MOVED TO LocusPage!!!!!!!!!!!!!!!!!!
    ////////////////////////////////////////////

    //Make an ajax response that associates the selected ontology term with this locus
    associateOntology: function(locus_id, sp_person_id) {
	if (this.isVisible('cvterm_list')) {
		var dbxref_id = $('cvterm_list_select').value;
		MochiKit.Logging.log("Locus.js: cvterm_list_select.dbxfref_id=...", dbxref_id);
	} else { 
		var dbxref_id = $('ontology_select').value;
		MochiKit.Logging.log("Locus.js: ontology_select.dbxfref_id=...", dbxref_id);
	}
	var type = 'locus';
	var relationship_id = $('relationship_select').value;
	var evidence_code_id = $('evidence_code_select').value;
	var evidence_description_id = $('evidence_description_select').value;
	var evidence_with_id = $('evidence_with_select').value;
	var reference_id = $('reference_select').value;
	
	new Ajax.Request('associate_ontology_term.pl', { parameters:
	{type: type, object_id: locus_id, dbxref_id: dbxref_id, sp_person_id: sp_person_id,  relationship_id: relationship_id, evidence_code_id: evidence_code_id, evidence_description_id: evidence_description_id, evidence_with_id: evidence_with_id, reference_id: reference_id}, onSuccess: this.ontologyResponse });
	
    },
    
    ontologyResponse: function(response) {
	var responseText = response.responseText;
	if (responseText) { alert(responseText); }	
	else { 
		MochiKit.Logging.log("about to reload page...", response );
		window.location.reload();
	}
    },
   
    //
    
    
    //##########
    toggleAssociateRegistry: function()
    {	
	MochiKit.Visual.toggle('associateRegistryForm', 'blind');
    },

    
    //#####################################LOCUS RELATIONSHIPS
	
    getLocusReference: function(locus_id) {

	var type = 'reference';
	var reference_id = $('locus_reference_select').value;
	new Ajax.Request('evidence_browser.pl', { parameters:
	{type: type, locus_id: locus_id}, onSuccess: this.updateLocusReferenceSelect });
	 MochiKit.Logging.log("Locus.js getLocusReference is calling UpdateReferenceSelect with locus_id", locus_id);
    },
    
    updateLocusReferenceSelect: function(request) {
	var select = $('locus_reference_select');
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	responseArray.unshift("*--Optional: select supporting reference --");
	
        select.length = 0;    
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    var referenceObject = responseArray[i].split("*");
	    select[i].value = referenceObject[0];
	    select[i].text = referenceObject[1];
	}
    },

    getLocusRelationship: function() {
	//MochiKit.DOM.getElement("associate_locus_button").disabled=false;
	var type = 'locus_relationship'; 
	var locus_relationship_id = MochiKit.DOM.getElement('locus_relationship_select').value;
	var d = new MochiKit.Async.doSimpleXMLHttpRequest("locus_browser.pl", {type: type} );	
	d.addCallbacks(this.updateLocusRelationshipSelect);
    },

    updateLocusRelationshipSelect: function(request) {
	var select = MochiKit.DOM.getElement('locus_relationship_select');
		
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
        select.length = 0;    
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++)
	{
	    var locusRelationshipObject = responseArray[i].split("*");
	    
	    select[i].value = locusRelationshipObject[0];
	    if (typeof(locusRelationshipObject[1]) != "undefined"){
		select[i].text = locusRelationshipObject[1];
	    }
	    else{
		select[i].text = locusRelationshipObject[0];
		select[i].value = null;
	    }
	}
    },
    
    getLocusEvidenceCode: function() {
    	//MochiKit.DOM.getElement("associate_locus_button").disabled=false;
	var type = 'locus_evidence_code';
	var locus_evidence_code_id = MochiKit.DOM.getElement('locus_evidence_code_select').value;
	var d = new MochiKit.Async.doSimpleXMLHttpRequest("locus_browser.pl", {type: type}  );	
	d.addCallbacks(this.updateLocusEvidenceCodeSelect);
    },
    
    updateLocusEvidenceCodeSelect: function(request) {
	var select = MochiKit.DOM.getElement('locus_evidence_code_select');
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	responseArray.unshift("*--please select an evidence code--");
        select.length = 0;    
	select.length = responseArray.length;
	
	for (i=0; i < responseArray.length; i++) {
	    var locusevidenceCodeObject = responseArray[i].split("*");
	    
	   select[i].value = locusevidenceCodeObject[0];
	   select[i].text = locusevidenceCodeObject[1];
	   
	   //document.evidence_code_select.options[i] = new Option(evidenceCodeObject[0], evidenceCodeObject[1]);
	}
    },
    
     
       
    //#####################################
    
    
    //Make an ajax response that finds all the unigenes with unigene ids like the current value of the unigene id input
    getUnigenes: function(unigene_id, locus_id) {
	if(unigene_id.length==0){
	    var select = MochiKit.DOM.getElement('unigene_select');
	    select.length=0;	
	    MochiKit.DOM.getElement('associate_unigene_button').disabled = true;
	} else {	
	    var type = 'browse';
	    new Ajax.Request('unigene_browser.pl', { parameters:
		    {type: type, locus_id: locus_id, unigene_id: unigene_id}, 
			onSuccess: this.updateUnigeneSelect }); 
	}
    },
    
    //Parse the ajax response and update the unigene  select box accordingly
    updateUnigeneSelect: function(response) {
	var select = MochiKit.DOM.getElement('unigene_select');
	//MochiKit.DOM.getElement('associate_unigene_button').disabled = true;
	var json  = response.responseText;
	var x = eval ("("+json+")"); 
	//var responseText = request.responseText;
	var responseArray = x.response.split("|");
	
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();

        select.length = responseArray.length;
        for (i=0; i < responseArray.length; i++) {
	    var unigeneObject = responseArray[i].split("*");
	    
	    select[i].value = unigeneObject[0];
	    if (typeof(unigeneObject[1]) != "undefined"){
		select[i].text = unigeneObject[1];
	    }
	}
     },

   
	//Make an ajax response that obsoletes the selected individual-allele association
    	obsoleteIndividualAllele: function(individual_allele_id)  {
		var type= 'obsolete';
		new Ajax.Request('individual_browser.pl', {parameters: 
		{type: type, individual_allele_id: individual_allele_id}, onSuccess: Tools.reloadPage });		
	},
	//Make an ajax response that finds all loci  with names/synonyms/symbols like the current value of the locus input
    	getMergeLocus: function(str, object_id) {
		if(str.length == 0){
	    		var select = MochiKit.DOM.getElement('locus_merge');
            		select.length=0;
	    		$('associate_locus_button').disabled = true;
		}else{
	    		var type = 'browse locus';
			var organism = $('common_name').value;
			new Ajax.Request("locus_browser.pl", {parameters: 
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
		MochiKit.DOM.getElement("merge_locus_button").disabled=false;	    
    	},

	//make an ajax response to merge locus x with the current locus
	mergeLocus: function(locus_id) {
		var merged_locus_id = MochiKit.DOM.getElement('locus_list').value;
		new Ajax.Request('merge_locus.pl', {
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
	
    toggleVisible:function(elem){
        MochiKit.DOM.toggleElementClass("invisible", elem);
	MochiKit.Logging.log("toggling visible element : " , elem);
    },	

    makeVisible: function(elem) {
        MochiKit.DOM.removeElementClass(elem, "invisible");
	MochiKit.DOM.addElementClass(elem, "visible");

    },

    makeInvisible: function(elem) {
	MochiKit.DOM.removeElementClass(elem, "visible");
        MochiKit.DOM.addElementClass(elem, "invisible");
    },
	
    isVisible: function(elem) {
        // you may also want to check for
        // getElement(elem).style.display == "none"
	MochiKit.Logging.log("testing isVisible", elem);
	if (MochiKit.DOM.hasElementClass(elem, "invisible")) {
		MochiKit.Logging.log("this element is invisible: ", elem);
	}else if  (MochiKit.DOM.hasElementClass(elem, "visible")) { 
	    MochiKit.Logging.log("this element is visible: ", elem); 
	}else {  MochiKit.Logging.log("this element does not have a visible/invisible element set: ", elem); } 
	
	return MochiKit.DOM.hasElementClass(elem, "visible") ;
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
			var select = MochiKit.DOM.getElement('cvterm_list_select');
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
    
}//
    
