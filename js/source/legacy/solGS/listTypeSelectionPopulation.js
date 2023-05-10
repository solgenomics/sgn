/**
selection population upload from lists
and files. Run prediction model on list selection population
and display output.

Isaak Y Tecle
iyt2@cornell.edu
*/

JSAN.use("jquery.blockUI");

var solGS = solGS || function solGS() {};

solGS.listTypeSelectionPopulation = {
  selectionPopsDiv: "#list_type_selection_pops_select_div",
  selectionPopsSelectMenuId: "#list_type_selection_pops_select",

  checkPredictedListSelection: function (listId) {
    var args = this.createSelectionReqArgs(listId);
    args = JSON.stringify(args);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: { arguments: args },
      url: "/solgs/check/predicted/list/selection",
      success: function (response) {
        args = JSON.parse(args);

        if (response.output) {
          solGS.listTypeSelectionPopulation.displayPredictedListTypeSelectionPops(
            args,
            response.output
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
      },
    });
  },

  getSelectionListElementsNames: function (list) {
    var names = [];
    for (var i = 0; i < list.length; i++) {
      names.push(list[i][1]);
    }

    return names;
  },

  getListTypeSelectionPopDetail: function (listId) {
    if (typeof listId == "number") {
      var list = new CXGN.List();

      var listData;
      var listType;
      var listName;

      if (listId) {
        listData = list.getListData(listId);
        listType = list.getListType(listId);
        listName = list.listNameById(listId);
        elemCount = listData.elements;
      }

      return { name: listName, list_id: listId, type: listType, elements_count: elemCount };
    }
  },

  askSelectionJobQueueing: function (listId) {
    var args = this.createSelectionReqArgs(listId);
    var modelId = args.training_pop_id;
    var selectionPopId = args.selection_pop_id;
    var protocolId = args.genotyping_protocol_id;

    var hostName = window.location.protocol + "//" + window.location.host;
    var page = hostName + "/solgs/selection/" + selectionPopId + "/model/" + modelId;

    solGS.waitPage(page, args);
  },

  createSelectionReqArgs: function (listId) {
    if (typeof listId == "number") {
      var genoList = this.getListTypeSelectionPopDetail(listId);
      var listName = genoList.name;
      var list = genoList.list;
      var modelId = this.getModelId();
      var traitId = this.getTraitId();

      var dataSetType = this.trainingDataSetType();

      var popType = "list_prediction";

      var selectionPopId = "list_" + listId;
      var protocolId = jQuery("#genotyping_protocol_id").val();

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

  getGenotypesList: function (listId) {
    var list = new CXGN.List();
    var genotypesList;

    if (!listId == "") {
      genotypesList = list.getListData(listId);
    }

    var listName = list.listNameById(listId);
    var listType = list.getListType(listId);

    return { name: listName, listId: listId, list_type: listType };
  },

  loadGenotypesListTypeSelectionPop: function (args) {
    var listDetail = this.getListTypeSelectionPopDetail(args.list_id);

    if (window.Prototype) {
      delete Array.prototype.toJSON;
    }

    args = JSON.stringify(args);
    var len = listDetail.elements_count;

    if (len === 0) {
      alert("The list is empty. Please select a list with content.");
    } else {
      jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
      jQuery.blockUI({ message: "Please wait.." });

      jQuery.ajax({
        type: "POST",
        dataType: "json",
        data: { arguments: args },
        url: "/solgs/load/genotypes/list/selection",
        success: function (response) {
          if (response.status == "success") {
            args = JSON.parse(args);
            var modelId = args.training_pop_id;
            var traitId = args.trait_id;
            var selPopId = args.selection_pop_id;
            var listId = args.list_id;

            if (window.location.href.match(/solgs\/trait\//)) {
              window.location =
                "/solgs/selection/" + selPopId + "/model/" + modelId + "/trait/" + traitId;
              jQuery.unblockUI();
            } else if (window.location.href.match(/solgs\/model\/combined\/populations\//)) {
              window.location =
                "/solgs/selection/" + selPopId + "/model/combined/" + modelId + "/trait/" + traitId;
              jQuery.unblockUI();
            } else {
              displayPredictedListTypeSelectionPops(args, response.output);
              solGS.sIndex.populateSindexMenu();
              solGS.correlation.populateGenCorrMenu();
              jQuery.unblockUI();
            }
          } else {
            alert("fail: Error occured while querying for the genotype data of the accessions.");
            jQuery.unblockUI();
          }
        },
        error: function (res) {
          alert("Error occured while querying for the genotype data of the accessions.");
          jQuery.unblockUI();
        },
      });
    }
  },

  predictGenotypesListSelectionPop: function (args) {
    var modelId = args.training_pop_id;
    var traitId = args.trait_id;
    var selPopId = args.selection_pop_id;

    var url = "/solgs/selection/" + selPopId + "/model/" + modelId;

    jQuery.ajax({
      dataType: "json",
      type: "POST",
      data: { trait_id: traitId, list_source: "from_db", list_prediction: 1 },
      url: url,
      success: function (res) {
        if (res.status == "success") {
          window.location =
            "/solgs/selection/" + selPopId + "/model/" + modelId + "/trait/" + traitId;
        } else {
          window.location = window.location.href;
        }
      },
    });

    jQuery.unblockUI();
  },

  getModelId: function () {
    var modelId;
    var modelIdExists = jQuery("#model_id").doesExist();
    var comboPopsIdExists = jQuery("#combo_pops_id").doesExist();
    var popIdExists = jQuery("#population_id").doesExist();

    if (jQuery("#model_id").val()) {
      modelId = jQuery("#model_id").val();
    } else if (jQuery("#population_id").val()) {
      modelId = jQuery("#population_id").val();
    } else if (jQuery("#combo_pops_id").val()) {
      modelId = jQuery("#combo_pops_id").val();
    }

    return modelId;
  },

  trainingDataSetType: function () {
    var dataSetType;
    var referer = document.URL;

    if (referer.match(/\/combined\//)) {
      dataSetType = "combined_populations";
    } else {
      dataSetType = "single_population";
    }

    return dataSetType;
  },

  getTraitId: function () {
    var traitId;
    var traitIdExists = jQuery("#trait_id").doesExist();

    if (traitIdExists == true) {
      traitId = jQuery("#trait_id").val();
    }

    return traitId;
  },

  displayPredictedListTypeSelectionPops: function (args, output) {
    var listName = args.list_name;
    var listId = args.list_id;
    var traitId = args.trait_id;
    var selectionPopId = args.selection_pop_id;
    var trainingPopId = args.training_pop_id;

    var url = "/solgs/selection/" + selectionPopId + "/model/" + trainingPopId;
    var listIdArg = "'" + listId + "'";
    var listSource = "'from_db'";
    var popIdName = { id: "list_" + listId, name: listName, pop_type: "list_selection" };
    popIdName = JSON.stringify(popIdName);
    var hiddenInput = '<input type="hidden" value=\'' + popIdName + "'/>";

    var predictedListTypeSelectionPops = jQuery("#list_type_selection_pops_table").doesExist();

    if (predictedListTypeSelectionPops == false) {
      var predictedListTypeSelectionTable =
        '<table id="list_type_selection_pops_table" class="table"><thead><tr>' +
        "<th>List-based selection population</th>" +
        "<th>View GEBVs</th>" +
        "</tr></thead><tbody>" +
        '<tr id="list_prediction_output_' +
        listId +
        '">' +
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
      var listIdArg = "'" + listId + "'";
      var listSource = "'from_db'";

      var popIdName = { id: "list_" + listId, name: listName, pop_type: "list_selection" };
      popIdName = JSON.stringify(popIdName);
      var hiddenInput = '<input type="hidden" value=\'' + popIdName + "'/>";

      var addRow =
        '<tr id="list_prediction_output_' +
        listId +
        '"><td>' +
        "<b>" +
        listName +
        "</td>" +
        "<td> <data>" +
        hiddenInput +
        "</data>" +
        output +
        "</td></tr>";

      var trId = "#list_prediction_output_" + listId;
      var samePop = jQuery(trId).doesExist();

      if (samePop == false) {
        jQuery("#list_type_selection_pops_table tr:last").after(addRow);
      } else {
        jQuery(trId).remove();
        jQuery("#list_type_selection_pops_table").append(addRow).show();
      }
    }
  },

  populateSelectionPopsMenu: function () {
    var list = new CXGN.List();
    var lists = list.getLists(["accessions", "trials"]);
    var selectionPrivatePops = list.convertArrayToJson(lists.private_lists);

    var menuId = this.selectionPopsSelectMenuId;
    var menu = new OptionsMenu(menuId);
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

  loadPredictionOutput: function (url, listId, listSource) {
    var traitId = this.getTraitId();
    var modelId = this.getModelId();

    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({ message: "Please wait.." });

    jQuery.ajax({
      type: "POST",
      url: url,
      dataType: "json",
      data: {
        list_prediction: 1,
        trait_id: traitId,
        model_id: modelId,
        prediction_id: listId,
        list_source: listSource,
      },

      success: function (response) {
        if (response.status == "success") {
          var tdId = "#list_prediction_output_" + listId;
          jQuery(tdId).html(response.output);

          var page = document.URL;

          if (page.match("/traits/all/population/") != null) {
            solGS.sIndex.populateSindexMenu();
            solGS.correlation.populateGenCorrMenu();
          }

          jQuery.unblockUI();
        } else {
          if (response.status == "failed") {
            alert("Error occured while uploading the list of selection genotypes.");
          } else {
            alert(response.status);
          }

          jQuery.unblockUI();
        }
      },

      error: function (response) {
        alert("error: " + res.responseText);
      },
    });
  },
};

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};

jQuery(document).ready(function () {
  solGS.listTypeSelectionPopulation.populateSelectionPopsMenu();
});

jQuery(document).ready(function () {
  jQuery("#list_type_selection_pops_select").change(function () {
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

          if (listDetail.type.match(/accessions/)) {
            solGS.listTypeSelectionPopulation.checkPredictedListSelection(selectedPop.id);
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
