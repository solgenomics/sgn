/**corrPlotDiv
 * runs genetic and phenotypic correlation analysis and plots correlation coefficients using d3
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

JSAN.use("solGS.heatMap");

var solGS = solGS || function solGS() {};

solGS.correlation = {
  canvas: "#corr_canvas",
  corrPlotDivPrefix: "#corr_plot",
  corrMsgDiv: "#corr_message",
  corrPopsSelectMenuId: "#corr_pops_select",
  corrPopsDiv: "#corr_pops_select_div",
  corrPopsDataDiv: "#corr_pops_data_div",

  getCorrPopName: function () {

    var corrPopName = jQuery("#corr_pop_name").val();

    if (!corrPopName) {
      corrPopName = jQuery("#corr_selected_pop_name").val();
    }
    if (!corrPopName) {
      corrPopName = jQuery("#training_pop_name").val();
    }
    if (!corrPopName) {
      corrPopName = jQuery("#trial_name").val();
    }
    if (!corrPopName) {
      corrPopName = jQuery("#analysis_pop_name").val();
    }

    return corrPopName;
},


  getPhenoCorrArgs: function () {
    var corrPopId = jQuery("#corr_pop_id").val();
    var dataSetType = jQuery("#data_set_type").val();
    var dataStr = jQuery("#data_structure").val();
    var corrPopName = this.getCorrPopName();
    
    var listId;
    var datasetId;

    if (dataStr.match(/dataset/)) {
      datasetId = corrPopId;
    } else if (dataStr.match(/list/)) {
      listId = corrPopId;
    }

    var corrDivs = this.getCorrDivs(corrPopId);

    var args = {
      corr_pop_id: corrPopId,
      corr_pop_name: corrPopName,
      data_set_type: dataSetType,
      data_structure: dataStr,
      dataset_id: datasetId,
      list_id: listId,
      data_type: "phenotype",
      correlation_type: "phenotypic",
      canvas: corrDivs.canvas,
      corr_plot_div: corrDivs.corr_plot_div,
      corr_msg_div: corrDivs.corr_msg_div,
    };

    return args;
  },

getCorrPopsRows: function(corrPops) {

  var corrPopsRows = [];

  for (var i = 0; i < corrPops.length; i++) {
    if (corrPops[i]) {
      var corrPopRow = this.createRowElements(corrPops[i]);
      corrPopsRows.push(corrPopRow);
    }
  }

  return corrPopsRows;

},

getCorrPops: function () {

  var list = new solGSList();
  var lists = list.getLists(["plots", "trials"]);
  lists = list.addDataStrAttr(lists);

  var datasets = solGS.dataset.getDatasetPops(["plots", "trials"]);
  var corrPops = [lists, datasets];

  return corrPops.flat();

},


getSelectedDataType: function (corrPopId) {
  var dataType;
  if (corrPopId) {
    var corrDataSelectedId = this.corrDataTypeSelectId(corrPopId);
    dataType = jQuery("#" + corrDataSelectedId).val();
  } else {
    dataType = jQuery("#corr_data_type_select").val();
  }

  return dataType;

},

getSelectedPopCorrArgs: function (runCorrElemId) {
  var corrArgs;

  var selectedPopDiv = document.getElementById(runCorrElemId);
  if (selectedPopDiv) {
    var selectedPopData = selectedPopDiv.dataset;

    var selectedPop = JSON.parse(selectedPopData.selectedPop);
    corrPopId = selectedPop.corr_pop_id;

    var dataType = this.getSelectedDataType(corrPopId);

    corrArgs = selectedPopData.selectedPop;
    corrArgs = JSON.parse(corrArgs);
    corrArgs["data_type"] = dataType;
    if (dataType.match(/Phenotype/)){
      corrArgs['correlation_type'] = 'phenotypic';
    }
  }

  return corrArgs;

},


  getCorrPopId: function (selectId, dataStr) {
    var corrPopId;
    if (dataStr) {
      corrPopId = `${dataStr}_${selectId}`;
    } else {
      corrPopId = selectId;
    }

    return corrPopId;

  },

  getCorrPopsTable: function (tableId) {
    return this.createTable(tableId);

  },

  createTable: function (tableId) {
    var table =
    `<table id="${tableId}" class="table table-striped"><thead><tr>` +
      "<th>Name</th>" +
      "<th>Data structure</th>" +
      "<th>Compatibility</th>" + 
      "<th>Ownership</th>" +
      "<th>Data type</th>" +
      "<th>Run correlation</th>" +
      "</tr>" +
      "</thead></table>";

    return table;

  },

  createRowElements: function (corrPop) {
    var popId = corrPop.id;
    var popName = corrPop.name;
    var dataStr = corrPop.data_str;
    var tool_compatibility = corrPop.tool_compatibility;
  
    var corrPopId = this.getCorrPopId(popId, dataStr);
   
    var dataTypeOpts = this.getDataTypeOpts({
      id: popId,
      name: popName,
      data_str: dataStr,
    });
  
    dataTypeOpts = this.createDataTypeSelect(dataTypeOpts, corrPopId);
    
    var runCorrBtnId = this.getRunCorrId(corrPopId);
  
    var listId;
    var datasetId;
  
    if (dataStr.match(/dataset/)) {
      datasetId = popId;
    } else if (dataStr.match(/list/)) {
      listId = popId;
    }
  
    var corrArgs = {
      corr_pop_id: corrPopId,
      data_structure: dataStr,
      dataset_id: datasetId,
      list_id: listId,
      corr_pop_name: popName,
      analysis_type: "correlation analysis",
    };
  
    corrArgs = JSON.stringify(corrArgs);
  
    var runCorrBtn =
      `<button type="button" id=${runCorrBtnId}` +
      ` class="btn btn-success" data-selected-pop='${corrArgs}'>Run Correlation</button>`;
  
    var compatibility_message = '';
    if (dataStr.match(/dataset/)) {
      popName = `<a href="/dataset/${popId}">${popName}</a>`;
      if (tool_compatibility == null || tool_compatibility["Correlation"] == null || tool_compatibility == "(not calculated)"){
        compatibility_message = "(not calculated)";
      } else {        
          if (tool_compatibility["Correlation"]['compatible'] == 0) {
          compatibility_message = '<b><span class="glyphicon glyphicon-remove" style="color:red"></span></b>'
          } else {
              if ('warn' in tool_compatibility["Correlation"]) {
                  compatibility_message = '<b><span class="glyphicon glyphicon-warning-sign" style="color:orange;font-size:14px" title="' + tool_compatibility["Correlation"]['warn'] + '"></span></b>';
              } else {
                  compatibility_message = '<b><span class="glyphicon glyphicon-ok" style="color:green"></span></b>';
              }
          }
      }
    }

    var rowData = [popName,
      dataStr, compatibility_message, corrPop.owner, dataTypeOpts, runCorrBtn, `${dataStr}_${popId}`];
    
    return rowData;
  },

  displayCorrPopsTable: function (tableId, data) {

    var table = jQuery(`#${tableId}`).DataTable({
      'searching': true,
      'ordering': true,
      'processing': true,
      'paging': true,
      'info': false,
      'pageLength': 5,
      'rowId': function (a) {
        return a[5]
      }
    });
  
    table.rows.add(data).draw();
  
  },

  getDataTypeOpts: function (args) {
    var dataTypeOpts = ["Phenotype"];
    return dataTypeOpts;
  },

  
  corrDataTypeSelectId: function (rowId) {
    if (location.pathname.match(/correlation\/analysis/) && rowId) {
      return `corr_data_type_select_${rowId}`;
    } else {
      return "corr_data_type_select";
    }

  },

  getRunCorrId: function (rowId) {
    if (location.pathname.match(/correlation\/analysis/) && rowId) {
      return `run_correlation_${rowId}`;
    } else {
      return "run_correlation";
    }

  },

  createDataTypeSelect: function (opts, rowId) {
    var corrDataTypeId = this.corrDataTypeSelectId(rowId);
    var dataTypeGroup = '<select class="form-control" id="' + corrDataTypeId + '">';

    for (var i = 0; i < opts.length; i++) {
      dataTypeGroup += '<option value="' + opts[i] + '">' + opts[i] + "</option>";
    }
    dataTypeGroup += "</select>";

    return dataTypeGroup;

  },

  populateGenCorrMenu: function (newPop) {
    var modelData = solGS.selectMenuModelArgs();
  
    var corrPops = [modelData];

    if (!modelData.id.match(/list/)) {
      var trialSelPopsList = solGS.selectionPopulation.getPredictedTrialTypeSelectionPops();

      if (trialSelPopsList) {
        corrPops.push(trialSelPopsList);
      }
    }

    var menu = new SelectMenu(this.corrPopsDiv, this.corrPopsSelectMenuId);

    if (newPop){
        menu.updateOptions(newPop);   
    } else {
      menu.populateMenu(corrPops);
    }
    
  },

  getGeneticCorrArgs: function (corrPopId, corrPopType, sIndexFile, sIndexName) {
    var corrDivs = this.getCorrDivs(corrPopId, sIndexName);

    var trainingPopId = jQuery("#training_pop_id").val();
    var traitsIds = jQuery("#training_traits_ids").val();
    var traitsCode = jQuery("#training_traits_code").val();
    var protocolId = jQuery("#genotyping_protocol_id").val();
    var dataSetType = jQuery("#data_set_type").val();

    if (traitsIds) {
      traitsIds = traitsIds.split(",");
    }

    var genArgs = {
      training_pop_id: trainingPopId,
      corr_pop_id: corrPopId,
      training_traits_ids: traitsIds,
      data_set_type: dataSetType,
      training_traits_code: traitsCode,
      pop_type: corrPopType,
      selection_index_file: sIndexFile,
      sindex_name: sIndexName,
      canvas: corrDivs.canvas,
      corr_plot_div: corrDivs.corr_plot_div,
      corr_msg_div: corrDivs.corr_msg_div,
      genotyping_protocol_id: protocolId,
      data_type: "gebvs",
      correlation_type: "genetic",
    };

    return genArgs;

  },

  runGeneticCorrelation: function (genArgs) {
    genArgs = JSON.stringify(genArgs);

    var analysisReq = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: genArgs },
      url: "/genetic/correlation/analysis",
    });

    return analysisReq;

  },

  runPhenoCorrelation: function (args) {
    args = JSON.stringify(args);
    var analysisReq = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/phenotypic/correlation/analysis",
    });

    return analysisReq;

  },

  createCorrDownloadLink: function (corrArgs) {
    var corrFile = corrArgs.corr_table_file;
    var corrFileName = corrFile.split("/").pop();
    var corrCoefLink =
      '<a href="' + corrFile + '" download=' + corrFileName + '">' + "coefficients" + "</a>";

    var corrDivs = this.getCorrDivs(corrArgs.corr_pop_id, corrArgs.sindex_name);

    corrPlotDivId = corrDivs.corr_plot_div.replace("#", "");
    var corrDownloadBtn = "download_" + corrPlotDivId;
    var corrPlotLink =
      "<a href='#'  onclick='event.preventDefault();' id='" + corrDownloadBtn + "'> plot</a>";

    var popName = corrArgs.corr_pop_name;
    if (!popName) {
      popName = this.getCorrPopName();
    }

    var downloadLinks = `Download <b>${popName}</b> correlation: ` + corrCoefLink + " | " + corrPlotLink;
    return downloadLinks;
  },

  showCorrProgress: function (canvas, msg) {
    var msgDiv;
    if (canvas === "#si_canvas") {
      msgDiv = "#si_corr_msg_div";
    } else {
      msgDiv = "#corr_msg_div";
      canvas = "#corr_canvas";
    }

    jQuery("#run_genetic_correlation").hide();
    jQuery(canvas + " .multi-spinner-container").show();
    jQuery(msgDiv).html(msg).show();
  },

  getCorrDivs: function (corrPopId, sIndexName) {
    var canvas;
    var corrMsgDiv;
    var corrPlotDiv;

    if (sIndexName) {
      canvas = solGS.sIndex.canvas; //"#si_canvas";
      corrMsgDiv = solGS.sIndex.siMsgDiv; //"#si_corr_msg_div";
      corrPlotDiv = `${this.corrPlotDivPrefix}_${sIndexName}`;
    } else {
      canvas = this.canvas;
      corrMsgDiv = this.corrMsgDiv;
      corrPlotDiv = `${this.corrPlotDivPrefix}_${corrPopId}`;
    }

    return { canvas: canvas, corr_msg_div: corrMsgDiv, corr_plot_div: corrPlotDiv };
  },

};

jQuery(document).ready(function () {
  var page = document.URL;

  if (
    page.match(/solgs\/traits\/all\//) != null ||
    page.match(/solgs\/models\/combined\/trials\//) != null
  ) {
    setTimeout(function () {
      solGS.correlation.populateGenCorrMenu();
    }, 5000);
  }
});

jQuery(document).ready(function () {
  jQuery("#corr_div").on("click", function (e) {
    var runCorrBtnId = e.target.id;

    var corrArgs;
    var corrPopId;
    if (runCorrBtnId.match(/run_corr/)) {
        corrArgs = solGS.correlation.getPhenoCorrArgs();
        corrPopId = corrArgs.corr_pop_id;

        if (!corrPopId) {
            corrArgs = solGS.correlation.getSelectedPopCorrArgs(runCorrBtnId);
         }

        if (!corrArgs.corr_pop_name) {
            corrArgs["corr_pop_name"] = solGS.correlation.getCorrPopName();
        }
    
        corrPopId = corrArgs.corr_pop_id;
        var canvas = solGS.correlation.canvas;
        var corrPlotDivId = solGS.correlation.corrPlotDivPrefix;
        corrPlotDivId = `${corrPlotDivId}_${corrPopId}`;

        var corrMsgDiv = solGS.correlation.corrMsgDiv;

        runCorrBtnId = `#${runCorrBtnId}`;
        jQuery(runCorrBtnId).hide();
        jQuery(`${canvas} .multi-spinner-container`).show();
        jQuery(corrMsgDiv).html("Running correlation... please wait...").show();

        solGS.correlation.runPhenoCorrelation(corrArgs).done(function (res) {
        if (res.status.match(/success/)) {
            corrArgs["corr_table_file"] = res.corre_table_file;    
            var corrDownload = solGS.correlation.createCorrDownloadLink(corrArgs);
            var heatmapArgs = {
              input_data: res.input_data,
              output_data: res.output_data,
              canvas: canvas,
              plot_div_id: corrPlotDivId,
              download_links: corrDownload
            };

            solGS.heatmap.plot(heatmapArgs);        
        } else {
            jQuery(corrMsgDiv).html(res.status + " There is no correlation output for this dataset.").fadeOut(8400);
        }

            jQuery(runCorrBtnId).show();
            jQuery(`${canvas} .multi-spinner-container`).hide();
            jQuery(corrMsgDiv).empty();
        });

    solGS.correlation.runPhenoCorrelation(corrArgs).fail(function (res) {
      jQuery(`${canvas} .multi-spinner-container`).hide();
      jQuery(corrMsgDiv).html("Error occured running the correlation analysis.").fadeOut(8400);
      jQuery(runCorrBtnId).show();
    });
  }});

  
  jQuery(document).on("click", "#run_genetic_correlation", function () {
    var corrPopId = jQuery("#corr_selected_pop_id").val();
    var popType = jQuery("#corr_selected_pop_type").val();

    var runCorrBtnId = "#run_genetic_correlation";

    jQuery(runCorrBtnId).hide();

    var args = solGS.correlation.getGeneticCorrArgs(corrPopId, popType);
    var canvas = args.canvas;
    var corrPlotDivId = args.corr_plot_div;
    var corrMsgDiv = args.corr_msg_div;

    jQuery(`${canvas} .multi-spinner-container`).show();
    var msg = "Running genetic correlation analysis...please wait...";
    jQuery(corrMsgDiv).html(msg).show();

    solGS.correlation
      .runGeneticCorrelation(args)
      .done(function (res) {
        if (res.status.match(/success/)) {
          args["corr_table_file"] = res.corre_table_file;
          var corrDownload = solGS.correlation.createCorrDownloadLink(args);
          var heatmapArgs = {
            input_data: res.input_data,
            output_data: res.output_data,
            canvas: canvas,
            plot_div_id: corrPlotDivId,
            download_links: corrDownload
          };
          solGS.heatmap.plot(heatmapArgs);
        } else {        
            jQuery(corrMsgDiv).html(res.status + " There is no correlation output for this dataset.").fadeOut(8400);
            
        }

        jQuery(`${canvas} .multi-spinner-container`).hide();
        jQuery(corrMsgDiv).empty();
        jQuery(runCorrBtnId).show();
      })
      .fail(function (res) {
        jQuery(`${canvas} .multi-spinner-container`).hide();
        jQuery(corrMsgDiv).html(res.status + " Error occured running correlation analysis.").fadeOut(8400);
        jQuery(runCorrBtnId).show();
        
      });
  });
});

jQuery(document).ready(function () {
  var corrPopsDiv = solGS.correlation.corrPopsDiv;
  jQuery(corrPopsDiv).change(function () {
    var selectedPop = jQuery("option:selected", this).data("pop");

    var selectedPopId = selectedPop.id;
    var selectedPopName = selectedPop.name;
    var selectedPopType = selectedPop.pop_type;

    jQuery("#corr_selected_pop_name").val(selectedPopName);
    jQuery("#corr_selected_pop_id").val(selectedPopId);
    jQuery("#corr_selected_pop_type").val(selectedPopType);
  });
});


jQuery(document).ready(function () {
  if (location.pathname.match(/correlation\/analysis/)) {
    corrPopsDataDiv = solGS.correlation.corrPopsDataDiv;
    var tableId = 'corr_pops_table';
    var corrPopsTable = solGS.correlation.createTable(tableId);
    jQuery(corrPopsDataDiv).append(corrPopsTable).show();

    var corrPops = solGS.correlation.getCorrPops();
    var corrPopsRows = solGS.correlation.getCorrPopsRows(corrPops);

    solGS.correlation.displayCorrPopsTable(tableId, corrPopsRows);

    jQuery("#create_new_list_dataset").show();

  }
});


jQuery(document).ready(function () {
  jQuery("#corr_canvas").on("click", "a", function (e) {
    var buttonId = e.target.id;
    var corrPlotId = buttonId.replace(/download_/, "");
    saveSvgAsPng(document.getElementById("#" + corrPlotId), corrPlotId + ".png", { scale: 1 });
  });

  jQuery("#si_corr_canvas").on("click", "a", function (e) {
    var buttonId = e.target.id;
    var corrPlotId = buttonId.replace(/download_/, "");
    saveSvgAsPng(document.getElementById("#" + corrPlotId), corrPlotId + ".png", { scale: 1 });
  });
});
