/** 
* @class rankGenotypes - selection index
* functions for rankGenotypes
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use('Prototype');
JSAN.use('jquery.blockUI');

function listSelPopulations ()  {
    var selPopsDiv   = document.getElementById("selection_populations");
    var selPopsTable = selPopsDiv.getElementsByTagName("table");
    var selPopsRows  = selPopsTable[0].rows;
    var predictedPop = [];
   
    var  popsList =  '<dl id="selected_population" class="si_dropdown">'
        + '<dt> <a href="#"><span>Choose a selection population</span></a></dt>'
        + '<dd>'
        + '<ul>';
       
    for (var i = 1; i < selPopsRows.length; i++) {
        var row    = selPopsRows[i];
        var popRow = row.innerHTML;
            
        predictedPop = popRow.match(/\/solgs\/download\/prediction\/model\//g);
           
        if (predictedPop) {
            if (predictedPop.length > 1) {
                var selPopsInput = row.getElementsByTagName("input")[0];
                var idPopName    = selPopsInput.value;
                        
                var idPopNameCopy = idPopName;
                idPopNameCopy     = JSON.parse(idPopNameCopy);
                var popName       = idPopNameCopy.name;
                                               
                popsList += '<li>'
                    + '<a href="#">' + popName + '<span class=value>' + idPopName + '</span></a>'
                    + '</li>';
            }
        }
    }
        
    popsList += '</ul></dd/</dl>';  
    return popsList;
}

        
function selectAPopulation(modelId){
    var selPopsDiv   = document.getElementById("selection_populations");
    var selPopsTable = selPopsDiv.getElementsByTagName("table");
    var selPopsRows  = selPopsTable[0].rows;
       
    var predictedPopExists;
       
    for (var i=0; i < selPopsRows.length; i++) {
        var row    = selPopsRows[i];
        var popRow = row.innerHTML;
           
        predictedPopExists = popRow.match(/\/solgs\/download\/prediction\/model\//);
         
        if(predictedPopExists) { 
            break; 
        }
    }
             
    var selectedPop  = jQuery('#selected_pop').val();
    var selectedPopId;
    var selectedPopName;
    var modelId;
        
    if(!selectedPop) {
        var popsList = listSelPopulations(); 
             
        if(predictedPopExists) {
            jQuery("#select_a_population_div").append(popsList);
            
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
                    //alert(model_id);
                    selectedPopId   = idPopName.id;
                    selectedPopName = idPopName.name;
                                       
                    jQuery("#selected_population_name").val(selectedPopName);
                    jQuery("#selected_population_id").val(selectedPopId);
                    
                    getSelectionPopTraits(modelId, selectedPopId);
                                         
                });
                       
            jQuery(document).bind('click', function(e) {
                    var clicked = jQuery(e.target);
                    
                    if (! clicked.parents().hasClass("si_dropdown"))
                        jQuery(".si_dropdown dd ul").hide();

                    e.preventDefault();

                });           
        }  
    }               
}

function getSelectionPopTraits (modelId, selectedPopId) {   
    jQuery.ajax({
            type: 'POST',
                dataType: "json",
                url: '/solgs/selection/index/form',
                data: {'pred_pop_id': selectedPopId, 'training_pop_id': modelId},
                success: function(res){
                
                if (res.status == 'success') {
                    var traits = res.traits;  
                    var table  = selectionIndexForm(modelId, selectedPopId, traits);
                   
                    var selectionIndex = jQuery('#selection_index').empty().append(table);
                    jQuery('#rel_gebv_form').empty();
                    //jQuery('#selection_index').empty();
                                                      
                    jQuery('#rel_gebv_form').append(selectionIndex).show(); 
                    
                }                                               
            }
        });
}


function  selectionIndexForm(modelId, predictionPopId, predictedTraits) {   
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
        +  '<input type="submit" value="Rank" name= "rank" id="rank_genotypes"'     
        +  '</td></tr>';

    var table = '<table id="selection_index_table" style="align:left;width:90%"><tr>' 
        +  row + '</tr>' 
        + rankButton 
        + '</table>';
        
    return table;

}


function applySelectionIndex(params, legend, trainingPopId, predictionPopId) {
       
    if(params) {                      
        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});
            
        var action;
           
        if (predictionPopId && isNaN(predictionPopId) == true) {
                  
            action = '/solgs/traits/all/population/' + trainingPopId;
        }else{
            action = '/solgs/traits/all/population/' + trainingPopId +  '/' + predictionPopId;
        }

        jQuery.ajax({
                type: 'POST',
                    dataType: "json",
                    url: action,
                    data: params,
                    success: function(res){                       
                    var suc = res.status;
                    var table;
                    if (suc == 'success' ) {
                        var genos = new Hash();
                        genos = res.genotypes;
                        var download_link = res.link;
                          
                        table = '<table  style="text-align:left; border:0px; padding: 1px; width:75%;">';
                        table += '<tr><th>Genotypes</th><th>Weighted Mean</th></tr>';
                       
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
                        table += '<br>' + download_link;
                        table += '<br>' + legend + '<br/><br/>';
                    }
                    else {
                        table = res.status + ' Ranking the genotypes failed..Please report the problem.';
                    }
                        
                    jQuery('#top_genotypes').append(table).show(); 
                    jQuery('#selected_pop').val('');
                    //jQuery("#select_a_population_div").empty();
                        
                    jQuery.unblockUI(); 
                      
                }
            });
    }           
}


function validateRelativeWts(nm, val)
 {    
     // alert(val + ' : ' + nm);
     if (isNaN(val) && nm != 'all') {
         alert('the relative weight of trait '+nm+ 
               ' must be a number.'
               );            
         return;
     }else if(!val && nm != 'all') {
         alert('You need to assign a relative weight to trait '+nm+'.' 
               +' If you want to exclude the trait assign 0 to it.'
               );            
         return;
     }else if(val < 0 && nm != 'all') {
         alert('The relative weight to trait '+nm+
               ' must be a positive number.'
               );            
         return;
     }else if (nm == 'all' && val == 0) {
         alert('At least two traits must be assigned relative weight.');      
         return; 
     }else{
         return true;
     }
 }


function sumElements (elements) {
        var sum = 0;
        for(var i=0; i<elements.length; i++) {            
            if(!isNaN(elements[i])) {
                sum +=  elements[i];
            }
        }
        return sum;
}

    

function selectionIndex ( trainingPopId, predictionPopId )
{    
    var predPopName   = jQuery("#selected_population_name").val();
   
    if (!predPopName) {
        predPopName = jQuery("#default_selected_population_name").val();
    }
    
    if (!predictionPopId) {
        predictionPopId = jQuery("#default_selected_population_id").val();
    }
   
    var rel_form = document.getElementById('rel_gebv_form');
    var all = rel_form.getElementsByTagName('input');
    var params, validate;
    var allValues = [];
    var legend = 'Relative Weights:<br/>';

     for (var i = 0; i < all.length; i++) {         
         var nm = all[i].name;
         var val = all[i].value;
             
         if (val != 'Rank')  {
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
         if (isNaN(allValues[i]) || allValues[i] < 0) { 
             params = undefined;
         }
     }
        
     if (predPopName) {
         legend += '<br/><b>Name</b>: ' + predPopName + '<br/>';
     }   

     if (params && validate) {
         applySelectionIndex(params, legend, trainingPopId, predictionPopId);
     }
 }




jQuery(document).ready( function () {
        jQuery("#rank_genotypes").live("click", function() {        
                var modelId          = jQuery("#model_id").val();
                var selectionPopId   = jQuery("#selected_population_id").val();
         
                selectionIndex(modelId, selectionPopId);        
            });

});


jQuery(document).ready( function () {
        selectAPopulation();
    });
