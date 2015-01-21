/** 
* Principal component analysis and scores plotting 
* plotting using d3js
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


jQuery(document).ready( function() { 
   
    pcaResult();   
 
});


function pcaResult () {
    var popId = getPopulationId();

   // alert(popId);
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        data: {'population_id': popId},
        url: '/pca/result/' + popId,
        success: function(response) {
            if(response.status === 'success') {
	
		var scores = response.pca_scores;
		var variances = response.pca_variances;
		var plotData = { 'scores': scores, 'variances': variances };

                plotPca(plotData);

		jQuery("#pca_message").empty();

            } else {                
               jQuery("#pca_message").html(response.status); 
            }
        },
        error: function(response) {                    
             jQuery("#pca_message").html('Error occured running population structure analysis (PCA).');   
        }  
    });
  
}


function getPopulationId () {

    var populationId = jQuery("#population_id").val();
  
    if (!populationId) {       
        populationId = jQuery("#model_id").val();
    }

    if (!populationId) {
        populationId = jQuery("#combo_pops_id").val();
    }

    return populationId;
        
}


function plotPca(plotData){
    var scores = plotData.scores;
    var variances = plotData.variances;
    
    var pc12 = [];
    var pc1  = [];
    var pc2  = []; 

    jQuery.each(scores, function(i, pc) {
                   
	pc12.push( [{'name' : pc[0], 'pc1' : parseFloat(pc[1]), 'pc2': parseFloat(pc[2])}] );
	pc1.push(parseFloat(pc[1]));
	pc2.push(parseFloat(pc[2]));
 
    });
     
    var height = 300;
    var width  = 500;
    var pad    = {left:20, top:20, right:20, bottom: 50}; 
    var totalH = height + pad.top + pad.bottom;
    var totalW = width + pad.left + pad.right;
   
    var svg = d3.select("#pca_canvas")
        .append("svg")
        .attr("width", totalW)
        .attr("height", totalH);

    var pcaPlot = svg.append("g")
        .attr("id", "#pca_plot")
        .attr("transform", "translate(" + (pad.left) + "," + (pad.top) + ")");

    var pc1Min = d3.min(pc1);
    var pc1Max = d3.max(pc1); 

    var pc1Limits = d3.max([Math.abs(d3.min(pc1)), d3.max(pc1)]);
    var pc2Limits = d3.max([Math.abs(d3.min(pc2)), d3.max(pc2)]);
  
    var pc1AxisScale = d3.scale.linear()
        .domain([0, pc1Limits])
        .range([0, width/2]);
    
    var pc1AxisLabel = d3.scale.linear()
        .domain([(-1 * pc1Limits), pc1Limits])
        .range([0, width]);

    var pc2AxisScale = d3.scale.linear()
        .domain([0, pc2Limits])
        .range([0, (height/2)]);

    var pc1Axis = d3.svg.axis()
        .scale(pc1AxisLabel)
        .tickSize(3)
        .orient("bottom");
          
    var pc2AxisLabel = d3.scale.linear()
        .domain([(-1 * pc2Limits), pc2Limits])
        .range([height, 0]);
    
   var pc2Axis = d3.svg.axis()
        .scale(pc2AxisLabel)
        .tickSize(3)
        .orient("left");
   
    var pc1AxisMid = 0.5 * (totalH); 
    var pc2AxisMid = 0.5 * (totalW);
  
    var yMidLineData = [
	{"x": pc2AxisMid, "y": pad.top}, 
	{"x": pc2AxisMid, "y": pad.top + height}
    ];

    var xMidLineData = [
	{"x": pad.left, "y": pad.top + height/2}, 
	{"x": pad.left + width, "y": pad.top + height/2}
    ];

    var lineFunction = d3.svg.line()
        .x(function(d) { return d.x; })
        .y(function(d) { return d.y; })
        .interpolate("linear");

    pcaPlot.append("path")
        .attr("d", lineFunction(yMidLineData))
        .attr("stroke", "red")
        .attr("stroke-width", 1)
        .attr("fill", "none");

    pcaPlot.append("path")
        .attr("d", lineFunction(xMidLineData))
        .attr("stroke", "green")
        .attr("stroke-width", 1)
        .attr("fill", "none");

    pcaPlot.append("g")
        .attr("class", "PC1 axis")
        .attr("transform", "translate(" + pad.left + "," + (pad.top + height) +")")
        .call(pc1Axis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", 10)
        .attr("dy", ".1em")         
        .attr("transform", "rotate(90)")
        .attr("fill", "green")
        .style({"text-anchor":"start", "fill": "#86B404"});
      
    pcaPlot.append("g")
        .attr("class", "PC2 axis")
        .attr("transform", "translate(" + pad.left +  "," + pad.top  + ")")
        .call(pc2Axis)
        .selectAll("text")
        .attr("y", 0)
        .attr("x", -10)
        .attr("fill", "green")
        .style("fill", "#86B404");

    pcaPlot.append("g")
        .attr("id", "pc1_axis_label")
        .append("text")
        .text("PC1, " + variances[0][1] + "%" )
        .attr("y", pad.top + height + 30)
        .attr("x", width/2)
        .attr("font-size", 10)
        .style("fill", "#9A2EFE")

    pcaPlot.append("g")
        .attr("id", "pc2_axis_label")
        .append("text")
        .text("PC2, " + variances[1][1] + "%" )
	.attr("transform", "rotate(-90)")

	.attr("y", -5)
        .attr("x", -((pad.top + height/2) + 10))
        .attr("font-size", 10)
        .style("fill", "#9A2EFE")

    pcaPlot.append("g")
        .selectAll("circle")
        .data(pc12)
        .enter()
        .append("circle")
        .attr("fill", "#9A2EFE")
        .attr("r", 3)
        .attr("cx", function(d) { 
            var xVal = d[0].pc1;            
	    if (xVal >= 0) {
                return  (pad.left + (width/2)) + pc1AxisScale(xVal);
            } else {
                return (pad.left + (width/2)) - (-1 * pc1AxisScale(xVal));
           }
        })
        .attr("cy", function(d) {             
            var yVal = d[0].pc2;
            
            if (yVal >= 0) {
                return ( pad.top + (height/2)) - pc2AxisScale(yVal);
            } else {
                return (pad.top + (height/2)) +  (-1 * pc2AxisScale(yVal));                  
            }
        })        
        .on("mouseover", function(d) {
            d3.select(this)
                .attr("r", 5)
                .style("fill", "#86B404")
            pcaPlot.append("text")
                .attr("id", "dLabel")
                .style("fill", "#86B404")              
                .text( d[0].name + "(" + d[0].pc1 + "," + d[0].pc2 + ")")
                .attr("x", pad.left + 1)
                .attr("y", pad.top + 80);
        })
        .on("mouseout", function(d) { 
            d3.select(this)
                .attr("r", 3)
                .style("fill", "#9A2EFE")
            d3.selectAll("text#dLabel").remove();            
        });

    pcaPlot.append("rect")
	.attr("transform", "translate(" + pad.left + "," + pad.top + ")")
        .attr("height", height)
        .attr("width", width)
        .attr("fill", "none")
        .attr("stroke", "#523CB5")
        .attr("stroke-width", 1)
        .attr("pointer-events", "none");
      
}









