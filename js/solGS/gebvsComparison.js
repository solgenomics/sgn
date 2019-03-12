/** 
* visualize and compare gebvs of a training population 
* and a selection population (genetic gain).
* normal distribution plotting using d3.
* uses methods from solGS.normalDistribution and solGS.linePlot js libraries

* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};

jQuery(document).ready(function () {
    jQuery('#check_genetic_gain').on('click', function () {
	solGS.geneticGain.gebvsComparison();
    }); 
});


solGS.geneticGain = {
    
    gebvsComparison: function () {
     
	var gebvParams = this.getGeneticGainArgs();
	
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
	    jQuery('#genetic_gain_message')
		.html('Can not compare GEBVs. I am missing ' + missing + '.')
		.show();
	}
	else {
	    console.log('tr pop id: ' + gebvParams.training_pop_id)
	    console.log('sel pop id: ' + gebvParams.selection_pop_id)
	    console.log('trait id: ' + gebvParams.trait_id)
	    this.plotGeneticGainBoxplot(gebvParams);
	    //getTrainingPopulationGEBVs(gebvParams);
	}
    },


    getGeneticGainArgs: function () {
	
	var trainingPopId  = jQuery('#genetic_gain_canvas #training_pop_id').val();
	var selectionPopId = jQuery('#genetic_gain_canvas #selection_pop_id').val();
	var traitId        = jQuery('#genetic_gain_canvas #trait_id').val();

	var geneticGainArgs = { 
	    'training_pop_id'  : trainingPopId,
	    'selection_pop_id' : selectionPopId,
	    'trait_id'         : [traitId]
	}

	return geneticGainArgs;

    },

    plotGeneticGainBoxplot: function(geneticGainArgs) {

	jQuery("#genetic_gain_canvas .multi-spinner-container").show();
	jQuery("#check_genetic_gain").hide();
	jQuery('#genetic_gain_message')
	    .html('Please wait... plotting genetic gain')
	    .show();
	
	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    data: geneticGainArgs,
	    url : '/solgs/genetic/gain/boxplot',
	    success: function (res) {		
		if (res.Error) {
		    jQuery("#genetic_gain_canvas .multi-spinner-container").hide();
		    jQuery("#genetic_gain_message").empty();
		    solGS.showMessage("genetic_gain_message", response.Error);
		    jQuery("#check_genetic_gain").show();
		    
		} else {
		    var boxplot = res.boxplot;
		    var boxplotData = res.boxplot_data
		    var plot = '<img  src= "' + boxplot + '">';
		    
		    console.log('boxplot file ' + boxplot)
		   	if (boxplot) {
			   			    
			    var fileNameBoxplot = boxplot.split('/').pop();					    
			    boxplotFile = "<a href=\"" + boxplot +  "\" download=" + fileNameBoxplot + ">boxplot</a>";
	
			    var fileNameData = boxplotData.split('/').pop();					    
			    var dataFile = "<a href=\"" + boxplotData +  "\" download=" + fileNameData + ">Data</a>";			    
			    jQuery("#genetic_gain_plot")
				.prepend('<div style="margin-top: 20px">' + plot + '</div>'
					 + '<br /> <strong>Download:</strong> '
					 + boxplotFile + ' | '
				         + dataFile)
				.show();

			    jQuery("#genetic_gain_canvas .multi-spinner-container").hide();
			    jQuery("#genetic_gain_message").empty();
			    
			}  else {
			    jQuery("#genetic_gain_canvas .multi-spinner-container").hide();
			    showMessage("There is no genetic gain plot for this dataset."); 		
			    jQuery("#check_genetic_gain").show();
			    
			}
		}
		
	    },
	    error: function(res) {
                jQuery("#genetic_gain_canvas .multi-spinner-container").hide();
		solGS.showMessage('genetic_gain_message', "Error occured plotting the genetic gain.");	    	
		jQuery("#check_genetic_gain").show();
		
	    }
	});

    },

	
    getTrainingPopulationGEBVs: function (gebvParams) {
	
	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    data: gebvParams,
	    url : '/solgs/get/gebvs/training/population',
	    success: function (res) {
		if (res.gebv_exists) {
		    jQuery('#genetic_gain_message').empty();
		    trainingGEBVs = res.gebv_arrayref;
		    
		    if (trainingGEBVs) {
			getSelectionPopulationGEBVs(gebvParams)
		    }
		    
		} else {
		    jQuery('#genetic_gain_message')
			.html('There is no GEBV data for the training population.')
			.show();
		}
	    },
	    error: function () {
		jQuery('#genetic_gain_message')
		    .html('Error occured checking for GEBV data for the training population.')
		    .show();
	    }
	});

    },


    getSelectionPopulationGEBVs: function (gebvParams) {
	
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
			jQuery('#genetic_gain_message')
			    .html('Please wait... plotting gebvs')
			    .show();
			
			plotGEBVs(trainingGEBVs, selectionGEBVs);
			
			jQuery('#genetic_gain_message').empty();
			jQuery('#check_genetic_gain').hide();
		    }
		} else {
		    jQuery('#genetic_gain_message')
			.html('There is no GEBV data for the selection population.')
			.show();
		}
	    },
	    error: function () {
		jQuery('#genetic_gain_message')
		    .html('Error occured checking for GEBV data for the selection population.')
		    .show();
	    }
	});  

    },
    

    ggSelectionPopulations: function()  {

	 console.log('gg page: t')
	var modelData  = getTrainingPopulationData();
	
	var trainingPopIdName = JSON.stringify(modelData);
	console.log('gg page: ', trainingPopIdName)
	var  popsList =  '<dl id="gg_selected_population" class="gg_dropdown">'
            + '<dt> <a href="#"><span>Choose a population</span></a></dt>'
            + '<dd>'
            + '<ul>';
            // + '<li>'
            // + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
            // + '</li>';  
	
	popsList += '</ul></dd></dl>'; 
	
	jQuery("#gg_select_a_population_div").empty().append(popsList).show();
	
	var dbSelPopsList;
	if (modelData.id.match(/list/) == null) {
            dbSelPopsList = addSelectionPopulations();
	}

	if (dbSelPopsList) {
            jQuery("#gg_select_a_population_div ul").append(dbSelPopsList); 
	}
	
	var userUploadedSelExists = jQuery("#list_selection_pops_table").doesExist();
	if (userUploadedSelExists == true) {
	    
            var userSelPops = listUploadedSelPopulations();
            if (userSelPops) {
		jQuery("#gg_select_a_population_div ul").append(userSelPops);  
            }
	}

	jQuery(".gg_dropdown dt a").click(function() {
            jQuery(".gg_dropdown dd ul").toggle();
	});
        
	jQuery(".gg_dropdown dd ul li a").click(function() {
	    
            var text = jQuery(this).html();
            
            jQuery(".gg_dropdown dt a span").html(text);
            jQuery(".gg_dropdown dd ul").hide();
            
            var idPopName = jQuery("#gg_selected_population").find("dt a span.value").html();
            idPopName     = JSON.parse(idPopName);
            modelId       = jQuery("#model_id").val();
            
            selectedPopId   = idPopName.id;
            selectedPopName = idPopName.name;
            selectedPopType = idPopName.pop_type; 
	    
            jQuery("#gg_selected_population_name").val(selectedPopName);
            jQuery("#gg_selected_population_id").val(selectedPopId);
            jQuery("#gg_selected_population_type").val(selectedPopType);
            
	});
        
	jQuery(".gg_dropdown").bind('click', function(e) {
            var clicked = jQuery(e.target);
            
            if (! clicked.parents().hasClass("gg_dropdown"))
		jQuery(".gg_dropdown dd ul").hide();

            e.preventDefault();

	});           
    },


///// genetic gain menu ///



    

    plotGEBVs: function (trainingGEBVs, selectionGEBVs) {
	
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
    },

//////////
}
/////////   

jQuery(document).ready( function() { 
    var page = document.URL;
    console.log('gg page: ', page)
    if (page.match(/solgs\/traits\/all\/|solgs\/models\/combined\/trials\//) != null) {
	
	setTimeout(function() {solGS.geneticGain.ggSelectionPopulations()}, 5000);
    }
							 	 
}); 
