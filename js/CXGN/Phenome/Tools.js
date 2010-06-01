/** 
* @class Tools
* Function used in phenome pages
* @author Naama Menda <nm249@cornell.edu>
*
*/

JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Async');

JSAN.use('CXGN.Effects');
JSAN.use('CXGN.Phenome.Locus');


var Tools = {
    
    //Find the selected sgn users from the locus select box and call and AJAX request to find the corresponding user type
    getUsers: function(user_info) {
	if (user_info.length==0) {
	    var select = MochiKit.DOM.getElement('user_select');
	    MochiKit.DOM.getElement('associate_button').disabled = true;
	}
	else {
	    var d = new MochiKit.Async.doSimpleXMLHttpRequest("assign_owner.pl", {user_info: user_info});
	    d.addCallbacks(this.updateUserSelect);
	}
    },
    
    updateUserTypeSelect: function() {
	
    },
    
    //
    updateUserSelect: function(request) {
	
	var select = MochiKit.DOM.getElement('user_select');
	
	//disable the button until an option is selected
	MochiKit.DOM.getElement('associate_button').disabled=true;
	var responseText = request.responseText;
	var responseArray = responseText.split("|");
	
	//last element of array is empty. dont want this in select box
	responseArray.pop();
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    var userObject = responseArray[i].split("*");
	    
	    if (typeof(userObject[1]) != "undefined"){
		select[i].value = userObject[0];
		select[i].text = userObject[1];
	    }
	}
    },
    
     //Logic on when to enable a  button
    enableButton: function(my_button) {
	$(my_button).disabled=false;	    
    },
    //Logic on when to disable a  button
    disableButton: function(my_button) {
	$(my_button).disabled=true;	    
    },
    
    assignOwner: function(object_id, object_type) {
	var sp_person_id = MochiKit.DOM.getElement('user_select').value;
	var d = new MochiKit.Async.doSimpleXMLHttpRequest("assign_owner.pl", {sp_person_id: sp_person_id, object_id: object_id, object_type: object_type});
	d.addCallbacks(this.reloadPage);
    },
    
    
    toggleAssignFormDisplay: function()    {	
	MochiKit.Visual.toggle('assignOwnerForm', 'blind');
    },
    toggleMergeFormDisplay: function()    {	
	MochiKit.Visual.toggle('mergeLocusForm', 'blind');
    },
    toggleDisplay: function(form)    {	
	MochiKit.Visual.toggle(form, 'blind');
    },
    reloadPage: function() {
	window.location.reload();
    },
    
    getOrganisms: function() {
	var type = 'organism';
	new Ajax.Request("locus_browser.pl", {parameters: 
		{type: type}, onSuccess: this.updateOrganismSelect });
    },
    
    updateOrganismSelect: function(request) {
	var select = $('organism_select');
	var responseText = request.responseText;
        MochiKit.Logging.log("the response text is: " , responseText);
	var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	select.length = 0;    
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    select[i].value = responseArray[i];
	    select[i].text = responseArray[i];
	}
    },
    //Make an ajax response that finds all loci  with names/synonyms/symbols like the current value of the locus input
    getLoci: function(locus_name, object_id) {
	MochiKit.Logging.log("getLoci is getting locus_name input ...", locus_name);
	if(locus_name.length == 0){
	    var select = MochiKit.DOM.getElement('locus_select');
	    select.length=0;
	    $('associate_locus_button').disabled = true;
	}else{
	    var type = 'browse locus';
	    var organism = $('organism_select').value;
	   
	    MochiKit.Logging.log("getLoci is updating locus select...", locus_name);
	    new Ajax.Request("locus_browser.pl", {parameters: 
    {type: type, locus_name: locus_name,object_id: object_id, organism: organism}, onSuccess: this.updateLocusSelect });		}
    },
    
    //Parse the ajax response and update the locus select box accordingly
    updateLocusSelect: function(request) {
	var select = $('locus_select');
	$('associate_locus_button').disabled = true;
	
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
    
    toggleAssociateOntology: function()
    {	
	MochiKit.Visual.toggle('associateOntologyForm', 'blind');
    },
    
    
    //Make an ajax response that finds all the ontology terms with names/definitions/synonyms/accessions like the current value of the ontology input
    getOntologies: function(str) {
	if(str.length<4){
	    var select = $('ontology_select').value;
            select.length=0;
	    if ($('associate_ontology_button'))   $('associate_ontology_button').disabled = true;
	}
	
        else{
	    var db_name = $('cv_select').value;
	    new Ajax.Request("/phenome/ontology_browser.pl", {parameters:
    {term_name: str, db_name: db_name}, onSuccess: this.updateOntologySelect});
	}
    },
    
    
    //Parse the ajax response and update the ontology select box accordingly
    updateOntologySelect: function(request) {
        var select = $('ontology_select');
	if  ($('associate_ontology_button')) $('associate_ontology_button').disabled = true;
	
        var responseText = request.responseText;
	var responseArray = responseText.split("|");
	
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();

        select.length = responseArray.length;
        for (i=0; i < responseArray.length; i++) {
	    var ontologyObject = responseArray[i].split("*");
	    
	    select[i].value = ontologyObject[0];
	    if (typeof(ontologyObject[1]) != "undefined"){
		select[i].text = ontologyObject[1];
	    }
	    else{
 		select[i].text = ontologyObject[0];
 		select[i].value = null;
	    }
	}
    },
    
    
    //Make an ajax request for finding the available relationship types
    getRelationship: function() {
	var type = 'relationship'; 
	var relationship_id = $('relationship_select').value;
	new Ajax.Request('evidence_browser.pl', {parameters:
    {type: type}, onSuccess:this.updateRelationshipSelect});
    },
    
    updateRelationshipSelect: function(request) {
	var select = $('relationship_select');
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	responseArray.unshift("*--please select an evidence code--");

	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
        select.length = 0;    
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++)
	{
	    var relationshipObject = responseArray[i].split("*");
	    
	    select[i].value = relationshipObject[0];
	    if (typeof(relationshipObject[1]) != "undefined"){
		select[i].text = relationshipObject[1];
	    }
	    else{
		select[i].text = relationshipObject[0];
		select[i].value = null;
	    }
	}
    },
    
    getEvidenceCode: function() {
    	
	var type = 'evidence_code';
	var evidence_code_id = $('evidence_code_select').value;
	new Ajax.Request('evidence_browser.pl', {parameters: 
    {type: type}, onSuccess:this.updateEvidenceCodeSelect});
    },
    
    updateEvidenceCodeSelect: function(request) {
	var select = $('evidence_code_select');
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	responseArray.unshift("*--please select an evidence code--");
        select.length = 0;    
	select.length = responseArray.length;
	
	for (i=0; i < responseArray.length; i++) {
	    var evidenceCodeObject = responseArray[i].split("*");
	    
	    select[i].value = evidenceCodeObject[0];
	   select[i].text = evidenceCodeObject[1];
	   
	   //document.evidence_code_select.options[i] = new Option(evidenceCodeObject[0], evidenceCodeObject[1]);
	}
    },
    
    
    getEvidenceDescription: function() {
	$('associate_ontology_button').disabled = false;
	var type = 'evidence_description';
	var evidence_code_id = $('evidence_code_select').value;
	var evidence_description_id = $('evidence_description_select').value;
	new Ajax.Request('evidence_browser.pl', {parameters:
    {type: type, evidence_code_id: evidence_code_id}, onSuccess:this.updateEvidenceDescriptionSelect});
    },
    
    updateEvidenceDescriptionSelect: function(request) {
	var select = $('evidence_description_select');
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//the last element of the array is empty. Dont want this in the select box
	responseArray.pop();
	responseArray.unshift("*--Optional: select an evidence description--");
        select.length = 0;    
	select.length = responseArray.length;
	for (i=0; i < responseArray.length; i++) {
	    var evidenceDescriptionObject = responseArray[i].split("*");
	    select[i].value = evidenceDescriptionObject[0];
	    select[i].text = evidenceDescriptionObject[1];
	}
    },
    
    //Make an ajax response that obsoletes the selected ontology term-locus association
    obsoleteAnnot: function(type, type_dbxref_id)  {
	var action= 'obsolete';
	new Ajax.Request('obsolete_object_dbxref.pl', {parameters:
    {object_dbxref_id: type_dbxref_id, type: type, action: action}, onSuccess:Tools.reloadPage});
    },
    //Make an ajax response that unobsoletes the selected ontology term-locus association
    unobsoleteAnnot: function(type, type_dbxref_id)  {
	var action = 'unobsolete';	
	new Ajax.Request('/phenome/obsolete_object_dbxref.pl', {parameters:
	{object_dbxref_id: type_dbxref_id, type: type, action: action}, onSuccess:Tools.reloadPage});
    },

   
    ////////////////////
    //move these to LocusPage and to IndividualPage ... ///////////
    /////////////////////////////////
    //Make an ajax response that obsoletes the selected ontology_term_evidence-locus association
    obsoleteAnnotEv: function(type, object_ev_id)  {
	var action= 'obsolete';
	new Ajax.Request('obsolete_object_ev.pl', {parameters:
    {object_ev_id: object_ev_id, type: type, action: action}, onSuccess:Tools.reloadPage});
    },
    //Make an ajax response that unobsoletes the selected ontology term-locus association
    unobsoleteAnnotEv: function(type, object_ev_id)  {
	var action = 'unobsolete';	
	new Ajax.Request('/phenome/obsolete_object_ev.pl', {parameters:
	{object_ev_id: object_ev_id, type: type, action: action}, onSuccess:Tools.reloadPage});
    },

    //toggle function. For toggling a collapsed section + a hidden ajax form.
    //This function will display correctly the form and the span contents. e.g. locus_display.pl->associate_accession 
    toggleContent: function(form,span,style) {
	
	if (!style) { style = 'inline'; }
	var content= span + "_content";
	var onswitch= span + "_onswitch";
	var offswitch= span + "_offswitch";
	
	var form_disp=$(form).style.display;
	var content_disp= $(content).style.display; 
	
	MochiKit.Logging.log('content display =', content_disp);    
	//MochiKit.Logging.log('form display=' , form_disp);
	Effects.showElement(content);
	Effects.swapElements(onswitch,offswitch);
	if (form_disp == 'none') {  //form is hidden, display both elements and change button to '-'
	    Effects.showElement(form);
	}else if (content_disp != 'none' ){  // form is visible. If content is hidden, open the span, but keep form open
	    Effects.hideElement(form);
	}
    },

}

