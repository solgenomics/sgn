
/**

reference population upload from lists.

Isaak Y Tecle 
iyt2@cornell.edu
*/

JSAN.use("CXGN.List");
JSAN.use("jquery.blockUI");


jQuery(document).ready( function() {
       
        var list = new CXGN.List();
        
    var listMenu = list.listSelect("reference_genotypes", ['plots', 'trials']);
       
	if(listMenu.match(/option/) != null) {
            
            jQuery("#reference_genotypes_list").append(listMenu);

        } else {
            
            jQuery("#reference_genotypes_list").append("<select><option>no lists found</option></select>");
        }
               
    });


jQuery(document).ready( function() { 
       
        var listId;
        
        jQuery("<option>", {value: '', selected: true}).prependTo("#reference_genotypes_list_select");
        
        jQuery("#reference_genotypes_list_select").change(function() {        
                listId = jQuery(this).find("option:selected").val();              
                                
                if(listId) {                
                    jQuery("#reference_genotypes_list_upload").click(function() {
                            //alert('get list: ' + listId);
                            loadReferenceGenotypesList(listId);
                        });
                }
            });       
    });


function getReferenceGenotypesList(listId) {   
    
    var list = new CXGN.List();
    var genotypesList;
    
    if (! listId == "") {
        genotypesList = list.getListData(listId);
    }

    var listName = list.listNameById(listId);
 
    return {'name'      : listName,
            'list'      : genotypesList.elements,
            };
}


function loadReferenceGenotypesList(listId) {     
    
    var genoList       = getReferenceGenotypesList(listId);
    var listName       = genoList.name;
    var list           = genoList.list;
    var modelId        = getModelId(listId);

    var populationType = 'uploaded_reference';

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
                    data: {'model_id': modelId, 'list_name': listName, 'list': list, 'population_type': populationType},
                    url: '/solgs/upload/reference/genotypes/list',
                   
                    success: function(response) {
                   
                    if (response.status == 'success') {
    
                        var uploadedRefPops = jQuery("#uploaded_reference_pops_table").doesExist();
                       
                        if (uploadedRefPops == false) {  
                            
                            uploadedRefPops = getUserUploadedRefPop(listId);                    
                            jQuery("#uploaded_reference_populations").append(uploadedRefPops).show();
                           
                        }
                        else {
                            
                            var url =   '\'/solgs/population/'+ modelId + '\'';
                            var listIdArg = '\'' + listId +'\'';
                            var listSource = '\'from_db\'';
                       
                            var popIdName   = {model_id : modelId, name: listName,};
                            popIdName       = JSON.stringify(popIdName);
                            var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';
                            
                            var addRow = '<tr><td>'
                                + '<a href="/solgs/population/' + modelId + '\"  onclick="javascript:loadPopulationPage(' + url + ',' 
                                + listIdArg + ',' + listSource + ')">' + '<data>'+ hiddenInput + '</data>'
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_reference_page_' + modelId +  '">'
                                + '<a href="/solgs/population/' + modelId + '\" onclick="javascript:loadPopulationPage(' + url + ',' 
                                + listIdArg + ',' + listSource + ')">' 
                                + '[ Build Model ]'+ '</a>'          
                                + '</td><tr>';
                            // alert(addRow);
                            var tdId = '#list_reference_page_' + modelId;
                            var addedRow = jQuery(tdId).doesExist();
                            // alert(addedRow);
                            if (addedRow == false) {
                                jQuery("#uploaded_reference_pops_table tr:last").after(addRow);

                            }                          
                        }
                        jQuery.unblockUI();                        
                      
                    } else {
                                    
                        alert("fail: Error occured while uploading the list of reference genotypes.");
                        jQuery.unblockUI();   
                    }
                     
                },
                    error: function(res) {
                    alert("Error occured while uploading the list of reference genotypes.");
                    jQuery.unblockUI();   
                }            
            });        
    }
}


jQuery.fn.doesExist = function(){
        return jQuery(this).length > 0;
 };



function getUserUploadedRefPop (listId) {
   
    var genoList       = getReferenceGenotypesList(listId);
    var listName       = genoList.name;
    var list           = genoList.list;
    var modelId        = getModelId(listId);
  
    var url         =   '\'/solgs/population/'+ modelId + '\'';
    var listIdArg   = '\'' + listId +'\'';
    var listSource  = '\'from_db\'';
    var popIdName   = {id : modelId, name: listName,};
    popIdName       = JSON.stringify(popIdName);
    var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';

    var uploadedSelPop ='<table id="uploaded_reference_pops_table" style="width:100%; text-align:left"><tr>'
                                + '<th>List-based training population</th>'
                                + '<th>Build model</th>'
                                +'</tr>'
                                + '<tr>'
                                + '<td>'
                                + '<a href="/solgs/population/' + modelId + '\" onclick="javascript:loadPopulationPage(' + url + ',' 
                                + listIdArg + ',' + listSource + ')">' + '<data>'+ hiddenInput + '</data>'
                                + listName + '</a>'
                                + '</td>'
                                + '<td id="list_reference_page_' + modelId +  '">'
                                + '<a href="/solgs/population/' + modelId + '\" onclick="javascript:loadPopulationPage(' + url + ',' 
                                + listIdArg + ',' + listSource + ')">' 
                                + '[ Build model ]'+ '</a>'
                                + '</td></tr></table>';

    return uploadedSelPop;
}


function loadPopulationPage (url, listId, listSource) {   
    
    // var traitId        = getTraitId();
    var genoList       = getReferenceGenotypesList(listId);
    var listName       = genoList.name;
    var modelId        = getModelId(listId);
     
    //alert('loadPopulationPage: url ' + url);
    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({message: 'Please wait..'});
   
    jQuery.ajax({
            type: 'POST',
                url: url,
                dataType: 'json',
                data: {
                       'uploaded_reference': 1, 
                       'model_id': modelId, 
                       'list_source': listSource,
                       'list_name'  : listName,
                      },

                success: function (response) {
               
                if (response.status == 'success') {
                                 
                    jQuery.unblockUI();
                 
                }
                else {                
                    alert('Fail: Error occured calculating GEBVs for the list of selection genotypes.');
                    jQuery.unblockUI();
                }
            },
                error: function(response) {
                alert('error: ' + res.responseText);

            }                       
        });
    
}


function getModelId (listId) {
  
    var modelId = 'uploaded_' + listId; 
    return modelId;

}

