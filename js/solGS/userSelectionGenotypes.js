

/**
selection population upload from lists
and files. Run prediction model on uploaded selection population 
and display output.

Isaak Y Tecle 
iyt2@cornell.edu
*/



JSAN.use("jquery.cookie");
JSAN.use("CXGN.List");


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

    //alert(list);
    if ( list.length === 0) {       
        alert('The list is empty. Please select a list with content.' );
    }
    else {     
        list = JSON.stringify(list);
   
        jQuery.ajax({
                type: 'POST',
                    dataType: 'json',
                    data: {id: listId, 'name': listName, 'list': list},
                    url: '/solgs/upload/prediction/genotypes/list',
                   
                    success: function(response) {
                    
                    if(response.status == 'success') {
    
                        var uploadedSelPops = jQuery("#uploaded_selection_pops_table").doesExist();
                        cnt++;
                        if (uploadedSelPops == false) {  
                           
                            uploadedSelPops = getUserUploadedSelPop(listId);                        
                            jQuery("#uploaded_selection_populations").append(uploadedSelPops).show();
                           
                        }
                        else {
                       
                            var url =   '\'/solgs/model/'+ modelId + '/uploaded/prediction/'+ selectionPopId + '\'' ;
                            var listIdArg = '\'' + listId +'\'';
                       
                            var addRow = '<tr><td>'
                                +'<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + '); return false;">' 
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_prediction_output_' + listId +  '">'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + '); return false;">' 
                                + '[ Predict GEBVs ]'+ '</a>'             
                                + '</td><tr>';

                            var tdId = '#list_prediction_output_' + listId;
                            var addedRow = jQuery(tdId).doesExist();
                           
                            if (addedRow == false) {
                                jQuery("#uploaded_selection_pops_table tr:last").after(addRow);

                            }                          
                        }
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
    
    var url =   '\'/solgs/model/'+ modelId + '/uploaded/prediction/'+ selectionPopId + '\'' ;
    var listIdArg = '\'' + listId +'\'';
  
    var uploadedSelPop ='<table id="uploaded_selection_pops_table" ""style="width:100%; text-align:left"><tr>'
                                + '<th>Uploaded Selection Population</th>'
                                + '<th>Prediction output</th>'
                                +'</tr>'
                                + '<tr>'
                                + '<td>'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + '); return false;">' 
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_prediction_output_' + listId +  '">'
                                + '<a href="#" onclick="javascript:loadPredictionOutput(' + url + ',' 
                                + listIdArg + '); return false;">' 
                                + '[ Predict GEBVs ]'+ '</a>'
                                + '</td></tr></table>';

    return uploadedSelPop;
}


function loadPredictionOutput (url, listId) {
   
    var traitId        = getTraitId();
    var modelId        = getModelId();
    
    jQuery.ajax({
            type: 'POST',
                url: url,
                dataType: 'json',
                data: {
                       'data_set_type': 'uploaded prediction', 
                       'trait_id': traitId, 
                       'model_id': modelId, 
                       'prediction_id': listId
                      },

                success: function (response) {
                
                if(response.status == 'success') {
                    alert(response.output);
                    var tdId = '#list_prediction_output_' + listId;
                    jQuery(tdId).html(response.output);
                }
                else {                
                    alert('error occured.');
                }
             }
         });
    
}
