export function init(dataset_id) {
    class Dataset {
        constructor() {
            this.datasets = {};
            this.data = [];
            this.outliers = [];
            this.firstRefresh = true;
            this.stdDevMultiplier = document.getElementById("myRange").value;
            this.selection = "default";
            this.dataset_id = dataset_id;
            this.phenotypes = {};
            this.traits = {};
            this.xAxisData = [];
            this.yAxisData = [];
        }

        getPhenotypes() {
          const LocalThis = this;
          this.firstRefresh = false;
          new jQuery.ajax({
            url: '/ajax/dataset/retrieve/' + this.dataset_id + '/phenotypes/',
            success: function(response) {
              LocalThis.phenotypes = response.phenotypes;
              LocalThis.setDropDownTraits();
            },
            error: function(response) {
              alert('Error');
            }
            
            
          })
        }

        setDropDownTraits() {
          const phenotypes = this.phenotypes;
          const keys = phenotypes[0];
          this.traits[keys[39]] = {};
          this.traits[keys[40]] = {};
          this.traits[keys[41]] = {};

          // Construct trait object
          for (let i = 1; i < phenotypes.length; i++) {
            this.traits[keys[39]][phenotypes[i][25]] = phenotypes[i][39];
            this.traits[keys[40]][phenotypes[i][25]] = phenotypes[i][40];
            this.traits[keys[41]][phenotypes[i][25]] = phenotypes[i][41];
          }

          // Use traits to set select options
          const select = document.getElementById("trait_selection");
          for (const traitName of Object.keys(this.traits)) {
            const option = document.createElement("option");
            option.value = traitName;
            option.innerHTML = traitName;
            select.appendChild(option);
          }

        }

        setData() {
          this.xAxisData = Object.keys(this.traits[this.selection]).filter((plotNumber) => this.traits[this.selection][plotNumber] != null);
          this.yAxisData = Object.values(this.traits[this.selection]).filter((value) => value != null).map(string => parseInt(string));
          this.yAxisData.sort((a,b) => a - b);
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
          
          // Handle Slider Events
          var slider = document.getElementById("myRange");
          slider.oninput = function() {
            LocalThis.stdDevMultiplier = this.value;
            d3.select("svg").remove();
            LocalThis.render();
          }
          
          // Handle Select Events
          let selection = document.getElementById("trait_selection");
          selection.addEventListener("change", (event) => {
            d3.select("svg").remove();
            LocalThis.selection = event.target.value;
            LocalThis.setData();
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

        render() {
          if (this.firstRefresh) {
            this.getPhenotypes();
            this.addEventListeners();
          };
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

          var isOutlier = function(unit, value, mean, stdDev) {
              let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
              if (value >= mean - stdDev * filter && value <= mean + stdDev * filter) {
                return "green";
              } else {
                LocalThis.outliers.push(unit);
                return "red";
              }
          }
          
          //Read the data
          // const data = [];
          // for (let i = 0; i < 40; i++) {
          //   data.push({ unit: 5 * String(i+1), value: 100 * Math.random()})
          // }
          // data.push({unit: 100, value: 148});

          // const data2 = [];
          // for (let i = 0; i < 40; i++) {
          //   data2.push({ unit: 5 * String(i+1), value: 100 * Math.random()})
          // }
          // data2.push({unit: 100, value: 148});

          // const data3 = [];
          // for (let i = 0; i < 40; i++) {
          //   data3.push({ unit: 5 * String(i+1), value: 100 * Math.random()})
          // }
          // data3.push({unit: 100, value: 148});

          // if (this.firstRefresh) {
          //   this.datasets["dataset_1"] = data;
          //   this.datasets["dataset_2"] = data2;
          //   this.datasets["dataset_3"] = data3;
          // }
          
          // switch(this.selection) {
          //   case "dataset_1":
          //     this.data = this.datasets['dataset_1'];
          //     break;
          //   case "dataset_2":
          //     this.data = this.datasets['dataset_2'];
          //     break;
          //   case "dataset_3":
          //     this.data = this.datasets['dataset_3'];
          //   default:
          //     break;
          // }
          
      
          // let unitVals = [];
          // for (let point of this.data) {
          //     unitVals.push(point.value);
          // }
          console.log(this.xAxisData);
          console.log(this.yAxisData);
          
          const [mean, stdDev] = this.standardDeviation(this.yAxisData);
          this.outliers = [];
          // Add X axis
          var x = d3.scaleLinear()
          .domain([0, this.xAxisData.length])
          .range([ 0, width]);
          svg.append("g")
          .style("font", "18px times")
          .attr("transform", "translate(0," + height + ")")
          .call(d3.axisBottom(x));
      
          // Add Y axis
          var y = d3.scaleLinear()
          .domain([Math.min(...this.yAxisData), Math.max(...this.yAxisData)])
          .range([ height, 0]);
          svg.append("g")
          .style("font", "18px times")
          .call(d3.axisLeft(y))
      
          // Add dots
          if (this.selection != null) {
            svg.append('g')
            .selectAll("dot")
            .data([...Array(this.xAxisData.length).keys()])
            .enter()
            .append("circle")
              .attr("cx", function (d) { return x(d); } )
              .attr("cy", function (d) { return y(LocalThis.yAxisData[d]); } )
              .attr("r", 4)
              .style("fill", function(d) {return isOutlier(LocalThis.xAxisData[d], LocalThis.yAxisData[d], mean, stdDev)})
        
          }
          
        }
    }
    const dataset = new Dataset;    
    return dataset;
}