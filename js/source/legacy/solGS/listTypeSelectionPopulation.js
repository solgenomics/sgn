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

  checkPredictedListSelection: function (listId) {
    var args = this.createSelectionReqArgs(listId);
    args = JSON.stringify(args);

    var checkPredicted = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/solgs/check/predicted/list/selection",
    });

    return checkPredicted;
  },

  askSelectionJobQueueing: function (listId) {
    var args = this.createSelectionReqArgs(listId);
    var modelId = args.training_pop_id;
    var selectionPopId = args.selection_pop_id;
    var protocolId = args.genotyping_protocol_id;

    var hostName = window.location.protocol + "//" + window.location.host;
    var page =
      hostName + "/solgs/selection/" + selectionPopId + "/model/" + modelId + "/gp/" + protocolId;

    solGS.waitPage(page, args);
  },

  createSelectionReqArgs: function (listId) {
    if (typeof listId == "number") {
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
    }
  },

  displayListTypeSelectionPops: function (args, output) {
    var selPopName = args.selection_pop_name;
    var selPopId = args.selection_pop_id;

    var popDetail = { id: selPopId, name: selPopName, pop_type: args.population_type };
    popDetail = JSON.stringify(popDetail);

    var tableId = "list_type_selection_pops_table";
    var listTypeSelectionTable = jQuery(`#${tableId}`).doesExist();

    if (listTypeSelectionTable == false) {
      listTypeSelectionTable =
        `<table id="${tableId}" class="table"><thead><tr>` +
        "<th>List/dataset type selection population</th>" +
        "<th>View GEBVs</th>" +
        "</tr></thead><tbody>";

      jQuery("#list_type_selection_pops_selected").append(listTypeSelectionTable).show();
    }

    var trId = `${args.population_type}_${selPopId}`;
    var popDisplayed = jQuery(`#${trId}`).doesExist();
    if (popDisplayed == false) {
      var row =
        `<tr id='${trId}' data-list-selection-pop='${popDetail}'>` +
        `<td><b>${selPopName}</b></td>` +
        `<td>${output}</td>` +
        "</tr>";

      jQuery(`#${tableId} tr:last`).after(row);
    }
  },

  populateSelectionPopsMenu: function () {
    var list = new CXGN.List();
    var lists = list.getLists(["accessions", "trials"]);
    var selectionPrivatePops = list.convertArrayToJson(lists.private_lists);

    var menuId = this.selectionPopsSelectMenuId;
    var menu = new SelectMenu(menuId);
    selectionPrivatePops = selectionPrivatePops.flat();
    var menuElem = menu.addOptions(selectionPrivatePops);

    if (lists.public_lists[0]) {
      var selectionPublicLists = list.convertArrayToJson(lists.public_lists);
      menu.addOptionsSeparator("public lists");
      menuElem = menu.addOptions(selectionPublicLists);
    }

    var datasetPops = solGS.dataset.getDatasetPops(["accessions", "trials"]);
    if (datasetPops) {
      menu.addOptionsSeparator("datasets");
      menuElem = menu.addOptions(datasetPops);
    }

    var selectionPopsDiv = this.selectionPopsDiv;
    jQuery(selectionPopsDiv).append(menuElem).show();
  },

  getListTypeSelPopulations: function () {
    var listTypeSelPopsDiv = document.getElementById("list_type_selection_pops_selected");
    var listTypeSelPopsTable = listTypeSelPopsDiv.getElementsByTagName("table");
    var listTypeSelPopsRows = listTypeSelPopsTable[0].rows;

    var popsList = [];
    for (var i = 1; i < listTypeSelPopsRows.length; i++) {
      var row = listTypeSelPopsRows[i];
      var notPredicted = row.innerHTML.match(/predict/gi);
      if (!notPredicted) {
        var selectedPop = row.dataset.listSelectionPop;
        selectedPop = JSON.parse(selectedPop);

        if (selectedPop.id.match(/\w+_/)) {
          if (selectedPop.id.match(/list/)) {
            selectedPop.data_str = "list";
          } else {
            selectedPop.data_str = "dataset";
          }
          selectedPop.id = selectedPop.id.replace(/\w+_/, "");
        }

        popsList.push(selectedPop);
      }
    }
    return popsList;
  },
};

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};

jQuery(document).ready(function () {
  solGS.listTypeSelectionPopulation.populateSelectionPopsMenu();
});

jQuery(document).ready(function () {
  var menuId = solGS.listTypeSelectionPopulation.selectionPopsSelectMenuId;
  jQuery(`${menuId}`).change(function () {
    var selectedPop = jQuery("option:selected", this).data("pop");

    if (selectedPop.id) {
      jQuery(" #list_type_selection_pop_go_btn").click(function () {
        if (typeof selectedPop.data_str === "undefined" || selectedPop.data_str.match(/list/i)) {
          const listObj = new solGSList(selectedPop.id);
          var listDetail = listObj.getListDetail();

          if (listDetail.type.match(/accessions/)) {
            solGS.listTypeSelectionPopulation
              .checkPredictedListSelection(selectedPop.id)
              .done(function (res) {
                var args = solGS.listTypeSelectionPopulation.createSelectionReqArgs(selectedPop.id);

                if (res.output) {
                  solGS.listTypeSelectionPopulation.displayListTypeSelectionPops(args, res.output);

                  if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
                    solGS.sIndex.populateSindexMenu();
                    solGS.correlation.populateGenCorrMenu();
                    solGS.geneticGain.ggSelectionPopulations();
                    solGS.cluster.listClusterPopulations();
                  }
                } else {
                  solGS.listTypeSelectionPopulation.askSelectionJobQueueing(selectedPop.id);
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
          solGS.dataset.checkPredictedDatasetSelection(selectedPop.id, selectedPop.name);
        }
      });
    }
  });
});
