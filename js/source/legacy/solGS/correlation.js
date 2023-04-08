/**
 * runs genetic and phenotypic correlation analysis and plots correlation coefficients using d3
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

JSAN.use("solGS.heatMap");

var solGS = solGS || function solGS() {};

solGS.correlation = {

  getPhenoCorrArgs: function() {
    var correPopId = jQuery("#corre_pop_id").val();
    var dataSetType = jQuery("#data_set_type").val();
    var dataStr = jQuery("#data_structure").val();

    var listId;
    var datasetId;

    if (dataStr.match(/dataset/)) {
      datasetId = selectId;
    } else if (dataStr.match(/list/)) {
      listId = selectId;
    }

    var args = {
      corre_pop_id: correPopId,
      data_set_type: dataSetType,
      data_structure: dataStr,
      dataset_id: datasetId,
      list_id: listId,
      data_type: 'phenotype',
      correlation_type: 'phenotypic',
    };

    return args;
  },

  loadCorrelationPopsList: function(selectId, selectName, dataStr) {
		var corrPopId = this.getCorrPopId(selectId, dataStr);
		if (selectId.length === 0) {
			alert('The list is empty. Please select a list with content.');
		} else {

			var tableId = "correlation_pops_list_table";
			var corrTable = jQuery('#' + tableId).doesExist();
			if (corrTable == false) {
				corrTable = this.getCorrPopsTable(tableId);
				jQuery("#correlation_pops_selected").append(corrTable).show();
			}

			var addRow = this.selectRow(selectId, selectName, dataStr);
			var tdId = '#corr_' + corrPopId;
			var addedRow = jQuery(tdId).doesExist();

			if (addedRow == false) {
				jQuery('#' + tableId + ' tr:last').after(addRow);
			}

		}
	},

  getCorrPopId: function(selectId, dataStr) {
		var corrPopId;
		if (dataStr) {
			corrPopId = `${dataStr}_${selectId}`;
		} else {
			corrPopId = selectId;
		}

		return corrPopId;
	},

  getCorrPopsTable: function(tableId) {
		return this.createTable(tableId);
	},

  createTable: function(tableId) {

		var table = '<table class="table table-striped" id="' + tableId + '">' +
			'<thead>' +
			'<tr>' +
			'<th>Name</th>' +
			'<th>Data structure</th>' +
			'<th>Data type</th>' +
			'<th>Run correlation</th>' +
			'</tr>' +
			'</thead></table>';

		return table;

	},

  selectRow: function(selectId, selectName, dataStr) {
		var corrPopId = this.getCorrPopId(selectId, dataStr);
	
		// var dataTypeOpts = this.getDataTypeOpts({
		// 	'select_id': selectId,
		// 	'data_str': dataStr
		// })
    var dataTypeOpts= ['Phenotype', 'GEBVs'];
		dataTypeOpts = this.createDataTypeSelect(dataTypeOpts, corrPopId);

    
    var listId;
    var datasetId;

    if (dataStr.match(/dataset/)) {
      datasetId = selectId;
    } else if (dataStr.match(/list/)) {
      listId = selectId;
    }

		var runCorrId = this.getRunCorrId(corrPopId);
    var correArgs = {
      'corre_pop_id': `${dataStr}_${selectId}`,
      'data_structure': dataStr,
      'dataset_id': datasetId,
      'list_id': listId,
      'corre_pop_name': selectName,
      'data_type': 'phenotype',
      'correlation_type': 'phenotypic'
    }

    correArgs = JSON.stringify(correArgs);

		var onClickVal = '<button type="button" id="' +  runCorrId + '" class="btn btn-success" data-selected-pop=\'' + correArgs +'\' onclick="solGS.correlation.runPhenoCorrelation(\'' + runCorrId + '\')">Run correlation</button>';

		var row = '<tr name="' + dataStr + '"' + ' id="' + corrPopId + '">' +
			'<td>' + selectName + '</td>' +
			'<td>' + dataStr + '</td>' +
			'<td>' + dataTypeOpts + '</td>' +
			'<td id="corr_' + corrPopId + '">' + onClickVal + '</td>' +
			'<tr>';

		return row;

	},

  corrDataTypeSelectId: function(rowId) {
		if (location.pathname.match(/correlation\/analysis/) && rowId) {
			return `correlation_data_type_select_${rowId}`;
		} else {
			return 'correlation_data_type_select';
		}

	},

  getRunCorrId: function(rowId) {
		if (location.pathname.match(/correlation\/analysis/) && rowId) {
			return `run_correlation_${rowId}`;
		} else {
			return 'run_correlation';
		}

	},

  createDataTypeSelect: function(opts, rowId) {
		var corrDataTypeId = this.corrDataTypeSelectId(rowId);
		var dataTypeGroup = '<select class="form-control" id="' + corrDataTypeId + '">';

		for (var i = 0; i < opts.length; i++) {

			dataTypeGroup += '<option value="' +
				opts[i] + '">' +
				opts[i] +
				'</option>';
		}
		dataTypeGroup += '</select>';

		return dataTypeGroup;
	},

  listGenCorPopulations: function () {
    var modelData = solGS.sIndex.getTrainingPopulationData();

    var trainingPopIdName = JSON.stringify(modelData);

    var popsList =
      '<dl id="corre_selected_population" class="corre_dropdown">' +
      '<dt> <a href="#"><span>Select a population</span></a></dt>' +
      "<dd>" +
      "<ul>" +
      "<li>" +
      '<a href="#">' +
      modelData.name +
      "<span class=value>" +
      trainingPopIdName +
      "</span></a>" +
      "</li>";

    popsList += "</ul></dd></dl>";

    jQuery("#corre_select_a_population_div").empty().append(popsList).show();

    var dbSelPopsList;
    if (modelData.id.match(/list/) == null) {
      dbSelPopsList = solGS.sIndex.addSelectionPopulations();
    }

    if (dbSelPopsList) {
      jQuery("#corre_select_a_population_div ul").append(dbSelPopsList);
    }

    var listTypeSelPops = jQuery("#list_type_selection_pops_table").length;

    if (listTypeSelPops) {
      var selPopsList = solGS.sIndex.getListTypeSelPopulations();

      if (selPopsList) {
        jQuery("#corre_select_a_population_div ul").append(selPopsList);
      }
    }

    jQuery(".corre_dropdown dt a").click(function () {
      jQuery(".corre_dropdown dd ul").toggle();
    });

    jQuery(".corre_dropdown dd ul li a").click(function () {
      var text = jQuery(this).html();

      jQuery(".corre_dropdown dt a span").html(text);
      jQuery(".corre_dropdown dd ul").hide();

      var idPopName = jQuery("#corre_selected_population").find("dt a span.value").html();
      idPopName = JSON.parse(idPopName);
      modelId = jQuery("#model_id").val();

      var selectedPopId = idPopName.id;
      var selectedPopName = idPopName.name;
      var selectedPopType = idPopName.pop_type;

      jQuery("#corre_selected_population_name").val(selectedPopName);
      jQuery("#corre_selected_population_id").val(selectedPopId);
      jQuery("#corre_selected_population_type").val(selectedPopType);
    });

    jQuery(".corre_dropdown").bind("click", function (e) {
      var clicked = jQuery(e.target);

      if (!clicked.parents().hasClass("corre_dropdown")) jQuery(".corre_dropdown dd ul").hide();

      e.preventDefault();
    });
  },

  getGeneticCorrArgs: function(correPopId, corrPopType, sIndexFile, sindexName) {

    var { canvas, corrMsgDiv } = this.corrDivs(sIndexFile);
    
    var trainingPopId = jQuery("#training_pop_id").val();
    var traitsIds = jQuery("#training_traits_ids").val();
    var traitsCode = jQuery("#training_traits_code").val();
    var protocolId = jQuery("#genotyping_protocol_id").val();

    if (traitsIds) {
      traitsIds = traitsIds.split(",");
    }

    var genArgs = {
      training_pop_id: trainingPopId,
      corre_pop_id: correPopId,
      training_traits_ids: traitsIds,
      training_traits_code: traitsCode,
      pop_type: corrPopType,
      selection_index_file: sIndexFile,
      sindex_name: sindexName,
      canvas: canvas,
      corr_msg_div: corrMsgDiv,
      genotyping_protocol_id: protocolId,
      data_type: 'gebvs',
      correlation_type: 'genetic'
    };

    return genArgs;

  },

  runGeneticCorrelation: function (correPopId, popType, sIndexFile, sindexName) {

    var { canvas, corrMsgDiv } = this.corrDivs(sIndexFile);
    
    jQuery("#run_genetic_correlation").hide();
    jQuery(canvas + " .multi-spinner-container").show();
    var msg = "Running genetic correlation analysis...please wait";
    jQuery(corrMsgDiv).html(`${msg}...`).show();

    var genArgs = this.getGeneticCorrArgs(correPopId, popType, sIndexFile, sindexName)
    genArgs = JSON.stringify(genArgs);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: genArgs },
      url: "/genetic/correlation/analysis",
      success: function (res) {
        if (res.status.match(/success/)) {
          var corrPlotDivId = "#corr_plot_" + correPopId;
          if (canvas === "#si_canvas") {
            sindexName = sindexName.replace(/-/g, '_')
            corrPlotDivId = "#corr_plot_" + sindexName;
          }
     
          var corrDownload = solGS.correlation.createCorrDownloadLink(
            res.corre_table_file, genArgs);

          solGS.heatmap.plot(res.data, canvas, corrPlotDivId, corrDownload);

          if (canvas === "#si_canvas") {
            var popName = jQuery("#selected_population_name").val();
            var legendValues = solGS.sIndex.legendParams();

            var popDiv = popName.replace(/\s+/g, "");
            var relWtsId = legendValues.params.replace(/[{",}:\s+<b/>]/gi, "");

            var corLegDiv = `<div id="si_correlation_${popDiv}_${relWtsId}">`;

            var corLegDivVal = jQuery(corLegDiv).html(legendValues.legend);

            jQuery(canvas).append(corLegDivVal).show();
          } 
        } else {
          jQuery(corrMsgDiv)
            .html(res.status)
            .fadeOut(8400);
        }

        jQuery(canvas + " .multi-spinner-container").hide();
        jQuery(corrMsgDiv).empty();
        jQuery("#run_genetic_correlation").show();
        jQuery.unblockUI();

      },
      error: function (res) {
        jQuery(corrMsgDiv)
          .html("Error occured running correlation analysis.")
          .fadeOut(8400);
      },
    });
  },

  
  runPhenoCorrelation: function (args) {

    jQuery("#run_pheno_correlation").hide();
    jQuery("#correlation_canvas .multi-spinner-container").show();
    jQuery("#correlation_message").html("Running correlation... please wait...").show();
    
    var corrPopId;

    try {
      var phenArgs = JSON.parse(args);
      corrPopId = phenArgs.corre_pop_id;
    } catch (err) {
        var selectedPopDiv = document.getElementById(args)
        if (selectedPopDiv) {
          var selectedPopData = selectedPopDiv.dataset;
          var selectedPop = JSON.parse(selectedPopData.selectedPop);
          corrPopId = selectedPop.corre_pop_id;
          args = selectedPopData.selectedPop;
      }
    }
    
    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/phenotypic/correlation/analysis",
      success: function (response) {
        if (response.data) {
         var corrCanvas = "#correlation_canvas";
          var corrPlotDivId = "#corr_plot_" + corrPopId;
          var corrDownload = solGS.correlation.createCorrDownloadLink(
            response.corre_table_file, args)

          solGS.heatmap.plot(response.data, corrCanvas, corrPlotDivId, corrDownload);

          jQuery("#correlation_canvas .multi-spinner-container").hide();
          jQuery("#correlation_message").empty();
          jQuery("#run_pheno_correlation").hide();
        } else {
          jQuery("#correlation_canvas .multi-spinner-container").hide();

          jQuery("#correlation_message")
            .html("There is no correlation output for this dataset.")
            .fadeOut(8400);

          jQuery("#run_pheno_correlation").show();
        }
      },
      error: function (response) {
        jQuery("#correlation_canvas .multi-spinner-container").hide();

        jQuery("#correlation_message")
          .html("Error occured running the correlation analysis.")
          .fadeOut(8400);

        jQuery("#run_pheno_correlation").show();
      },
    });
  },

  createCorrDownloadLink: function (corrFile, corrArgs) {
    var corrFileName = corrFile.split("/").pop();
    var corrCoefLink =
      '<a href="' +
      corrFile +
      '" download=' +
      corrFileName +
      '">' +
      "coefficients" +
      "</a>";

      corrArgs = JSON.parse(corrArgs);
      var corrPlotDivId = "#corr_plot_" + corrArgs.corre_pop_id;
      corrPlotDivId = corrPlotDivId.replace('#', '');
      
      var corrDownloadBtn = "download_" + corrPlotDivId;
      var corrPlotLink = "<a href='#'  onclick='event.preventDefault();' id='" + corrDownloadBtn + "'> plot</a>";

      var popName =  corrArgs.corre_pop_name;
      if (!popName) {popName = jQuery("#corre_selected_population_name").val();}
      if (!popName) {popName = jQuery("#training_pop_name").val();}
      if (!popName) {popName = jQuery("#trial_name").val();}

      var downloadLinks = `Download ${popName} correlation: `  + corrCoefLink +  ' | '  +  corrPlotLink;
      return downloadLinks;
  },

  showCorrProgress: function (canvas, msg) {
    var msgDiv;
    if (canvas === "#si_canvas") {
      msgDiv = "#si_correlation_message";
    } else {
      msgDiv = "#correlation_message";
      canvas = "#correlation_canvas";
    }

    jQuery("#run_genetic_correlation").hide();
    jQuery(canvas + " .multi-spinner-container").show();
    jQuery(msgDiv).html(`${msg}...`).show();
  },

  corrDivs: function (sIndexFile) {
    var canvas;
    var corrMsgDiv;

    if (sIndexFile) {
      canvas = "#si_canvas";
      corrMsgDiv = "#si_correlation_message";
    } else {
      canvas = "#correlation_canvas";
      corrMsgDiv = "#correlation_message";
    }

    return { canvas, corrMsgDiv };
  },

  runGenCorrelationAnalysis: function (args) {
    var genArgs = JSON.parse(args);
    var canvas = genArgs.canvas;
    var corrMsgDiv = genArgs.corr_msg_div;
    var corrPopId = genArgs.corre_pop_id;
    var sindexName = genArgs.sindex_name;

    var msg = "Running genetic correlation analysis";
    this.showCorrProgress(canvas, msg);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/genetic/correlation/analysis",
      success: function (response) {
        if (response.status == "success") {
          jQuery(canvas).show();
          var corrPlotDivId = "#corr_plot_" + corrPopId;
          if (canvas === "#si_canvas") {
            sindexName = sindexName.replace(/-/g, '_')
            corrPlotDivId = "#corr_plot_" + sindexName;
          }

          var corrDownload = solGS.correlation.createCorrDownloadLink(
            response.corre_table_file, corrPlotDivId);

          solGS.heatmap.plot(response.data, canvas, corrPlotDivId, corrDownload);

          if (canvas === "#si_canvas") {
            var popName = jQuery("#selected_population_name").val();
            var legendValues = solGS.sIndex.legendParams();

            var popDiv = popName.replace(/\s+/g, "");
            var relWtsId = legendValues.params.replace(/[{",}:\s+<b/>]/gi, "");

            var corLegDiv = `<div id="si_correlation_${popDiv}_${relWtsId}">`;
            var corLegDivVal = jQuery(corLegDiv).html(legendValues.legend);

            jQuery(canvas).append(corLegDivVal).show();
          } else {
            jQuery("#run_genetic_correlation").show();
          }
        } else {
          jQuery(corrMsgDiv)
            .html("There is no genetic correlation output for this dataset.")
            .fadeOut(8400);
        }

        jQuery(canvas + " .multi-spinner-container").hide();
        jQuery(corrMsgDiv).empty();
        jQuery("#run_genetic_correlation").show();
        jQuery.unblockUI();
      },
      error: function (response) {
        jQuery(corrMsgDiv)
          .html("Error occured running the genetic correlation analysis.")
          .fadeOut(8400);

        jQuery("#run_genetic_correlation").show();
        jQuery(canvas + " .multi-spinner-container").hide();
        jQuery.unblockUI();
      },
    });
  },

///////
};
////////

jQuery(document).ready(function () {
  var page = document.URL;

  if (page.match(/solgs\/traits\/all\//) != null ||
    page.match(/solgs\/models\/combined\/trials\//) != null) {
    setTimeout(function () {
      solGS.correlation.listGenCorPopulations();
    }, 5000);
  }
});

jQuery(document).ready(function () {
  jQuery("#run_pheno_correlation").click(function () {
    var args = solGS.correlation.getPhenoCorrArgs();
    args = JSON.stringify(args);
    solGS.correlation.runPhenoCorrelation(args);
  });


  jQuery(document).on("click", "#run_genetic_correlation", function () {
    var popId = jQuery("#corre_selected_population_id").val();
    var popType = jQuery("#corre_selected_population_type").val();
  
    solGS.correlation.runGeneticCorrelation(popId, popType);
  });

	var url = location.pathname;

	if (url.match(/correlation\/analysis/)) {

    solGS.selectMenu.populateMenu("correlation_pops", ['plots', 'trials'], ['plots', 'trials']);

  }
});

jQuery(document).ready(function () {
      jQuery("#correlation_pops_list_select").change(function() {
        var selectedPop = solGS.selectMenu.getSelectedPop('correlation_pops');

        if (selectedPop.selected_id) {
          jQuery("#correlation_pops_go_btn").click(function() {
            solGS.correlation.loadCorrelationPopsList(selectedPop.selected_id, selectedPop.selected_name, selectedPop.data_str);
          });
        }
      });
    });


    jQuery(document).ready(function () {
      console.log(`correlation plotdivid:  regex`)

      jQuery("#correlation_canvas").on('click' , 'a', function(e) {
        var buttonId = e.target.id;
        console.log(`correlation buttonidid: ${buttonId}`)

        var corrPlotId = buttonId.replace(/download_/, '');
        console.log(`correlation plotdivid: ${corrPlotId}`)
        saveSvgAsPng(document.getElementById("#" + corrPlotId),  corrPlotId + ".png", {scale:1});	
      });
    
      jQuery("#si_correlation_canvas").on('click' , 'a', function(e) {
        var buttonId = e.target.id;
        var corrPlotId = buttonId.replace(/download_/, '');
      
        console.log(`correlation si canvas plotdivid: ${corrPlotId}`)
      
        saveSvgAsPng(document.getElementById("#" + corrPlotId),  corrPlotId + ".png", {scale: 1});	
      });
      });
