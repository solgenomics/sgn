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

  getPhenoCorrArgs: function () {
    var corrPopId = jQuery("#corr_pop_id").val();
    var dataSetType = jQuery("#data_set_type").val();
    var dataStr = jQuery("#data_structure").val();

    var listId;
    var datasetId;

    if (dataStr.match(/dataset/)) {
      datasetId = selectId;
    } else if (dataStr.match(/list/)) {
      listId = selectId;
    }

    var corrDivs = this.getCorrDivs(corrPopId);

    var args = {
      corr_pop_id: corrPopId,
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

  displaySelectedCorrPop: function (selectedPop) {
    var corrPopId = this.getCorrPopId(selectedPop.id, selectedPop.data_str);
    if (selectedPop.length === 0) {
      alert("The list is empty. Please select a list with content.");
    } else {
      var tableId = "corr_pops_list_table";
      var corrTable = jQuery("#" + tableId).doesExist();
      if (corrTable == false) {
        corrTable = this.getCorrPopsTable(tableId);
        jQuery("#corr_pops_selected").append(corrTable).show();
      }

      var addRow = this.selectRow(selectedPop);
      var tdId = "#corr_" + corrPopId;
      var addedRow = jQuery(tdId).doesExist();

      if (addedRow == false) {
        jQuery("#" + tableId + " tr:last").after(addRow);
      }
    }
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
      '<table class="table table-striped" id="' +
      tableId +
      '">' +
      "<thead>" +
      "<tr>" +
      "<th>Name</th>" +
      "<th>Data structure</th>" +
      "<th>Data type</th>" +
      "<th>Run correlation</th>" +
      "</tr>" +
      "</thead></table>";

    return table;
  },

  selectRow: function (selectedPop) {
    var selectedId = selectedPop.id;
    var selectedName = selectedPop.name;
    var dataStr = selectedPop.data_str;

    var corrPopId = this.getCorrPopId(selectedId, dataStr);

    // var dataTypeOpts = this.getDataTypeOpts({
    // 	'select_id': selectId,
    // 	'data_str': dataStr
    // })
    var dataTypeOpts = ["Phenotype"];
    dataTypeOpts = this.createDataTypeSelect(dataTypeOpts, corrPopId);

    var listId;
    var datasetId;

    if (dataStr.match(/dataset/)) {
      datasetId = selectedId;
    } else if (dataStr.match(/list/)) {
      listId = selectedId;
    }

    var runCorrBtnId = this.getRunCorrBtnId(corrPopId);
    var corrDivs = this.getCorrDivs(corrPopId);

    var correArgs = {
      corr_pop_id: corrPopId,
      data_structure: dataStr,
      dataset_id: datasetId,
      list_id: listId,
      corre_pop_name: selectedName,
      data_type: "phenotype",
      correlation_type: "phenotypic",
      canvas: corrDivs.canvas,
      corr_plot_div: corrDivs.corr_plot_div,
      corr_msg_div: corrDivs.corr_msg_div,
    };

    correArgs = JSON.stringify(correArgs);
    var onClickVal = `<button type="button" id=${runCorrBtnId} class="btn btn-success" data-selected-pop='${correArgs}'>Run correlation</button>`;

    var row =
      '<tr name="' +
      dataStr +
      '"' +
      ' id="' +
      corrPopId +
      '">' +
      "<td>" +
      selectedName +
      "</td>" +
      "<td>" +
      dataStr +
      "</td>" +
      "<td>" +
      dataTypeOpts +
      "</td>" +
      '<td id="corr_' +
      corrPopId +
      '">' +
      onClickVal +
      "</td>" +
      "<tr>";

    return row;
  },

  corrDataTypeSelectId: function (rowId) {
    if (location.pathname.match(/correlation\/analysis/) && rowId) {
      return `corr_data_type_select_${rowId}`;
    } else {
      return "corr_data_type_select";
    }
  },

  getRunCorrBtnId: function (rowId) {
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

  populateGenCorrMenu: function () {
    var modelData = solGS.getModelArgs();
    modelData = {
      id: modelData.training_pop_id,
      name: modelData.training_pop_name,
      pop_type: 'training'
    }
    var corrPops = [modelData];

    if (!modelData.id.match(/list/)) {
      var trialSelPopsList = solGS.selectionPopulation.getPredictedTrialTypeSelectionPops();

      if (trialSelPopsList) {
        corrPops.push(trialSelPopsList);
      }
    }

    var listTypeSelPopsTable = jQuery("#list_type_selection_pops_table").length;
    if (listTypeSelPopsTable) {
      var listTypeSelPops = solGS.listTypeSelectionPopulation.getListTypeSelPopulations();
      if (listTypeSelPops) {
        corrPops.push(listTypeSelPops);
      }
    }

    var menuId = this.corrPopsSelectMenuId;
    var menu = new SelectMenu(menuId);
    corrPops = corrPops.flat();
    var menuElem = menu.addOptions(corrPops);
    var corrPopDiv = this.corrPopsDiv;
    jQuery(corrPopDiv).empty().append(menuElem).show();
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

    var popName = corrArgs.corre_pop_name;
    if (!popName) {
      popName = jQuery("#corr_selected_pop_name").val();
    }
    if (!popName) {
      popName = jQuery("#training_pop_name").val();
    }
    if (!popName) {
      popName = jQuery("#trial_name").val();
    }

    var downloadLinks = `Download ${popName} correlation: ` + corrCoefLink + " | " + corrPlotLink;
    return downloadLinks;
  },

  showCorrProgress: function (canvas, msg) {
    var msgDiv;
    if (canvas === "#si_canvas") {
      msgDiv = "#si_corr_message";
    } else {
      msgDiv = "#corr_message";
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
      corrMsgDiv = solGS.sIndex.siMsgDiv; //"#si_corr_message";
      corrPlotDiv = `${this.corrPlotDivPrefix}_${sIndexName}`;
    } else {
      canvas = this.canvas;
      corrMsgDiv = this.corrMsgDiv;
      corrPlotDiv = `${this.corrPlotDivPrefix}_${corrPopId}`;
    }

    return { canvas: canvas, corr_msg_div: corrMsgDiv, corr_plot_div: corrPlotDiv };
  },

  populateCorrPopsMenu: function () {
    var listTypes = ["plots", "trials"];
    var datasetTypes = ["accessions", "plots", "trials"];
    var menuId = this.corrPopsSelectMenuId;
    var menu = new SelectMenu(menuId);
    var selectMenu = menu.getSelectMenuByTypes(listTypes, datasetTypes);

    var corrPopsDiv = this.corrPopsDiv;
    jQuery(corrPopsDiv).append(selectMenu).show();
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
      solGS.correlation.populateGenCorrMenu();
    }, 5000);
  }
});

jQuery(document).ready(function () {
  var runCorrBtnId = "#run_pheno_correlation";

  jQuery(runCorrBtnId).click(function () {
    var args = solGS.correlation.getPhenoCorrArgs();
    var canvas = args.canvas;
    var corrPlotDivId = args.corr_plot_div;
    var corrMsgDiv = args.corr_msg_div;

    jQuery(runCorrBtnId).hide();
    jQuery(`${canvas} .multi-spinner-container`).show();
    jQuery(corrMsgDiv).html("Running correlation... please wait...").show();

    solGS.correlation.runPhenoCorrelation(args).done(function (res) {
      if (res.data) {
        args["corr_table_file"] = res.corre_table_file;
        var corrDownload = solGS.correlation.createCorrDownloadLink(args);

        solGS.heatmap.plot(res.data, canvas, corrPlotDivId, corrDownload);

        jQuery(`${canvas} .multi-spinner-container`).hide();
        jQuery(corrMsgDiv).empty();
        jQuery(runCorrBtnId).hide();
      } else {
        jQuery(`${canvas} .multi-spinner-container`).hide();

        jQuery(corrMsgDiv).html("There is no correlation output for this dataset.").fadeOut(8400);

        jQuery(runCorrBtnId).show();
      }
    });

    solGS.correlation.runPhenoCorrelation(args).fail(function (res) {
      jQuery(`${canvas} .multi-spinner-container`).hide();

      jQuery(corrMsgDiv).html("Error occured running the correlation analysis.").fadeOut(8400);

      jQuery(runCorrBtnId).show();
    });
  });

  jQuery(document).ready(function () {
    jQuery("#corr_pops_selected").on("click", "button", function (e) {
      var runCorrBtnId = e.target.id;

      var selectedPopDiv = document.getElementById(runCorrBtnId);
      var args;
      if (selectedPopDiv) {
        var selectedPopData = selectedPopDiv.dataset;
        args = selectedPopData.selectedPop;
      }

      args = JSON.parse(args);
      var canvas = args.canvas;
      var corrPlotDivId = args.corr_plot_div;
      var corrMsgDiv = args.corr_msg_div;

      runCorrBtnId = `#${runCorrBtnId}`;
      jQuery(runCorrBtnId).hide();
      jQuery(`${canvas} .multi-spinner-container`).show();
      jQuery(corrMsgDiv).html("Running correlation... please wait...").show();
      solGS.correlation
        .runPhenoCorrelation(args)
        .done(function (res) {
          if (res.data) {
            args["corr_table_file"] = res.corre_table_file;
            var corrDownload = solGS.correlation.createCorrDownloadLink(args);

            solGS.heatmap.plot(res.data, canvas, corrPlotDivId, corrDownload);

            jQuery(`${canvas} .multi-spinner-container`).hide();
            jQuery(corrMsgDiv).empty();
            jQuery(runCorrBtnId).show();
          } else {
            jQuery(`${canvas} .multi-spinner-container`).hide();

            jQuery(corrMsgDiv)
              .html("There is no correlation output for this dataset.")
              .fadeOut(8400);

            jQuery(runCorrBtnId).show();
          }
        })
        .fail(function (res) {
          jQuery(`${canvas} .multi-spinner-container`).hide();

          jQuery(corrMsgDiv).html("Error occured running the correlation analysis.").fadeOut(8400);

          jQuery(runCorrBtnId).show();
        });
    });
  });

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
          solGS.heatmap.plot(res.data, canvas, corrPlotDivId, corrDownload);
        } else {
          jQuery(corrMsgDiv).html(res.status).fadeOut(8400);
        }

        jQuery(`${canvas} .multi-spinner-container`).hide();
        jQuery(corrMsgDiv).empty();
        jQuery(runCorrBtnId).show();
      })
      .fail(function (res) {
        jQuery(corrMsgDiv).html("Error occured running correlation analysis.").fadeOut(8400);
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
  var corrPopsDiv = solGS.correlation.corrPopsDiv;
  jQuery(corrPopsDiv).change(function () {

    var selectedPop = jQuery("option:selected", this).data("pop");
    if (selectedPop.id) {
      jQuery("#corr_pop_go_btn").click(function () {
        if (!selectedPop.data_str) {
          selectedPop.data_str = "list";
        }
        solGS.correlation.displaySelectedCorrPop(selectedPop);
      });
    }
  });
});

jQuery(document).ready(function () {
  var url = location.pathname;
  if (url.match(/correlation\/analysis/)) {
    solGS.correlation.populateCorrPopsMenu();
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
