/**
* for graphical presentation of GEBVs of a trait.
*
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};


solGS.gebvs = {


    getGebvsParams: function () {

	var popId          = jQuery('#model_id').val();
	var traitId        = jQuery('#trait_id').val();
	var comboPopsId    = jQuery('#combo_pops_id').val();
	var popsList       = jQuery('#pops_list').val();
	var selectionPopId = jQuery('#selection_pop_id').val();
	var protocolId     = jQuery('#genotyping_protocol_id').val();

	var params = {
	    'training_pop_id': popId,
	    'combo_pops_id': comboPopsId,
	    'selection_pop_id': selectionPopId,
	    'genotyping_protocol_id': protocolId,
	    'trait_id': traitId
	};

	return params;

    },


    getGebvsData: function () {

    	var action = '/solgs/trait/gebvs/data';
    	var params = this.getGebvsParams();

    	var gebvsData = jQuery.ajax({
                async: false,
                url: action,
                dataType:"json",
                data: params,
    	});

        return gebvsData;
    },


    plotGebvs: function (gebvsData) {

    	var histoArgs = {
    	    'canvas': '#gebvs_histo_canvas',
    	    'plot_id': '#gebvs_histo_plot',
    	    'x_label': 'GEBVs',
    	    'y_label': 'Counts',
            'namedValues' : gebvsData
    	};

	   solGS.histogram.plotHistogram(histoArgs);

    },

/////
}
/////


jQuery(document).ready( function() {

    solGS.gebvs.getGebvsData().done(function (res) {
            solGS.gebvs.plotGebvs(res.gebvs_data);
    });

});
