/** 
* @class rankGenotypes - selection index
* functions for rankGenotypes
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

//JSAN.use('MochiKit.LoggingPane');
JSAN.use('jquery');
JSAN.use('Prototype');
JSAN.use('jquery.blockUI');

var rankGenotypes = {
    gebvWeights: function( pop_id, prediction_pop_id )
 {    
     var selectedIdPop = jQuery('#selected_pop').val();
     selectedIdPop     = selectedIdPop.split(':');
     prediction_pop_id = selectedIdPop[0];
     var predPopName   = selectedIdPop[1];
    
     // alert('got selected pop: ' + prediction_pop_id + ": " + predPopName);
    
     var rel_form = document.getElementById('rel_gebv_form');
     var all = rel_form.getElementsByTagName('input');
     var params, validate;
     var allValues = [];
     var legend = 'Relative Weights:<br/>';

     for (var i = 0; i < all.length; i++) {         
         var nm = all[i].name;
         var val = all[i].value;
             
         // if (nm == 'prediction_pop_name') {
         //    predPopName = val;
                 
         //   if (predPopName) {
         //        legend += '<br/><b>Name</b>: ' + predPopName + '<br/>';
         //    }         

         //  }

         if (val != 'rank')  {
             if (nm != 'prediction_pop_name') {
                 allValues.push(val);
                 validate = this.validateValues(nm, val);
              
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
   
     var sum = this.sumElements(allValues);
     validate = this.validateValues('all', sum);
        
     for (var i=0;  i<allValues.length; i++)  {
         if (isNaN(allValues[i]) || allValues[i] < 0) { 
             params = undefined;
         }
     }
        
     if (predPopName) {
         legend += '<br/><b>Name</b>: ' + predPopName + '<br/>';
     }   

     if (params && validate) {
         this.sendArguments(params, legend, pop_id, prediction_pop_id);
     }//else {
     // params = false;
     //  window.location = '/traits/all/population/' + pop_id;
     // }
 },

 validateValues: function(nm, val)
 {    
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
 },

    sumElements: function(elements) {
        var sum = 0;
        for(var i=0; i<elements.length; i++) {            
            if(!isNaN(elements[i])) {
                sum +=  elements[i];
            }
        }
        return sum;
    },

    sendArguments: function(params, legend, pop_id, prediction_pop_id) {
       
        if(params) {
                                 
            jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
            jQuery.blockUI({message: 'Please wait..'});
            
            var action;
           
            if (prediction_pop_id && isNaN(prediction_pop_id) == true) {
                  
                    action = '/solgs/traits/all/population/' + pop_id;
            }else{
                action = '/solgs/traits/all/population/' + pop_id +  '/' + prediction_pop_id;
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
                        jQuery.unblockUI(); 
                        // this.selectAPopulation();
                    }
                });
        }           
    },


    listSelPopulations: function()
    {
        var selPopsDiv   = document.getElementById("selection_populations");
        var selPopsTable = selPopsDiv.getElementsByTagName("table");
        var selPopsRows  = selPopsTable[0].rows;
        var predictedPop;

        var  popsList =  '<ul  id="select_a_population">';
       
        for (var i = 1; i < selPopsRows.length; i++) {
           
            var row = selPopsRows[i];
            var popRow = row.innerHTML;
            predictedPop = popRow.match(/\/solgs\/download\/prediction\/model\//);
           
            if(predictedPop) {
                var selPopsInput = row.getElementsByTagName("input")[0];
                var idPopName    = selPopsInput.value;

                idPopName = JSON.parse(idPopName);
                var popName = idPopName.name;
        
                popsList += '<li>' + '<input class="predicted_pop" type="hidden" value="' + 
                             idPopName.id +':'+idPopName.name  +'"/>' + 
                             popName + '</li>';
            }
        }
        
        popsList += '</ul>';
   
        return popsList;

    },

    selectAPopulation: function(modelId)
    {
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
     
        if(!selectedPop) {
            var popsList = this.listSelPopulations(); 
            //alert('popList: ' + popsList);           
               if(predictedPopExists) {
                   
                   jQuery("#select_a_population_div").empty();
                   jQuery("#select_a_population_div").append(popsList);
             
                   jQuery('#select_a_population').selectable({               
                           selected: function(event, ui) { 
                               jQuery(".ui-selected").each(function() {
                                       selectedPop =  jQuery(this).children('input').val();
                                       jQuery("#selected_pop").val(selectedPop);
                                       // jQuery("#select_a_population_div").append(selectedPop).show();                 
                                   });
                           }                    
                       });
       
                   jQuery('#select_a_population_div').dialog({
                           modal: true, 
                               title: 'Select a population', 
                               minWidth: 400,                                  
                               buttons: { 
                               Select: function() { 
                                   jQuery( this ).dialog( "close" ); },  
                                   Cancel: function() {  
                                   jQuery('#selected_pop').val('');
                                   jQuery( this ).dialog( "close" ); 
                               } 
                           },                                          
                  });
               }
        }
    },


///////
}
////
