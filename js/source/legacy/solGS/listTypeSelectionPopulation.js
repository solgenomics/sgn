/**
selection population upload from lists
and files. Run prediction model on list selection population
and display output.

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
        population_type: popType,
        training_traits_ids: trainingTraitsIds,
        genotyping_protocol_id: protocolId,
      };

      return args;
    }
  },

  displayPredictedListTypeSelectionPops: function (args, output) {
    var listName = args.list_name;
    var listId = args.list_id;

    var popIdName = { id: "list_" + listId, name: listName, pop_type: "list_selection" };
    popIdName = JSON.stringify(popIdName);
    var hiddenInput = '<input type="hidden" value=\'' + popIdName + "'/>";

    var tableId = "list_type_selection_pops_table";
    var trId = "list_selection_" + listId;
    var predictedListTypeSelectionPops = jQuery(`#${tableId}`).doesExist();

    if (predictedListTypeSelectionPops == false) {
      var predictedListTypeSelectionTable =
        `<table id="${tableId}" class="table"><thead><tr>` +
        "<th>List-based selection population</th>" +
        "<th>View GEBVs</th>" +
        "</tr></thead><tbody>" +
        `<tr id="${trId}">` +
        "<td>" +
        "<b>" +
        listName +
        "</b>" +
        "</td>" +
        "<td><data>" +
        hiddenInput +
        "</data>" +
        output +
        "</td></tr></tbody></table>";

      jQuery("#list_type_selection_pops_selected").append(predictedListTypeSelectionTable).show();
    } else {
      var addRow =
        `<tr id="${trId}">` +
        "<td>" +
        "<b>" +
        listName +
        "</td>" +
        "<td> <data>" +
        hiddenInput +
        "</data>" +
        output +
        "</td></tr>";

      var samePop = jQuery(`#${trId}`).doesExist();

      if (samePop == false) {
        jQuery(`#${tableId} tr:last`).after(addRow);
      } else {
        jQuery(`#${trId}`).remove();
        jQuery(`#${tableId}`).append(addRow).show();
      }
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
      var popRow = row.innerHTML;

      var predict = popRow.match(/predict/gi);
      if (!predict) {
        var selPopsInput = row.getElementsByTagName("input")[0];
        var sIndexPopData = selPopsInput.value;
        popsList.push(JSON.parse(sIndexPopData));
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
        if (
          typeof selectedPop.data_str === "undefined" ||
          !selectedPop.data_str.match(/dataset/i)
        ) {
          var listDetail = solGS.listTypeSelectionPopulation.getListTypeSelectionPopDetail(
            selectedPop.id
          );
          const listObj = new solGSList(selectedPop.id);
          var listDetail = listObj.getListDetail();
    
          if (listDetail.type.match(/accessions/)) {
            solGS.listTypeSelectionPopulation
              .checkPredictedListSelection(selectedPop.id)
              .done(function (res) {
                var args = solGS.listTypeSelectionPopulation.createSelectionReqArgs(selectedPop.id);

                if (res.output) {
                  solGS.listTypeSelectionPopulation.displayPredictedListTypeSelectionPops(
                    args,
                    res.output
                  );

                  if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
                    solGS.sIndex.populateSindexMenu();
                    solGS.correlation.populateGenCorrMenu();
                    solGS.geneticGain.ggSelectionPopulations();
                    solGS.cluster.listClusterPopulations();
                  }
                } else {
                  solGS.listTypeSelectionPopulation.askSelectionJobQueueing(listId);
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
