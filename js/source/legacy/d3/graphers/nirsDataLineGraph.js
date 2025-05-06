(function(exports){
    //check, whether d3v4 is loaded !!
    var d3 = typeof d3v4 !== 'undefined' ? d3v4 : d3;
    if (typeof d3 === 'undefined') {
        throw new Error ("D3 is not loaded");
    }

    /*
    * Draw a line graph for repetitive trait values - for both the small and large graph !!.
    @param {Array} data -  an array of object, which contains both the 'value' and 'frequency' properties !!  
    @param {HTMLElement|String} container - the target where the graph should be drawn !!
    @param {Object} [layout] - (OPTIONAL) ab object that that holds all the dimensions properties including length, width, margin etc ... of the line graph !!
    @param {String} trait_name - the trait_name is used for the y-axis label !!
    @param {string} label_observation_unit_name - since, we have the repetitive values for unique obs_unit_name, therefore, using as the title of the graph !!
    @param {Object} [options] - (OPTIONAL) this is an object holds the properites related to graphs details - x- and y-axis labels, title, and data-points !!
    
    */

    exports.drawLineGraph = function(data, container, layout, trait_name, label_observation_unit_name, options) {
        // set the default layout for the large graph 
        layout = layout || {
            "width": 800,
            "height": 400,
            "margin": { "top": 20, "right": 30, "bottom": 100, "left": 80 }
        };

        options = options || {
            showXAxis: true,
            showYAxis: true,
            showDots: true,
            showTitle: true
        };

        var margin = layout.margin;
        var width = layout.width - margin.left - margin.right;
        var height = layout.height - margin.top - margin.bottom;

        // Clear any existing content
        d3.select(container).html('');

        // Create SVG container
        var svg = d3.select(container)
            .append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .append("g")
                .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

        // Set the x-axis scale
        var xExtent = d3.extent(data, function(d) { return d.frequency; });
        var xPadding = 0.05 * (xExtent[1] - xExtent[0]);
        var x = d3.scaleLinear()
        .domain([
            d3.timeMillisecond.offset(xExtent[0], -xPadding),
            d3.timeMillisecond.offset(xExtent[1], xPadding)
        ])
        .range([0, width]);

        // Set the y-axis scale
        var y = d3.scaleLinear()
            .domain([d3.min(data, function(d) { return d.value; }), d3.max(data, function(d) {return d.value; })])
            .nice()
            .range([height, 0]);

        // add the x-axis
        if (options.showXAxis) {
            svg.append("g")
            .attr("transform", "translate(0," + height + ")")
            .call(d3.axisBottom(x))
            //.tickFormat(d3.timeFormat("%Y-%m-%d")))
            .selectAll("text")
            .attr("transform", "rotate(-45)") //the labels will be at 45 degree angle because of the space !!
            .style("text-anchor", "end");
        }

        // Add y-axis
        if (options.showYAxis) {
            svg.append("g")
                .call(d3.axisLeft(y));
        }

        var line = d3.line()
            .x(function(d) {return x(d.frequency); })
            .y(function(d) {return y(d.value); })
            .curve(d3.curveMonotoneX); //this will make the line 

        // Draw line path
        svg.append("path")
            .datum(data)
            .attr("fill", "none")
            .attr("stroke", "steelblue")
            .attr("stroke-width", 2)
            .attr("d", line);

        var tooltip = d3.select("body").append("div")
            .attr("class", "tooltip")
            .style("position", "absolute")
            .style("background-color", "#fff")
            .style("border", "1px solid #ccc")
            .style("padding", "5px")
            .style("z-index", 9999)
            .style("opacity", 0);
        if (options.showDots) {
            var dotsGroup = svg.selectAll("g.dot-group")
                .data(data)
                .enter()
                .append("g")
                  .attr("class", "dot-group");

            // The visible circle (red, radius=4)
            dotsGroup
                .append("circle")
                  .attr("cx", function(d) { return x(d.frequency); })
                  .attr("cy", function(d) { return y(d.value); })
                  .attr("r", 4)
                  .attr("fill", "red");

            // The invisible circle (bigger radius) to capture hover events
            dotsGroup
            .append("circle")
                .attr("cx", function(d) { return x(d.frequency); })
                .attr("cy", function(d) { return y(d.value); })
                .attr("r", 10)                        // bigger radius
                .style("fill", "none")
                .style("pointer-events", "all")       // ensure it can receive events
                .on("mouseover", function(d) {
                var e = d3.event;
                tooltip
                    .html(
                        "<strong>Value:</strong> " + d.value + "<br/>" +
                        "<strong>Frequency:</strong> " + d.frequency
                    )
                    .style("left", (e.pageX + 10) + "px")
                    .style("top",  (e.pageY - 25) + "px")
                    .style("opacity", 1);
                })
                .on("mousemove", function() {
                    var e = d3.event;
                    tooltip
                      .style("left", (e.pageX + 10) + "px")
                      .style("top",  (e.pageY - 25) + "px");
                })
                .on("mouseout", function() {
                    tooltip.style("opacity", 0);
                });
        }

        // add the attributes to the x- and y-axis
        if (options.showXAxis) {
            svg.append("text")
            .attr("x", width / 2)
            .attr("y", height + margin.bottom - 10)
            .attr("text-anchor", "middle")
            .style("font-size", "12px")
            .text("Frequency");
        }

        if (options.showYAxis) {
            svg.append("text")
            .attr("transform", "rotate(-90)")
            .attr("x", -height / 2)
            .attr("y", -margin.left + 20)
            .attr("text-anchor", "middle")
            .style("font-size", "12px")
            .text(trait_name);
        }

        if(options.showTitle) {
            svg.append("text")
            .attr("x", width / 2)
            .attr("y", 0 - (margin.top / 4))
            .attr("text-anchor", "middle")
            .style("font-size", "16px")
            //.style("text-decoration", "underline")
            .text(label_observation_unit_name);
        }

    };

    /*
    exports.drawLineGraph = function drawMultiLineGraph(datasets, selector, xLabel, yLabel, title, options) {
        const margin = { top: 60, right: 100, bottom: 50, left: 60 };
        const width = 900 - margin.left - margin.right;
        const height = 400 - margin.top - margin.bottom;
    };
    */
}(typeof exports === 'undefined' ? this.nirsDataLineGraph = {} : exports));
