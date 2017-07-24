
/**

reference population upload from lists.

Isaak Y Tecle 
iyt2@cornell.edu
*/

JSAN.use("CXGN.List");
JSAN.use("jquery.blockUI");


jQuery(document).ready( function() {
       
    var list = new CXGN.List();
        
    var listMenu = list.listSelect("list_type_training_pops", ['plots', 'trials']);
       
    if (listMenu.match(/option/) != null) {           
        jQuery("#list_type_training_pops_list").append(listMenu);
    } else {
        jQuery("#list_type_training_pops_list").append("<select><option>no lists found</option></select>");
    }
               
});


jQuery(document).ready( function() { 
               
    jQuery("<option>", {value: 'select...', selected: true})
	.prependTo("#list_type_training_pops_list_select");
        
    jQuery("#list_type_training_pops_list_select")
	.change(function() { 
        
	    var listId = jQuery(this).find("option:selected").val();                             
            if (listId) {  
		var listDetail = getListTypeTrainingPopDetail(listId);
		jQuery("#list_type_training_pop_load").click(function() {
		    
		    if (listDetail.type.match(/plots/)) {
			askTrainingJobQueueing(listId);
		    } else {
			var trialsList = listDetail.list;
			var trialsNames = listDetail.elementsNames;
			
			loadTrialListTypeTrainingPop(trialsNames);		    
		    }
		});
            }
	});       
});


function getTrainingListElementsNames (list) {
   
    var names = [];
    for (var i = 0; i < list.length; i++) {
	names.push(list[i][1]);
    }

    return names;

}


function getTrainingListElementsIds (list) {
   
    var ids = [];
    for (var i = 0; i < list.length; i++) {
	ids.push(list[i][0]);
    }

    return ids;

}


function getListTypeTrainingPopDetail(listId) {   
    
    var list = new CXGN.List();
    
    var listData;
    var listType;
    var listName;
    var listElements;
    var listElementsNames;
    var listElementsIds;

    if (listId) {
        listData      = list.getListData(listId);
	listType      = list.getListType(listId);
	listName      = list.listNameById(listId);
	listElements  = listData.elements;

	listElementsNames = getTrainingListElementsNames(listElements);
	listElementsIds   = getTrainingListElementsIds(listElements);
    }
  
    return {'name'          : listName,
            'list'          : listElements,	    
	    'type'          : listType,
	    'elementsIds'   : listElementsIds,
	    'elementsNames' : listElementsNames,
           };
}


function loadTrialListTypeTrainingPop (trialsNames) {
   
    jQuery.ajax({
        type: 'POST',
        url: '/solgs/get/trial/id/',
        dataType: 'json',
        data: { 'trials_names': trialsNames},
        success: function (res) { 
            getCombinedPopsId(res.trials_ids);
        },
        error: function(response) {
            alert('Error occured querying for trials ids');
        }                       
    });

}

function askTrainingJobQueueing (listId) {
 
    var args = createTrainingReqArgs(listId);
    var modelId = args.training_pop_id;
      
    var hostName = window.location.protocol + '//' + window.location.host;    
    var page     = hostName + '/solgs/population/' + modelId;

    solGS.waitPage(page, args);

}


function createTrainingReqArgs (listId) {

    var genoList  = getListTypeTrainingPopDetail(listId);
    var listName  = genoList.name;
    var list      = genoList.list;
    var popId     = getModelId(listId);
 
    var popType = 'uploaded_reference';

    var args = {
	'list_name'       : listName,
	'list'            : list,
	'list_id'         : listId,
	'analysis_type'   : 'population download',
	'data_set_type'   : 'single population',
        'training_pop_id' : popId,
	'population_type' : popType,
    };  

    return args;

}


function loadPlotListTypeTrainingPop(listId) {     
  
    var args  = createTrainingReqArgs(listId);
    var len   = args.list.length;
    var popId = args.training_pop_id;

    if (window.Prototype) {
	delete Array.prototype.toJSON;
    }
    
    args = JSON.stringify(args);

    if (len === 0) {       
        alert('The list is empty. Please select a list with content.' );
    }
    else {  
        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});
       
        jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'arguments': args},
            url: '/solgs/load/plots/list/training',                   
            success: function(response) {
                   
                if (response.status == 'success') {
    
                    window.location = '/solgs/population/' + popId;                       
		    jQuery.unblockUI();                        
                      
                } else {                                    
                    alert("fail: Error occured while querying for the training data.");
                    jQuery.unblockUI();   
                }                     
            },
            error: function(res) {
                alert("Error occured while querying for the training data.");
                jQuery.unblockUI();   
            }            
        });        
    }
}


jQuery.fn.doesExist = function(){
        return jQuery(this).length > 0;
 };



function getUserUploadedRefPop (listId) {
   
    var genoList       = getListTypeTrainingPopDetail(listId);
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
                                + '<th>Models</th>'
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
    
    var genoList       = getListTypeTrainingPopDetail(listId);
    var listName       = genoList.name;
    var modelId        = getModelId(listId);
     
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

