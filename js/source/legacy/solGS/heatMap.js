/** 
* heatmap plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS() {};

solGS.heatmap = {

    plot: function (data, heatmapCanvasDiv, heatmapPlotDiv, downloadLinks) {

	data = JSON.parse(data);

	var labels = data.labels.splice(0,20);
	//var labels = data.labels;
	var values = data.values;
	var nLabels = labels.length;

	var corr = [];
	var coefs = [];
	
        for (var i=0;  i<values.length; i++) {

	    if (i < 20) {
	    var rw = values[i];
	    
	    for (var j = 0; j<nLabels; j++) {
		var clNm = labels[j];
		
		var rwVl = rw[clNm];
		
		if (rwVl === undefined) {rwVl = 'NA';}

		if (j < 20) {
		
		corr.push({"row": i, "col": j, "value": rwVl});

		if (rwVl != 'NA') {
		    coefs.push(rwVl);
		}			
		}		
	}
	    }
	}

	if (heatmapCanvasDiv.match(/#/) == null) {heatmapCanvasDiv = '#' + heatmapCanvasDiv;}
	
	if (heatmapPlotDiv) {
	    if (heatmapPlotDiv.match(/#/) == null) {heatmapPlotDiv = '#' + heatmapPlotDiv;}
	} else {
	    heatmapPlotDiv =  "#heatmap_plot"; 
	}

	var heatmapCanvas = heatmapCanvasDiv; 

	var plotExists = jQuery(heatmapCanvas).text();
	console.log('plotexist ', plotExists)
	
	var height = 400;
	var width  = 400;

	if (nLabels < 8) {
            height = height * 0.5;
            width  = width  * 0.5;
	}

	var pad    = {left:70, top:30, right:100, bottom: 90};
	var totalH = height + pad.top + pad.bottom;
	var totalW = width + pad.left + pad.right;

	var corXscale = d3.scale.ordinal().domain(d3.range(nLabels)).rangeBands([0, width]);
	var corYscale = d3.scale.ordinal().domain(d3.range(nLabels)).rangeBands([height, 0]);
	var corZscale = d3.scale.linear().domain([-1, 0, 1]).range(["#6A0888","white", "#86B404"]);

	var xAxisScale = d3.scale.ordinal()
            .domain(labels)
            .rangeBands([0, width]);

	var yAxisScale = d3.scale.ordinal()
            .domain(labels)
            .rangeRoundBands([height, 0]);
	
	var svg = d3.select(heatmapCanvas)
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
            .attr("id", heatmapPlotDiv)
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
        

	var cell = corrplot.selectAll("rect")
            .data(corr)  
            .enter().append("rect")
            .attr("class", "cell")
            .attr("x", function (d) {return corXscale(d.col)})
            .attr("y", function (d) {return corYscale(d.row)})
            .attr("width", corXscale.rangeBand())
            .attr("height", corYscale.rangeBand())      
            .attr("fill", function (d) {
                if (d.value == 'NA') {return "white";} 
                else { return corZscale(d.value)}
            })
            .attr("stroke", "white")
            .attr("stroke-width", 1)
            .on("mouseover", function (d) {
                if(d.value != 'NA') {
                    d3.select(this)
                        .attr("stroke", "green")
                    corrplot.append("text")
                        .attr("id", "corrtext")
                        .text("[" + labels[d.row]
                              + " vs. " + labels[d.col] 
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
            .attr("y", function (d) { return 1 + (d[0] * recLH) + (d[0] * 5); })   
            .attr("width", recLH)
            .attr("height", recLW)
            .style("stroke", "black")
            .attr("fill", function (d) { 
		if (d == 'NA') {return "white"} 
		else {return corZscale(d[1])}
            });
	
	var legendTxt = corrplot.append("g")
            .attr("transform", "translate(" + (width + 40) + ","
		  + ((height * 0.25) + (0.5 * recLW)) + ")")
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


	if (downloadLinks) {
	    jQuery(heatmapCanvas).append('<p>' + downloadLinks + '</p>');
	}
   
    },

    
///////
}




