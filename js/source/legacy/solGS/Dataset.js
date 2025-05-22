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

  addDataTypeAttr(datasets, analysis) {

    // for (var i = 0; i < datasets.length; i++) {
    //   if (datasets[i].type.match(/accessions/)) {
    //     datasets[i]["data_type"] = ["Genotype"];
    //   } else if (datasets[i].type.match(/plots/)) {
    //     datasets[i]["data_type"] = ["Phenotype"];
    //   } else if (datasets[i].type.match(/trials/)) {
    //     datasets[i]["data_type"] = ["Genotype", "Phenotype"];
    //   }
  
    // }
    var type_opts;
    if (analysis == "Population Structure") {
      type_opts = ["Genotype", "Phenotype"];
    } else if (analysis == "Clustering") {
      type_opts = ["Genotype", "Phenotype", "GEBV"];
    }

    for (var i = 0; i < datasets.length; i++) {
      datasets[i]["data_type"] = type_opts;
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
      for (var j = 0; j < datasetTypes.length; j++) {
        if (d.categories[datasetTypes[j]] && d.categories[datasetTypes[j]].length) {
          if (!dsIds.includes(id)) {
            var dsObj = {
              id: id,
              name: name,
              type: datasetTypes[j],
              data_str: "dataset",
              tool_compatibility: d.tool_compatibility
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
    console.log(allDatasets);
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


  getDatasetGenoProtocolId: function (datasetId) {
    var dataset = new CXGN.Dataset();
    var d = dataset.getDataset(datasetId);

    var protocolId = d.categories["genotyping_protocols"]
    ? d.categories["genotyping_protocols"][0]
    : null;

    if (!protocolId) {
      protocolId = jQuery("#genotyping_protocol_id").val();
    }

    return protocolId;

  },

  createDatasetTrainingReqArgs: function (datasetId, datasetName) {
   
    var protocolId = this.getDatasetGenoProtocolId(datasetId);

    var args = {
      dataset_name: datasetName,
      dataset_id: datasetId,
      analysis_type: "dataset_type_training",
      data_set_type: "single_population",
      training_pop_id: `dataset_${datasetId}`,
      training_pop_name: datasetName,
      population_type: "dataset_training",
      genotyping_protocol_id: protocolId,
      data_structure: 'dataset'
    };

    return args;
  },

  createDatasetTypeSelectionReqArgs: function (datasetId, datasetName) {
    var selectionPopId = "dataset_" + datasetId;

    var modelArgs = solGS.getModelArgs();
    var protocolId = this.getDatasetGenoProtocolId(datasetId);
   
    var args = {
      dataset_id: datasetId,
      dataset_name: datasetName,
      training_pop_id: modelArgs.training_pop_id,
      selection_pop_id: selectionPopId,
      selection_pop_name: datasetName,
      training_traits_ids: modelArgs.training_traits_ids,
      population_type: "dataset_selection",
      data_set_type: modelArgs.data_set_type,
      genotyping_protocol_id: protocolId,
      data_structure: 'dataset'
    };

    return args;

  },


  checkPredictedDatasetSelection: function (datasetId, datasetName) {
    var args = this.createDatasetTypeSelectionReqArgs(datasetId, datasetName);
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

      var checkPredicted = jQuery.ajax({
        type: "POST",
        dataType: "json",
        data: { arguments: args },
        url: "/solgs/check/predicted/dataset/selection",
      });

      return checkPredicted;
  }

  },

  queueDatasetSelectionPredictionJob: function (datasetId, datasetName) {
    var args = this.createDatasetTypeSelectionReqArgs(datasetId, datasetName);
    var modelId = args.training_pop_id;
    var selectionPopId = args.selection_pop_id;
    var traitId = args.training_traits_ids;
    var protocolId = args.genotyping_protocol_id;

    var hostName = window.location.protocol + "//" + window.location.host;
    var page;

    if (document.URL.match(/combined/)) {
      page = `${hostName}/solgs/combined/model/${modelId}/selection/${selectionPopId}/trait/${traitId}/gp/${protocolId}`;
    } else {
      page = `${hostName}/solgs/selection/${selectionPopId}/model/${modelId}/trait/${traitId}/gp/${protocolId}`;
    }

    solGS.waitPage(page, args);
  },

  /////
};
/////
