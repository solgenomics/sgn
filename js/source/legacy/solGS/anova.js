/**
* single trial ANOVA analysis
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

var solGS = solGS || function solGS() {};

solGS.anova = {
	checkTrialDesign: function () {

		var trialId = this.getTrialId();

		var args = JSON.stringify({'trial_id': trialId})
		
		jQuery.ajax({
			type: 'POST',
			dataType: 'json',
			data: {'arguments': args},
			url: '/anova/check/design/',
			success: function(response) {

			if (response.Error) {
			solGS.anova.showMessage(response.Error);
			jQuery("#run_anova").hide();
			} else {

				solGS.anova.listAnovaTraits();
			}
			},
			error: function() {
				solGS.anova.showMessage("Error occured running the ANOVA.");
				jQuery("#run_anova").show();
			}
		});

	},


	anovaAlert: function (msg) {

		var jobSubmit = '<div id= "anova_msg">' + msg + '</div>';

		jQuery(jobSubmit).appendTo('body');

			jQuery('#anova_msg')
			.dialog({
			modal  : true,
			title  : 'Alert',
			buttons: {
				OK: {
				click: function () {
					jQuery(this).dialog('close');
				},
				class: 'btn btn-success',
				text : 'OK',
				},
			}
			});
	},


	queryPhenoData: function (traitId) {

		var trialId = this.getTrialId();
		var args = JSON.stringify({'trial_id': trialId, 'trait_id': traitId});

		jQuery.ajax({
			type: 'POST',
			dataType: 'json',
		data: {'arguments': args},
			url: '/anova/phenotype/data/',
			success: function(response) {

			if (response.Error) {
				solGS.anova.showMessage(response.Error);
			jQuery("#run_anova").show();
			jQuery("#anova_canvas .multi-spinner-container").hide();
			} else {
			var traitsAbbrs = response.traits_abbrs;
			traitsAbbrs = JSON.parse(traitsAbbrs);
			solGS.anova.runAnovaAnalysis(traitsAbbrs);
			}
			},
			error: function() {
				solGS.anova.showMessage("Error occured running the ANOVA.");
				jQuery("#anova_canvas .multi-spinner-container").hide();
				jQuery("#run_anova").show();
			}
		});
	},


	showMessage: function (msg) {
		jQuery("#anova_message")
			.css({"padding-left": '0px'})
			.html(msg);

	},


	runAnovaAnalysis: function (traits) {

		var trialId = this.getTrialId();
		var captions       = jQuery('#anova_table table').find('caption').text();
		var analyzedTraits = captions.replace(/ANOVA result:/g, ' ');

		var traitAbbr = traits.trait_abbr;

		if (analyzedTraits.match(traitAbbr) == null) {
			var args = JSON.stringify({'trial_id': trialId, 'trait_id': traits.trait_id});

			jQuery.ajax({
			type: 'POST',
			dataType: 'json',
			data: {'arguments': args},
			url: '/anova/analysis/',
			success: function(response) {

				if(response.Error) {
				jQuery("#anova_canvas .multi-spinner-container").hide();
				jQuery("#anova_message").empty();
				solGS.anova.showMessage(response.Error);
				jQuery("#run_anova").show();
				} else {
				var anovaTable = response.anova_html_table;
				if (anovaTable) {
					var anovaFile = response.anova_table_file;
					var modelFile = response.anova_model_file;
					var meansFile = response.adj_means_file;
					var diagnosticsFile = response.anova_diagnostics_file;

					var fileNameAnova = anovaFile.split('/').pop();
					var fileNameModel = modelFile.split('/').pop();
					var fileNameMeans = meansFile.split('/').pop();
					var fileNameDiagnostics = diagnosticsFile.split('/').pop()
					anovaFile = "<a href=\"" + anovaFile +  "\" download=" + fileNameAnova + ">[Anova table]</a>";
					modelFile = "<a href=\"" + modelFile +  "\" download=" + fileNameModel + ">[Model summary]</a>";
					meansFile = "<a href=\"" + meansFile +  "\" download=" + fileNameMeans + ">[Adjusted means]</a>";

					diagnosticsFile = "<a href=\"" + diagnosticsFile
					+  "\" download=" + fileNameDiagnostics + ">[Model diagnostics]</a>";

					jQuery("#anova_table")
					.prepend('<div style="margin-top: 20px">' + anovaTable + '</div>'
						+ '<br /> <strong>Download:</strong> '
						+ anovaFile + ' | '
						+ modelFile + ' | '
						+ diagnosticsFile + ' | '
						+ meansFile)
					.show();

					jQuery("#anova_canvas .multi-spinner-container").hide();
					jQuery("#anova_message").empty();

					jQuery("#run_anova").show();
				}  else {
					jQuery("#anova_canvas .multi-spinner-container").hide();
					solGS.anova.showMessage("There is no anova output for this dataset.");
					jQuery("#run_anova").show();

				}
				}
				solGS.anova.clearTraitSelection();
			},
			error: function() {
				jQuery("#anova_canvas .multi-spinner-container").hide();
				solGS.anova.showMessage("Error occured running the anova analysis.");
				jQuery("#run_anova").show();
				solGS.anova.clearTraitSelection();

			}

			});
		} else {
			jQuery("#anova_message").empty();
			jQuery("#run_anova").show();
			solGS.anova.clearTraitSelection();
		}

	},


	listAnovaTraits: function ()  {

		var trialId = this.getTrialId();
		var args = JSON.stringify({'trial_id': trialId});
		jQuery.ajax({
			type: 'POST',
			dataType: 'json',
		data: {'arguments': args},
			url: '/anova/traits/list/',
			success: function(response) {
			var traits = response.anova_traits;

			if (traits.length) {
				solGS.anova.formatAnovaTraits(traits);
				jQuery("#run_anova").show();
			} else {
				solGS.anova.showMessage('This trial has no phenotyped traits.');
				jQuery("#run_anova").hide();
			}
			},
			error: function() {
				solGS.anova.showMessage("Error occured listing anova traits.");
				jQuery("#run_anova").hide();
			}
		});


	},

	formatAnovaTraits: function (traits) {

		var traitsList = '';

		for (var i = 0; i < traits.length; i++) {
		var traitName = traits[i].trait_name;

		var idName = JSON.stringify(traits[i]);
		traitsList +='<li>'
			+ '<a href="#">' + traitName + '<span class=value>' + idName + '</span></a>'
			+ '</li>';
		}

		var  traitsList =  '<dl id="anova_selected_trait" class="anova_dropdown">'
			+ '<dt> <a href="#"><span>Select a trait</span></a></dt>'
			+ '<dd>'
			+ '<ul>'
			+ traitsList
		+ '</ul></dd></dl>';

		jQuery("#anova_select_a_trait_div").empty().append(traitsList).show();

		jQuery(".anova_dropdown dt a").click(function() {
			jQuery(".anova_dropdown dd ul").toggle();
		});

		jQuery(".anova_dropdown dd ul li a").click(function() {

			var text = jQuery(this).html();

			jQuery(".anova_dropdown dt a span").html(text);
			jQuery(".anova_dropdown dd ul").hide();

			var traitIdName = jQuery("#anova_selected_trait").find("dt a span.value").html();
			traitIdName     = JSON.parse(traitIdName);

			var traitId   = traitIdName.trait_id;
			var traitName = traitIdName.trait_name;

			jQuery("#anova_selected_trait_name").val(traitName);
			jQuery("#anova_selected_trait_id").val(traitId);

		});

		jQuery(".anova_dropdown").bind('click', function(e) {
			var clicked = jQuery(e.target);

			if (!clicked.parents().hasClass("anova_dropdown"))
				jQuery(".anova_dropdown dd ul").hide();

			e.preventDefault();


		});

	},


	clearTraitSelection: function () {

		jQuery("#anova_selected_trait_name").val('');
		jQuery("#anova_selected_trait_id").val('');

	},


	getTrialId: function () {

		var trialId    =  jQuery("#trial_id").val();

		if (!trialId) {
			trialId = jQuery("#training_pop_id").val();
		}

		return trialId;

	},
}


jQuery(document).ready( function() {

    var url = document.URL;

    if (url.match(/\/breeders_toolbox\/trial|breeders\/trial|\/solgs\/population\//)) {
		solGS.anova.checkTrialDesign();
    }
});

jQuery(document).ready(function () {
    jQuery(document).on("click", "#run_anova", function() {

	var traitId = jQuery("#anova_selected_trait_id").val();

	if (traitId) {

	    solGS.anova.queryPhenoData(traitId);

	    jQuery("#run_anova").hide();
	    jQuery("#anova_canvas .multi-spinner-container").show();
	    solGS.anova.showMessage("Running ANOVA...please wait.");
	} else {
	    var msg = 'You need to select a trait first.'
	    solGS.anova.anovaAlert(msg);
	}
    });

});
