
/** 
* @class LocusPage
* Functions used by the locus page
* @author Naama Menda <nm249@cornell.edu>
*
*This javascript object deals with dynamic printing and updating 
*of sections in the locus page (locus_display.pl)
*More js functions that are used from the locus page are currently in Locus.js
*Ideally all js code for the locus page should move here.  
*
*LocusPage.js object is instanciated from CXGN::Phenome::Locus::LocusPage
*/



JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Async');

JSAN.use('CXGN.Phenome.Tools');
JSAN.use('Prototype');

if (!CXGN) CXGN = function() {};
if (!CXGN.Phenome) CXGN.Phenome = function() {};
if (!CXGN.Phenome.Locus) CXGN.Phenome.Locus = function() {};

CXGN.Phenome.Locus.LocusPage = function() { 
    //alert('In constructor');
   
};


CXGN.Phenome.Locus.LocusPage.prototype = { 

   
    render: function() { 

	this.printLocusUnigenes(this.getLocusId());
    },


    //////////////////////////////////////////////
    /////////////////////////////////////////////////
    /////////////////////////////////////////////////////


   
    //////////////////////////
    //Locus unigenes section
    ///////////////////////////
    
    printLocusUnigenes: function(locus_id) {	
	if (!locus_id) locus_id = this.getLocusId();
	var type = "unigenes";
	new Ajax.Request("/phenome/locus_page/print_locus_page.pl", {
                method: "get",
		parameters: { type: type, locus_id: locus_id},
		    onSuccess: this.processLocusUnigenesResponse
		    });
    },

     processLocusUnigenesResponse: function (request) { 
	var json = request.responseText;
	var x =eval ("("+json+")");
	var e = $("locus_unigenes").innerHTML=x.response;
	var s = $("solcyc_links").innerHTML=x.solcyc;
	if ( x.error() ) { alert(x.error) ; }
    },
    

      //Make an ajax response that associates the selected unigene  with this locus
    associateUnigene: function(locus_id, sp_person_id) {
	if (!locus_id)  locus_id = this.getLocusId(); 
      	var type = 'associate';
	var unigene_id = $('unigene_select').value;
	
	new Ajax.Request('unigene_browser.pl', { parameters:
	{type: type, locus_id: locus_id, unigene_id: unigene_id, sp_person_id: sp_person_id}, 
	    onSuccess: function(response) {
	    var json = response.responseText;
	    MochiKit.Logging.log("associateUnigene works! ", json);
	    var x = eval ("("+json+")");
	    MochiKit.Logging.log("associateUnigene: " , json);
	    if (x.error) { alert(x.error); }
	    else { 
		//alert('about to reprint locus unigenes... ');
		Tools.toggleContent('associateUnigeneForm', 'unigenes');
		locusPage.printLocusUnigenes(locus_id);
	    }
	},
	    });
    },
    
    ////////////////////////////////////////////////
    //Make an ajax response that obsoletes the selected unigene-locus association
    obsoleteLocusUnigene: function(locus_unigene_id)  {
	var type= 'obsolete';
	new Ajax.Request('unigene_browser.pl', {
		parameters: {type: type, locus_unigene_id: locus_unigene_id},
		    onSuccess: function(response) {
		    var json = response.responseText;
		    var x = eval ("("+json+")");
		    MochiKit.Logging.log("obsoleteLocusUnigene response:  " , json);
		    if (x.error) { alert(x.error); }
		    else { locusPage.printLocusUnigenes(); }
		},
		    });
    },
    
    //Make an ajax response that finds all the unigenes with unigene ids like the current value of the unigene id input
    getUnigenes: function(unigene_id, locus_id) {
	if(unigene_id.length==0){
	    var select = $('unigene_select');
	    select.length=0;	
	    $('associate_unigene_button').disabled = true;
	} else {	
	    var type = 'browse';
	    new Ajax.Request('unigene_browser.pl', { parameters:
		    {type: type, locus_id: locus_id, unigene_id: unigene_id}, 
			onSuccess: this.updateUnigeneSelect }); 
	}
    },
    
    //Parse the ajax response and update the unigene  select box accordingly
    updateUnigeneSelect: function(response) {
	var select = $('unigene_select');
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
    
    printSolcycLinks: function(locus_id) {	
	
	if (!locus_id) locus_id = this.getLocusId();
	this.printLocusUnigenes;
	//var type = "solcyc";
	//new Ajax.Request("/phenome/locus_page/print_locus_page.pl", {
	//parameters: { type: type, locus_id: locus_id},
	//    onSuccess: this.processLocusUnigenesResponse
	//    });
    },
    /////////////////////////////////////////////
    
    setLocusId: function(locus_id) { 
	this.locus_id = locus_id;
    },
    
    getLocusId: function() { 
	return this.locus_id;
    },
    
};


