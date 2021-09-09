


var solGS = solGS || function solGS () {};

solGS.phenoHistogram =  {

    getTraitPhenoMeansData: function () {

	var params = this.getHistogramParams();
	var histoData = jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: params,
            url: '/trait/pheno/means/data/',
        });

       return histoData;
    },

    getTraitPhenoRawData: function () {

	var params = this.getHistogramParams();
	var histoData = jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: params,
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

   var histMsgId = "#pheno_means_histogram_canvas #histogram_message";
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
                var args = {
                    'namedValues' : traitData,
                    'canvas' : '#pheno_means_histo_canvas',
                    'plot_id': '#pheno_means_histo_plot'
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
                 var args = {
                     'namedValues' : traitRawData,
                     'canvas' : '#pheno_raw_histo_canvas',
                     'plot_id': '#pheno_raw_histo_plot'
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
});
