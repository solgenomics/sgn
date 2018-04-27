/** 
* @class Qtl
* functions for qtl
* @author Isaak Tecle <iyt2@cornell.edu>
*
*/

JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Async');
JSAN.use('CXGN.Effects');
JSAN.use('CXGN.Phenome.Tools');
JSAN.use('jquery.blockUI');



var Qtl = {

    toggleAssociateTaxon: function()
    {	
	MochiKit.Visual.toggle('associateTaxonForm', 'appear');
    },
  
//Make an ajax response that finds all the TAXON with organism ids
    getTaxons: function(str) {
	
	if(str.length==0){
	    var select = MochiKit.DOM.getElement('taxon_select');
	    select.length=0;
	    MochiKit.DOM.getElement('associate_taxon_button').disabled = true;
	}
        else{
	    var type = 'browse';
	    var d = new MochiKit.Async.doSimpleXMLHttpRequest("/phenome/organism_browser.pl", {organism: str, type: type});
	    d.addCallbacks(this.updateTaxonSelect);
	}
    },
 
    updateTaxonSelect: function(request) {
        var select = MochiKit.DOM.getElement('taxon_select');
	MochiKit.DOM.getElement('associate_taxon_button').disabled = false;
	
        var responseText = request.responseText;
        var responseArray = responseText.split("|");
	//last element of array is empty. dont want this in select box
	responseArray.pop();
        select.length = 0;
        select.length = responseArray.length;
        for (i=0; i < responseArray.length; i++) {
	    var taxonObject = responseArray[i].split("*");
	    select[i].value = taxonObject[0];
	    if (typeof(taxonObject[1]) != "undefined"){
		select[i].text = taxonObject[1];
	    }
	    else{
		select[i].text = taxonObject[0];
		select[i].value = null;
	    }
	}
    },
  
   
    //Make an ajax response that associates the selected organism id  with the population
    associateTaxon: function() {
      	var type = 'associate';
	var organism_id = MochiKit.DOM.getElement('taxon_select').value;	

	new Ajax.Request('/phenome/organism_browser.pl', { parameters:
		{type: type, organism_id: organism_id}, onSuccess: Tools.reloadPage} );


    },


    toggleStatOptions: function(id)
    {
        var e = document.getElementById('statTools');       
        var all = e.getElementsByTagName('div');
        
        for ( var i=0;i<all.length;i++ )
            {
                all[i].style.display="none";
                if ( all[i].id == id )
                    {
                        all[i].style.display="block";
                    }
            }
    },
   
    setUserStatOption: function( id, useroption ) 
    {
        new MochiKit.Async.doSimpleXMLHttpRequest ('/qtl/stat/option', 
                                                   { pop_id: id, 
                                                     stat_params: useroption
                                                   }
                                                  );
    },


    logUser: function( userid ) 
    {
	if (userid == null) 
            {
                window.location="/user/login";
            } 
        else 
            {
                Qtl.toggleStatOptions('qtlParameters');
            }
    }, 

    waitPage: function() 
    {
        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Running QTL Analysis...Please wait...'});
            
        if(location.reload()) 
            {
                jQuery.unblockUI();
            }          
    },

     genericWaitPage: function() 
    {
        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait....'});
                       
        if(location.reload()) 
            {
                jQuery.unblockUI();
            }          
    },
            
      
}//

	




