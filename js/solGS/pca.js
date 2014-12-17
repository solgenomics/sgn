/** 
* Principal component analysis and scores plotting 
* plotting using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


jQuery(document).ready( function() { 
   
    pcaResult();   
 
});


function pcaResult () {
    var popId = getPopulationId();

   // alert(popId);
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': popId},
        url: '/pca/result/' + popId,
        success: function(response) {
            if(response.status === 'success') {
                plotPca();

            } else {                
               jQuery("#pca_message").html(response.status); 
            }
        },
        error: function(response) {                    
             jQuery("#pca_message").html('Error occured running population structure analysis (PCA).');   
        }  
    });
  
}


function getPopulationId () {

    var populationId = jQuery("#population_id").val();
  
    if (!populationId) {       
        populationId = jQuery("#model_id").val();
    }

    if (!populationId) {
        populationId = jQuery("#combo_pops_id").val();
    }

    return populationId;
        
}


function plotPca(pcaData){
  
    var scores   = pcaData.scores;
    var loadings = pca.scores;
   
    
}









