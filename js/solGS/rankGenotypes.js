/** 
* @class rankGenotypes
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
        var rel_form = document.getElementById('rel_gebv_form');
        var all = rel_form.getElementsByTagName('input');
        var params, validate;
        var allValues = [];
        var legend = 'Relative Weights:<br/>';
        var predPopName;

        for (var i = 0; i < all.length; i++) {         
             var nm = all[i].name;
             var val = all[i].value;
             
             if (nm == 'prediction_pop_name') {
                 predPopName = val;
                 
                 if (predPopName) {
                     legend += '<br/><b>Name</b>: ' + predPopName + '<br/>';
                 }         

             }

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
                          
                            table = '<table  style="padding: 1px; width:75%;">';
                            table += '<tr><th>Genotypes</th><th>Weighted Mean</th></tr>';
                       
                            var sorted = []; 
                            for (var geno in genos) {
                                sorted.push([geno, genos[geno]]);
                                sorted = sorted.sort(function(a, b) {return b[1] - a[1]});
                            }

                            for (var i=0; i<sorted.length; i++) {
                                table += '<tr class="columnar_table bgcoloralt1">';
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
                            table = 'Ranking the genotypes failed..Please report the problem.';
                        }
                        
                        jQuery('#top_genotypes').append(table).show();                       
                        jQuery.unblockUI();                   
                    }
                });
        }           
    },

///////
}
////
