
/**

For training populations  from list of plots and trials.

Isaak Y Tecle 
iyt2@cornell.edu
*/

// JSAN.use("CXGN.List");
JSAN.use("jquery.blockUI");

var solGS = solGS || function solGS() {};

solGS.listTypeTrainingPopulation = {

 trainingPopsDiv: "#list_type_training_pops_select_div",
 trainingPopsSelectMenuId: "#list_type_training_pops_select",

getTrainingListElementsNames: function (list) {
   
    var names = [];
    for (var i = 0; i < list.length; i++) {
	names.push(list[i][1]);
    }

    return names;

},

populateTrainingPopsMenu: function  () {
    var list = new CXGN.List();
    var lists = list.getLists([ "plots", "trials"]);
    var trainingPrivatePops = list.convertArrayToJson(lists.private_lists);

    var menuId = this.trainingPopsSelectMenuId;
    var menu = new OptionsMenu(menuId);
    trainingPrivatePops = trainingPrivatePops.flat();
    var menuElem = menu.addOptions(trainingPrivatePops);

    if (lists.public_lists[0]) {
      var trainingPublicLists = list.convertArrayToJson(lists.public_lists);
      menu.addOptionsSeparator("public lists");
      menuElem = menu.addOptions(trainingPublicLists);
    }

    var datasetPops = solGS.dataset.getDatasetPops(["accessions","plots", "trials"]);
    if (datasetPops) {
      menu.addOptionsSeparator("datasets");
      menuElem = menu.addOptions(datasetPops);
    }

    var trainingPopsDiv = this.trainingPopsDiv;
    jQuery(trainingPopsDiv).append(menuElem).show();
  },


getTrainingListElementsIds: function (list) {
   
    var ids = [];
    for (var i = 0; i < list.length; i++) {
	ids.push(list[i][0]);
    }

    return ids;

},


getListTypeTrainingPopDetail: function(listId) {   
    
    var list = new CXGN.List();
    
    var listData;
    var listType;
    var listName;

    if (listId) {
        listData      = list.getListData(listId);
	listType      = list.getListType(listId);
	listName      = list.listNameById(listId);
	listElements  = listData.elements;

	listElementsNames = this.getTrainingListElementsNames(listElements);
	listElementsIds   = this.getTrainingListElementsIds(listElements);
    }
  
    return {'name'          : listName,	    
	    'type'          : listType,
	    'list_id'       : listId,
	    'list_elements_names' : listElementsNames,
	    'list_elements_ids' : listElementsIds,
           };
    
},


loadTrialListTypeTrainingPop: function (trialsNames) {
   
    jQuery.ajax({
        type: 'POST',
        url: '/solgs/get/trial/id/',
        dataType: 'json',
        data: { 'trials_names': trialsNames},
        success: function (res) {
            solGS.combinedTrials.getCombinedPopsId(res.trials_ids);
        },
        error: function(response) {
            alert('Error occured querying for trials ids');
        }                       
    });

},

askTrainingJobQueueing: function (listId) {
 
    var args = this.createTrainingReqArgs(listId);
    var modelId = args.training_pop_id;
    var protocolId = args.genotyping_protocol_id;
    
    var hostName = window.location.protocol + '//' + window.location.host;    
    var page     = hostName + '/solgs/population/' + modelId;

    if (protocolId) {
	page = page + '/gp/' + protocolId;
    }
    
    solGS.waitPage(page, args);

},


createTrainingReqArgs: function (listId) {

    var genoList  = this.getListTypeTrainingPopDetail(listId);
    var listName  = genoList.name;
    var list      = genoList.list;
    var popId     = getModelId(listId);
    var protocolId = jQuery('#genotyping_protocol_id').val();
    var popType = 'list_reference';

    var args = {
	'list_name'       : listName,
	'list_id'         : listId,
	'analysis_type'   : 'training_dataset',
	'data_set_type'   : 'single_population',
        'training_pop_id' : popId,
	'population_type' : popType,
	'genotyping_protocol_id': protocolId
    };  

    return args;

},


loadPlotListTypeTrainingPop: function(listId) {     
  
    var args  = this.createTrainingReqArgs(listId);
    var popId = args.training_pop_id;

    if (window.Prototype) {
	delete Array.prototype.toJSON;
    }
    
    args = JSON.stringify(args);

    if ( args.list.length === 0) {       
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
                    alert("Error occured while querying for the training data.");
                    jQuery.unblockUI();   
                }                     
            },
            error: function(res) {
                alert("Error occured while querying for the training data.");
                jQuery.unblockUI();   
            }            
        });        
    }
},

};




jQuery.fn.doesExist = function(){
        return jQuery(this).length > 0;
 };



function getUserUploadedRefPop (listId) {
 
    var genoList       = this.getListTypeTrainingPopDetail(listId);
    var listName       = genoList.name;
    var list           = genoList.list;
    var modelId        = getModelId(listId);
  
    var url         =   '\'/solgs/population/'+ modelId + '\'';
    var listIdArg   = '\'' + listId +'\'';
    var listSource  = '\'from_db\'';
    var popIdName   = {id : modelId, name: listName,};
    popIdName       = JSON.stringify(popIdName);
    var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';

    var listSelPop ='<table id="list_reference_pops_table" style="width:100%; text-align:left"><tr>'
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

    return listSelPop;
}


function loadPopulationPage (url, listId, listSource) {   
    
    var genoList       = this.getListTypeTrainingPopDetail(listId);
    var listName       = genoList.name;
    var modelId        = getModelId(listId);
     
    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({message: 'Please wait..'});
   
    jQuery.ajax({
            type: 'POST',
                url: url,
                dataType: 'json',
                data: {
                       'list_reference': 1, 
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
  
    var modelId = 'list_' + listId; 
    return modelId;

}

jQuery(document).ready( function() {
    solGS.listTypeTrainingPopulation.populateTrainingPopsMenu();
          
});


jQuery(document).ready( function() {  
    jQuery("#list_type_training_pops_select").change(function() { 
        var selectedPop = jQuery("option:selected", this).data("pop");
        if (selectedPop.id) {  	
            jQuery("#list_type_training_pop_go_btn").click(function() {

                if (typeof selectedPop.data_str === 'undefined' || !selectedPop.data_str.match(/dataset/i)) {
                    var listDetail = solGS.listTypeTrainingPopulation.getListTypeTrainingPopDetail(selectedPop.id);

                    if (listDetail.type.match(/plots/)) {
                        solGS.listTypeTrainingPopulation.askTrainingJobQueueing(selectedPop.id);
                    } else {
                        var trialsList = listDetail.list;
                        var trialsNames = listDetail.list_elements_names;

                        solGS.listTypeTrainingPopulation.loadTrialListTypeTrainingPop(trialsNames);		    
                    }
                    } else {
                        solGS.dataset.datasetTrainingPop(selectedPop.id, selectedPop.name);
                    }
                });
        }	   
    });       
});

