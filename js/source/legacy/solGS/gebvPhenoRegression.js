
/** 
* breeding values vs phenotypic deviation 
* plotting using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS() {};

solGS.gebvPhenoRegression = {

gebvPhenoRegCanvasId: '#gebv_pheno_regression_canvas',
gebvPhenoRegPlotDivId: '#gebv_pheno_regression_plot',

checkDataExists: function(args) {

    var regArgs = JSON.stringify(args);
    var checkData = jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'arguments': regArgs},
        url: '/solgs/check/regression/data/',
    });

    return checkData;
  
},


getRegressionData: function(args) { 
       
    var regArgs = JSON.stringify(args);

   var regData =  jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'arguments': regArgs},
        url: '/solgs/get/regression/data/',
    });

    return regData;
},

createGebvPhenoDownloadLinks: function () {

    var gebvPhenoRegPlotDivId = this.gebvPhenoRegPlotDivId.replace(/#/, '');
    var regDownloadBtn = "download_" + gebvPhenoRegPlotDivId;
    var regPlotLink = "<a href='#'  onclick='event.preventDefault();' id='" + regDownloadBtn + "'>" + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.regression_plot_link", " Regression plot") : " Regression plot") + "</a>";
    var downloadLinks = `${(window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.download_prefix", "Download:  ") : "Download:  ")}${regPlotLink}`;

    return downloadLinks;

  },
}

jQuery(document).ready( function() {
    var args = solGS.getModelArgs();
    solGS.gebvPhenoRegression.getRegressionData(args).done(function(res){
        if (res.status) {

            var gebvPhenoRegPlotDivId = solGS.gebvPhenoRegression.gebvPhenoRegPlotDivId;
            var canvas = solGS.gebvPhenoRegression.gebvPhenoRegCanvasId;
            var downloadLinks = solGS.gebvPhenoRegression.createGebvPhenoDownloadLinks();

            var regressionData = {
                    'y_data': res.gebv_data,
                    'y_label': 'GEBVs',
                    'x_data': res.pheno_deviations,
                    'x_label': (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.phenotypic_deviations_axis", "Phenotypic deviations") : 'Phenotypic deviations'),
                    'heritability': res.heritability,
                    'plot_div_id': gebvPhenoRegPlotDivId,
                    'canvas': canvas,
                    'download_links': downloadLinks
            };
                            
            jQuery("#gebv_pheno_regression_message").empty();
            solGS.scatterPlot.plotRegression(regressionData);
        } else {
            jQuery("#gebvs_pheno_regression_message").html((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.no_gebv_phenotype_regression", "There is no GEBVs vs observed phenotypes regression data.") : 'There is no GEBVs vs observed phenotypes regression data.'));
        }
    }); 

    solGS.gebvPhenoRegression.getRegressionData(args).fail(function(res){ 
        jQuery("#gebvs_pheno_regression_message").html((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.gebv_phenotype_regression_request_error", "Error occured requesting for theGEBVs vs observed phenotypes regression data.") : 'Error occured requesting for theGEBVs vs observed phenotypes regression data.'));
    });

    jQuery("#gebv_pheno_regression_canvas").on('click' , 'a', function(e) {
		var buttonId = e.target.id;
		var regPlotId = buttonId.replace(/download_/, '');
		saveSvgAsPng(document.getElementById("#" + regPlotId),  regPlotId + ".png", {scale:1});	
	});
});










