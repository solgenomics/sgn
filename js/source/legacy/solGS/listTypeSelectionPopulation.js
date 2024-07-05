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

////////////// datatable /////////
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
    var popName = selectionPop.name;
    var dataStr = selectionPop.data_str;

    var selectionPopArgs;

    if (dataStr.match(/dataset/)) {
      selectionPopArgs = solGS.dataset.createDatasetTypeSelectionReqArgs(popId, popName);
      // popName = `<a href="/dataset/${popId}">${popName}</a>`;
  
    } else if (dataStr.match(/list/)) {
      selectionPopArgs = this.createListTypeSelectionReqArgs(popId);
    }

    selectionPopArgs['analysis_type'] = `${dataStr}_type_selection`;
    selectionPopArgs['data_structure'] = dataStr;

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
    var popName = selectionPop.name;
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
      'pageLength': 5,
      'rowId': function (a) {
        return a[4]
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


///////////// end datatable ////////

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
    var page =
      hostName + "/solgs/selection/" + selectionPopId + "/model/" + modelId + "/trait/" +traitId + "/gp/" + protocolId;

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

  // displayListTypeSelectionPops: function (args, output) {
  //   var selPopName = args.selection_pop_name;
  //   var selPopId = args.selection_pop_id;

  //   var popDetail = { id: selPopId, name: selPopName, pop_type: args.population_type };
  //   popDetail = JSON.stringify(popDetail);

  //   var tableId = "list_type_selection_pops_table";
  //   var listTypeSelectionTable = jQuery(`#${tableId}`).doesExist();

  //   if (listTypeSelectionTable == false) {
  //     listTypeSelectionTable =
  //       `<table id="${tableId}" class="table"><thead><tr>` +
  //       "<th>List/dataset type selection population</th>" +
  //       "<th>View GEBVs</th>" +
  //       "</tr></thead><tbody>";

  //     jQuery("#list_type_selection_pops_selected").append(listTypeSelectionTable).show();
  //   }

  //   var trId = `${args.population_type}_${selPopId}`;
  //   var popDisplayed = jQuery(`#${trId}`).doesExist();
  //   if (popDisplayed == false) {
  //     var row =
  //       `<tr id='${trId}' data-list-selection-pop='${popDetail}'>` +
  //       `<td><b>${selPopName}</b></td>` +
  //       `<td>${output}</td>` +
  //       "</tr>";

  //     jQuery(`#${tableId} tr:last`).after(row);
  //   }
  // },

  // populateSelectionPopsMenu: function () {
  //   var list = new CXGN.List();
  //   var lists = list.getLists(["accessions", "trials"]);
  //   var selectionPrivatePops = list.convertArrayToJson(lists.private_lists);

  //   var menuId = this.selectionPopsSelectMenuId;
  //   var menu = new SelectMenu(menuId);
  //   selectionPrivatePops = selectionPrivatePops.flat();
  //   var menuElem = menu.addOptions(selectionPrivatePops);

  //   if (lists.public_lists[0]) {
  //     var selectionPublicLists = list.convertArrayToJson(lists.public_lists);
  //     menu.addOptionsSeparator("public lists");
  //     menuElem = menu.addOptions(selectionPublicLists);
  //   }

  //   var datasetPops = solGS.dataset.getDatasetPops(["accessions", "trials"]);
  //   if (datasetPops) {
  //     menu.addOptionsSeparator("datasets");
  //     menuElem = menu.addOptions(datasetPops);
  //   }

  //   var selectionPopsDiv = this.selectionPopsDiv;
  //   jQuery(selectionPopsDiv).append(menuElem).show();
  // },

  // getListTypeSelPopulations: function () {
  //   var listTypeSelPopsDiv = document.getElementById("list_type_selection_pops_selected");
  //   var listTypeSelPopsTable = listTypeSelPopsDiv.getElementsByTagName("table");
  //   var listTypeSelPopsRows = listTypeSelPopsTable[0].rows;

  //   var popsList = [];
  //   for (var i = 1; i < listTypeSelPopsRows.length; i++) {
  //     var row = listTypeSelPopsRows[i];
  //     var notPredicted = row.innerHTML.match(/predict/gi);
  //     if (!notPredicted) {
  //       var selectedPop = row.dataset.listSelectionPop;
  //       selectedPop = JSON.parse(selectedPop);

  //       if (selectedPop.id.match(/\w+_/)) {
  //         if (selectedPop.id.match(/list/)) {
  //           selectedPop.data_str = "list";
  //         } else {
  //           selectedPop.data_str = "dataset";
  //         }
  //         selectedPop.id = selectedPop.id.replace(/\w+_/, "");
  //       }

  //       popsList.push(selectedPop);
  //     }
  //   }
  //   return popsList;
  // },
};

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};


jQuery(document).ready(function () {

  var selectionListPopsDataDiv = solGS.listTypeSelectionPopulation.selectionListPopsDataDiv;
  var tableId = solGS.listTypeSelectionPopulation.selectionListPopsTable;
  
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
                var args = solGS.listTypeSelectionPopulation.createListTypeSelectionReqArgs(listId);

                if (!res.output.match(/Predict/)) {
                  var selDataTable = jQuery(tableId).DataTable()
                  var tableRowIdx = selDataTable.row('[id='+selectionPopId + ']').index();
                  selDataTable.cell(tableRowIdx, 3).data(res.output).draw();               
                 
                  jQuery(`#${runSolgsBtnId}`).html(res.output);
                  if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
                    solGS.sIndex.populateSindexMenu();
                    solGS.correlation.populateGenCorrMenu();
                    solGS.geneticGain.ggSelectionPopulations();
                    solGS.cluster.listClusterPopulations();
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
          var datasetId = selectedPop.dataset_id;
          var datasetName = selectedPop.dataset_name;

          solGS.dataset.checkPredictedDatasetSelection(datasetId, datasetName).done(function (res) {
            var args = solGS.dataset.createDatasetTypeSelectionReqArgs(datasetId, datasetName);
            var selectionPopId = args.selection_pop_id;

            if (!res.output.match(/Predict/)) {
              var selDataTable = jQuery(tableId).DataTable()
              var tableRowIdx = selDataTable.row('[id='+selectionPopId + ']').index();
              selDataTable.cell(tableRowIdx, 3).data(res.output).draw();     

              if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
                solGS.sIndex.populateSindexMenu();
                solGS.correlation.populateGenCorrMenu();
                solGS.geneticGain.ggSelectionPopulations();
                solGS.cluster.listClusterPopulations();
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

  var selectionPopsDataDiv = solGS.listTypeSelectionPopulation.selectionListPopsDataDiv;
  var tableId = solGS.listTypeSelectionPopulation.selectionListPopsTable;
  var selectionPopsTable = solGS.listTypeSelectionPopulation.createTable(tableId)

  jQuery(selectionPopsDataDiv).append(selectionPopsTable).show();
  
  var selectionPops = solGS.listTypeSelectionPopulation.getSelectionListPops();
  var selectionPopsRows = solGS.listTypeSelectionPopulation.getSelectionListPopsRows(selectionPops);

  solGS.listTypeSelectionPopulation.displaySelectionListPopsTable(tableId, selectionPopsRows)

});