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
    return solGS.getSelectionPredictionArgs();
  },

  getGebvsData: function () {
    
    var gebvsArgs = this.getGebvsParams();
    gebvsArgs = JSON.stringify(gebvsArgs);

    var gebvsData = jQuery.ajax({
      async: false,
      type: "POST",
      url: "/solgs/trait/gebvs/data",
      dataType: "json",
      data: {'arguments': gebvsArgs},
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
