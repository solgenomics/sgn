/**
* heatmap plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS() {};

solGS.heatmap = {

    plot: function (data, heatmapCanvasDiv, heatmapPlotDiv, downloadLinks) {

	if (heatmapCanvasDiv == null) {
	    alert("The div element where the heatmap to draw is missing.");
	}

	data = JSON.parse(data);

	var labels = data.labels;
	var values = data.values;
	var nLabels = labels.length;

	var corr = [];
	var coefs = [];

        for (var i=0;  i<values.length; i++) {

	    var rw = values[i];

	    for (var j = 0; j<nLabels; j++) {
		var clNm = labels[j];

		var rwVl = rw[clNm];

		if (rwVl === undefined) {rwVl = 'NA';}

		corr.push({"row": i, "col": j, "value": rwVl});

		if (rwVl != 'NA') {
		    coefs.push(rwVl);
		}

	    }
	}

	if (heatmapCanvasDiv.match(/#/) == null) {heatmapCanvasDiv = '#' + heatmapCanvasDiv;}



	if (heatmapPlotDiv) {
          heatmapPlotDiv = heatmapPlotDiv.replace(/#/, '');
	//     if (heatmapPlotDiv.match(/#/) == null) {heatmapPlotDiv = '#' + heatmapPlotDiv;}
	} else {
	    heatmapPlotDiv =  "heatmap_plot";
	}
	console.log(heatmapCanvasDiv + ' ' + heatmapPlotDiv )
	var heatmapCanvas = heatmapCanvasDiv;

	var fs = 10;

	if (nLabels >= 100) {
	    height = 600;
	    width  = 600;
	    fs = 10 * .85;
	} else {
	    height = 500;
	    width  = 500;
	    fs = 10 * 1.2;
	}

	if (nLabels < 20) {
            height = height * 0.5;
            width  = width  * 0.5;
	    fs = 10 * 1.3;
	}

	fs = fs + 'px';

	var pad    = {left:150, top:30, right:255, bottom: 150};
	var totalH = height + pad.top + pad.bottom;
	var totalW = width + pad.left + pad.right;

	var nve  = "#6A0888";
	var pve  = "#86B404";
	var nral = "#98AFC7"; //blue gray

	var rmax = d3.max(coefs);
	var rmin = d3.min(coefs);

	var coefRange = [];
	var coefDom = [];

	if (rmin >= 0 && rmax > 0 ) {
            rmax = rmax;
	    coefDom = [0, rmax];
	    coefRange = ["white", pve];

	} else if (rmin < 0 && rmax > 0)  {
	    if (-rmin > rmax) {
		rmax = -rmin;
	    }
	    coefDom = [-rmax, 0, rmax];
	    coefRange = [nve, "white", pve];

	} else if (rmin <= 0 && rmax < 0 ) {
	    coefDom = [rmin, 0];
	    coefRange = [nve, "white"];
	}

	var corXscale = d3.scale.ordinal().domain(d3.range(nLabels)).rangeBands([0, width]);
	var corYscale = d3.scale.ordinal().domain(d3.range(nLabels)).rangeBands([height, 0]);
	var corZscale = d3.scale.linear().domain(coefDom).range(coefRange);

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
            .attr("x", 10)
	    .attr("y", 0)
	    .attr("dy", ".1em")
            .attr("transform", "rotate(90)")
            .attr("fill", "#523CB5")
            .style({"text-anchor":"start", "fill": "#523CB5", "font-size":fs});

	corrplot.append("g")
            .attr("class", "y axis")
            .attr("transform", "translate(0,0)")
            .call(yAxis)
            .selectAll("text")
            .attr("x", -10)
	    .attr("y", 0)
            .attr("dy", ".1em")
            .attr("fill", "#523CB5")
            .style({"fill": "#523CB5", "font-size":fs});


	var cell = corrplot.selectAll("rect")
            .data(corr)
            .enter().append("rect")
            .attr("class", "cell")
            .attr("x", function (d) {return corXscale(d.col)})
            .attr("y", function (d) {return corYscale(d.row)})
            .attr("width", corXscale.rangeBand())
            .attr("height", corYscale.rangeBand())
            .attr("fill", function (d) {
                if (d.value == 'NA') {
		    return "white";
		}  else if (d.value == 0){
		    return nral;
		} else {
		    return corZscale(d.value);
		}
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
                              + ": " + d3.format(".3f")(d.value)
                              + "]")
                        .style("fill", function () {
                            if (d.value >  0) {
				return pve;
			    }
			    else if (d.value == 0) {
				return nral;
			    }
			    else if (d.value < 0) {
				return nve;
			    }
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

	if (d3.min(coefs) >= 0 && d3.max(coefs) > 0 ) {
            legendValues = [[0, 0], [1, d3.max(coefs)]];
	} else if (d3.min(coefs) < 0 && d3.max(coefs) < 0 )  {
            legendValues = [[0, d3.min(coefs)], [1, 0], [2, 1]];
	} else {
            legendValues = [[0, d3.min(coefs)], [1, 0], [2, d3.max(coefs)]];
	}

	if (heatmapCanvas.match(/kinship/)) {
	    legendValues.push([3, 'Diagonals: inbreeding coefficients'], [4, 'Off-diagonals: kinship coefficients']);
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
		if (d == 'NA') {
		    return "white";
		} else if( d[1] == 0) {
		    return nral;
		} else {
		    return corZscale(d[1])
		}
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
		if (d[1] > 0) { return '> 0'; }
		else if (d[1] < 0) { return '< 0'; }
		else if (d[1] == 0 ){ return '0'; }
		else {
		    return d[1];
		}
            })
            .attr("dominant-baseline", "middle")
            .attr("text-anchor", "start");


	if (downloadLinks) {
	    jQuery(heatmapCanvas).append('<p>' + downloadLinks + '</p>');
	}

    },


///////
}
