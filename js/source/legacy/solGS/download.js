/**
 * solGS prediction raw, model input downloads
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.download = {
  getTrainingPopRawDataFiles: function () {
    var args = solGS.getTrainingPopArgs();
    args = JSON.stringify(args);

    var popDataReq = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        arguments: args,
      },
      url: "/solgs/download/training/pop/data",
    });

    return popDataReq;
  },

  createTrainingPopDownloadLinks: function (res) {
    var genoFile = res.training_pop_raw_geno_file;
    var phenoFile = res.training_pop_raw_pheno_file;

    var genoFileName = genoFile.split("/").pop();
    var genoFileLink =
      '<a href="' + genoFile + '" download=' + genoFileName + '">' + "Genotype data" + "</a>";

    var phenoFileName = phenoFile.split("/").pop();
    var phenoFileLink =
      '<a href="' + phenoFile + '" download=' + phenoFileName + '">' + "Phenotype data" + "</a>";

    var downloadLinks =
      " <strong>Download training population</strong>: " +
      genoFileLink +
      " | " +
      phenoFileLink;

    jQuery("#training_pop_download").prepend(
      '<p style="margin-top: 20px">' + downloadLinks + "</p>"
    );
  },

  getModelInputDataFiles: function () {
    var args = solGS.getModelArgs();
    args = JSON.stringify(args);

    var modelInputReq = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        arguments: args,
      },
      url: "/solgs/download/model/input/data",
    });

    return modelInputReq;
  },

  createModelInputDownloadLinks: function (res) {
    var genoFile = res.model_geno_data_file;
    var phenoFile = res.model_pheno_data_file;

    console.log("geno file: " + genoFile);
    console.log("pheno file: " + phenoFile);

    var genoFileName = genoFile.split("/").pop();
    var genoFileLink =
      '<a href="' + genoFile + '" download=' + genoFileName + '">' + "Genotype data" + "</a>";

    var phenoFileName = phenoFile.split("/").pop();
    var phenoFileLink =
      '<a href="' + phenoFile + '" download=' + phenoFileName + '">' + "Phenotype data" + "</a>";

    var downloadLinks =
      " <strong>Download model</strong>: " + genoFileLink + " | " + phenoFileLink;

    jQuery("#model_input_data_download").prepend(
      '<p style="margin-top: 20px">' + downloadLinks + "</p>"
    );
  },

  getValidationFile: function () {
    var args = solGS.getModelArgs();
    args = JSON.stringify(args);

    var valDataReq = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        arguments: args,
      },
      url: "/solgs/download/model/validation",
    });

    return valDataReq;
  },

  createValidationDownloadLink: function (res) {
    var valFileName = res.validation_file.split("/").pop();
    var valFileLink =
      '<a href="' +
      res.validation_file +
      '" download=' +
      valFileName +
      '">' +
      "Download model accuracy" +
      "</a>";

    jQuery("#validation_download").prepend('<p style="margin-top: 20px">' + valFileLink + "</p>");
  },

  getMarkerEffectsFile: function () {
    var args = solGS.getModelArgs();
    args = JSON.stringify(args);

    var markerEffectsReq = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        arguments: args,
      },
      url: "/solgs/download/model/marker/effects",
    });

    return markerEffectsReq;
  },

  createMarkerEffectsDownloadLink: function (res) {
    var effectsFileName = res.marker_effects_file.split("/").pop();
    var effectsFileLink =
      '<a href="' +
      res.marker_effects_file +
      '" download=' +
      effectsFileName +
      '">' +
      "Download marker effects" +
      "</a>";

    jQuery("#marker_effects_download").prepend(
      '<p style="margin-top: 20px">' + effectsFileLink + "</p>"
    );
  },
};

jQuery(document).ready(function () {
  solGS.checkPageType().done(function (res) {
    if (res.page_type.match(/training population/)) {
      solGS.download.getTrainingPopRawDataFiles().done(function (res) {
        solGS.download.createTrainingPopDownloadLinks(res);
      });

      solGS.download.getTrainingPopRawDataFiles().fail(function (res) {
        var errorMsg = "Error occured getting training pop raw data files.";
        jQuery("#download_message").html(errorMsg);
      });
    } else if (res.page_type.match(/training model/)) {
      solGS.download.getModelInputDataFiles().done(function (res) {
        solGS.download.createModelInputDownloadLinks(res);
      });

      solGS.download.getModelInputDataFiles().fail(function (res) {
        var errorMsg = "Error occured getting model input data files.";
        jQuery("#download_message").html(errorMsg);
      });

      solGS.download.getValidationFile().done(function (res) {
        solGS.download.createValidationDownloadLink(res);
      });

      solGS.download.getValidationFile().fail(function (res) {
        var errorMsg = "Error occured getting model validation file.";
        jQuery("#validation_download_message").html(errorMsg);
      });

      solGS.download.getMarkerEffectsFile().done(function (res) {
        solGS.download.createMarkerEffectsDownloadLink(res);
      });

      solGS.download.getMarkerEffectsFile().fail(function (res) {
        var errorMsg = "Error occured getting marker effects file.";
        jQuery("#marker_effects_download_message").html(errorMsg);
      });
    }
  });

  solGS.checkPageType().fail(function (res) {
    solGS.alertMessage("Error occured checking for page type.");
  });
});
