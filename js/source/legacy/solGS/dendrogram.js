
var solGS = solGS || function solGS() {};

solGS.dendrogram = {

    plot: function (data, dendroCanvasDiv, dendroPlotDiv, downloadLinks) {

	var width = 900;
	var height = 900;

	var svg = d3.select(dendroCanvasDiv)
	    .append("svg")
	    .attr("width", width)
	    .attr("height", height)
	    .append("g")
	    .attr("transform", "translate(40,0)");  

	if (typeof data == 'string') {
	    data = JSON.parse(data);
	}
	
	var cluster = d3.cluster()
            .size([height, width - 170]);  

	var root = d3.hierarchy(data);
	cluster(root);

	var links = root.descendants().slice(1);
	var linker = function(d) {
	    return "M" + d.y + "," + d.x
	        + "C" + (d.y + d.parent.y) / 2 + "," + d.x
	        + " " + (d.y + d.parent.y) / 2 + "," + d.parent.x
	        + " " + d.parent.y + "," + d.parent.x;
	};
		
	var links = svg.selectAll('.link')
            .data(links)
	    .enter()
            .append('path')
	    .attr('class', 'link')
	    .attr("d", linker)
	    .style("fill", '#96CA2D')
	    .attr("stroke-width", 3)
	    .attr("stroke", '#ccc');
	
	var nodes = root.descendants();
	
	var node = svg.selectAll(".node")
	    .data(nodes)
            .enter()
            .append("g")
	    .attr("class", "node")
            .attr("transform", function(d) {
		//console.log('d.y: ' + d.y + ' d.x: ' + d.x)
		return "translate(" + d.y + "," + d.x + ")"
	    })
	
        node.append("circle")
	    .attr("r", 3)
	    .style("fill", "purple")
            .attr("stroke", "purple")
            .style("stroke-width", 2);
	
	node.append("text")
	    .attr("dx", "8")
	    .attr("dy", "3")
	    .attr("font-family", "sans-serif")
	    .attr("font-size", "10px")
	    .attr("fill", "blue")
	    .style("text-anchor", 'start')
	    .text(function (d) {
		var leafName = d.data.name;
		//console.log('leafName: ' + leafName)
		if (!leafName.match(/node/)) {
		    return leafName;
		} else {
		    return;
		}
	    });

	if (downloadLinks) {
	    jQuery(dendroCanvasDiv).append('<p>' + downloadLinks + '</p>');
	}
	
    },
    
////////
}
