/** 
* visualize and compare gebvs of a training population 
* and a selection population.
* normal distribution plotting using d3.
* uses methods from statistics/simple_statistics js library
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

	var extremesX = [
	    d3.min(xValuesT), 
	    d3.min(xValuesT), 
	    d3.max(xValuesS), 
	    d3.max(xValuesS)
	];

	var height = 300;
	var width  = 800;
	var pad    = {'left':60, 'top':40, 'right':20, 'bottom': 40}; 
	var totalH = height + pad.top + pad.bottom;
	var totalW = width + pad.left + pad.right;		

	var svgId  = '#compare_gebvs_canvas';
	var plotId = '#compare_gebvs_plot';

	var trColor   = '#86B404';
	var slColor   = '#F7D358';
	var axisColor = '#5882FA';   
	var yLabel    = 'Probability';
	var xLabel    = 'GEBVs';

	var title = 'Normal distribution curves of GEBVs ' 
	    + 'for the training and selection populations.';
	
	var legendValues = [
	    [trColor, 'Training population'], 
	    [slColor, 'Selection population']
	];

	var trainingMidlineData  = [
	    [ss.mean(xValuesT), d3.min(yValuesT)], 
	    [ss.mean(xValuesT), d3.max(yValuesT)]
	];
	
	var selectionMidlineData = [
	    [ss.mean(xValuesS), d3.min(yValuesS)], 
	    [ss.mean(xValuesS), d3.max(yValuesS)]
	];

	var xScale = d3.scale.linear()
	    .domain([d3.min(extremesX), d3.max(extremesX)])
	    .range([0, width]);

	var yScale = d3.scale.linear()
	    .domain([0, d3.max([d3.max(yValuesT), d3.max(yValuesS)])])
	    .range([height, 0]);
	
	var line = d3.svg.line()
	    .x(function(d) { 
		return xScale(d[0]); 
	    })
	    .y(function(d) { 			
		return yScale(d[1]); 
	    });

	var svg = d3.select(svgId)
	    .append("svg")
	    .attr("width", totalW)
	    .attr("height", totalH);

	var graph = svg.append("g")
	    .attr("id", plotId)
            .attr("transform", "translate(" + pad.left + "," + pad.top  + ")");

	var xAxis = d3.svg.axis()
            .scale(xScale)
            .orient("bottom")
	    .ticks(15);

	var yAxis = d3.svg.axis()
            .scale(yScale)
	    .ticks(5)
            .orient("left");
	
	graph.append("g")
	    .attr("class", "x axis")
	    .attr("transform", "translate(0,"  +  height + ")")
	    .call(xAxis)
	    .attr("fill", axisColor)
            .style({"text-anchor":"start", "fill": axisColor});

	graph.append("g")
	    .attr("class", "y axis")
	    .attr("transform", "translate(0,0)")
	    .call(yAxis)
	    .attr("fill", axisColor);
	
	var path = graph.append("path")
	    .attr("d", line(xYT))
	    .attr("stroke", trColor)
	    .attr("stroke-width", "3")
	    .attr("fill", "none");
	
	var totalLength = path.node().getTotalLength();

	path.attr("stroke-dasharray", totalLength + " " + totalLength)
    	    .attr("stroke-dashoffset", totalLength)
    	    .transition()
            .duration(2000)
            .ease("linear")
            .attr("stroke-dashoffset", 0);

	path = graph.append("path")
	    .attr("d", line(xYS))
	    .attr("stroke", slColor)
	    .attr("stroke-width", "3")
	    .attr("fill", "none");
	
	totalLength = path.node().getTotalLength();

	path.attr("stroke-dasharray", totalLength + " " + totalLength)
    	    .attr("stroke-dashoffset",  totalLength)
    	    .transition()
            .duration(2000)
            .ease("linear")
            .attr("stroke-dashoffset", 0);

	graph.append("path")
	    .attr("d", line(trainingMidlineData))
	    .attr("stroke", trColor)
	    .attr("stroke-width", "3")
	    .attr("fill", "none");

	graph.append("path")
	    .attr("d", line(selectionMidlineData))
	    .attr("stroke", slColor)
	    .attr("stroke-width", "3")
	    .attr("fill", "none");

	graph.append("text")
            .attr("id", "title")
            .attr("fill", axisColor)              
            .text(title)
            .attr("x", pad.left)
            .attr("y", -20);
	
	graph.append("text")
            .attr("id", "xLabel")
            .attr("fill", axisColor)              
            .text(xLabel)
            .attr("x", width * 0.5)
            .attr("y", height + 40);

	graph.append("text")
            .attr("id", "yLabel")
            .attr("fill", axisColor)              
            .text(yLabel)     
	    .attr("transform", "translate(" + -40 + "," +  height * 0.5 + ")" + " rotate(-90)");

	var legendTxt = graph.append("g")
    	    .attr("transform", "translate(" + (width - 150) + "," + (height * 0.25)  + ")")
            .attr("id", "normalLegend");

	legendTxt.selectAll("text")
            .data(legendValues)  
            .enter()
            .append("text")              
            .attr("fill", function (d) { 
		return d[0]; 
	    })
	    .attr("font-weight", "bold")
            .attr("x", 1)
            .attr("y", function (d, i) { 
		return i * 20; 
	    })
            .text(function (d) { 
		return d[1];
	    }); 
  	
    }

//////////
}
/////////   

 
