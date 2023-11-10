/**

For training populations options from list of plots and trials and datasets.

Isaak Y Tecle 
iyt2@cornell.edu
*/

var solGS = solGS || function solGS() {};

solGS.listTypeTrainingPopulation = {
  trainingPopsDiv: "#list_type_training_pops_select_div",
  trainingPopsSelectMenuId: "#list_type_training_pops_select",

  populateTrainingPopsMenu: function () {
    var list = new CXGN.List();
    var lists = list.getLists(["plots", "trials"]);
    var trainingPrivatePops = list.convertArrayToJson(lists.private_lists);

    var menuId = this.trainingPopsSelectMenuId;
    var menu = new SelectMenu(menuId);
    trainingPrivatePops = trainingPrivatePops.flat();
    var menuElem = menu.addOptions(trainingPrivatePops);

    if (lists.public_lists[0]) {
      var trainingPublicLists = list.convertArrayToJson(lists.public_lists);
      menu.addOptionsSeparator("public lists");
      menuElem = menu.addOptions(trainingPublicLists);
    }

    var datasetPops = solGS.dataset.getDatasetPops(["accessions", "plots", "trials"]);
    if (datasetPops) {
      menu.addOptionsSeparator("datasets");
      menuElem = menu.addOptions(datasetPops);
    }

    var trainingPopsDiv = this.trainingPopsDiv;
    jQuery(trainingPopsDiv).append(menuElem).show();
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

  askTrainingJobQueueing: function (listId) {
    var args = this.createTrainingReqArgs(listId);
    var modelId = args.training_pop_id;
    var protocolId = args.genotyping_protocol_id;

    var hostName = window.location.protocol + "//" + window.location.host;

    var page = hostName + "/solgs/population/" + modelId;

    if (protocolId) {
      page = page + "/gp/" + protocolId;
    }
    solGS.waitPage(page, args);
  },

  createTrainingReqArgs: function (listId) {
    const listObj = new solGSList(listId);
    var listDetail = listObj.getListDetail();
    var listName = listDetail.name;

    var popId = this.getModelId(listId);
    var protocolId = solGS.genotypingProtocol.getGenotypingProtocolId();
    var popType = "list_training";

    var args = {
      list_name: listName,
      list_id: listId,
      analysis_type: "training_dataset",
      data_set_type: "single_population",
      training_pop_id: popId,
      training_pop_name: listName,
      population_type: popType,
      genotyping_protocol_id: protocolId,
    };

    return args;
  },

  getModelId: function (listId) {
    var modelId = "list_" + listId;
    return modelId;
  },

  displayListTypeTrainingPops: function (args) {
    var trainingPopId = args.training_pop_id;
    var trainingPopName = args.training_pop_name;
    var popType = args.population_type;
    var protocolId = args.genotyping_protocol_id;

    var popDetail = { id: trainingPopId, name: trainingPopName, pop_type: popType };
    popDetail = JSON.stringify(popDetail);

    var tableId = "list_type_training_pops_table";
    var listTypeTrainingTable = jQuery(`#${tableId}`).doesExist();

    if (listTypeTrainingTable == false) {
      listTypeTrainingTable =
        `<table id="${tableId}" class="table"><thead><tr>` +
        "<th>List/dataset type training population</th>" +
        "<th>Detail page</th>" +
        "</tr></thead><tbody>";

      jQuery("#list_type_training_pops_selected").append(listTypeTrainingTable).show();
    }

    var popPath = `/solgs/population/${trainingPopId}/gp/${protocolId}`;
    var popLink = `<a href="${popPath}"  data-selected-pop='${popDetail}'>${trainingPopName}</a>`;

    var trId = `${popType}_${trainingPopId}`;
    var popDisplayed = jQuery(`#${trId}`).doesExist();
    if (popDisplayed == false) {
      var row =
        `<tr id='${trId}' data-selected-pop='${popDetail}'>` +
        `<td><b>${trainingPopName}</b></td>` +
        `<td>${popLink}</td>` +
        "</tr>";

      jQuery(`#${tableId} tr:last`).after(row);
    }
  },
};

jQuery.fn.doesExist = function () {
  return jQuery(this).length > 0;
};

jQuery(document).ready(function () {
  solGS.listTypeTrainingPopulation.populateTrainingPopsMenu();
});

jQuery(document).ready(function () {
  jQuery("#list_type_training_pops_select").change(function () {
    var selectedPop = jQuery("option:selected", this).data("pop");
    if (selectedPop.id) {
      jQuery("#list_type_training_pop_go_btn").click(function () {
        if (typeof selectedPop.data_str === "undefined" || selectedPop.data_str.match(/list/i)) {
          const list = new solGSList(selectedPop.id);
          var listDetail = list.getListDetail();
          var args;
          if (listDetail.type.match(/plots|trials/)) {
            args = solGS.listTypeTrainingPopulation.createTrainingReqArgs(selectedPop.id);
            solGS.listTypeTrainingPopulation.displayListTypeTrainingPops(args);
          }
        } else {
          args = solGS.dataset.createDatasetTrainingReqArgs(selectedPop.id, selectedPop.name);
        }
        solGS.listTypeTrainingPopulation.displayListTypeTrainingPops(args);
      });
    }
  });
});

jQuery("#list_type_training_pops_table").ready(function () {
  jQuery("body").on("click", "#list_type_training_pops_table tr a", function (row) {
    row.preventDefault();

    var selectedPop = row.target.dataset.selectedPop;

    selectedPop = JSON.parse(selectedPop);
    if (selectedPop.id.match(/\w+_/)) {
      selectedPop.id = selectedPop.id.replace(/\w+_/, "");
    }

    if (selectedPop.pop_type.match(/list/)) {
    
      const list = new solGSList(selectedPop.id);
      var listDetail = list.getListDetail();
      if (listDetail.type.match(/plots/)) {
        solGS.listTypeTrainingPopulation.askTrainingJobQueueing(selectedPop.id);
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
      solGS.dataset.datasetTrainingPop(selectedPop.id, selectedPop.name);
    }
  });
});
