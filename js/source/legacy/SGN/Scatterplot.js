// var data = [
//     {
//         "label": "Dairy Milk",
//         "type": "cadbury",
//         "x_pos": 45,
//         "y_pos": 2
//     }, {
//         "label": "Galaxy",
//         "type": "Nestle",
//         "x_pos": 42,
//         "y_pos": 3
//     }
// ];


function SGND3ScatterPlot(data, div_id, x_label) {
    //console.log(data);
    var margins = {
        "left": 40,
        "right": 30,
        "top": 30,
        "bottom": 30
    };

    var width = 500;
    var height = 500;
    var colors = d3.scale.category10();

    var svg = d3.select("#"+div_id).append("svg").attr("width", width).attr("height", height).append("g")
        .attr("transform", "translate(" + margins.left + "," + margins.top + ")");

    var x = d3.scale.linear()
        .domain(d3.extent(data, function (d) {
        return d.x_pos;
    }))
        .range([0, width - margins.left - margins.right]);

    var y = d3.scale.linear()
        .domain(d3.extent(data, function (d) {
        return d.y_pos;
    }))
    .range([height - margins.top - margins.bottom, 0]);

    svg.append("g").attr("class", "x axis").attr("transform", "translate(0," + y.range()[0] + ")");
    svg.append("g").attr("class", "y axis");

    svg.append("text")
        .attr("fill", "#414241")
        .attr("text-anchor", "end")
        .attr("x", width / 2)
        .attr("y", height - 35)
        .text(x_label);

    var xAxis = d3.svg.axis().scale(x).orient("bottom").tickPadding(2);
    var yAxis = d3.svg.axis().scale(y).orient("left").tickPadding(2);

    svg.selectAll("g.y.axis").call(yAxis);
    svg.selectAll("g.x.axis").call(xAxis);

    var valInd = svg.selectAll("g.node").data(data, function (d) {
        return d.label;
    });

    var valGroup = valInd.enter().append("g").attr("class", "node")
    .attr('transform', function (d) {
        return "translate(" + x(d.x_pos) + "," + y(d.y_pos) + ")";
    });

    valGroup.append("circle")
        .attr("r", 5)
        .attr("class", "dot")
        .style("fill", function (d) {
            return colors(d.type);
    });

    valGroup.append("text")
        .style("text-anchor", "middle")
        .attr("dy", -10)
        .text(function (d) {
            return d.label;
    });
}

