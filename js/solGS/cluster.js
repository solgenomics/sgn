/** 
* K-means cluster analysis and vizualization 
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};

solGS.cluster = {

    checkClusterResult: function() {

	var listId = jQuery('#list_id').val();
	var clusterType = 'k-means';
	var popDetails = solGS.getPopulationDetails();
	
	var comboPopsId = jQuery('#combo_pops_id').val();
	
	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
	    data: {'list_id': listId,
		   'combo_pops_id': comboPopsId,
		   'training_pop_id': popDetails.training_pop_id,
		   'selection_pop_id': popDetails.selection_pop_id,
		   'cluster_type': clusterType
		  },
            url: '/cluster/check/result/',
            success: function(res) {
		if (res.result) {		   
		    solGS.cluster.plotClusterOutput(res);
				    
		    jQuery("#cluster_message").empty();
		    jQuery("#run_cluster").hide();
		   
		} else { 
		    jQuery("#run_cluster").show();	
		}
	    },
	    
	});
	
    },


    getSelectName: function(selectId, dataStructureType) {
	var selectName;
 	if (dataStructureType == 'list') {
	    var genoList = this.getClusterGenotypesListData(selectId);
	    var selectName = genoList.name;
	    //	dataStructureType = genoList.listType + ' list';
	} else if (dataStructureType == 'dataset') {
	    var dataset = solGS.getDatasetData(selectId);
	    var selectName = dataset.name;
	}

	return selectName;
    },


    loadClusterGenotypesList: function(selectId, dataStructureType) {     
		
	if ( selectId.length === 0) {       
            alert('The list is empty. Please select a list with content.' );
	} else {
	    
	    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
            jQuery.blockUI({message: 'Please wait..'});
	    
            var tableId = "list_cluster_populations_table";
            var clusterTable = jQuery('#' + tableId).doesExist();
            
            if (clusterTable == false) {	
		clusterTable = this.getClusterPopsTable(tableId);	
		jQuery("#list_cluster_populations").append(clusterTable).show();		
            }
	    
	    var addRow = this.selectRow(selectId, dataStructureType);

	    var tdId = '#list_cluster_page_' + selectId;
	    var addedRow = jQuery(tdId).doesExist();
	    
	    if (addedRow == false) {
                jQuery('#' + tableId + ' tr:last').after(addRow);
	    }                          
                   
	    jQuery.unblockUI();                                
	}
    },

    selectRowId: function (selectId) {
	
	var rowId = 'cluster_row_select_' + selectId;
	return rowId;
    },
   
    selectRow: function(selectId, dataStructureType) {

	var selectName = this.getSelectName(selectId, dataStructureType);
	var rowId = this.selectRowId(selectId);

	var kMeans = '<label class="radio-inline"><input  type="radio" name="analysis_select"'
	    + '  id="k_means_select" value="k-means">K-Means</label>';
	
	var hierarchical= '<label class="radio-inline"><input type="radio"  name="analysis_select"'
	    + ' id="heirarchical_select" value="heirarchical">Hierarchical</lable>';

	var formGroup =  '<div class="form-group">' + kMeans + hierarchical + '</div>';
	
	var row = '<tr name="' + dataStructureType + '"' + ' id="' + rowId +  '">'
	    + '<td>'
            + '<a href="#"  onclick="solGS.cluster.runCluster(' + selectId + ",'" + dataStructureType + "'" + '); return false;">' 
            + selectName + '</a>'
            + '</td>'
	    + '<td>' + dataStructureType + '</td>'
	    + '<td>' + formGroup + '</td>'
            + '<td id="list_cluster_page_' + selectId +  '">'
            + '<a href="#" onclick="solGS.cluster.runCluster(' + selectId + ",'" + dataStructureType + "'" + ');return false;">' 
            + '[ Run Cluster ] </a>'                                     
            + '</td><tr>';
	
	return row;
    },


    createTable: function(tableId) {

	var table ='<table class="table" id="' + tableId + '" style="width:100%; text-align:left">'
	    + '<tr>'
            + '<th>Name</th>'
            + '<th>Data Structure</th>'
            + '<th>Cluster type</th>'
	    + '<th>Run</th>'
            + '</tr>'
            + '</table>';

	return table;
	
    },

    clusterResult: function(selectId, dataStructureType, clusterType) {
	var popDetails  = solGS.getPopulationDetails();

	if (clusterType === 'undefined') {
	    clusterType = 'k-means';
	}
		
	var listName;
	var listType;
	var listId;

	var datasetId;
	var datasetName;
	var dataStructure = dataStructureType;
	
	if (dataStructureType == 'list') {
	    var genoList = this.getClusterGenotypesListData(selectId);
	    listName = genoList.name;
	    listType = genoList.listType;
	    listId   = selectId;
	   
	    popDetails['training_pop_id'] = 'list_' + listId;
	
	} else if (dataStructureType == 'dataset') {
	    datasetId = selectId;
	    popDetails['training_pop_id'] = 'dataset_' + datasetId;
	    var dataset = solGS.getDatasetData(selectId);
	    datasetName = dataset.name;
	}
	
	if (listId || datasetId || popDetails.training_pop_id || popDetails.selection_pop_id) {
	    jQuery("#cluster_message").html("Running K-means clustering... please wait...");
	    jQuery("#run_cluster").hide();
	}  

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'training_pop_id': popDetails.training_pop_id,
		   'selection_pop_id': popDetails.selection_pop_id,
		   'combo_pops_id': popDetails.combo_pops_id,
		   'list_id': listId, 
		   'list_name': listName,
		   'list_type': listType,
		   'cluster_type': clusterType,
		   'data_structure': dataStructure,
		   'dataset_id': datasetId,
		   'dataset_name': datasetName,
		  },
            url: '/cluster/result',
            success: function(res) {
		if (res.status === 'success') {
		    
		    if (res.pop_id) {
			var popId = res.pop_id;
		    }

		    var resultName = listName || datasetName;
		    solGS.cluster.plotClusterOutput(res, resultName);
				    
		    jQuery("#cluster_message").empty();
		    jQuery("#run_cluster").hide();

		} else {                
		    jQuery("#cluster_message").html(res.status);
		    jQuery("#run_cluster").show();
		}
	    },
            error: function(res) {                    
		jQuery("#cluster_message").html('Error occured running the clustering.');
		jQuery("#run_cluser").show();
            }  
	});
	
    },


    plotClusterOutput: function(res, resultName) {

	var plot = '<img src= "' + res.kcluster_plot + '">';
    
	var filePlot  = res.kcluster_plot.split('/').pop();

	var popDetails = solGS.getPopulationDetails();
	resultName = resultName || popDetails.population_name;	
	var plotType = 'K-means plot';
	
	var plotLink = "<a href=\""
	    + res.kcluster_plot
	    +  "\" download="
	    + filePlot + ">["
	    + plotType +  "]</a>";

	var plotId;
	if(resultName != undefined) {
	     plotId = resultName.replace(/\s/g, '_');
	} else {
	    resultName = '';
	}
	
	var clustersFile = res.clusters;
	var fileClusters  = clustersFile.split('/').pop();
		    
	var clustersLink = "<a href=\""
	    + clustersFile
	    +  "\" download="
	    + fileClusters
	    + ">[Clusters]</a>";

	jQuery('#cluster_plot').append(plot
				       + ' <strong>Download '
				       + resultName + ' </strong>: '
				       + plotLink + ' | '
				       + clustersLink);
	
    },

    getClusterPopsTable: function(tableId) {

	var clusterTable  = this.createTable(tableId);
	return clusterTable;
    },

    runCluster: function(selectId, dataStructureType) {
	//	this.setListId(selectId, dataStructureType);
	var clusterType = this.registerClusterType(selectId, dataStructureType);	
    	this.clusterResult(selectId, dataStructureType, clusterType);		
    },

    registerClusterType: function(selectId, dataStructureType) {
	var analysisRowId = this.selectRowId(selectId);
	var clusterType = jQuery('input[name=analysis_select]:checked', '#' + analysisRowId).val();
	return clusterType;
    },

    getClusterGenotypesListData: function(listId) {   
	
	var list = new CXGN.List();
	console.log('list data  id: ' + listId)
	if (listId) {
	    console.log('list data  id: ' + listId)
	    var listName = list.listNameById(listId);
            var listType = list.getListType(listId);
	    
	    return {'name'     : listName,
		    'listType' : listType,
		   };
	} else {
	    return;
	}	
    },


    plotKCluster: function(plotData){

    },

}


jQuery.fn.doesExist = function(){

        return jQuery(this).length > 0;

 };

    

jQuery(document).ready( function() {
    
    var url = window.location.pathname;
    console.log('url: ' + url)
    if (url.match(/cluster\/analysis/)) {
    
        var list = new CXGN.List();
        
        var listMenu = list.listSelect("cluster_genotypes", ['accessions', 'trials']);

	var dType = ['accessions', 'trials'];
	var dMenu = solGS.getDatasetsMenu(dType);
	
	if (listMenu.match(/option/) != null) {         
            jQuery("#cluster_genotypes_list").append(listMenu);
	    jQuery("#cluster_genotypes_list_select").append(dMenu);
	    
        } else {            
            jQuery("#cluster_genotypes_list").append("<select><option>no lists found - Log in</option></select>");
        }
    }
               
});


jQuery(document).ready( function() { 
     
    var url = window.location.pathname;
    
    if (url.match(/cluster\/analysis/)) {  
        
        jQuery("<option>", {value: '', selected: true}).prependTo("#cluster_genotypes_list_select");
     
        jQuery("#cluster_genotypes_list_select").change(function() {        
            var selectId = jQuery(this).find("option:selected").val();
            var dataStructureType  = jQuery(this).find("option:selected").attr('name');

	    if (typeof dataStructureType == 'undefined') {
		dataStructureType = 'list';
	    }
	    
            if (selectId) {                
                jQuery(".go_btn").click(function() {		    
		    solGS.cluster.loadClusterGenotypesList(selectId, dataStructureType);
                });
            }
        });

	//checkClusterResult();
    }      
});


jQuery(document).ready( function() { 
   
    var url = window.location.pathname;

    if (url.match(/solgs\/trait|breeders_toolbox\/trial|breeders\/trial\/|solgs\/selection\//)) {
       solGS.cluster.checkClusterResult();  
    } 
 
});


jQuery(document).ready( function() { 

    jQuery("#run_cluster").click(function() {
        solGS.cluster.clusterResult();
    }); 
  
});
