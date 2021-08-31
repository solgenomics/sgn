


var solGS = solGS || function solGS () {};

solGS.phenoHistogram =  {

    getHistogramData: function () {

	var params = this.getHistogramParams();
	var histoData = jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: params,
            url: '/histogram/phenotype/data/',
        });

       return histoData;
    },

    getHistogramParams: function () {

	var traitId      = jQuery("#trait_id").val();
	var population   = solGS.getPopulationDetails();
	var populationId = population.training_pop_id;
	var comboPopsId  = population.combo_pops_id;

	var params = {
	    'trait_id'     : traitId,
	    'training_pop_id': populationId,
	    'combo_pops_id'  : comboPopsId
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

   var histMsgId = "#pheno_histogram_canvas #histogram_message";
   solGS.phenoHistogram.getHistogramData().done(function(res) {

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
                    'canvas' : '#pheno_histo_canvas',
                    'plot_id': '#pheno_histo_plot'
                };

                solGS.histogram.plotHistogram(args);
                jQuery(histMsgId).empty();

            }
       } else {
            var msg = "<p>This trait has no phenotype data to plot.</p>";
            solGS.showMessage(histMsgId, msg);
       }

    });

    solGS.phenoHistogram.getHistogramData().fail(function(res) {
        var msg = "<p>Error occured plotting histogram for this trait dataset.</p>";
        solGS.showMessage(histMsgId, msg);
    });

});
