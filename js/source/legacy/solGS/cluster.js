/**
* K-means cluster analysis and vizualization
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};

solGS.cluster = {

    getClusterArgsFromUrl: function() {

     var page = location.pathname;
     if (page == '/cluster/analysis/') {
         page = '/cluster/analysis';
     }

     var urlArgs = page.replace("/cluster/analysis", "")

     var clusterPopId;
     var traitId;
     var protocolId;
     var kNumber;
     var dataType;
     var sIndexName;
     var selectionProp;
     var traitsCode;

     if (urlArgs) {
          var args = urlArgs.split(/\/+/);

         clusterPopId = args[1];
         dataType = args[3];
         kNumber = args[5];

         if (urlArgs.match(/traits/)) {
            traitsCode = args[7];
        }

        if (urlArgs.match(/selPop/)) {
            selectionProp = args[9];
         }

         protocolId = args.pop();

         if (!dataType.match(/phenotype|genotype|gebv/)) {
             sIndexName = dataType;
             dataType = 'genotype';
         }

         var dataStr;
         var listId;
         var datasetId;

         if (clusterPopId.match(/dataset/)) {
             dataStr = 'dataset';
             //datasetId = clusterPopId.replace(/dataset_/, '');
        } else if (clusterPopId.match(/list/)) {
            dataStr = 'list';
            //listId = clusterPopId.replace(/list_/, '');
         }

         var args = {
         'cluster_pop_id': clusterPopId,
         'data_type': dataType,
         'k_number': kNumber,
         'sindex_name': sIndexName,
         'selection_proportion': selectionProp,
         'list_id': listId,
         'trait_id': traitId,
         'training_traits_code': traitsCode,
         'dataset_id': datasetId,
         'data_structure': dataStr,
         'genotyping_protocol_id': protocolId,
         'cluster_type': 'k-means'
         };

         var reg = /\.+-\.+/;
         if (clusterPopId.match(reg)) {
             var ids = clusterPopd.split('-');
             args['training_pop_id'] = ids[0];
             args['selection_pop_id'] = ids[1];
         }
         return args;
        } else {
         return {};
        }

    },

    loadClusterGenotypesList: function(selectId, selectName, dataStr) {

	if ( selectId.length === 0) {
            alert('The list is empty. Please select a list with content.' );
	} else {

            var tableId = "list_cluster_populations_table";
            var clusterTable = jQuery('#' + tableId).doesExist();

            if (clusterTable == false) {
		clusterTable = this.getClusterPopsTable(tableId);
		jQuery("#list_cluster_populations").append(clusterTable).show();
            }

	    var addRow = this.selectRow(selectId, selectName, dataStr);
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
	// + '<option value="heirarchical">Heirarchical</option>'
	var clusterTypeGroup  = '<select class="form-control" id="cluster_type_select">'
	    + '<option value="k-means">K-Means</option>'
	    +  '</select>';

	return clusterTypeGroup;

    },

    createDataTypeSelect: function(opts) {
	var dataTypeGroup = '<select class="form-control" id="cluster_data_type_select">';

	for (var i=0; i < opts.length; i++) {

	    dataTypeGroup += '<option value="'
		+ opts[i] + '">'
		+ opts[i]
		+ '</option>';
	}
	  dataTypeGroup +=  '</select>';

	return dataTypeGroup;
     },


    selectRow: function(selectId, selectName, dataStr) {

    	var rowId = this.selectRowId(selectId);
    	var clusterTypeOpts = this.createClusterTypeSelect();

    	var dataTypeOpts;
    	var url = document.URL;
    	var pagesTr = '/breeders/trial/'
    	    + '|cluster/analysis'
    	    + '|solgs/trait/\d+/population\/'
    	    + '|solgs/model/combined/populations/';

    	var pagesMultiModels = '/solgs/traits/all/population/'
    	    + '|solgs/models/combined/trials\/';

    	if (url.match(pagesTr)) {
    	    dataTypeOpts = ['Genotype', 'Phenotype'];
    	} else if (url.match(pagesMultiModels)) {
    	    dataTypeOpts = ['Genotype', 'GEBV', 'Phenotype'];
    	}

    	var dataTypeOpts=  this.createDataTypeSelect(dataTypeOpts);

    	var kNum = '<input class="form-control" type="text" placeholder="No. of clusters?" id="k_number" />';

        var onClickVal =  '<button type="button" id="run_cluster" class="btn btn-success" onclick="solGS.cluster.runCluster('
                + selectId + ",'" + selectName + "'" +  ",'" + dataStr
            + "'" + ')">Run Cluster</button>';

    	var row = '<tr name="' + dataStr + '"' + ' id="' + rowId +  '">'
    	    + '<td>' + selectName + '</td>'
            + '<td>' + dataStr + '</td>'
            + '<td>' + clusterTypeOpts + '</td>'
            + '<td>' + dataTypeOpts + '</td>'
            + '<td>' + kNum + '</td>'
            + '<td id="list_cluster_page_' + selectId +  '">' + onClickVal + '</td>'
    	    + '<tr>';

    	return row;

    },


    createTable: function(tableId) {

    	var table ='<table class="table table-striped" id="' + tableId + '">'
    	    + '<thead>'
    	    + '<tr>'
            + '<th>Name</th>'
            + '<th>Data structure</th>'
            + '<th>Cluster type</th>'
    	    + '<th>Data type</th>'
    	    + '<th>No. of  clusters (K)</th>'
    	    + '<th>Run cluster</th>'
            + '</tr>'
            + '</thead></table>';

    	return table;

    },

    clusterResult: function(clusterArgs) {

	var clusterType = clusterArgs.cluster_type;
	var kNumber     = clusterArgs.k_number;
	var dataType    = clusterArgs.data_type;
	var selectionProp = clusterArgs.selection_proportion;
	var selectId     = clusterArgs.select_id;
	var selectName    = clusterArgs.select_name;
	var dataStr      = clusterArgs.data_structure;

    dataType = dataType.toLowerCase();
    cluseterType = clusterType.toLowerCase();
	var protocolId = jQuery('#cluster_div #genotyping_protocol #genotyping_protocol_id').val();

    if (!protocolId) {
        var protocolId = jQuery('#genotyping_protocol_id').val();
    }

	var trainingTraitsIds = jQuery('#training_traits_ids').val();

	if (trainingTraitsIds) {
	    trainingTraitsIds = trainingTraitsIds.split(',');
	}


	if (!trainingTraitsIds) {
        var traitId = jQuery('#trait_id').val();
	    trainingTraitsIds = [traitId];
	}

    if (trainingTraitsIds == '') {
        trainingTraitsIds = [];
    }

	var popDetails  = solGS.getPopulationDetails();
	if (popDetails == undefined) {
	    popDetails = {};
	}

	var popId;
	var popType;
	var popName;

	var page = document.URL;
	if (page.match(/solgs\/trait\/\d+\/population\/|solgs\/model\/combined\/populations\/|breeders\//)) {
	    popId = popDetails.training_pop_id;
	    popName = popDetails.training_pop_name;
	    popType = 'training';
	} else if (page.match(/solgs\/selection\/|solgs\/model\/combined\/trials\//)){
	    popId = popDetails.selection_pop_id;
	    popName = popDetails.selection_pop_name;
	    popType = 'selection';

	} else {
	    popId   = jQuery("#cluster_selected_population_id").val();
	    popType = jQuery("#cluster_selected_population_type").val();
	    popName = jQuery("#cluster_selected_population_name").val();
	}

	if(!selectName) {
	    selectName = popName;
	}

	if (!selectId) {
	    selectId = popId;
	}

	var validateArgs =  {
	    'data_id': selectId,
	    'data_structure': dataStr,
	    'data_type': dataType,
	    'selection_proportion': selectionProp,
	    'pop_type': popType
	};

	var message = this.validateClusterParams(validateArgs);
	var url = document.URL;

	if (message != undefined) {

	    jQuery("#cluster_message").html(message)
		.show().fadeOut(9400);

	} else {
	    if (url.match(/solgs\/models\/combined\/trials\//)) {
		if (popType.match(/training/)) {
		    popDetails['combo_pops_id'] = popId;
		} else if (popType.match(/selection/)) {
		    popDetails['selection_pop_id'] = popId;
		}
	    }

	    var listId;
	    var datasetId;
	    var datasetName;
	    var sIndexName;
	    var clusterPopId;

            if (String(selectId).match(/list/)) {
                dataStr = 'list';
            } else if (String(selectId).match(/dataset/)) {
                dataStr = 'dataset';
            }

	    if (dataStr == 'list') {
    		if (isNaN(selectId)) {
    		    listId = selectId.replace('list_', '');
            } else {
        		    listId = selectId;
        	}
	    } else if (dataStr == 'dataset') {

    		if (isNaN(selectId)) {
    		     datasetId = selectId.replace('dataset_', '');
    		} else {
    		     datasetId = selectId;
    		}

    		datasetName = selectName;
        }

        if (dataStr.match(/list|dataset/) && !String(selectId).match(/list|dataset/)) {
            clusterPopId = dataStr + '_' + selectId;
        } else {
            clusterPopId = popId;
        }
	    if (!clusterPopId) {
    		if (url.match(/solgs\/trait\//)) {
    		    clusterPopId = popDetails.training_pop_id;
    		} else if (url.match(/solgs\/selection\//)) {
    		    clusterPopId = popDetails.selection_pop_id;
    		} else if (url.match(/combined/)) {
    		    clusterPopId = jQuery('#combo_pops_id').val();
    		}
	    }

	    if (popType == 'selection_index') {
		    sIndexName = selectName;
	    }

        var traitsCode;

  var page;
  var fileId = clusterPopId;
if (document.URL.match(/cluster\/analysis/)) {
   page =  '/cluster/analysis/' + clusterPopId + '/dtype/' + dataType + '/k/' + kNumber;
   if (dataType.match(/genotype/i)) {
      page = page + '/gp/' + protocolId;
  }
} else {

         traitsCode = jQuery('#training_traits_code').val();
         if (popType.match(/selection/) && document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\/trials\//)) {
           popDetails['selection_pop_id'] = clusterPopId;
         fileId = popDetails.training_pop_id + '-' + clusterPopId;
        }
       if (sIndexName) {
          page =  '/cluster/analysis/' + fileId + '/dtype/' + sIndexName + '/k/' + kNumber;

        } else {
           page =  '/cluster/analysis/' + fileId + '/dtype/' + dataType + '/k/' + kNumber;

        if (traitsCode) {
           page = page + '/traits/' + traitsCode;
       } else {
            page = page + '/traits/' + 'undefined';
       }

       if (selectionProp) {
              page = page + '/selProp/' + selectionProp;
       } else {
             page = page + '/selProp/' + 'undefined' ;
       }

           page = page + '/gp/' + protocolId;
    }
}
    var clusterArgs =  {'training_pop_id': popDetails.training_pop_id,
       'selection_pop_id': popDetails.selection_pop_id,
       'combo_pops_id': popDetails.combo_pops_id,
       'training_traits_ids': trainingTraitsIds,
        'training_traits_code': traitsCode,
       'cluster_pop_id': clusterPopId,
       'list_id': listId,
       'cluster_type': clusterType,
       'data_structure': dataStr,
       'dataset_id': datasetId,
       'dataset_name': datasetName,
       'data_type': dataType,
       'k_number' : kNumber,
       'selection_proportion': selectionProp,
       'sindex_name': sIndexName,
       'cluster_pop_name': selectName || '',
       'genotyping_protocol_id': protocolId,
        'analysis_type': 'cluster analysis',
        'analysis_page': page
          };

	    this.checkCachedCluster(page, clusterArgs);
	}

    },

    checkCachedCluster: function(page, args) {

        if (typeof args !== 'string') {
    	       args = JSON.stringify(args);
        }

    	jQuery.ajax({
    	    type    : 'POST',
    	    dataType: 'json',
    	    data    : {'page': page, 'args': args },
    	    url     : '/solgs/check/cached/result/',
    	    success : function(res) {
    		if (res.cached) {
    		    solGS.cluster.runClusterAnalysis(args);
    		} else {
                args = JSON.parse(args);
    		    solGS.cluster.selectAnalysisOption(page, args);
    		}
    	    },
    	    error: function() {
    		alert('Error occured checking for cached output.')
    	    }
    	});
    },

    selectAnalysisOption: function(page, args) {
	var t = '<p>This analysis may take a long time. '
	    + 'Do you want to submit the analysis and get an email when it completes?</p>';

	jQuery('<div />')
	    .html(t)
	    .dialog({
		height : 200,
		width  : 400,
		modal  : true,
		title  : "cluster job submission",
 		buttons: {
		    OK: {
			text: 'Yes',
			class: 'btn btn-success',
                        id   : 'queue_job',
			click: function() {
			    jQuery(this).dialog("close");
                solGS.submitJob.checkUserLogin(page, args);
			},
		    },

		    No: {
		    	text: 'No, I will wait till it completes.',
		    	class: 'btn btn-warning',
                        id   : 'no_queue',
		    	click: function() {
		    	    jQuery(this).dialog("close");

		    	    solGS.cluster.runClusterAnalysis(args);
		    	},
		    },

		    Cancel: {
			text: 'Cancel',
			class: 'btn btn-info',
                        id   : 'cancel_queue_info',
			click: function() {
			    jQuery(this).dialog("close");
			},
		    },
		}
	    });

    },


    runClusterAnalysis: function(clusterArgs) {
    if (typeof clusterArgs !== 'string') {
        clusterArgs = JSON.stringify(clusterArgs);
    }

	if (clusterArgs) {

	    jQuery("#cluster_message")
		.html("Running K-means clustering... please wait...it may take minutes")
		.show();

        jQuery("#cluster_canvas .multi-spinner-container").show();

	    jQuery("#run_cluster").hide();

	    jQuery.ajax({
		type: 'POST',
		dataType: 'json',
		data: {'arguments': clusterArgs},
		url: '/run/cluster/analysis',
		success: function(res) {
		    if (res.result == 'success') {
			jQuery("#cluster_canvas .multi-spinner-container").hide();

			solGS.cluster.plotClusterOutput(res);

			jQuery("#cluster_message").empty();
		    jQuery("#run_cluster").show();

		    } else {
			jQuery("#cluster_message").html(res.result);
			jQuery("#cluster_canvas .multi-spinner-container").hide();
			jQuery("#run_cluster").show();
		    }
		},
		error: function(res) {
		    jQuery("#cluster_message").html('Error occured running the clustering.');
		    jQuery("#cluster_canvas .multi-spinner-container").hide();
		    jQuery("#run_cluster").show();
		}
	    });
	} else {
	    jQuery("#cluster_message").html('Missing cluster parameters.')
		.show().fadeOut(8400);
	}

    },


    validateClusterParams: function(valArgs) {

	var popType  = valArgs.pop_type;
	var dataType = valArgs.data_type;
	var selectionProp = valArgs.selection_proportion;
	var dataStr = valArgs.data_structure;
	var dataId = valArgs.data_id;
	var msg;

	if (popType == 'selection_index') {

	    if (dataType.match(/genotype/i) == null) {
		msg = 'K-means clustering for selection index type'
		    + ' data works with genotype data only.';
	    }

	    if (dataType.match(/genotype/i) != null
		&& !selectionProp) {

		msg = 'The selection proportion value is empty.'
		    + ' You need to define the fraction of the'
		    +' population you want to select.';
	    }

	}

	if (dataStr == 'list') {
	    var list = new CXGN.List();

	    if (isNaN(dataId)) {
		dataId= dataId.replace(/list_/, '');
	    }

	    var listType = list.getListType(dataId);

	    if (listType == 'accessions'
		&& dataType.match(/phenotype/i)) {
		msg = 'With list of clones, you can only cluster based on <em>genotype</em>.';
	    }

	    if (listType == 'plots'
		&& dataType.match(/genotype/i)) {
		msg = 'With list of plots, you can only cluster based on <em>phenotype</em>.';
	    }

	}

	return msg;
    },

    plotClusterOutput: function(res) {

	var resultName = res.result_name || '';
	var imageId = res.plot_name;
	console.log('image id: ' + imageId)
	imageId = 'id="' + imageId + '"';
	var plot = '<img '+ imageId + ' src="' + res.kcluster_plot + '">';
	var filePlot  = res.kcluster_plot.split('/').pop();
	var plotType = 'K-means plot';
	var plotLink = "<a href=\""
	    + res.kcluster_plot
	    +  "\" download="
	    + filePlot + ">["
	    + plotType +  "]</a>";

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

    runCluster: function(selectId, selectName, dataStr) {

	var clusterOpts = solGS.cluster.clusteringOptions(selectId);
	var clusterType = clusterOpts.cluster_type || 'k-means';
	var kNumber     = clusterOpts.k_number;
	var dataType    = clusterOpts.data_type || 'genotype';

	var clusterArgs = { 'select_id': selectId,
			    'select_name': selectName,
			    'data_structure':  dataStr,
			    'cluster_type':  clusterType,
			    'data_type': dataType,
			    'k_number':  kNumber
			  }

    	this.clusterResult(clusterArgs);
    },

    registerClusterType: function(selectId) {
	var analysisRowId = this.selectRowId(selectId);
	var clusterType = jQuery('input[name=analysis_select]:checked', '#' + analysisRowId).val();
	return clusterType;
    },

    clusteringOptions: function(selectId) {

	var url = document.URL;

	if(url.match(/cluster\/analysis/)) {
	    selectId = this.selectRowId(selectId);
	}

	var dataType    = jQuery('#'+selectId + ' #cluster_data_type_select').val();
	var clusterType = jQuery('#'+selectId + ' #cluster_type_select').val();
	var kNumber     = jQuery('#'+selectId + ' #k_number').val();

	var selectionProp = jQuery('#'+selectId + ' #selection_proportion').val()

	if (selectionProp) {
	    selectionProp = selectionProp.replace(/%/, '');
	    selectionProp = selectionProp.replace(/\s+/g, '');
	}

	if (kNumber) {
	    kNumber = kNumber.replace(/\s+/g, '');
	}

	return {'data_type' : dataType,
		'cluster_type': clusterType,
		'k_number': kNumber,
		'selection_proportion': selectionProp
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
	var modelData = solGS.sIndex.getTrainingPopulationData();

	var trainingPopIdName = JSON.stringify(modelData);

	var  popsList =  '<dl id="cluster_selected_population" class="cluster_dropdown">'
            + '<dt> <a href="#"><span>Choose a population</span></a></dt>'
            + '<dd><ul>'
            + '<li>'
            + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
            + '</li>'
	    + '</ul></dd></dl>';

	jQuery("#cluster_select_a_population_div").empty().append(popsList).show();

	var dbSelPopsList;
	if (modelData.id.match(/list/) == null) {
            dbSelPopsList = solGS.sIndex.addSelectionPopulations();
	}

	if (dbSelPopsList) {
            jQuery("#cluster_select_a_population_div ul").append(dbSelPopsList);
	}

	var listTypeSelPops = jQuery("#list_type_selection_pops_table").length;

	if (listTypeSelPops) {
            var selPopsList = solGS.sIndex.getListTypeSelPopulations();
            if (selPopsList) {
		jQuery("#cluster_select_a_population_div ul").append(selPopsList);
            }
	}

        var sIndexPops = solGS.sIndex.addIndexedClustering();
        if (sIndexPops) {
	    jQuery("#cluster_select_a_population_div ul").append(sIndexPops);
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

            var selectedPopId   = idPopName.id;
            var selectedPopName = idPopName.name;
            var selectedPopType = idPopName.pop_type;

            jQuery("#cluster_selected_population_name").val(selectedPopName);
            jQuery("#cluster_selected_population_id").val(selectedPopId);
            jQuery("#cluster_selected_population_type").val(selectedPopType);

	    if (selectedPopType.match(/selection_index/)) {
		jQuery('#cluster_div #cluster_options #selection_proportion_div').show();
	    } else {
		jQuery('#cluster_div #cluster_options #selection_proportion_div').hide();
	    }

	});

	jQuery(".cluster_dropdown").bind('click', function(e) {
            var clicked = jQuery(e.target);

            if (!clicked.parents().hasClass("cluster_dropdown"))
		jQuery(".cluster_dropdown dd ul").hide();

            e.preventDefault();

	});
    },


    // plotKCluster: function(plotData){

    // },

}


jQuery.fn.doesExist = function(){

        return jQuery(this).length > 0;

 };


jQuery(document).ready( function() {

    var url = document.URL;

    if (url.match(/cluster\/analysis/)) {

        var list = new CXGN.List();

        var listMenu = list.listSelect("cluster_genotypes", ['accessions','plots', 'trials'], undefined, undefined, undefined);

	    var dType = ['accessions', 'trials'];

	var dMenu = solGS.dataset.getDatasetsMenu(dType);

	if (listMenu.match(/option/) != null) {
        jQuery("#cluster_genotypes_list").append(listMenu);
	    jQuery("#cluster_genotypes_list_select").append(dMenu);

        var clusterArgs = solGS.cluster.getClusterArgsFromUrl();
        var clusterPopId = clusterArgs.cluster_pop_id;
        if (clusterPopId) {
            solGS.cluster.runClusterAnalysis(clusterArgs);
        }

        } else {
            jQuery("#cluster_genotypes_list").append("<select><option>no lists found - Log in</option></select>");
        }
    }

});


jQuery(document).ready( function() {

    var url = document.URL;

    if (url.match(/cluster\/analysis/)) {

        jQuery("<option>", {value: '', selected: true}).prependTo("#cluster_genotypes_list_select");

        jQuery("#cluster_genotypes_list_select").change(function() {
            var selectId = jQuery(this).find("option:selected").val();
	    var selectName = jQuery(this).find("option:selected").text();
            var dataStr  = jQuery(this).find("option:selected").attr('name');

	    if (dataStr == undefined) {
		dataStr = 'list';
	    }

            if (selectId) {
                jQuery("#cluster_go_btn").click(function() {
		    solGS.cluster.loadClusterGenotypesList(selectId, selectName, dataStr);
                });
            }
        });

	//checkClusterResult();
    }
});


jQuery(document).ready( function() {

    jQuery("#run_cluster").click(function() {
	var dataStr = jQuery('#data_structure').val();
	var selectId;
	var selectName;
	if (dataStr == 'dataset') {
	    selectId = jQuery('#dataset_id').val();
	} else if (dataStr == 'list') {
	     selectId = jQuery('#list_id').val();
	}

	if (!dataStr) {
	    var popType = jQuery("#cluster_selected_population_type").val();

	    if (popType == 'list') {
		dataStr = 'list';
	    } else if (popType == 'dataset') {
		dataStr = 'dataset';
	    }
	}

	if (selectId == undefined) {
	    selectId = jQuery("#cluster_selected_population_id").val();
	}

	if (document.URL.match(/breeders\/trial\//)) {
	    selectId = jQuery("#trial_id").val();
	    selectName = jQuery("#trial_name").val();
	}

	if (selectName == undefined) {
	    selectName = jQuery("#cluster_selected_population_name").val();
	}

	var clusterOptsId = 'cluster_options';
	var clusterOpts = solGS.cluster.clusteringOptions(clusterOptsId);

	// if (clusterOpts.selection_proportion) {
	//     selectId = selectName;
	// }

	var clusterArgs = { 'select_id': selectId,
			    'select_name': selectName,
			    'data_structure':  dataStr,
			    'cluster_type':  clusterOpts.cluster_type,
			    'data_type': clusterOpts.data_type,
			    'k_number': clusterOpts.k_number,
			    'selection_proportion': clusterOpts.selection_proportion
			  };

        solGS.cluster.clusterResult(clusterArgs);
    });

});


jQuery(document).ready( function() {
    var page = document.URL;

    if (page.match(/solgs\/traits\/all\/|solgs\/models\/combined\/trials\//) != null) {

	setTimeout(function() {solGS.cluster.listClusterPopulations()}, 5000);


	var dataTypeOpts = ['Genotype', 'GEBV', 'Phenotype'];
	dataTypeOpts =   solGS.cluster.createDataTypeSelect(dataTypeOpts);

	var clusterTypeOpts =   solGS.cluster.createClusterTypeSelect();

	jQuery(document).ready(checkClusterPop);

	function checkClusterPop() {
	    if(jQuery('#cluster_div #cluster_select_a_population_div').is(':visible')) {
		jQuery('#cluster_div #cluster_options #cluster_data_type_opts').html(dataTypeOpts);
		jQuery('#cluster_div #cluster_options #cluster_type_opts').html(clusterTypeOpts);
		jQuery('#cluster_div #cluster_options').show();
	    } else {
		setTimeout(checkClusterPop, 6000);
	    }
	}

} else {
        var dataTypeOpts;
        if (page.match(/cluster\/analysis|breeders\/trial\//)) {

    	    dataTypeOpts = ['Genotype', 'Phenotype'];
        } else if (page.match(/solgs\/trait\/\d+\/population\/|solgs\/model\/combined\/trials\//)) {
        	dataTypeOpts = ['Genotype'];
        }

    dataTypeOpts =   solGS.cluster.createDataTypeSelect(dataTypeOpts);
    var clusterTypeOpts =   solGS.cluster.createClusterTypeSelect();

	jQuery('#cluster_div #cluster_options #cluster_data_type_opts').html(dataTypeOpts);
	jQuery('#cluster_div #cluster_options #cluster_type_opts').html(clusterTypeOpts);
	jQuery("#cluster_div #cluster_options").show();

    }
});
