export function init(datasetId, datasetName) {
	class Dataset {
		constructor() {
			this.datasets = {};
			this.data = [];
			// store phenotype id, trait, value
			this.outliers = [];
			this.outlierCutoffs = new Set();
			this.firstRefresh = true;
			this.stdDevMultiplier = document.getElementById("myRange").value;
			this.selection = "default";
			this.datasetId = datasetId;
			this.observations = {};
			this.traits = {};
			this.traitsIds = {};
			this.phenoIds = [];
			this.traitVals = [];
		}

		getPhenotypes() {
		    const LocalThis = this;
		    this.firstRefresh = false;
		    new jQuery.ajax({
			    url: '/ajax/dataset/retrieve/' + this.datasetId + '/phenotypes?include_phenotype_primary_key=1',
			    success: function(response) {
			        LocalThis.observations = response.phenotypes;
			        LocalThis.setDropDownTraits();
			    },
			    error: function(response) {
			        alert('Error');
			    }
		    })
		}

		getTraits() {
            const LocalThis = this;
            this.firstRefresh = false;
            new jQuery.ajax({
			    url: '/ajax/dataset/retrieve/' + this.datasetId + '/traits',
			    success: function(response) {
			        LocalThis.traitsIds = response.traits.map(
				        trait => trait[0]
			        );
                // console.log("response from ajax:");
                // console.log(response);
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
		    if (this.selection != "default") {
			// Gets a list of pheno ids, filters them so only the ones that have non null values are included and then sorts the ids by their value by looking up their values in traits hash.
			this.phenoIds = Object.keys(this.traits[this.selection])
			    .filter((phenoId) => !isNaN(parseFloat(this.traits[this.selection][phenoId])))
			    .sort((a,b) => this.traits[this.selection][a] - this.traits[this.selection][b]);

			this.traitVals = this.phenoIds.map((id) => parseFloat(this.traits[this.selection][id]));
			// console.log(this.traitVals);
			// Debugging check: You should see a list of ids and the corresponding values, logs should be sorted by increasing values.
			// for (let id of this.phenoIds) {
			//   console.log(id, this.traits[this.selection][id].value);
			// }
		  }
		}

		standardDeviation(values) {
		    var average = function(data) {
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
                LocalThis.outliers = [];
                LocalThis.outlierCutoffs = new Set();
                d3.select("svg").remove();
                LocalThis.render();
		    }

		    // Handle Select Events
		    let selection = document.getElementById("trait_selection");
		    selection.addEventListener("change", (event) => {
                d3.select("svg").remove();
                LocalThis.selection = event.target.value;
                LocalThis.setData();
                LocalThis.outliers = [];
                LocalThis.outlierCutoffs = new Set();
			    if (!this.firstRefresh) {
			        LocalThis.render();
			    }
		    });

		    let storeOutliersButton = document.getElementById("store_outliers");
		    storeOutliersButton.onclick = function() {
			    const stringOutliers = LocalThis.outliers.join(',');
			    const stringOutlierCutoffs = [...LocalThis.outlierCutoffs].join(',');
			    new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/store_outliers/' + LocalThis.datasetId,
                    data: {outliers: stringOutliers, outlier_cutoffs: stringOutlierCutoffs },
                    success: function(response) {
                        alert('outliers successfully stored!');
                    },
			        error: function(response) {
				        alert('Error');
			        }
			    })
		    }
		}

		render() {
		    if (this.firstRefresh) {
			    this.getPhenotypes();
			    this.getTraits();
			    this.addEventListeners();
		    } else if (this.selection != "default") {
			    const LocalThis = this;

			    var margin = {top: 10, right: 30, bottom: 30, left: 60},
				    width = 1180 - margin.left - margin.right,
				    height = 600 - margin.top - margin.bottom;

			    var svg = d3.select("#trait_graph")
                    .append("svg")
				        .attr("width", width + margin.left + margin.right)
				        .attr("height", height + margin.top + margin.bottom)
			        .append("g")
				        .attr(
				            "transform",
				            "translate(" + margin.left + "," + margin.top + ")"
				            );

			    var isOutlier = function(id, value, mean, stdDev) {
				    let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
				    let leftCutoff = mean - stdDev * filter;
				    let rightCutoff = mean + stdDev * filter;
				    if (value >= leftCutoff && value <= rightCutoff) {
				        return "green";
				    } else {
                        // if left cutoff is negative, don't include it.
                        if (leftCutoff >= 0) {LocalThis.outlierCutoffs.add(leftCutoff)};
                        LocalThis.outlierCutoffs.add(rightCutoff);
                        LocalThis.outliers.push(id);
                        return "red";
				    }
			    }

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

                // mean legend
                const legend = svg.append('g')
                    .attr('id', 'legend')
                    .attr('height', 100)
                    .attr('width', 500)
                    .attr('transform', 'translate(950, 50)');

                legend.append("text")
                    .text("Mean: " + mean.toFixed(2));

                legend.append("text")
                    .text("Std Dev: " + stdDev.toFixed(2))
                    .attr('x', 0)
                    .attr('y', 15);

                legend.append("text")
//                  .text(LocalThis.stdDevMultiplier);\
                    .text(() => {
                        let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
                        let leftCutoff = mean - stdDev * filter;
                        return "Left Cutoff: " + leftCutoff.toFixed(2);
                    })
                    .attr('x', 0)
                    .attr('y', 30);

                legend.append("text")
                    .text(() => {
                        let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
                        let rightCutoff = mean + stdDev * filter;
                        return "Right Cutoff: " +  rightCutoff.toFixed(2);
                    })
                    .attr('x', 0)
                    .attr('y', 45);

                legend.append("text")
                    .text(() => {
                        let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
                        return "Filter multiplier: " +  filter;
                    })
                    .attr('x', 0)
                    .attr('y', 60);

		    }
		}
	}
	const dataset = new Dataset;
	return dataset;
}