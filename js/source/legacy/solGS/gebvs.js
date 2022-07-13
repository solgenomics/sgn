/**
 * for graphical presentation and downloading of GEBVs of a trait model.
 *
 * @author Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.gebvs = {
  getGebvsParams: function () {
    return solGS.getSelectionPredictionArgs();
  },

  getGebvsData: function () {
    var action = "/solgs/trait/gebvs/data";
    var params = this.getGebvsParams();
    params = JSON.stringify(params);

    var gebvsData = jQuery.ajax({
      async: false,
      type: 'POST',
      url: action,
      dataType: "json",
      data: {arguments: params},
    });

    return gebvsData;
  },

  plotGebvs: function (gebvsData) {
    var histoArgs = {
      canvas: "#gebvs_histo_canvas",
      plot_id: "#gebvs_histo_plot",
      x_label: "GEBVs",
      y_label: "Counts",
      namedValues: gebvsData,
    };

    solGS.histogram.plotHistogram(histoArgs);
  },

  getGebvsFiles: function () {
    var args = solGS.getSelectionPredictionArgs();
    args = JSON.stringify(args);

    var gebvsDataReq = jQuery.ajax({
      type: "POST",
      dataType: "json",
      data: {
        arguments: args,
      },
      url: "/solgs/download/gebvs/pop",
    });

    return gebvsDataReq;
  },

  createGebvsDownloadLinks: function (res) {
    var gebvsFileName = res.gebvs_file.split("/").pop();
    var gebvsFileLink =
      '<a href="' +
      res.gebvs_file +
      '" download=' +
      gebvsFileName +
      '">' +
      "Download GEBVs" +
      "</a>";

    jQuery("#gebvs_output").prepend(gebvsFileLink + " | ");
  },

  /////
};
/////

jQuery(document).ready(function () {
  solGS.gebvs.getGebvsData().done(function (res) {
    solGS.gebvs.plotGebvs(res.gebvs_data);
  });

  solGS.checkPageType().done(function (res) {
    if (res.page_type.match(/training model|selection population/)) {
      solGS.gebvs.getGebvsFiles().done(function (res) {
        solGS.gebvs.createGebvsDownloadLinks(res);
      });

      solGS.gebvs.getGebvsFiles().fail(function (res) {
        var errorMsg = "Error occured getting training gebvs files.";
        jQuery("#gebvs_output_message").html(errorMsg);
      });
    }
  });
});
