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
    var protocolId = jQuery("#genotyping_protocol_id").val();
    var popType = "list_training";

    var args = {
      list_name: listName,
      list_id: listId,
      analysis_type: "training_dataset",
      data_set_type: "single_population",
      training_pop_id: popId,
      population_type: popType,
      genotyping_protocol_id: protocolId,
    };

    return args;
  },

  loadPlotListTypeTrainingPop: function (listId) {
    var args = this.createTrainingReqArgs(listId);

    if (window.Prototype) {
      delete Array.prototype.toJSON;
    }

    args = JSON.stringify(args);

    if (args.list.length === 0) {
      alert("The list is empty. Please select a list with content.");
    } else {
      // jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
      // jQuery.blockUI({ message: "Please wait.." });

      var plotsList = jQuery.ajax({
        type: "POST",
        dataType: "json",
        data: { arguments: args },
        url: "/solgs/load/plots/list/training",
      });

      return plotsList;
    }

    //       success: function (response) {
    //         if (response.status == "success") {
    //           window.location = "/solgs/population/" + popId;
    //           jQuery.unblockUI();
    //         } else {
    //           alert("Error occured while querying for the training data.");
    //           jQuery.unblockUI();
    //         }
    //       },
    //       error: function (res) {
    //         alert("Error occured while querying for the training data.");
    //         jQuery.unblockUI();
    //       },
    //     });
    //   }
  },

  getModelId: function (listId) {
    var modelId = "list_" + listId;
    return modelId;
  },

  getUserUploadedRefPop: function (listId) {
    const listObj = new solGSList(listId);
    var listDetail = listObj.getListDetail();
    var listName = listDetail.name;
    var modelId = this.getModelId(listId);

    var url = "'/solgs/population/" + modelId + "'";
    var listIdArg = "'" + listId + "'";
    var listSource = "'from_db'";
    var popIdName = { id: modelId, name: listName };
    popIdName = JSON.stringify(popIdName);
    var hiddenInput = '<input type="hidden" value=\'' + popIdName + "'/>";

    var listSelPop =
      '<table id="list_reference_pops_table" style="width:100%; text-align:left"><tr>' +
      "<th>List-based training population</th>" +
      "<th>Models</th>" +
      "</tr>" +
      "<tr>" +
      "<td>" +
      '<a href="/solgs/population/' +
      modelId +
      '" onclick="javascript:loadPopulationPage(' +
      url +
      "," +
      listIdArg +
      "," +
      listSource +
      ')">' +
      "<data>" +
      hiddenInput +
      "</data>" +
      listName +
      "</a>" +
      "</td>" +
      '<td id="list_reference_page_' +
      modelId +
      '">' +
      '<a href="/solgs/population/' +
      modelId +
      '" onclick="javascript:loadPopulationPage(' +
      url +
      "," +
      listIdArg +
      "," +
      listSource +
      ')">' +
      "[ Build model ]" +
      "</a>" +
      "</td></tr></table>";

    return listSelPop;
  },

  displayListTypeTrainingPops: function (listId) {
    const listObj = new solGSList(listId);
    var listDetail = listObj.getListDetail();
    var listName = listDetail.name;
    var modelId = this.getModelId(listId);


    var popIdName = { id: modelId, name: listName, pop_type: "list_training" };
    popIdName = JSON.stringify(popIdName);
    var hiddenInput = '<input type="hidden" value=\'' + popIdName + "'/>";

    var tableId = "list_type_training_pops_table";
    var trId = "list_training_" + listId;
    var listTypeSelectionPops = jQuery(`#${tableId}`).doesExist();

    if (listTypeSelectionPops == false) {
      var listTypeTrainingTable =
        `<table id="${tableId}" class="table"><thead><tr>` +
        "<th>List-based tranining population</th>" +
        "<th>View Population</th>" +
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

      jQuery("#list_type_training_pops_selected").append(listTypeTrainingTable).show();
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

  loadPopulationPage: function (url, listId, listSource) {
    const listObj = new solGSList(listId);
    var listDetail = listObj.getListDetail();
    var listName = listDetail.name;
    var modelId = this.getModelId(listId);

    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({ message: "Please wait.." });

    jQuery.ajax({
      type: "POST",
      url: url,
      dataType: "json",
      data: {
        list_reference: 1,
        model_id: modelId,
        list_source: listSource,
        list_name: listName,
      },
      success: function (response) {
        if (response.status == "success") {
          jQuery.unblockUI();
        } else {
          alert("Fail: Error occured calculating GEBVs for the list of selection genotypes.");
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
  solGS.listTypeTrainingPopulation.populateTrainingPopsMenu();
});

jQuery(document).ready(function () {
  jQuery("#list_type_training_pops_select").change(function () {
    var selectedPop = jQuery("option:selected", this).data("pop");
    if (selectedPop.id) {
      jQuery("#list_type_training_pop_go_btn").click(function () {
        if (
          typeof selectedPop.data_str === "undefined" ||
          !selectedPop.data_str.match(/dataset/i)
        ) {
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
    }
  });
});
