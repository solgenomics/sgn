/**
 * adds dataset related objects to the solGS object
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.dataset = {
  getDataset: function (id) {
    var dataset = new CXGN.Dataset();
    var allDatasets = dataset.getDatasets();
    var data = {};

    for (var i = 0; i < allDatasets.length; i++) {
      if (allDatasets[i][0] == id) {
        data.name = allDatasets[i][1];
        data.id = id;
      }
    }

    return data;
  },

  addDataOwnerAttr(datasets, owner) {

    for (var i = 0; i < datasets.length; i++) {
      if (datasets[i]) {
        datasets[i]["owner"] = owner;
      }
    }

    return datasets;
  },

  converDatasetArrayToJson(datasets, datasetTypes) {

    var dataset = new CXGN.Dataset();
    var dsIds = [];
    var datasetPops = [];
    for (var i = 0; i < datasets.length; i++) {
      var id = datasets[i][0];
      var name = datasets[i][1];
      var d = dataset.getDataset(id);
      console.log(`d: ${JSON.stringify(d)}`)
      for (var j = 0; j < datasetTypes.length; j++) {
        if (d.categories[datasetTypes[j]] && d.categories[datasetTypes[j]].length) {
          if (!dsIds.includes(id)) {
            var dsObj = {
              id: id,
              name: name,
              type: datasetTypes[j],
              data_str: "dataset",
            };
            datasetPops.push(dsObj);
            dsIds.push(id);
          }
        }
      }
    }

    return datasetPops;

  },

  getDatasetPops: function (datasetTypes) {
    if (!Array.isArray(datasetTypes)) {
      datasetTypes = [datasetTypes];
    }
    var dataset = new CXGN.Dataset();
    
    var publicDatasets = dataset.getPublicDatasets();
    publicDatasets = this.converDatasetArrayToJson(publicDatasets, datasetTypes);
    publicDatasets = this.addDataOwnerAttr(publicDatasets, 'public')


    var privateDatasets = dataset.getDatasets();
    privateDatasets = this.converDatasetArrayToJson(privateDatasets, datasetTypes);
    privateDatasets = this.addDataOwnerAttr(privateDatasets, 'private')
    
    var allDatasets = [privateDatasets, publicDatasets];
    return allDatasets.flat();
    
  },

  datasetTrainingPop: function (datasetId) {
    var dataset = new CXGN.Dataset();
    var d = dataset.getDataset(datasetId);
    var plots = d.categories["plots"];

    if (plots == "") {
      plots = null;
    }

    if (d.categories["trials"] && plots == null) {
      this.datasetTrialsTrainingPop(datasetId);
    } else if (d.categories["trials"] && d.categories["plots"]) {
      this.datasetPlotsTrainingPop(datasetId);
    }
  },

  datasetTrialsTrainingPop: function (datasetId) {
    jQuery.ajax({
      type: "POST",
      dataType: "json",
      url: "/solgs/get/dataset/trials",
      data: {
        dataset_id: datasetId,
      },
      success: function (res) {
        var trialsIds = res.trials_ids;
        var comboPopsId = res.combo_pops_id;
        var genoProId = res.genotyping_protocol_id;

        if (trialsIds) {
          var args = {
            combo_pops_id: [comboPopsId],
            combo_pops_list: trialsIds,
            genotyping_protocol_id: genoProId,
          };

          var singleArgs = {
            trial_id: trialsIds[0],
            genotyping_protocol_id: genoProId,
          };

          if (trialsIds.length > 1) {
            solGS.combinedTrials.downloadCombinedTrialsTrainingPopData(args);
          } else {
            solGS.combinedTrials.downloadSingleTrialTrainingPopData(singleArgs);
          }
        } else {
          Alert("No trials ids were found for this dataset");
        }
      },
      error: function (res) {
        Alert("Error Occurred fetching trials ids in the dataset. " + res.responseText);
      },
    });
  },

  datasetPlotsTrainingPop: function (datasetId, datasetName) {
    this.queueDatasetPlotsTrainingPop(datasetId, datasetName);
  },

  queueDatasetPlotsTrainingPop: function (datasetId, datasetName) {
    var args = this.createDatasetTrainingReqArgs(datasetId, datasetName);
    var modelId = args.training_pop_id;

    var hostName = window.location.protocol + "//" + window.location.host;
    var page = hostName + "/solgs/population/" + modelId;

    solGS.waitPage(page, args);
  },

  createDatasetTrainingReqArgs: function (datasetId, datasetName) {
    var dataset = new CXGN.Dataset();
    var d = dataset.getDataset(datasetId);

    var protocolId = d.categories["genotyping_protocols"]
      ? d.categories["genotyping_protocols"][0]
      : null;

    if (!protocolId) {
      protocolId = jQuery("#genotyping_protocol_id").val();
    }

    var popId = "dataset_" + datasetId;
    var popType = "dataset_training";

    var args = {
      dataset_name: datasetName,
      dataset_id: datasetId,
      analysis_type: "training_dataset",
      data_set_type: "single_population",
      training_pop_id: popId,
      training_pop_name: datasetName,
      population_type: popType,
      genotyping_protocol_id: protocolId,
    };

    return args;
  },

  createDatasetSelectionArgs: function (datasetId, datasetName) {
    var trainingPopDetails = solGS.getPopulationDetails();
    var selectionPopId = "dataset_" + datasetId;

    var trainingTraitsIds = solGS.getTrainingTraitsIds();

    var dataset = new CXGN.Dataset();
    var d = dataset.getDataset(datasetId);

    var protocols = solGS.genotypingProtocol.getPredictionGenotypingProtocols();
    var selPopProtocolId;
    var protocolId = protocols.genotyping_protocol_id;
    if (d.categories["genotyping_protocols"]) {
      selPopProtocolId = d.categories["genotyping_protocols"][0];
    } else {
      selPopProtocolId = protocols.selection_pop_genotyping_protocol_id;
    }

    var args = {
      dataset_id: datasetId,
      dataset_name: datasetName,
      training_pop_id: trainingPopDetails.training_pop_id,
      selection_pop_id: selectionPopId,
      selection_pop_name: datasetName,
      training_traits_ids: trainingTraitsIds,
      population_type: "dataset_selection",
      data_set_type: trainingPopDetails.data_set_type,
      genotyping_protocol_id: protocolId,
      selection_pop_genotyping_protocol_id: selPopProtocolId,
    };

    return args;
  },

  checkPredictedDatasetSelection: function (datasetId, datasetName) {
    var args = this.createDatasetSelectionArgs(datasetId, datasetName);

    var trainingPopGenoPro = jQuery("#genotyping_protocol_id").val();
    var selectionPopGenoPro = args.genotyping_protocol_id;

    if (trainingPopGenoPro != selectionPopGenoPro) {
      var msg =
        "This dataset of selection candidates has a " +
        "different genotyping protocol from the training " +
        "population. Please use a dataset with " +
        "a matching genotyping protocol.";

      solGS.alertMessage(msg);
    } else {
      args = JSON.stringify(args);

      jQuery.ajax({
        type: "POST",
        dataType: "json",
        data: {
          arguments: args,
        },
        url: "/solgs/check/predicted/dataset/selection",
        success: function (response) {
          args = JSON.parse(args);
          var selPopLink = response.output;
          if (selPopLink) {
            solGS.listTypeSelectionPopulation.displayListTypeSelectionPops(
              args,
              selPopLink
            );

            if (document.URL.match(/solgs\/traits\/all\/|solgs\/models\/combined\//)) {
              solGS.sIndex.populateSindexMenu();
              solGS.correlation.populateGenCorrMenu();
              solGS.geneticGain.ggSelectionPopulations();
              solGS.cluster.listClusterPopulations();
            }
          } else {
            solGS.dataset.queueDatasetSelectionPredictionJob(datasetId, selPopLink);
          }
        },
      });
    }
  },

  queueDatasetSelectionPredictionJob: function (datasetId, selPopLink) {
    var args = this.createDatasetSelectionArgs(datasetId);
    solGS.waitPage(selPopLink, args);
  },

  /////
};
/////
