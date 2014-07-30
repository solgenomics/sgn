/** 
* breeding values vs phenotypic deviation 
* plotting using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


function getDataDetails () {

    var populationId   = jQuery("#population_id").val();
    var traitId        = jQuery("#trait_id").val();
   
    if(populationId == 'undefined' ) {       
        populationId = jQuery("#model_id").val();
    }

    if(populationId == 'undefined') {
        populationId = jQuery("#combo_pops_id").val();
    }

    return {'population_id' : populationId, 
            'trait_id' : traitId
            };
        
}


function checkDataExists () {
    var dataDetails  = getDataDetails();
    var traitId      = dataDetails.trait_id;
    var populationId = dataDetails.population_id;

    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': populationId, 'trait_id': traitId},
        url: '/heritability/check/data/',
        success: function(response) {
            if(response.exists === 'yes') {
                getRegressionData();

            } else {                
                calculateVarianceComponents();
            }
        },
        error: function(response) {                    
            // alert('there is error in checking the dataset for heritability analysis.');     
        }  
    });
  
}


function calculateVarianceComponents () {
    var dataDetails  = getDataDetails();
    var traitId      = dataDetails.trait_id;
    var populationId = dataDetails.population_id;
    
    var gebvUrl = '/solgs/trait/' + traitId  + '/population/' + populationId;
    
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'source' : 'heritability'},
        url: gebvUrl,
        success: function(response) {
            if(response.status === 'success') {
                getRegressionData();
            } else {
              jQuery("#heritability_message").html('Error occured estimating breeding values for this trait.');   
            }
        },
        error: function(response) { 
            jQuery("#heritability_message").html('Error occured estimating breeding values for this trait.');            
        }  
    });
}


function getRegressionData () { 
    var dataDetails  = getDataDetails();
    var traitId      = dataDetails.trait_id;
    var populationId = dataDetails.population_id;
    
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': populationId, 'trait_id': traitId},
        url: '/heritability/regression/data/',
        success: function(response) {
            if(response.status === 'success') {
                var regressionData = {
                    'breeding_values'     : response.gebv_data,
                    'phenotype_values'    : response.pheno_data,
                    'phenotype_deviations': response.pheno_deviations,
                    'heritability'        : response.heritability  
                };
                    
                jQuery("#heritability_message").empty();
                plotRegressionData(regressionData);
                jQuery("#trait_histogram_canvas").empty();
                getHistogramData();
            }
        },
        error: function(response) {                    
          jQuery("#heritability_message").html('Error occured getting regression data.');
        }
    });
}


function plotRegressionData(regressionData){
  
    var breedingValues      = regressionData.breeding_values;
    var phenotypeDeviations = regressionData.phenotype_deviations;
    var heritability        = regressionData.heritability;

    var phenoXValues = phenotypeDeviations.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

     var breedingYValues = breedingValues.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

    var plotData = phenotypeDeviations.map( function (pv) {
      
        var plotData =[];
        jQuery.each(breedingValues, function(i, gv) {
            
            if ( pv[0] === gv[0] ) {
         
                plotData.push({'name' : gv[0], 'gebv' : gv[1], 'pheno_dev': pv[1]} );
                return false;

            }
            
        });

        return plotData;
    });

    var height = 300;
    var width  = 500;
    var pad    = {left:20, top:20, right:20, bottom: 20}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    var svg = d3.select("#gebv_pheno_regression_canvas")
        .append("svg")
        .attr("width", totalW)
        .attr("height", totalH);

    var regressionPlot = svg.append("g")
        .attr("id", "#gebv_pheno_regression_plot")
        .attr("transform", "translate(" + (pad.left - 5) + "," + (pad.top - 5) + ")");

   
    var phenoMin = d3.min(phenoXValues);
    var phenoMax = d3.max(phenoXValues);
 
    var yLimits = d3.max([Math.abs(d3.min(breedingYValues)), d3.max(breedingYValues)])
    var xLimits = d3.max([Math.abs(d3.min(phenoXValues)), d3.max(phenoXValues)])
  
     var xAxisScale = d3.scale.linear()
        .domain([0, xLimits])
        .range([0, width/2]);
    
    var xAxisLabel = d3.scale.linear()
        .domain([(-1 * xLimits), xLimits])
        .range([0, width]);

    var yAxisScale = d3.scale.linear()
        .domain([0, yLimits])
        .range([0, (height/2)]);

    var xAxis = d3.svg.axis()
        .scale(xAxisLabel)
        .tickSize(3)
        .orient("bottom");
          
    var yAxisLabel = d3.scale.linear()
        .domain([(-1 * yLimits), yLimits])
        .range([height, 0]);
    
   var yAxis = d3.svg.axis()
        .scale(yAxisLabel)
        .tickSize(3)
        .orient("left");

    var xAxisMid = 0.5 * (totalH); 
    var yAxisMid = 0.5 * (totalW);
 
    regressionPlot.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(" + pad.left + "," + xAxisMid +")")
        .call(xAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", 10)
        .attr("dy", ".1em")         
        .attr("transform", "rotate(90)")
        .attr("fill", "purple")
        .style({"text-anchor":"start", "fill": "purple"});
       
    regressionPlot.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(" + yAxisMid +  "," + pad.top  + ")")
        .call(yAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "purple")
        .style("fill", "purple");

 regressionPlot.append("g")
        .attr("id", "x_axis_label")
        .append("text")
        .text("Phenotype deviations (X)")
        .attr("y", (pad.top + (height/2)) + 50)
        .attr("x", (width - 110))
        .attr("font-size", 10)

 regressionPlot.append("g")
        .attr("id", "y_axis_label")
        .append("text")
        .text("Breeding values (Y)")
        .attr("y", (pad.top -  10))
        .attr("x", ((width/2) - 80))
        .attr("font-size", 10)


    regressionPlot.append("g")
        .selectAll("circle")
        .data(plotData)
        .enter()
        .append("circle")
        .attr("fill", "green")
        .attr("r", 3)
        .attr("cx", function(d) {
            var xVal = d[0].pheno_dev;
           // console.log(xVal, xAxisScale(xVal),d[0].gebv, yAxisScale(d[0].gebv)); 
            if (xVal >= 0) {
                return  (pad.left + (width/2)) + xAxisScale(xVal);
            } else {   
                return (pad.left + (width/2)) - (-1 * xAxisScale(xVal));
           }
        })
        .attr("cy", function(d) { 
            
            var yVal = d[0].gebv;
            
            if (yVal >= 0) {
                return ( pad.top + (height/2)) - yAxisScale(yVal);
            } else {
                return  (pad.top + (height/2)) +  (-1 * yAxisScale(yVal));                  
            }
        })        
        .on("mouseover", function(d) {
            d3.select(this)
                .attr("r", 5)
                .style("fill", "purple")
            regressionPlot.append("text")
                .attr("id", "dLabel")
                .style("fill", "purple")
                .style("font-weight", "bold")
                .text( d[0].name + "(" +d[0].pheno_dev +"," + d[0].gebv + ")")
                .attr("x", pad.left + 10)
                .attr("y", pad.top + 50);
               

        })
        .on("mouseout", function(d) { 
            d3.select(this)
                .attr("r", 3)
                .style("fill", "green")
            d3.selectAll("text#dLabel").remove();            
        });

     regressionPlot.append("g")
        .attr("id", "heritability")
        .append("text")
        .text("Heritability: " + heritability)
        .attr("x", 20)
        .attr("y", 10)
        .style("fill", "purple")
        .style("font-weight", "bold");     
}


jQuery(document).ready( function () { 
   
    checkDataExists();   
 });






