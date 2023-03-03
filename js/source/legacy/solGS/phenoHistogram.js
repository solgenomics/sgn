


var solGS = solGS || function solGS () {};

solGS.phenoHistogram =  {

    PhenoRawHistoCanvas: '#pheno_raw_histo_canvas',
    PhenoRawHistoPlotDiv: '#pheno_raw_histo_plot',
    PhenoMeansHistoCanvas: '#pheno_means_histo_canvas',
    PhenoMeansHistoPlotDiv: '#pheno_means_histo_plot',

    getTraitPhenoMeansData: function () {

	var params = this.getHistogramParams();
    params = JSON.stringify(params);
	var histoData = jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'arguments': params},
            url: '/trait/pheno/means/data/',
        });

       return histoData;
    },

    getTraitPhenoRawData: function () {

	var params = this.getHistogramParams();
    params = JSON.stringify(params);
	var histoData = jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'arguments': params},
            url: '/trait/pheno/raw/data/',
        });

       return histoData;
    },

    getHistogramParams: function () {

	var traitId      = jQuery("#trait_id").val();
	var population   = solGS.getPopulationDetails();
	var populationId = population.training_pop_id;
	var comboPopsId  = population.combo_pops_id;
    var protocolId = jQuery("#genotyping_protocol_id").val();

	var params = {
	    'trait_id'     : traitId,
	    'training_pop_id': populationId,
	    'combo_pops_id'  : comboPopsId,
        'genotyping_protocol_id': protocolId
	};

	return params;
    },

    createHistoDownloadLinks: function (phenoTypeHistoDivId) {

        var phenoTypeHistoDivId = phenoTypeHistoDivId.replace(/#/, '');
        var histoDownloadBtn = "download_" + phenoTypeHistoDivId;
        var histoPlotLink = "<a href='#'  onclick='event.preventDefault();' id='" + histoDownloadBtn + "'> Histogram</a>";
        var downloadLinks = `Download:  ${histoPlotLink}`;

        return downloadLinks;
    
      },

////////
}
////////

jQuery(document).ready(function() {
    jQuery(function() {
        jQuery("#tabs_phenotype").tabs({
        event: "mouseover"
        });
    });
});


jQuery(document).ready(function () {
    var PhenoRawHistoCanvas = solGS.phenoHistogram.PhenoRawHistoCanvas;
    var PhenoRawHistoPlotDiv = solGS.phenoHistogram.PhenoRawHistoPlotDiv;
    var PhenoMeansHistoCanvas = solGS.phenoHistogram.PhenoMeansHistoCanvas;
    var PhenoMeansHistoPlotDiv = solGS.phenoHistogram.PhenoMeansHistoPlotDiv;
  
    var histMsgId = `${PhenoRawHistoCanvas} #histogram_message`;
    solGS.phenoHistogram.getTraitPhenoMeansData().done(function(res) {

        if (res.status == 'success') {
           var traitData = res.data;
           var variation = solGS.histogram.checkDataVariation(traitData);

            if (variation.uniq_count == 1) {
                var msg = '<p> All of the valid observations '
                                  + '('+ variation.obs_count +') ' + 'in this dataset have '
                                  + 'a value of ' + variation.uniqValue
                                  + '. No frequency distribution plot.</p>';

                solGS.showMessage(histMsgId, msg);

            } else {
                var phenoMeansPlotLinks= solGS.phenoHistogram.createHistoDownloadLinks(PhenoMeansHistoPlotDiv);
                var args = {
                    'named_values' : traitData,
                    'canvas' : PhenoMeansHistoCanvas,
                    'plot_id': PhenoMeansHistoPlotDiv,
                    'download_links': phenoMeansPlotLinks
                };

                solGS.histogram.plotHistogram(args);
                jQuery(histMsgId).empty();

            }
       } else {
            var msg = "<p>This trait has no phenotype data to plot.</p>";
            solGS.showMessage(histMsgId, msg);
       }

    });

    solGS.phenoHistogram.getTraitPhenoMeansData().fail(function(res) {
        var msg = "<p>Error occured plotting histogram for this trait dataset.</p>";
        solGS.showMessage(histMsgId, msg);
    });



    var histMsgIdRaw = "#pheno_raw_histogram_canvas #histogram_message";
    solGS.phenoHistogram.getTraitPhenoRawData().done(function(res) {

         if (res.status == 'success') {
            var traitRawData = res.data;
            var variationRaw = solGS.histogram.checkDataVariation(traitRawData);

             if (variationRaw.uniq_count == 1) {
                 var msg = '<p> All of the valid observations '
                                   + '('+ variationRaw.obs_count +') ' + 'in this dataset have '
                                   + 'a value of ' + variationRaw.uniqValue
                                   + '. No frequency distribution plot.</p>';

                 solGS.showMessage(histMsgIdRaw, msg);

             } else {
                var phenoRawPlotLinks= solGS.phenoHistogram.createHistoDownloadLinks(PhenoRawHistoPlotDiv);
                 var args = {
                     'named_values' : traitRawData,
                     'canvas' : PhenoRawHistoCanvas,
                     'plot_id': PhenoRawHistoPlotDiv,
                     'download_links': phenoRawPlotLinks
                 };

                 solGS.histogram.plotHistogram(args);
                 jQuery(histMsgIdRaw).empty();

             }
        } else {
             var msg = "<p>This trait has no phenotype data to plot.</p>";
             solGS.showMessage(histMsgIdRaw, msg);
        }

     });

     solGS.phenoHistogram.getTraitPhenoRawData().fail(function(res) {
         var msg = "<p>Error occured plotting histogram for this trait dataset.</p>";
         solGS.showMessage(histMsgIdRaw, msg);
     });


     jQuery("#pheno_means_histo_canvas").on('click' , 'a', function(e) {
		var buttonId = e.target.id;
		var histoPlotId = buttonId.replace(/download_/, '');
		saveSvgAsPng(document.getElementById("#" + histoPlotId),  histoPlotId + ".png", {scale:1});	
	});

    jQuery("#pheno_raw_histo_canvas").on('click' , 'a', function(e) {
		var buttonId = e.target.id;
		var histoPlotId = buttonId.replace(/download_/, '');
		saveSvgAsPng(document.getElementById("#" + histoPlotId),  histoPlotId + ".png", {scale:1});	
	});

});
