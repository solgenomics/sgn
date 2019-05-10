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
        console.log('dtype: ' + dType)
	
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

		console.log('categories: ' + d.categories[dType[j]])
		console.log('dType[j] '+ dType[j])
		if (d.categories[dType[j]] !== null  && d.categories[dType[j]].length ) {
		    console.log('categories: ' + d.categories[dType[j]])
		    console.log('name: ' + name)
		    if (!dsIds.includes(id)) {

			if (!dType[j].match(/accessions/)) {
			    if (d.categories['accessions'] == ''
				|| d.categories['accessions'] == null)  {
				
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

	if (d.categories['trials'] &&
	    d.categories['plots'] === null) {
	  	    
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


    datasetPlotsTrainingPop: function(datasetId) {
	this.queueDatasetPlotsTrainingPop(datasetId);	
    },

    
    queueDatasetPlotsTrainingPop: function (datasetId) {

	var args = this.createDatasetTrainingReqArgs(datasetId);
	var modelId = args.training_pop_id;
      	
	var hostName = window.location.protocol + '//' + window.location.host;    
	var page     = hostName + '/solgs/population/' + modelId;

	solGS.waitPage(page, args);

    },


    createDatasetTrainingReqArgs: function (datasetId) {

	var dataset = new CXGN.Dataset();
	var d = dataset.getDataset(datasetId);

	var popId     = 'dataset_' + datasetId;
	var popType = 'dataset_training';

	var args = {
	    //'dataset_name'    : datasetName,
	    'dataset_id'      : datasetId,
	    'analysis_type'   : 'population download',
	    'data_set_type'   : 'single population',
            'training_pop_id' : popId,
	    'population_type' : popType,
	};  

	return args;


    }

    

/////
}
/////
