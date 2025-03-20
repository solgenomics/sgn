/**

For training populations options from list of plots and trials and datasets.

Isaak Y Tecle 
iyt2@cornell.edu
*/

var solGS = solGS || function solGS() {};

solGS.listTypeTrainingPopulation = {
  trainingPopsDiv: "#list_type_training_pops_select_div",
  trainingPopsSelectMenuId: "#list_type_training_pops_select",
  trainingListPopsDataDiv: "#list_type_training_pops_data_div",
  trainingListPopsTable: "#list_type_training_pops_table",

 
  getTrainingListPops: function () {

    var list = new solGSList();
    var lists = list.getLists(["plots", "trials"]);
    lists = list.addDataStrAttr(lists);
   
    var datasets = solGS.dataset.getDatasetPops(["trials"]);
   
    var trainingPops = [lists, datasets];

    return trainingPops.flat();

  },


  getTrainingListPopsRows: function(trainingPops) {

    var trainingPopsRows = [];

    for (var i = 0; i < trainingPops.length; i++) {
      if (trainingPops[i]) {
        var trainingPopRow = this.createRowElements(trainingPops[i]);
        trainingPopsRows.push(trainingPopRow);
      }
    }

    return trainingPopsRows;

  },

  getTrainingPopId: function (popId, dataStr) {

    var trainingPopId;
    if (dataStr) {
      trainingPopId = `${dataStr}_${popId}`;
    } else {
      trainingPopId = popId;
    }

    return trainingPopId;
  },

  createRowElements: function (trainingPop) {
    var popId = trainingPop.id;
    var popName = trainingPop.name;
    var dataStr = trainingPop.data_str;
   
    if (dataStr.match(/dataset/)) {
      popName = `<a href="/dataset/${popId}">${popName}</a>`;
    }

    var runSolgsBtn = this.getRunSolgsBtnElement(trainingPop);

    var rowData = [popName,
      dataStr, trainingPop.owner, runSolgsBtn, `${dataStr}_${popId}`];

    return rowData;

  },

  getRunSolgsBtnElement: function(trainingPop) {
    var popId = trainingPop.id;
    var popName = trainingPop.name;
    var dataStr = trainingPop.data_str;

    var trainingPopId = this.getTrainingPopId(popId, dataStr);
    var runSolgsBtnId = this.getRunSolgsId(trainingPopId);

    var trainingArgs = this.getTrainingPopArgs(trainingPop);
    trainingArgs = JSON.stringify(trainingArgs);

    var runSolgsBtn =
      `<button type="button" id=${runSolgsBtnId}` +
      ` class="btn btn-success" data-selected-pop='${trainingArgs}'>Create Training Population</button>`;

      return runSolgsBtn;

  },

  getTrainingPopArgs: function(trainingPop) {
    var popId = trainingPop.id;
    var dataStr = trainingPop.data_str;

    var trainingPopId = this.getTrainingPopId(popId, dataStr);
    var trainingArgs = {
      training_pop_id: trainingPopId,
      training_pop_name: trainingPop.name,
      population_type: `${dataStr}_training`,
      data_structure: dataStr
    };

    var protocolId;
    if (dataStr.match(/dataset/)) {
      protocolId = solGS.dataset.getDatasetGenoProtocolId(popId);
    } else if (dataStr.match(/list/)) {
      protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();
    }

    trainingArgs['analysis_type'] = `${dataStr}_type_training`;
    trainingArgs['genotyping_protocol_id'] = protocolId;

    return trainingArgs;

  },

  getRunSolgsId: function (trainingPopId) {
    if (trainingPopId) {
      return `run_solgs_${trainingPopId}`;
    } else {
      return "run_solgs";
    }
  },


  createTable: function (tableId) {

    tableId = tableId.replace('#', "");
    var trainingTable =
      `<table id="${tableId}" class="table table-striped"><thead><tr>` +
      "<th>Population</th>" +
      "<th>Data structure</th>" +
      "<th>Ownership</th>" +
      "<th>Run solGS</th>" +
      "</tr></thead></table>";

    return trainingTable;
  },

  displayTrainingListPopsTable: function (tableId, data) {

    var table = jQuery(`${tableId}`).DataTable({
      'searching': true,
      'ordering': true,
      'processing': true,
      'paging': true,
      'info': false,
      'pageLength': 5,
      'rowId': function (a) {
        return a[4]
      },
      "oLanguage": {
        "sSearch": "Filter"
      }
    });

    table.rows.add(data).draw();

  },

  getSelectedPopSolgsArgs: function (runSolgsElemId) {
    var solgsArgs;
    var selectedPopDiv = document.getElementById(runSolgsElemId);

    if (selectedPopDiv) {
      var selectedPopData = selectedPopDiv.dataset;
      solgsArgs = JSON.parse(selectedPopData.selectedPop);
    }

    return solgsArgs;
  },

  loadTrialListTypeTrainingPop: function (trialsNames) {
    var trialsList = jQuery.ajax({
      type: "POST",
      url: "/solgs/get/trial/id/",
      dataType: "json",
      data: { trials_names: trialsNames },
    });

    return trialsList;
  },

  showJobSubmissionDialog: function (listId) {
    var args = this.createListTypeTrainingReqArgs(listId);
    var modelId = args.training_pop_id;
    var protocolId = args.genotyping_protocol_id;

    var hostName = window.location.protocol + "//" + window.location.host;

    var page = hostName + "/solgs/population/" + modelId;

    if (protocolId) {
      page = page + "/gp/" + protocolId;
    }
    solGS.waitPage(page, args);
  },

  createListTypeTrainingReqArgs: function (listId) {
    const listObj = new solGSList(listId);
    var listDetail = listObj.getListDetail();
    var listName = listDetail.name;

    var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();
    
    var args = {
      list_name: listName,
      list_id: listId,
      list_type: listDetail.type,
      training_pop_id: `list_${listId}`,
      training_pop_name: listName,
      population_type: "list_training",
      genotyping_protocol_id: protocolId,
      data_structure: 'list'
    };

    return args;
  },

};

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};

jQuery(document).ready(function () {
  trainingListPopsDataDiv = solGS.listTypeTrainingPopulation.trainingListPopsDataDiv;

  jQuery(trainingListPopsDataDiv).on("click", function (e) {
    var runSolgsBtnId = e.target.id;

    if (runSolgsBtnId.match(/run_solgs/)) {

      var selectedPop = solGS.listTypeTrainingPopulation.getSelectedPopSolgsArgs(runSolgsBtnId);
      var trainingPopId = selectedPop.training_pop_id;

      if (trainingPopId.match(/list/)) {

        var listId = trainingPopId.replace(/\w+_/, "");
        const list = new solGSList(listId);
        var listDetail = list.getListDetail();

        if (listDetail.type.match(/plots/)) {
          solGS.listTypeTrainingPopulation.showJobSubmissionDialog(listId);
        } else {
          var trialsNames = list.getListElementsNames();

          solGS.listTypeTrainingPopulation
            .loadTrialListTypeTrainingPop(trialsNames)
            .done(function (res) {
              solGS.combinedTrials.getCombinedPopsId(res.trials_ids);
            })
            .fail(function (res) {
              alert("Error occured querying for trials ids");
            });
        }
      } else {
        var datasetId = trainingPopId.replace(/\w+_/, "");
        solGS.dataset.datasetTrainingPop(datasetId, selectedPop.training_pop_name);
      }
    }
  });
});


jQuery(document).ready(function () {

  jQuery("#lists_datasets_message").show();
  jQuery("#lists_datasets_progress .multi-spinner-container").show();
 
  var trainingPopsDataDiv = solGS.listTypeTrainingPopulation.trainingListPopsDataDiv;
  
  var tableId = solGS.listTypeTrainingPopulation.trainingListPopsTable;
  var trainingPopsTable = solGS.listTypeTrainingPopulation.createTable(tableId)

  jQuery(trainingPopsDataDiv).append(trainingPopsTable).show();
  var trainingPops = solGS.listTypeTrainingPopulation.getTrainingListPops()
  var trainingPopsRows = solGS.listTypeTrainingPopulation.getTrainingListPopsRows(trainingPops);

  solGS.listTypeTrainingPopulation.displayTrainingListPopsTable(tableId, trainingPopsRows);

  jQuery("#lists_datasets_message").hide();
  jQuery("#lists_datasets_progress .multi-spinner-container").hide();
  jQuery("#create_new_list_dataset").show();

});