/** 
* visualize and compare gebvs of a training population 
* and a selection population (genetic gain).
* normal distribution plotting using d3.
* uses methods from solGS.normalDistribution and solGS.linePlot js libraries

* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};

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
	    jQuery('#gg_message')
		.html('Can not compare GEBVs. I am missing ' + missing + '.')
		.show();
	}
	else {

	    this.plotGeneticGainBoxplot(gebvParams);
	    //getTrainingPopulationGEBVs(gebvParams);
	}
    },


    getGeneticGainArgs: function () {

	var trainingPopId   = jQuery('#gg_canvas #training_pop_id').val();
	var trainingPopName = jQuery('#gg_canvas #training_pop_name').val();
	var selectionPopId  = jQuery('#gg_canvas #selection_pop_id').val();
	var selectionTraits = jQuery('#gg_canvas').find('#selection_traits_ids').val();
	var traitId         = jQuery('#trait_id').val();

	selectionTraits = selectionTraits.split(',');
	
	var ggArgs = { 
	    'training_pop_id'  : trainingPopId,
	    'training_pop_name' : trainingPopName,
	    'selection_pop_id' : selectionPopId,
	    'selection_traits' : selectionTraits,
	    'trait_id'         : traitId
	}

	return ggArgs;

    },

    plotGeneticGainBoxplot: function(ggArgs) {

	jQuery("#gg_canvas .multi-spinner-container").show();
	jQuery("#check_genetic_gain").hide();
	jQuery('#gg_message')
	    .html('Please wait... plotting genetic gain')
	    .show();
	
	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    data: ggArgs,
	    url : '/solgs/genetic/gain/boxplot',
	    success: function (res) {		
		if (res.Error) {
		    jQuery("#gg_canvas .multi-spinner-container").hide();
		    jQuery("#gg_message").empty();
		    
		    solGS.showMessage("gg_message", response.Error);
		   
		    if (document.URL.match(/\/solgs\/traits\/all\/population\//)) {
                        jQuery("#check_genetic_gain").show();
                    }
		    
		} else {
		    var boxplot = res.boxplot;
		    var boxplotData = res.boxplot_data
		    var plot = '<img  src= "' + boxplot + '">';
		    
		    if (boxplot) {
			   			    
			var fileNameBoxplot = boxplot.split('/').pop();					    
			boxplotFile = "<a href=\"" + boxplot +  "\" download=" + fileNameBoxplot + ">boxplot</a>";
			
			var fileNameData = boxplotData.split('/').pop();					    
			var dataFile = "<a href=\"" + boxplotData +  "\" download=" + fileNameData + ">Data</a>";			    
			jQuery("#gg_plot")
			    .prepend('<div style="margin-top: 20px">' + plot + '</div>'
				     + '<br /> <strong>Download:</strong> '
				     + boxplotFile + ' | '
				     + dataFile)
			    .show();

			jQuery("#gg_canvas .multi-spinner-container").hide();
			jQuery("#gg_message").empty();
			    
		    }  else {
			jQuery("#gg_canvas .multi-spinner-container").hide();
			showMessage("There is no genetic gain plot for this dataset."); 		
			jQuery("#check_genetic_gain").show();
			
		    }
		}
		
	    },
	    error: function(res) {
                jQuery("#gg_canvas .multi-spinner-container").hide();
		solGS.showMessage('gg_message', "Error occured plotting the genetic gain.");	    	
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
		    jQuery('#gg_message').empty();
		    trainingGEBVs = res.gebv_arrayref;
		    
		    if (trainingGEBVs) {
			getSelectionPopulationGEBVs(gebvParams)
		    }
		    
		} else {
		    jQuery('#gg_message')
			.html('There is no GEBV data for the training population.')
			.show();
		}
	    },
	    error: function () {
		jQuery('#gg_message')
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
		    jQuery('#gg_message').empty();
		    
		    selectionGEBVs = res.gebv_arrayref;
		    
		    if (selectionGEBVs && trainingGEBVs) {
			jQuery('#gg_message')
			    .html('Please wait... plotting gebvs')
			    .show();
			
			plotGEBVs(trainingGEBVs, selectionGEBVs);
			
			jQuery('#gg_message').empty();
			jQuery('#check_genetic_gain').hide();
		    }
		} else {
		    jQuery('#gg_message')
			.html('There is no GEBV data for the selection population.')
			.show();
		}
	    },
	    error: function () {
		jQuery('#gg_message')
		    .html('Error occured checking for GEBV data for the selection population.')
		    .show();
	    }
	});  

    },
    

    ggSelectionPopulations: function()  {
	
	var ggArgs  = this.getGeneticGainArgs();
	
	var  popsList =  '<dl id="gg_selected_population" class="gg_dropdown">'
            + '<dt><a href="#"><span>Choose a population</span></a></dt>'
            + '<dd><ul>'
	    + '</ul></dd>'
	    + '</dl>'; 
	
	jQuery("#gg_select_a_population_div").empty().append(popsList).show();
	
	var dbSelPopsList;
	if (ggArgs.training_pop_id.match(/list/) == null) {
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
                       
            var selectedPopId   = idPopName.id;
            var selectedPopName = idPopName.name;
            var selectedPopType = idPopName.pop_type;
	    
            jQuery("#gg_selected_population_name").val(selectedPopName);
            jQuery("#gg_selected_population_id").val(selectedPopId);
	    jQuery("#gg_canvas #selection_pop_id").val(selectedPopId);
            jQuery("#gg_selected_population_type").val(selectedPopType);
	   
	});
	
	jQuery(".gg_dropdown").bind('click', function(e) {
            var clicked = jQuery(e.target);
            
            if (! clicked.parents().hasClass("gg_dropdown"))
		jQuery(".gg_dropdown dd ul").hide();

            e.preventDefault();

	});

    },


    getSelPopPredictedTraits: function(ggArgs) {
		    
	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    data: ggArgs,
	    url : '/solgs/selection/population/predicted/traits',
	    success: function (res) {
		if (res.selection_traits) {
		    
		    var selectionTraits = res.selection_traits.join(',');		    
		    jQuery('#gg_canvas #selection_traits_ids').val(selectionTraits);

		    var ggArgs = solGS.geneticGain.getGeneticGainArgs();
		    solGS.geneticGain.plotGeneticGainBoxplot(ggArgs);
		    
		} else {
		   jQuery('#gg_message')
		    .html('This selection population has no predicted traits.')
		    .show(); 
		}
	    },
	    error: function () {
		jQuery('#gg_message')
		    .html('Error occured checking for predicted traits for the selection population ' + selectionPopId)
		    .show();
	    }
	});
	
    },

    
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

jQuery(document).ready(function () {
    jQuery('#check_genetic_gain').on('click', function () {
	var page = document.URL;
	if (page.match(/solgs\/selection\//)) {
	    solGS.geneticGain.gebvsComparison();
	} else {

	    console.log('clicked check_genetic_gain')
	    var selectedPopId   = jQuery("#gg_selected_population_id").val();
	    var selectedPopType = jQuery("#gg_selected_population_type").val();
	    var selectedPopName = jQuery("#gg_selected_population_name").val();
	    
	    
	    jQuery("#gg_message")
		.css({"padding-left": '0px'})
		.html("checking predicted traits for selection population " + selectedPopName);

	    var ggArgs  = solGS.geneticGain.getGeneticGainArgs();
	    solGS.geneticGain.getSelPopPredictedTraits(ggArgs);
	   	    
	}
    }); 
});


jQuery(document).ready( function() { 
    var page = document.URL;
  
    if (page.match(/solgs\/traits\/all\/|solgs\/models\/combined\/trials\//) != null) {	
	setTimeout(function() {solGS.geneticGain.ggSelectionPopulations()}, 5000);
    }
							 	 
});

