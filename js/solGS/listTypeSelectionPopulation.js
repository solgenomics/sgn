

/**
selection population upload from lists
and files. Run prediction model on uploaded selection population 
and display output.

Isaak Y Tecle 
iyt2@cornell.edu
*/

JSAN.use("CXGN.List");
JSAN.use("jquery.blockUI");


jQuery(document).ready( function() {
    var list = new CXGN.List();
    var listMenu = list.listSelect("list_type_selection_pops", ["accessions"]);
    var relevant =[]; 	
        
    if (listMenu.match(/option/) != null) {
            
        jQuery("#list_type_selection_pops_list").append(listMenu);
	checkPredictedListSelection();

        } else {
            
            jQuery("#list_type_selection_pops_list").append("<select><option>no lists found</option></select>");
        }
               
    });




jQuery(document).ready( function() { 
    var listId;
        
    jQuery("<option>", {value: '', selected: true})
	.prependTo("#list_type_selection_pops_list_select");
      
    jQuery("#list_type_selection_pops_list_select").change(function() {
           
        listId = jQuery(this).find("option:selected").val(); 
       
        var listDetail = getListTypeSelectionPopDetail(listId);

        if (listId) {
	
	    jQuery("#list_type_selection_pop_load").click(function() {
		    
		if (listDetail.type.match(/accessions/)) {
		    
		    askSelectionJobQueueing(listId);
		} else {
			//TO-DO
		//	var trialsList = listDetail.list;
		//	var trialsNames = listDetail.elementsNames;
			
		//	loadTrialListTypeSelectionPop(trialsNames);		    
		}
            });
        }
    });       
});


function checkPredictedListSelection () {
   
    jQuery('select#list_type_selection_pops_list_select option')
	.each(function(idx, val) {
	   
	    var listId = jQuery(val).val();	  
	    var args =  createSelectionReqArgs(listId);

	    args = JSON.stringify(args);
	    
	    jQuery.ajax({
		type: 'POST',
		dataType: 'json',
		data: {'arguments': args},
		url: '/solgs/check/predicted/list/selection',                   
		success: function(response) { 
		    args = JSON.parse(args);
		  
		    if (response.output) {		    
			displayPredictedListTypeSelectionPops(args, response.output); 
			
			if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
			    listSelectionIndexPopulations();
			    listGenCorPopulations();
			}			
		    }
		}
	    });
	});    
}


function getSelectionListElementsNames (list) {
   
    var names = [];
    for (var i = 0; i < list.length; i++) {
	names.push(list[i][1]);
    }

    return names;

}


function getListTypeSelectionPopDetail(listId) {   
    
    var list = new CXGN.List();
    
    var listData;
    var listType;
    var listName;
    var listElements;
    var listElementsNames;

    if (listId) {
        listData      = list.getListData(listId);
	listType      = list.getListType(listId);
	listName      = list.listNameById(listId);
	listElements  = listData.elements;

	listElementsNames = getSelectionListElementsNames(listElements);
    }
  
    return {'name'          : listName,
            'list'          : listElements,
	    'type'          : listType,
	    'elementsNames' : listElementsNames,
           };
}


function askSelectionJobQueueing (listId) {
 
    var args = createSelectionReqArgs(listId);
    var modelId = args.training_pop_id;
    var selectionPopId = args.selection_pop_id;
      
    var hostName = window.location.protocol + '//' + window.location.host;    
    var page     = hostName + '/solgs/model/' + modelId + '/prediction/' + selectionPopId;

    solGS.waitPage(page, args);

}


function createSelectionReqArgs (listId) {

    var genoList  = getListTypeSelectionPopDetail(listId);
    var listName  = genoList.name;
    var list      = genoList.list;
    var modelId   = getModelId();
    var traitId   = getTraitId();
    
    var dataSetType = trainingDataSetType();
   
    var popType = 'uploaded_prediction';
   
    var selectionPopId = 'uploaded_' + listId;
    
    var args = {
	'list_name'        : listName,
	'list'             : list,
	'list_id'          : listId,
	'analysis_type'    : 'selection prediction',
	'data_set_type'    : dataSetType,
	'trait_id'         : traitId,
	'training_pop_id'  : modelId, 
	'selection_pop_id' : selectionPopId, 
	'population_type'  : popType,
    };  

    return args;

}


function getGenotypesList(listId) {
    
    var list = new CXGN.List();
    var genotypesList;
    
    if (! listId == "") {
        genotypesList = list.getListData(listId);
    }

    var listName = list.listNameById(listId);
    var listType;// = list.getListType(listId);

    return {'name'      : listName,
            'list'      : genotypesList.elements,
            'list_type' : listType,
            };
}


function loadGenotypesListTypeSelectionPop(args) {     
  
    //var args  = createSelectionReqArgs(listId);
    var len   = args.list.length;
    //var popId = args.selection_pop_id;
   
    if (window.Prototype) {
	delete Array.prototype.toJSON;
    }
    
    args = JSON.stringify(args);

    if (len === 0) {       
        alert('The list is empty. Please select a list with content.' );
    }
    else { 
	//jQuery(document).ajaxStart(jQuery.blockUI).ajaxStop(jQuery.unblockUI);
	jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
	jQuery.blockUI({message: 'Please wait..'});
       
        jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'arguments': args},
            url: '/solgs/load/genotypes/list/selection',                   
            success: function(response) {
                   
                if (response.status == 'success') {
		    args = JSON.parse(args);
		    var modelId  = args.training_pop_id;
		    var traitId  = args.trait_id;
		    var selPopId = args.selection_pop_id;
		    var listId   = args.list_id
		  
		    if (window.location.href.match(/solgs\/trait\//)) {
			window.location = "/solgs/selection/" + selPopId + '/model/' + modelId + '/trait/' + traitId;
			jQuery.unblockUI(); 
		    } else if (window.location.href.match(/solgs\/model\/combined\/populations\//)) {
			window.location = "/solgs/selection/" + selPopId + '/model/combined/' + modelId + '/trait/' + traitId;
			jQuery.unblockUI(); 	
		    } else {
			displayPredictedListTypeSelectionPops(args, response.output);
			listSelectionIndexPopulations();
			listGenCorPopulations();    
			jQuery.unblockUI(); 
		    }
		                                            
                } else {                                    
                    alert("fail: Error occured while querying for the genotype data of the accessions.");
                    jQuery.unblockUI();   
                }                     
            },
            error: function(res) {
                alert("Error occured while querying for the genotype data of the accessions.");
                jQuery.unblockUI();   
            }            
        });        
    }
}



function predictGenotypesListSelectionPop (args) {
   
    //jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    //jQuery.blockUI({message: 'Please wait..'});

    var modelId  = args.training_pop_id;
    var traitId  = args.trait_id;
    var selPopId = args.selection_pop_id;

    var url = '/solgs/model/' + modelId + '/uploaded/prediction/' + selPopId; 
    
    jQuery.ajax({
	dataType: 'json',
	type    : 'POST',
 	data    : {'trait_id': traitId, 'list_source': 'from_db', 'uploaded_prediction': 1},
	url     : url,
	success : function (res) {
	    if (res.status == 'success') {
		window.location = "/solgs/selection/" + selPopId + '/model/' + modelId + '/trait/' + traitId; 
	    } else {
		// alert('else')
		window.location = window.location.href;
	    }
	}							
    });

    jQuery.unblockUI();    
}





// function loadGenotypesList(listId) {
     
//     var genoList       = getGenotypesList(listId);
//     var listName       = genoList.name;
//     var list           = genoList.list;
//     var modelId        = getModelId();
//     var traitId        = getTraitId();
//     var selectionPopId = listId;

//     var args  = createSelectionReqArgs(listId);
//      if (window.Prototype) {
// 	delete Array.prototype.toJSON;
//     }
    
//     args = JSON.stringify(args);

//     if ( list.length === 0) {       
//         alert('The list is empty. Please select a list with content.' );
//     }
//     else {  

//         jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
//         jQuery.blockUI({message: 'Please wait..'});

//         jQuery.ajax({
//             type: 'POST',
//             dataType: 'json',
//             data: {'arguments': args},
//             url: '/solgs/load/genotypes/list/selection',
                   
//             success: function(response) {
                   
//                 if (response.status == 'success') {
    
//                     var predictedListTypeSelectionPops = jQuery("#uploaded_selection_pops_table").doesExist();
                       
//                     if (predictedListTypeSelectionPops == false) {  
                            
// 			predictedListTypeSelectionPops = displayPredictedListTypeSelectionPops(listId); 
//                         jQuery("#uploaded_selection_populations").append(predictedListTypeSelectionPops).show();
                           
//                     }
//                     else {
                            
//                         var url =   '\'/solgs/model/'+ modelId + '/uploaded/prediction/'+ selectionPopId + '\'' ;
//                         var listIdArg = '\'' + listId +'\'';
//                         var listSource = '\'from_db\'';
			
//                         var popIdName   = {id : 'uploaded_' + listId, name: listName, pop_type: 'list_selection'};
//                         popIdName       = JSON.stringify(popIdName);
//                         var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';
                        
//                         var addRow = '<tr><td>'
//                             +'<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
//                             + listIdArg + ',' + listSource + '); return false;">' + '<data>'+ hiddenInput + '</data>'
//                             + listName + '</a>'
//                             + '</td>'
//                             + '<td id="list_prediction_output_' + listId +  '">'
//                             + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
//                             + listIdArg + ',' + listSource + '); return false;">' 
//                             + '[ Predict ]'+ '</a>'             
//                             + '</td><tr>';

//                         var tdId = '#list_prediction_output_' + listId;
//                         var addedRow = jQuery(tdId).doesExist();
                        
//                         if (addedRow == false) {
//                             jQuery("#uploaded_selection_pops_table tr:last").after(addRow);

//                         }                          
//                         }
//                     jQuery.unblockUI();                        
                      
//                 } else {
                       
//                     alert("Error occured while uploading the list of selection genotypes.");                      
//                     jQuery.unblockUI();   
//                 }
                     
//             },
//                     error: function(res) {
                 
//                     jQuery.unblockUI();
//                     alert("Error occured while uploading the list of selection genotypes.\n\n" + res.responseText);
//                 }            
//             });        
//     }
// }


jQuery.fn.doesExist = function(){
        return jQuery(this).length > 0;
 };


function getModelId () {
  
    var modelId;
    var modelIdExists = jQuery("#model_id").doesExist();
    var comboPopsIdExists = jQuery("#combo_pops_id").doesExist();
    var popIdExists = jQuery("#population_id").doesExist();

    if (jQuery("#model_id").val()) {   
        modelId = jQuery("#model_id").val();
    }
    else if (jQuery("#population_id").val()) {
	modelId = jQuery("#population_id").val();
    }
    else if (jQuery("#combo_pops_id").val() ) { 
        modelId = jQuery("#combo_pops_id").val();
    }
  
    return modelId;
}


function trainingDataSetType () {
  
    var dataSetType;
    var referer = document.URL;
   
    if ( referer.match(/\/combined\//) ) {      
        dataSetType = 'combined populations';
    } else {        
        dataSetType = 'single population';
    } 

    return dataSetType;
}


function getTraitId () {
  
    var traitId;
    var traitIdExists = jQuery("#trait_id").doesExist();

    if ( traitIdExists == true ) {        
        traitId = jQuery("#trait_id").val();
    }
    
    return traitId;
}


function displayPredictedListTypeSelectionPops(args, output) {
   
    //var genoList       = getGenotypesList(listId);
    //args = JSON.parse(args);

    var listName       = args.list_name;
    var listId         = args.list_id;
    var traitId        = args.trait_id;
    var selectionPopId = args.selection_pop_id;
    var trainingPopId  = args.training_pop_id;
   
    var url =   '/solgs/model/'+ trainingPopId + '/prediction/'+ selectionPopId;
    var listIdArg   = '\'' + listId +'\'';
    var listSource  = '\'from_db\'';
    var popIdName   = {'id' : 'uploaded_' + listId, 'name' : listName, 'pop_type': 'list_selection'};
    popIdName       = JSON.stringify(popIdName);
    var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';
 
    var predictedListTypeSelectionPops = jQuery("#uploaded_selection_pops_table").doesExist();
                       
    if ( predictedListTypeSelectionPops == false) {  
                                  
	var predictedListTypeSelectionTable ='<table id="uploaded_selection_pops_table" style="width:100%;text-align:left"><thead><tr>'
            + '<th>List-based selection population</th>'
            + '<th>View GEBVs</th>'
            + '</tr></thead><tbody>'
            + '<tr id="list_prediction_output_' + listId +  '">'
            + '<td>'
            + '<b>' + listName + '</b>'
            + '</td>'
            + '<td><data>'+ hiddenInput + '</data>'               
            + output
            + '</td></tr></tbody></table>';
	
	jQuery("#uploaded_selection_populations").append(predictedListTypeSelectionTable).show();

    } else {
        var listIdArg = '\'' + listId +'\'';
        var listSource = '\'from_db\'';
			
        var popIdName   = {id : 'uploaded_' + listId, name: listName, pop_type: 'list_selection'};
        popIdName       = JSON.stringify(popIdName);
        var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';
        
        var addRow = '<tr id="list_prediction_output_' + listId +  '"><td>'       
	    + '<b>' + listName 
            + '</td>'
            + '<td> <data>'+ hiddenInput + '</data>'               
            + output
            + '</td></tr>';
        
	var trId = '#list_prediction_output_' + listId;
        var samePop = jQuery(trId).doesExist();
        
        if (samePop == false) {
            jQuery("#uploaded_selection_pops_table tr:last").after(addRow);

        } else {
	    jQuery(trId).remove();
	    jQuery("#uploaded_selection_pops_table").append(addRow).show();
	}                          
        
    }

}


function loadPredictionOutput (url, listId, listSource) {
   
    var traitId = getTraitId();
    var modelId = getModelId();
   
    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({message: 'Please wait..'});
   
    jQuery.ajax({
        type: 'POST',
        url: url,
        dataType: 'json',
        data: {
            'uploaded_prediction': 1, 
            'trait_id': traitId, 
            'model_id': modelId, 
            'prediction_id': listId,
            'list_source': listSource,
        },
                
        success: function (response) {
                  
            if (response.status == 'success') {
                    
                var tdId = '#list_prediction_output_' + listId;
                jQuery(tdId).html(response.output);
                                 
                var page = document.URL; 
                    
                if (page.match('/traits/all/population/') != null) {
                    listSelectionIndexPopulations();
                    listGenCorPopulations();                 
                }
                    
                jQuery.unblockUI();        
            }
            else {                
                if(response.status == 'failed') {
                    alert("Error occured while uploading the list of selection genotypes.");
                } else {
                    alert(response.status);  
                }
                  
                jQuery.unblockUI();                 
            }
        },
                
        error: function(response) {
            alert('error: ' + res.responseText);

        }                       
    });
    
}

