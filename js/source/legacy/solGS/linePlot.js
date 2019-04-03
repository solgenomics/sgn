/** 
* draws any number of line plots; for now only for numeric x and y values.
* import solGS.linePlot and call it like solGS.linePlot(lineData);
* lineData argument has the ff structure


var lineData =  {
	    'div_id': svgId, 
	    'plot_title': title, 
	    'x_axis_label': xLabel,
	    'y_axis_label': yLabel,
	    'axis_label_color: axisLabelColor,
	    'lines' : 
	    [ 		
		{
		    'data'  : xy, 
		    'legend': lineDesc ,
		    'color' : optional,
		},	
		{
		    'data'  : xy, 
		    'legend': legend,
		    'color' : optional,
		},		    
		
	    ]    
	};


* Isaak Y Tecle <iyt2@cornell.edu>

**/

var solGS = solGS || function solGS () {};

solGS.linePlot = function (allData) { 

    var linePlot = drawLines(allData);
  
    function getXValues (xy) {
	
	var xv = [];
	
	for (var i=0; i < xy.length; i++) {      
            var x = xy[i][0];
            x     = x.replace(/^\s+|\s+$/g, '');
	    x     = Number(x);
	    xv.push(x);
	}
	
	return xv;
	
    }


    function getYValues (xy) {
	
	var yv = [];
	
	for (var i=0; i < xy.length; i++) {      
            var y = xy[i][1];	 
            y     = Number(y);
	    
	    yv.push(y);
	}
	
	return yv;
	
    }


    function getLegendValues (allData) {
	
	var legend = [];
	var linesCount = Object.keys(allData.lines).length;

	setLineColors(allData);

	for (var i=0; i < linesCount; i++) {
	    var lc = allData.lines[i].color;
	    var l  = allData.lines[i].legend;

	    legend.push([lc, l]);
	}

	return legend;

    }


    function getExtremeValues (alldata) {
	
	var linesCount = Object.keys(allData.lines).length;
	
	var eX = [];
	var eY = [];

	for ( var i=0; i < linesCount; i++) {
	    var data = allData.lines[i].data;
	    var x = getXValues(data);
	    var y = getYValues(data);
	  
	    eX.push(d3.min(x), d3.max(x));
	    eY.push(d3.min(y), d3.max(y));	
	}  

	return { 'x' : eX, 'y': eY };

    }


    function setLineColors (allData) {
	
	var colors = [ 
	    '#86B404', '#F7D358', 
	    '#5C5858', '#4863A0', 
	    '#A18648', '#8C001A',
	];
	
	var linesCount = Object.keys(allData.lines).length;
	
	for ( var i=0; i < linesCount; i++) {

	    if (!allData.lines[i].color) {
		allData.lines[i].color = colors[i];   
	    }	
	}
    }


    function drawLines (allData) {
	
	var svgId = allData.div_id;
	var title = allData.plot_title;
	
	var height = 300;
	var width  = 800;
	var pad    = {'left':60, 'top':40, 'right':20, 'bottom': 40}; 
	var totalH = height + pad.top + pad.bottom;
	var totalW = width + pad.left + pad.right;		

	jQuery(svgId).append('<div id=line_plot></div>');
	
	var plotId = '#line_plot';
	var axisColor = allData.axis_label_color; 
  
	var yLabel = allData.y_axis_label;
	var xLabel = allData.x_axis_label;
	var title  = allData.plot_title;
	
	var legendValues = getLegendValues(allData); 
	
	var extremes  = getExtremeValues(allData);
	var extremesX = extremes.x;
	var extremesY = extremes.y;

	var xScale = d3.scale.linear()
	    .domain([d3.min(extremesX), d3.max(extremesX)])
	    .range([0, width]);

	var yScale = d3.scale.linear()
	    .domain([0, d3.max(extremesY)])
	    .range([height, 0]);
	
	var line = d3.svg.line()
	    .interpolate('basis')
	    .x(function(d) { 
		return xScale(d[0]); 
	    })
	    .y(function(d) { 			
		return yScale(d[1]); 
	    });

	var svg = d3.select(svgId)
	    .append("svg")
	    .attr("width", totalW)
	    .attr("height", totalH);

	var graph = svg.append("g")
	    .attr("id", plotId)
            .attr("transform", "translate(" + pad.left + "," + pad.top  + ")");

	var xAxis = d3.svg.axis()
            .scale(xScale)
            .orient("bottom")
	    .ticks(15);

	var yAxis = d3.svg.axis()
            .scale(yScale)
	    .ticks(5)
            .orient("left");
	
	graph.append("g")
	    .attr("class", "x axis")
	    .attr("transform", "translate(0,"  +  height + ")")
	    .call(xAxis)
	    .attr("fill", axisColor)
            .style({"text-anchor":"start", "fill": axisColor});

	graph.append("g")
	    .attr("class", "y axis")
	    .attr("transform", "translate(0,0)")
	    .call(yAxis)
	    .attr("fill", axisColor);
	
	var linesCount = Object.keys(allData.lines).length;

	for ( var i=0; i < linesCount; i++) {   
	    
	    var path = graph.append("path")
		.attr("d", line(allData.lines[i].data))
		.attr("stroke", allData.lines[i].color)
		.attr("stroke-width", "3")
		.attr("fill", "none");
	    
	    var totalLength = path.node().getTotalLength();

	    path.attr("stroke-dasharray", totalLength + " " + totalLength)
    		.attr("stroke-dashoffset", totalLength)
    		.transition()
		.duration(2000)
		.ease("linear")
		.attr("stroke-dashoffset", 0);
	}

	graph.append("text")
            .attr("id", "title")
            .attr("fill", axisColor)              
            .text(title)
            .attr("x", pad.left)
            .attr("y", -20);
	
	graph.append("text")
            .attr("id", "xLabel")
            .attr("fill", axisColor)              
            .text(xLabel)
            .attr("x", width * 0.5)
            .attr("y", height + 40);

	graph.append("text")
            .attr("id", "yLabel")
            .attr("fill", axisColor)              
            .text(yLabel)     
	    .attr("transform", "translate(" + -40 + "," +  height * 0.5 + ")" + " rotate(-90)");

	var legendTxt = graph.append("g")
    	    .attr("transform", "translate(" + (width - 150) + "," + (height * 0.25)  + ")")
            .attr("id", "normalLegend");

	legendTxt.selectAll("text")
            .data(legendValues)  
            .enter()
            .append("text")              
            .attr("fill", function (d) { 
		return d[0]; 
	    })
	    .attr("font-weight", "bold")
            .attr("x", 1)
            .attr("y", function (d, i) { 
		return i * 20; 
	    })
            .text(function (d) { 
		return d[1];
	    }); 

	return {'graph': graph, 'xScale': xScale, 'yScale': yScale};
	
    }

    return linePlot;

}
