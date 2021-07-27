/**
* histogram plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

var solGS = solGS || function solGS () {};


solGS.histogram =  {

    cleanData: function (traitValues) {
        traitValues = traitValues.sort();
        traitValues = traitValues.filter( function(val) {

        return !(val === ""
             || typeof val == "undefined"
             || val === null
             || isNaN(val) == true
            );
        });

        return traitValues;
    },

    extractValues: function (traitData) {

        var traitValues = traitData.map( function (d) {
            return  parseFloat(d[1]);
        });

        return traitValues;
    },

    getUnique: function (inputArray) {

	var outputArray = [];
	for (var i = 0; i < inputArray.length; i++) {
	    if ((jQuery.inArray(inputArray[i], outputArray)) == -1) {
		outputArray.push(inputArray[i]);
	    }
	}

	return outputArray;
    },

    checkDataVariation: function (traitData) {
        var traitValues = this.extractValues(traitData);
        traitValues = this.cleanData(traitValues);
        var obsCnt = traitValues.length;

        var uniqValues = this.getUnique(traitValues);
        var uniqCnt = uniqValues.length;

        return {
            'obs_count': obsCnt,
            'uniq_count': uniqCnt,
            'uniqValue': uniqValues[0]
        };
    },

    createBinElementsTable: function () {

        var table = '<div class="bin_elements" style="display:none">'
          + '<table class="table bin_elements_table" style="text-align: left;">'
          + '<thead>'
          +  '<tr>'
          +  '<th>Bin elements</th>'
          +  '<th>Values</th>'
          +  '</tr>'
          + '</thead>'
          + '</table>'
          + '</div>';

        return table;
    },

    displayBinElements: function(data, canvas) {
        var table;
        if (!jQuery(canvas + ' .bin_elements').length) {
            table = this.createBinElementsTable();
            jQuery(canvas).append(table);
        }

        jQuery(canvas + ' .bin_elements').show();
        table = canvas  +  ' .bin_elements .bin_elements_table';
        if (jQuery.fn.DataTable.isDataTable(table) ) {
             jQuery(table).DataTable().destroy();
        }

       table = jQuery(table).DataTable({
        'searching' : false,
        'ordering'  : false,
        'processing': true,
        'paging'    : false,
        'info'      : false,
        });

        table.clear().draw();
        table.rows.add(data).draw();

    },


//  call plotHistogram with an object with the ff str.
    // histo = {'canvas': 'div element to draw the plot',
    // 'plot_id': 'plot div element',
    // 'x_label': 'label for x axis',
    // 'y_label': 'label for y axis',
    // 'bar_color': 'optional color for bars,
    // 'alt_bar_color': 'optional color for bars for on mouseover',
   // 'values': optional array of values
    // 'namedValues' : an array of arrray of named values}, necessary if you want view bin
        //elements on mouseover;
    //
    plotHistogram: function (histo) {

	var canvas = histo.canvas || 'histogram_canvas';
	var plotId = histo.plot_id || 'histogram_plot';
	var values = histo.values;
    var namedValues = histo.namedValues;

    var barClr = histo.bar_color || '#9A2EFE';
    var altBarClr = histo.alt_bar_color ||  '#C07CFE';
    var caption = histo.caption;


    if (!values || !values[0]) {
        values = this.extractValues(namedValues);

    }

    values = this.cleanData(values);

	var height = 300;
	var width  = 500;
	var pad    = {left:20, top:50, right:50, bottom: 50};
	var totalH = height + pad.top + pad.bottom;
	var totalW = width + pad.left + pad.right;

	uniqueValues = this.getUnique(values);

	var binNum;

	if ( uniqueValues.length > 9) {
	    binNum = 10;
	} else {
	    binNum = uniqueValues.length;
	}

	var xRange;
	var xMin;
	var xMax;

	if (binNum == 1) {
	    xRange = values[0];
	    xMin   = 0;
	    xMax   = d3.max(values);
	} else {
	    xRange = d3.max(values) -  d3.min(values);
	    xMin   = d3.min(values);
	    xMax   = d3.max(values);
	}

	var histogram = d3.layout.histogram()
            .bins(binNum)
        (values);

	var xAxisScale = d3.scale.linear()
            .domain([xMin, xMax])
            .range([0, width]);

	var yAxisScale = d3.scale.linear()
            .domain([0, d3.max(histogram, ( function (d) {return d.y;}) )])
            .range([0, height]);

   var tVals = d3.range(xMin, xMax, xRange / binNum);
    tVals.push(xMax)
	var xAxis = d3.svg.axis()
            .scale(xAxisScale)
            .orient("bottom")
            .tickValues(tVals);

	var yAxisLabel = d3.scale.linear()
            .domain([0, d3.max(histogram, ( function (d) {return d.y;}) )])
            .range([height, 0]);

	var yAxis = d3.svg.axis()
            .scale(yAxisLabel)
            .orient("left");

    var xLabel = histo.x_label || 'Values';
	var yLabel = histo.y_label || 'Frequency';

	var svg = d3.select(canvas)
            .append("svg")
            .attr("height", totalH)
            .attr("width", totalW);

    var tip = d3.tip().attr('class', 'd3-tip').html(function(d) {
        var binElem = [];
        var dMin = d3.min(d);
        var dMax = d3.max(d);

        namedValues.forEach(function(el, idx) {
            var ek = el[1];

           if ( ek >= dMin && ek <= dMax) {
               binElem.push(el);
           }
       });

    solGS.histogram.displayBinElements(binElem, canvas);

        return 'See below';
    });

    svg.call(tip)

	var histogramPlot = svg.append("g")
            .attr("id", plotId)
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
            .attr("x", function(d) { return 2*pad.left + xAxisScale(d.x); } )
            .attr("y", function(d) {return height - yAxisScale(d.y); })
            .attr("width", function(d) {return width / binNum; })
            .attr("height", function(d) { return yAxisScale(d.y); })
            .style("fill", barClr)
	        .style('stroke', "#ffffff")
            .on("mouseover", function(d) {
                tip.show(d);
                d3.select(this).style("fill", altBarClr);
            })
            .on("mouseout", function() {
                tip.hide();
                jQuery('.bin_elements').hide();
                d3.select(this).style("fill", barClr);
            });

	bar.append("text")
            .text(function(d) { return d.y; })
            .attr("y", function(d) {return height - (yAxisScale(d.y) + 10); } )
            .attr("x",  function(d) { return 2*pad.left + xAxisScale(d.x) + 0.05*width; } )
            .attr("dy", ".6em")
            .attr("text-anchor", "end")
            .attr("font-family", "sans-serif")
            .attr("font-size", "12px")
            .attr("fill", barClr)
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
            .attr("fill", barClr)
            .style({"text-anchor":"start", "fill": barClr});

	histogramPlot.append("g")
            .attr("class", "y axis")
            .attr("transform", "translate(" + 2* pad.left +  "," + 0 + ")")
            .call(yAxis)
            .selectAll("text")
            .attr("y", 0)
            .attr("x", -10)
            .attr("fill", barClr)
            .style("fill", barClr);

	histogramPlot.append("g")
            .attr("transform", "translate(" + (totalW * 0.5) + "," + (height + pad.bottom) + ")")
            .append("text")
            .text(xLabel)
            .attr("fill", barClr)
            .style("fill", barClr);

	histogramPlot.append("g")
            .attr("transform", "translate(" + 0 + "," + ( totalH*0.5) + ")")
            .append("text")
            .text(yLabel)
            .attr("fill", barClr)
            .style("fill", barClr)
            .attr("transform", "rotate(-90)");

    if (caption) {
        jQuery(canvas).append('<br/>' + caption);
    }
    },


}
//////
