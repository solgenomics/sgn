/** 
* histogram plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


function getTraitDetails () {

    var populationId = jQuery("#population_id").val();
    var traitId = jQuery("#trait_id").val();
   
    if(populationId == 'undifined' ) {       
        populationId = jQuery("#model_id").val();

    }
    alert(traitId + ' ' + populationId);
    return {'population_id' : populationId, 
            'trait_id' : traitId
            };
        
}


jQuery(document).ready( function () { 
        var trait = getTraitDetails();
        
        jQuery.ajax({
                type: 'POST',
                    dataType: 'json',
                    data: {'population_id': trait.population_id, 'trait_id' : trait.trait_id  },
                    url: '/histogram/phenotype/data/',
                    success: function(response) { 
                    //  alert(response.data);
                   
                     plotHistogram(response.data);
                },
                    error: function(response) {
                    
                    alert('there is error in creating the phenotype data set for the histogram.');
                }
            });

    });


// function runCorrelationAnalysis () {
//     var population = getPopulationDetails();
    
//     jQuery.ajax({
//             type: 'POST',
//                 dataType: 'json',
//                 data: {'population_id': population.population_id },
//                 url: '/correlation/analysis/output',
//                 success: function(response) {         
//                 plotCorrelation(response.data);
//                 jQuery("#correlation_message").empty();
//             },
//                 error: function(response) {           
//                 alert('There is error running correlation analysis.');
//                 jQuery("#correlation_message")
//                     .css({"padding-left": '0px'})
//                     .html("There is no correlation output for this population.");
//             }
                
//         });

// }


function plotHistogram (data) {
    // alert(data[0][0] + ' ' + data[0][1] );
     
    var height = 300;
    var width  = 300;
    var pad    = {left:20, top:5, right:5, bottom: 20}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;

    
    traitValues = data.map( function (d) {
            d = d[1]; 
            return parseFloat(d); 
        });
var formatCount = d3.format(",.0f");
    // console.log(traitValues);
    traitValues = traitValues.sort();
    // console.log(traitValues);
     var histogram = d3.layout.histogram()
         .bins(10)
         (traitValues);
   
     // alert('test 2');
     // console.log(histogram);

    
    var xAxisScale = d3.scale.linear()
        .domain([0, d3.max(traitValues)])
        .range([0, width]);

    //alert('end x scale');

    var yAxisScale = d3.scale.linear()
        .domain([0, d3.max(histogram, ( function (d) {return d.y;}) )])
        .range([0, height]);

    var xAxis = d3.svg.axis()
        .scale(xAxisScale)
        .orient("bottom");

    var yAxis = d3.svg.axis()
        .scale(yAxisScale)
        .orient("left");

    // alert('test');
   

    var svg = d3.select("#trait_histogram_canvas")
        .append("svg")
        .attr("height", totalH)
        .attr("width", totalW);
          
    var histogramPlot = svg.append("g")
        .attr("id", "trait_histogram_plot")
        .attr("transform", "translate(" + pad.left + "," + pad.top + ")");

    //alert('start grouping bar');
    var bar = histogramPlot.selectAll(".bar")
        .data(histogram)
        .enter()
        .append("g")
        .attr("class", "bar")
        .attr("transform",  function(d) {return "translate(" + xAxisScale(d.x)  + "," + height -  yAxisScale(d.y) + ")"; });     
    //alert('end grouping bar');
    //attr("x", function(d) {return d.x; }
    //   .attr("y", height)

    //alert('start adding bar');
    bar.append("rect")
        .attr("x", function(d) { return xAxisScale(d.x); } )
        .attr("y", function(d) {return height - yAxisScale(d.y); }) 
        .attr("width", function(d) {return xAxisScale(d.dx); })
        .attr("height", function(d) { return yAxisScale(d.y); })
        .style("fill", "blue")
        .on("mouseover", function() {
                d3.select(this).style("fill", "red");
            })
        .on("mouseout", function() {
                d3.select(this).style("fill", "blue");
            });
    //  alert('end adding bar');
    bar.append("text")
    .attr("dy", ".75em")
    .attr("y", 6)
    .attr("x", xAxisScale(histogram[0].dx) / 2)
    .attr("text-anchor", "middle")
    .text(function(d) { return formatCount(d.y); });

   

    //  bar.append("text")
       
   //  histogramPlot.append("g")
//         .attr("class", "x axis")
//         .attr("transform", "translate(0," + height +")")
//         .call(xAxis)
//         .selectAll("text")
//         .attr("y", 0)
//         .attr("x", 10)
//         .attr("dy", ".1em")         
//         .attr("transform", "rotate(90)")
//         .attr("fill", "purple")
//         .style({"text-anchor":"start", "fill": "purple"});
          

//     histogramPlot.append("g")
//         .attr("class", "y axis")
//         .attr("transform", "translate(0,0)")
//         .call(yAxis)
//         .selectAll("text")
//         .attr("y", 0)
//         .attr("x", -10)
//         .attr("fill", "purple")
//         .style("fill", "purple");      
    
    
}   

