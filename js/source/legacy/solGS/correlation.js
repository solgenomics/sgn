/**
 * correlation coefficients plotting using d3
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

JSAN.use("solGS.heatMap");

var solGS = solGS || function solGS() {};

solGS.correlation = {
  checkPhenoCorreResult: function () {
    var popId = jQuery("#corre_pop_id").val();

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/phenotype/correlation/check/result",
      data: { corre_pop_id: popId },
      success: function (response) {
        if (response.result) {
          solGS.correlation.phenotypicCorrelation();
        } else {
          jQuery("#run_pheno_correlation").show();
        }
      },
    });
  },

  loadCorrelationPopsList: function(selectId, selectName, dataStr) {
    console.log(` loadCorrelationPopsList selectId: ${selectId} -- name: ${selectName} -- dt str: ${dataStr}`)
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
			var tdId = '#list_corr_page_' + corrPopId;
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

		var runCorrId = this.corrRunCorrId(corrPopId);
    var correArgs = {
      'corre_pop_id': `${dataStr}_${selectId}`,
      'data_structure': dataStr,
      'corre_pop_name': selectName
    }

    correArgs = JSON.stringify(correArgs);
    console.log(`correargs: ${correArgs}`)

		var onClickVal = '<button type="button" id="' +  runCorrId + '" class="btn btn-success" data-selected-pop=\'' + correArgs +'\' onclick="solGS.correlation.runPhenoCorrelationAnalysis(\'' + runCorrId + '\')">Run correlation</button>';

    // var onClickVal = '<button type="button" id="' + runCorrId + '" class="btn btn-success" onclick="solGS.correlation.runPhenoCorrelationAnalysis(' +
		// 	selectId + ",'" + selectName + "'" + ",'" + dataStr +
		// 	"'" + ')">Run correlation</button>';

    console.log(`onclickVal ${onClickVal}`)
		var row = '<tr name="' + dataStr + '"' + ' id="' + corrPopId + '">' +
			'<td>' + selectName + '</td>' +
			'<td>' + dataStr + '</td>' +
			'<td>' + dataTypeOpts + '</td>' +
			'<td>' + onClickVal + '</td>' +
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

  corrRunCorrId: function(rowId) {
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

  formatGenCorInputData: function (correPopId, popType, sIndexFile) {
    var trainingPopId = jQuery("#training_pop_id").val();
    var traitsIds = jQuery("#training_traits_ids").val();
    var traitsCode = jQuery("#training_traits_code").val();
    var divPlace;
    if (traitsIds) {
      traitsIds = traitsIds.split(",");
    }

    var protocolId = jQuery("#genotyping_protocol_id").val();

    var { canvas, corrMsgDiv } = this.corrDivs(sIndexFile);
    this.showCorrProgress(canvas, "Preparing GEBVS");

    var genArgs = {
      training_pop_id: trainingPopId,
      corre_pop_id: correPopId,
      training_traits_ids: traitsIds,
      training_traits_code: traitsCode,
      pop_type: popType,
      selection_index_file: sIndexFile,
      canvas: canvas,
      corr_msg_div: corrMsgDiv,
      genotyping_protocol_id: protocolId,
    };

    genArgs = JSON.stringify(genArgs);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: genArgs },
      url: "/correlation/genetic/data/",
      success: function (res) {
        if (res.status) {
          solGS.correlation.runGenCorrelationAnalysis(res.corre_args);
        } else {
          jQuery(corrMsgDiv)
            .html("This population has no valid traits to correlate.")
            .fadeOut(8400);
        }
      },
      error: function (res) {
        jQuery(corrMsgDiv)
          .html("Error occured preparing the additive genetic data for correlation analysis.")
          .fadeOut(8400);
      },
    });
  },

  phenotypicCorrelation: function () {
    var correPopId = jQuery("#corre_pop_id").val();
    var dataSetType = jQuery("#data_set_type").val();
    var dataStr = jQuery("#data_structure").val();

    var args = {
      corre_pop_id: correPopId,
      data_set_type: dataSetType,
      data_structure: dataStr,
    };

    args = JSON.stringify(args);

    jQuery("#run_pheno_correlation").hide();
    jQuery("#correlation_canvas .multi-spinner-container").show();
    jQuery("#correlation_message").html("Running correlation... please wait...").show();

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/correlation/phenotype/data/",
      success: function (response) {
        if (response.result) {
          solGS.correlation.runPhenoCorrelationAnalysis(args);
        } else {
          jQuery("#correlation_message")
            .html("This population has no phenotype data.")
            .fadeOut(8400);

          jQuery("#run_pheno_correlation").show();
        }
      },
      error: function (response) {
        jQuery("#correlation_message")
          .html("Error occured preparing the phenotype data for correlation analysis.")
          .fadeOut(8400);

        jQuery("#run_pheno_correlation").show();
      },
    });
  },

  runPhenoCorrelationAnalysis: function (args) {
    console.log(`runPhenoCorrelationAnalysis arg: ${args}`)
    
  try {
    var testArgs = JSON.parse(args);

  } catch (err) {
    console.log(`caught error ${err.message}`)
    var selectedPopDiv = document.getElementById(args)
    if (selectedPopDiv) {
    console.log(`arg is: ${selectedPopDiv.dataset}`);
    var selectedPopData = selectedPopDiv.dataset;
    console.log(`arg is corre_pop_id arg: ${JSON.parse(selectedPopData.selectedPop)}`)
    var selectedPop = JSON.parse(selectedPopData.selectedPop);
    console.log(`arg is corre_pop_id arg: ${selectedPop.corre_pop_id}`)

    args = selectedPopData.selectedPop;
    console.log(`arguments args: ${args}`)
  }
  }
  
    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/phenotypic/correlation/analysis/output",
      success: function (response) {
        if (response.data) {
          console.log(`correlation data ${response.data}`)
          solGS.correlation.plotCorrelation(response.data, "#correlation_canvas");

          var corrDownload = solGS.correlation.createPhenoCorrDownloadLink(
            response.corre_table_file
          );

          jQuery("#correlation_canvas")
            .append("<br />" + corrDownload)
            .show();

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

  createPhenoCorrDownloadLink: function (correFile) {
    var correFileName = correFile.split("/").pop();
    var correFileLink =
      '<a href="' +
      correFile +
      '" download=' +
      correFileName +
      '">' +
      "Download correlation coefficients" +
      "</a>";

    return correFileLink;
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
    var divPlace = JSON.parse(args);
    canvas = divPlace.canvas;
    corrMsgDiv = divPlace.corr_msg_div;

    var msg = "Running genetic correlation analysis";
    this.showCorrProgress(canvas, msg);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/genetic/correlation/analysis/output",
      success: function (response) {
        if (response.status == "success") {
          jQuery(canvas).show();

          var heatmapDiv = "corr_heatmap";

          if (canvas === "#si_canvas") {
            heatmapDiv = "#si_heatmap";
          }

          solGS.correlation.plotCorrelation(response.data, canvas, heatmapDiv);

          if (canvas === "#si_canvas") {
            var popName = jQuery("#selected_population_name").val();
            var legendValues = solGS.sIndex.legendParams();

            var popDiv = popName.replace(/\s+/g, "");
            var relWtsId = legendValues.params.replace(/[{",}:\s+<b/>]/gi, "");

            var corLegDiv = `<div id="si_correlation_${popDiv}_${relWtsId}">`;

            var corLegDivVal = jQuery(corLegDiv).html(legendValues.legend);

            jQuery(canvas).append(corLegDivVal).show();
          } else {
            var popName = jQuery("#corre_selected_population_name").val();
            var corLegDiv = '<div id="corre_correlation_' + popName.replace(/\s/g, "") + '"></div>';

            var corLegDivVal = jQuery(corLegDiv).html(popName);
            jQuery(canvas).append(corLegDivVal).show();

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

  plotCorrelation: function (data, canvas, heatmapDiv) {
    solGS.heatmap.plot(data, canvas, heatmapDiv);
  },

  ///////
};

////////

jQuery(document).ready(function () {
  var page = document.URL;

  if (
    page.match(/solgs\/traits\/all\//) != null ||
    page.match(/solgs\/models\/combined\/trials\//) != null
  ) {
    setTimeout(function () {
      solGS.correlation.listGenCorPopulations();
    }, 5000);
  } else {
    // if (page.match(/solgs\/population\/|breeders\/trial\//)) {
    solGS.correlation.checkPhenoCorreResult();
    // }
  }
});

jQuery(document).ready(function () {
  jQuery("#run_pheno_correlation").click(function () {
    solGS.correlation.phenotypicCorrelation();
  });
});

jQuery(document).on("click", "#run_genetic_correlation", function () {
  var popId = jQuery("#corre_selected_population_id").val();
  var popType = jQuery("#corre_selected_population_type").val();

  //jQuery("#correlation_canvas").empty();

  solGS.correlation.formatGenCorInputData(popId, popType);
});


jQuery(document).ready(function() {

	var url = location.pathname;

	if (url.match(/correlation\/analysis/)) {

    solGS.selectMenu.populateMenu("correlation_pops", ['plots', 'trials'], ['plots', 'trials'])
	
	}


  
  
    if (url.match(/correlation\/analysis/)) {
  
      jQuery("#correlation_pops_list_select").change(function() {
        var selectedPop = solGS.selectMenu.getSelectedPop('correlation_pops');
        console.log(` SELECTED CorrelationPopsList selectId: ${selectedPop.selected_id} -- name: ${selectedPop.selected_name} -- dt str: ${selectedPop.data_str}`)

        if (selectedPop.selected_id) {
          jQuery("#correlation_pops_go_btn").click(function() {
            solGS.correlation.loadCorrelationPopsList(selectedPop.selected_id, selectedPop.selected_name, selectedPop.data_str);
          });
        }
      });
      }

});