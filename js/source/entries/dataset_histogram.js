export function init(dataset_id) {
    class Dataset {
        constructor() {
            this.datasets = {};
            this.data = [];
            // store phenotype id, trait, value
            this.outliers = [];
            this.firstRefresh = true;
            this.stdDevMultiplier = document.getElementById("myRange").value;
            this.selection = "default";
            this.dataset_id = dataset_id;
            this.observations = {};
            this.traits = {};
            this.phenoIds = [];
            this.traitVals
            // this.xAxisData = [];
            // this.yAxisData = [];
        }

        getPhenotypes() {
          const LocalThis = this;
          this.firstRefresh = false;
          new jQuery.ajax({
            url: '/ajax/dataset/retrieve/' + this.dataset_id + '/phenotypes?include_phenotype_primary_key=1',
            success: function(response) {
              console.log(response);
              LocalThis.observations = response.phenotypes;
              LocalThis.setDropDownTraits();
            },
            error: function(response) {
              alert('Error');
            }
            
            
          })
        }

        setDropDownTraits() {
          const keys = this.observations[0];
          // Construct trait object
          for (let i = 39; i < keys.length - 1; i++) {
            if (i % 2 == 1 && i <= keys.length - 2) {
              this.traits[keys[i]] = {};
            }
          }

          for (let i = 1; i < this.observations.length; i++) {
            // Goes through each observation, and populates the traits hash with each trait, using the phenotype id as the key, and the traitValue as the value.
            for (let j = 39; j < this.observations[i].length - 1; j++) {
              if (j % 2 == 1) {
                this.traits[keys[j]][this.observations[i][j+1]] = this.observations[i][j];
              }
            }
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
          // Gets a list of pheno ids, filters them so only the ones that have non null values are included and then sorts the ids by their value by looking up their values in traits hash.
          this.phenoIds = Object.keys(this.traits[this.selection])
            .filter((phenoId) => !isNaN(parseFloat(this.traits[this.selection][phenoId])))
            .sort((a,b) => this.traits[this.selection][a] - this.traits[this.selection][b]);

          console.log(this.phenoIds);
          this.traitVals = this.phenoIds.map((id) => parseFloat(this.traits[this.selection][id]));
          console.log(this.traitVals);
          // console.log(this.traitVals);
          // Debugging check: You should see a list of ids and the corresponding values, logs should be sorted by increasing values.
          // for (let id of this.phenoIds) {
          //   console.log(id, this.traits[this.selection][id].value);
          // }
        }

        standardDeviation(values) {
          function average(data) {
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
              width = 1180 - margin.left - margin.right,
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
          console.log('traitVals', this.traitVals);
          const [mean, stdDev] = this.standardDeviation(this.traitVals);
          this.outliers = [];
          // Add X axis
          var x = d3.scaleLinear()
          .domain([0, this.phenoIds.length])
          .range([ 0, width]);
          svg.append("g")
          .style("font", "18px times")
          .attr("transform", "translate(0," + height + ")")
      
          // Add Y axis
          var y = d3.scaleLinear()
          .domain([Math.min(...this.traitVals), Math.max(...this.traitVals)])
          .range([ height, 0]);
          svg.append("g")
          .style("font", "18px times")
          .call(d3.axisLeft(y))

          svg.append("text")
            .attr("transform", "rotate(-90)")
            .attr("y", 0 - margin.left)
            .attr("x",0 - (height / 2))
            .attr("dy", ".65em")
            .style("text-anchor", "middle")
            .style("font", "18px times")
            .text("Trait Value");

      
          // Add dots
          if (this.selection != null) {

            var tooltip = d3.select("#trait_graph")
            .append("div")
            .attr("id", "tooltip")
            .attr("class", "tooltip")
            .style("background-color", "white")
            .style("border", "solid")
            .style("border-width", "2px")
            .style("font-size", "15px")
            .style("border-radius", "5px")
            .style("padding", "5px")
            .style("opacity", 0);

            var mouseover = function(d) {
              tooltip
                  .style("opacity", 1)
                d3.select(this)
                  .style("stroke", "black")
                  .style("opacity", 1)
            }
            
            var mousemove = function(d) {
              tooltip
                .html("id: " + LocalThis.phenoIds[d] + "<br>" + "val: " + LocalThis.traitVals[d])
                .style("left", (d3.mouse(this)[0]+90) + "px")
                .style("top", (d3.mouse(this)[1]+180) + "px")
            }

            var mouseleave = function(d) {
              tooltip
                .style("opacity", 0)
              d3.select(this)
                .style("stroke", "none")
                .style("opacity", 0.8)
            }
            


            svg.append('g')
            .selectAll("dot")
            .data([...Array(this.phenoIds.length).keys()])
            .enter()
            .append("circle")
              .attr("cx", function (d) { return x(d); } )
              .attr("cy", function (d) { return y(LocalThis.traitVals[d]); } )
              .attr("r", 6)
              .style("fill", function(d) {return isOutlier(LocalThis.phenoIds[d], LocalThis.traitVals[d], mean, stdDev)})
              .on("mouseover", mouseover)
              .on("mousemove", mousemove)
              .on("mouseleave", mouseleave);

          }


          
        }
    }
    const dataset = new Dataset;    
    return dataset;
}