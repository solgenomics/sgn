/** 
* correlation coefficients plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


jQuery(document).ready( function() { 
    var page = document.URL;
   
    if (page.match(/solgs\/traits\/all\//) != null || 
        page.match(/solgs\/models\/combined\/trials\//) != null) {
	
	setTimeout(function() {listGenCorPopulations()}, 5000);
        
    } else {

	var url = window.location.pathname;

	if (url.match(/[solgs\/population|breeders_toolbox\/trial|breeders\/trial]/)) {
	    checkPhenoCorreResult();  
	} 
    }
          
});


function checkPhenoCorreResult () {
    
    var popDetails = getPopulationDetails();
    var popId      = popDetails.population_id;
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/phenotype/correlation/check/result/' + popId,
        success: function(response) {
            if (response.result) {
		phenotypicCorrelation();					
            } else { 
		jQuery("#run_pheno_correlation").show();	
            }
	}
    });
    
}


jQuery(document).ready( function() { 

    jQuery("#run_pheno_correlation").click(function() {
        phenotypicCorrelation();
	jQuery("#run_pheno_correlation").hide();
    }); 
  
});




jQuery("#run_genetic_correlation").live("click", function() {        
    var popId   = jQuery("#corre_selected_population_id").val();
    var popType = jQuery("#corre_selected_population_type").val();
    
    jQuery("#correlation_canvas").empty();
   
    jQuery("#correlation_message")
        .css({"padding-left": '0px'})
        .html("Running genetic correlation analysis...");
    
    formatGenCorInputData(popId, popType);
         
});


function listGenCorPopulations ()  {
    var modelData = getTrainingPopulationData();
   
    var trainingPopIdName = JSON.stringify(modelData);
   
    var  popsList =  '<dl id="corre_selected_population" class="corre_dropdown">'
        + '<dt> <a href="#"><span>Choose a population</span></a></dt>'
        + '<dd>'
        + '<ul>'
        + '<li>'
        + '<a href="#">' + modelData.name + '<span class=value>' + trainingPopIdName + '</span></a>'
        + '</li>';  
 
    popsList += '</ul></dd></dl>'; 
   
    jQuery("#corre_select_a_population_div").empty().append(popsList).show();
     
    var dbSelPopsList;
    if (modelData.id.match(/uploaded/) == null) {
        dbSelPopsList = addSelectionPopulations();
    }

    if (dbSelPopsList) {
            jQuery("#corre_select_a_population_div ul").append(dbSelPopsList); 
    }
      
    var userUploadedSelExists = jQuery("#uploaded_selection_pops_table").doesExist();
    if (userUploadedSelExists == true) {
      
        var userSelPops = listUploadedSelPopulations();
        if (userSelPops) {

            jQuery("#corre_select_a_population_div ul").append(userSelPops);  
        }
    }

    jQuery(".corre_dropdown dt a").click(function() {
        jQuery(".corre_dropdown dd ul").toggle();
    });
                 
    jQuery(".corre_dropdown dd ul li a").click(function() {
      
        var text = jQuery(this).html();
           
        jQuery(".corre_dropdown dt a span").html(text);
        jQuery(".corre_dropdown dd ul").hide();
                
        var idPopName = jQuery("#corre_selected_population").find("dt a span.value").html();
        idPopName     = JSON.parse(idPopName);
        modelId       = jQuery("#model_id").val();
                   
        selectedPopId   = idPopName.id;
        selectedPopName = idPopName.name;
        selectedPopType = idPopName.pop_type; 
       
        jQuery("#corre_selected_population_name").val(selectedPopName);
        jQuery("#corre_selected_population_id").val(selectedPopId);
        jQuery("#corre_selected_population_type").val(selectedPopType);
                                
    });
                       
    jQuery(".corre_dropdown").bind('click', function(e) {
        var clicked = jQuery(e.target);
               
        if (! clicked.parents().hasClass("corre_dropdown"))
            jQuery(".corre_dropdown dd ul").hide();

        e.preventDefault();

    });           
}


function formatGenCorInputData (popId, type, indexFile) {
    var modelDetail = getPopulationDetails();
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'model_id': modelDetail.population_id, 'corr_population_id': popId, 'type' : type, 'index_file': indexFile},
        url: '/correlation/genetic/data/',
        success: function(response) {
           
            if(response.status == 'success') {
                gebvsFile = response.gebvs_file;
                   
                var divPlace;
                if(indexFile) {
                    divPlace = '#si_correlation_canvas';
                }

                var args = {
                    'model_id': modelDetail.population_id, 
                    'corr_population_id': popId, 
                    'type': type, 
                    'gebvs_file': gebvsFile,
                    'div_place' : divPlace,
                };
              
                runGenCorrelationAnalysis(args);

            } else {
                jQuery("#correlation_message")
                    .css({"padding-left": '0px'})
                    .html("This population has no valid traits to correlate.");
		
            }
        },
        error: function(response) {
            jQuery("#correlation_message")
                .css({"padding-left": '0px'})
                .html("Error occured preparing the additive genetic data for correlation analysis.");
	         
            jQuery.unblockUI();
        }         
    });
}


function getPopulationDetails () {

    var populationId = jQuery("#population_id").val();
    var populationName = jQuery("#population_name").val();
   
    if (populationId == 'undefined') {       
        populationId = jQuery("#model_id").val();
        populationName = jQuery("#model_name").val();
    }

    return {'population_id' : populationId, 
            'population_name' : populationName
           };        
}


function phenotypicCorrelation () {
 
    var population = getPopulationDetails();
    
    jQuery("#correlation_message").html("Running correlation... please wait...");
         
    jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: {'population_id': population.population_id },
            url: '/correlation/phenotype/data/',
            success: function(response) {
	
                if (response.result) {
                    runPhenoCorrelationAnalysis();
                } else {
                    jQuery("#correlation_message")
                        .css({"padding-left": '0px'})
                        .html("This population has no phenotype data.");

		    jQuery("#run_pheno_correlation").show();
                }
            },
            error: function(response) {
                jQuery("#correlation_message")
                    .css({"padding-left": '0px'})
                    .html("Error occured preparing the phenotype data for correlation analysis.");

		jQuery("#run_pheno_correlation").show();
            }
    });     
}


function runPhenoCorrelationAnalysis () {
    var population = getPopulationDetails();
    var popId     = population.population_id;
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': popId },
        url: '/phenotypic/correlation/analysis/output',
        success: function(response) {
            if (response.status== 'success') {
                plotCorrelation(response.data);
		
		var corrDownload = "<a href=\"/download/phenotypic/correlation/population/" 
		                    + popId + "\">Download correlation coefficients</a>";

		jQuery("#correlation_canvas").append("<br />[ " + corrDownload + " ]").show();
                jQuery("#correlation_message").empty();
		jQuery("#run_pheno_correlation").hide();
            } else {
                jQuery("#correlation_message")
                    .css({"padding-left": '0px'})
                    .html("There is no correlation output for this dataset."); 
		
		jQuery("#run_pheno_correlation").show();
            }
        },
        error: function(response) {                          
            jQuery("#correlation_message")
                .css({"padding-left": '0px'})
                .html("Error occured running the correlation analysis.");
	    	
	    jQuery("#run_pheno_correlation").show();
        }                
    });
}


function runGenCorrelationAnalysis (args) {
   
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: args,
        url: '/genetic/correlation/analysis/output',
        success: function(response) {
            if (response.status == 'success') {
                
                divPlace = args.div_place;
               
                if (divPlace === '#si_correlation_canvas') {
                    jQuery("#si_correlation_section").show();                 
                }
                
                plotCorrelation(response.data, divPlace);
                jQuery("#correlation_message").empty();
                jQuery("#si_correlation_message").empty();
                
                if (divPlace === '#si_correlation_canvas') {
  
                    var popName   = jQuery("#selected_population_name").val();                   
                    var corLegDiv = "<div id=\"si_correlation_" 
                        + popName.replace(/\s/g, "") 
                        + "\"></div>";  
                
                    var legendValues = legendParams();                 
                    var corLegDivVal = jQuery(corLegDiv).html(legendValues.legend);
            
                    jQuery("#si_correlation_canvas").append(corLegDivVal).show();
  
                } else {
                    
                    var popName = jQuery("#corre_selected_population_name").val(); 
                    var corLegDiv  = "<div id=\"corre_correlation_" 
                        + popName.replace(/\s/g, "") 
                        + "\"></div>";
                    
                    var corLegDivVal = jQuery(corLegDiv).html(popName);            
                    jQuery("#correlation_canvas").append(corLegDivVal).show(); 
                }                        
               
            } else {
                jQuery("#correlation_message")
                    .css({"padding-left": '0px'})
                    .html("There is no genetic correlation output for this dataset.");               
            }
            
            jQuery.unblockUI();
        },
        error: function(response) {                          
            jQuery("#correlation_message")
                .css({"padding-left": '0px'})
                .html("Error occured running the genetic correlation analysis.");
             
            jQuery.unblockUI();
        }       
    });
}


function plotCorrelation (data, divPlace) {
   
    data = data.replace(/\s/g, '');
    data = data.replace(/\\/g, '');
    data = data.replace(/^\"/, '');
    data = data.replace(/\"$/, '');
    data = data.replace(/\"NA\"/g, 100);
    
    data = JSON.parse(data);
  
    var height = 400;
    var width  = 400;

    var nTraits = data.traits.length;

    if (nTraits < 8) {
        height = height * 0.5;
        width  = width  * 0.5;
    }

    var pad    = {left:70, top:20, right:100, bottom: 70}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    var corXscale = d3.scale.ordinal().domain(d3.range(nTraits)).rangeBands([0, width]);
    var corYscale = d3.scale.ordinal().domain(d3.range(nTraits)).rangeBands([height, 0]);
    var corZscale = d3.scale.linear().domain([-1, 0, 1]).range(["#6A0888","white", "#86B404"]);

    var xAxisScale = d3.scale.ordinal()
        .domain(data.traits)
        .rangeBands([0, width]);

    var yAxisScale = d3.scale.ordinal()
        .domain(data.traits)
        .rangeRoundBands([height, 0]);
  
    if ( divPlace == null) {
        divPlace = '#correlation_canvas'; 
    }

    var svg = d3.select(divPlace)
        .append("svg")
        .attr("height", totalH)
        .attr("width", totalW);

    var xAxis = d3.svg.axis()
        .scale(xAxisScale)
        .orient("bottom");

    var yAxis = d3.svg.axis()
        .scale(yAxisScale)
        .orient("left");
       
    var corrplot = svg.append("g")
        .attr("id", "correlation_plot")
        .attr("transform", "translate(" + pad.left + "," + pad.top + ")");
       
    corrplot.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0," + height +")")
        .call(xAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", 10)
        .attr("dy", ".1em")         
        .attr("transform", "rotate(90)")
        .attr("fill", "#523CB5")
        .style({"text-anchor":"start", "fill": "#523CB5"});
          
    corrplot.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(0,0)")
        .call(yAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("dy", ".1em")  
        .attr("fill", "#523CB5")
        .style("fill", "#523CB5");
            
    var corr = [];
    var coefs = [];   
    for (var i=0; i<data.coefficients.length; i++) {
        for (var j=0;  j<data.coefficients[i].length; j++) {
            corr.push({"row":i, "col":j, "value": data.coefficients[i][j]});
            
            if (data.coefficients[i][j] != 100) {
                coefs.push(data.coefficients[i][j]);
            }
        }
    }
                                 
    var cell = corrplot.selectAll("rect")
        .data(corr)  
        .enter().append("rect")
        .attr("class", "cell")
        .attr("x", function (d) { return corXscale(d.col)})
        .attr("y", function (d) { return corYscale(d.row)})
        .attr("width", corXscale.rangeBand())
        .attr("height", corYscale.rangeBand())      
        .attr("fill", function (d) { 
                if (d.value === 100) {return "white";} 
                else {return corZscale(d.value)}
            })
        .attr("stroke", "white")
        .attr("stroke-width", 1)
        .on("mouseover", function (d) {
                if(d.value != 100) {
                    d3.select(this)
                        .attr("stroke", "green")
                    corrplot.append("text")
                        .attr("id", "corrtext")
                        .text("[" + data.traits[d.row] 
                              + " vs. " + data.traits[d.col] 
                              + ": " + d3.format(".2f")(d.value) 
                              + "]")
                        .style("fill", function () { 
                            if (d.value > 0) 
                            { return "#86B404"; } 
                            else if (d.value < 0) 
                            { return "#6A0888"; }
                        })  
                        .attr("x", totalW * 0.5)
                        .attr("y", totalH * 0.5)
                        .attr("font-weight", "bold")
                        .attr("dominant-baseline", "middle")
                        .attr("text-anchor", "middle")                       
                }
        })                
        .on("mouseout", function() {
                d3.selectAll("text.corrlabel").remove()
                d3.selectAll("text#corrtext").remove()
                d3.select(this).attr("stroke","white")
            });
            
    corrplot.append("rect")
        .attr("height", height)
        .attr("width", width)
        .attr("fill", "none")
        .attr("stroke", "#523CB5")
        .attr("stroke-width", 1)
        .attr("pointer-events", "none");
   
    var legendValues = []; 
    
    if (d3.min(coefs) > 0 && d3.max(coefs) > 0 ) {
        legendValues = [[0, 0], [1, d3.max(coefs)]];
    } else if (d3.min(coefs) < 0 && d3.max(coefs) < 0 )  {
        legendValues = [[0, d3.min(coefs)], [1, 0]]; 
    } else {
        legendValues = [[0, d3.min(coefs)], [1, 0], [2, d3.max(coefs)]];
    }
 
    var legend = corrplot.append("g")
        .attr("class", "cell")
        .attr("transform", "translate(" + (width + 10) + "," +  (height * 0.25) + ")")
        .attr("height", 100)
        .attr("width", 100);
       
    var recLH = 20;
    var recLW = 20;

    legend = legend.selectAll("rect")
        .data(legendValues)  
        .enter()
        .append("rect")
        .attr("x", function (d) { return 1;})
        .attr("y", function (d) {return 1 + (d[0] * recLH) + (d[0] * 5); })   
        .attr("width", recLH)
        .attr("height", recLW)
        .style("stroke", "black")
        .attr("fill", function (d) { 
            if (d === 100) {return "white"} 
            else {return corZscale(d[1])}
        });
 
    var legendTxt = corrplot.append("g")
        .attr("transform", "translate(" + (width + 40) + "," + ((height * 0.25) + (0.5 * recLW)) + ")")
        .attr("id", "legendtext");

    legendTxt.selectAll("text")
        .data(legendValues)  
        .enter()
        .append("text")              
        .attr("fill", "#523CB5")
        .style("fill", "#523CB5")
        .attr("x", 1)
        .attr("y", function (d) { return 1 + (d[0] * recLH) + (d[0] * 5); })
        .text(function (d) { 
            if (d[1] > 0) { return "Positive"; } 
            else if (d[1] < 0) { return "Negative"; } 
            else if (d[1] === 0) { return "Neutral"; }
        })  
        .attr("dominant-baseline", "middle")
        .attr("text-anchor", "start");

}


