/** 
* adds dataset related objects to the solGS object
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

//JSAN('CXGN.Dataset');

var solGS = solGS || function solGS () {};

solGS.getDatasetData = function (id) {
    
    var dataset = new CXGN.Dataset();
    var allDatasets = dataset.getDatasets();
    var data = {};
    
    for (var i =0; i < allDatasets.length; i++) {
	console.log(allDatasets[i][0] + ' ' + allDatasets[i][1]);
	
	if (allDatasets[i][0] == id) {
	    data.name = allDatasets[i][1];
	    data.id   = id;
	}	    
    }

    return data;
    
}

  
solGS.getDatasetsMenu = function (dType) {
    console.log('forming datasets menu')
    console.log(Array.isArray(dType))
    
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
	console.log('name ' + name)
    	var d = dataset.getDataset(id);

	for (var j=0; j<dType.length; j++) {
	    console.log('dtype j ' + dType[j])
	    console.log('d.categories[dType[j]]: ' + d.categories[dType[j]])
	    //d.categories[dType[j]].length
    	    if (d.categories[dType[j]] !== null && d.categories[dType[j]].length ) {

		if (!dsIds.includes(id)) {
		    if (!dType[j].match(/accessions/)) {
			if (d.categories['accessions'] == ''
			    || d.categories['accessions'] == null) {
			  
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
    
}


solGS.datasetTrainingPop = function (datasetId) {
    
    	jQuery.ajax({  
            type: 'POST',
            dataType: "json",
            url: '/solgs/get/dataset/trials',
            data: {'dataset_id': datasetId},
            success: function(res) {
		console.log('success fetching trials ids')
		var trialsIds = res.trials_ids;
		var comboPopsId = res.combo_pops_id; 
		if (trialsIds) {
		    console.log('got dataset trials ids: ' + trialsIds)

		     var args = {
			'combo_pops_id'   : [ comboPopsId ],
			'combo_pops_list' : trialsIds,
		     };
		    if (trialsIds.length > 1) {
			goToCombinedTrialsTrainingPopPage(args);
		    } else {
			goToSingleTrialTrainingPopPage(trialsIds[0])
		    }
		} else {
		    Alert('No trials ids were found for this dataset')
		}
	    },
	    error: function(res) {
		Alert('Error Occurred fetching trials ids in the dataset. ' + res.responseText)	
	    }
	});

    
}
