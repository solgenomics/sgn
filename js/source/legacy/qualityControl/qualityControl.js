/** 
* qualityControl coefficients plotting using d3
* Chris Simoes <cs263@cornell.edu>
*
*/


jQuery(document).ready( function() {


     jQuery("#run_pheno_qualityControl").show();    
    // var page = document.URL;


    
    // if (page.match(/solgs\/traits\/all\//) != null || 
    //     page.match(/solgs\/models\/combined\/trials\//) != null) {
    
    // setTimeout(function() {listGenCorPopulations()}, 5000);
        
    // } else {

    // var url = window.location.pathname;

    // if (url.match(/[solgs\/population|breeders_toolbox\/trial|breeders\/trial]/)) {
    //     checkPhenoqcResult();  
    // } 
    // }
          
});


function checkPhenoqcResult () {
    
    var popDetails = getPopulationDetails();
    var popId      = popDetails.population_id;
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/phenotype/qualityControl/check/result/' + popId,
        success: function(response) {
            if (response.result) {
        phenotypicqualityControl();                    
            } else { 
        jQuery("#run_pheno_qualityControl").show();    
            }
    }
    });
    
}


jQuery(document).ready( function() { 

    jQuery("#run_pheno_qualityControl").click(function() {
        phenotypicqualityControl();
	jQuery("#run_pheno_qualityControl").hide();
    }); 
  
});



function listGenCorPopulations ()  {
    var modelData = solGS.sIndex.getTrainingPopulationData();
   
    var trainingPopIdName = JSON.stringify(modelData);
   
    var  popsList =  '<dl id="qc_selected_population" class="qc_dropdown">'
        + '<dt> <a href="#"><span>Choose a population</span></a></dt>'
        + '<dd>'
        + '<ul>'
        + '<li>'
        + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
        + '</li>';  
 
    popsList += '</ul></dd></dl>'; 
   
    jQuery("#qc_select_a_population_div").empty().append(popsList).show();
     
    var dbSelPopsList;
    if (modelData.id.match(/list/) == null) {
        dbSelPopsList = solGS.sIndex.addSelectionPopulations();
    }

    if (dbSelPopsList) {
            jQuery("#qc_select_a_population_div ul").append(dbSelPopsList); 
    }
      
    var listTypeSelPops = jQuery("#list_type_selection_pops_table").length;
   
    if (listTypeSelPops) {
        var selPopsList = solGS.listTypeSelectionPopulation.getListTypeSelPopulations();

        if (selPopsList) {
            jQuery("#qc_select_a_population_div ul").append(selPopsList);  
        }
    }

    jQuery(".qc_dropdown dt a").click(function() {
        jQuery(".qc_dropdown dd ul").toggle();
    });
                 
    jQuery(".qc_dropdown dd ul li a").click(function() {
      
        var text = jQuery(this).html();
           
        jQuery(".qc_dropdown dt a span").html(text);
        jQuery(".qc_dropdown dd ul").hide();
                
        var idPopName = jQuery("#qc_selected_population").find("dt a span.value").html();
        idPopName     = JSON.parse(idPopName);
        modelId       = jQuery("#model_id").val();
                   
        var selectedPopId   = idPopName.id;
        var selectedPopName = idPopName.name;
        var selectedPopType = idPopName.pop_type; 
       
        jQuery("#qc_selected_population_name").val(selectedPopName);
        jQuery("#qc_selected_population_id").val(selectedPopId);
        jQuery("#qc_selected_population_type").val(selectedPopType);
                                
    });
                       
    jQuery(".qc_dropdown").bind('click', function(e) {
        var clicked = jQuery(e.target);
               
        if (! clicked.parents().hasClass("qc_dropdown"))
            jQuery(".qc_dropdown dd ul").hide();

        e.preventDefault();

    });           
}


function formatGenCorInputData (popId, type, indexFile) {
    var modelDetail = getPopulationDetails();

    
    var traitsIds = jQuery('#training_traits_ids').val();
    if(traitsIds) {
    traitsIds = traitsIds.split(',');
    }

    var modelId  = modelDetail.population_id;
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'model_id': modelId,
           'qc_population_id': popId,
           'traits_ids': traitsIds,
           'type' : type,
           'index_file': indexFile},
        url: '/qualityControl/genetic/data/',
        success: function(response) {

            if (response.status) {
        
                gebvsFile = response.gebvs_file;
        indexFile = response.index_file;
        
                var divPlace;
                if (indexFile) {
                    divPlace = '#si_qualityControl_canvas';
                }

                var args = {
                    'model_id': modelDetail.population_id, 
                    'qc_population_id': popId, 
                    'type': type,
            'traits_ids': traitsIds,
                    'gebvs_file': gebvsFile,
            'index_file': indexFile,
                    'div_place' : divPlace,
                };
        
                runGenqualityControlAnalysis(args);

            } else {
                jQuery(divPlace +" #qualityControl_message")
                    .css({"padding-left": '0px'})
                    .html("This population has no valid traits to qclate.");
        
            }
        },
        error: function(response) {
            jQuery(divPlace +"#qualityControl_message")
                .css({"padding-left": '0px'})
                .html("Error 3 occured preparing the additive genetic data for qualityControl analysis.");
             
            jQuery.unblockUI();
        }         
    });
}


function getPopulationDetails () {

    var populationId = jQuery("#population_id").val();
    var populationName = jQuery("#population_name").val();
   
    if (populationId == 'undefined') {       
        populationId = jQuery("#model_id").val();
        populationName = jQuery("#model_name").val();
    }

    return {'population_id' : populationId, 
            'population_name' : populationName
           };        
}


function phenotypicqualityControl () {
 
    var population = getPopulationDetails();
    
    jQuery("#qualityControl_message").html("Running qualityControl... please wait...");
         
    jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'population_id': population.population_id },
            url: '/qualityControl/phenotype/data/',
            success: function(response) {
    
                if (response.result) {
		    console.log('phenotypicqualityControl ' + response.result)
                    runPhenoqualityControlAnalysis();
                } else {
                    jQuery("#qualityControl_message")
                        .css({"padding-left": '0px'})
                        .html("This population has no phenotype data.");

		    jQuery("#run_pheno_qualityControl").show();
                }
            },
            error: function(response) {
                jQuery("#qualityControl_message")
                    .css({"padding-left": '0px'})
                    .html("Error 1 occured preparing the phenotype data for qualityControl analysis.");

		jQuery("#run_pheno_qualityControl").show();
            }
    });     
}


function runPhenoqualityControlAnalysis () {
    var population = getPopulationDetails();
    var popId     = population.population_id;
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': popId },
        url: '/phenotypic/qualityControl/analysis/output',
        success: function(response) {
            if (response.status== 'success') {
		                plotqualityControl(response.data);
		        
		        var qcDownload = "<a href=\"/download/phenotypic/qualityControl/population/" 
		                            + popId + "\">Download QC comments</a>";

		        jQuery("#qualityControl_canvas").append("<br />[ " + qcDownload + " ]").show();
		        jQuery("#qualityControl_message").empty();
				jQuery("#run_pheno_qualityControl").hide();
            } else {
                jQuery("#qualityControl_message")
                    .css({"padding-left": '0px'})
                    .html("There is no qualityControl output for this dataset."); 
        
		jQuery("#run_pheno_qualityControl").show();
            }
        },
        error: function(response) {                          
            jQuery("#qualityControl_message")
                .css({"padding-left": '0px'})
                .html("Error 2 occured running the qualityControl analysis.");
            
        jQuery("#run_pheno_qualityControl").show();
        }                
    });
}


function createqualityControlTable (tableId) {
    
    var table = '<table id="' + tableId + '" class="table" style="width:100%;text-align:left">';
    table    += '<thead><tr>';
    table    += '<th>Trait</th><th>QC - comments</t'; 
    table    += '</tr></thead>';
    table    += '</table>';

    return table;

}


function plotqualityControl (data, divPlace) {
    console.log(data)
  
    if (data) {
    var qctableId = 'qualityControl_table';    
    var qctable = createqualityControlTable(qctableId);

    jQuery('#qualityControl_canvas').append(qctable); 
       
    jQuery('#' + qctableId).dataTable({
            'searching'    : true,
            'ordering'     : true,
            'processing'   : true,
            'lengthChange' : false,
                    "bInfo"        : false,
                    "paging"       : false,
                    'oLanguage'    : {
                             "sSearch": "Filter traits: "
                            },
            'data'         : data,
        });
    }
   
}



  
