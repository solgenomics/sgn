/** 
* @class solgs
* general solGS app wide and misc functions
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use('jquery.blockUI');
JSAN.use('jquery.form');


var solGS = solGS || function solGS () {};

solGS.waitPage = function (page, args) {

    var matchItems = 'solgs/population/'
	+ '|solgs/populations/combined/' 
	+ '|solgs/trait/' 
	+ '|solgs/model/combined/trials/'
	+ '|solgs/search/trials/trait/'
	+ '|solgs/model/\\w+_\\d+/prediction/'
	+ '|solgs/model/\\d+/prediction/'
	+ '|solgs/models/combined/trials/'
     	+ '|solgs/analyze/traits/';
  		    
    if (page.match(matchItems)) {

    	askUser(page, args);
    }
    else {

    	blockPage(page, args);
    }
   

    function  askUser(page, args) {
	
	var t = '<p>This analysis may take longer than 20 min. ' 
	    + 'Would you like to be emailed when it is done?</p>';
	
	jQuery('<div />')
	    .html(t)
	    .dialog({	    
		height : 200,
		width  : 400,
		modal  : true,
		title  : "Analysis job submission",
 		buttons: {	
		    Yes: {
			text: 'Yes',
			class: 'btn btn-success',
                        id   : 'queue_job',
			click: function() {
			    jQuery(this).dialog("close");			  
			    
			    checkUserLogin(page, args);
			},
		    }, 
		    
		    No: { 
			text: 'No, I will wait...',
			class: 'btn btn-primary',
                        id   : 'no_queue',
			click: function() { 
			    jQuery(this).dialog("close");
			    
			    displayAnalysisNow(page, args);
			},
		    },
		    
		    Cancel: { 
			text: 'Cancel',
			class: 'btn btn-info',
                        id   : 'cancel_queue_info',
			click: function() { 
			    jQuery(this).dialog("close");
			},
		    },
		}
	    });
	
    }


    function checkUserLogin (page, args) {
	
	if (args === undefined) {	
	    args = {};
	}

	jQuery.ajax({
	    type    : 'POST',
	    dataType: 'json',
	    url     : '/solgs/check/user/login/',
	    success : function(response) {
		if (response.loggedin) {
		    var contact = response.contact;
		    
		    args['user_name']  = contact.name;
		    args['user_email'] = contact.email;

		    getProfileDialog(page, args);

		} else {
		    loginAlert();
		}
	    }
	});

    }


    function loginAlert () {
	
	jQuery('<div />')
	    .html('To use this feature, you need to log in and start over the process.')
	    .dialog({
		height : 200,
		width  : 250,
		modal  : true,
		title  : 'Login',
		buttons: {
		    OK: {
			click: function () {
			    jQuery(this).dialog('close');		
			    loginUser();
			},
			class: 'btn btn-success',
			text : 'OK',
		    },

		    Cancel: {
			click: function () {
			    jQuery(this).dialog('close');		
			},
			class: 'btn btn-primary',
			text : 'Cancel'
		    }
		}			
	    });	    

    }
    

    function loginUser () {

	window.location = '/solpeople/login.pl?goto_url=' + window.location.pathname;
	
    }


    function displayAnalysisNow (page, args) {

	blockPage(page, args);

    }


    function blockPage (page, args) {

	goToPage(page, args);
		
	jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
	jQuery.blockUI({message: 'Please wait..'});
        
	// jQuery(window).unload(function()  {
	//     jQuery.unblockUI();            
	// }); 

    }

    function goToPage (page, args) { 

	var matchItems = 'solgs/confirm/request'
	    + '|solgs/trait/'
	    + '|solgs/model/combined/trials/';
	
	var multiTraitsUrls = 'solgs/analyze/traits/population/'
	    + '|solgs/models/combined/trials/';

	if (page.match(matchItems)) {

	    window.location = page;
	    
	} else if (page.match(multiTraitsUrls)) {


	   // submitTraitSelections(page, args);
		    
	    if (page.match('solgs/analyze/traits/population/')) {
		var popId  = jQuery('#population_id').val();
		var traitIds = args.trait_id;
	
		jQuery.ajax({
		    dataType: 'json',
		    type    : 'POST',
 		    data    : {'trait_id': traitIds, 'source': 'AJAX'},
		    url     : '/solgs/analyze/traits/population/' + popId,
		    success : function (res){
			if (res.status) {
			    window.location = '/solgs/traits/all/population/' + popId;
			} else	{
			    window.location = window.location.href;
			}				
		    }
		});
		
	    } else {
		var comboPopsId = jQuery("#population_id").val();
		var traitIds = args.trait_id;
	
		jQuery.ajax({
		    dataType: 'json',
		    type    : 'POST',
 		    data    : {'trait_id': traitIds, 'source': 'AJAX'},
		    url     : '/solgs/models/combined/trials/' + comboPopsId,
		    success : function (res){			
			if (res.status) {
			    window.location = '/solgs/models/combined/trials/' + comboPopsId;			    
			} else {
			    window.location = window.location.href;
			}				
		    }
		});
		
	    }
	   
	}  else if (page.match(/solgs\/populations\/combined\//)) {
	    retrievePopsData(args.combo_pops_list);  
	} else if (page.match(/solgs\/population\//)) {
	    if (page.match(/solgs\/population\/uploaded_/)) {
		var listId = args.list_id;
		loadPlotListTypeTrainingPop(listId);  
	    } else {
		window.location = page;
	    }	   
	} else if (page.match(/solgs\/model\//)) {	    
	    if (page.match(/solgs\/model\/\d+\/prediction\/\w+_|solgs\/model\/\w+_\d+\/prediction\/\w+_/)) {	
		loadGenotypesListTypeSelectionPop(args);
	    } else {
		window.location = page;
	    }			
	}
	else {
	    window.location = window.location.href;
	}	
    }


    function submitTraitSelections (page, args) {
	
	wrapTraitsForm();

	if (args == 'undefined') {
	    document.getElementById('traits_selection_form').submit(); 
	    document.getElementById('traits_selection_form').reset(); 

	} else {  
	    jQuery('#traits_selection_form').ajaxSubmit();
	    jQuery('#traits_selection_form').resetForm();
	}
    }


    function wrapTraitsForm () {
	
	var popId  = jQuery('#population_id').val();
	var formId = ' id="traits_selection_form"';
	
	var action;   
	var referer = window.location.href;
	
	if ( referer.match(/solgs\/populations\/combined\//) ) {
	    action = ' action="/solgs/models/combined/trials/' + popId + '"';		 		 
	}

	if ( referer.match(/solgs\/population\//) ) {
	    action = ' action="/solgs/analyze/traits/population/' + popId + '"';
	}
	
	var method = ' method="POST"';
	
	var traitsForm = '<form'
	    + formId
	    + action
	    + method
	    + '>' 
	    + '</form>';

	jQuery('#population_traits_list').wrap(traitsForm);

    }


    function getProfileDialog (page, args) {
	
	var matchItems = '/solgs/population/'
	    + '|solgs/trait/' 
	    + '|solgs/model/combined/trials/'
	    + '|solgs/model/\\w+_\\d+/prediction/'
	    + '|solgs/model/\\d+/prediction/';

	if (page.match(matchItems) ) {

	    args = getArgsFromUrl(page, args);
	}
	
	var form = getProfileForm(args);
	
	jQuery('<div />', {id: 'email-form'})
	    .html(form)
	    .dialog({	
		height : 350,
		width  : 400,
		modal  : true,
		title  : 'Info about your analysis.',
 		buttons: {
		    Submit: {
			click: function() { 
			    
			    var userName  = jQuery("#user_name").val();		
			    var userEmail = jQuery("#user_email").val();
			    
			    var analysisName = jQuery('#analysis_name').val();
			    var analysisType = args.analysis_type;
			    
			    var dataSetType = args.data_set_type;
			    
			    args['user_email'] = userEmail;
			    args = JSON.stringify(args);
			    
			    var analysisProfile = {
				'user_name'    : userName, 
				'user_email'   : userEmail,
				'analysis_name': analysisName,
				'analysis_page': page,
				'analysis_type': analysisType,
				'data_set_type': dataSetType,
				'arguments'    : args,
			    };
			    
			    jQuery(this).dialog('close');
			    
			    saveAnalysisProfile(analysisProfile);
			},
			class: 'btn btn-success',
			text: 'Submit'
		    },

		    Cancel:  {
			click: function() {
			    jQuery(this).dialog('close');
			},
			class: 'btn btn-primary',
			text: 'Cancel',
		    }		 
		}
	    });

    }


    function getArgsFromUrl (url, args) {
    
	if (window.Prototype) {
	    delete Array.prototype.toJSON;
	}

	if (url.match(/solgs\/trait\//)) {
	    
	    var urlStr = url.split(/\/+/);
	    
	    if (args === undefined) {
		
		args = {'trait_id'      : [ urlStr[4] ], 
			'training_pop_id' : [ urlStr[6] ], 
			'analysis_type' : 'single model',
			'data_set_type' : 'single population',
		       };
	    }
	    else {

		args['trait_id']      = [ urlStr[4] ];
		args['training_pop_id'] = [ urlStr[6] ];
		args['analysis_type'] = 'single model';
		args['data_set_type'] = 'single population';
		
	    }
	} else if (url.match(/solgs\/model\/combined\/trials\//)) {

	    var urlStr = url.split(/\/+/);

	    var traitId      = [];
	    var populationId = [];
	    var comboPopsId  = [];
	    
	    var referer      = window.location.href;
	    
	    if (referer.match(/solgs\/search\/trials\/trait\//)) {

		populationId.push(urlStr[5]);
		comboPopsId.push(urlStr[5]);
		traitId.push(urlStr[7]);
	    }
	    else if (referer.match(/solgs\/populations\/combined\//)) {

		populationId.push(urlStr[6]);
		comboPopsId.push(urlStr[6]);
		traitId.push(urlStr[8]);   
	    }
	    
	    if (args === undefined) {
		
		args = {'trait_id'      : traitId, 
			'training_pop_id' : populationId, 
			'combo_pops_id' : comboPopsId,
			'analysis_type' : 'single model',
			'data_set_type' : 'combined populations'};
	    } else {

		args['trait_id']      = traitId;
		args['training_pop_id'] = populationId;
		args['combo_pops_id'] = comboPopsId;
		args['analysis_type'] = 'single model';
		args['data_set_type'] = 'combined populations';	
	    }
	} else if (url.match(/solgs\/population\//)) {
	    
	    var urlStr = url.split(/\/+/);
	 
	    if (args === undefined) {
		args = { 
		    'training_pop_id' : [ urlStr[4] ], 
		    'analysis_type' : 'population download',
		    'data_set_type' : 'single population'
		};
	    } else {
		args['training_pop_id'] = [ urlStr[4] ];
		args['analysis_type'] = 'population download';
		args['data_set_type'] = 'single population';	
	    }
	} else if (url.match(/solgs\/model\/\d+\/prediction\/|solgs\/model\/\w+_\d+\/prediction\//)) {

	    var traitId = jQuery('#trait_id').val();
	    var modelId = jQuery('#model_id').val();
	    var urlStr  = url.split(/\/+/);
	   
	    var dataSetType;

	    if (window.location.href.match(/solgs\/model\/combined\/populations\/|solgs\/models\/combined\//)) {
		dataSetType = 'combined populations';
	    } else if (window.location.href.match(/solgs\/trait\/|solgs\/traits\/all\/population\//)) {
		dataSetType = 'single population';
	    }

	    if (args === undefined) {
		
		args = {
		    'trait_id'         : [ traitId ],
		    'training_pop_id'  : [ urlStr[4] ], 
		    'selection_pop_id' : [ urlStr[6] ], 
		    'analysis_type'    : 'selection prediction',
		    'data_set_type'    : dataSetType,
		};
	    }
	    else {
		args['trait_id']         = [ traitId ];
		args['training_pop_id']  = [ urlStr[4] ];
		args['selection_pop_id'] = [ urlStr[6] ];
		args['analysis_type']    = 'selection prediction';
		args['data_set_type']    = dataSetType;	
	    }
	}
 
	return args;

    }


    function getProfileForm (args) {

	var email = '';
	if (args.user_email) {
	    email = args.user_email;
	}
	
	var userName = '';
	if (args.user_name) {
	    userName = args.user_name;
	}
	
	var emailForm = '<p>Please fill in your:</p>'
            + '<div class="form-group">'
	    + '<table class="table">'
	    + '<tr>'
     	    + '<td>Name:</td>'
     	    + '<td><input type="text" class="form-control" name="user_name" id="user_name" value=\"' + userName + '\"/></td>' 
     	    + '</tr>'
	    + '<tr>'
	    + '<td>Analysis name:</td>'
	    + '<td><input  type="text"  class="form-control" name="analysis_name" id="analysis_name"></td>'
	    + '</tr>'
            + '<tr>'
     	    + '<td>Email:</td>'
     	    + '<td><input type="text" class="form-control" name="user_email" id="user_email" value=\"' + email + '\"/></td>' 
     	    + '</tr>'
	    + '</table>'
	    + '<div>';
	
	return emailForm;

    }


    function saveAnalysisProfile (profile) {
	
	jQuery.ajax({
	    type    : 'POST',
	    dataType: 'json',
	    data    : profile,
	    url     : '/solgs/save/analysis/profile/',
	    success : function(response) {
		if (response.result) {
		    runAnalysis(profile);
		    ////confirmRequest();
		    
		} else { 
		    jQuery('<div />', {id: 'error-message'})
			.html('Failed saving your analysis profile.')
			.dialog({
			    height : 200,
			    width  : 250,
			    modal  : true,
			    title  : 'Error message',
			    buttons: {
				OK: function () {
				    jQuery(this).dialog('close');
				    window.location = window.location.href;
				}
			    }			
			});
		}
	    },
	    error: function () {
		jQuery('<div />')
		    .html('Error occured calling the function to save your analysis profile.')
		    .dialog({
			height : 200,
			width  : 250,
			modal  : true,
			title  : 'Error message',
			buttons: {
			    OK: function () {
				jQuery(this).dialog('close');
				window.location = window.location.href;
			    }
			}			
		    });	    
	    }
	});

    }


    function runAnalysis (profile) {
	
	jQuery.ajax({
	    dataType: 'json',
	    type    : 'POST',
 	    data    : profile,
	    url     : '/solgs/run/saved/analysis/',
	    success : function(response) {
		if (response.result.match(/Submitted/)) {
		    confirmRequest();
		} else {
		    jQuery('<div />')
			.html('Error occured submitting the job. Please contact the developers.' + "\n\nHint: " + response.result)
			.dialog({
			    height : 200,
			    width  : 250,
			    modal  : true,
			    title  : 'Error message',
			    buttons: {
				OK: function () {
				    jQuery(this).dialog('close');
				    window.location = window.location.href;
				}
			    }			
			});	     
		}
	    },
	    error: function (response) {
		 jQuery('<div />')
			.html('Error occured submitting the job. Please contact the developers.' + "\n\nHint: " + response.result)
			.dialog({
			    height : 200,
			    width  : 250,
			    modal  : true,
			    title  : 'Error message',
			    buttons: {
				OK: function () {
				    jQuery(this).dialog('close');
				    window.location = window.location.href;
				}
			    }			
			});	     
	    }
	});
	
    }


    function confirmRequest () {
	
	blockPage('/solgs/confirm/request');
	
    }

}


function selectTraitMessage () {
    
    var message = '<p style="text-align:justify;">Please select one or more traits to build prediction models.</p>';

    jQuery('<div />')
	.html(message)
	.dialog({	    
	    height : 200,
	    width  : 400,
	    modal  : true,
	    title  : "Prediction Modeling Message",
 		buttons: {	
		    Yes: {
			text: 'OK',
			class: 'btn btn-success',
                        id   : 'select_trait_message',
			click: function() {
			    jQuery(this).dialog("close");			  
			    
			},
		    }, 
		}
	    });

}


jQuery(document).ready(function (){
 
     jQuery('#runGS').on('click',  function() {
	 if (window.Prototype) {
	     delete Array.prototype.toJSON;
	 }

	 var traitIds = jQuery("#traits_selection_div :checkbox").fieldValue();
	 var popId    = jQuery('#population_id').val(); 

	 if (traitIds.length) {	  
	     var page;
	     var analysisType;
	     var dataSetType;
	 
		 
	     var hostName = window.location.protocol 
		 + '//' 
		 + window.location.host;
	     
	     var referer = window.location.href;
	     
	     if ( referer.match(/solgs\/populations\/combined\//) ) {
		 
		 dataSetType = 'combined populations';		 		 
	     }

	     if ( referer.match(/solgs\/population\//) ) {
		 
		 dataSetType = 'single population';		 		 
	     }
	     
	     if (traitIds.length == 1 ) {	   

		 analysisType = 'single model';
		 
		 if ( referer.match(/solgs\/populations\/combined\//) ) {
		     
		     page = hostName 
			 + '/solgs/model/combined/trials/' 
			 + popId 
			 + '/trait/' 
			 + traitIds[0];		 
		     
		 } else if ( referer.match(/solgs\/population\//)) {
		     
		     page = hostName 
			 + '/solgs/trait/' 
			 + traitIds[0] 
			 + '/population/' 
			 + popId;		 
		 }
			 
	     } else {
		 
		 analysisType = 'multiple models';
		 
		 if ( referer.match(/solgs\/populations\/combined\//) ) {
		     page = hostName 
			 + '/solgs/models/combined/trials/' 
			 + popId;
		     
		 } else {
		     
		     page = hostName 
			 + '/solgs/analyze/traits/population/' 
			 + popId;
		 }	    
	     }
	 
	     var args = {'trait_id'        : traitIds, 
			 'training_pop_id' : [ popId ], 
			 'analysis_type'   : analysisType,
			 'data_set_type'   : dataSetType,
			};

	     solGS.waitPage(page, args);
	 } else {
	     selectTraitMessage();
	 }

     });
    
});


solGS.getTraitDetails = function (traitId) {
  
    if (!traitId) {
	traitId = jQuery("#trait_id").val();
    }
 
    if (traitId) {	
	jQuery.ajax({
	    dataType: 'json',
	    type    : 'POST',
	    data    : {'trait_id': traitId},
	    url     : '/solgs/details/trait/' + traitId,
	    success: function (trait) {
		jQuery(document.body)
		    .append('<input type="hidden" id="trait_name" value="' 
			    + trait.name + '"></input>');
		jQuery(document.body)
		    .append('<input type="hidden" id="trait_abbr" value="' 
			    + trait.abbr + '"></input>');
	    },	    
	});
    }

}


solGS.getPopulationDetails = function () {

    var populationId   = jQuery("#population_id").val();
    var populationName = jQuery("#population_name").val();
   
    var selectionPopId   = jQuery("#selection_pop_id").val();
    var selectionPopName = jQuery("#selection_pop_name").val();

    if (populationId == 'undefined') {       
        populationId   = jQuery("#model_id").val();
        populationName = jQuery("#model_name").val();
    }

    if (!populationId) {       
        populationId = jQuery("#combo_pops_id").val();
    }
   
    return {
	    'training_pop_id'   : populationId,
            'population_name'   : populationName,
	    'training_pop_name' : populationName,
	    'selection_pop_id'  : selectionPopId,
	    'selection_pop_name': selectionPopName,
           };        
}

//executes two functions alternately
jQuery.fn.alternateFunctions = function(a, b) {
    return this.each(function() {
        var clicked = false;
        jQuery(this).bind("click", function() {
            if (clicked) {
                clicked = false;
                return b.apply(this, arguments);
              
            }
            clicked = true;
             return a.apply(this, arguments);
           
        });
    });
};

