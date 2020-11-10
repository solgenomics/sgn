/** 
* histogram plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

var solGS = solGS || function solGS () {};



solGS.histogram =  {

    getHistogram: function () {

	var params = this.getHistogramParams();

	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: params,
            url: '/histogram/phenotype/data/',
            success: function(response) {
		if (response.status == 'success') {
		    var traitValues = response.data;
		    var stat = response.stat;

		    traitValues = traitValues.map( function (d) {		   
			
			return  parseFloat(d[1]);
		    });	
		    
		    traitValues = traitValues.sort();
		    traitValues = traitValues.filter( function(val) {		   
			
			return !(val === "" 
				 || typeof val == "undefined" 
				 || val === null 
				 || isNaN(val) == true
				);
		    });

		    var obs = traitValues.length;
		    var uniqueValues = solGS.histogram.getUnique(traitValues);
		    
		    if (uniqueValues.length === 1) {
			jQuery("#histogram_message").html('<p> All of the valid observations ' 
							  + '('+ obs +') ' + 'in this dataset have '
							  + 'a value of ' + uniqueValues[0] 
							  + '. No frequency distribution plot.</p>'
							 );

		    } else {
			var args = {
			    'values' : traitValues,
			    'canvas' : 'trait_histogram_canvas',
			    'plot_id': 'trait_histogram_plot'
			};
			
			solGS.histogram.plotHistogram(args);
			
			jQuery("#histogram_message").empty();
			//solGS.histogram.descriptiveStat(stat);	
		    }
		} else {                
                    var errorMessage = "<p>This trait has no phenotype data to plot.</p>";
                    jQuery("#histogram_message").html(errorMessage);  
		}
		
            },
            error: function(response) {
		var errorMessage = "<p>Error occured plotting histogram for this trait dataset.</p>";
		jQuery("#histogram_message").html(errorMessage);                  
            }
	});
	
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

    getHistogramParams: function () {
	
	var traitId      = jQuery("#trait_id").val();    
	var population   = solGS.getPopulationDetails();
	var populationId = population.training_pop_id;
	var comboPopsId  = population.combo_pops_id;
	
	var params = { 
	    'trait_id'     : traitId,
	    'training_pop_id': populationId,
	    'combo_pops_id'  : comboPopsId
	};

	return params;
    },
    

    descriptiveStat: function (stat)  {
	
	var table = '<table style="margin-top: 40px;width:100%;text-align:left">';

	for (var i=0; i < stat.length; i++) {
	    
            if (stat[i]) {
		table += '<tr>';
		table += '<td>' + stat[i][0] + '</td>'  + '<td>' + stat[i][1] + '</td>';
		table += '</tr>';
            }
	}
	
	table += '</table>';

	jQuery("#trait_histogram_canvas").append(table);
	

    },


    plotHistogram: function (histo) {

	var canvas = histo.canvas || 'histogram_canvas';
	var plotId = histo.plot_id || 'histogram_plot';
	var values = histo.values;
	var xLabel = histo.x_label || 'Values';
	var yLabel = histo.y_label || 'Frequency';
	
	var height = 300;
	var width  = 500;
	var pad    = {left:20, top:50, right:40, bottom: 50}; 
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
	
	var xAxis = d3.svg.axis()
            .scale(xAxisScale)
            .orient("bottom")
            .tickValues(d3.range(xMin, 
				 xMax, 
				 0.1 * xRange)
                       );

	var yAxisLabel = d3.scale.linear()
            .domain([0, d3.max(histogram, ( function (d) {return d.y;}) )])
            .range([height, 0]);

	var yAxis = d3.svg.axis()
            .scale(yAxisLabel)
            .orient("left");

	var svg = d3.select("#" + canvas)
            .append("svg")
            .attr("height", totalH)
            .attr("width", totalW);
        
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
            .attr("width", function(d) {return 0.1*width; })
            .attr("height", function(d) { return yAxisScale(d.y); })
            .style("fill", "green")
	    .style('stroke', 'white')
            .on("mouseover", function(d) {
                d3.select(this).style("fill", "teal");
            })
            .on("mouseout", function() {
                d3.select(this).style("fill", "green");
            });
	
	bar.append("text")
            .text(function(d) { return d.y; })
            .attr("y", function(d) {return height - (yAxisScale(d.y) + 10); } )
            .attr("x",  function(d) { return 2*pad.left + xAxisScale(d.x) + 0.05*width; } )      
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
            .attr("transform", "translate(" + 2* pad.left +  "," + 0 + ")")
            .call(yAxis)
            .selectAll("text")
            .attr("y", 0)
            .attr("x", -10)
            .attr("fill", "green")
            .style("fill", "green");

	histogramPlot.append("g")
            .attr("transform", "translate(" + (totalW * 0.5) + "," + (height + pad.bottom) + ")")        
            .append("text")
            .text(xLabel)            
            .attr("fill", "teal")
            .style("fill", "teal");

	histogramPlot.append("g")
            .attr("transform", "translate(" + 0 + "," + ( totalH*0.5) + ")")        
            .append("text")
            .text(yLabel)            
            .attr("fill", "teal")
            .style("fill", "teal")
            .attr("transform", "rotate(-90)");	
    },   


//////    
}
//////


jQuery(document).ready(function () {

    solGS.histogram.getHistogram();

});
