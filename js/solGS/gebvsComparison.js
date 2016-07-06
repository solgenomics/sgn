/** 
* visualize and compare gebvs of a training population 
* and a selection population.
* normal distribution plotting using d3.
* uses methods from statistics/simple_statistics and solGS.linePlot js libraries
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


jQuery(document).ready(function () {
    jQuery('#compare_gebvs').on('click', function () {
	gebvsComparison();
    }); 
});


function gebvsComparison () {
     
    var gebvParams = getGebvsParams();
   
    var trainingGEBVs  = '';
    var selectionGEBVs = ''; 
    
    var missing;
    if (!gebvParams.training_pop_id) {
	missing = 'training population id';
    }

    if (!gebvParams.selection_pop_id) {
	missing += ', selection population id';
    }

    if (!gebvParams.trait_id) {
	missing += ', trait id';
    }

    if (missing) {	
	jQuery('#compare_gebvs_message')
	    .html('Can not compare GEBVs. I am missing ' + missing + '.')
	    .show();
    }
    else {  
	getTrainingPopulationGEBVs(gebvParams);
    }


    function getGebvsParams () {
	
	var trainingPopId  = jQuery('#training_pop_id').val();
	var selectionPopId = jQuery('#selection_pop_id').val();
	var traitId        = jQuery('#trait_id').val();
	
	var gebvParams = { 
	    'training_pop_id'  : trainingPopId,
	    'selection_pop_id' : selectionPopId,
	    'trait_id'         : traitId
	}

	return gebvParams;

    }

    function getTrainingPopulationGEBVs (gebvParams) {
    
	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    data: gebvParams,
	    url : '/solgs/get/gebvs/training/population',
	    success: function (res) {
		if (res.gebv_exists) {
		    jQuery('#compare_gebvs_message').empty();
		    trainingGEBVs = res.gebv_arrayref;
		    
		    if (trainingGEBVs) {
			getSelectionPopulationGEBVs(gebvParams)
		    }
		    
		} else {
		    jQuery('#compare_gebvs_message')
			.html('There is no GEBV data for the training population.')
			.show();
		}
	    },
	    error: function () {
		jQuery('#compare_gebvs_message')
		    .html('Error occured checking for GEBV data for the training population.')
		    .show();
	    }
	});

    }


    function getSelectionPopulationGEBVs (gebvParams) {
	
	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    data: gebvParams,
	    url : '/solgs/get/gebvs/selection/population',
	    success: function (res) {
		if (res.gebv_exists) {
		    jQuery('#compare_gebvs_message').empty();
		    
		    selectionGEBVs = res.gebv_arrayref;
		    
		    if (selectionGEBVs && trainingGEBVs) {
			jQuery('#compare_gebvs_message')
			    .html('Please wait... plotting gebvs')
			    .show();
		    
			plotGEBVs(trainingGEBVs, selectionGEBVs);
		    
			jQuery('#compare_gebvs_message').empty();
			jQuery('#compare_gebvs').hide();
		    }
		} else {
		    jQuery('#compare_gebvs_message')
			.html('There is no GEBV data for the selection population.')
			.show();
		}
	    },
	    error: function () {
		jQuery('#compare_gebvs_message')
		    .html('Error occured checking for GEBV data for the selection population.')
		    .show();
	    }
	});  

    }


    function getGebvs (gebvsData) {

	var gebv = [];
	
	for (var i=0; i < gebvsData.length; i++) {      
            var g = gebvsData[i][1];
            g     = g.replace(/\s+/, '');
            g     = Number(g);
	    gebv.push(g);
	}
	
	return gebv;
    } 


    function getPValues (normalData) {

	var p = [];
	
	for (var i=0; i < normalData.length; i++) {
            var pV  = normalData[i].p;
	    p.push(pV);
	}
	
	return p;

    } 


    function getGebvZScores (normalData) {

	var gz = [];
	
	for (var i=0; i < normalData.length; i++) {
            var g = normalData[i].gebv;
	    var z  = normalData[i].z;
	    gz.push([g, z]);

	}
	
	return gz;
    } 


    function getZScoresP (normalData) {

	var zp = [];

	for (var i=0; i < normalData.length; i++) {
            var zV  = normalData[i].z;
	    var pV  = normalData[i].p;
	    zp.push([zV, pV]);

	}
	
	return zp;
    } 


    function getGebvP (normalData) {

	var gp = [];

	for (var i=0; i < normalData.length; i++) {
            var x  = normalData[i].gebv;
	    var y  = normalData[i].p;
	    gp.push([x, y]);

	}
	
	return gp;
    } 


    function getNormalDistData (gebvData) { 
	
	var gebvs = getGebvs(gebvData);
	
	var mean = ss.mean(gebvs);
	var std  = ss.standard_deviation(gebvs);
	
	var normalDistData = [];
	for (var i=0; i < gebvData.length; i++) {
	    
	    var ind  = gebvData[i][0];
	    var gebv = gebvData[i][1];

	    var z = ss.z_score(gebv, mean, std);
	    var p = ss.cumulative_std_normal_probability(z);
	    
	    if (gebv > mean) {
		p = 1 - p;
	    }

	    normalDistData.push({'ind': ind, 'gebv': gebv, 'z': z, 'p': p});
	}
	
	return normalDistData;

    }


    function plotGEBVs (trainingGEBVs, selectionGEBVs) {
	
	var trainingNormalDistData  = getNormalDistData(trainingGEBVs);
	var selectionNormalDistData = getNormalDistData(selectionGEBVs);
	
	var gebvZScoresT = getGebvZScores(trainingNormalDistData);
	var gebvZScoresS = getGebvZScores(selectionNormalDistData);
	
	var yValuesT = getPValues(trainingNormalDistData);
	var yValuesS = getPValues(selectionNormalDistData);

	var zScoresPT = getZScoresP(trainingNormalDistData);
	var zScoresPS = getZScoresP(selectionNormalDistData);

	var xYT = getGebvP(trainingNormalDistData);
	var xYS = getGebvP(selectionNormalDistData);
	
	var xValuesT = getGebvs(trainingGEBVs);
	var xValuesS = getGebvs(selectionGEBVs);

	var svgId  = '#compare_gebvs_canvas';
	var plotId = '#compare_gebvs_plot';

	var trColor   = '#86B404';
	var slColor   = '#F7D358';
	var axisColor = '#5882FA';   
	var yLabel    = 'Probability';
	var xLabel    = 'GEBVs';

	var title = 'Normal distribution curves of GEBVs ' 
	    + 'for the training and selection populations.';
	

	var allData =  {
	    'div_id': svgId, 
	    'plot_title': title, 
	    'x_axis_label': xLabel,
	    'y_axix_label': yLabel,
	    'lines' : 
	    [ 		
		{
		    'data'  : xYT, 
		    'legend': 'Training population' ,
		    'color' : trColor,
		},	
		{
		    'data'  : xYS, 
		    'legend': 'Selection population',
		    'color' : slColor,
		},		    
		
	    ]    
	};


	var linePlot  = solGS.linePlot(allData);

	var trainingMidlineData  = [
	    [ss.mean(xValuesT), d3.min(yValuesT)], 
	    [ss.mean(xValuesT), d3.max(yValuesT)]
	];
	
	var selectionMidlineData = [
	    [ss.mean(xValuesS), d3.min(yValuesS)], 
	    [ss.mean(xValuesS), d3.max(yValuesS)]
	];

	var midLine = d3.svg.line()
	    .x(function(d) { 
		return linePlot.xScale(d[0]); 
	    })
	    .y(function(d) { 			
		return linePlot.yScale(d[1]); 
	    });

	
	linePlot.graph.append("path")
	    .attr("d", midLine(trainingMidlineData))
	    .attr("stroke", trColor)
	    .attr("stroke-width", "3")
	    .attr("fill", "none");

	linePlot.graph.append("path")
	    .attr("d", midLine(selectionMidlineData))
	    .attr("stroke", slColor)
	    .attr("stroke-width", "3")
	    .attr("fill", "none");


    }

//////////
}
/////////   

 
