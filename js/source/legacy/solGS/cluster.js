/**
 * K-means and hierarchical cluster analysis and vizualization
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() { };

solGS.cluster = {
  canvas: "#cluster_canvas",
  clusterPlotDivPrefix: "#cluster_plot",
  clusterMsgDiv: "#cluster_message",
  clusterPopsDiv: "#cluster_pops_select_div",
  clusterPopsSelectMenuId: "#cluster_pops_select",
  clusterPopsDataDiv: "#cluster_pops_data_div",

  getClusterArgsFromUrl: function () {
    var page = location.pathname;
    if (page == "/cluster/analysis/") {
      page = "/cluster/analysis";
    }

    var urlArgs = page.replace("/cluster/analysis", "");

    var clusterPopId;
    var traitId;
    var protocolId;
    var kNumber;
    var dataType;
    var sIndexName;
    var selectionProp;
    var traitsCode;
    var clusterType;

    if (urlArgs) {
      var args = urlArgs.split(/\/+/);
      clusterPopId = args[1];
      clusterType = args[3];
      dataType = args[5];
      kNumber = args[7];

      if (urlArgs.match(/traits/)) {
        traitsCode = args[9];
      }

      if (urlArgs.match(/selPop/)) {
        selectionProp = args[11];
      }

      protocolId = args.pop();

      if (!dataType.match(/phenotype|genotype|gebv/)) {
        sIndexName = dataType;
        dataType = "genotype";
      }

      var dataStr;
      var listId;
      var datasetId;

      if (clusterPopId.match(/dataset/)) {
        dataStr = "dataset";
        datasetId = clusterPopId.replace(/dataset_/, "");
      } else if (clusterPopId.match(/list/)) {
        dataStr = "list";
        listId = clusterPopId.replace(/list_/, "");
      }

      var args = {
        cluster_pop_id: clusterPopId,
        data_type: dataType,
        k_number: kNumber,
        sindex_name: sIndexName,
        selection_proportion: selectionProp,
        list_id: listId,
        trait_id: traitId,
        training_traits_code: traitsCode,
        dataset_id: datasetId,
        data_structure: dataStr,
        genotyping_protocol_id: protocolId,
        cluster_type: clusterType,
      };

      var reg = /\.+-\.+/;
      if (clusterPopId.match(reg)) {
        var ids = clusterPopId.split("-");
        args["training_pop_id"] = ids[0];
        args["selection_pop_id"] = ids[1];
      }
      return args;
    } else {
      return {};
    }
  },

  getClusterPopId: function (selectedId, dataStr) {

    var clusterPopId;
    if (dataStr) {
      clusterPopId = `${dataStr}_${selectedId}`;
    } else {
      clusterPopId = selectedId;
    }

    return clusterPopId;
  },

  createClusterTypeSelect: function (rowId) {
    var clusterTypeId = this.clusterTypeSelectId(rowId);
    var clusterTypeGroup =
      '<div id="cluster_type_opts"><select class="form-control" id="' +
      clusterTypeId +
      '">' +
      '<option value="k-means">K-Means</option>' +
      '<option value="hierarchical">Hierarchical</option>' +
      "</select></div>";

    return clusterTypeGroup;
  },

  clusterTypeSelectId: function (rowId) {
    if (location.pathname.match(/cluster\/analysis/) && rowId) {
      return `cluster_type_select_${rowId}`;
    } else {
      return "cluster_type_select";
    }
  },

  clusterDataTypeSelectId: function (rowId) {
    if (location.pathname.match(/cluster\/analysis/) && rowId) {
      return `cluster_data_type_select_${rowId}`;
    } else {
      return "cluster_data_type_select";
    }
  },

  clusterKnumSelectId: function (rowId) {
    if (location.pathname.match(/cluster\/analysis/) && rowId) {
      return `k_number_input_${rowId}`;
    } else {
      return "k_number_input";
    }
  },

  clusterSelPropSelectId: function (rowId) {
    if (location.pathname.match(/cluster\/analysis/) && rowId) {
      return `selection_proportion_input_${rowId}`;
    } else {
      return "selection_proportion_input";
    }
  },

  getRunClusterBtnId: function (rowId) {
    if (location.pathname.match(/cluster\/analysis/) && rowId) {
      return `run_cluster_${rowId}`;
    } else {
      return "run_cluster";
    }
  },

  createDataTypeSelect: function (opts, rowId) {
    var clusterDataTypeId = this.clusterDataTypeSelectId(rowId);
    var dataTypeGroup = '<select class="form-control" id="' + clusterDataTypeId + '">';

    for (var i = 0; i < opts.length; i++) {
      dataTypeGroup += '<option value="' + opts[i] + '">' + opts[i] + "</option>";
    }
    dataTypeGroup += "</select>";

    return dataTypeGroup;
  },

  getDataTypeOpts: function (args) {

    var popType;
    if (args) {
      popType = args.type;
    }

    var dataTypeOpts = [];
    var page = location.pathname;

    if (page.match(/breeders\/trial/)) {
      dataTypeOpts = ["Genotype", "Phenotype"];
    } else if (page.match(/solgs\/trait\/\d+\/population\/|solgs\/model\/combined\/trials\//)) {
      dataTypeOpts = ["Genotype"];
    } else {
      if (!popType) {
        popType = "undef";
      }

      if (popType.match(/^selection$/)) {
        dataTypeOpts = ["Genotype", "GEBV"];
      } else if (popType.match(/selection_index/)) {
        dataTypeOpts = ["Genotype"];
      } else {
        dataTypeOpts = ["Genotype", "GEBV", "Phenotype"];
      }
    }

    return dataTypeOpts;
  },

  createRowElements: function (clusterPop) {
    var popId = clusterPop.id;
    var popName = clusterPop.name;
    var dataStr = clusterPop.data_str;

    var clusterPopId = solGS.cluster.getClusterPopId(popId, dataStr);
    var clusterTypeOpts = solGS.cluster.createClusterTypeSelect(clusterPopId);

    var dataTypes;
    if (location.pathname.match(/pca\/analysis/)) {
      dataTypes = clusterPop.data_type;
    } else {
      dataTypes = this.getDataTypeOpts();
    }

    var dataTypeOpts = solGS.cluster.createDataTypeSelect(dataTypes, clusterPopId);
    var kNumId = solGS.cluster.clusterKnumSelectId(clusterPopId);
    var runClusterBtnId = solGS.cluster.getRunClusterBtnId(clusterPopId);

    var kNum = '<input class="form-control" type="text" placeholder="3" id="' + kNumId + '"/>';

    var clusterArgs = JSON.stringify(clusterPop);

    var runClusterBtn =
      `<button type="button" id=${runClusterBtnId}` +
      ` class="btn btn-success" data-selected-pop='${clusterArgs}'>Run cluster</button>`;

    if (dataStr.match(/dataset/)) {
      popName = `<a href="/dataset/${popId}">${popName}</a>`;
    }
    var rowData = [popName,
      dataStr, clusterPop.owner, clusterTypeOpts,
      dataTypeOpts, kNum, runClusterBtn, `${dataStr}_${popId}`];

    return rowData;
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
      "<th>Ownership</th>" +
      "<th>Clustering method</th>" +
      "<th>Data type</th>" +
      "<th>No. of  clusters (K)</th>" +
      "<th>Run cluster</th>" +
      "</tr>" +
      "</thead></table>";

    return table;
  },

  clusterResult: function (clusterArgs) {
    var clusterPopId = clusterArgs.cluster_pop_id;
    var clusterType = clusterArgs.cluster_type;
    var kNumber = clusterArgs.k_number;
    var dataType = clusterArgs.data_type;
    var selectionProp = clusterArgs.selection_proportion;
    var selectedId = clusterArgs.selected_id;
    var selectedName = clusterArgs.selected_name;
    var dataStr = clusterArgs.data_structure;

    dataType = dataType.toLowerCase();
    clusterType = clusterType.toLowerCase();
    var protocolId = jQuery("#cluster_div #genotyping_protocol #genotyping_protocol_id").val();

    if (!protocolId) {
      protocolId = solGS.genotypingProtocol.getGenotypingProtocolId("cluster_div");
    }

    var trainingTraitsIds = jQuery("#training_traits_ids").val();

    if (trainingTraitsIds) {
      trainingTraitsIds = trainingTraitsIds.split(",");
    }

    if (!trainingTraitsIds) {
      var traitId = jQuery("#trait_id").val();
      trainingTraitsIds = [traitId];
    }

    if (trainingTraitsIds == "") {
      trainingTraitsIds = [];
    }

    var popDetails = solGS.getPopulationDetails();
    if (!popDetails) {
      popDetails = {};
    }

    var popId;
    var popType;
    var popName;

    var page = location.pathname;
    if (!page.match(/cluster\/analysis/)) {
      if (
        page.match(/solgs\/trait\/\d+\/population\/|solgs\/model\/combined\/populations\/|breeders\//)
      ) {
        popId = popDetails.training_pop_id;
        popName = popDetails.training_pop_name;
        popType = "training";
      } else if (page.match(/solgs\/selection\/|solgs\/model\/combined\/trials\//)) {
        popId = popDetails.selection_pop_id;
        popName = popDetails.selection_pop_name;
        popType = "selection";
      } else {
        popId = jQuery("#cluster_selected_pop_id").val();
        popType = jQuery("#cluster_selected_pop_type").val();
        popName = jQuery("#cluster_selected_pop_name").val();

      }
    }

    if (!selectedName) {
      selectedName = popName;
    }

    if (!selectedId) {
      selectedId = popId;
    }

    var validateArgs = {
      data_id: selectedId,
      data_structure: dataStr,
      data_type: dataType,
      selection_proportion: selectionProp,
      pop_type: popType,
    };

    var message = this.validateClusterParams(validateArgs);
    var url = location.pathname;

    var clusterMsgDiv = this.clusterMsgDiv;

    if (message != undefined) {
      jQuery(clusterMsgDiv).html(message).show().fadeOut(9400);
    } else {
      if (url.match(/solgs\/models\/combined\/trials\//)) {
        if (popType.match(/training/)) {
          popDetails["combo_pops_id"] = popId;
        } else if (popType.match(/selection/)) {
          popDetails["selection_pop_id"] = popId;
        }
      }

      var listId;
      var datasetId;
      var datasetName;
      var sIndexName;

      if (String(selectedId).match(/list/)) {
        dataStr = "list";
      } else if (String(selectedId).match(/dataset/)) {
        dataStr = "dataset";
      }

      if (dataStr == "list") {
        if (isNaN(selectedId)) {
          listId = selectedId.replace("list_", "");
        } else {
          listId = selectedId;
        }
      } else if (dataStr == "dataset") {
        if (isNaN(selectedId)) {
          datasetId = selectedId.replace("dataset_", "");
        } else {
          datasetId = selectedId;
        }

        datasetName = selectedName;
      }

      if (!clusterPopId) {
        if (url.match(/solgs\/trait\//)) {
          clusterPopId = popDetails.training_pop_id;
        } else if (url.match(/solgs\/selection\//)) {
          clusterPopId = popDetails.selection_pop_id;
        } else if (url.match(/combined/)) {
          clusterPopId = jQuery("#combo_pops_id").val();
        }
      }

      if (popType == "selection_index") {
        sIndexName = selectedName;
      }

      var traitsCode;

      var page;
      var fileId = clusterPopId;
      if (location.pathname.match(/cluster\/analysis/)) {
        page =
          "/cluster/analysis/" +
          clusterPopId +
          "/ct/" +
          clusterType +
          "/dt/" +
          dataType +
          "/k/" +
          kNumber;
        if (dataType.match(/genotype/i)) {
          page = page + "/gp/" + protocolId;
        }
      } else {
        traitsCode = jQuery("#training_traits_code").val();
        if (
          popType.match(/selection/) &&
          location.pathname.match(/solgs\/traits\/all\/|solgs\/models\/combined\/trials\//)
        ) {
          popDetails["selection_pop_id"] = clusterPopId;
          fileId = popDetails.training_pop_id + "-" + clusterPopId;
        }
        if (sIndexName) {
          page =
            "/cluster/analysis/" +
            fileId +
            "/ct/" +
            clusterType +
            "/dt/" +
            sIndexName +
            "/k/" +
            kNumber;
        } else {
          page =
            "/cluster/analysis/" +
            fileId +
            "/ct/" +
            clusterType +
            "/dt/" +
            dataType +
            "/k/" +
            kNumber;

          if (traitsCode) {
            page = page + "/traits/" + traitsCode;
          } else {
            page = page + "/traits/" + "undefined";
          }

          if (selectionProp) {
            page = page + "/sp/" + selectionProp;
          } else {
            page = page + "/sp/" + "undefined";
          }

          page = page + "/gp/" + protocolId;
        }
      }
      var clusterArgs = {
        training_pop_id: popDetails.training_pop_id,
        selection_pop_id: popDetails.selection_pop_id,
        combo_pops_id: popDetails.combo_pops_id,
        training_traits_ids: trainingTraitsIds,
        training_traits_code: traitsCode,
        cluster_pop_id: clusterPopId,
        list_id: listId,
        cluster_type: clusterType,
        data_structure: dataStr,
        dataset_id: datasetId,
        dataset_name: datasetName,
        data_type: dataType,
        k_number: kNumber,
        selection_proportion: selectionProp,
        sindex_name: sIndexName,
        cluster_pop_name: selectedName || "",
        genotyping_protocol_id: protocolId,
        analysis_type: "cluster analysis",
        analysis_page: page,
      };

      return clusterArgs;
    }
  },

  checkCachedCluster: function (page, args) {
    if (typeof args !== "string") {
      args = JSON.stringify(args);
    }

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

  runClusterAnalysis: function (clusterArgs) {
    var clusterPopId;
    if (typeof clusterArgs == "string") {
      clusterArgs = JSON.parse(clusterArgs);
      clusterType = clusterArgs.cluster_type;
      clusterPopId = clusterArgs.cluster_pop_id;
      runClusterBtnId = this.getRunClusterBtnId(clusterPopId);
    } else {
      clusterType = clusterArgs.cluster_type;
      clusterPopId = clusterArgs.cluster_pop_id;
      runClusterBtnId = this.getRunClusterBtnId(clusterPopId);
    }

    if (typeof clusterArgs !== "string") {
      clusterArgs = JSON.stringify(clusterArgs);
    }

    var runAnalysis = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        arguments: clusterArgs,
      },
      url: "/run/cluster/analysis",
    });

    return runAnalysis;

  },

  validateClusterParams: function (valArgs) {
    var popType = valArgs.pop_type;
    var dataType = valArgs.data_type;
    var selectionProp = valArgs.selection_proportion;
    var dataStr = valArgs.data_structure;
    var dataId = valArgs.data_id;
    var msg;

    if (popType == "selection_index") {
      if (dataType.match(/phenotype/i) || dataType.match(/gebv/i)) {
        msg =
          "K-means clustering for selection index type" + " data works with genotype data only.";
      }

      if (dataType.match(/genotype/i) != null && !selectionProp) {
        msg =
          "The selection proportion value is empty." +
          " You need to define the fraction of the" +
          " population you want to select.";
      }
    }

    if (dataStr == "list") {
      var list = new CXGN.List();

      if (isNaN(dataId)) {
        dataId = dataId.replace(/list_/, "");
      }

      var listType = list.getListType(dataId);

      if (listType == "accessions" && dataType.match(/phenotype/i)) {
        msg = "With list of clones, you can only cluster based on <em>genotype</em>.";
      }

      if (listType == "plots" && dataType.match(/genotype/i)) {
        msg = "With list of plots, you can only cluster based on <em>phenotype</em>.";
      }
    }

    return msg;
  },

  createClusterDownloadLinks: function (res) {
    var popName = res.cluster_pop_name || "";
    var clusterPlotFileName = res.cluster_plot.split("/").pop();
    var plotType;
    var outFileType;
    var clustersFile;
    var elbowPlotFile;
    var kclusterMeansFile;
    var kclusterVariancesFile;

    if (clusterPlotFileName.match(/k-means/i)) {
      plotType = "K-means plot";
      outFileType = "Clusters";
      clustersFile = res.kmeans_clusters;
      elbowPlotFile = res.elbow_plot;
      kclusterVariancesFile = res.kcluster_variances;
      kclusterMeansFile = res.kcluster_means;
    } else {
      plotType = "Dendrogram";
      outFileType = "Newick tree format";
      clustersFile = res.newick_file;
    }

    var clusterPlotLink =
      '<a href="' +
      res.cluster_plot +
      '" download=' +
      clusterPlotFileName +
      '">' +
      plotType +
      "</a>";

    var clustersFileName = clustersFile.split("/").pop();
    var clustersLink =
      '<a href="' + clustersFile + '" download=' + clustersFileName + '">' + outFileType + "</a>";

    var elbowLink;
    var kclusterMeansLink;
    var kclusterVariancesLink;

    if (elbowPlotFile) {
      var elbowFileName = elbowPlotFile.split("/").pop();
      elbowLink = '<a href="' + elbowPlotFile + '" download=' + elbowFileName + '">Elbow plot</a>';

      if (kclusterMeansFile) {
        var kclusterMeansFileName = kclusterMeansFile.split("/").pop();
        kclusterMeansLink =
          '<a href="' +
          kclusterMeansFile +
          '" download=' +
          kclusterMeansFileName +
          '">Cluster means</a>';
      }

      var kclusterVariancesFileName = kclusterVariancesFile.split("/").pop();
      kclusterVariancesLink =
        '<a href="' +
        kclusterVariancesFile +
        '" download=' +
        kclusterVariancesFileName +
        '">Cluster variances </a>';
    }

    var reportFile = res.cluster_report;
    var reportFileName = reportFile.split("/").pop();
    var reportLink =
      '<a href="' + reportFile + '" download=' + reportFileName + '">Analysis Report </a>';

    var downloadLinks =
      " <strong>Download " +
      popName +
      " </strong>: " +
      clusterPlotLink +
      " | " +
      clustersLink +
      " | " +
      reportLink;

    if (elbowPlotFile) {
      if (kclusterMeansLink) {
        downloadLinks += " | " + kclusterMeansLink;
      }

      downloadLinks += " | " + kclusterVariancesLink + " | " + elbowLink;
    }

    return downloadLinks;
  },

  plotClusterOutput: function (res) {

    var imageId = res.plot_name;
    imageId = 'id="' + imageId + '"';
    var plot = "<img " + imageId + ' src="' + res.cluster_plot + '">';

    var downloadLinks = this.createClusterDownloadLinks(res);
    jQuery("#cluster_plot").prepend('<p style="margin-top: 20px">' + downloadLinks + "</p>");
    jQuery("#cluster_plot").prepend(plot);
    //     // solGS.dendrogram.plot(res.json_data, '#cluster_canvas', '#cluster_plot', downloadLinks)
  },

  getClusterPopsTable: function (tableId) {
    var clusterTable = this.createTable(tableId);
    return clusterTable;
  },

  runCluster: function (selectedId, selectedName, dataStr) {
    var clusterPopId = this.getClusterPopId(selectedId, dataStr);
    var clusterOpts = solGS.cluster.clusteringOptions(clusterPopId);
    var clusterType = clusterOpts.cluster_type || "k-means";
    var kNumber = clusterOpts.k_number || 3;
    var dataType = clusterOpts.data_type || "genotype";

    var clusterArgs = {
      selected_id: selectedId,
      selected_name: selectedName,
      data_structure: dataStr,
      cluster_pop_id: clusterPopId,
      cluster_type: clusterType,
      data_type: dataType,
      k_number: kNumber,
    };

    this.clusterResult(clusterArgs);
  },

  clusteringOptions: function (clusterPopId) {
    var clusterTypeId = this.clusterTypeSelectId(clusterPopId);
    var kNumId = this.clusterKnumSelectId(clusterPopId);
    var dataTypeId = this.clusterDataTypeSelectId(clusterPopId);
    var selectionPropId = this.clusterSelPropSelectId(clusterPopId);

    var dataType = jQuery("#" + dataTypeId).val() || "genotype";
    var clusterType = jQuery("#" + clusterTypeId).val() || "k-means";
    var kNumber = jQuery("#" + kNumId).val() || 3;
    var selectionProp = jQuery("#" + selectionPropId).val();

    if (typeof kNumber === "string") {
      kNumber = kNumber.replace(/\s+/g, "");
    }

    if (selectionProp) {
      selectionProp = selectionProp.replace(/%/, "");
      selectionProp = selectionProp.replace(/\s+/g, "");
    }

    return {
      data_type: dataType,
      cluster_type: clusterType,
      k_number: kNumber,
      selection_proportion: selectionProp,
    };
  },

  
  displayClusterPopsTable: function (tableId, data) {

    var table = jQuery(`#${tableId}`).DataTable({
      'searching': true,
      'ordering': true,
      'processing': true,
      'paging': true,
      'info': false,
      'pageLength': 5,
      'rowId': function (a) {
        return a[7]
      }
    });

    table.rows.add(data).draw();

  },


  getClusterPopsRows: function(clusterPops) {

    var clusterPopsRows = [];

    for (var i = 0; i < clusterPops.length; i++) {
      if (clusterPops[i]) {
        var clusterPopRow = this.createRowElements(clusterPops[i]);
        clusterPopsRows.push(clusterPopRow);
      }
    }

    return clusterPopsRows;

  },

  getClusterPops: function () {
    var list = new solGSList();
    var lists = list.getLists(["accessions", "plots", "trials"]);
    lists = list.addDataStrAttr(lists);
    lists = list.addDataTypeAttr(lists);

    var datasets = solGS.dataset.getDatasetPops(["accessions", "trials"]);
    datasets = solGS.dataset.addDataTypeAttr(datasets);
    clusterPops = [lists, datasets];

    return clusterPops.flat();

  },


  getSelectedPopClusterArgs: function (runClusterElemId) {
    var clusterArgs;

    var selectedPopDiv = document.getElementById(runClusterElemId);
    if (selectedPopDiv) {
      var selectedPopData = selectedPopDiv.dataset;

      clusterArgs = JSON.parse(selectedPopData.selectedPop);
      var clusterPopId = clusterArgs.data_str + "_" + clusterArgs.id;

      var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId("cluster_div");

      clusterArgs["analysis_type"] = "cluster analysis";
      clusterArgs["genotyping_protocol_id"] = protocolId;
      clusterArgs["cluster_pop_id"] = clusterPopId;
      clusterArgs["data_structure"] = clusterArgs.data_str;
    }

    return clusterArgs;
  },

  populateClusterMenu: function (newPop) {
    var modelData = solGS.selectMenuModelArgs();
    var clusterPops = [modelData];

    if (modelData.id.match(/list/) == null) {
      var trialSelPopsList = solGS.selectionPopulation.getPredictedTrialTypeSelectionPops();
      if (trialSelPopsList) {
        clusterPops.push(trialSelPopsList);
      }
    }
  
    var menu = new SelectMenu(this.clusterPopsDiv, this.clusterPopsSelectMenuId);

    if (newPop){
        menu.updateOptions(newPop);   
    } else {
      menu.populateMenu(clusterPops);
    }

  },
};

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};

jQuery(document).ready(function () {
  var url = location.pathname;

  if (url.match(/cluster\/analysis/)) {
    solGS.cluster.populateClusterMenu();
    var canvas = solGS.cluster.canvas;
    var clusterMsgDiv = solGS.cluster.clusterMsgDiv;

    var clusterArgs = solGS.cluster.getClusterArgsFromUrl();
    var clusterPopId = clusterArgs.cluster_pop_id;
    if (clusterPopId) {
      jQuery(clusterMsgDiv).text("Running cluster... please wait...it may take minutes.").show();

      jQuery(`${canvas} .multi-spinner-container`).show();

      solGS.cluster.checkCachedCluster(url, clusterArgs).done(function (res) {
        if (res.result == "success") {
          solGS.cluster.plotClusterOutput(res);

          jQuery(clusterMsgDiv).empty();
          jQuery(`${canvas} .multi-spinner-container`).hide();
        }
      });
    }
  }
});

jQuery(document).ready(function () {
  jQuery("#cluster_div").on("change", "#cluster_type_opts", function () {
    var rowId = jQuery(this).closest("tr").attr("id");

    var clusterTypeId = solGS.cluster.clusterTypeSelectId(rowId);
    var kNumId = solGS.cluster.clusterKnumSelectId(rowId);
    var clusterDataTypeId = solGS.cluster.clusterDataTypeSelectId(rowId);
    var clusterType = jQuery("#" + clusterTypeId).val();
    var clusterDataType = jQuery("#" + clusterDataTypeId).val();
    if (clusterType.match(/hierarchical/i)) {
      jQuery("#k_number_div").hide();
      jQuery("#" + kNumId).prop("disabled", true);
    } else {
      jQuery("#k_number_div").show();
      jQuery("#" + kNumId).prop("disabled", false);
    }
  });
});

jQuery(document).ready(function () {

  jQuery("#cluster_div").on("change", "#cluster_selected_pop", function () {
    var rowId = jQuery(this).closest("tr").attr("id");

    var popType = jQuery("#cluster_selected_pop_type").val();
    var clusterTypeId = solGS.cluster.clusterTypeSelectId(rowId);

    var clusterDataType = jQuery("#" + clusterDataTypeId).val();
  });
});

jQuery(document).ready(function () {
  jQuery("#cluster_div").on("click", function (e) {
    var runClusterBtnId = e.target.id;
    if (runClusterBtnId.match(/run_cluster/)) {
      jQuery(clusterMsgDiv).text("Running cluster... please wait...it may take minutes.").show();

      jQuery(`${canvas} .multi-spinner-container`).show();

      var canvas = solGS.cluster.canvas;
      var clusterMsgDiv = solGS.cluster.clusterMsgDiv;
      var runClusterBtnId;
      var popType;
      var page = location.pathname;
      var selectedId, selectedName, dataStr;
      if (page.match(/cluster\/analysis/)) {
        var clusterArgs = solGS.cluster.getSelectedPopClusterArgs(runClusterBtnId);
        selectedId = clusterArgs.id;
        selectedName = clusterArgs.name;
        dataStr = clusterArgs.data_str;

      } else if (page.match(/breeders\/trial\//)) {
        selectedId = jQuery("#trial_id").val();
        selectedName = jQuery("#trial_name").val();
      } else {
        selectedId = jQuery("#cluster_selected_pop_id").val();
        selectedName = jQuery("#cluster_selected_pop_name").val();
        var popType = jQuery("#cluster_selected_pop_type").val();

        if (popType) {
          if (popType.match(/list/)) {
            dataStr = "list";
          } else if (popType.match(/dataset/)) {
            dataStr = "dataset";
          }
        }
      }

      var clusterOptsId = "cluster_options";
      var clusterPopId = solGS.cluster.getClusterPopId(selectedId, dataStr);
      var clusterOpts = solGS.cluster.clusteringOptions(clusterPopId);

      var clusterArgs = {
        selected_id: selectedId,
        selected_name: selectedName,
        data_structure: dataStr,
        cluster_pop_id: clusterPopId,
        cluster_type: clusterOpts.cluster_type,
        data_type: clusterOpts.data_type,
        k_number: clusterOpts.k_number,
        selection_proportion: clusterOpts.selection_proportion,
      };

      clusterArgs = solGS.cluster.clusterResult(clusterArgs);
      runClusterBtnId = solGS.cluster.getRunClusterBtnId(clusterPopId);
      var page = clusterArgs.analysis_page;

      solGS.cluster
        .checkCachedCluster(page, clusterArgs)
        .done(function (res) {
          if (res.result == "success") {
            jQuery(`${canvas} .multi-spinner-container`).hide();

            solGS.cluster.plotClusterOutput(res);

            jQuery(clusterMsgDiv).empty();
            jQuery("#" + runClusterBtnId).show();
          } else {


            jQuery(`${canvas} .multi-spinner-container`).hide();
            jQuery(clusterMsgDiv).empty();

            runClusterBtnId = `#${runClusterBtnId}`;

            var title =
              "<p>This analysis may take a long time. " +
              "Do you want to submit the analysis and get an email when it completes?</p>";

            var jobSubmit = '<div id= "cluster_submit">' + title + "</div>";

            jQuery(jobSubmit).appendTo("body");

            jQuery("#cluster_submit").dialog({
              height: "auto",
              width: "auto",
              modal: true,
              title: "cluster job submission",
              buttons: {
                OK: {
                  text: "Yes",
                  class: "btn btn-success",
                  id: "queue_job",
                  click: function () {
                    jQuery(this).dialog("close");
                    solGS.submitJob.checkUserLogin(page, clusterArgs);
                  },
                },

                No: {
                  text: "No, I will wait till it completes.",
                  class: "btn btn-warning",
                  id: "no_queue",
                  click: function () {
                    jQuery(this).dialog("close");

                    jQuery(runClusterBtnId).hide();
                    jQuery(clusterMsgDiv)
                      .text("Running cluster... please wait...it may take minutes.")
                      .show();
                    jQuery(`${canvas} .multi-spinner-container`).show();

                    solGS.cluster
                      .runClusterAnalysis(clusterArgs)
                      .done(function (res) {
                        if (res.result == "success") {
                          jQuery(`${canvas} .multi-spinner-container`).hide();

                          solGS.cluster.plotClusterOutput(res);

                          jQuery(clusterMsgDiv).empty();
                          jQuery(runClusterBtnId).show();
                        } else {
                          jQuery(clusterMsgDiv).html(
                            "Error occured running the clustering. Possibly the R script failed."
                          );
                          jQuery(`${canvas} .multi-spinner-container`).hide();
                          jQuery(runClusterBtnId).show();
                        }
                      })
                      .fail(function () {
                        jQuery(clusterMsgDiv).html("Error occured running the clustering");
                        jQuery(`${canvas} .multi-spinner-container`).hide();
                        jQuery(runClusterBtnId).show();
                      });
                  },
                },

                Cancel: {
                  text: "Cancel",
                  class: "btn btn-info",
                  id: "cancel_queue_info",
                  click: function () {
                    jQuery(this).dialog("close");
                    jQuery(runClusterBtnId).show();
                  },
                },
              },
            });
          }
        })
        .fail(function () { });
    }
  });
});

jQuery(document).ready(function () {
  var page = location.pathname;

  if (page.match(/solgs\/traits\/all\/|solgs\/models\/combined\/trials\//)) {
    setTimeout(function () {
      solGS.cluster.populateClusterMenu();
    }, 5000);

    var dataTypeOpts = solGS.cluster.getDataTypeOpts();

    dataTypeOpts = solGS.cluster.createDataTypeSelect(dataTypeOpts);
    var clusterTypeOpts = solGS.cluster.createClusterTypeSelect();

    jQuery(document).ready(checkClusterPop);

    function checkClusterPop() {
      if (jQuery("#cluster_div #cluster_pops_select_div").is(":visible")) {
        jQuery("#cluster_div #cluster_options #cluster_data_type_opts").html(dataTypeOpts);
        jQuery("#cluster_div #cluster_options #cluster_type_opts").html(clusterTypeOpts);
        jQuery("#cluster_div #cluster_options").show();
      } else {
        setTimeout(checkClusterPop, 6000);
      }
    }
  } else {
    if (!page.match(/cluster\/analysis/)) {
      var dataTypeOpts = solGS.cluster.getDataTypeOpts();
      dataTypeOpts = solGS.cluster.createDataTypeSelect(dataTypeOpts);
      var clusterTypeOpts = solGS.cluster.createClusterTypeSelect();

      jQuery("#cluster_div #cluster_options #cluster_data_type_opts").html(dataTypeOpts);
      jQuery("#cluster_div #cluster_options #cluster_type_opts").html(clusterTypeOpts);
      jQuery("#cluster_div #cluster_options").show();
    }
  }
});

jQuery(document).ready(function () {

  if (!location.pathname.match(/cluster\/analysis/)) {
    var clusterPopsDiv = solGS.cluster.clusterPopsDiv;

    jQuery(clusterPopsDiv).on("change", function () {
      var selectedPop = jQuery("option:selected", this).data("pop");

      var selectedPopId = selectedPop.id;
      var selectedPopName = selectedPop.name;
      var selectedPopType = selectedPop.type || selectedPop.pop_type;


      var dataTypeId = solGS.cluster.clusterDataTypeSelectId(selectedPopId);
      var dataType = jQuery("#" + dataTypeId).val();

      jQuery("#cluster_selected_pop_name").val(selectedPopName);
      jQuery("#cluster_selected_pop_id").val(selectedPopId);
      jQuery("#cluster_selected_pop_type").val(selectedPopType);

      var dataTypeOpts = solGS.cluster.getDataTypeOpts(selectedPop);

      dataTypeOpts = solGS.cluster.createDataTypeSelect(dataTypeOpts, selectedPopId);
      jQuery("#cluster_div #cluster_options #cluster_data_type_opts").html(dataTypeOpts);

      if (selectedPopType.match(/selection_index/) && dataType.match(/Genotype/i)) {
        jQuery("#cluster_div #cluster_options #selection_proportion_div").show();
      } else {
        jQuery("#cluster_div #cluster_options #selection_proportion_div").hide();
      }

    });
  }
});


jQuery(document).ready(function () {
  if (location.pathname.match(/cluster\/analysis/)) {

    clusterPopsDataDiv = solGS.cluster.clusterPopsDataDiv;
    var tableId = 'cluster_pops_table';
    var clusterPopsTable = solGS.cluster.createTable(tableId)
    jQuery(clusterPopsDataDiv).append(clusterPopsTable).show();

    var clusterPops = solGS.cluster.getClusterPops()
    var clusterPopsRows = solGS.cluster.getClusterPopsRows(clusterPops);

    solGS.cluster.displayClusterPopsTable(tableId, clusterPopsRows)
 
    jQuery("#add_new_pops").show();
    
  }
});
