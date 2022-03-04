export function init() {
    class Dataset {
        constructor() {
            this.dataset = [];
        }

        render() {
            // set the dimensions and margins of the graph
            var margin = {top: 30, right: 30, bottom: 70, left: 60},
                width = 460 - margin.left - margin.right,
                height = 400 - margin.top - margin.bottom;

            // append the svg object to the body of the page
            var svg = d3.select("#trait_histogram")
            .append("svg")
                .attr("width", width + margin.left + margin.right)
                .attr("height", height + margin.top + margin.bottom)
            .append("g")
                .attr("transform",
                    "translate(" + margin.left + "," + margin.top + ")");

            // Parse the Data
            // d3.csv("https://raw.githubusercontent.com/holtzy/data_to_viz/master/Example_dataset/7_OneCatOneNum_header.csv", function(data) {
            let data = [{Trait: "Orange", Value: 4000}, {Trait: "Blue", Value: 12000 }, {Trait: "Green", Value: 7000}, {Trait: "Yellow", Value: 1700}];
            // sort data
                // data.sort(function(b, a) {
                //     return a.Value - b.Value;
                // });

                // X axis
                var x = d3.scaleBand()
                    .range([ 0, width ])
                    .domain(data.map(function(d) { return d.Trait; }))
                    .padding(0.2);
                svg.append("g")
                    .attr("transform", "translate(0," + height + ")")
                    .call(d3.axisBottom(x))
                    .selectAll("text")
                    .attr("transform", "translate(-10,0)rotate(-45)")
                    .style("text-anchor", "end");

                // Add Y axis
                var y = d3.scaleLinear()
                    .domain([0, 13000])
                    .range([ height, 0]);
                svg.append("g")
                    .call(d3.axisLeft(y));

                // Bars
                svg.selectAll("mybar")
                    .data(data)
                    .enter()
                    .append("rect")
                    .attr("x", function(d) { return x(d.Trait); })
                    .attr("y", function(d) { return y(d.Value); })
                    .attr("width", x.bandwidth())
                    .attr("height", function(d) { return height - y(d.Value); })
                    .attr("fill", "#69b3a2")

            
        }
    }
    const dataset = new Dataset;    
    return dataset;
}