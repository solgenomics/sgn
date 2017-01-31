/** 
* visualize and compare gebvs of a training population 
* and a selection population.
* normal distribution plotting using d3.
* uses methods from solGS.normalDistribution and solGS.linePlot js libraries
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


    function plotGEBVs (trainingGEBVs, selectionGEBVs) {
	
	var normalDistTraining = new solGS.normalDistribution();
	
	var trainingNormalDistData  = normalDistTraining
	    .getNormalDistData(trainingGEBVs);
	
	var gebvZScoresT = normalDistTraining
	    .getYValuesZScores(trainingNormalDistData);

	var yValuesT = normalDistTraining
	    .getPValues(trainingNormalDistData);

	var zScoresPT = normalDistTraining
	    .getZScoresP(trainingNormalDistData);

	var xYT =  normalDistTraining
	    .getYValuesP(trainingNormalDistData);

	var xValuesT =  normalDistTraining
	    .getYValues(trainingGEBVs);

	var trMean = ss.mean(xValuesT);

	var stdT = trMean <= 0 ? -1.0 : 1.0;

	var xMT = normalDistTraining.getObsValueZScore(gebvZScoresT, stdT);

	var normalDistSelection = new solGS.normalDistribution();

	var selectionNormalDistData = normalDistSelection
	    .getNormalDistData(selectionGEBVs);

	var gebvZScoresS = normalDistSelection 
	    .getYValuesZScores(selectionNormalDistData);
		
	var yValuesS = normalDistSelection
	    .getPValues(selectionNormalDistData);
	
	var zScoresPS = normalDistSelection
	    .getZScoresP(selectionNormalDistData);
	
	var xYS = normalDistSelection
	    .getYValuesP(selectionNormalDistData);
	
	var xValuesS = normalDistSelection
	    .getYValues(selectionGEBVs);
	
	var slMean = ss.mean(xValuesS);

	var stdS = slMean <= 0 ? -1.0 : 1.0;

	var xMS = normalDistTraining.getObsValueZScore(gebvZScoresS, stdS);

	var svgId  = '#compare_gebvs_canvas';
	var plotId = '#compare_gebvs_plot';

	var trColor      = '#02bcff'; 
	var slColor      = '#ff1302'; 
	var axLabelColor = '#ff8d02';    
	var yLabel       = 'Probability';
	var xLabel       = 'GEBVs';

	var title = 'Normal distribution curves of GEBVs ' 
	    + 'for the training and selection populations.';
	
	var allData =  {
	    'div_id': svgId, 
	    'plot_title': title, 
	    'x_axis_label': xLabel,
	    'y_axis_label': yLabel,
	    'axis_label_color': axLabelColor,
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
	    [trMean, 0], 
	    [trMean, d3.max(yValuesT)]
	];
	
	var selectionMidlineData = [
	    [slMean, 0], 
	    [slMean, d3.max(yValuesS)]
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
	    .attr("fill", "none")
	    .on("mouseover", function (d) {
                if (d = trMean) {
                    linePlot.graph.append("text")
                        .attr("id", "tr_mean")
                        .text(d3.format(".2f")(trMean))
                        .style({
			    "fill"       : trColor, 
			    "font-weight": "bold"
			}) 
			.attr("x", linePlot.xScale(xMT[0]))
                        .attr("y", linePlot.yScale(d3.max(yValuesT) * 0.5))                     
                }
            })                
            .on("mouseout", function() {
                d3.selectAll("text#tr_mean").remove();
            });

	linePlot.graph.append("path")
	    .attr("d", midLine(selectionMidlineData))
	    .attr("stroke", slColor)
	    .attr("stroke-width", "3")
	    .attr("fill", "none")
	    .on("mouseover", function (d) {
                if (d = slMean) {
                    linePlot.graph.append("text")
                        .attr("id", "sl_mean")
                        .text(d3.format(".2f")(slMean))
                        .style({
			    "fill"       : slColor, 
			    "font-weight": "bold"
			})  
                        .attr("x", linePlot.xScale(xMS[0]))
                        .attr("y", linePlot.yScale(d3.max(yValuesS) * 0.5))
                             
                }
            })                
            .on("mouseout", function() {
		d3.selectAll("text#sl_mean").remove(); 
            });
    }

//////////
}
/////////   

 
