/**
 * solGS prediction raw, model input and output downloads
 * Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.download = {
  getTrainingPopRawDataFiles: function () {
    var args = {
      training_pop_id: jQuery("#training_pop_id").val(),
      genotyping_protocol_id: jQuery("#genotyping_protocol_id").val(),
    };

    args = JSON.stringify(args);

    jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        arguments: args,
      },
      url: "/solgs/download/training/pop/data",
      success: function (res) {
        var errorMsg = "Error occured getting training pop data download links.";

        if (res) {
          solGS.download.createTrainingPopDownloadLinks(res);
        } else {
          jQuery("#training_pop_download_message").html(errorMsg);
        }
      },
      error: function (res) {
        jQuery("#training_pop_download_message").html("errorMsg");
      },
    });
  },

  createTrainingPopDownloadLinks: function (res) {
    var genoFile = res.training_pop_raw_geno_file;
    var phenoFile = res.training_pop_raw_pheno_file;

    console.log("geno file: " + genoFile);
    console.log("pheno file: " + phenoFile);

    var genoFileName = genoFile.split("/").pop();
    var genoFileLink =
      '<a href="' + genoFile + '" download=' + genoFileName + '">' + "Genotype data" + "</a>";

    var phenoFileName = phenoFile.split("/").pop();
    var phenoFileLink =
      '<a href="' + phenoFile + '" download=' + phenoFileName + '">' + "Phenotype data" + "</a>";

    var downloadLinks =
      " <strong>Download " +
      "Training population" +
      " </strong>: " +
      genoFileLink +
      " | " +
      phenoFileLink;

    jQuery("#training_pop_download").prepend(
      '<p style="margin-top: 20px">' + downloadLinks + "</p>"
    );
  },
};

jQuery(document).ready(function () {
  solGS.download.getTrainingPopRawDataFiles();
});
