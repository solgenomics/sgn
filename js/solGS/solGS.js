/** 
* @class solgs
* general solGS app wide and misc functions
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use('jquery.blockUI');
JSAN.use('jquery.form');


function solGS () {};

solGS.waitPage = function (page) {
 
    if ( page.match(/solgs\/trait\//) || page.match(/solgs\/model\/combined\/trials\//)) {
    	askUser(page);
    } else {
    	blockPage(page);
    }
   
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
	    title  : "Analysis update message",
 	    buttons: {
		No: { text: "No, I will wait...",
                      click: function() { 
			  jQuery(this).dialog("close");
			  
			  displayAnalysisNow(page, args);
		      },
		    },

		Yes: { text: "Yes", 
                       click: function() {
			   jQuery(this).dialog("close");			  
			 
			   checkUserLogin(page, args);
		       },
		     }          
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
	    title  : 'Login Alert',
	    buttons: {
		OK: function () {
		    jQuery(this).dialog('close');
		
		    loginUser();
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
         
    jQuery(window).unload(function()  {
	jQuery.unblockUI();            
    }); 
 
}


function goToPage (page, args) {    
   
    if (page.match(/solgs\/confirm\/request/)) {

	window.location = page;
	
    } else if (page.match(/solgs\/analyze\/traits\/population\//)) {

	submitTraitSelections(page, args);	

    } else if (page.match(/solgs\/trait\//)) {
	
	window.location = page;
	    
    } else if (page.match(/solgs\/models\/combined\/trials\//)) {
	
	window.location = page;
	    
    }
	    
}


function submitTraitSelections (page, args) {
   
    wrapTraitsForm();
    
    if ( typeof args.analysis_name == 'undefined') {
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
   
    if (page.match(/solgs\/trait\//) || page.match(/solgs\/model\/combined\/trials\//)) {
	args = getArgsFromUrl(page, args);
    }
      
    var form = getProfileForm(args);
   
    jQuery('<div />', {id: 'email-form'})
	.html(form)
	.dialog({	
	    height : 300,
	    width  : 300,
	    modal  : true,
	    title  : 'Info about your analysis.',
 	    buttons: {
		Submit: function() { 
  
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
		    }

		    jQuery(this).dialog('close');
		     
		    saveAnalysisProfile(analysisProfile);
		},
		Cancel:  function() {
		    jQuery(this).dialog('close');
		},    
	    }
	});

}


function getArgsFromUrl (url, args) {
    
    if (url.match(/solgs\/trait\//)) {
	
	var urlStr = url.split(/\/+/);

	if (!args) {
	    
	    args = {'trait_id'      : [ urlStr[4] ], 
		    'population_id' : [ urlStr[6] ], 
		    'analysis_type' : 'single model',
		    'data_set_type' : 'single population',
		   };
	}
	else {

	    args['trait_id']      = [ urlStr[4]  ];
	    args['population_id'] = [  urlStr[6] ] ;
	    args['analysis_type'] = 'single model';
	    args['data_set_type'] = 'single population';
	
	}
    } 
 
    if (url.match(/solgs\/model\/combined\/trials\//)) {
	
	var urlStr = url.split(/\/+/);

	if (!args) {
	    
	    args = {'trait_id'      : [ urlStr[8] ], 
		    'population_id' : [ urlStr[6] ], 
		    'analysis_type' : 'single model',
		    'data_set_type' : 'combined populations',
		   };
	}
	else {

	    args['trait_id']      = [ urlStr[8]  ];
	    args['population_id'] = [  urlStr[6] ] ;
	    args['analysis_type'] = 'single model';
	    args['data_set_type'] = 'combined populations';
	
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
	+'<table>'
	+  '<tr>'
     	+  '<td>name:</td>'
     	+  '<td><input type="text" name="user_name" id="user_name" value=\"' + userName + '\"/></td>' 
     	+  '</tr>'
	+  '<tr>'
	+  '<td>analysis name:</td>'
	+  '<td><input  type="text" name="analysis_name" id="analysis_name"></td>'
	+  '</tr>'
        +  '<tr>'
     	+  '<td>email:</td>'
     	+  '<td><input type="text" name="user_email" id="user_email" value=\"' + email + '\"/></td>' 
     	+  '</tr>'
	+'</table>';
   
    return emailForm;
}


jQuery(document).ready(function (){
 
     jQuery('#runGS').on('click',  function() {
	 		 
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
	 
	 var traitIds = jQuery("#traits_selection_div :checkbox").fieldValue();
	 var popId = jQuery('#population_id').val(); 

	 var page;
	 var analysisType;
	 var dataSetType;
	 
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
	 
	 var args = {'trait_id'      : traitIds, 
		     'population_id' : [ popId ], 
		     'analysis_type' : analysisType,
		     'data_set_type' : dataSetType,
		    };

	 askUser(page, args);

     });
    
});


function saveAnalysisProfile (profile) {
    
    jQuery.ajax({
	type    : 'POST',
	dataType: 'json',
	data    : profile,
	url     : '/solgs/save/analysis/profile/',
	success : function(response) {
            if (response.result) {
		runAnalysis(profile);
		confirmRequest();
	
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
    });
 
}


function confirmRequest () {
    
    blockPage('/solgs/confirm/request');
 
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

