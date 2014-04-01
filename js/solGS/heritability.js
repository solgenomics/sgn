/** 
* breeding values vs phenotypic deviation 
* plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

JSAN.use('statistics.jsStats');


function getDataDetails () {

    var populationId   = jQuery("#population_id").val();
    var traitId        = jQuery("#trait_id").val();
   
    if(populationId == 'undefined' ) {       
        populationId = jQuery("#model_id").val();
    }

    if(populationId == 'undefined') {
        populationId = jQuery("#combo_pops_id").val();
    }

    return {'population_id' : populationId, 
            'trait_id' : traitId
            };
        
}


function checkDataExists () {
    var dataDetails  = getDataDetails();
    var traitId      = dataDetails.trait_id;
    var populationId = detaDetails.population_id;

    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': populationId, 'trait_id': traitId },
        url: '/heritabililty/check/data/',
        success: function(response) {
            if(response.exists == true) {
                return true;
            } else {                
                return false;
            }
        },
        error: function(response) {                    
            // alert('there is error in checking the dataset for heritability analysis.');
            return false;
        }
    });
}


function getRegressionData () {
    var dataExists = checkDataExists();
    
    if (dataExists == true) {

        var dataDetails  = getDataDetails();
        var traitId      = dataDetails.trait_id;
        var populationId = detaDetails.population_id;
        
        var breedingValues = [];
        var phenotypeDeviations = [];

        jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'population_id': populationId, 'trait_id': traitId },
            url: '/heritabililty/regeression/data/',
            success: function(response) {
                if(response.exists == true) {
                    return true;
                } else {                
                    return false;
                }
            },
            error: function(response) {                    
                // alert('there is error in checking the dataset for heritability analysis.');
                return false;
            }
        });

    }


}


function plotRegressionData(){

    getRegressionData();

}


jQuery(document).ready( function () { 
    plotRegressionData();
 });






