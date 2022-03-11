export function init() {
    class Dataset {
        constructor() {
            this.dataset = [];
            this.stdDevMultiplier = 1;
        }


        standardDeviation(values){
            function average(data){
                var sum = data.reduce(function(sum, value){
                  return sum + value;
                }, 0);
                            
                var avg = sum / data.length;
                return avg;
              }
            
            var avg = average(values);
            
            var squareDiffs = values.map(function(value){
              var diff = value - avg;
              var sqrDiff = diff * diff;
              return sqrDiff;
            });
            
            var avgSquareDiff = average(squareDiffs);
          
            var stdDev = Math.sqrt(avgSquareDiff);
            return [avg, stdDev];
        }
        
        slider() {
          let LocalThis = this;
          let stdDevMultiplier = 1;
          var slider = document.getElementById("myRange");
          slider.oninput = function() {
            LocalThis.stdDevMultiplier = this.value;
            d3.select("svg").remove();
            LocalThis.render();
          } 
        }

        render() {
          const LocalThis = this;
          this.slider();
          console.log(this.stdDevMultiplier);

          var margin = {top: 10, right: 30, bottom: 30, left: 60},
              width = 1170 - margin.left - margin.right,
              height = 620 - margin.top - margin.bottom;
          
          var svg = d3.select("#trait_graph")
            .append("svg")
              .attr("width", width + margin.left + margin.right)
              .attr("height", height + margin.top + margin.bottom)
            .append("g")
              .attr("transform",
                    "translate(" + margin.left + "," + margin.top + ")");

          var isOutlier = function(d) {
              let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;

              return d.value >= mean - stdDev * filter && d.value <= mean + stdDev * filter ? "green" : "red";
          }
          
          //Read the data
          const data = [
              {observationUnit: "One", xVal: 0, value: 10}, {observatioUnit: "Two", xVal: 5, value: 15}, {observationUnit: "Three", xVal: 10, value: 20}, {observationUnit: "Four", xVal: 15, value: 25}, {observationUnit: "Five", xVal: 20, value: 30},
              {observationUnit: "Six", xVal: 25, value: 35}, {observatioUnit: "Seven", xVal: 30, value: 40}, {observationUnit: "Eight", xVal: 35,value: 22}, {observationUnit: "Nine", xVal: 40, value: 24}, {observationUnit: "Ten", xVal: 45, value: 11},
              {observationUnit: "Eleven", xVal: 50, value: 3}, {observatioUnit: "Twelve", xVal: 55, value: 29}, {observationUnit: "Thirteen", xVal: 60, value: 16}, {observationUnit: "Fourteen", xVal: 65, value: 25}, {observationUnit: "Fifteen", xVal: 70, value: 23},
              {observationUnit: "Sixteen", xVal: 75, value: 43}, {observatioUnit: "Seventeen", xVal: 80, value: 19}, {observationUnit: "Eighteen", xVal: 85, value: 2}, {observationUnit: "Nineteen", xVal: 90, value: 42}, {observationUnit: "Twenty", xVal: 95, value: 31},
              {observationUnit: "Sixteen", xVal: 100, value: 18}, {observatioUnit: "Seventeen", xVal: 105, value: 26}, {observationUnit: "Eighteen", xVal: 110, value: 38}, {observationUnit: "Nineteen", xVal: 115, value: 12}, {observationUnit: "Twenty", xVal: 120, value: 25},
              {observationUnit: "Sixteen", xVal: 125, value: 9}, {observatioUnit: "Seventeen", xVal: 130, value: 6}, {observationUnit: "Eighteen", xVal: 135, value: 11}, {observationUnit: "Nineteen", xVal: 140, value: 35}, {observationUnit: "Twenty", xVal: 145, value: 40},
              {observationUnit: "Sixteen", xVal: 150, value: 26}, {observatioUnit: "Seventeen", xVal: 155, value: 34}, {observationUnit: "Eighteen", xVal: 160, value: 3}, {observationUnit: "Nineteen", xVal: 165, value: 32}, {observationUnit: "Twenty", xVal: 170, value: 2},
              {observationUnit: "Sixteen", xVal: 175, value: 21}, {observatioUnit: "Seventeen", xVal: 180, value: 19}, {observationUnit: "Eighteen", xVal: 185, value: 43}, {observationUnit: "Nineteen", xVal: 190, value: 16}, {observationUnit: "Twenty", xVal: 195, value: 17},



          ]
      
          let traitVals = [];
          for (let point of data) {
              traitVals.push(point.value);
          }

          const [mean, stdDev] = this.standardDeviation(traitVals)

          // Add X axis
          var x = d3.scaleLinear()
          .domain([0, 200])
          .range([ 0, width ]);
          svg.append("g")
          .style("font", "18px times")
          .attr("transform", "translate(0," + height + ")")
          .call(d3.axisBottom(x));
      
          // Add Y axis
          var y = d3.scaleLinear()
          .domain([0, 50])
          .range([ height, 0]);
          svg.append("g")
          .style("font", "18px times")
          .call(d3.axisLeft(y));
      
          // Add dots
          svg.append('g')
          .selectAll("dot")
          .data(data)
          .enter()
          .append("circle")
              .attr("cx", function (d) { return x(d.xVal); } )
              .attr("cy", function (d) { return y(d.value); } )
              .attr("r", 7)
              .style("fill", function(d) {return isOutlier(d)})
      
        }
    }
    const dataset = new Dataset;    
    return dataset;
}