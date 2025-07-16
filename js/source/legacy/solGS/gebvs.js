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
    var traitId = jQuery("#trait_id").val();
    var comboPopsId = jQuery("#combo_pops_id").val();
    var selectionPopId = jQuery("#selection_pop_id").val();
    var protocolId = jQuery("#genotyping_protocol_id").val();
    var trainingPopId = jQuery("#training_pop_id").val();
    var datasetType = jQuery("#data_set_type").val();

    var params = {
      training_pop_id: trainingPopId,
      combo_pops_id: comboPopsId,
      selection_pop_id: selectionPopId,
      genotyping_protocol_id: protocolId,
      trait_id: traitId,
      data_set_type: datasetType
    };

    return params;
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

      var gebvsHistoPlotDivId = this.histoPlotId.replace(/#/, '');
      var histoDownloadBtn = "download_" + gebvsHistoPlotDivId;
      var histoPlotLink = "<a href='#'  onclick='event.preventDefault();' id='" + histoDownloadBtn + "'> Histogram (GEBVs)</a>";
    
      var downloadLinks = `Download:  ${gebvsFileLink} | ${histoPlotLink}`;
      return downloadLinks;

  },

  createGeneticValuesDownloadLinks: function (res) {
    var geneticValuesFileName = res.genetic_values_file.split("/").pop();
    var geneticValuesFileLink =
      '<a href="' +
      res.genetic_values_file +
      '" download=' +
      geneticValuesFileName +
      '">' +
      "Genetic values" +
      "</a>";
    
      return geneticValuesFileLink;

  },

  /////
};
/////

jQuery(document).ready(function () {
    solGS.checkPageType().done(function (res) {
        if (res.page_type.match(/training_model|selection_prediction/)) {
            solGS.gebvs.getGebvsFiles().done(function (res) {
                var gebvsDownloadLinks = solGS.gebvs.createGebvsDownloadLinks(res);
                var geneticValuesDownloadLinks = solGS.gebvs.createGeneticValuesDownloadLinks(res);
                var downloadLinks = `${gebvsDownloadLinks} | ${geneticValuesDownloadLinks}`;
                console.log(`Calling getGebvsData`)

                solGS.gebvs.getGebvsData().done(function (res) {
                    console.log(`getGebvsData res: ${JSON.stringify(res)}`)
                    solGS.gebvs.plotGebvs(res.gebvs_data, downloadLinks);
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
