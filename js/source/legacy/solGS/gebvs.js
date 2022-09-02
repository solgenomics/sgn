/**
 * for graphical presentation and downloading of GEBVs of a trait model.
 *
 * @author Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.gebvs = {
  getGebvsParams: function () {
    var popId = jQuery("#model_id").val();
    var traitId = jQuery("#trait_id").val();
    var comboPopsId = jQuery("#combo_pops_id").val();
    var selectionPopId = jQuery("#selection_pop_id").val();
    var protocolId = jQuery("#genotyping_protocol_id").val();

    var params = {
      training_pop_id: popId,
      combo_pops_id: comboPopsId,
      selection_pop_id: selectionPopId,
      genotyping_protocol_id: protocolId,
      trait_id: traitId,
    };

    return params;
  },

  getGebvsData: function () {
    var action = "/solgs/trait/gebvs/data";
    var params = this.getGebvsParams();

    var gebvsData = jQuery.ajax({
      async: false,
      url: action,
      dataType: "json",
      data: params,
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
    var trainingTraitsIds = solGS.getTrainingTraitsIds();
    var args = {
      training_pop_id: jQuery("#training_pop_id").val(),
      selection_pop_id: jQuery("#selection_pop_id").val(),
      training_traits_ids: trainingTraitsIds,
      genotyping_protocol_id: jQuery("#genotyping_protocol_id").val(),
    };

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
