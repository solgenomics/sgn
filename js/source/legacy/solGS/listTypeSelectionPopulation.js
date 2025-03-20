/**
A search interface for list and dataset type selection populations

Isaak Y Tecle
iyt2@cornell.edu
*/

// JSAN.use("jquery.blockUI");

var solGS = solGS || function solGS() {};

solGS.listTypeSelectionPopulation = {
  selectionPopsDiv: "#list_type_selection_pops_select_div",
  selectionPopsSelectMenuId: "#list_type_selection_pops_select",
  selectionListPopsDataDiv: "#list_type_selection_pops_data_div",
  selectionListPopsTable: "#list_type_selection_pops_table",

 
  getSelectionListPops: function () {
    var list = new solGSList();
    var lists = list.getLists(["accessions"]);
    lists = list.addDataStrAttr(lists);

    var datasets = solGS.dataset.getDatasetPops(["accessions", "trials"]);
    var selectionPops = [lists, datasets];

    return selectionPops.flat();

  },


  getSelectionListPopsRows: function(selectionPops) {
    var selectionPopsRows = [];

    for (var i = 0; i < selectionPops.length; i++) {
      if (selectionPops[i]) {
        var selectionPopRow = this.createRowElements(selectionPops[i]);
        selectionPopsRows.push(selectionPopRow);
      }
    }

    return selectionPopsRows;

  },

  getSelectionPopId: function (popId, dataStr) {
    var selectionPopId;

    if (dataStr) {
      selectionPopId = `${dataStr}_${popId}`;
    } else {
      selectionPopId = popId;
    }

    return selectionPopId;
  },

  getSelectionPopArgs(selectionPop) {
    var popId = selectionPop.id;
    var dataStr = selectionPop.data_str;
  
    var protocolId;
    if (dataStr.match(/dataset/)) {
      protocolId = solGS.dataset.getDatasetGenoProtocolId(popId);
    } else if (dataStr.match(/list/)) {
      protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();
    }

    var modelArgs = solGS.getModelArgs();
    var selectionPopId = this.getSelectionPopId(popId, dataStr);

    var selectionPopArgs = {
      training_pop_id: modelArgs.training_pop_id,
      selection_pop_id: selectionPopId,
      selection_pop_name: selectionPop.name,
      training_traits_ids: modelArgs.training_traits_ids,
      population_type: `${dataStr}_selection`,
      data_set_type: modelArgs.data_set_type,
      genotyping_protocol_id: protocolId,
      analysis_type: `${dataStr}_type_selection`,
      data_structure: dataStr,
    };

    return selectionPopArgs;

  },

  createRowElements: function (selectionPop) {
    var popId = selectionPop.id;
    var popName = selectionPop.name;
    var dataStr = selectionPop.data_str;

    if (dataStr.match(/dataset/)) {
      popName = `<a href="/dataset/${popId}">${popName}</a>`;  
    } 

    var runSolgsCol = this.getRunSolgsBtnElement(selectionPop);
    var rowData = [popName,
    dataStr, selectionPop.owner, runSolgsCol, `${dataStr}_${popId}`];
    
    return rowData;
  },


  getRunSolgsBtnElement: function(selectionPop) {
    var popId = selectionPop.id;
    var dataStr = selectionPop.data_str;

    var selectionPopId = this.getSelectionPopId(popId, dataStr);
    var runSolgsBtnId = this.getRunSolgsId(selectionPopId);

    var selectionArgs = this.getSelectionPopArgs(selectionPop);
    selectionArgs = JSON.stringify(selectionArgs);

    var runSolgsBtn =
      `<button type="button" id=${runSolgsBtnId}` +
      ` class="btn btn-success" data-selected-pop='${selectionArgs}'>Predict</button>`;

      return runSolgsBtn;

  },

  getRunSolgsId: function (selectionPopId) {
    if (selectionPopId) {
      return `run_solgs_${selectionPopId}`;
    } else {
      return "run_solgs";
    }
  },


  createTable: function (tableId) {
    tableId = tableId.replace('#', "");

    var selectionTable =
      `<table id="${tableId}" class="table table-striped"><thead><tr>` +
      "<th>Population</th>" +
      "<th>Data structure</th>" +
      "<th>Ownership</th>" +
      "<th>Run solGS</th>" +
      "</tr></thead></table>";

    return selectionTable;
  },

  displaySelectionListPopsTable: function (tableId, data) {

    var table = jQuery(tableId).DataTable({
      'searching': true,
      'ordering': true,
      'processing': true,
      'paging': true,
      'info': false,
      'pageLength': 15,
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

  checkPredictedListSelection: function (listId) {
    var args = this.createListTypeSelectionReqArgs(listId);
    args = JSON.stringify(args);

    var checkPredicted = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/solgs/check/predicted/list/selection",
    });

    return checkPredicted;
  },

  showJobSubmissionDialog: function (listId) {
    var args = this.createListTypeSelectionReqArgs(listId);
    var modelId = args.training_pop_id;
    var selectionPopId = args.selection_pop_id;
    var protocolId = args.genotyping_protocol_id;
    var traitId = args.training_traits_ids;

    var hostName = window.location.protocol + "//" + window.location.host;
    var page;

    if (document.URL.match(/combined/)) {
      page = `${hostName}/solgs/combined/model/${modelId}/selection/${selectionPopId}/trait/${traitId}/gp/${protocolId}`;
    } else {
     page = `${hostName}/solgs/selection/${selectionPopId}/model/${modelId}/trait/${traitId}/gp/${protocolId}`;
    }

    solGS.waitPage(page, args);
  },

  createListTypeSelectionReqArgs: function (listId) {
      const listObj = new solGSList(listId);
      var listDetail = listObj.getListDetail();
      var listName = listDetail.name;

      var modelArgs = solGS.getModelArgs();
      var modelId = modelArgs.training_pop_id;
      var dataSetType = modelArgs.data_set_type;
      var popType = "list_selection";

      var selectionPopId = "list_" + listId;
      var protocolId = modelArgs.genotyping_protocol_id;
      var trainingTraitsIds = solGS.getTrainingTraitsIds();

      var args = {
        list_name: listName,
        list_id: listId,
        analysis_type: "selection_prediction",
        data_set_type: dataSetType,
        training_pop_id: modelId,
        selection_pop_id: selectionPopId,
        selection_pop_name: listName,
        population_type: popType,
        training_traits_ids: trainingTraitsIds,
        genotyping_protocol_id: protocolId,
      };

      return args;

  },

  replaceSolgsBtn: function(selectionPopId, predictedLink) {

    var tableId = this.selectionListPopsTable;
    var selDataTable = jQuery(tableId).DataTable()
    var tableRowIdx = selDataTable.row('[id='+selectionPopId + ']').index();
    selDataTable.cell(tableRowIdx, 3).data(predictedLink).draw();  

  },

  getPredictedSelectionPopArgs: function(selectionPopArgs) {
    var predictedPopArgs = {
      'id' : selectionPopArgs.selection_pop_id,
      'name': selectionPopArgs.selection_pop_name,
      'data_str': selectionPopArgs.data_structure,
      'pop_type': 'selection'
    };

      return predictedPopArgs;
  },

};

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};


jQuery(document).ready(function () {
  var selectionListPopsDataDiv = solGS.listTypeSelectionPopulation.selectionListPopsDataDiv;
  
  jQuery(selectionListPopsDataDiv).on("click", function (e) {
    var runSolgsBtnId = e.target.id;
      
    if (runSolgsBtnId.match(/run_solgs/)) {

      var selectedPop = solGS.listTypeSelectionPopulation.getSelectedPopSolgsArgs(runSolgsBtnId);
      var selectionPopId = selectedPop.selection_pop_id;
      
      if (selectionPopId.match(/list/)) {
          var listId = selectionPopId.replace(/\w+_/, "");
  
          const listObj = new solGSList(listId);
          var listDetail = listObj.getListDetail();
          if (listDetail.type.match(/accessions/)) {
            solGS.listTypeSelectionPopulation
              .checkPredictedListSelection(listId)
              .done(function (res) {
                if (!res.output.match(/Predict/)) {
                  solGS.listTypeSelectionPopulation.replaceSolgsBtn(selectionPopId, res.output);
   
                  if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
                    var predictedPop = solGS.listTypeSelectionPopulation.getPredictedSelectionPopArgs(selectedPop)

                    solGS.sIndex.populateSindexMenu(predictedPop);
                    solGS.correlation.populateGenCorrMenu(predictedPop);
                    solGS.geneticGain.populateGeneticGainMenu(predictedPop);
                    solGS.cluster.populateClusterMenu(predictedPop);
                  }
                } else {
                  solGS.listTypeSelectionPopulation.showJobSubmissionDialog(listId);
                }
              })
              .fail(function () {
                alert("Error occured checking if the selection population has predicted output.");
              });
          } else {
            //TO-DO
            //	var trialsList = listDetail.list;
            //	var trialsNames = listDetail.elementsNames;
            //	loadTrialListTypeSelectionPop(trialsNames);
          }
          
        } else {
          var selectedPop = solGS.listTypeSelectionPopulation.getSelectedPopSolgsArgs(runSolgsBtnId);
          var datasetId = selectedPop.selection_pop_id.replace(/\w+_/,'');
          var datasetName = selectedPop.selection_pop_name;

          solGS.dataset.checkPredictedDatasetSelection(datasetId, datasetName).done(function (res) { 
            if (!res.output.match(/Predict/)) {
              solGS.listTypeSelectionPopulation.replaceSolgsBtn(selectionPopId, res.output);
            
              if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
                var predictedPop = solGS.listTypeSelectionPopulation.getPredictedSelectionPopArgs(selectedPop)

                solGS.sIndex.populateSindexMenu(predictedPop);
                solGS.correlation.populateGenCorrMenu(predictedPop);
                solGS.geneticGain.populateGeneticGainMenu(predictedPop);
                solGS.cluster.populateClusterMenu(predictedPop);
              }
            } else {
              solGS.dataset.queueDatasetSelectionPredictionJob(datasetId, datasetName);
            }
          })
          .fail(function () {
            alert("Error occured checking if the selection population has predicted output.");
          });
        }
      }
  });
});

jQuery(document).ready(function () {
  jQuery("#lists_datasets_message").show();
  jQuery("#lists_datasets_progress .multi-spinner-container").show();

  var selectionPopsDataDiv = solGS.listTypeSelectionPopulation.selectionListPopsDataDiv;
  var tableId = solGS.listTypeSelectionPopulation.selectionListPopsTable;
  var selectionPopsTable = solGS.listTypeSelectionPopulation.createTable(tableId);

  jQuery(selectionPopsDataDiv).append(selectionPopsTable).show();
  
  var selectionPops = solGS.listTypeSelectionPopulation.getSelectionListPops();
  var selectionPopsRows = solGS.listTypeSelectionPopulation.getSelectionListPopsRows(selectionPops);

  solGS.listTypeSelectionPopulation.displaySelectionListPopsTable(tableId, selectionPopsRows);

  jQuery("#lists_datasets_message").hide();
  jQuery("#lists_datasets_progress .multi-spinner-container").hide();
  jQuery("#create_new_list_dataset").show();

});