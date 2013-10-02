

/**
selection population upload from lists
and files. Run prediction model on uploaded selection population 
and display output.

Isaak Y Tecle 
iyt2@cornell.edu
*/



JSAN.use("jquery.cookie");
JSAN.use("CXGN.List");
JSAN.use("jquery.blockUI");


jQuery(document).ready( function() {
        var list = new CXGN.List();
        var listMenu = list.listSelect("prediction_genotypes");
	
        jQuery("#prediction_genotypes_list").append(listMenu);
               
    });


jQuery(document).ready( function() { 
        var listId;
        jQuery("#prediction_genotypes_list_select").change(function() {
           
                listId = jQuery(this).find("option:selected").val();              
             
                if(listId) {
                    jQuery("#prediction_genotypes_list_upload").click(function() {
                            //alert('get list: ' + listId);
                            loadGenotypesList(listId);
                        });
                }
            });       
    });


function getGenotypesList(listId) {
    
    var list = new CXGN.List();
    var genotypesList;
    
    if (! listId == "") {
        genotypesList = list.getList(listId);
    }

    var listName = list.listNameById(listId);
   
    return {'name'   : listName,
            'list'   : genotypesList             
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
                    data: {id: listId, 'name': listName, 'list': list},
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
                       
                            var addRow = '<tr><td>'
                                +'<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' 
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_prediction_output_' + listId +  '">'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' 
                                + '[ Predict GEBVs ]'+ '</a>'             
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
   

    var url        =   '\'/solgs/model/'+ modelId + '/uploaded/prediction/'+ selectionPopId + '\'' ;
    var listIdArg  = '\'' + listId +'\'';
    var listSource = '\'from_db\'';
    
    var uploadedSelPop ='<table id="uploaded_selection_pops_table" ""style="width:100%; text-align:left"><tr>'
                                + '<th>Uploaded Selection Population</th>'
                                + '<th>Prediction output</th>'
                                +'</tr>'
                                + '<tr>'
                                + '<td>'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' 
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_prediction_output_' + listId +  '">'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' 
                                + '[ Predict GEBVs ]'+ '</a>'
                                + '</td></tr></table>';

    return uploadedSelPop;
}


function loadPredictionOutput (url, listId, listSource) {
   
    var traitId        = getTraitId();
    var modelId        = getModelId();
   
    alert('loadPredictionOutput listId, listSource, url: ' + listId +" " + listSource + " " + url);
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
                    jQuery.unblockUI();
                }
                else {                
                    alert('Error occured calculating GEBVs for the list of selection genotypes.');
                    jQuery.unblockUI();
                }
            },
                error: function(response) {
                alert('error: ' + res.responseText);

            }                       
        });
    
}


jQuery(function () {
        var url = '/solgs/upload/prediction/genotypes/file';
        jQuery('#fileupload').fileupload({
                url: url,
                    dataType: 'json',
                    done: function (e, data) {
                    jQuery.each(data.result.files, function (index, file) { 
                      
                            getCheckValue(file.name);

                        });
                }
            });
    });



function getCheckValue(fileName) {
   
    jQuery.ajax({
            type: 'POST',
                url: '/solgs/generate/checkvalue',
                dataType: 'json',
                data: {'file_name': fileName},

                success: function (response) {
               
                if (response.status == 'success') {
                    alert('check_value: ' +  response.check_value);
                    var checkValue = response.check_value;
                    jQuery("#check_value").empty();
                    jQuery("#check_value").val(checkValue);
                    // alert('checkvalue :' +  jQuery("#check_value").val());
                    
                    loadListFromFile(fileName, checkValue);
                        
                }              
            }
        });

}


function loadListFromFile(fileName, listId) {
    // alert('loadListFromFile file name: ' + fileName + " " + listId);
    var listName       = fileName;
    var modelId        = getModelId();
    var traitId        = getTraitId();
    var selectionPopId = listId;

    if ( ! fileName ) {       
        alert('The list is empty. Please select a list with content.' );
    }
    else {  

        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});
        
        var uploadedSelPops = jQuery("#uploaded_selection_pops_table").doesExist();
                       
        if (uploadedSelPops == false) {  
                           
            uploadedSelPops = getUserUploadedFile(fileName, listId);                        
            jQuery("#uploaded_selection_populations").append(uploadedSelPops).show();
            jQuery.unblockUI();
        }
        else {
                       
            var url =   '\'/solgs/model/'+ modelId + '/uploaded/prediction/'+ selectionPopId + '\'' ;
            var listIdArg = '\'' + listId +'\'';
            var listSource = '\'from_file \'';

            var addRow = '<tr><td>'
                +'<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                + listIdArg + ',' + listSource + '); return false;">' 
                + listName + '</a>'
                + '</td>'
                + '<td id="list_prediction_output_' + listId +  '">'
                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                + listIdArg + ',' + listSource + '); return false;">' 
                + '[ Predict GEBVs ]'+ '</a>'             
                + '</td><tr>';

            var tdId = '#list_prediction_output_' + listId;
            var addedRow = jQuery(tdId).doesExist();
                           
            if (addedRow == false) {
                jQuery("#uploaded_selection_pops_table tr:last").after(addRow);
                jQuery.unblockUI();
            }                          
        }                      
    }
 
}                  


function getUserUploadedFile (fileName, listId) {

    var listName       = fileName;
    var modelId        = getModelId();
    var traitId        = getTraitId();
    var selectionPopId = listId;
    //alert('getUserUploadedFile selectionPopId :' + selectionPopId);
    var url =   '\'/solgs/model/'+ modelId + '/uploaded/prediction/'+ selectionPopId + '\'' ;
    var listIdArg = '\'' + listId +'\'';
    var listSource = '\'from_file \'';

    var uploadedSelPop ='<table id="uploaded_selection_pops_table" ""style="width:100%; text-align:left"><tr>'
                                + '<th>Uploaded Selection Population</th>'
                                + '<th>Prediction output</th>'
                                +'</tr>'
                                + '<tr>'
                                + '<td>'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' 
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_prediction_output_' + listId +  '">'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + ',' + listSource + '); return false;">' 
                                + '[ Predict GEBVs ]'+ '</a>'
                                + '</td></tr></table>';

    return uploadedSelPop;
}
