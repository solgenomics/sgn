
/** 
* breeding values vs phenotypic deviation 
* plotting using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS() {};

solGS.gebvPhenoRegression = {

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
}
}

jQuery(document).ready( function() {
    var args = solGS.getModelArgs();
    solGS.gebvPhenoRegression.getRegressionData(args).done(function(res){
        if (res.status) {
            var regressionData = {
                    'breeding_values'     : res.gebv_data,
                    'phenotype_values'    : res.pheno_data,
                    'phenotype_deviations': res.pheno_deviations,
                    'heritability'        : res.heritability  
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
});










