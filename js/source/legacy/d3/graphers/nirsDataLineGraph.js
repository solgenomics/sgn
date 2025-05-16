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

    var currentYMax = null;

    exports.drawMultiLineGraph = function(datasets, selector, xLabel, yLabel, title, options) {
        const margin = { top: 60, right: 100, bottom: 50, left: 60 };
        const width = 970 - margin.left - margin.right;
        const height = 500 - margin.top - margin.bottom;

        d3.select(selector).select("svg").remove();

        const svg = d3.select(selector)
            .append("svg")
            .attr("width", width + margin.left + margin.right)
            .attr("height", height + margin.top + margin.bottom)
            .style("background-color", "#fff")
            .append("g")
            .attr("transform", `translate(${margin.left},${margin.top})`);

        //Flatten all data to get global x and y domains
        const allPoints = datasets.flatMap(d => d.data);
        const xExtent = d3.extent(allPoints, d => d.frequency);
        const yMax = d3.max(allPoints, d => d.value);

        if (currentYMax == null || yMax > currentYMax) {
            currentYMax = yMax;
        }

        // Scales
        const x = d3.scaleLinear().domain(xExtent).range([0, width]);
        const y = d3.scaleLinear().domain([0, currentYMax]).range([height, 0]);

        //Axes
        if (options.showXAxis !== false) {
            svg.append("g")
                .attr("transform", `translate(0, ${height})`)
                .call(d3.axisBottom(x));
        }

        if (options.showYAxis !== false) {
            svg.append("g")
                .call(d3.axisLeft(y));
        }
        // Axis labels
        if (xLabel) {
            svg.append("text")
                .attr("text-anchor", "end")
                .attr("x", width / 2 + margin.left)
                .attr("y", height + margin.bottom - 5)
                .text(xLabel)
                .style("font-size", "12px");
        }

        if (yLabel) {
            svg.append("text")
                .attr("text-anchor", "end")
                .attr("transform", "rotate(-90)")
                .attr("x", -height / 2)
                .attr("y", -margin.left + 15)
                .text(yLabel)
                .style("font-size", "12px");
        }

        //Title
        if (options.showTitle !== false && title) {
            svg.append("text")
                .attr("x", width / 2)
                .attr("y", -20)
                .attr("text-anchor", "middle")
                .style("font-size", "16px")
                .style("font-weight", "bold")
                .text(title);
        }

        const color = d3.scaleOrdinal(d3.schemeCategory10);

        const line = d3.line()
            .x(function(d) {return x(d.frequency); })
            .y(function(d) {return y(d.value); })
            .curve(d3.curveMonotoneX);

        const tooltip2 = d3.select("body").append("div")
                    .attr("class", "tooltip2")
                    .style("position", "absolute")
                    .style("background-color", "#fff")
                    .style("border", "1px solid #ccc")
                    .style("padding", "5px")
                    .style("z-index", 9999)
                    .style("opacity", 0);

        let added_lines = [];
        datasets.forEach((dataset, i) => {
            if (!added_lines.includes(dataset.label)) {
                svg.append("path")
                    .datum(dataset.data)
                    .attr("fill", "none")
                    .attr("stroke-width", 2)
                    .attr("stroke", color(i))
                    .attr("d", line)
                    .attr("class", "data-line")
                    .attr("data-label", dataset.label);

                svg.selectAll(`.dot-${i}`)
                    .data(dataset.data)
                    .enter()
                    .append("circle")
                    .attr("class", `dot dot-${i}`)
                    .attr("cx", function(d) { return x(d.frequency); })
                    .attr("cy", function(d) { return y(d.value); })
                    .attr("r", 4)
                    .attr("fill", color(i))
                    .style("pointer-events", "all")
                    .style("opacity", 0);

                const currentLabel = dataset.label;
                
                svg.append("g")
                    .selectAll("circle")
                    .data(dataset.data)
                    .enter()
                    .append("circle")
                    .attr("class", `hover-dot hover-dot-${i}`)
                    .attr("cx", function(d) { return x(d.frequency); })
                    .attr("cy", function(d) { return y(d.value); })
                    .attr("r", 10)
                    .style("fill", "transparent")
                    .style("pointer-events", "all")
                    .on("mouseover", function(d) {
                        var e = d3.event;
                        d3.selectAll(".data-line").style("opacity", 0.2);
                        d3.select(`.data-line[data-label ='${currentLabel}']`)
                            .style("stroke-width", 3)
                            .style("opacity", 1);
                        
                        d3.selectAll(".legend-text").style("opacity", 0.3);
                        d3.select(`.legend-text[data-label ='${currentLabel}']`)
                            .style("font-weight", "bold")
                            .style("opacity", 1);

                        d3.selectAll(".legend-color").style("opacity", 0.3);
                        d3.select(`.legend-color[data-label ='${currentLabel}']`)
                            .style("font-weight", "bold")
                            .style("opacity", 1);

                        d3.selectAll(".dot").style("opacity", 0);
                        d3.selectAll(`.dot-${i}`).style("opacity", 1);

                        tooltip2
                            .html(
                                "<strong>Sample:<strong> " + dataset.label + "<br/>" +
                                "<strong>Value:</strong> " + d.value + "<br/>" +
                                "<strong>Frequency:</strong> " + d.frequency
                            )
                            .style("left", (e.clientX + 10) + "px")
                            .style("top",  (e.clientY - 25 + window.scrollY) + "px")
                            .style("opacity", 1);
                    })
                    .on("mousemove", function() {
                        var e = d3.event;
                        tooltip2
                            .style("left", (e.pageX + 10) + "px")
                            .style("top", (e.pageY - 25) + "px");
                    })
                    .on("mouseleave", function() {
                        d3.selectAll(".data-line").style("opacity", 1).style("stroke-width", 2);
                        d3.selectAll(".legend-text").style("opacity", 1).style("font-weight", "normal");
                        d3.selectAll(".legend-color").style("opacity", 1);
                        d3.selectAll(".dot").style("opacity", 0);

                        tooltip2.style("opacity", 0);
                    });
            
                added_lines.push(dataset.label);
            }
        });

        const legend = svg.append("g")
            .attr("transform", `translate(${width + 1}, 0)`);

        let added_samples = [];
        datasets.forEach((dataset, i) => {
            if (!added_samples.includes(dataset.label)) {
                legend.append("rect")
                    .attr("x", 0)
                    .attr("y", i * 20)
                    .attr("width", 10)
                    .attr("height", 10)
                    .attr("fill", color(i))
                    .attr("cursor", "pointer")
                    .attr("data-label", dataset.label)
                    .attr("class", "legend-color");

                legend.append("text")
                    .attr("x", 15)
                    .attr("y", i * 20 + 9)
                    .text(dataset.label || `Sample ${i + 1}`)
                    .style("font-size", "12px")
                    .attr("alignment-baseline", "middle")
                    .attr("data-label", dataset.label)
                    .attr("class", "legend-text");

                added_samples.push(dataset.label);
            }
        });
    };

    exports.clearGraph = function(selector) {
        const svg = d3.select(selector).select("svg");
        
        svg.selectAll(".data-line").remove();
        svg.selectAll("circle").remove();
        svg.selectAll(".legend-text").remove();
        svg.selectAll(".legend-color").remove();
    };
    
}(typeof exports === 'undefined' ? this.nirsDataLineGraph = {} : exports));
