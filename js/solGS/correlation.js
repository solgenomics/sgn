/** 
* correlation coefficients plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


function getPopulationDetails () {

    var populationId = jQuery("#population_id").val();
    var populationName = jQuery("#population_name").val();
   
    if(populationId == 'undefined' ) {       
        populationId = jQuery("#model_id").val();
        populationName = jQuery("#model_name").val();
    }

    return {'population_id' : populationId, 
            'population_name' : populationName
            };
        
}


jQuery(document).ready( function () { 
        var population = getPopulationDetails();
        
        jQuery.ajax({
                type: 'POST',
                    dataType: 'json',
                    data: {'population_id': population.population_id },
                    url: '/correlation/phenotype/data/',
                    success: function(response) {         
                    runCorrelationAnalysis();
                },
                    error: function(response) {                    
                   // alert('there is error in creating the phenotype data set for this correlation analysis.');
                }
            });

    });


function runCorrelationAnalysis () {
    var population = getPopulationDetails();
    
    jQuery.ajax({
            type: 'POST',
                dataType: 'json',
                data: {'population_id': population.population_id },
                url: '/correlation/analysis/output',
                success: function(response) {         
                plotCorrelation(response.data);
                jQuery("#correlation_message").empty();
            },
                error: function(response) {           
               // alert('There is error running correlation analysis.');
                jQuery("#correlation_message")
                    .css({"padding-left": '0px'})
                    .html("There is no correlation output for this population.");
            }
                
        });

}


function plotCorrelation (data) {
   
    data = data.replace(/\s/g, '');
    data = data.replace(/\\/g, '');
    data = data.replace(/^\"/, '');
    data = data.replace(/\"$/, '');
    data = data.replace(/\"NA\"/g, 100);
    
    data = JSON.parse(data);
    
    var height = 350;
    var width  = 350;
    var pad    = {left:70, top:5, right:5, bottom: 90}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    var nTraits = data.traits.length;      
    var corXscale = d3.scale.ordinal().domain(d3.range(nTraits)).rangeBands([0, width]);
    var corYscale = d3.scale.ordinal().domain(d3.range(nTraits)).rangeBands([height, 0]);
    var corZscale = d3.scale.linear().domain([-1, 0, 1]).range(["#0000A0", "white", "#A52A2A"]);

    var xAxisScale = d3.scale.ordinal()
        .domain(data.traits)
        .rangeBands([0, width]);

    var yAxisScale = d3.scale.ordinal()
        .domain(data.traits)
        .rangeRoundBands([height, 0]);

    var svg = d3.select("#correlation_canvas")
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
        .attr("fill", "purple")
        .style({"text-anchor":"start", "fill": "purple"});
          

    corrplot.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(0,0)")
        .call(yAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "purple")
        .style("fill", "purple");
          
   
    var corr = [];
       
    for (var i=0; i<data.coefficients.length; i++) {
        for  (var j=0;  j<data.coefficients[i].length; j++) {
            corr.push({"row":i, "col":j, "value": data.coefficients[i][j]});
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
        .attr("stroke", "none")
        .attr("stroke-width", 2)
        .on("mouseover", function (d) {
                if(d.value != 100) {
                    d3.select(this)
                    .attr("stroke", "green")
                    corrplot.append("text")
                    .attr("id", "corrtext")
                    .text("[" + data.traits[d.col] 
                          + " vs. " + data.traits[d.row] 
                          + ": " + d3.format(".2f")(d.value) 
                          + "]")
                    .style("fill", "#34282C")
                    .attr("x", function(){                       
                            var mult = -1;
                            if (d.col < nTraits/2) { mult = +1;}
                            return  corXscale(d.col) + mult * 30;
                        })
                .attr("y", function() {                       
                        var mult = +1;
                        if (d.row < nTraits/2) { mult = -1;}
                        return corYscale(d.row) + (mult + 0.35) * 20;
                    })
                    .attr("fill", "black")
                    .attr("dominant-baseline", "middle")
                    .attr("text-anchor", "middle")                       
                }
            })                
        .on("mouseout", function() {
                d3.selectAll("text.corrlabel").remove()
                d3.selectAll("text#corrtext").remove()
                d3.select(this).attr("stroke","none")
            });
            
    corrplot.append("rect")
        .attr("height", height)
        .attr("width", width)
        .attr("fill", "none")
        .attr("stroke", "purple")
        .attr("stroke-width", 1)
        .attr("pointer-events", "none");

}
