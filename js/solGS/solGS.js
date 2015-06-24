/** 
* @class solgs
* general solGS app wide and misc functions
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use('jquery.blockUI');

function solGS () {};

solGS.waitPage = function (page) {

//ask user if they want to be notified when analysis is complete.
//if yes, call server side method to store user and analysis details
//run analysis.
//email to the user the link to the analysis output page 
//if no, block page and run analysis as usual..
 
    //alert(page)

      askUser(page);




                 
        //jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        // jQuery.blockUI({message: 'Please wait..'});
         
        // jQuery(window).unload(function()  {
        //         jQuery.unblockUI();            
        //     });

//
   }



solGS.analysisUpdate = function () {
    



}


function  askUser(page) {
     
    //count to 5 sec and then ask...

   
    var t = '<p>This analysis may take longer than 20 min. ' 
	+ 'Would you like to be emailed when it is done?</p>';
    
    jQuery('<div />')
	.html(t)
	.dialog( {
	    height : 200,
	    width  : 400,
	    modal  : true,
	    title  : "Analysis update message",
 	    buttons: {
		No: { text: "No, I will wait...",
                      click: function() { 
			  jQuery(this).dialog("close");
			  displayAnalysisNow(page);
		      },
		    },

		Yes: { text: "Yes", 
                       click: function() {
			   jQuery(this).dialog("close");			  
			   getProfileDialog(page);
		       },
		     }          
	    }
	});
  
}


function displayAnalysisNow (page) {
   // alert(page);
    window.location = page;
    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({message: 'Please wait..'});
         
    jQuery(window).unload(function()  {
            jQuery.unblockUI();            
    });

 }



function getProfileForm () {
  
    var emailForm = '<p>Please fill in your email.</p>'
	+'<table>'
	+ '<tr>'
	+  '<td>Your name:</td>'
	+  '<td><input  type="text" name="user_name" id="user_name"></td>'
	+ '</tr>'
	+ '<tr>'
	+  '<td>Your analysis name:</td>'
	+  '<td><input  type="text" name="analysis_name" id="analysis_name"></td>'
	+  '</tr>'
	+ '<tr>'
	+  '<td>Email:</td>'
	+  '<td><input type="text" name="user_email" id="user_email"></td>' 
	+ '</tr>'
	+'</table>';
   
    return emailForm;
}
 

function clearUserEmail() {
    document.getElementById('#user_email').reset();

}

function clearUserName() {
    document.getElementById('#user_name').reset();

}

function clearAnalysisName() {
    alert('analysis name before reset: ' + jQuery('#analysis_name').val());
    document.getElementById('#analysis_name').reset();
    alert('analysis name after reset:' + jQuery('#analysis_name').val());
}

function getProfileDialog (page) {
    var form = getProfileForm();
    
    jQuery('<div />', {id: 'email-form'})
	.html(form)
	.dialog({	
	    height : 300,
	    width  : 300,
	    modal  : true,
	    title  : 'Submit your email',
 	    buttons: {
		Submit: function() { 
		    var userName     = jQuery('#user_name').val();
		    var userEmail    = jQuery('#user_email').val();
		    var analysisName = jQuery('#analysis_name').val();
		     //validate input
		    var analysisProfile = {
			'user_name'    : userName, 
			'user_email'   : userEmail,
			'analysis_name': analysisName,
			'analysis_page': page
		    }
		    
		   // jQuery('#user_name').val('');
		   // jQuery('#user_email').val('');
		   // jQuery('#analysis_name').val('');
		   // window.location = window.location.href;


		   

		    jQuery(this).dialog('close');
		     
		    saveAnalysisProfile(analysisProfile);
 // alert('clearing..analysis name');
 // 		    clearAnalysisName();
 // 		    alert('clearing..user name');
 // 		  clearUserName();
 // 		     alert('clearing..user email');
 // 		    clearUserEmail();
		    
		},
		Cancel:  function() {
		    jQuery(this).dialog('close');
		},    
	    }
	});

}


// function confirmRequest () {
//    var m = 'You will receive an email when the analysis is complete.'; 
    
//     jQuery('<div />', {id: 'confirmation-message'})
// 	.html(m)
// 	.dialog({	
// 	    height: 200,
// 	    width:  250,
// 	    modal: true,
// 	    title: 'Request confirmation',
//  	    buttons: {
// 		OK: function() {
// 		    jQuery(this).dialog('close');
	
	 	   
// 		}
// 	    }
// 	});
	
//    //  
// }


function saveAnalysisProfile (profile) {
    
    //make an ajax request
    //save analysis details in a file
    //run analysis, when complete, retrieve analysis owner and send an email

    jQuery.ajax({
	type    : 'POST',
	dataType: 'json',
	cache   : false,
	data    : profile,
	url     : '/solgs/save/analysis/profile/',
	success : function(response) {
            if (response.result) {
		runAnalysis(profile);
		confirmRequest();
		
		//jQuery(document).ready( function () {
		  //  alert('calling run analysis... ' + profile.user_name);
	
		//    runAnalysis(profile);
		    
	//	});
		
	
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
    alert('called runAnalysis...' + profile.analysis_name);
    
    jQuery.ajax({
	async: true,
	type: 'POST',
	dataType: 'json',
	data: profile,
	url: '/solgs/run/saved/analysis/',
	 success: function () {
	//     alert(res.empty_response); 
	//     window.location.reload(true);   
	 },	
    });
 
}


function confirmRequest () {
    alert('confirming request');
    // jQuery.ajax({
    // 	type: 'POST',
    // 	dataType: 'json',
    // 	url: '/solgs/confirm/request/',
    // 	// success: function (res) {
    // 	//     alert(res.empty_response); 
    // 	//     window.location.reload(true);   
    // 	// },

	
    // });

    window.location.href ='/solgs/confirm/request/';
 
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
//



 //  $(function() {
//     var dialog, form,
 
//       // From http://www.whatwg.org/specs/web-apps/current-work/multipage/states-of-the-type-attribute.html#e-mail-state-%28type=email%29
//       emailRegex = /^[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/,
//       name = $( "#name" ),
//       email = $( "#email" ),
//       password = $( "#password" ),
//       allFields = $( [] ).add( name ).add( email ).add( password ),
//       tips = $( ".validateTips" );
 
//     function updateTips( t ) {
//       tips
//         .text( t )
//         .addClass( "ui-state-highlight" );
//       setTimeout(function() {
//         tips.removeClass( "ui-state-highlight", 1500 );
//       }, 500 );
//     }
 
//     function checkLength( o, n, min, max ) {
//       if ( o.val().length > max || o.val().length < min ) {
//         o.addClass( "ui-state-error" );
//         updateTips( "Length of " + n + " must be between " +
//           min + " and " + max + "." );
//         return false;
//       } else {
//         return true;
//       }
//     }
 
//     function checkRegexp( o, regexp, n ) {
//       if ( !( regexp.test( o.val() ) ) ) {
//         o.addClass( "ui-state-error" );
//         updateTips( n );
//         return false;
//       } else {
//         return true;
//       }
//     }
 
//     function addUser() {
//       var valid = true;
//       allFields.removeClass( "ui-state-error" );
 
//       valid = valid && checkLength( name, "username", 3, 16 );
//       valid = valid && checkLength( email, "email", 6, 80 );
//       valid = valid && checkLength( password, "password", 5, 16 );
 
//       valid = valid && checkRegexp( name, /^[a-z]([0-9a-z_\s])+$/i, "Username may consist of a-z, 0-9, underscores, spaces and must begin with a letter." );
//       valid = valid && checkRegexp( email, emailRegex, "eg. ui@jquery.com" );
//       valid = valid && checkRegexp( password, /^([0-9a-zA-Z])+$/, "Password field only allow : a-z 0-9" );
 
//       if ( valid ) {
//         $( "#users tbody" ).append( "<tr>" +
//           "<td>" + name.val() + "</td>" +
//           "<td>" + email.val() + "</td>" +
//           "<td>" + password.val() + "</td>" +
//         "</tr>" );
//         dialog.dialog( "close" );
//       }
//       return valid;
//     }
 
//     dialog = $( "#dialog-form" ).dialog({
//       autoOpen: false,
//       height: 300,
//       width: 350,
//       modal: true,
//       buttons: {
//         "Create an account": addUser,
//         Cancel: function() {
//           dialog.dialog( "close" );
//         }
//       },
//       close: function() {
//         form[ 0 ].reset();
//         allFields.removeClass( "ui-state-error" );
//       }
//     });
 
//     form = dialog.find( "form" ).on( "submit", function( event ) {
//       event.preventDefault();
//       addUser();
//     });
 
//     $( "#create-user" ).button().on( "click", function() {
//       dialog.dialog( "open" );
//     });
//   });
//   </script>
// </head>
// <body>
 
