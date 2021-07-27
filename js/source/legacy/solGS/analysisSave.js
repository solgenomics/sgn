/*
*Saves solgs modeling output
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/



var solGS = solGS || function solGS () {};

solGS.save = {

	checkStoredAnalysis: function() {
		var args = this.saveGebvsArgs();

		var stored = jQuery.ajax({
			dataType: 'json',
			type : 'POST',
			data : args,
			url : '/solgs/check/stored/analysis/'

		});

		return stored;

    },

    getResultDetails: function() {
		var args = this.saveGebvsArgs();

		var details = jQuery.ajax({
			dataType: 'json',
			type : 'POST',
			data : args,
			url : '/solgs/analysis/result/details'

		});

		return details;

    },

	saveGebvs: function(args) {
		//var args = this.saveGebvsArgs();

		var save = jQuery.ajax({
			dataType: 'json',
			type : 'POST',
			data : args,
			url : '/ajax/analysis/store/json'

		});

		return save;

    },


	saveGebvsArgs: function() {
	   var trainingPopId = jQuery('#training_pop_id').val();
	   var selectionPopId = jQuery('#selection_pop_id').val();
	   var traitId       = jQuery('#trait_id').val();
	   var protocolId = jQuery('#genotyping_protocol_id').val();

	   var analysisResultType = this.analysisResultType();

	   var args = {
		   'training_pop_id' : trainingPopId,
		   'selection_pop_id': selectionPopId,
		   'trait_id' : traitId,
		   'genotyping_protocol_id' : protocolId,
		   'analysis_result_type' : analysisResultType
	   }

	   return args;
	},

	analysisResultType: function() {
		var type;
		var path = location.pathname;

		if (path.match(/solgs\/trait\/\d+\/population\/\d+\//)) {
			type = 'single model';
		} else if (path.match(/solgs\/traits\/all\/population\/\d+\//)) {
			type = 'multiple models';
		} else if (path.match(/solgs\/selection\/\d+\/model\/\d+\//)) {
			type = 'selection prediction';
		}

		return type;
	},


    checkUserStatus: function() {

		 return jQuery.ajax({
		    type    : 'POST',
		    dataType: 'json',
		    url     : '/solgs/check/user/login/'
		});

    },

}


jQuery(document).ready( function() {

	solGS.save.checkStoredAnalysis().done(function (res){
		console.log('stored analysis id ' + res.analysis_id)

		jQuery("#save_gebvs").hide();
		var link = '<a href="/analyses/'+ res.analysis_id + '">View stored GEBVs</a>';
		jQuery("#gebvs_output").append(link);

	});

    jQuery("#save_gebvs").click(function () {

		jQuery("#gebvs_output .multi-spinner-container").show();
		jQuery("#save_gebvs").hide();

		solGS.save.checkUserStatus().done(function (res) {
			if (!res.loggedin) {
				solGS.submitJob.loginAlert();
			} else {

			}
		});

		solGS.save.checkUserStatus().fail(function (){
			 solGS.alertMessage('Error occured checking for user status');
		});

		solGS.save.getResultDetails().done(function (res) {
			console.log('saveGebvs analysis_details ' + res.analysis_details)
			console.log('saveGebvs error ' + res.error)

			if (res.error) {
				console.log('getResultDetails ' + res.error)
				jQuery("#gebvs_output .multi-spinner-container").hide();
				jQuery("#gebvs_save_message")
					.html(res.error + '. The logged info may not exist for the result.')
					.show()
					.fadeOut(50000);

				jQuery("#save_gebvs").show();
		 	} else {
				var save = solGS.save.saveGebvs(res.analysis_details);

				save.done(function (res) {
					jQuery("#gebvs_output .multi-spinner-container").hide();
					if (res.error) {
						jQuery("#gebvs_save_message")
						.html(res.error)
						.show()
						.fadeOut(50000);

						jQuery("#save_gebvs").show();

					} else {
						var link = '<a href="/analyses/'+ res.analysis_id + '">View stored GEBVs</a>';
						jQuery("#gebvs_output").append(link);
					}
				});

				save.fail(function (res) {
					jQuery("#gebvs_output .multi-spinner-container").hide();
					jQuery("#save_gebvs").show();
					jQuery("#gebvs_save_message")
					.html(res.error)
					.show()
					.fadeOut(50000);

				});
			}
		});
    });
});
