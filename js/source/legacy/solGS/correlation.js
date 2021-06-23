/**
* correlation coefficients plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use("solGS.heatMap");

var solGS = solGS || function solGS() {};

solGS.correlation = {

    checkPhenoCorreResult: function () {

	var popId =  jQuery("#corre_pop_id").val();

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            url: '/phenotype/correlation/check/result',
            data: {'corre_pop_id': popId},
            success: function (response) {
		if (response.result) {
		    solGS.correlation.phenotypicCorrelation();
		} else {
		    jQuery("#run_pheno_correlation").show();
		}
	    }
	});

    },

    listGenCorPopulations: function ()  {
	var modelData = solGS.sIndex.getTrainingPopulationData();

	var trainingPopIdName = JSON.stringify(modelData);

	var  popsList =  '<dl id="corre_selected_population" class="corre_dropdown">'
            + '<dt> <a href="#"><span>Choose a population</span></a></dt>'
            + '<dd>'
            + '<ul>'
            + '<li>'
            + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
            + '</li>';

	popsList += '</ul></dd></dl>';

	jQuery("#corre_select_a_population_div").empty().append(popsList).show();

	var dbSelPopsList;
	if (modelData.id.match(/list/) == null) {
            dbSelPopsList = solGS.sIndex.addSelectionPopulations();
	}

	if (dbSelPopsList) {
            jQuery("#corre_select_a_population_div ul").append(dbSelPopsList);
	}

	var listTypeSelPops = jQuery("#list_type_selection_pops_table").length;

	if (listTypeSelPops) {
            var selPopsList = solGS.sIndex.getListTypeSelPopulations();

            if (selPopsList) {
		jQuery("#corre_select_a_population_div ul").append(selPopsList);
            }
	}

	jQuery(".corre_dropdown dt a").click(function () {
            jQuery(".corre_dropdown dd ul").toggle();
	});

	jQuery(".corre_dropdown dd ul li a").click(function () {

            var text = jQuery(this).html();

            jQuery(".corre_dropdown dt a span").html(text);
            jQuery(".corre_dropdown dd ul").hide();

            var idPopName = jQuery("#corre_selected_population").find("dt a span.value").html();
            idPopName     = JSON.parse(idPopName);
            modelId       = jQuery("#model_id").val();

            var selectedPopId   = idPopName.id;
            var selectedPopName = idPopName.name;
            var selectedPopType = idPopName.pop_type;

            jQuery("#corre_selected_population_name").val(selectedPopName);
            jQuery("#corre_selected_population_id").val(selectedPopId);
            jQuery("#corre_selected_population_type").val(selectedPopType);

	});

	jQuery(".corre_dropdown").bind('click', function (e) {
            var clicked = jQuery(e.target);

            if (! clicked.parents().hasClass("corre_dropdown"))
		jQuery(".corre_dropdown dd ul").hide();

            e.preventDefault();

	});
    },


    formatGenCorInputData: function (correPopId, popType, sIndexFile) {

    var trainingPopId = jQuery('#training_pop_id').val();
	var traitsIds = jQuery('#training_traits_ids').val();
    var traitsCode = jQuery('#training_traits_code').val();
    var divPlace;
	if (traitsIds) {
	    traitsIds = traitsIds.split(',');
	}
	var protocolId = jQuery('#genotyping_protocol_id').val();
	var genArgs = {
	    'training_pop_id': trainingPopId,
	    'corre_pop_id': correPopId,
	    'training_traits_ids': traitsIds,
        'training_traits_code': traitsCode,
	    'pop_type' : popType,
	    'selection_index_file': sIndexFile,
	    'genotyping_protocol_id': protocolId
	};

    genArgs = JSON.stringify(genArgs);

	jQuery("#run_genetic_correlation").hide();
	jQuery("#correlation_message")
            .css({"padding-left": '0px'})
            .html("Running genetic correlation analysis...");

	jQuery("#correlation_canvas .multi-spinner-container").show();

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'arguments': genArgs},
            url: '/correlation/genetic/data/',
            success: function (res) {

		if (res.status) {

            var genArgs = JSON.parse(res.corre_args);

            if (genArgs.selection_index_file) {
			    divPlace = '#si_correlation_canvas';
            } else {
			    divPlace = '#correlation_canvas';
		    }

            genArgs['div_place'] = divPlace;
            solGS.correlation.runGenCorrelationAnalysis(genArgs);

		} else {
                    jQuery(divPlace +" #correlation_message")
			.css({"padding-left": '0px'})
			.html("This population has no valid traits to correlate.");

		}
            },
            error: function (res) {
		jQuery(divPlace +"#correlation_message")
                    .css({"padding-left": '0px'})
                    .html("Error occured preparing the additive genetic data for correlation analysis.");

		jQuery.unblockUI();
            }
	});
    },

    phenotypicCorrelation: function() {

    var correPopId = jQuery('#corre_pop_id').val();
	jQuery("#run_pheno_correlation").hide();
	jQuery("#correlation_canvas .multi-spinner-container").show();
	jQuery("#correlation_message").html("Running correlation... please wait...");

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'corre_pop_id': correPopId},
            url: '/correlation/phenotype/data/',
            success: function (response) {

                if (response.result) {
                    solGS.correlation.runPhenoCorrelationAnalysis();
                } else {
                    jQuery("#correlation_message")
                        .css({"padding-left": '0px'})
                        .html("This population has no phenotype data.");

		    jQuery("#run_pheno_correlation").show();
                }
            },
            error: function (response) {
                jQuery("#correlation_message")
                    .css({"padding-left": '0px'})
                    .html("Error occured preparing the phenotype data for correlation analysis.");

		jQuery("#run_pheno_correlation").show();
            }
	});
    },


    runPhenoCorrelationAnalysis: function () {
	var popId     = jQuery('#corre_pop_id').val();

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'corre_pop_id': popId},
            url: '/phenotypic/correlation/analysis/output',
            success: function (response) {
		if (response.data) {
                    solGS.correlation.plotCorrelation(response.data, '#correlation_canvas');

		    var corrDownload = "<a href=\"/download/phenotypic/correlation/population/"
		        + popId + "\">Download correlation coefficients</a>";

		    jQuery("#correlation_canvas").append("<br />[ " + corrDownload + " ]").show();

		    jQuery("#correlation_canvas .multi-spinner-container").hide();
                    jQuery("#correlation_message").empty();
		    jQuery("#run_pheno_correlation").hide();
		} else {
		    jQuery("#correlation_canvas .multi-spinner-container").hide();
                    jQuery("#correlation_message")
			.css({"padding-left": '0px'})
			.html("There is no correlation output for this dataset.")
			.fadeOut(8400);

		    jQuery("#run_pheno_correlation").show();
		}
            },
            error: function (response) {
                jQuery("#correlation_canvas .multi-spinner-container").hide();
		jQuery("#correlation_message")
                    .css({"padding-left": '0px'})
                    .html("Error occured running the correlation analysis.")
		    .fadeOut(8400);

		jQuery("#run_pheno_correlation").show();
            }
	});
    },


    runGenCorrelationAnalysis: function (args) {
  var divPlace = args.div_place;
  args = JSON.stringify(args);
	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'arguments': args} ,
            url: '/genetic/correlation/analysis/output',
            success: function (response) {
		if (response.status == 'success') {

                    if (divPlace == '#si_correlation_canvas') {
			jQuery("#si_correlation_message").empty();
			jQuery("#si_correlation_section").show();
                    }

                    solGS.correlation.plotCorrelation(response.data, divPlace);
                    jQuery("#correlation_message").empty();

                    if (divPlace === '#si_correlation_canvas') {

			var popName   = jQuery("#selected_population_name").val();
			var corLegDiv = "<div id=\"si_correlation_"
                            + popName.replace(/\s/g, "")
                            + "\"></div>";

			var legendValues = solGS.sIndex.legendParams();
			var corLegDivVal = jQuery(corLegDiv).html(legendValues.legend);

			jQuery("#si_correlation_canvas").append(corLegDivVal).show();

                    } else {

			var popName = jQuery("#corre_selected_population_name").val();
			var corLegDiv  = "<div id=\"corre_correlation_"
                            + popName.replace(/\s/g, "")
                            + "\"></div>";

			var corLegDivVal = jQuery(corLegDiv).html(popName);
			jQuery("#correlation_canvas").append(corLegDivVal).show();

			jQuery("#run_genetic_correlation").show();
                    }

		} else {
                    jQuery(divPlace + " #correlation_message")
			.css({"padding-left": '0px'})
			.html("There is no genetic correlation output for this dataset.");
		}

		jQuery("#correlation_canvas .multi-spinner-container").hide();
		jQuery.unblockUI();
            },
            error: function (response) {
		jQuery(divPlace +" #correlation_message")
                    .css({"padding-left": '0px'})
                    .html("Error occured running the genetic correlation analysis.");

		jQuery("#run_genetic_correlation").show();
		jQuery("#correlation_canvas .multi-spinner-container").hide();
		jQuery.unblockUI();
            }
	});
    },


    plotCorrelation: function (data, divPlace) {

	solGS.heatmap.plot(data, divPlace);

    },


    // createAcronymsTable: function (tableId) {
    //
	// var table = '<table id="' + tableId + '" class="table" style="width:100%;text-align:left">';
	// table    += '<thead><tr>';
	// table    += '<th>Acronyms</th><th>Trait</th>';
	// table    += '</tr></thead>';
	// table    += '</table>';
    //
	// return table;
    //
    // },
    //
    //
    // displayTraitAcronyms: function (acronyms) {
    //
	// if (acronyms) {
	//     var tableId = 'traits_acronyms';
	//     var table = this.createAcronymsTable(tableId);
    //
	//     jQuery('#correlation_canvas').append(table);
    //
	//     jQuery('#' + tableId).dataTable({
	// 	'searching'    : true,
	// 	'ordering'     : true,
	// 	'processing'   : true,
	// 	'lengthChange' : false,
    //             "bInfo"        : false,
    //             "paging"       : false,
    //             'oLanguage'    : {
	// 	    "sSearch": "Filter traits: "
	// 	},
	// 	'data'         : acronyms,
	//     });
	// }
    //
    // },

///////
}

////////

jQuery(document).ready( function () {
    var page = document.URL;

    if (page.match(/solgs\/traits\/all\//) != null ||
        page.match(/solgs\/models\/combined\/trials\//) != null) {

	setTimeout(function () {solGS.correlation.listGenCorPopulations()}, 5000);

    } else {

	if (page.match(/solgs\/population\/|breeders\/trial\//)) {
	    solGS.correlation.checkPhenoCorreResult();
	}
    }

});


jQuery(document).ready( function () {

    jQuery("#run_pheno_correlation").click(function () {
        solGS.correlation.phenotypicCorrelation();
	jQuery("#run_pheno_correlation").hide();
    });

});


jQuery(document).on("click", "#run_genetic_correlation", function () {
    var popId   = jQuery("#corre_selected_population_id").val();
    var popType = jQuery("#corre_selected_population_type").val();

    //jQuery("#correlation_canvas").empty();

    solGS.correlation.formatGenCorInputData(popId, popType);

});
