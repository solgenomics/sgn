/**
 * Principal component analysis and scores plotting
 * using d3js
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.pca = {
  canvas: "#pca_canvas",
  pcaPlotDivPrefix: "#pca_plot",
  pcaMsgDiv: "#pca_message",
  pcaPopsDiv: "#pca_pops_select_div",
  pcaPopsSelectMenuId: "#pca_pops_select",

  getPcaArgs: function () {
    var page = location.pathname;
    var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId("pca_div");
    var dataType = this.getSelectedDataType();

    if (page.match(/pca\/analysis/)) {
      pcaArgs = this.getPcaArgsFromUrl();
    } else {
      var pcaPopId;
      var trainingPopId;
      var selectionPopId;
      var dataType;
      var dataStr;

      var trainingPopId = jQuery("#training_pop_id").val();
      if (page.match(/solgs\/trait\/|solgs\/model\/combined\/trials\/|\/breeders\/trial\//)) {
        if (!trainingPopId) {
          trainingPopId = jQuery("#trial_id").val();
        }
        pcaPopId = trainingPopId;
      } else if (page.match(/\/selection\/|\/prediction\//)) {
        selectionPopId = jQuery("#selection_pop_id").val();
        pcaPopId = selectionPopId;
      } else if (page.match(/solgs\/traits\/all\/population\/|models\/combined\/trials\//)) {
        pcaPopId = trainingPopId;
      }

      var traitId = jQuery("#trait_id").val();

      if (page.match(/combined/)) {
        var dataSetType = "combined_populations";
        var comboPopsId = trainingPopId;
        if (comboPopsId) {
          var dataSetType = "combined_populations";
        }
      }

      pcaArgs = {
        pca_pop_id: pcaPopId,
        training_pop_id: trainingPopId,
        combo_pops_id: comboPopsId,
        selection_pop_id: selectionPopId,
        data_structure: dataStr,
        data_type: dataType,
        data_set_type: dataSetType,
        genotyping_protocol_id: protocolId,
        trait_id: traitId,
        analysis_type: "pca analysis",
      };
    }

    return pcaArgs;
  },

  getPcaArgsFromUrl: function () {
    var page = location.pathname;
    if (page == "/pca/analysis/") {
      page = "/pca/analysis";
    }

    var urlArgs = page.replace("/pca/analysis", "");

    var pcaPopId;
    var traitId;
    var protocolId;

    if (urlArgs) {
      var args = urlArgs.split(/\/+/);
      if (urlArgs.match(/trait/)) {
        pcaPopId = args[1];
        traitId = args[3];
        protocolId = args[5];
      } else {
        pcaPopId = args[1];
        protocolId = args[3];
      }

      var dataType;
      if (protocolId) {
        dataType = "genotype";
      } else {
        dataType = "phenotype";
      }

      var dataStr;
      var listId;
      var datasetId;

      if (pcaPopId.match(/dataset/)) {
        dataStr = "dataset";
        datasetId = pcaPopId.replace(/dataset_/, "");
      } else if (pcaPopId.match(/list/)) {
        dataStr = "list";
        listId = pcaPopId.replace(/list_/, "");
      }

      var args = {
        pca_pop_id: pcaPopId,
        list_id: listId,
        trait_id: traitId,
        dataset_id: datasetId,
        data_structure: dataStr,
        data_type: dataType,
        genotyping_protocol_id: protocolId,
      };

      var reg = /\d+-+\d+/;
      if (pcaPopId.match(reg)) {
        var ids = pcaPopId.split("-");
        args["training_pop_id"] = ids[0];
        args["selection_pop_id"] = ids[1];
      }
      return args;
    } else {
      return {};
    }
  },

  getRunPcaId: function (pcaPopId) {
    if (pcaPopId) {
      return `run_pca_${pcaPopId}`;
    } else {
      return "run_pca";
    }
  },

  displaySelectedPcaPop: function (selectedPop) {
    if (selectedPop.length === 0) {
      alert("The list is empty. Please select a list with content.");
    } else {
      var pcaTable = jQuery("#pca_pops_table").doesExist();

      if (pcaTable == false) {
        pcaTable = this.createTable();
        jQuery("#pca_pops_selected").append(pcaTable).show();
      }

      var addRow = this.selectRow(selectedPop);
      var pcaPopId = `${selectedPop.data_str}_${selectedPop.id}`;
      var tdId = "#pca_" + pcaPopId;
      var addedRow = jQuery(tdId).doesExist();

      if (addedRow == false) {
        jQuery("#pca_pops_table tr:last").after(addRow);
      }
    }
  },

  populatePcaPopsMenu: function () {
    var listTypes = ["accessions", "plots", "trials"];
    var datasetTypes = ["accessions", "trials"];
    var menuId = this.pcaPopsSelectMenuId;
    var menu = new SelectMenu(menuId);
    var selectMenu = menu.getSelectMenuByTypes(listTypes, datasetTypes);
    var pcaPopsDiv = this.pcaPopsDiv;
    jQuery(pcaPopsDiv).append(selectMenu).show();
  },

  selectRow: function (selectedPop) {
    var selectedId = selectedPop.id;
    var selectedName = selectedPop.name;
    var dataStr = selectedPop.data_str;

    var pcaPopId = `${dataStr}_${selectedId}`;
    var listId;
    var datasetId;

    if (dataStr.match(/dataset/)) {
      datasetId = selectedId;
    } else if (dataStr.match(/list/)) {
      listId = selectedId;
    }
    var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId("pca_div");
    var pcaArgs = {
      pca_pop_id: pcaPopId,
      data_structure: dataStr,
      dataset_id: datasetId,
      list_id: listId,
      pca_pop_name: selectedName,
      genotyping_protocol_id: protocolId,
      analysis_type: "pca analysis",
    };

    var runPcaId = this.getRunPcaId(pcaPopId);

    pcaArgs = JSON.stringify(pcaArgs);
    var onClickVal = `<button type="button" id=${runPcaId} class="btn btn-success" data-selected-pop='${pcaArgs}'>Run PCA</button>`;

    var dataType = ["Genotype", "Phenotype"];
    var dataTypeOpts = this.createDataTypeSelect(dataType, pcaPopId);

    var addRow =
      '<tr  id="' +
      pcaPopId +
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
      '<td id="pca_' +
      pcaPopId +
      '">' +
      onClickVal +
      "</td>" +
      "<tr>";

    return addRow;
  },

  getSelectedPopPcaArgs: function (runPcaElemId) {
    var pcaArgs;

    // var runPcaElemId = this.getRunPcaId(pcaPopId);
    var selectedPopDiv = document.getElementById(runPcaElemId);
    if (selectedPopDiv) {
      var selectedPopData = selectedPopDiv.dataset;

      var selectedPop = JSON.parse(selectedPopData.selectedPop);
      pcaPopId = selectedPop.pca_pop_id;

      var dataType = this.getSelectedDataType(pcaPopId);
      var pcaUrl = this.generatePcaUrl(pcaPopId);

      pcaArgs = selectedPopData.selectedPop;
      pcaArgs = JSON.parse(pcaArgs);
      pcaArgs["data_type"] = dataType;
      pcaArgs["analysis_page"] = pcaUrl;
    }

    return pcaArgs;
  },

  checkCachedPca: function (pcaArgs) {
    if (document.URL.match(/pca\/analysis/)) {
      var message = this.validatePcaParams(pcaArgs);

      if (message) {
        jQuery(this.pcaMsgDiv).prependTo(jQuery(this.canvas)).html(message).show().fadeOut(9400);
      }

      var page = pcaArgs.analysis_page;
    }
    pcaArgs = JSON.stringify(pcaArgs);

    var checkCache = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        page: page,
        arguments: pcaArgs,
      },
      url: "/solgs/check/cached/result/",
    });

    return checkCache;
  },

  // optJobSubmission: function (page, args) {
  //   var title =
  //     "<p>This analysis may take a long time. " +
  //     "Do you want to submit the analysis and get an email when it completes?</p>";

  //   var jobSubmit = '<div id= "pca_submit">' + title + "</div>";

  //   jQuery(jobSubmit).appendTo("body");

  //   jQuery("#pca_submit").dialog({
  //     height: 200,
  //     width: 400,
  //     modal: true,
  //     title: "pca job submission",
  //     buttons: {
  //       OK: {
  //         text: "Yes",
  //         class: "btn btn-success",
  //         id: "queue_job",
  //         //   click: function () {
  //         //     jQuery(this).dialog("close");
  //         //     solGS.submitJob.checkUserLogin(page, args);
  //         //   },
  //       },

  //       No: {
  //         text: "No, I will wait till it completes.",
  //         class: "btn btn-warning",
  //         id: "no_queue",
  //         // click: function () {
  //         //   jQuery(this).dialog("close");

  //         //   solGS.pca.runPcaAnalysis(args);
  //         // },
  //       },

  //       Cancel: {
  //         text: "Cancel",
  //         class: "btn btn-info",
  //         id: "cancel_queue_info",
  //         click: function () {
  //           jQuery(this).dialog("close");
  //         },
  //       },
  //     },
  //   });
  // },

  pcaDataTypeSelectId: function (pcaPopId) {
    if (location.pathname.match(/pca\/analysis/) && pcaPopId) {
      return `pca_data_type_select_${pcaPopId}`;
    } else {
      return "pca_data_type_select";
    }
  },

  getSelectedDataType: function (pcaPopId) {
    var dataType;
    if (pcaPopId) {
      var pcaDataSelectedId = this.pcaDataTypeSelectId(pcaPopId);
      dataType = jQuery("#" + pcaDataSelectedId).val();
    } else {
      dataType = jQuery("#pca_data_type_select").val();
    }

    return dataType;
  },

  runPcaAnalysis: function (pcaArgs) {
    pcaArgs = JSON.stringify(pcaArgs);

    var pcaAnalysis = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        arguments: pcaArgs,
      },
      url: "/run/pca/analysis",
    });

    return pcaAnalysis;
  },

  validatePcaParams: function (valArgs) {
    var dataType = valArgs.data_type;
    var dataStr = valArgs.data_structure;
    var pcaPopId = valArgs.pca_pop_id;
    var msg;

    if (dataStr && dataStr.match("list")) {
      var listId = pcaPopId.replace(/\w+_/, "");
      var list = new CXGN.List();
      var listType = list.getListType(listId);

      if (listType.match(/accessions/) && dataType.match(/phenotype/i)) {
        msg = "With list of clones, you can only do PCA based on <em>genotype</em>.";
      }

      if (listType.match(/plots/) && dataType.match(/genotype/i)) {
        msg = "With list of plots, you can only do PCA based on <em>phenotype</em>.";
      }
    }

    return msg;
  },

  createTable: function () {
    var pcaTable =
      '<table id="pca_pops_table" class="table table-striped"><tr>' +
      "<th>Population</th>" +
      "<th>Data structure type</th>" +
      "<th>Data type</th>" +
      "<th>Run PCA</th>" +
      "</tr>" +
      "</td></tr></table>";

    return pcaTable;
  },

  createDataTypeSelect: function (opts, pcaPopId) {
    var pcaDataTypeId = this.pcaDataTypeSelectId(pcaPopId);
    var dataTypeGroup = '<select class="form-control" id="' + pcaDataTypeId + '">';

    for (var i = 0; i < opts.length; i++) {
      dataTypeGroup += '<option value="' + opts[i] + '">' + opts[i] + "</option>";
    }
    dataTypeGroup += "</select>";

    return dataTypeGroup;
  },

  getPcaGenotypesListData: function (listId) {
    var list = new CXGN.List();

    if (!listId == "") {
      var listName = list.listNameById(listId);
      var listType = list.getListType(listId);

      return {
        name: listName,
        listType: listType,
      };
    } else {
      return;
    }
  },

  setListId: function (listId) {
    var existingListId = jQuery("#list_id").doesExist();

    if (existingListId) {
      jQuery("#list_id").remove();
    }

    jQuery(this.canvas).append('<input type="hidden" id="list_id" value=' + listId + "></input>");
  },

  getListId: function () {
    var listId = jQuery("#list_id").val();
    return listId;
  },

  pcaDownloadLinks: function (res) {
    var screePlotFile = res.scree_plot_file;
    var scoresFile = res.scores_file;
    var loadingsFile = res.loadings_file;
    var variancesFile = res.variances_file;

    var screePlot = screePlotFile.split("/").pop();
    var screePlotLink = '<a href="' + screePlotFile + '" download=' + screePlot + ">Scree plot</a>";

    var scores = scoresFile.split("/").pop();

    var scoresLink = '<a href="' + scoresFile + '" download=' + scores + "> Scores </a>";

    var loadings = loadingsFile.split("/").pop();

    var loadingsLink = '<a href="' + loadingsFile + '" download=' + loadings + ">Loadings</a>";

    var variances = variancesFile.split("/").pop();

    var variancesLink = '<a href="' + variancesFile + '" download=' + variances + ">Variances</a>";

    var plotId = res.pca_pop_id.replace(/-/g, "_");
    var pcaDownloadBtn = "download_pca_plot_" + plotId;
    pcaPlot =
      "<a href='#'  onclick='event.preventDefault();' id='" + pcaDownloadBtn + "'>PCA plot</a>";

    var downloadLinks =
      screePlotLink +
      " | " +
      scoresLink +
      " | " +
      variancesLink +
      " | " +
      loadingsLink +
      " | " +
      pcaPlot;

    return downloadLinks;
  },

  structurePlotData: function (res) {
    var listId = res.list_id;
    var listName;

    if (listId) {
      var list = new CXGN.List();
      listName = list.listNameById(listId);
    }

    var plotData = {
      scores: res.scores,
      variances: res.variances,
      loadings: res.loadings,
      pca_pop_id: res.pca_pop_id,
      list_id: listId,
      list_name: listName,
      trials_names: res.trials_names,
      output_link: res.output_link,
      data_type: res.data_type,
    };

    return plotData;
  },

  generatePcaUrl: function (pcaPopId) {
    var traitId = jQuery("#trait_id").val();
    var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId("pca_div");

    var solgsPages =
      "solgs/population/" +
      "|solgs/populations/combined/" +
      "|solgs/trait/" +
      "|solgs/model/combined/trials/" +
      "|solgs/selection/\\d+|\\w+_\\d+/model/" +
      "|solgs/combined/model/\\d+|\\w+_\\d+/selection/" +
      "|solgs/models/combined/trials/" +
      "|solgs/traits/all/population/";

    var url = "/pca/analysis/" + pcaPopId;

    var dataType;
    if (location.pathname.match(solgsPages)) {
      url = url + "/trait/" + traitId;
    }

    var pcaDataSelectedId = this.pcaDataTypeSelectId(pcaPopId);
    dataType = jQuery("#" + pcaDataSelectedId).val();

    if (dataType.match(/genotype/i)) {
      url = url + "/gp/" + protocolId;
    }

    return url;
  },

  cleanUpOnSuccess: function (pcaPopId) {

    jQuery(this.pcaMsgDiv).empty();
    jQuery(`${this.canvas} .multi-spinner-container`).hide();
    jQuery(`#${this.getRunPcaId(pcaPopId)}`).show();

  },

  feedBackOnFailure: function (pcaPopId, msg) {
    jQuery(`${this.canvas} .multi-spinner-container`).hide();

    jQuery(this.pcaMsgDiv)
      .html(msg)
      .fadeOut(8400);

      jQuery(`#${this.getRunPcaId(pcaPopId)}`).show();

  },


  plotPca: function (plotData, downloadLinks) {
    var scores = plotData.scores;
    var variances = plotData.variances;
    var loadings = plotData.loadings;
    var trialsNames = plotData.trials_names;

    var pc12 = [];
    var pc1 = [];
    var pc2 = [];
    var trials = [];

    jQuery.each(scores, function (i, pc) {
      pc12.push([
        {
          name: pc[0],
          pc1: parseFloat(pc[2]),
          pc2: parseFloat(pc[3]),
          trial: pc[1],
        },
      ]);
      pc1.push(parseFloat(pc[2]));
      pc2.push(parseFloat(pc[3]));

      if (!trials.includes(pc[1])) {
        trials.push(pc[1]);
      }
    });

    var height = 400;
    var width = 400;
    var pad = {
      left: 60,
      top: 20,
      right: 40,
      bottom: 20,
    };
    var totalH = height + pad.top + pad.bottom + 100;
    var totalW = width + pad.left + pad.right + 400;

    var pcaCanvasDivId = this.canvas;
    var pcaPlotDivId = plotData.pca_pop_id.replace(/-/g, "_");
    pcaPlotDivId = "pca_plot_" + pcaPlotDivId;

    jQuery(pcaCanvasDivId).append("<div id=" + pcaPlotDivId + "></div>");
    pcaPlotDivId = "#" + pcaPlotDivId;

    var svg = d3
      .select(pcaPlotDivId)
      .insert("svg", ":first-child")
      .attr("width", totalW)
      .attr("height", totalH);

    var pcaPlot = svg.append("g").attr("id", pcaPlotDivId).attr("transform", "translate(0,0)");

    var pc1Min = d3.min(pc1);
    var pc1Max = d3.max(pc1);

    var pc1Limits = d3.max([Math.abs(d3.min(pc1)), d3.max(pc1)]);
    var pc2Limits = d3.max([Math.abs(d3.min(pc2)), d3.max(pc2)]);

    var pc1AxisScale = d3.scale
      .linear()
      .domain([0, pc1Limits])
      .range([0, width / 2]);

    var pc1AxisLabel = d3.scale
      .linear()
      .domain([-1 * pc1Limits, pc1Limits])
      .range([0, width]);

    var pc2AxisScale = d3.scale
      .linear()
      .domain([0, pc2Limits])
      .range([0, height / 2]);

    var pc1Axis = d3.svg.axis().scale(pc1AxisLabel).tickSize(3).orient("bottom");

    var pc2AxisLabel = d3.scale
      .linear()
      .domain([-1 * pc2Limits, pc2Limits])
      .range([height, 0]);

    var pc2Axis = d3.svg.axis().scale(pc2AxisLabel).tickSize(3).orient("left");

    var pc1AxisMid = 0.5 * height + pad.top;
    var pc2AxisMid = 0.5 * width + pad.left;

    var verMidLineData = [
      {
        x: pc2AxisMid,
        y: pad.top,
      },
      {
        x: pc2AxisMid,
        y: pad.top + height,
      },
    ];

    var rightNudge = 5;
    var horMidLineData = [
      {
        x: pad.left,
        y: pad.top + height / 2,
      },
      {
        x: pad.left + width + rightNudge,
        y: pad.top + height / 2,
      },
    ];

    var lineFunction = d3.svg
      .line()
      .x(function (d) {
        return d.x;
      })
      .y(function (d) {
        return d.y;
      })
      .interpolate("linear");

    var pc1Color = "green";
    var pc2Color = "red";
    var axisValColor = "#86B404";
    var labelFs = 12;

    pcaPlot
      .append("g")
      .attr("class", "PC1 axis")
      .attr("transform", "translate(" + pad.left + "," + (pad.top + height) + ")")
      .call(pc1Axis)
      .selectAll("text")
      .attr("y", 0)
      .attr("x", 10)
      .attr("dy", ".1em")
      .attr("transform", "rotate(90)")
      .attr("fill", pc1Color)
      .style({
        "text-anchor": "start",
        fill: axisValColor,
      });

    pcaPlot
      .append("g")
      .attr("transform", "translate(" + pc1AxisMid + "," + height + ")")
      .append("text")
      .text("PC1 (" + variances[0][1] + "%)")
      .attr("y", pad.top + 40)
      .attr("x", 0)
      .attr("font-size", labelFs)
      .style("fill", pc1Color);

    pcaPlot
      .append("g")
      .attr("transform", "translate(" + pad.left + "," + pc2AxisMid + ")")
      .append("text")
      .text("PC2 (" + variances[1][1] + "%)")
      .attr("y", -40)
      .attr("x", 0)
      .attr("transform", "rotate(-90)")
      .attr("font-size", labelFs)
      .style("fill", pc2Color);

    pcaPlot
      .append("g")
      .attr("class", "PC2 axis")
      .attr("transform", "translate(" + pad.left + "," + pad.top + ")")
      .call(pc2Axis)
      .selectAll("text")
      .attr("y", 0)
      .attr("x", -10)
      .style("fill", axisValColor);

    pcaPlot
      .append("path")
      .attr("d", lineFunction(verMidLineData))
      .attr("stroke", pc2Color)
      .attr("stroke-width", 1)
      .attr("fill", "none");

    pcaPlot
      .append("path")
      .attr("d", lineFunction(horMidLineData))
      .attr("stroke", pc1Color)
      .attr("stroke-width", 1)
      .attr("fill", "none");

    var grpColor = d3.scale.category10();

    pcaPlot
      .append("g")
      .selectAll("circle")
      .data(pc12)
      .enter()
      .append("circle")
      .style("fill", function (d) {
        return grpColor(d[0].trial);
      })
      .attr("r", 3)
      .attr("cx", function (d) {
        var xVal = d[0].pc1;
        if (xVal >= 0) {
          return pad.left + width / 2 + pc1AxisScale(xVal);
        } else {
          return pad.left + width / 2 - -1 * pc1AxisScale(xVal);
        }
      })
      .attr("cy", function (d) {
        var yVal = d[0].pc2;

        if (yVal >= 0) {
          return pad.top + height / 2 - pc2AxisScale(yVal);
        } else {
          return pad.top + height / 2 + -1 * pc2AxisScale(yVal);
        }
      })
      .on("mouseover", function (d) {
        d3.select(this).attr("r", 5).style("fill", axisValColor);
        pcaPlot
          .append("text")
          .attr("id", "dLabel")
          .style("fill", axisValColor)
          .text(d[0].name + "(" + d[0].pc1 + "," + d[0].pc2 + ")")
          .attr("x", width + pad.left + rightNudge)
          .attr("y", height / 2);
      })
      .on("mouseout", function (d) {
        d3.select(this)
          .attr("r", 3)
          .style("fill", function (d) {
            return grpColor(d[0].trial);
          });
        d3.selectAll("text#dLabel").remove();
      });

    pcaPlot
      .append("rect")
      .attr("transform", "translate(" + pad.left + "," + pad.top + ")")
      .attr("height", height)
      .attr("width", width + rightNudge)
      .attr("fill", "none")
      .attr("stroke", "#523CB5")
      .attr("stroke-width", 1)
      .attr("pointer-events", "none");

    var popName = "";
    if (plotData.list_name) {
      popName = plotData.list_name;
    }

    popName = popName ? popName + " (" + plotData.data_type + ")" : " (" + plotData.data_type + ")";
    var dld = "Download PCA " + popName + ": ";

    if (downloadLinks) {
      jQuery(pcaPlotDivId).append('<p style="margin-left: 40px">' + dld + downloadLinks + "</p>");
    }

    if (trialsNames && Object.keys(trialsNames).length > 1) {
      var trialsIds = jQuery.uniqueSort(trials);
      trialsIds = jQuery.uniqueSort(trialsIds);

      var legendValues = [];
      var cnt = 0;
      var allTrialsNames = [];

      for (var tr in trialsNames) {
        allTrialsNames.push(trialsNames[tr]);
      }

      trialsIds.forEach(function (id) {
        var groupName = [];

        if (id.match(/\d+-\d+/)) {
          var ids = id.split("-");

          ids.forEach(function (id) {
            groupName.push(trialsNames[id]);
          });

          groupName = "common: " + groupName.join(",");
        } else {
          groupName = trialsNames[id];
        }

        legendValues.push([cnt, id, groupName]);
        cnt++;
      });

      var recLH = 20;
      var recLW = 20;
      var legendXOrig = pad.left + 10 + width;
      var legendYOrig = height * 0.25;

      var legend = pcaPlot
        .append("g")
        .attr("class", "cell")
        .attr("transform", "translate(" + legendXOrig + "," + legendYOrig + ")")
        .attr("height", 100)
        .attr("width", 100);

      legend = legend
        .selectAll("rect")
        .data(legendValues)
        .enter()
        .append("rect")
        .attr("x", function (d) {
          return 1;
        })
        .attr("y", function (d) {
          return 1 + d[0] * recLH + d[0] * 5;
        })
        .attr("width", recLH)
        .attr("height", recLW)
        .style("stroke", "black")
        .attr("fill", function (d) {
          return grpColor(d[1]);
        });

      var legendTxt = pcaPlot
        .append("g")
        .attr(
          "transform",
          "translate(" + (legendXOrig + 30) + "," + (legendYOrig + 0.5 * recLW) + ")"
        )
        .attr("id", "legendtext");

      legendTxt
        .selectAll("text")
        .data(legendValues)
        .enter()
        .append("text")
        .attr("fill", "#523CB5")
        .style("fill", "#523CB5")
        .attr("x", 1)
        .attr("y", function (d) {
          return 1 + d[0] * recLH + d[0] * 5;
        })
        .text(function (d) {
          return d[2];
        })
        .attr("dominant-baseline", "middle")
        .attr("text-anchor", "start");
    }
  },

  ////////
};
/////

jQuery(document).ready(function () {
  var url = location.pathname;
  var canvas = solGS.pca.canvas;

  if (url.match(/pca\/analysis/)) {
    solGS.pca.populatePcaPopsMenu();

    var pcaArgs = solGS.pca.getPcaArgsFromUrl();
    var pcaPopId = pcaArgs.pca_pop_id;
    if (pcaPopId) {
      if (pcaArgs.data_structure && !pcaPopId.match(/list|dataset/)) {
        pcaArgs["pca_pop_id"] = pcaArgs.data_structure + "_" + pcaPopId;
      }
      pcaArgs["analysis_page"] = url;

      solGS.pca.checkCachedPca(pcaArgs).done(function (res) {
        if (res.scores) {
          var plotData = solGS.pca.structurePlotData(res);
          var downloadLinks = solGS.pca.pcaDownloadLinks(res);
          solGS.pca.plotPca(plotData, downloadLinks);
        }
      });
    }
  }

  jQuery(canvas).on("click", "a", function (e) {
    var buttonId = e.target.id;
    var pcaPlotId = buttonId.replace(/download_/, "");
    saveSvgAsPng(document.getElementById("#" + pcaPlotId), pcaPlotId + ".png", { scale: 2 });
  });
});

jQuery(document).ready(function () {
  var url = location.pathname;

  if (url.match(/solgs\/selection\/|solgs\/combined\/model\/\d+\/selection\//)) {
    jQuery("#pca_data_type_select").html('<option selected="genotype">Genotype</option>');
  }

  var pcaPopsDiv = solGS.pca.pcaPopsSelectMenuId;

  if (url.match(/pca\/analysis/)) {
    jQuery("<option>", {
      value: "",
      selected: true,
    }).prependTo(pcaPopsDiv);

    var pcaPopsDiv = solGS.pca.pcaPopsSelectMenuId;
    jQuery(pcaPopsDiv).change(function () {
      var selectedPop = jQuery("option:selected", this).data("pop");

      if (selectedPop.id) {
        jQuery("#pca_pop_go_btn").click(function () {
          if (!selectedPop.data_str) {
            selectedPop.data_str = "list";
          }
          solGS.pca.displaySelectedPcaPop(selectedPop);
        });
      }
    });
  }
});

jQuery(document).ready(function () {
  jQuery("#pca_div").on("click", function (e) {
    var runPcaBtnId = e.target.id;
    if (runPcaBtnId.match(/run_pca/)) {
      var pcaArgs = solGS.pca.getPcaArgs();
      var pcaPopId = pcaArgs.pca_pop_id;
      if (!pcaPopId) {
        pcaArgs = solGS.pca.getSelectedPopPcaArgs(runPcaBtnId);
      }
      pcaPopId = pcaArgs.pca_pop_id;
      var canvas = solGS.pca.canvas;
      // var pcaPlotDivId = solGS.pca.pcaPlotDivPrefix;
      var pcaMsgDiv = solGS.pca.pcaMsgDiv;
      runPcaBtnId = `#${runPcaBtnId}`;
      var pcaUrl = solGS.pca.generatePcaUrl(pcaPopId);
      pcaArgs["analysis_page"] = pcaUrl;

      jQuery(runPcaBtnId).hide();
      jQuery(`${canvas} .multi-spinner-container`).show();
      jQuery(pcaMsgDiv).html("Running pca... please wait...").show();

      solGS.pca
        .checkCachedPca(pcaArgs)
        .done(function (res) {
          if (res.scores) {
            var plotData = solGS.pca.structurePlotData(res);
            var downloadLinks = solGS.pca.pcaDownloadLinks(res);
            solGS.pca.plotPca(plotData, downloadLinks);

             solGS.pca.cleanUpOnSuccess(pcaPopId);
          } else {
            var page = location.pathname;
            var pcaUrl = solGS.pca.generatePcaUrl(pcaArgs.pca_pop_id);
            pcaArgs["analysis_page"] = pcaUrl;

            var title =
              "<p>This analysis may take a long time. " +
              "Do you want to submit the analysis and get an email when it completes?</p>";

            var jobSubmit = '<div id= "pca_submit">' + title + "</div>";

            jQuery(jobSubmit).appendTo("body");

            jQuery("#pca_submit").dialog({
              height: 200,
              width: 400,
              modal: true,
              title: "pca job submission",
              buttons: {
                OK: {
                  text: "Yes",
                  class: "btn btn-success",
                  id: "queue_job",
                  click: function () {
                    jQuery(this).dialog("close");
                    solGS.submitJob.checkUserLogin(pcaUrl, pcaArgs);
                  },
                },

                No: {
                  text: "No, I will wait till it completes.",
                  class: "btn btn-warning",
                  id: "no_queue",
                  click: function () {
                    jQuery(this).dialog("close");

                    solGS.pca
                      .runPcaAnalysis(pcaArgs)
                      .done(function (res) {
                        if (res.scores) {
                          var downloadLinks = solGS.pca.pcaDownloadLinks(res);
                          var plotData = solGS.pca.structurePlotData(res);
                          solGS.pca.plotPca(plotData, downloadLinks);

                          solGS.pca.cleanUpOnSuccess(pcaPopId);
                        } else {
                          var msg = "There is no PCA output for this dataset.";
                          solGS.pca.feedBackOnFailure(pcaPopId, msg);
                        }
                      })
                      .fail(function (res) {
                        var msg = "Error occured running the PCA.";
                        solGS.pca.feedBackOnFailure(pcaPopId, msg);
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
            jQuery(jobSubmit).show();

            jQuery("#queue_job").on("click", function (e) {
              solGS.submitJob.checkUserLogin(page, args);
            });

            jQuery("#queue_no").on("click", function (e) {
              solGS.pca
                .runPcaAnalysis(pcaArgs)
                .done(function (res) {
                  if (res.scores) {
                    var plotData = solGS.pca.structurePlotData(res);
                    var downloadLinks = solGS.pca.pcaDownloadLinks(res);
                    solGS.pca.plotPca(plotData, downloadLinks);

                   solGS.pca.cleanUpOnSuccess(pcaPopId);
                  } else {
                    var msg = "There is no PCA output for this dataset.";
                    solGS.pca.feedBackOnFailure(pcaPopId, msg);
                  }
                })
                .fail(function (res) {
                  var msg = "Error occured running the PCA.";
                        solGS.pca.feedBackOnFailure(pcaPopId,msg);
                });
            });
          }
        })
        .fail(function () {
          var msg = "Error occured checking for cached output.";
          solGS.pca.feedBackOnFailure(pcaPopId,msg);
        });
    }
  });
});

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};
