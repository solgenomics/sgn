/** 
* for graphical presentation of GEBVs of a trait.
* With capability for zooming in for selected area. 
* Double clicking zooms in by 50%.
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


    getGebvs: function () {

	var action = '/solgs/trait/gebv/graph';
	var params = this.getGebvsParams();

	var gebvsData;
	
	jQuery.ajax({
            async: false,
            url: action,
            dataType:"json",
            data: params,
            success: function(data) {
                var gebvsData  = data.gebv_data;
                solGS.gebvs.plotGebvs(gebvsData);
	    },
	});
    },
 

    plotGebvs: function (gebvsData) {
	
	var graphArray      = [];
	graphArray[0]       = [];  
	var xAxisTickValues = [];
	var yAxisTickValues = [];
	var yValues         = [];

	for (var i=0; i < gebvsData.length; i++) {
            var xD = gebvsData[i][0];
            xD     = xD.toString();
            var yD = gebvsData[i][1];
            yD     = yD.replace(/\s/, '');
            yD     = Number(yD);
            
            xAxisTickValues.push([i, xD]);                               
            yAxisTickValues.push([i, yD]);
            yValues.push(yD);
            
            graphArray[0][i]    = [];
            graphArray[0][i][0] = xD;
            graphArray[0][i][1] = yD; 
                                 
        }

	var histoArgs = {
	    'canvas': 'gebvs_histo_canvas',
	    'plot_id': 'gebvs_histo_plot',
	    'values': yValues,
	    'x_label': 'GEBVs',
	    'y_label': 'Counts',
	    'xyData' :gebvsData
	};
	
	console.log(yValues);

	solGS.histogram.plotHistogram(histoArgs);

	
    },
   
    
/////
}
/////


jQuery(document).ready( function() {
       solGS.gebvs.getGebvs();
    });


   
