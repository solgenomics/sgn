/** 
* adds dataset related objects to the solGS object
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

var solGS = solGS || function solGS () {};

solGS.getDatasetData = function (id) {
    
    var dataset = new CXGN.Dataset();
    var allDatasets = dataset.getDatasets();
    var data = {};
    
    for (var i =0; i <allDatasets.length; i++) {
	console.log(allDatasets[i][0] + ' ' + allDatasets[i][1]);

	var name = allDatasets[i][1];
	if (allDatasets[i][0] == id) {
	    data.name = allDatasets[i][1];
	    data.id   = id;
	}	    
    }

    return data;
    
}

  
solGS.getDatasetsMenu = function (dType) {
    
    var dataset = new CXGN.Dataset();
    var allDatasets = dataset.getDatasets();
    
    var sp = ' ----------- ';
    var dMenu = '<option disabled>' + sp +  'DATASETS' + sp + '</option>';
    
    for (var i =0; i <allDatasets.length; i++) {
	var id = allDatasets[i][0];
	var name = allDatasets[i][1];

	var d = dataset.getDataset(id);
	if (d.categories[dType].length){	  
	    dMenu += '<option name="dataset" value=' + id + '>' + name + '</option>';
	}	   	    
    }

    return dMenu;
    
}
