

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
    var listMenu = list.listSelect("prediction_genotypes", ["accessions"]);
    var relevant =[]; 	
        
    if (listMenu.match(/option/) != null) {
            
        jQuery("#prediction_genotypes_list").append(listMenu);

        } else {
            
            jQuery("#prediction_genotypes_list").append("<select><option>no lists found</option></select>");
        }
               
    });


jQuery(document).ready( function() { 
        var listId;
        
        jQuery("<option>", {value: '', selected: true}).prependTo("#prediction_genotypes_list_select");
        jQuery("#prediction_genotypes_list_select").change(function() {
           
                listId = jQuery(this).find("option:selected").val();              
             
                if(listId) {
		    var cnt = 1;
                    jQuery("#prediction_genotypes_list_upload").click(function() {
			if(cnt === 1) {		
                            loadGenotypesList(listId);
			}
			cnt = cnt + 1 ;
                    });
                }
            });       
    });


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


function loadGenotypesList(listId) {
     
    var genoList       = getGenotypesList(listId);
    var listName       = genoList.name;
    var list           = genoList.list;
    var modelId        = getModelId();
    var traitId        = getTraitId();
    var selectionPopId = listId;
    
    if ( list.length === 0) {       
        alert('The list is empty. Please select a list with content.' );
    }
    else {  

        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});

        list = JSON.stringify(list);
   
        jQuery.ajax({
                type: 'POST',
                    dataType: 'json',
                    data: {'id': 'uploaded_' + listId, 'name': listName, 'list': list},
                    url: '/solgs/upload/prediction/genotypes/list',
                   
                    success: function(response) {
                   
                    if (response.status == 'success') {
    
                        var uploadedSelPops = jQuery("#uploaded_selection_pops_table").doesExist();
                       
                        if (uploadedSelPops == false) {  
                            
                            uploadedSelPops = getUserUploadedSelPop(listId);                    
                            jQuery("#uploaded_selection_populations").append(uploadedSelPops).show();
                           
                        }
                        else {
                            
                            var url =   '\'/solgs/model/'+ modelId + '/uploaded/prediction/'+ selectionPopId + '\'' ;
                            var listIdArg = '\'' + listId +'\'';
                            var listSource = '\'from_db\'';
                       
                            var popIdName   = {id : 'uploaded_' + listId, name: listName, pop_type: 'list_selection'};
                            popIdName       = JSON.stringify(popIdName);
                            var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';
                            
                            var addRow = '<tr><td>'
                                +'<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' + '<data>'+ hiddenInput + '</data>'
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_prediction_output_' + listId +  '">'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' 
                                + '[ Predict ]'+ '</a>'             
                                + '</td><tr>';

                            var tdId = '#list_prediction_output_' + listId;
                            var addedRow = jQuery(tdId).doesExist();
                           
                            if (addedRow == false) {
                                jQuery("#uploaded_selection_pops_table tr:last").after(addRow);

                            }                          
                        }
                        jQuery.unblockUI();                        
                      
                    } else {
                       
                        alert("Error occured while uploading the list of selection genotypes.");                      
                        jQuery.unblockUI();   
                    }
                     
                },
                    error: function(res) {
                 
                    jQuery.unblockUI();
                    alert("Error occured while uploading the list of selection genotypes.\n\n" + res.responseText);
                }            
            });        
    }
}


jQuery.fn.doesExist = function(){
        return jQuery(this).length > 0;
 };


function getModelId () {
  
    var modelId;
    var modelIdExists = jQuery("#model_id").doesExist();
    var comboPopsIdExists = jQuery("#combo_pops_id").doesExist();
   
    if ( modelIdExists == true ) {        
        modelId = jQuery("#model_id").val();
    }
    else if ( comboPopsIdExists == true ) {      
        modelId = jQuery("#combo_pops_id").val();
    }
  
    return modelId;
}


function getTraitId () {
  
    var traitId;
    var traitIdExists = jQuery("#trait_id").doesExist();

    if ( traitIdExists == true ) {        
        traitId = jQuery("#trait_id").val();
    }
    
    return traitId;
}


function getUserUploadedSelPop (listId) {
   
    var genoList       = getGenotypesList(listId);
    var listName       = genoList.name;
    var list           = genoList.list;
    var modelId        = getModelId();
    var traitId        = getTraitId();
    var selectionPopId = listId;
   
    var url         =   '\'/solgs/model/'+ modelId + '/uploaded/prediction/'+ selectionPopId + '\'' ;
    var listIdArg   = '\'' + listId +'\'';
    var listSource  = '\'from_db\'';
    var popIdName   = {'id' : 'uploaded_' + listId, 'name' : listName, 'pop_type': 'list_selection'};
    popIdName       = JSON.stringify(popIdName);
    var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';
  
    var uploadedSelPop ='<table id="uploaded_selection_pops_table" style="width:100%;text-align:left"><tr>'
                                + '<th>List-based selection population</th>'
                                + '<th>Predict GEBVs</th>'
                                +'</tr>'
                                + '<tr>'
                                + '<td>'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' + '<data>'+ hiddenInput + '</data>'
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_prediction_output_' + listId +  '">'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' 
                                + '[ Predict ]'+ '</a>'
                                + '</td></tr></table>';

    return uploadedSelPop;
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

