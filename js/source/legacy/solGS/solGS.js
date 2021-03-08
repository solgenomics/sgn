/**
* @class solgs
* general solGS app wide and misc functions
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use('jquery.blockUI');
JSAN.use('jquery.form');


var solGS = solGS || function solGS() {};

solGS.submitJob = {

    waitPage: function(page, args) {

		var host = window.location.protocol + '//'  + window.location.host;
		page = page.replace(host, '');

		var matchItems = 'solgs/population/'
		    + '|solgs/populations/combined/'
		    + '|solgs/trait/'
		    + '|solgs/model/combined/trials/'
		    + '|solgs/search/trials/trait\//'
		    + '|solgs/selection/\\d+|\\w+_\\d+\/model/'
			+ '|solgs/combined/model/\\d+|\\w+_\\d+/selection/'
		    + '|solgs/models/combined/trials/'
	     	+ '|solgs/traits/all/population/'
	    	+ '|kinship/analysis/';

		if (page.match(matchItems)) {

		    var multiTraitsUrls = 'solgs/traits/all/population/'
			+ '|solgs/models/combined/trials/';

		    if (page.match(multiTraitsUrls)) {
				this.getTraitsSelectionId(page, args);
		    } else {
			//if (page.match(/list_/)) {
			//	askUser(page, args)
			// } else {
			this.checkCachedResult(page, args);
			// }
		    }
		}
		else {
			console.log(' goto matchItems ' + matchItems)
	    	  this.goToPage(page, args);
		}
    },


    checkCachedResult: function(page, args) {

	var trainingTraitsIds = jQuery('#training_traits_ids').val();

	if (trainingTraitsIds ) {
	    trainingTraitsIds = trainingTraitsIds.split(',');

	    if (args === undefined) {
		args = {'training_traits_ids' : trainingTraitsIds};
	    } else {
		args['training_traits_ids'] = trainingTraitsIds;
	    }
	}

	args = this.getArgsFromUrl(page, args);
	args = JSON.stringify(args);

	jQuery.ajax({
	    type    : 'POST',
	    dataType: 'json',
	    data    : {'page': page, 'args': args },
	    url     : '/solgs/check/cached/result/',
	    success : function(response) {
		if (response.cached) {
		    args = JSON.parse(args);
		    solGS.submitJob.goToPage(page, args);
		} else {

		    if (document.URL.match(/solgs\/population\/|solgs\/populations\/combined\//)) {
			solGS.submitJob.checkTrainingPopRequirement(page, args);
		    }  else {
			args = JSON.parse(args);
			solGS.submitJob.askUser(page, args);
		    }
		}

	    },
	    error: function() {
		alert('Error occured checking for cached output.')
	    }

	})
    },


    checkTrainingPopRequirement: function(page, args) {

	jQuery.ajax({
	    dataType: 'json',
	    type    : 'POST',
	    data    : {'args': args},
	    url     : '/solgs/check/training/pop/size/',
	    success : function (res) {
		var trainingPopSize = res.member_count;
		if (trainingPopSize >= 20) {
		    args = JSON.parse(args);
		    solGS.submitJob.askUser(page, args);
		} else {
		    var msg = 'The training population size ('
			+ trainingPopSize + ') is too small. Minimum required is 20.';

		    solGS.alertMessage(msg);

		}
	    },
	});
    },


    askUser: function(page, args) {

	var t = '<p>This analysis takes long time. '
	    + 'Do you want to submit the analysis and get an email when it completes?</p>';


	jQuery('<div />')
	    .html(t)
	    .dialog({
		height : 200,
		width  : 400,
		modal  : true,
		title  : "Analysis job submission",
 		buttons: {
		    OK: {
			text: 'Yes',
			class: 'btn btn-success',
                        id   : 'queue_job',
			click: function() {
			    jQuery(this).dialog("close");

			    solGS.submitJob.checkUserLogin(page, args);
			},
		    },
		    // No: {
		    //     text: 'No, I will wait...',
		    //     class: 'btn btn-primary',
		    //     id   : 'no_queue',
		    //     click: function() {
		    // 	jQuery(this).dialog("close");

		    // 	analyzeNow(page, args);
		    //     },
		    // },
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

    },


    checkUserLogin: function(page, args) {

	if (args === undefined) {
	    args = {};
	}

	jQuery.ajax({
	    type    : 'POST',
	    dataType: 'json',
	    url     : '/solgs/check/user/login/',
	    success : function(res) {
		if (res.loggedin) {
		    var contact = res.contact;

		    args['first_name']  = contact.first_name;
		    args['user_email'] = contact.email;
		    args['user_name'] = contact.user_name;

		    solGS.submitJob.getProfileDialog(page, args);

		} else {
		    solGS.submitJob.loginAlert();
		}
	    }
	});

    },


    loginAlert: function() {

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
			    solGS.submitJob.loginUser();
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

    },


    loginUser: function() {

	window.location = '/user/login?goto_url=' + window.location.pathname;

    },


    getTraitsSelectionId: function(page, args) {

	var traitIds = args.training_traits_ids;
	var protocolId = jQuery('#genotyping_protocol_id').val();

	jQuery.ajax({
	    dataType: 'json',
	    type    : 'POST',
 	    data    : {'trait_ids': traitIds},
	    url     : '/solgs/get/traits/selection/id',
	    success : function (res){
		var traitsSelectionId = res.traits_selection_id;
		page = page  + '/traits/' + traitsSelectionId + '/gp/' + protocolId;

		//if (page.match(/list_/)) {
		//    askUser(page, args)
		//} else {
		solGS.submitJob.checkCachedResult(page, args);
		//}
	    },
	    error: function (res, st, error) {
		alert('error: ' + error)
	    },

	});

    },

    goToPage: function(page, args) {

	jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
	jQuery.blockUI({message: 'Please wait..'});

	var matchItems = 'solgs/confirm/request'
	    + '|solgs/trait/'
	    + '|solgs/traits/all/population/'
	    + '|solgs/models/combined/trials/'
	    + '|solgs/model/combined/trials/'
	    + '|kinship/analysis';

	if (page.match(matchItems)) {
	    window.location = page;
	}  else if (page.match(/solgs\/populations\/combined\//)) {
	    solGS.combinedTrials.displayCombinedTrialsTrainingPopPage(args);
	} else if (page.match(/solgs\/population\//)) {
	    // if (page.match(/solgs\/population\/list_/)) {
	    // 	var listId = args.list_id;
	    // 	loadPlotListTypeTrainingPop(listId);
	    // } else {
	    window.location = page;
	    // }
	} else if (page.match(/solgs\/selection\//)) {
		var listTypePages = 'solgs/selection/\\w+_\\d+/model/\\w+_\\d+/'
		+ '|solgs/selection/\\d+/model/\\w+_\\d+/';

	    if (page.match(/listTypePages/)) {
			loadGenotypesListTypeSelectionPop(args);
	    } else {
		window.location = page;
	    }
	}
	else {
	    window.location = window.location.href;
	}
    },


    submitTraitSelections: function(page, args) {

	wrapTraitsForm();

	if (args == 'undefined') {
	    document.getElementById('traits_selection_form').submit();
	    document.getElementById('traits_selection_form').reset();
	} else {
	    jQuery('#traits_selection_form').ajaxSubmit();
	    jQuery('#traits_selection_form').resetForm();
	}
    },


    wrapTraitsForm: function() {

	var popId  = jQuery('#population_id').val();
	var protocolId = jQuery('#genotyping_protocol_id').val();

	var formId = ' id="traits_selection_form"';

	var action;
	var referer = window.location.href;

	if ( referer.match(/solgs\/populations\/combined\//) ) {
	    action = ' action="/solgs/models/combined/trials/'
		+ popId + '/gp/'
		+ protocolId + '"';
	}

	if ( referer.match(/solgs\/population\//) ) {
	    action = ' action="/solgs/traits/all/population/'
		+ popId + '/gp/'
		+ protocolId + '"';
	}

	var method = ' method="POST"';

	var traitsForm = '<form'
	    + formId
	    + action
	    + method
	    + '>'
	    + '</form>';

	jQuery('#population_traits_list').wrap(traitsForm);

    },


    getProfileDialog: function(page, args) {

	var matchItems = '/solgs/population/'
	    + '|solgs/trait/'
	    + '|solgs/model/combined/trials/'
		+ '|solgs/combined/model/\\d+|\\w+_\\d+/selection/'
	    + '|solgs/selection/\\d+|\\w+_\\d+/model/';

	if (page.match(matchItems) ) {
	    args = this.getArgsFromUrl(page, args);
	}

	var form = this.getProfileForm(args);

	jQuery('<div />', {id: 'email-form'})
	    .html(form)
	    .dialog({
		height : 'auto',
		width  : 'auto',
		modal  : true,
		title  : 'Please fill in some info about your analysis.',
 		buttons: {
		    Submit: {
			click: function(e) {

			    var userEmail = jQuery("#user_email").val();
			    var analysisName = jQuery('#analysis_name').val();
			    var analysisType = args.analysis_type;
			    var userName  = args.user_name;
			    var dataSetType = args.data_set_type;

			    args['user_email'] = userEmail;
			    args['analysis_name'] = analysisName;
			    args['analysis_page'] = page;

			    //args = JSON.stringify(args);

			    var analysisProfile = {
				'user_name'    : userName,
				'analysis_name': analysisName,
				'analysis_page': page,
				'analysis_type': analysisType,
				'data_set_type': dataSetType,
				'arguments'    : args,
			    };


			    solGS.submitJob.checkAnalysisName(analysisName, analysisProfile);
			    solGS.submitJob.checkEmail(userEmail);

			},
			id   :'submit_job',
			class: 'btn btn-success',
			text: 'Submit',
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

    },


    checkEmail: function(email) {

	if (email == '') {
	    jQuery("#user_email")
		.css('border', 'solid #FF0000');

	    jQuery("#form-feedback-user-email")
		.text('Please give your email.');
	}

    },


    checkAnalysisName: function(name, analysisProfile) {

	jQuery.ajax({
	    dataType: 'json',
	    type    : 'POST',
 	    data    : {'name': name},
	    url     : '/solgs/check/analysis/name',
	    success : function(res) {

		if (res.match > 0) {
		    jQuery("#analysis_name")
			.css('border', 'solid #FF0000');

		    jQuery("#form-feedback-analysis-name")
			.text('The same name exists. Please give a new name.');

		    var email = jQuery('#user_email').val();
	 	    solGS.submitJob.checkEmail(email);

		} else {
		    analysisProfile['arguments'] = JSON.stringify(analysisProfile.arguments);

		    var email = jQuery('#user_email').val();
	 	    solGS.submitJob.checkEmail(email);

		    if (email) {
		    jQuery("#email-form").dialog('close');
			solGS.submitJob.saveAnalysisProfile(analysisProfile);
		    }
		}
	    },
	    error: function (response) {
		var message = 'Error occured submitting the job. Please contact the developers.'
		    + "\n\nHint: " + response.result;
		solGS.alertMessage(message);
	    }
	});

    },


    getArgsFromUrl: function(url, args) {

	var referer = document.URL;

	if (args === undefined) { args = {};}

	if (window.Prototype) {
	    delete Array.prototype.toJSON;
	}

	if (url.match(/solgs\/trait\//)) {

	    var urlStr = url.split(/\/+/);

		args['trait_id']      = [ urlStr[3] ];
		args['training_pop_id'] = [ urlStr[5] ];
		args['analysis_type'] = 'single model';
		args['data_set_type'] = 'single population';

	} else if (url.match(/solgs\/model\/combined\/trials\//)) {

	    var urlStr = url.split(/\/+/);

	    var traitId      = [];
	    var populationId = [];
	    var comboPopsId  = [];
	    var protocolId;

	    if (referer.match(/solgs\/search\/trials\/trait\//)) {
			populationId.push(urlStr[5]);
			comboPopsId.push(urlStr[5]);
			traitId.push(urlStr[7]);
			protocolId = urlStr[9];
	    }
	    else if (referer.match(/solgs\/populations\/combined\//)) {

			populationId.push(urlStr[5]);
			comboPopsId.push(urlStr[5]);
			traitId.push(urlStr[7]);
			protocolId = urlStr[9];
	    }

		args['trait_id']      = traitId;
		args['training_pop_id'] = populationId;
		args['combo_pops_id'] = comboPopsId;
		args['analysis_type'] = 'single model';
		args['data_set_type'] = 'combined populations';
		args['genotyping_protocol_id'] = protocolId;

	} else if (url.match(/solgs\/population\//)) {

	    var urlStr = url.split(/\/+/);

		args['training_pop_id'] = [ urlStr[3] ];
		args['analysis_type'] = 'training dataset';
		args['data_set_type'] = 'single population';
		args['genotyping_protocol_id'] = urlStr[5];

	} else if (url.match(/solgs\/selection\//)) {

	    var traitId = jQuery('#trait_id').val();
	    var modelId = jQuery('#model_id').val();
	    var urlStr  = url.split(/\/+/);

	    var dataSetType;

	    if (referer.match(/solgs\/model\/combined\/trials\/|solgs\/models\/combined\//)) {
			dataSetType = 'combined populations';
	    } else if (referer.match(/solgs\/trait\/|solgs\/traits\/all\/population\//)) {
			dataSetType = 'single population';
	    }

		args['trait_id']         = [ traitId ];
		args['training_pop_id']  = [ urlStr[5] ];
		args['selection_pop_id'] = [ urlStr[3] ];
		args['analysis_type']    = 'selection prediction';
		args['data_set_type']    = dataSetType;

	} else if (url.match(/solgs\/combined\/model\//)) {

	    var urlStr  = url.split(/\/+/);
		//var protocolId = urlStr[10];
	    var dataSetType = 'combined populations';

		args['training_pop_id']  = [ urlStr[4] ];
		args['selection_pop_id'] = [ urlStr[6] ];
		args['trait_id'] = [ urlStr[8] ];
		args['analysis_type']    = 'selection prediction';
		args['data_set_type']    = dataSetType;

	}

	var trainingTraitsIds = jQuery('#training_traits_ids').val();

	if (trainingTraitsIds) {
	    trainingTraitsIds = trainingTraitsIds.split(',');
	    args['training_traits_ids'] = trainingTraitsIds;
	    args['trait_id'] = trainingTraitsIds;
	}

	var protocolId = args.genotyping_protocol_id;
	if (!protocolId) {
	    protocolId = jQuery('#genotyping_protocol_id').val();
	}

	var popDesc = jQuery('#training_pop_desc').val();

	args['training_pop_desc'] = jQuery('#training_pop_desc').val();
	args['selection_pop_desc'] = jQuery('#selection_pop_desc').val();
	args['genotyping_protocol_id'] = protocolId;

	return args;

    },


    getProfileForm: function(args) {

	var email = '';
	if (args.user_email) {
	    email = args.user_email;
	}

	var firstName = '';
	if (args.first_name) {
	    firstName = args.first_name;
	}

	var emailForm = '<form><div class="form-group">'
     	    + '<label for="first_name">Name:</label>'
     	    + '<input type="text" class="form-control" id="first_name"  value=\"' + firstName + '\"/>'
	    + '</div>'
	    + '<div class="form-group">'
	    + '<label for="analysis_name">Analysis name:</label>'
	    + '<input type="text" class="form-control" id="analysis_name">'
	    + '<div style="color:red" id="form-feedback-analysis-name"> </div>'
	    + '</div>'
	    + '<div class="form-group">'
     	    + '<label for="user_email">Email:</label>'
     	    + '<input type="email" class="form-control" id="user_email" value=\"' + email + '\"/>'
	    + '<div style="color:red" id="form-feedback-user-email"> </div>'
	    + '</div>'

	    +'</form>';

	return emailForm;

    },


    saveAnalysisProfile: function(profile) {

	jQuery.ajax({
	    type    : 'POST',
	    dataType: 'json',
	    data    : profile,
	    url     : '/solgs/save/analysis/profile/',
	    success : function(response) {
		if (response.result) {
		    solGS.submitJob.runAnalysis(profile);

		} else {
		    var message = 'Failed saving your analysis profile.';
		    solGS.alertMessage(message);
		}
	    },
	    error: function () {
		var message = 'Error occured calling the function to save your analysis profile.';
		solGS.alertMessage(message);
	    }
	});

    },


    runAnalysis: function(profile) {

	jQuery.ajax({
	    dataType: 'json',
	    type    : 'POST',
 	    data    : profile,
	    url     : '/solgs/run/saved/analysis/',
	    success : function(response) {
		if (response.result.match(/Submitted/)) {
		    solGS.submitJob.confirmRequest();
		} else {
		    var message = 'Error occured submitting the job. Please contact the developers.'
			+ "\n\nHint: " + response.result;
		    solGS.alertMessage(message);
		}
	    },
	    error: function (response) {
		var message = 'Error occured submitting the job. Please contact the developers.'
		    + "\n\nHint: " + response.result;
		solGS.alertMessage(message);
	    }
	});

    },


    confirmRequest: function() {

	solGS.submitJob.goToPage('/solgs/confirm/request');

    },


    selectTraitMessage: function() {

	var message = '<p style="text-align:justify;">'
	+ 'Please select one or more traits to build prediction models.</p>';

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
    },
}


solGS.waitPage = function(page, args) {

    solGS.submitJob.waitPage(page,args);
}

jQuery(document).ready(function() {

     jQuery('#runGS').on('click',  function() {
	 if (window.Prototype) {
	     delete Array.prototype.toJSON;
	 }

	 var traitIds = jQuery("#traits_selection_div :checkbox").fieldValue();
	 var popId    = jQuery('#training_pop_id').val();
	 var protocolId = jQuery('#genotyping_protocol_id').val();

	 if (traitIds.length) {
	     var page;
	     var analysisType;
	     var dataSetType;

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

		     page = '/solgs/model/combined/trials/' + popId
			 + '/trait/' + traitIds[0]
			 + '/gp/' + protocolId;

		 } else if ( referer.match(/solgs\/population\//)) {

		     page = '/solgs/trait/' + traitIds[0]
			 + '/population/' + popId
			 + '/gp/' + protocolId;
		 }

	     } else {

		 analysisType = 'multiple models';

		 if ( referer.match(/solgs\/populations\/combined\//) ) {
		     page = '/solgs/models/combined/trials/' + popId;

		 } else {
		     page = '/solgs/traits/all/population/' + popId;
		 }
	     }

	     var args = {'trait_id'        : traitIds,
			 'training_traits_ids': traitIds,
			 'training_pop_id' : [ popId ],
			 'analysis_type'   : analysisType,
			 'data_set_type'   : dataSetType,
			};

	     solGS.submitJob.waitPage(page, args);

	 } else {
	     solGS.submitJob.selectTraitMessage();
	 }
     });
});


solGS.alertMessage = function(msg, msgTitle, divId) {

    if (!msgTitle) {
	msgTitle = 'Message';
    }

    if (!divId) {
	divId = 'error_message';
    }

    jQuery('<div />', {id: divId})
	.html(msg)
	.dialog({
	   height : 'auto',
	    width  : 'auto',
	    modal  : true,
	    title  : msgTitle,
	    buttons: {
		OK: { click: function () {
		    jQuery(this).dialog('close');
		    //window.location = window.location.href;
		},
		class: 'btn btn-success',
		text : 'OK',
	    }
	}
	});
}


solGS.getTraitDetails = function(traitId) {

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


solGS.getPopulationDetails = function() {

    var trainingPopId   = jQuery("#population_id").val();
    var trainingPopName = jQuery("#population_name").val();

    if (!trainingPopId) {
    	trainingPopId   = jQuery("#training_pop_id").val();
    	trainingPopName = jQuery("#training_pop_name").val();
    }

    var selectionPopId   = jQuery("#selection_pop_id").val();
    var selectionPopName = jQuery("#selection_pop_name").val();

    if (!trainingPopId) {
        trainingPopId  = jQuery("#model_id").val();
        traininPopName = jQuery("#model_name").val();
    }

    var  comboPopsId = jQuery("#combo_pops_id").val();

    var dataSetType;

    if (comboPopsId) {
        dataSetType = 'combined populations';
    	trainingPopId = comboPopsId;
    } else {
        dataSetType = 'single population';
    }

    return {
	'training_pop_id'   : trainingPopId,
        'population_name'   : trainingPopName,
	'training_pop_name' : trainingPopName,
	'selection_pop_id'  : selectionPopId,
	'selection_pop_name': selectionPopName,
	'combo_pops_id'     : comboPopsId,
	'data_set_type'     : dataSetType
    };
}


solGS.showMessage = function(divId, msg) {
     jQuery("#" + divId)
        .css({"padding-left": '0px'})
        .html(msg);

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

jQuery.fn.doesExist = function() {

        return jQuery(this).length > 0;

};



jQuery(document).on('keyup', '#user_email', function(e) {

    jQuery("#user_email")
	.css('border', 'solid #96d3ec');

    jQuery("#form-feedback-user-email")
	.empty();
});

jQuery(document).on('keyup', '#analysis_name', function(e) {

    jQuery("#analysis_name")
	.css('border', 'solid #96d3ec');

    jQuery("#form-feedback-analysis-name")
	.empty();
});
