/*
*Saves solgs modeling output
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/



var solGS = solGS || function solGS () {};

solGS.save = {

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

    jQuery("#save_gebvs").click(function() {

		solGS.save.checkUserStatus().done(function(res) {
			if (!res.loggedin) {
				solGS.submitJob.loginAlert();
			} else {

			}
		});

		solGS.save.checkUserStatus().fail(function(){
			 solGS.alertMessage('Error occured checking for user status');
		});

		jQuery("#gebvs_output .multi-spinner-container").show();
		jQuery("#save_gebvs").hide();

		solGS.save.getResultDetails().done(function(res) {
			console.log('saveGebvs ' + res.analysis_details)
			if (res.error) {
				console.log('res analysis id ' + res.analysis_id)
					if (res.analysis_id) {
					var link = '<a href="/analyses/'+ res.analysis_id + '">View stored GEBVs</a>';
					jQuery("#gebvs_output").append(link);
				} else {
					jQuery("#save_gebvs").show();
					jQuery("#gebvs_save_message").html(res.error).show().fadeOut(10000);

				}
				jQuery("#gebvs_output .multi-spinner-container").hide();
		 } else {
			var save = solGS.save.saveGebvs(res.analysis_details);

			save.done(function(res) {
				jQuery("#gebvs_output .multi-spinner-container").hide();
				if (res.error) {
					console.log('res analysis id ' + res.analysis_id)
					if (res.analysis_id) {
					var link = '<a href="/analyses/'+ res.analysis_id + '">View Stored GEBVs</a>';
					jQuery("#gebvs_output").append(link);
				} else {
					jQuery("#gebvs_save_message").html(res.error).show().fadeOut(10000);

				}
					//jQuery("#save_gebvs").show();
				} else {

					var link = '<a href="/analyses/'+ res.analysis_id + '">View stored GEBVs</a>';
					jQuery("#gebvs_output").append(link);
			}
			});

			save.fail(function(res) {
				jQuery("#gebvs_output .multi-spinner-container").hide();
					jQuery("#save_gebvs").show();
				jQuery("#gebvs_save_message").html('Error occured storing the GEBVs').show().fadeOut(10000);
			});
}

		});

		// solGS.save.saveGebvs().fail(function(res) {
		// 	//solGS.alertMessage('Error occured storing your Gebvs in the database');
		// 	solGS.alertMessage(res.error);
		// });


    });

});
