/** 
* K-means cluster analysis and vizualization 
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};

solGS.cluster = {

    checkClusterResult: function() {

	var listId = jQuery('#list_id').val();

	var clusterOpts = solGS.cluster.clusteringOptions('cluster_options');
	var clusterType = clusterOpts.cluster_type;
	var dataType = clusterOpts.data_type;
	
	var popDetails = solGS. getPopulationDetails();
	
	var comboPopsId = jQuery('#combo_pops_id').val();

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
	    data: {'list_id': listId,
		   'combo_pops_id': comboPopsId,
		   'training_pop_id': popDetails.training_pop_id,
		   'selection_pop_id': popDetails.selection_pop_id,
		   'cluster_type': clusterType,
		   'data_type': dataType
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
                   
	}
    },

    selectRowId: function (selectId) {
	
	var rowId = 'cluster_row_select_' + selectId;
	return rowId;
    },

    createClusterTypeSelect: function() {

	var clusterTypeGroup  = '<select class="form-control" id="cluster_type_select">'
	    + '<option value="k-means">K-Means</option>'
	    + '<option value="heirarchical">Heirarchical</option>'	   
	    +  '</select>';

	return clusterTypeGroup;
	
    },

    createDataTypeSelect: function(opts) {
	var dataTypeGroup = '<select class="form-control" id="data_type_select">';

	for (var i=0; i < opts.length; i++) {
	    console.log(opts[i]);
	    dataTypeGroup += '<option value="'
		+ opts[i] + '">'
		+ opts[i]
		+ '</option>';
	}

	console.log(dataTypeGroup)
	  dataTypeGroup +=  '</select>';
	
	return dataTypeGroup;
     },
    
    
    selectRow: function(selectId, dataStructureType) {

	var selectName = this.getSelectName(selectId, dataStructureType);
	var rowId = this.selectRowId(selectId);

	var clusterTypeOpts = this.createClusterTypeSelect();

	var dataTypeOpts;
	var url = document.URL;

	console.log('url '  + url)

	if (url.match(/breeders\/trial\/|cluster\/analysis/)) {
	    dataTypeOpts = ['Genotype', 'Phenotype'];

	} else if (url.match(/solgs\/traits\/all\/population\//)) {
	    dataTypeOpts = ['Genotype', 'GEBV'];
	}
	
	var dataTypeOpts=  this.createDataTypeSelect(dataTypeOpts);

	var kNum = '<input class="form-control" type="text" placeholder="No. of clusters?" id="k_number" />';
	
	var row = '<tr name="' + dataStructureType + '"' + ' id="' + rowId +  '">'
	    + '<td>'
            + '<a href="#"  onclick="solGS.cluster.runCluster('
	    + selectId + ",'" + dataStructureType + "'" + '); return false;">' 
            + selectName + '</a>'
            + '</td>'
	    + '<td>' + dataStructureType + '</td>'
	    + '<td>' + clusterTypeOpts + '</td>'
	    + '<td>' + dataTypeOpts + '</td>'
	    + '<td>' + kNum + '</td>'
            + '<td id="list_cluster_page_' + selectId +  '">'
            + '<a href="#" onclick="solGS.cluster.runCluster('
	    + selectId + ",'" + dataStructureType + "'" + ');return false;">' 
            + '[ Run Cluster ] </a>'                                     
            + '</td>'
	    + '<tr>';
	
	return row;
    },


    createTable: function(tableId) {

	var table ='<table class="table table-striped" id="' + tableId + '">'
	    + '<thead>'
	    + '<tr>'
            + '<th>Name</th>'
            + '<th>Data Structure</th>'
            + '<th>Cluster type</th>'
	    + '<th>Data type</th>'
	    + '<th>No. of  Clusters</th>'
	    + '<th>Run</th>'
            + '</tr>'
            + '</thead></table>';

	return table;
	
    },

    clusterResult: function(clusterArgs) {

	var clusterType = clusterArgs.cluster_type;
	var kNumber     = clusterArgs.k_number;
	var dataType    = clusterArgs.data_type;
	var selectId     = clusterArgs.select_id;
	var dataStructureType = clusterArgs.data_structure_type;
	
	console.log('clusterResult ' + clusterType + ' ' + dataType +  ' k_num ' + kNumber)

	var popDetails  = solGS.getPopulationDetails();

	if(document.URL.match(/solgs\/traits\/all\/population/)) {
	    var popId   = jQuery("#cluster_selected_population_id").val();
	    var popType = jQuery("#cluster_selected_population_type").val();
	    popDetails['training_pop_id'] = popId;
	    
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
	
	if (listId
	    || datasetId
	    || popDetails.training_pop_id
	    || popDetails.selection_pop_id
	    || popDetails.combo_pops_id) {
	 
	    jQuery("#cluster_canvas .multi-spinner-container").show();
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
		   'data_type': dataType,
		   'k_number' : kNumber
		  },
            url: '/cluster/result',
            success: function(res) {
		if (res.result === 'success') {

		    jQuery("#cluster_canvas .multi-spinner-container").hide();
		    var resultName = listName || datasetName;
		    solGS.cluster.plotClusterOutput(res, resultName);
				    
		    jQuery("#cluster_message").empty();
		    if (document.URL.match(/solgs\/traits\/all\/population\//)) {
			 jQuery("#run_cluster").show();
		    } else {
			jQuery("#run_cluster").hide();
		    }

		} else {                
		    jQuery("#cluster_message").html(res.result);
		    jQuery("#cluster_canvas .multi-spinner-container").hide();
		    jQuery("#run_cluster").show();		    
		}
	    },
            error: function(res) {
		alert('res ' + res.responseText)
		jQuery("#cluster_message").html('Error occured running the clustering.');
		jQuery("#cluster_canvas .multi-spinner-container").hide();
		jQuery("#run_cluster").show();
            }  
	});	
    },


    plotClusterOutput: function(res, resultName) {
	
	var plot = '<img  src= "' + res.kcluster_plot + '">';
	console.log(plot)
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

	var reportFile = res.cluster_report;
	var report  = reportFile.split('/').pop();
	
	var reportLink = "<a href=\""
	    + reportFile
	    +  "\" download="
	    + report
	    + ">[Analysis Report]</a>";

	var downloadLinks = ' <strong>Download '
	    + resultName + ' </strong>: '
	    + plotLink + ' | '
	    + clustersLink + ' | '
	    + reportLink;
	
	jQuery('#cluster_plot').prepend('<p>' + downloadLinks + '</p>');
	jQuery('#cluster_plot').prepend(plot);
	
    },

    getClusterPopsTable: function(tableId) {

	var clusterTable  = this.createTable(tableId);
	return clusterTable;
    },

    runCluster: function(selectId, dataStructureType) {
	
	var clusterOpts = solGS.cluster.clusteringOptions(selectId);
	var clusterType = clusterOpts.cluster_type;
	var kNumber     = clusterOpts.k_number;
	var dataType    = clusterOpts.data_type;
	
	console.log(dataType + ' ' + clusterType + ' k= ' + kNumber)

	var clusterArgs = { 'select_id': selectId,
			    'data_structure_type':  dataStructureType,
			    'cluster_type':  clusterType,
			    'data_type': dataType,
			    'k_number':  kNumber	    
	}

	
    	this.clusterResult(clusterArgs);
    },

    registerClusterType: function(selectId, dataStructureType) {
	var analysisRowId = this.selectRowId(selectId);
	var clusterType = jQuery('input[name=analysis_select]:checked', '#' + analysisRowId).val();
	return clusterType;
    },

    clusteringOptions: function(selectId) {

	var url = document.URL;
	if(url.match(/cluster\/analysis/)) {
	    selectId = this.selectRowId(selectId);
	}
	
	var dataType    = jQuery('#'+selectId + ' #data_type_select').val();
	var clusterType = jQuery('#'+selectId + ' #cluster_type_select').val();
	var kNumber     = jQuery('#'+selectId + ' #k_number').val();

	return {'data_type' : dataType,
		'cluster_type': clusterType,
		'k_number': kNumber
	       };
	
    },

    getClusterGenotypesListData: function(listId) {   
	
	var list = new CXGN.List();

	if (listId) {
	   
	    var listName = list.listNameById(listId);
            var listType = list.getListType(listId);
	    
	    return {'name'     : listName,
		    'listType' : listType,
		   };
	} else {
	    return;
	}	
    },


    listClusterPopulations: function()  {
	var modelData = getTrainingPopulationData();
	console.log(modelData.name)
	var trainingPopIdName = JSON.stringify(modelData);
	
	var  popsList =  '<dl id="cluster_selected_population" class="cluster_dropdown">'
            + '<dt> <a href="#"><span>Choose a population</span></a></dt>'
            + '<dd>'
            + '<ul>'
            + '<li>'
            + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
            + '</li>';  
	
	popsList += '</ul></dd></dl>'; 
	
	jQuery("#cluster_select_a_population_div").empty().append(popsList).show();
	
	var dbSelPopsList;
	if (modelData.id.match(/list/) == null) {
            dbSelPopsList = addSelectionPopulations();
	}

	if (dbSelPopsList) {
            jQuery("#cluster_select_a_population_div ul").append(dbSelPopsList); 
	}
	
	var userUploadedSelExists = jQuery("#list_selection_pops_table").doesExist();
	if (userUploadedSelExists == true) {
	    
            var userSelPops = listUploadedSelPopulations();
            if (userSelPops) {

		jQuery("#cluster_select_a_population_div ul").append(userSelPops);  
            }
	}

	jQuery(".cluster_dropdown dt a").click(function() {
            jQuery(".cluster_dropdown dd ul").toggle();
	});
        
	jQuery(".cluster_dropdown dd ul li a").click(function() {
	    
            var text = jQuery(this).html();
            
            jQuery(".cluster_dropdown dt a span").html(text);
            jQuery(".cluster_dropdown dd ul").hide();
            
            var idPopName = jQuery("#cluster_selected_population").find("dt a span.value").html();
            idPopName     = JSON.parse(idPopName);
            modelId       = jQuery("#model_id").val();
            
            selectedPopId   = idPopName.id;
            selectedPopName = idPopName.name;
            selectedPopType = idPopName.pop_type; 
	    
            jQuery("#cluster_selected_population_name").val(selectedPopName);
            jQuery("#cluster_selected_population_id").val(selectedPopId);
            jQuery("#cluster_selected_population_type").val(selectedPopType);
            
	});
        
	jQuery(".cluster_dropdown").bind('click', function(e) {
            var clicked = jQuery(e.target);
            
            if (! clicked.parents().hasClass("cluster_dropdown"))
		jQuery(".cluster_dropdown dd ul").hide();

            e.preventDefault();

	});           
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
                jQuery("#cluster_go_btn").click(function() {		    
		    solGS.cluster.loadClusterGenotypesList(selectId, dataStructureType);
                });
            }
        });

	//checkClusterResult();
    }      
});


// jQuery(document).ready( function() { 
   
//     var url = window.location.pathname;
    
//     var urlMatch = ['solgs\/trait', 
//                     'breeders_toolbox\/trial', 
//                     'breeders\/trial\/', 
//                     'solgs\/selection\/', 
//                     'solgs\/model\/combined\/populations\/'];
       
//     urlMatch = urlMatch.join('|');

//     if (url.match(urlMatch)) {
	
//         solGS.cluster.checkClusterResult();  
//     } 
 
// });


jQuery(document).ready( function() { 

    jQuery("#run_cluster").click(function() {
	var dataStructureType = jQuery('#data_structure_type').val();
	var selectId;

	if (dataStructureType == 'dataset') {
	    selectId = jQuery('#dataset_id').val();
	} else if (dataStructureType == 'list') {
	     selectId = jQuery('#list_id').val();
	}

	var clusterOptsId = 'cluster_options';
	var clusterOpts = solGS.cluster.clusteringOptions(clusterOptsId);
	var clusterType = clusterOpts.cluster_type;
	var kNumber     = clusterOpts.k_number;
	var dataType    =  clusterOpts.data_type;
	
	console.log('multi models page: ' + clusterType + ' dt type ' + dataType)
	console.log('select id: ' + selectId + ' dt str ' + dataStructureType)

	var clusterArgs = { 'select_id': clusterOptsId,
			    'data_structure_type':  dataStructureType,
			    'cluster_type':  clusterType,
			    'data_type': dataType,
			    'k_number':  kNumber
			  };

	
        solGS.cluster.clusterResult(clusterArgs);

    }); 
  
});


jQuery(document).ready( function() { 
    var page = document.URL;
   
    if (page.match(/solgs\/traits\/all\//) != null || 
        page.match(/solgs\/models\/combined\/trials\//) != null) {
	
	setTimeout(function() {solGS.cluster.listClusterPopulations()}, 5000);

	var dataTypeOpts = ['Genotype', 'GEBV'];	
	dataTypeOpts =   solGS.cluster.createDataTypeSelect(dataTypeOpts);
	console.log(dataTypeOpts)
	var clusterTypeOpts =   solGS.cluster.createClusterTypeSelect();

	jQuery(document).ready(checkClusterPop);

	function checkClusterPop() {
	    if(jQuery('#cluster_select_a_population_div').is(':visible')) {
		jQuery('#cluster_options #data_type_opts').html(dataTypeOpts);
		jQuery('#cluster_options #cluster_type_opts').html(clusterTypeOpts);
		jQuery("#cluster_options").show();
	    } else {
		setTimeout(checkClusterPop, 6000);
	    }
	} 
							 
	
    } else if (page.match(/breeders\/trial\//)) {

	var dataTypeOpts = ['Genotype', 'Phenotype'];	
	dataTypeOpts =   solGS.cluster.createDataTypeSelect(dataTypeOpts);
	console.log(dataTypeOpts)
	var clusterTypeOpts =   solGS.cluster.createClusterTypeSelect();

	jQuery('#cluster_options #data_type_opts').html(dataTypeOpts);
	jQuery('#cluster_options #cluster_type_opts').html(clusterTypeOpts);
	jQuery("#cluster_options").show();
	
    }                   
});


