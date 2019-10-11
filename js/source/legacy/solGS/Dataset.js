/** 
* adds dataset related objects to the solGS object
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};

solGS.dataset = {

    getDataset: function (id) {
    
	var dataset = new CXGN.Dataset();
	var allDatasets = dataset.getDatasets();
	var data = {};
	
	for (var i =0; i < allDatasets.length; i++) {	    
	    if (allDatasets[i][0] == id) {
		data.name = allDatasets[i][1];
		data.id   = id;
	    }	    
	}

	return data;
    
    },

  
    getDatasetsMenu: function (dType) {
	if (!Array.isArray(dType)) {
	    dType = [dType];
	}
       
	var dataset = new CXGN.Dataset();
	var allDatasets = dataset.getDatasets();
	
	var sp = ' ----------- ';
	var dMenu = '<option disabled>' + sp +  'DATASETS' + sp + '</option>';

	var dsIds = [];

	for (var i=0; i < allDatasets.length; i++) {
    	    var id = allDatasets[i][0];
    	    var name = allDatasets[i][1];
    	    var d = dataset.getDataset(id);

	    for (var j=0; j<dType.length; j++) {

		if (d.categories[dType[j]] !== null  && d.categories[dType[j]].length) {

		    if (!dsIds.includes(id)) {

			if (document.URL.match(/solgs\/search/)) {			  			    
			    var accessions = d.categories['accessions'];
			    if (accessions == null) {
				accessions = '';
			    }
			  
			    if (accessions.length < 1 ) {
				dsIds.push(id);
				dMenu += '<option name="dataset" value=' + id + '>' + name + '</option>';
			    } else {
				console.log('NOT ADDING ' + name)
			    }
			} else {
			    dsIds.push(id);
			    dMenu += '<option name="dataset" value=' + id + '>' + name + '</option>';		    
			} 
		    }       
		}
	    }       
    	}

	return dMenu;
    },


    datasetTrainingPop:  function (datasetId) {

	var dataset = new CXGN.Dataset();
	var d = dataset.getDataset(datasetId);

	var plots = d.categories['plots'];

	if (plots == '') {
	    plots = null;
	}
	
	if (d.categories['trials'] &&
	    plots == null) {
	  	    
	    this.datasetTrialsTrainingPop(datasetId);
	    
	} else if (d.categories['trials'] &&
		   d.categories['plots'])  {

	    this.datasetPlotsTrainingPop(datasetId);
	}
	   
    },


    datasetTrialsTrainingPop: function(datasetId) {
	jQuery.ajax({  
            type: 'POST',
            dataType: "json",
            url: '/solgs/get/dataset/trials',
            data: {'dataset_id': datasetId},
            success: function(res) {
		
		var trialsIds = res.trials_ids;
		var comboPopsId = res.combo_pops_id; 

		if (trialsIds) {
		    var args = {
			'combo_pops_id'   : [ comboPopsId ],
			'combo_pops_list' : trialsIds,
		    };
		    
		    if (trialsIds.length > 1) {
			solGS.combinedTrials.downloadCombinedTrialsTrainingPopData(args);
		    } else {
			solGS.combinedTrials.downloadSingleTrialTrainingPopData(trialsIds[0])
		    }
		} else {
		    Alert('No trials ids were found for this dataset')
		}
	    },
	    error: function(res) {
		Alert('Error Occurred fetching trials ids in the dataset. ' + res.responseText)	
	    }
	});
	
    },


    datasetPlotsTrainingPop: function(datasetId, datasetName) {
	this.queueDatasetPlotsTrainingPop(datasetId, datasetName);	
    },

    
    queueDatasetPlotsTrainingPop: function (datasetId, datasetName) {

	var args = this.createDatasetTrainingReqArgs(datasetId, datasetName);
	var modelId = args.training_pop_id;
      	
	var hostName = window.location.protocol + '//' + window.location.host;    
	var page     = hostName + '/solgs/population/' + modelId;

	solGS.waitPage(page, args);

    },

    createDatasetTrainingReqArgs: function (datasetId, datasetName) {

	var popId     = 'dataset_' + datasetId;
	var popType = 'dataset_training';

	var args = {
	    'dataset_name'    : datasetName,
	    'dataset_id'      : datasetId,
	    'analysis_type'   : 'population download',
	    'data_set_type'   : 'single population',
            'training_pop_id' : popId,
	    'population_type' : popType,
	};  

	return args;


    },

    createDatasetSelectionArgs: function (datasetId, datasetName) {
		
	var trainingPopDetails = solGS.getPopulationDetails();	
	var selectionPopId = 'dataset_' + datasetId;

	var trainingTraitsIds = jQuery('#training_traits_ids').val();
	var traitId   = jQuery("#trait_id").val();

	if (trainingTraitsIds) {
	    trainingTraitsIds = trainingTraitsIds.split(',');
	} else {
	    trainingTraitsIds = [traitId];
	}
	
	var args = {
	    'dataset_id'       : datasetId,
	    'dataset_name'     : datasetName,
	    'trait_id'         : [traitId],
	    'training_pop_id'  :  trainingPopDetails.training_pop_id, 
	    'selection_pop_id' : selectionPopId, 
	    'training_traits_ids' : trainingTraitsIds,
	    'data_set_type'    : trainingPopDetails.data_set_type
	};  
	
	return args;
    },

    checkPredictedDatasetSelection: function (datasetId, datasetName) {
	
	var args =  this.createDatasetSelectionArgs(datasetId, datasetName);
	args = JSON.stringify(args);

	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    data: {'arguments': args},
	    url: '/solgs/check/predicted/dataset/selection',                   
	    success: function(response) {	
		args = JSON.parse(args);
			
		if (response.output) {
		    solGS.dataset.displayPredictedDatasetTypeSelectionPops(args, response.output); 
		    
		    if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
			solGS.sIndex.listSelectionIndexPopulations();
			listGenCorPopulations();
			solGS.geneticGain.ggSelectionPopulations();
			solGS.cluster.listClusterPopulations();
		    } 			
		} else {
		    solGS.dataset.queueDatasetSelectionPredictionJob(datasetId);
		}
	    }
	});
    
    },

    queueDatasetSelectionPredictionJob:  function (datasetId) {
 
	var args = this.createDatasetSelectionArgs(datasetId);
	var modelId = args.training_pop_id;
	var selectionPopId = args.selection_pop_id;
      
	var hostName = window.location.protocol + '//' + window.location.host;    
	var page     = hostName + '/solgs/model/' + modelId + '/prediction/' + selectionPopId;

	solGS.waitPage(page, args);

    },

    
    displayPredictedDatasetTypeSelectionPops: function(args, output) {
   
	var datasetName = args.dataset_name;
	var datasetId   = args.dataset_id;
	
	var traitId        = args.trait_id;
	var selectionPopId = args.selection_pop_id;
	var trainingPopId  = args.training_pop_id;
	
	var url =   '/solgs/model/'+ trainingPopId + '/prediction/'+ selectionPopId;
	var datasetIdArg   = '\'' + datasetId +'\'';
	var listSource  = '\'from_db\'';
	var popIdName   = {'id' : 'dataset_' + datasetId, 'name' : datasetName, 'pop_type': 'dataset_selection'};
	popIdName       = JSON.stringify(popIdName);
	var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';
	
	var predictedListTypeSelectionPops = jQuery("#list_type_selection_pops_table").doesExist();
        
	if ( predictedListTypeSelectionPops == false) {  
            
	    var predictedListTypeSelectionTable ='<table id="list_type_selection_pops_table" class="table"><thead><tr>'
		+ '<th>List-based selection population</th>'
		+ '<th>View GEBVs</th>'
		+ '</tr></thead><tbody>'
		+ '<tr id="list_prediction_output_' + datasetId +  '">'
		+ '<td>'
		+ '<b>' + datasetName + '</b>'
		+ '</td>'
		+ '<td><data>'+ hiddenInput + '</data>'               
		+ output
		+ '</td></tr></tbody></table>';
	    
	    jQuery("#list_type_selection_populations").append(predictedListTypeSelectionTable).show();

	} else {
            var datasetIdArg = '\'' + datasetId +'\'';
            var datasetSource = '\'from_db\'';
	    
            var popIdName   = {id : 'dataset_' + datasetId, name: datasetName, pop_type: 'dataset_selection'};
            popIdName       = JSON.stringify(popIdName);
            var hiddenInput =  '<input type="hidden" value=\'' + popIdName + '\'/>';
            
            var addRow = '<tr id="list_prediction_output_' + datasetId +  '"><td>'       
		+ '<b>' + datasetName 
		+ '</td>'
		+ '<td> <data>'+ hiddenInput + '</data>'               
		+ output
		+ '</td></tr>';
            
	    var trId = '#list_prediction_output_' + datasetId;
            var samePop = jQuery(trId).doesExist();
            
            if (samePop == false) {
		jQuery("#list_type_selection_pops_table tr:last").after(addRow);

            } else {
		jQuery(trId).remove();
		jQuery("#list_type_selection_pops_table").append(addRow).show();
	    }                          
            
	}

   },
 

/////
}
/////
