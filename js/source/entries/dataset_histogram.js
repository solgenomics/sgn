export function init() {
    class Dataset {
        constructor() {
            this.datasets = {};
            this.data = [];
            this.outliers = [];
            this.firstRefresh = true;
            this.stdDevMultiplier = Number;
            this.selection = "default";
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
        
        addEventListeners() {
          let LocalThis = this;
          let stdDevMultiplier = 1;
          var slider = document.getElementById("myRange");
          slider.oninput = function() {
            LocalThis.stdDevMultiplier = this.value;
            d3.select("svg").remove();
            LocalThis.firstRefresh = false;
            LocalThis.render();
          }
        
          let selection = document.getElementById("dataset_selection");
          selection.addEventListener("change", (event) => {
            d3.select("svg").remove();
            LocalThis.selection = event.target.value;
            LocalThis.render(); 
          });

          let downloadOutliersButton = document.getElementById("download_outliers");
          downloadOutliersButton.onclick = function() {
            let csv = 'outliers\n' + LocalThis.outliers.map((outlier) => outlier + '\n');
            var hiddenElement = document.createElement('a');
            hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csv);
            hiddenElement.target = '_blank';
            hiddenElement.download = `test.csv`;
            hiddenElement.click();    
          }


        }

        // getDatasets() {
        //   const endpoint = '/ajax/dataset/get';
        // }

        render() {
          if (this.firstRefresh) {
            this.addEventListeners();   
          };
          console.log(this.selection);
          const LocalThis = this;


          var margin = {top: 10, right: 30, bottom: 30, left: 60},
              width = 1170 - margin.left - margin.right,
              height = 600 - margin.top - margin.bottom;
          
          var svg = d3.select("#trait_graph")
            .append("svg")
              .attr("width", width + margin.left + margin.right)
              .attr("height", height + margin.top + margin.bottom)
            .append("g")
              .attr("transform",
                    "translate(" + margin.left + "," + margin.top + ")");

          var isOutlier = function(d, mean, stdDev) {
              let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
              if (d.value >= mean - stdDev * filter && d.value <= mean + stdDev * filter) {
                return "green";
              } else {
                LocalThis.outliers.push(d.unit);
                return "red";
              }
          }
          
          //Read the data
          const data = [];
          for (let i = 0; i < 40; i++) {
            data.push({ unit: 5 * String(i+1), value: 100 * Math.random()})
          }
          data.push({unit: 100, value: 148});

          const data2 = [];
          for (let i = 0; i < 40; i++) {
            data2.push({ unit: 5 * String(i+1), value: 100 * Math.random()})
          }
          data2.push({unit: 100, value: 148});

          const data3 = [];
          for (let i = 0; i < 40; i++) {
            data3.push({ unit: 5 * String(i+1), value: 100 * Math.random()})
          }
          data3.push({unit: 100, value: 148});

          if (this.firstRefresh) {
            this.datasets["dataset_1"] = data;
            this.datasets["dataset_2"] = data2;
            this.datasets["dataset_3"] = data3;
          }
          
          switch(this.selection) {
            case "dataset_1":
              this.data = this.datasets['dataset_1'];
              break;
            case "dataset_2":
              this.data = this.datasets['dataset_2'];
              break;
            case "dataset_3":
              this.data = this.datasets['dataset_3'];
            default:
              break;
          }
          
      
          let unitVals = [];
          for (let point of this.data) {
              unitVals.push(point.value);
          }

          const [mean, stdDev] = this.standardDeviation(unitVals);
          this.outliers = [];
          // Add X axis
          var x = d3.scaleLinear()
          .domain([0, 200])
          .range([ 0, width]);
          svg.append("g")
          .style("font", "18px times")
          .attr("transform", "translate(0," + height + ")")
          .call(d3.axisBottom(x));
      
          // Add Y axis
          var y = d3.scaleLinear()
          .domain([0, 150])
          .range([ height, 0]);
          svg.append("g")
          .style("font", "18px times")
          .call(d3.axisLeft(y))
      
          // Add dots
          svg.append('g')
          .selectAll("dot")
          .data(LocalThis.data)
          .enter()
          .append("circle")
              .attr("cx", function (d) { return x(d.unit); } )
              .attr("cy", function (d) { return y(d.value); } )
              .attr("r", 7)
              .style("fill", function(d) {return isOutlier(d, mean, stdDev)})
      
        }
    }
    const dataset = new Dataset;    
    return dataset;
}