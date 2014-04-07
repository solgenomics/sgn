/** 
* breeding values vs phenotypic deviation 
* plotting using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

JSAN.use('statistics.jsStats');


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
        data: {'population_id': populationId, 'trait_id': traitId },
        url: '/heritability/check/data/',
        success: function(response) {
            if(response.exists === 'yes') {
                getRegressionData();

            } else {                
        
            }
        },
        error: function(response) {                    
            // alert('there is error in checking the dataset for heritability analysis.');
      
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
            data: {'population_id': populationId, 'trait_id': traitId },
            url: '/heritability/regression/data/',
            success: function(response) {
                if(response.status === 'success') {
                    var regressionData = {
                        'breeding_values'     : response.gebv_data,
                        'phenotype_values'    : response.pheno_data,
                        'phenotype_deviations': response.pheno_deviations
                    };
                    plotRegressionData(regressionData);
                                   
                } else {
                    
                    alert('there is problem getting regression data.');
                }
            },
            error: function(response) {                    
                alert('there is porblem getting regression data.');
            }
        });

}


function plotRegressionData(regressionData){
  
    var breedingValues      = regressionData.breeding_values;
    var phenotypeDeviations = regressionData.phenotype_deviations;

    var phenoXValues = phenotypeDeviations.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

     var breedingYValues = breedingValues.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

    var plotData = phenotypeDeviations.map( function (pv) {
        var combinedData = {};    
        var plotData =[];
        jQuery.each(breedingValues, function(i, gv) {
            
            if ( pv[0] === gv[0] ) {
            
                combinedData = jQuery.extend(combinedData, {'clone': pv[0], 'gebv': gv[1], 'pheno' : pv[1]});
                plotData.push({'name' : gv[0], 'gebv' : gv[1], 'pheno_dev': pv[1]} );
                return false;
            }
            
        });

        return plotData;
    });

   // alert('gebv max ' + d3.max(breedingYValues) + ' gebv min ' + d3.min(breedingYValues) );
   // alert('pheno max ' + d3.max(phenoXValues) + ' pheno min ' + d3.min(phenoXValues) )


    //alert('plot data: ' + plotData);

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
        .attr("transform", "translate(" + pad.left + "," + pad.top + ")");

   
    var phenoMin = d3.min(phenoXValues);
    var phenoMax = d3.max(phenoXValues);
 
    var yLimits = d3.max([Math.abs(d3.min(breedingYValues)), d3.max(breedingYValues)])
    var xLimits = d3.max([Math.abs(d3.min(phenoXValues)), d3.max(phenoXValues)])
  
     var xAxisScale = d3.scale.linear()
        .domain([0, xLimits])
        .range([0, (width/2)]);
    
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
        .domain([(-1 * yLimits), yLimits, ])
        .range([height, 0]);
    
   var yAxis = d3.svg.axis()
        .scale(yAxisLabel)
        .tickSize(3)
        .orient("left");

    var it1 = yAxisScale(-0.5);
    var it2 = yAxisScale(0.5);
    var it3 = xAxisScale(-0.5);
    var it4 = xAxisScale(0.5);
    alert(it1 + " (-.5 : .5) " + it2);
     alert(it3 + " (-.5 : .5) " + it4);
   // console.log(plotData);
    var xAxisMid = 0.5 * (totalH); // pad.left + xAxisScale(d3.min(phenoXValues)); // pad.top + yAxisScale(d3.max(breedingYValues));
   // alert('xMid ' +  xAxisMid);

    var yAxisMid = 0.5 * (totalW); // pad.top + yAxisScale(d3.max(breedingYValues));
   // alert('yMid ' +  yAxisMid);
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
        .style({"text-anchor":"start", "fill": "green"});
       
    regressionPlot.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(" + yAxisMid +  "," + pad.top  + ")")
        .call(yAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "green")
        .style("fill", "green");

    regressionPlot.append("g")
        .selectAll("circle")
        .data(plotData)
        .enter()
        .append("circle")
        .attr("fill", "green")
        .attr("r", 3)
        .attr("cx", function(d) {
            var xVal = d[0].pheno_dev;
            console.log(xVal, xAxisScale(xVal),d[0].gebv, yAxisScale(d[0].gebv)); 
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
            regressionPlot.append("text")
                .attr("id", "dLabel")
                .style("fill", "green")
                .text( d[0].name + "(" +d[0].pheno_dev +"," + d[0].gebv + ")") 

        })
        .on("mouseout", function(d) { 
            d3.select(this)
                .attr("r", 3)
            d3.selectAll("text#dLabel").remove();            
        });


    
}


jQuery(document).ready( function () { 
    checkDataExists();
 });






