/** 
* histogram plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


function getTraitDetails () {

    var populationId = jQuery("#population_id").val();
    var traitId = jQuery("#trait_id").val();
   
    if(populationId == 'undefined' ) {       
        populationId = jQuery("#model_id").val();

    }

    if(populationId == 'undefined' ) {       
        populationId = jQuery("#combo_pops_id").val();

    }
   
    return {'population_id' : populationId, 
            'trait_id' : traitId
            };
        
}


jQuery(document).ready( function () {     
    getHistogramData();
});

function getHistogramData () {
    var trait = getTraitDetails();
       
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': trait.population_id, 'trait_id' : trait.trait_id  },
        url: '/histogram/phenotype/data/',
        success: function(response) {
            if(response.status == 'success') {
                plotHistogram(response.data);
                jQuery("#histogram_message").empty();
            }
            
        },
        error: function(response) {
            var errorMessage = 'There is no phenotype data to plot.';
            jQuery("#histogram_message").html(errorMessage);                  
        }
    });
}


function plotHistogram (data) {
    
    var height = 300;
    var width  = 500;
    var pad    = {left:20, top:50, right:40, bottom: 50}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    
    traitValues = data.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });

    traitValues = traitValues.sort();
    // console.log(traitValues);
    var histogram = d3.layout.histogram()
        .bins(10)
        (traitValues);

     // console.log(histogram);
   
    var xAxisScale = d3.scale.linear()
        .domain([0, d3.max(traitValues)])
        .range([0, width]);

    //alert('end x scale');

    var yAxisScale = d3.scale.linear()
        .domain([0, d3.max(histogram, ( function (d) {return d.y;}) )])
        .range([0, height]);

    var xRange =  d3.max(traitValues) -  d3.min(traitValues);
    
    var xAxis = d3.svg.axis()
        .scale(xAxisScale)
        .orient("bottom")
        .tickValues(d3.range(d3.min(traitValues), 
                             d3.max(traitValues),  
                             0.1 * xRange)
                    );
 
     var yAxisLabel = d3.scale.linear()
        .domain([0, d3.max(histogram, ( function (d) {return d.y;}) )])
        .range([height, 0]);
    var yAxis = d3.svg.axis()
        .scale(yAxisLabel)
        .orient("left");

    var svg = d3.select("#trait_histogram_canvas")
        .append("svg")
        .attr("height", totalH)
        .attr("width", totalW);
          
    var histogramPlot = svg.append("g")
        .attr("id", "trait_histogram_plot")
        .attr("transform", "translate(" +  pad.left + "," + pad.top + ")");

    var bar = histogramPlot.selectAll(".bar")
        .data(histogram)
        .enter()
        .append("g")
        .attr("class", "bar")
        .attr("transform", function(d) {
            return "translate(" + xAxisScale(d.x)  
                + "," + height - yAxisScale(d.y) + ")"; 
            });     
  
    bar.append("rect")
        .attr("x", function(d) { return (pad.left + 5) + xAxisScale(d.x); } )
        .attr("y", function(d) {return height - yAxisScale(d.y); }) 
        .attr("width", function(d) {return xAxisScale(d.dx) - 2  ; })
        .attr("height", function(d) { return yAxisScale(d.y); })
        .style("fill", "green")
        .on("mouseover", function(d) {
                d3.select(this).style("fill", "teal");
            })
        .on("mouseout", function() {
                d3.select(this).style("fill", "green");
            });
   
    bar.append("text")
        .text(function(d) { return d.y; })
        .attr("y", function(d) {return height - (yAxisScale(d.y) + 10); } )
        .attr("x",  function(d) { return ((2*pad.left) + xAxisScale(d.x)); } )      
        .attr("dy", ".6em")
        .attr("text-anchor", "end")  
        .attr("font-family", "sans-serif")
        .attr("font-size", "12px")
        .attr("fill", "green")
        .attr("class", "histoLabel");
                  
    histogramPlot.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(" + (2*pad.left) + "," + height +")")
        .call(xAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", 10)
        .attr("dy", ".1em")         
        .attr("transform", "rotate(90)")
        .attr("fill", "purple")
        .style({"text-anchor":"start", "fill": "green"});
     
          
    histogramPlot.append("g")
        .attr("class", "y axis")
        .attr("transform", "translate(" +(2* pad.left) +  "," + 0 + ")")
        .call(yAxis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "green")
        .style("fill", "green");

    histogramPlot.append("g")
        .attr("transform", "translate(" + (totalW * 0.5) + "," + (height + pad.bottom) + ")")        
        .append("text")
        .text("Trait values")            
        .attr("fill", "teal")
        .style("fill", "teal");

    histogramPlot.append("g")
        .attr("transform", "translate(" + 0 + "," + ( totalH*0.5) + ")")        
        .append("text")
        .text("Frequency")            
        .attr("fill", "teal")
        .style("fill", "teal")
        .attr("transform", "rotate(-90)");
       
    
}   

