/** 
* selection index form, calculation and presentation
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

JSAN.use('jquery.blockUI');



var solGS = solGS || function solGS () {};


solGS.sIndex = {
   
    listSelectionIndexPopulations: function()  {
   
	var modelData = this.getTrainingPopulationData();
	var trainingPopIdName = JSON.stringify(modelData);
	
	var  popsList =  '<dl id="selected_population" class="si_dropdown">'
            + '<dt> <a href="#"><span>Choose a population</span></a></dt>'
            + '<dd><ul>'
            + '<li>'
            + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
            + '</li>'
	    + '</ul></dd></dl>'; 
	
	jQuery("#si_canvas #select_a_population_div").empty().append(popsList).show();
	
	var dbSelPopsList;
	if ( modelData.id.match(/list/) == null) {
            dbSelPopsList = this.addSelectionPopulations();
	}

	if (dbSelPopsList) {
            jQuery("#si_canvas #select_a_population_div ul").append(dbSelPopsList); 
	}
	
	var listTypeSelPops = jQuery("#list_type_selection_pops_table").length;

	if (listTypeSelPops == true) {
            var listTypeSelPops = this.getListTypeSelPopulations();

	    if (listTypeSelPops) {
		jQuery("#si_canvas #select_a_population_div ul").append(listTypeSelPops);  
            }
	}

	this.getSelectionPopTraits(modelData.id, modelData.id);
	
	jQuery(".si_dropdown dt a").click(function() {
            jQuery(".si_dropdown dd ul").toggle();
        });
        
	jQuery(".si_dropdown dd ul li a").click(function() {
	    
            var text = jQuery(this).html();
            
            jQuery(".si_dropdown dt a span").html(text);
            jQuery(".si_dropdown dd ul").hide();
            
            var idPopName = jQuery("#si_canvas #selected_population").find("dt a span.value").html();
            idPopName     = JSON.parse(idPopName);
            modelId = jQuery("#model_id").val();
            
            selectedPopId   = idPopName.id;
            selectedPopName = idPopName.name;
            selectedPopType = idPopName.pop_type;
	    
            jQuery("#si_canvas #selected_population_name").val(selectedPopName);
            jQuery("#si_canvas #selected_population_id").val(selectedPopId);
            jQuery("#si_canvas #selected_population_type").val(selectedPopType);        
            
           this.getSelectionPopTraits(modelId, selectedPopId);
            
	});
        
	jQuery(".si_dropdown").bind('click', function(e) {
            var clicked = jQuery(e.target);
            
            if (! clicked.parents().hasClass("si_dropdown"))
		jQuery(".si_dropdown dd ul").hide();
            
            e.preventDefault();
	});           
    },

    addIndexedClustering: function() {

	var indexed = solGS.sIndex.indexed;
	var sIndexList = ''; 

	if (indexed) {

	    for (var i = 0; i < indexed.length; i++) {
		var indexData = {
		    'id': indexed[i][0],
		    'name': indexed[i][1],
		    'pop_type': 'selection_index'
		};
	
		indexData = JSON.stringify(indexData);
		sIndexList += '<li><a href="#">' + indexed[i][1] + '<span class=value>' + indexData + '</span></a></li>';
	    }
	}
	
	return sIndexList;
    },


    saveIndexedPops: function(siId) {
	solGS.sIndex.indexed.push(siId);	    
    },
        
    addSelectionPopulations: function() {
      
	var selPopsTable = jQuery("#selection_pops_list").html();
	var selPopsRows;
	
	if (selPopsTable !== null) {
	    selPopsRows  = jQuery("#selection_pops_list").find("tbody > tr");
	}
	
	var predictedPop = [];
	var popsList = '';
	
	for (var i = 0; i < selPopsRows.length; i++) {
            var row    = selPopsRows[i];
            var popRow = row.innerHTML;
	    
            predictedPop = popRow.match(/\/solgs\/selection\//g);
            
            if (predictedPop) {
		if (predictedPop.length) {
                    var selPopsInput  = row.getElementsByTagName("input")[0];
                    var idPopName     = selPopsInput.value;
                    var idPopNameCopy = idPopName;
                    idPopNameCopy     = JSON.parse(idPopNameCopy);
                    var popName       = idPopNameCopy.name;
                    
                    popsList += '<li><a href="#">' + popName + '<span class=value>' + idPopName + '</span></a></li>';
		}
            }
	}
	
	return popsList;
    },


    getSelectionPopTraits: function(modelId, selectedPopId) {

	if (modelId === selectedPopId) {selectedPopId=undefined;}

	var trainingTraitsIds = jQuery('#training_traits_ids').val();
	if (trainingTraitsIds) {
	    trainingTraitsIds = trainingTraitsIds.split(',');
	}

	var args = {
	    'selection_pop_id': selectedPopId,
	    'training_pop_id': modelId,
	    'training_traits_ids': trainingTraitsIds
	};

	jQuery.ajax({
            type: 'POST',
            dataType: "json",
            url: '/solgs/selection/index/form',
            data: args,
            success: function(res) {
                
		if (res.status == 'success') {
                    var table;
                    var traits = res.traits;
		    
                    if (traits.length > 1) {
			table  = solGS.sIndex.selectionIndexForm(traits);
                    } else {
			var msg = 'There is only one trait with valid GEBV predictions.';
			jQuery("#si_canvas #select_a_population_div").empty(); 
			jQuery("#si_canvas #select_a_population_div_text").empty().append(msg);      
                    }
		    
                    jQuery('#si_canvas #selection_index_form').empty().append(table);
		    
		}                                               
            }
	});
    },


    selectionIndexForm: function(predictedTraits) {   
	
	var trait = '<div>';
	for (var i=0; i < predictedTraits.length; i++) { 
	    trait += '<div class="form-group  class="col-sm-3">'
		+ '<div  class="col-sm-1">'
		+ '<label for="' + predictedTraits[i] + '">' + predictedTraits[i] + '</label>'
		+ '</div>'
		+ '<div  class="col-sm-2">'
		+ '<input class="form-control"  name="' + predictedTraits[i] + '" id="' + predictedTraits[i] + '" type="text" />'
		+ '</div>'
		+ '</div>';       
	}
	
	trait += '<div class="col-sm-12">'
	    + '<input style="margin: 10px 0 10px 0;"' + 
            'class="btn btn-success" type="submit"' + 
            'value="Calculate" name= "rank" id="calculate_si"' + '/>'
	    + '</div>';
	
	trait += '</div>'
        
	return trait;
    },


    calcSelectionIndex: function(params, legend, trainingPopId, selectionPopId) {
	
	if (params) {                      
            jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
            jQuery.blockUI({message: 'Please wait..'});

	    var trainingTraitsIds = jQuery('#training_traits_ids').val();
	    if (trainingTraitsIds) {
		trainingTraitsIds = trainingTraitsIds.split(',');
	    }

	    if (trainingPopId == selectionPopId) { selectionPopId = "";}

	    var siArgs = {
		'training_pop_id': trainingPopId,
		'selection_pop_id': selectionPopId,
		'rel_wts': params,
		'training_traits_ids': trainingTraitsIds
	    };
	    
            jQuery.ajax({
		type: 'POST',
		dataType: "json",
		data: siArgs,
		url: '/solgs/calculate/selection/index/',
		success: function(res){                       
                    var table;                 
                    if (res.status == 'success' ) {
					
			var genos = res.top_10_genotypes;
			var indexFile = res.index_file;
			
			table = '<br /><table class="table table-condensed">';
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
		
			table += res.download_link; 
			table += ' <strong>| Index Name:</strong> ' + res.sindex_name;
			table += legend;
                    } else {
			table = res.status + ' Ranking the genotypes failed..Please report the problem.';
                    }
                 
                    jQuery('#si_canvas #si_top_genotypes').append(table).show();
		                     
		    var popType = jQuery("#si_canvas #selected_population_type").val();
		    var popId   = jQuery("#si_canvas #selected_population_id").val();
                    formatGenCorInputData(popId, popType, indexFile);

		    jQuery('#si_canvas #selected_pop').val('');
		   
		    solGS.sIndex.saveIndexedPops([popId, res.sindex_name]);
		    solGS.cluster.listClusterPopulations();
		},
		error: function(res){
                    alert('error occured calculating selection index.');
                    jQuery.unblockUI(); 
		}
            });
	}           
    },
    

    validateRelativeWts: function(nm, val) {    
	
	if (isNaN(val) && nm != 'all') {
            alert('the relative weight of trait ' + nm + ' must be a number.');            
            return;
	} else if (!val && nm != 'all') {
            alert('You need to assign a relative weight to trait ' + nm + '.' 
		  + ' If you want to exclude the trait assign 0 to it.');            
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
	
    },


     sumElements: function(elements) {
	 var sum = 0;
	 for (var i=0; i<elements.length; i++) {            
             if (!isNaN(elements[i])) {
		 sum = parseFloat(sum) +  parseFloat(elements[i]);
             }
	 }
	 
	 return sum;
     },

    
    selectionIndex: function(trainingPopId, selectionPopId) {    
       
	var legendValues = this.legendParams();
	
	var legend   = legendValues.legend;
	var params   = legendValues.params;
	var validate = legendValues.validate;
	
	if (params && validate) {
            this.calcSelectionIndex(params, legend, trainingPopId, selectionPopId);
	}
	
    },


    legendParams: function() {
    
	var selectedPopName   = jQuery("#si_canvas #selected_population_name").val();
	
	if (!selectedPopName) {
            selectedPopName = jQuery("#si_canvas #default_selected_population_name").val();
	}

	var rel_form = document.getElementById('selection_index_form');
	var all = rel_form.getElementsByTagName('input');

	var params = {};
	var validate;
	var allValues = [];
	
	var trRelWts= '<b>Relative weights</b>:';

	for (var i = 0; i < all.length; i++) {         
            var nm = all[i].name;
            var val = all[i].value;
	 
            if (val != 'Calculate')  {
		if (nm != 'prediction_pop_name') {
                    
                    allValues.push(val);
                    validate = this.validateRelativeWts(nm, val);
		    
                    if (validate) {
			params[nm] = val;
			trRelWts += '<b> ' + nm + '</b>' + ': '+ val;
                    }
		}
            }            
	}

	params = JSON.stringify(params);
	var sum = this.sumElements(allValues);
	validate = this.validateRelativeWts('all', sum);
        
	for (var i=0;  i<allValues.length; i++)  {
	    // (isNaN(allValues[i]) || allValues[i] < 0) 
            if (isNaN(allValues[i])) { 
		params = undefined;
            }
	}
        var legend;
	if (selectedPopName) {
	    var popName = '<strong>Population name:</strong> ' + selectedPopName;
	    var divId = selectedPopName.replace(/\s/g, "");
	    legend = '<div id="si_legend_"' + divId + '">'
		+ popName + ' <strong>|</strong> ' +  trRelWts
		+ '</div>';           
	}      

	return {
	    'legend' : legend, 
	    'params': params, 
	    'validate' : validate
        };
	
    },


    getListTypeSelPopulations: function()  {
    
	var listTypeSelPopsDiv   = document.getElementById("list_type_selection_populations");
	var listTypeSelPopsTable = listTypeSelPopsDiv.getElementsByTagName("table");
	var listTypeSelPopsRows  = listTypeSelPopsTable[0].rows;
	var predictedListTypePops = [];
	
	var popsList ='';
	for (var i = 1; i < listTypeSelPopsRows.length; i++) {
            var row    = listTypeSelPopsRows[i];
            var popRow = row.innerHTML;
            
            predictedListTypePops = popRow.match(/\/solgs\/selection\//g);
	    
            if (predictedListTypePops) {
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
	
    },


    getTrainingPopulationData: function() {

	var modelId   = jQuery("#si_canvas #model_id").val();
	var modelName = jQuery("#si_canvas #model_name").val();

	return {
	    'id' : modelId,
	    'name' : modelName,
	    'pop_type': 'training'
	};
	
    },


/////
}
////


solGS.sIndex.indexed = [];

jQuery(document).ready( function() {
    
    setTimeout(function (){
	solGS.sIndex.listSelectionIndexPopulations()
    }, 5000);
       
});

jQuery(document).on("click", "#calculate_si", function() {        
    var modelId = jQuery("#si_canvas #model_id").val();
    var selectionPopId = jQuery("#si_canvas #selected_population_id").val();
    var popType = jQuery("#si_canvas #selected_population_type").val();

    solGS.sIndex.selectionIndex(modelId, selectionPopId);
});
