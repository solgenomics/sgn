
//Pass an array of values e.g. ['1.01', '2', '500'] and the div_id for the div you want the histogram to appear in.

function plot_histogram(values, div_id) {

  var identical = identical_check(values);

  if (identical == true) {
      jQuery("#"+div_id).html("<center><h3>All "+values.length+" values were the same value of "+values[0]+".</h3></center>");
  }  else {

      // A formatter for counts.
      var formatCount = d3.format(",.0f");

      var div_width = document.getElementById(div_id).offsetWidth;

      var margin = {top: 10, right: 30, bottom: 30, left: 30},
      width = div_width - margin.left - margin.right,
      height = 200 - margin.top - margin.bottom;

      var x = d3.scale.linear()
      .domain([d3.min(values),d3.max(values)])
      .range([0, width]);

      // Generate a histogram using twenty uniformly-spaced bins.
      var data = d3.layout.histogram()
      .bins(x.ticks(20))
      (values);

      var y = d3.scale.linear()
      .domain([0, d3.max(data, function(d) { return d.y; })])
      .range([height, 0]);

      var xAxis = d3.svg.axis()
      .scale(x)
      .orient("bottom");

      var svg = d3.select("#"+div_id).append("svg")
      .attr("id", "svg_id")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("id", "g_id")
      .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

      var bar = svg.selectAll(".bar")
      .data(data)
      .enter().append("g")
      .attr("id", "g_id")
      .attr("class", "bar")
      .attr("transform", function(d) { return "translate(" + x(d.x) + "," + y(d.y) + ")"; });

      bar.append("rect")
      .attr("id", "rect_id")
      .attr("x", 1)
      .attr("width", (x.range()[1] - x.range()[0]) / 20 )
      .attr("height", function(d) { return height - y(d.y); });

      bar.append("text")
      .attr("id", "text_id")
      .attr("dy", ".75em")
      .attr("y", 6)
      .attr("x", ((x.range()[1] - x.range()[0]) / 20) / 2)
      .attr("text-anchor", "middle")
      .text(function(d) { return formatCount(d.y); });

      svg.append("g")
      .attr("id", "g_id")
      .attr("class", "x axis")
      .attr("transform", "translate(0," + height + ")")
      .call(xAxis);

  }
}

function identical_check(array) {
    for(var i = 0; i < array.length - 1; i++) {
        if(array[i] != array[i+1]) {
            return false;
        }
    }
    return true;
}
