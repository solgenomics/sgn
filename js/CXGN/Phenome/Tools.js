/**
* @class Tools
* DEPRECATED - this is used only on the locus page. - move locus specific functions to Locus.js
* Some functions may be made generic for use with other phenome objects, such as stocks.
* The individual page is deprecated, and future pages should use
* CXGN.AJAX.Ontology which is more generic
* Function used in phenome pages
* @author Naama Menda <nm249@cornell.edu>
*
*/

JSAN.use('MochiKit.Visual');

JSAN.use('CXGN.Effects');
JSAN.use('CXGN.Phenome.Locus');
JSAN.use('CXGN.AJAX.Ontology');
JSAN.use('Prototype');

var Tools = {

    //Find the selected sgn users from the locus select box and call and AJAX request to find the corresponding user type
    getUsers: function(user_info) {
	if (user_info.length==0) {
	    var select = $('user_select');
	    $('associate_button').disabled = true;
	}
	else {
            new Ajax.Request("/phenome/assign_owner.pl", {
                    parameters:
                    {user_info: user_info},
                    onSuccess: function(response) {
                        var select = $('user_select');
                        //disable the button until an option is selected
                        $('associate_button').disabled=true;
                        var responseText = response.responseText;
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
                    }, } );
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
	var sp_person_id = $('user_select').value;
	new Ajax.Request("/phenome/assign_owner.pl", {parameters: ///move to /ajax/locus/assign_owner
		{sp_person_id: sp_person_id, object_id: object_id, object_type: object_type},
		    onSuccess: window.location.reload() } );
    },
    ////////////////move to toggleContent ////////////////////////////
    toggleAssignFormDisplay: function()    {
	MochiKit.Visual.toggle('assignOwnerForm', 'blind');
    },
    toggleMergeFormDisplay: function()    {
	MochiKit.Visual.toggle('mergeLocusForm', 'blind');
    },
    ///////////////////////
    reloadPage: function() {
	window.location.reload();
    },

    getOrganisms: function() {
	var type = 'organism';
	new Ajax.Request("/phenome/locus_browser.pl", {parameters: 
		{type: type}, onSuccess: function(response) {
		    var select = $('organism_select');
		    var responseText = response.responseText;
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
				  });
    },
    //Make an ajax response that finds all loci  with names/synonyms/symbols like the current value of the locus input
    getLoci: function(locus_name, object_id) {
	MochiKit.Logging.log("getLoci is getting locus_name input ...", locus_name);
	if(locus_name.length == 0){
	    var select = $('locus_select');
	    select.length=0;
	    $('associate_locus_button').disabled = true;
	}else{
	    var type = 'browse locus';
	    var organism = $('organism_select').value;

	    MochiKit.Logging.log("getLoci is updating locus select...", locus_name);
	    new Ajax.Request("/phenome/locus_browser.pl", {parameters: 
		    {type: type, locus_name: locus_name,object_id: object_id, organism: organism}, 
			onSuccess: function(response) {
			var select = $('locus_select');
			$('associate_locus_button').disabled = true;
			var responseText = response.responseText;
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
			});
	}
    },

    /////////////////////////////////////////////////////////////////////////////////////////
    //DEPRECATED - still used in add_publication.pl!
    //Make an ajax response that obsoletes the selected ontology term-locus association
    obsoleteAnnot: function(type, type_dbxref_id)  {
	var action= 'obsolete';
	new Ajax.Request('/phenome/obsolete_object_dbxref.pl', {parameters:
		{object_dbxref_id: type_dbxref_id, type: type, action: action}, 
		    onSuccess: function(response) {
		    var json  = response.responseText;
		    var x = eval ("("+json+")"); 
		    if (x.error) { alert(x.error); }
		    else {  window.location.reload() ; }
		},
		    onFailure: function(response) {
		    alert("Failed obsoleting annotation for " + type) ;
		    var json = response.responseText;
		    //var x = jQuery.parseJSON( json );
		    var x = eval("("+json+")");
		    //alert (x);
		},
		    });
    },

    //Make an ajax response that unobsoletes the selected ontology term-locus association
    //this is also used in add_publication.pl - need to refactor.
    unobsoleteAnnot: function(type, type_dbxref_id)  {
	var action = 'unobsolete';
	new Ajax.Request('/phenome/obsolete_object_dbxref.pl', {
		method: 'get',
		    parameters:
		{object_dbxref_id: type_dbxref_id, type: type, action: action}, 
		    onSuccess: function(response) {
		    var json  = response.responseText;
		    var x = eval ("("+json+")");
		    if (x.error) { alert(x.error); }
		    else {  window.location.reload() ; }
		},
		    onFailure: function(response) {
		    alert("Failed unobsoleting annotation for " + type) ;
		    var json = response.responseText;
		    //var x = jQuery.parseJSON( json );
		    var x = eval("("+json+")");
		    alert (x);
		},
		    });
    },

    /////////////////////////
    //toggle function. For toggling a collapsed section + a hidden ajax form.
    //This function will display correctly the form and the span contents.
    toggleContent: function(form,span,style) {
	if (!style) { style = 'inline'; }
	var content= span + "_content";
	var onswitch= span + "_onswitch";
	var offswitch= span + "_offswitch";
	var form_disp = $(form).style.display;
	var content_disp = $(content).style.display; 
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

    //Make an ajax response that obsoletes the selected ontology term-locus association
    toggleObsoleteAnnotation: function(obsolete, id, obsolete_url, ontology_url)  {
        new Ajax.Request(obsolete_url, {
                method: 'post',
                    parameters:
		{id: id , obsolete: obsolete },
                    onSuccess: function(response) {
		    var json = response.responseText;
		    var x =eval ("("+json+")");
                    //var e = $("locus_ontology").innerHTML=x.response;
                    //this should update the locus_ontology div
		    if ( x.error ) { alert(x.error) ; }
                }
        });
        Ontology.displayOntologies("ontology" , ontology_url);
    },

}

