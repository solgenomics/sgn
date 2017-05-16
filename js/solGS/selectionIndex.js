/** 
* selection index form, calculation and presentation
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

JSAN.use('jquery.blockUI');


jQuery(document).ready( function () {
    
    setTimeout(function(){listSelectionIndexPopulations()}, 5000);
       
});


jQuery("#rank_genotypes").live("click", function() {        
    var modelId        = jQuery("#model_id").val();
    var selectionPopId = jQuery("#selected_population_id").val();
    var popType        = jQuery("#selected_population_type").val();
   
    selectionIndex(modelId, selectionPopId);        
});


function listSelectionIndexPopulations ()  {
   
    var modelData = getTrainingPopulationData();
    var trainingPopIdName = JSON.stringify(modelData);
   
    var  popsList =  '<dl id="selected_population" class="si_dropdown">'
        + '<dt> <a href="#"><span>Choose a population</span></a></dt>'
        + '<dd>'
        + '<ul>'
        + '<li>'
        + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
        + '</li>';  
 
    popsList += '</ul></dd></dl>'; 
   
    jQuery("#select_a_population_div").empty().append(popsList).show();
     
    var dbSelPopsList;
    if( modelData.id.match(/uploaded/) == null) {
        dbSelPopsList = addSelectionPopulations();
    }

    if (dbSelPopsList) {
            jQuery("#select_a_population_div ul").append(dbSelPopsList); 
    }
      
    var userUploadedSelExists = jQuery("#uploaded_selection_pops_table").doesExist();
    if( userUploadedSelExists == true) {
        var userSelPops = listUploadedSelPopulations();
        if (userSelPops) {

            jQuery("#select_a_population_div ul").append(userSelPops);  
        }
    }

    getSelectionPopTraits(modelData.id, modelData.id);


   jQuery(".si_dropdown dt a").click(function() {
            jQuery(".si_dropdown dd ul").toggle();
        });
                 
    jQuery(".si_dropdown dd ul li a").click(function() {
      
        var text = jQuery(this).html();
        
        jQuery(".si_dropdown dt a span").html(text);
        jQuery(".si_dropdown dd ul").hide();
                
        var idPopName = jQuery("#selected_population").find("dt a span.value").html();
        idPopName     = JSON.parse(idPopName);
        modelId = jQuery("#model_id").val();
                   
        selectedPopId   = idPopName.id;
        selectedPopName = idPopName.name;
        selectedPopType = idPopName.pop_type;
      
        jQuery("#selected_population_name").val(selectedPopName);
        jQuery("#selected_population_id").val(selectedPopId);
        jQuery("#selected_population_type").val(selectedPopType);        
            
        getSelectionPopTraits(modelId, selectedPopId);
                                         
    });
                       
    jQuery(".si_dropdown").bind('click', function(e) {
        var clicked = jQuery(e.target);
                    
        if (! clicked.parents().hasClass("si_dropdown"))
            jQuery(".si_dropdown dd ul").hide();
        
        e.preventDefault();
    });           
}

       
function addSelectionPopulations(){
      
    var selPopsTable = jQuery("#selection_pops_list").html();  
    var selPopsRows  = jQuery(selPopsTable).find("tr");
 
    var predictedPop = [];
    var popsList = '';
       
    for (var i = 1; i < selPopsRows.length; i++) {
        var row    = selPopsRows[i];
        var popRow = row.innerHTML;
       
        predictedPop = popRow.match(/\/solgs\/selection\//g);
           
        if (predictedPop) {
            if (predictedPop.length > 1) {
                var selPopsInput  = row.getElementsByTagName("input")[0];
                var idPopName     = selPopsInput.value;
                var idPopNameCopy = idPopName;
                idPopNameCopy     = JSON.parse(idPopNameCopy);
                var popName       = idPopNameCopy.name;
                        
                popsList += '<li>'
                    + '<a href="#">' + popName + '<span class=value>' + idPopName + '</span></a>'
                    + '</li>';
            }
        }
    }

    return popsList;
}


function getSelectionPopTraits (modelId, selectedPopId) {

    if (modelId === selectedPopId) {selectedPopId=undefined;}
   
    jQuery.ajax({
        type: 'POST',
        dataType: "json",
        url: '/solgs/selection/index/form',
        data: {'pred_pop_id': selectedPopId, 'training_pop_id': modelId},
        success: function(res) {
                
            if (res.status == 'success') {
                var table;
                var traits = res.traits;
                
                if (traits.length > 1) {
                    table  = selectionIndexForm(traits);
                } else {
                    var msg = 'There is only one trait with valid GEBV predictions.';
                    jQuery("#select_a_population_div").empty(); 
                    jQuery("#select_a_population_div_text").empty().append(msg);      
                }
    
                jQuery('#selection_index_form').empty().append(table);
     
            }                                               
        }
    });
}


function  selectionIndexForm(predictedTraits) {   
    var cnt = 1;
    var row = '';
    var totalCount = 1;
   
    for (var i=0; i < predictedTraits.length; i++) { 
        var tdCell  = '<td>' + predictedTraits[i]  + ':</td>';
        var rowTag  = '';
                  
        if ( cnt === 3 ) {
            rowTag = '</tr><tr>';
        }
               
        row += tdCell 
            + '<td><input type="text" name=' +  predictedTraits[i]
            + ' size = 5px '
            + '></td>'  
            + rowTag;
                                                           
        if (cnt === 3 ) { cnt=0;}
        cnt++;
        totalCount++;                          
    }
   
    var rankButton =  '<tr><td>'
        +  '<input style="position:relative;" " class="button" type="submit" value="Calculate" name= "rank" id="rank_genotypes"'     
        +  '</td></tr>';

    var table = '<br /> <table id="selection_index_table" style="align:left;width:90%"><tbody><tr>' 
        +  row + '</tr>' 
        + rankButton 
        + '</tbody></table>';
        
    return table;
}


function applySelectionIndex(params, legend, trainingPopId, predictionPopId) {
   
    if (params) {                      
        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});
            
        var action;
           
        if (!predictionPopId) {     
            predictionPopId = 'undef';      
        }
        
        var action = '/solgs/calculate/selection/index/' + trainingPopId +  '/' + predictionPopId;
          
        jQuery.ajax({
            type: 'POST',
            dataType: "json",
            url: action,
            data: params,
            success: function(res){                       
                var suc = res.status;
                var table;
                if (suc == 'success' ) {
                       
                    var genos = new Object();
              
                    genos = res.genotypes;
                    var download_link = res.link;
                    var indexFile     = res.index_file;
                        
                    table = '<table  style="text-align:left; border:0px; padding: 1px; width:75%;">';
                    table += '<tr><th>Genotypes</th><th>Selection indices</th></tr>';
                       
                    var sorted = []; 
                    for (var geno in genos) {
                        sorted.push([geno, genos[geno]]);
                        sorted = sorted.sort(function(a, b) {return b[1] - a[1]});
                    }

                    for (var i=0; i<sorted.length; i++) {
                        table += '<tr>';
                        table += '<td>' 
                            + sorted[i][0] + '</td>' + '<td>' 
                            + sorted[i][1] + '</td>';
                        table += '</tr>';                          
                    }
                        
                    table += '</table>';                    
                    table += '<br>[ ' + download_link + ' ]';
                    table += '<br>' + legend + '<br/><br/>';
                } else {
                    table = res.status + ' Ranking the genotypes failed..Please report the problem.';
                }
                        
                jQuery('#top_genotypes').append(table).show(); 
                jQuery('#selected_pop').val('');
                              
                var popId;
                var type;
                if (predictionPopId && predictionPopId !== trainingPopId) {
                    popId = predictionPopId;
                    type  = 'selection';                    
                } else {                    
                    popId = trainingPopId;
                    type  = 'training';
                }

                formatGenCorInputData(popId, type, indexFile);
                
                jQuery("#si_correlation_message")
                    .css({"padding-left": '0px'})
                    .html("Running correlation analysis..."); 
                
            },
            error: function(res){
                alert('error occured calculating selection index.');
                jQuery.unblockUI(); 
            }
        });
    }           
}


function validateRelativeWts(nm, val) {    
    
     if (isNaN(val) && nm != 'all') {
         alert('the relative weight of trait '+nm+ 
               ' must be a number.'
               );            
         return;
     } else if (!val && nm != 'all') {
         alert('You need to assign a relative weight to trait '+nm+'.' 
               +' If you want to exclude the trait assign 0 to it.'
               );            
         return;
    // }// else if (val < 0 && nm != 'all') {
      //   alert('The relative weight to trait '+nm+
      //         ' must be a positive number.'
      //         );            
     //    return;
     } else if (nm == 'all' && val == 0) {
         alert('At least two traits must be assigned relative weight.');      
         return; 
     } else {
         return true;
     }
 }


function sumElements (elements) {
    var sum = 0;
    for (var i=0; i<elements.length; i++) {            
        if (!isNaN(elements[i])) {
            sum = parseFloat(sum) +  parseFloat(elements[i]);
        }
    }
    return sum;
}

    
function selectionIndex ( trainingPopId, predictionPopId ) {    
       
    if (!predictionPopId) {
        predictionPopId = jQuery("#default_selected_population_id").val();
    }
   
    var legendValues = legendParams();
    
    var legend   = legendValues.legend;
    var params   = legendValues.params;
    var validate = legendValues.validate;
  
    if (params && validate) {
        applySelectionIndex(legendValues.params, legendValues.legend, trainingPopId, predictionPopId);
    }
}


function legendParams () {
    
    var predPopName   = jQuery("#selected_population_name").val();
   
    if (!predPopName) {
        predPopName = jQuery("#default_selected_population_name").val();
    }

    var rel_form = document.getElementById('selection_index_form');
    var all = rel_form.getElementsByTagName('input');
    var params, validate;
    var allValues = [];
    
    var legend =  "<div id=\"si_legend_" 
                    + predPopName.replace(/\s/g, "") 
                    + "\">";

    legend += '<b>Relative weights</b>:';

     for (var i = 0; i < all.length; i++) {         
         var nm = all[i].name;
         var val = all[i].value;

         if (val != 'Calculate')  {
             if (nm != 'prediction_pop_name') {
                 
                 allValues.push(val);
                 validate = validateRelativeWts(nm, val);
              
                 if (validate) {
                     if (i == 0) { 
                         params = nm+'='+val; 
                     } else {
                         params = params +'&'+ nm + '=' + val;
                     }                               
                     legend += '<b> ' + nm + '</b>' + ': '+ val;
                 }
             }
         }            
     } 
  
     var sum = sumElements(allValues);
     validate = validateRelativeWts('all', sum);
        
     for (var i=0;  i<allValues.length; i++)  {
	// (isNaN(allValues[i]) || allValues[i] < 0) 
         if (isNaN(allValues[i])) { 
             params = undefined;
         }
     }
        
     if (predPopName) {
         legend += '<br/><b>Name</b>: ' + predPopName + '<br/></div';
     }      

    return {'legend' : legend, 
            'params': params, 
            'validate' : validate
           };
}


function listUploadedSelPopulations ()  {
   
    var selPopsDivUploaded   = document.getElementById("uploaded_selection_populations");
    var selPopsTableUploaded = selPopsDivUploaded.getElementsByTagName("table");
    var selPopsRowsUploaded  = selPopsTableUploaded[0].rows;
    var predictedPopUploaded = [];
   
    var popsList ='';
    for (var i = 1; i < selPopsRowsUploaded.length; i++) {
        var row    = selPopsRowsUploaded[i];
        var popRow = row.innerHTML;
            
        predictedPopUploaded = popRow.match(/\/solgs\/selection\//g);
      
        if (predictedPopUploaded) {
            var selPopsInput  = row.getElementsByTagName("input")[0];
            var idPopName     = selPopsInput.value;     
            var idPopNameCopy = idPopName;
            idPopNameCopy     = JSON.parse(idPopNameCopy);
            var popName       = idPopNameCopy.name;
           
            popsList += '<li>'
                + '<a href="#">' + popName + '<span class=value>' + idPopName + '</span></a>'
                + '</li>';
        } else {
            popsList = undefined;
        }
    }
 
   return popsList; 
}


function getTrainingPopulationData () {

    var modelId   = jQuery("#model_id").val();
    var modelName = jQuery("#model_name").val();
    var popType   = jQuery("#default_selected_population_type").val();

    return {'id' : modelId, 'name' : modelName, 'pop_type': popType};        
}

