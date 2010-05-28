/** 
* @class Individual
* Function used in individual.pl
* @author Naama Menda <nm249@cornell.edu>
*
*/

JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Async');

JSAN.use('CXGN.Effects');
JSAN.use('CXGN.Phenome.Locus');
JSAN.use('CXGN.Phenome.Tools');

var Individual = {

	//Find the selected locus from the locus select box and call and AJAX request to find the corresponding alleles
	getAlleles: function(str, individual_id) {
	var select_box = MochiKit.DOM.getElement('locus_select');
	for (i=0; i < select_box.length; i++){
		if(select_box.options[i].selected) {
		MochiKit.DOM.getElement('associate_locus_button').disabled=false;
		var d = new MochiKit.Async.doSimpleXMLHttpRequest("allele_browser.pl", {locus_id: str, individual_id: individual_id});
		
		//updating the allele select box should work the same as in the Locus object..
		d.addCallbacks(Locus.updateAlleleSelect);
	    }
	}
    },



    //Parse the results of the AJAX request and fill the locus select box accordingly
    updateLociSelect: function(request) {
        var select = MochiKit.DOM.getElement('locus_select');

	//disable the button until an option is selected
	 MochiKit.DOM.getElement('associate_locus_button').disabled=true;
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");

	//last element of array is empty. dont want this in select box
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

	associateAllele: function(sp_person_id, individual_id) {
		var allele_id = MochiKit.DOM.getElement('allele_select').value;
		//var individual_id = MochiKit.DOM.getElement('locus_select').value;
		var d = new MochiKit.Async.doSimpleXMLHttpRequest("associate_allele.pl", {allele_id: allele_id, individual_id: individual_id, sp_person_id: sp_person_id});
		d.addCallbacks(Tools.reloadPage);
    	},


    toggleAssociateFormDisplay: function()    {	
	MochiKit.Visual.toggle('associationForm', 'blind');
    },
	
	//Get evidence with and reference for onology term annotations.
	//The get and update ontology term, relationship and evidence codes are in Phenome/Tools.js 

	getEvidenceWith: function(individual_id)  {
	var type = 'evidence_with';
	var evidence_with_id = $('evidence_with_select').value;
	new Ajax.Request('evidence_browser.pl', {parameters:
		{type: type, individual_id: individual_id}, onSuccess:this.updateEvidenceWithSelect});
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
    
    
    getReference: function(individual_id) {

	var type = 'reference';
	var reference_id = $('reference_select').value;
	new Ajax.Request('evidence_browser.pl', { parameters:
	{type: type, individual_id: individual_id}, onSuccess: this.updateReferenceSelect });
	 MochiKit.Logging.log("Individual.js getReference is calling UpdateReferenceSelect with individual_id", individual_id);
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
 

	//Make an ajax response that associates the selected ontology term with this individual
  	associateOntology: function(object_id, sp_person_id) {
		var type = 'individual';
		var dbxref_id = $('ontology_select').value;
		
		var relationship_id = $('relationship_select').value;
		var evidence_code_id = $('evidence_code_select').value;
		var evidence_description_id = $('evidence_description_select').value;
		var evidence_with_id = $('evidence_with_select').value;
		var reference_id = $('reference_select').value;
	
		new Ajax.Request('associate_ontology_term.pl', { parameters:
		{type:type, object_id: object_id, dbxref_id: dbxref_id, sp_person_id: sp_person_id,  relationship_id: relationship_id, evidence_code_id: evidence_code_id, evidence_description_id: evidence_description_id, evidence_with_id: evidence_with_id, reference_id: reference_id}, onSuccess: Tools.reloadPage });
	
    },

	
}
    
    
