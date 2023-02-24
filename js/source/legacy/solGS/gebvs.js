/**
 * for graphical presentation and downloading of GEBVs of a trait model.
 *
 * @author Isaak Y Tecle <iyt2@cornell.edu>
 *
 */

var solGS = solGS || function solGS() {};

solGS.gebvs = {

  histoCanvasId: "#gebvs_histo_canvas",
  histoPlotId: "#gebvs_histo_plot",

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

  plotGebvs: function (gebvsData, downloadLinks) {

    var histoArgs = {
      canvas: this.histoCanvasId,
      plot_id: this.histoPlotId,
      x_label: "GEBVs",
      y_label: "Counts",
      named_values: gebvsData,
      download_links: downloadLinks,

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
      "GEBVs" +
      "</a>";

      // var gebvsFileId = res.gebvs_file_id.replace(/-/g, "_")
      var gebvsHistoPlotDivId = this.histoPlotId.replace(/#/, '');
      var histoDownloadBtn = "download_" + gebvsHistoPlotDivId; //+ gebvsFileId;
      var histoPlotLink = "<a href='#'  onclick='event.preventDefault();' id='" + histoDownloadBtn + "'> Histogram</a>";

      //  var downloadLinks =  jQuery("#gebvs_output").prepend(`Download:  ${gebvsFileLink} | ${histoPlotLink} | `);
    
      var downloadLinks = `Download:  ${gebvsFileLink} | ${histoPlotLink}`;
      return downloadLinks;

  },

  /////
};
/////

jQuery(document).ready(function () {

  solGS.checkPageType().done(function (res) {
    if (res.page_type.match(/training_model|selection_prediction/)) {
      
        solGS.gebvs.getGebvsFiles().done(function (res) {
        var gebvsDownloadLinks = solGS.gebvs.createGebvsDownloadLinks(res);

        solGS.gebvs.getGebvsData().done(function (res) {
        solGS.gebvs.plotGebvs(res.gebvs_data, gebvsDownloadLinks);
        });
      });

      solGS.gebvs.getGebvsFiles().fail(function (res) {
        var errorMsg = "Error occured getting training gebvs files.";
        jQuery("#gebvs_output_message").html(errorMsg);
      });
    }
  });

  jQuery("#gebvs_histo_canvas").on('click' , 'a', function(e) {
		var buttonId = e.target.id;
		var histoPlotId = buttonId.replace(/download_/, '');
		saveSvgAsPng(document.getElementById("#" + histoPlotId),  histoPlotId + ".png", {scale:1});	
	});

});
