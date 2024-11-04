(function(exports){
    //check, whether d3v4 is loaded !!
    var d3 = typeof d3v4 !== 'undefined' ? d3v4 : d3;
    if (typeof d3 === 'undefined') {
        throw new Error ("D3 is not loaded");
    }

    /*

    * Draw a line graph for repetitive trait values - for both the small and large graph !!.
    @param {Array} data -  an array of object, which contains both the 'value' and 'date' properties !!  
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
            "margin": { "top": 20, "right": 30, "bottom": 100, "left": 70 }
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

        // Parse the date strings into Date objects
        data.forEach(d => {
            d.date = new Date(d.date);
            d.value = +d.value;
        });

        // sort the datA BY date in ascending order  
        data.sort((a, b) => d3.ascending(a.date, b.date));

        // Set the x-axis scale
        var xExtent = d3.extent(data, d => d.date);
        var xPadding = 0.05 * (xExtent[1] - xExtent[0]);
        var x = d3.scaleTime()
        .domain([
            d3.timeMillisecond.offset(xExtent[0], -xPadding),
            d3.timeMillisecond.offset(xExtent[1], xPadding)
        ])
        .range([0, width]);

        // Set the y-axis scale
        var y = d3.scaleLinear()
            .domain([d3.min(data, d => d.value), d3.max(data, d => d.value)])
            .nice()
            .range([height, 0]);

        // add the x-axis
        if (options.showXAxis) {
            svg.append("g")
            .attr("transform", "translate(0," + height + ")")
            .call(d3.axisBottom(x)
            .tickFormat(d3.timeFormat("%Y-%m-%d")))
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
            .x(d => x(d.date))
            .y(d => y(d.value))
            .curve(d3.curveMonotoneX); //this will make the line 

        // Draw line path
        svg.append("path")
            .datum(data)
            .attr("fill", "none")
            .attr("stroke", "steelblue")
            .attr("stroke-width", 2)
            .attr("d", line);

        // highlight the data points with dots 
        if (options.showDots) {
            svg.selectAll("dot")
                .data(data)
                .enter()
                .append("circle")
                .attr("cx", d => x(d.date))
                .attr("cy", d => y(d.value))
                .attr("r", 4)
                .attr("fill", "red")
                .on("mouseover", function(event, d) {
                    //console.log('chek mouseover is working as it supposed to be:', d);
                    // Show tooltip with date + value
                    var tooltip = d3.select("body").append("div")
                        .attr("class", "tooltip")
                        .style("position", "absolute")
                        .style("background-color", "#fff")
                        .style("border", "1px solid #ccc")
                        .style("padding", "5px")
                        .html(`<strong>Date:</strong> ${d3.timeFormat("%Y-%m-%d")(d.date)}<br><strong>Value:</strong> ${d.value}`)
                        .style("left", (event.pageX + 10) + "px")
                        .style("top", (event.pageY - 25) + "px");
                })
                .on("mouseout", function() {
                    //console.log('check mouseout is working as it supposed to be:', d);
                    d3.select(".tooltip").remove();
                });
        }

        // add the attributes to the x- and y-axis
        if (options.showXAxis) {
            svg.append("text")
            .attr("x", width / 2)
            .attr("y", height + margin.bottom - 10)
            .attr("text-anchor", "middle")
            .style("font-size", "12px")
            .text("Collect Date");
        }
 
        if (options.showYAxis) {
            svg.append("text")
            .attr("transform", "rotate(-90)")
            .attr("x", -height / 2)
            .attr("y", -margin.left + 15)
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

}(typeof exports === 'undefined' ? this.lineGraphRepetitiveValues = {} : exports));