/** 
* @class rankGenotypes
* functions for rankGenotypes
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

//JSAN.use('MochiKit.LoggingPane');
JSAN.use('jquery');
JSAN.use('Prototype');
//JSAN.use('hash');

var rankgenotypes = {
 gebvWeights: function( pop_id )
 {
      
        var rel_form = document.getElementById('rel_gebv_form');
        var all = rel_form.getElementsByTagName('input');
        var args = new Hash();
        var params, validate;
        var allValues = [];
        
        for (var i = 0; i < all.length; i++) {         
             var nm = all[i].name;
             var val = all[i].value;
             
             if (val != 'rank')  {
                 allValues.push(val);
                 validate = this.validateValues(nm, val);
              
                 if (validate) {
                     if (i == 0) { 
                         params = nm+'='+val; 
                     } else {
                         params = params +'&'+ nm + '=' + val;
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
            this.sendArguments(params, pop_id );
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

 sendArguments: function(params, pop_id) {
     
        if(params) {
            var action = '/traits/all/population/' + pop_id;
            jQuery.ajax({
                    type: 'POST',
                        dataType: "json",
                        url: action,
                        data: params,                       
                        success: function(res) {
                        var suc = res.status;
                        var genos = new Hash();
                        genos = res.genotypes;
                        var download = res.link;
                        var kys = [];
                        kys = Object.keys(genos);
                       
                        var table = '<table  style="padding: 1px; width:75%;">';
                        table += '<tr><th>Genotypes</th><th>Weighted Mean</th></tr>';
                       
                        for (var i=0; i<kys.length; i++) {
                            var ky = kys[i];
                            var val = genos[kys[i]];
                            table += '<tr>';
                            table += '<td  class="columnar_table bgcoloralt1">' 
                                + ky + '</td>' + '<td class="columnar_table bgcoloralt1">' 
                                + val + '</td>';
                            table += '</tr>';                          
                        }
                        var str = 'test';
                    table += '</table>';
                    table += '<br>' + download;
                    jQuery('#top_genotypes').append(table).show();
                                               
                    }
                });
        }           
    },

///////
}
////
