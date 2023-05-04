
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
    var regPlotLink = "<a href='#'  onclick='event.preventDefault();' id='" + regDownloadBtn + "'> Regression plot</a>";
    var downloadLinks = `Download:  ${regPlotLink}`;

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
                    'breeding_values'     : res.gebv_data,
                    'phenotype_values'    : res.pheno_data,
                    'phenotype_deviations': res.pheno_deviations,
                    'heritability'        : res.heritability,
                    'gebv_pheno_regression_div_id':gebvPhenoRegPlotDivId,
                    'canvas':canvas,
                    'download_links': downloadLinks  
            };
                            
            jQuery("#gebv_pheno_regression_message").empty();
            solGS.scatterPlot.plotRegression(regressionData);
        } else {
            jQuery("#gebvs_pheno_regression_message").html('There is no GEBVs vs observed phenotypes regression data.');
        }
    }); 

    solGS.gebvPhenoRegression.getRegressionData(args).fail(function(res){ 
        jQuery("#gebvs_pheno_regression_message").html('Error occured requesting for theGEBVs vs observed phenotypes regression data.');
    });


    jQuery("#gebv_pheno_regression_canvas").on('click' , 'a', function(e) {
		var buttonId = e.target.id;
		var regPlotId = buttonId.replace(/download_/, '');
		saveSvgAsPng(document.getElementById("#" + regPlotId),  regPlotId + ".png", {scale:1});	
	});
});










