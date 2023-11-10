/**
 * kinship analysis call and result plotting using d3
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.kinship = {
  canvas: "#kinship_canvas",
  kinshipPlotDivPrefix: "#kinship_plot",
  kinshipMsgDiv: "#kinship_message",
  kinshipPopsSelectMenuId: "#kinship_pops_select",
  kinshipPopsDiv: "#kinship_pops_select_div",

  getKinshipArgs: function () {
    var page = location.pathname;
    var kinshipPopId;
    var kinshipUrlArgs;
    var dataStr;
    var trainingPopId;
    var selectionPopId;

    if (page.match(/solgs\/trait\/|solgs\/model\/combined\/trials\/|\/breeders\/trial\//)) {
      trainingPopId = jQuery("#training_pop_id").val();
      if (!trainingPopId) {
        trainingPopId = jQuery("#trial_id").val();
      }
      kinshipPopId = trainingPopId;
    } else if (page.match(/kinship\/analysis/)) {
      kinshipUrlArgs = this.getKinshipArgsFromUrl();
      kinshipPopId = kinshipUrlArgs.kinship_pop_id;
      dataStr = kinshipUrlArgs.data_structure;
      protocolId = kinshipUrlArgs.genotyping_protocol_id;
    } else if (page.match(/\/selection\/|\/prediction\//)) {
      selectionPopId = jQuery("#selection_pop_id").val();
      kinshipPopId = selectionPopId;
    } else if (page.match(/solgs\/traits\/all\/population\/|models\/combined\/trials\//)) {
      trainingPopId = jQuery("#training_pop_id").val();
      kinshipPopId = trainingPopId;
    }

    if (page.match(/combined/)) {
      var comboPopsId = trainingPopId;
    }

    var protocolId = jQuery("#genotyping_protocol_id").val();
    var traitId = jQuery("#trait_id").val();

    return {
      kinship_pop_id: kinshipPopId,
      training_pop_id: trainingPopId,
      combo_pops_id: comboPopsId,
      selection_pop_id: selectionPopId,
      data_structure: dataStr,
      genotyping_protocol_id: protocolId,
      trait_id: traitId,
      analysis_type: "kinship analysis",
    };
  },

  getKinshipArgsFromUrl: function () {
    var page = location.pathname;
    if (page == "/kinship/analysis/") {
      page = "/kinship/analysis";
    }
    var urlArgs = page.replace("/kinship/analysis", "");

    if (urlArgs) {
      var args = urlArgs.split(/\/+/);
      var selectId = args[1];
      var protocolId = args[3];

      var dataStr;
      var reg = /\d+/;
      var popId = selectId.match(reg)[0];
      if (selectId.match(/dataset/)) {
        dataStr = "dataset";
      } else if (selectId.match(/list/)) {
        dataStr = "list";
      }

      var args = {
        kinship_pop_id: popId,
        data_structure: dataStr,
        genotyping_protocol_id: protocolId,
      };

      return args;
    } else {
      return {};
    }
  },

  displaySelectedKinshipPop: function (selectedPop) {
    if (selectedPop.length === 0) {
      alert("The list is empty. Please select a list with content.");
    } else {
      var kinshipTable = jQuery("#kinship_pops_table").doesExist();

      if (kinshipTable == false) {
        kinshipTable = this.createTable();
        jQuery("#kinship_pops_selected").append(kinshipTable).show();
      }

      var newRow = this.selectRow(selectedPop);
      var kinshipPopId = `${selectedPop.data_str}_${selectedPop.id}`;
      var tdId = this.getTableTdId(kinshipPopId);
      var rowExists = jQuery(`#${tdId}`).doesExist();

      if (!rowExists) {
        jQuery("#kinship_pops_table tr:last").after(newRow);
      }
    }
  },

  getTableTdId: function (kinshipPopId) {
    return `kinship_${kinshipPopId}`;
  },

  selectRow: function (selectedPop) {
    var selectedId = selectedPop.id;
    var selectedName = selectedPop.name;
    var dataStr = selectedPop.data_str;

    var kinshipPopId = `${dataStr}_${selectedId}`;

    if (dataStr.match(/dataset/)) {
      datasetId = selectedId;
    } else if (dataStr.match(/list/)) {
      listId = selectedId;
    }

    var kinshipArgs = {
      kinship_pop_id: kinshipPopId,
      kinship_pop_name: selectedName,
      data_str: dataStr,
      data_structure: dataStr,
    };

    var runKinshipBtnId = this.getRunKinshipBtnId(kinshipPopId);

    kinshipArgs = JSON.stringify(kinshipArgs);
    var runKinshipBtn =
      `<button type="button" id=${runKinshipBtnId}` +
      ` class="btn btn-success" data-selected-pop='${kinshipArgs}'>Run kinship</button>`;

    var dataType = ["Genotype"];
    var dataTypeOpts = this.createDataTypeSelect(dataType);

    var tdId = this.getTableTdId(kinshipPopId);
    var newRow =
      `<tr  name="${kinshipPopId}" id="${kinshipPopId}">` +
      ` <td>${selectedName}</td>` +
      ` <td>${dataStr}</td>` +
      ` <td>${dataTypeOpts}</td>` +
      `<td id="${tdId}">` +
      runKinshipBtn +
      "</td>" +
      "<tr>";

    return newRow;
  },

  createTable: function () {
    var kinshipTable =
      '<table id="kinship_pops_table" class="table table-striped"><tr>' +
      "<th>Population</th>" +
      "<th>Data structure type</th>" +
      "<th>Data type</th>" +
      "<th>Run Kinship</th>" +
      "</tr>" +
      "</td></tr></table>";

    return kinshipTable;
  },

  createDataTypeSelect: function (opts) {
    var dataTypeGroup = '<select class="form-control" id="kinship_data_type_select">';

    for (var i = 0; i < opts.length; i++) {
      dataTypeGroup += '<option value="' + opts[i] + '">' + opts[i] + "</option>";
    }
    dataTypeGroup += "</select>";

    return dataTypeGroup;
  },

  getSelectedPopKinshipArgs: function (runKinshipElemId) {
    var kinshipArgs;

    // var runKinshipElemId = this.getRunKinshipId(kinshipPopId);
    var selectedPopDiv = document.getElementById(runKinshipElemId);
    if (selectedPopDiv) {
      var selectedPopData = selectedPopDiv.dataset;

      var kinshipArgs = JSON.parse(selectedPopData.selectedPop);
      var kinshipPopId = kinshipArgs.data_str + "_" + kinshipArgs.id;

      var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId("kinship_div");
      var page = `/kinship/analysis/${kinshipPopId}/gp/${protocolId}`;

      kinshipArgs["analysis_type"] = "kinship analysis";
      kinshipArgs["genotyping_protocol_id"] = protocolId;
      kinshipArgs["analysis_page"] = page;
      kinshipArgs["data_structure"] = kinshipArgs.data_str;
    }

    return kinshipArgs;
  },

  checkCachedKinship: function (page, args) {
    args = JSON.stringify(args);

    var checkCached = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        page: page,
        arguments: args,
      },
      url: "/solgs/check/cached/result/",
    });

    return checkCached;
  },

  runKinshipAnalysis: function (args) {
    var kinArgs = JSON.stringify(args);

    var runKinship = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: kinArgs },
      url: "/run/kinship/analysis/",
    });

    return runKinship;
  },

  addDowloandLinks: function (res) {
    var popName = res.kinship_pop_name;
    var kinFileId = res.kinship_file_id;
    var kinshipFile = res.kinship_table_file;

    var aveFile = res.kinship_averages_file;
    var inbreedingFile = res.inbreeding_file;

    var fileNameKinship = kinshipFile.split("/").pop();
    var fileNameAve = aveFile.split("/").pop();
    var fileNameInbreeding = inbreedingFile.split("/").pop();

    kinshipFile =
      '<a href="' + kinshipFile + '" download=' + fileNameKinship + ">Kinship matrix</a>";

    aveFile = '<a href="' + aveFile + '" download=' + fileNameAve + ">Average kinship</a>";

    inbreedingFile =
      '<a href="' +
      inbreedingFile +
      '" download=' +
      fileNameInbreeding +
      ">Inbreeding coefficients</a>";

    var kinDownloadBtn = "download_" + "kinship_plot_" + kinFileId;
    var kinPlotLink =
      "<a href='#'  onclick='event.preventDefault();' id='" + kinDownloadBtn + "'> plot</a>";

    var links = "<strong>Download:</strong> ";

    if (popName) {
      links = links + popName + " ";
    }

    links = links + kinshipFile + " | " + aveFile + " | " + inbreedingFile + " | " + kinPlotLink;

    return links;
  },

  populateKinshipPopsMenu: function () {
    var listTypes = ["accessions", "trials"];
    var datasetTypes = ["accessions", "trials"];
    var menuId = this.kinshipPopsSelectMenuId;
    var menu = new SelectMenu(menuId);
    var selectMenu = menu.getSelectMenuByTypes(listTypes, datasetTypes);

    var kinshipPopsDiv = this.kinshipPopsDiv;
    jQuery(kinshipPopsDiv).append(selectMenu).show();
  },

  getRunKinshipBtnId: function (rowId) {
    if (location.pathname.match(/kinship\/analysis/) && rowId) {
      return `run_kinship_${rowId}`;
    } else {
      return "run_kinship";
    }
  },

  getKinshipPopId: function (selectId, dataStr) {
    var kinshipPopId;
    if (dataStr) {
      kinshipPopId = `${dataStr}_${selectId}`;
    } else {
      kinshipPopId = selectId;
    }

    return kinshipPopId;
  },

  ///////
};

jQuery(document).ready(function () {
  jQuery("#kinship_div").on("click", function (e) {
    var runKinshipBtnId = e.target.id;
    if (runKinshipBtnId.match(/run_kinship/)) {
      var kinshipArgs = solGS.kinship.getKinshipArgs();
      var kinshipPopId = kinshipArgs.kinship_pop_id;
      if (!kinshipPopId) {
        kinshipArgs = solGS.kinship.getSelectedPopKinshipArgs(runKinshipBtnId);
      }
      kinshipPopId = kinshipArgs.kinship_pop_id;
      var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId("kinship_div");

      var canvas = solGS.kinship.canvas;
      var kinshipPlotDivId = solGS.kinship.kinshipPlotDivPrefix;
      var kinshipMsgDiv = solGS.kinship.kinshipMsgDiv;
      runKinshipBtnId = `#${runKinshipBtnId}`;
      var kinshipUrl = `/kinship/analysis/${kinshipPopId}/gp/${protocolId}`;
      //    solGS.kinship.generateKinshipUrl(kinshipPopId);
      kinshipArgs["analysis_page"] = kinshipUrl;

      jQuery(runKinshipBtnId).hide();
      jQuery(`${canvas} .multi-spinner-container`).show();

      jQuery(runKinshipBtnId).hide();
      jQuery(kinshipMsgDiv).text("Running kinship... please wait...it may take minutes.").show();

      jQuery(`${canvas} .multi-spinner-container`).show();
      solGS.kinship
        .checkCachedKinship(kinshipUrl, kinshipArgs)
        .done(function (res) {
          if (res.data) {
            jQuery(this.kinshipMsgDiv).html("Generating heatmap... please wait...").show();

            kinshipPlotDivId = `${kinshipPlotDivId}_${res.kinship_file_id}`;

            var links = solGS.kinship.addDowloandLinks(res);
            solGS.heatmap.plot(res.data, canvas, kinshipPlotDivId, links);

            jQuery(`${canvas} .multi-spinner-container`).hide();
            jQuery(kinshipMsgDiv).empty();
            jQuery(runKinshipBtnId).show();
          } else {

			jQuery(`${canvas} .multi-spinner-container`).hide();
            jQuery(kinshipMsgDiv).empty();

            var title =
              "<p>This analysis may take a long time. " +
              "Do you want to submit the analysis and get an email when it completes?</p>";

            var jobSubmit = '<div id= "kinship_submit">' + title + "</div>";

            jQuery(jobSubmit).appendTo("body");

            jQuery("#kinship_submit").dialog({
              height: "auto",
              width: "auto",
              modal: true,
              title: "Kinship job submission",
              buttons: {
                OK: {
                  text: "Yes",
                  class: "btn btn-success",
                  id: "queue_job",
                  click: function () {
                    jQuery(this).dialog("close");

                    solGS.submitJob.checkUserLogin(kinshipUrl, kinshipArgs);
                  },
                },

                No: {
                  text: "No, I will wait till it completes.",
                  class: "btn btn-warning",
                  id: "no_queue",
                  click: function () {
                    jQuery(this).dialog("close");

					jQuery(kinshipMsgDiv).text("Running kinship... please wait...it may take minutes.").show();
					jQuery(`${canvas} .multi-spinner-container`).show();

                    solGS.kinship
                      .runKinshipAnalysis(kinshipArgs)
                      .done(function (res) {
                        if (res.data) {
                          jQuery(kinshipMsgDiv)
                            .html("Generating heatmap... please wait...")
                            .show();

                          kinshipPlotDivId = `${kinshipPlotDivId}_${res.kinship_file_id}`;

                          var links = solGS.kinship.addDowloandLinks(res);
                          solGS.heatmap.plot(res.data, canvas, kinshipPlotDivId, links);

                          jQuery(`${canvas} .multi-spinner-container`).hide();
                          jQuery(kinshipMsgDiv).empty();
                          jQuery(runKinshipBtnId).show();
                        } else {
                          jQuery(`${canvas} .multi-spinner-container`).hide();
                          jQuery(kinshipMsgDiv)
                            .css({
                              "padding-left": "0px",
                            })
                            .html("This population has no kinship output data.")
                            .fadeOut(8400);

                          jQuery(runKinshipBtnId).show();
                        }
                      })
                      .fail(function () {
                        jQuery(this.kinshipMsgDiv)
                          .html("Error occured running the kinship.")
                          .show()
                          .fadeOut(8400);

                        jQuery(`${canvas} .multi-spinner-container`).hide();
                      });
                  },
                },

                Cancel: {
                  text: "Cancel",
                  class: "btn btn-info",
                  id: "cancel_queue_info",
                  click: function () {
                    jQuery(this).dialog("close");
                  },
                },
              },
            });
          }
        })
        .fail(function () {
          jQuery(kinshipMsgDiv).html("Error occured running the kinship.").show().fadeOut(8400);
          jQuery(`${canvas} .multi-spinner-container`).hide();
        });
    }
  });
});

jQuery(document).ready(function () {
  var url = location.pathname;

  if (url.match(/kinship\/analysis/)) {
    solGS.kinship.populateKinshipPopsMenu();
    var args = solGS.kinship.getKinshipArgsFromUrl();
    if (args.kinship_pop_id) {
      if (args.data_structure) {
        args["kinship_pop_id"] = args.data_structure + "_" + args.kinship_pop_id;
      }
      solGS.kinship.checkCachedKinship(url, args);
    }
  }
});

jQuery(document).ready(function () {
  jQuery("#kinship_canvas").on("click", "a", function (e) {
    var buttonId = e.target.id;
    var kinPlotId = buttonId.replace(/download_/, "");
    console.log(`buttonID ${buttonId} -- kinplotId: ${kinPlotId}`);
    saveSvgAsPng(document.getElementById("#" + kinPlotId), kinPlotId + ".png", { scale: 1 });
  });
});

jQuery(document).ready(function () {
  var url = location.pathname;

  if (url.match(/kinship\/analysis/)) {
    var kinshipPopsDiv = solGS.kinship.kinshipPopsSelectMenuId;
    jQuery(kinshipPopsDiv).change(function () {
      var selectedPop = jQuery("option:selected", this).data("pop");
      if (selectedPop.id) {
        jQuery("#kinship_pop_go_btn").click(function () {
          if (!selectedPop.data_str) {
            selectedPop.data_str = "list";
          }
          solGS.kinship.displaySelectedKinshipPop(selectedPop);
        });
      }
    });
  }
});
