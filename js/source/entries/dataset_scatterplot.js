export function init(datasetId, datasetName) {
	class Dataset {
		constructor() {
			this.datasets = {};
			this.data = [];
			// store phenotype id, trait, value
			this.outliers = [];
			this.outlierCutoffs = new Set();
			this.firstRefresh = true;
			this.stdDevMultiplier = document.getElementById("outliersRange").value;
			this.selection = "default";
			this.datasetId = datasetId;
			this.observations = {};
			this.traits = {};
			this.traitsIds = {};
			this.phenoIds = [];
			this.traitVals = [];
			this.storedOutliersIds = [];
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
			    },
			    error: function(response) {
			        alert('Error');
			    }
            })
		}

        getStoredOutliers() {
            const LocalThis = this;            
            new jQuery.ajax({
                type: 'POST',
                url: '/ajax/dataset/retrieve_outliers/' + LocalThis.datasetId,
                success: function(response) {
                    console.log("response from ajax stored outliers:");
                    console.log(response.outliers);
                    LocalThis.storedOutliersIds = response.outliers;
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


        median(values) {
            let sorted = [...values].sort((a, b) => a - b);
            let middle = Math.floor(sorted.length / 2);

            if (sorted.length % 2 === 0) {
                return (sorted[middle - 1] + sorted[middle]) / 2;
            }

            return sorted[middle];
        }

        mad(values) {
            return 1;
        }

		addEventListeners() {
		    let LocalThis = this;

		    // Handle Slider Events
		    var slider = document.getElementById("outliersRange");
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
				document.getElementById("outliersRange").value = document.getElementById("outliersRange").max; 
				LocalThis.stdDevMultiplier = document.getElementById("outliersRange").value;
			    if (!this.firstRefresh) {
			        LocalThis.render();
			    }				
		    });

		    let storeOutliersButton = document.getElementById("store_outliers");
		    storeOutliersButton.onclick = function() {
		        let allOutliers = new Set(LocalThis.storedOutliersIds.concat(LocalThis.outliers));
			    let stringOutliers = [...allOutliers].join(',');
			    let stringOutlierCutoffs = [...LocalThis.outlierCutoffs].join(',');
			    new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/store_outliers/' + LocalThis.datasetId,
                    data: {outliers: stringOutliers, outlier_cutoffs: stringOutlierCutoffs },
                    success: function(response) {
                        alert('outliers successfully stored!');
                        LocalThis.storedOutliersIds = [...allOutliers];
                    },
			        error: function(response) {
				        alert('Error');
			        }
			    })
		    }

            let resetOutliersButton = document.getElementById("reset_outliers");
            resetOutliersButton.onclick = function() {

                new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/store_outliers/' + LocalThis.datasetId,
                    data: {outliers: "", outlier_cutoffs: "" },
                    success: function(response) {
                        alert('outliers successfully reseted!');
                        LocalThis.storedOutliersIds = [];						
						d3.select("svg").remove();
						LocalThis.render();
                    },
                    error: function(response) {
                        alert('Error');
                    }
                })
            }

            let resetTraitOutliersButton = document.getElementById("reset_trait");
            resetTraitOutliersButton.onclick = function() {                
                let filteredNonTrait = LocalThis.storedOutliersIds.filter(elem => !LocalThis.phenoIds.includes(elem));
                let stringFilteredNonTrait = filteredNonTrait.join(',');                
               	new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/store_outliers/' + LocalThis.datasetId,
                    data: {outliers: stringFilteredNonTrait, outlier_cutoffs: "" },
                    success: function(response) {
                        alert('outliers successfully reseted!');
                        LocalThis.storedOutliersIds = filteredNonTrait;					   					    
						d3.select("svg").remove();
						LocalThis.render();
                    },
                    error: function(response) {
                       alert('Error');
                    }
               })
            }

// 		    let retrieveOutliersButton = document.getElementById("retrieve_outliers");
//             retrieveOutliersButton.onclick = function() {
//                 new jQuery.ajax({
//                     type: 'POST',
//                     url: '/ajax/dataset/retrieve_outliers/' + LocalThis.datasetId,
//                     success: function(response) {
//                         alert('outliers successfully restored!');
//                         console.log(response.outliers);
// //                        LocalThis.storedOutliersIds = response.outliers;
//                     },
//                     error: function(response) {
//                         alert('Error');
//                     }
//                 })
//             }

            // let showOutliersButton = document.getElementById("show_outliers");
            // showOutliersButton.onclick = function() {
            //     console.log(LocalThis.outliers);
            // }

		}

		render() {
		    if (this.firstRefresh) {
			    this.getPhenotypes();
			    this.getTraits();
			    this.getStoredOutliers();
			    this.addEventListeners();
		    } else if (this.selection != "default") {
			    const LocalThis = this;

			    const margin = {top: 10, right: 30, bottom: 30, left: 60},
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

                const greenColor = "#00ba38"
                    , yellowColor = "#ffe531"
                    , redColor = "#f7756c";

                var isOutlier = function(id, value, mean, stdDev) {
				    let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
				    let leftCutoff = mean - stdDev * filter;
				    let rightCutoff = mean + stdDev * filter;
				    let color = "";
//				    console.log(LocalThis.storedOutliersIds);

				    if (value >= leftCutoff && value <= rightCutoff) {
				         color = greenColor;
                    }

                    if (LocalThis.storedOutliersIds.includes(id.toString())) {
                         color = yellowColor;
                    }

                    if (value <= leftCutoff || value >= rightCutoff){
                        if (leftCutoff >= 0) {LocalThis.outlierCutoffs.add(leftCutoff)};
                        LocalThis.outlierCutoffs.add(rightCutoff);
                        LocalThis.outliers.push(id);
                        color = redColor;
                    }

                    return color;
                }

			    const [mean, stdDev] = this.standardDeviation(this.traitVals);

			    this.outliers = [];

			    // Add ackground ggplot2 like
                svg.append("rect")
                    .attr("x",0)
                    .attr("y",0)
                    .attr("height", height)
                    .attr("width", width)
                    .style("fill", "#ebebeb")

			    // Add X axis
			    var x = d3.scaleLinear()
			        .domain([0, this.phenoIds.length])
			        .range([ 0, width]);
//                svg.append("g")
//			        .style("font", "16px arial")
//			        .attr("transform", "translate(0," + height + ")")

			    // Add Y axis
			    var y = d3.scaleLinear()
			        .domain([Math.min(...this.traitVals), Math.max(...this.traitVals)])
			        .range([ height, 0]);
                svg.append("g")
                    .call(d3.axisLeft(y).tickSize(-width*1).ticks(10))
                     .style("font", "16px arial")
//                    .select(".domain").remove()

                // Customization
                svg.selectAll(".tick line").attr("stroke", "white")

//			    svg.append("g")
//			        .style("font", "16px arial")
//			        .call(d3.axisLeft(y))

			    svg.append("text")
			        .attr("transform", "rotate(-90)")
			        .attr("y", 0 - margin.left)
			        .attr("x",0 - (height / 2))
                    .attr("dy", ".65em")
			        .style("text-anchor", "middle")
			        .style("font", "16px arial")
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
                        .style("left", (d3.mouse(this)[0]+50) + "px")
                        .style("top", (d3.mouse(this)[1]+40) + "px")
			    }

			    var mouseleave = function(d) {
			        tooltip
				        .style("opacity", 0)
			        d3.select(this)
				        .style("stroke", "none")
				        .style("opacity", 0.8)
		    	}

		    	let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
                let rightCutoff = mean + stdDev * filter;
                let leftCutoff = mean - stdDev * filter;

			    svg.append('g')
			        .selectAll("dot")
			        .data([...Array(this.phenoIds.length).keys()])
			        .enter()
                    .append("circle")
			            .attr("cx", function (d) { return x(d); } )
                        .attr("cy", function (d) { return y(LocalThis.traitVals[d]); } )
                        .attr("r", 6)
                        .style("fill", function(d) {return isOutlier(LocalThis.phenoIds[d], LocalThis.traitVals[d], mean, stdDev)})
                        .style("opacity", (d) => { return (LocalThis.traitVals[d] <= leftCutoff || LocalThis.traitVals[d] >= rightCutoff ? 0.2 : 0.8) })
                        .on("mouseover", mouseover)
                        .on("mousemove", mousemove)
                        .on("mouseleave", mouseleave);

                svg.append("line")
                   .attr("class", "mean-line")
                   .attr("x1", 0)
                   .attr("y1", y(mean))
                   .attr("x2", width)
                   .attr("y2", y(mean))
                   .attr("fill", "none")
                   .attr("stroke", "black");


               svg.append("line")
                  .attr("class", "sd-line-top")
                  .attr("x1", 0)
                  .attr("y1", y(rightCutoff))
                  .attr("x2", width)
                  .attr("y2", y(rightCutoff))
                  .attr("fill", "none")
                  .attr("stroke", "darkgrey");

               svg.append("line")
                  .attr("class", "sd-line-bottom")
                  .attr("x1", 0)
                  .attr("y1", y(leftCutoff >= 0 ? leftCutoff : 0))
                  .attr("x2", width)
                  .attr("y2", y(leftCutoff >= 0 ? leftCutoff : 0))
                  .attr("fill", "none")
                  .attr("stroke", "darkgrey");



				// legend builder				
				const legendSize = {
					width: 250,
					height: 135,
					get posX() {
                        return 5;
					},
					get posY() {
						return 15
					}
					};
				const  dotSize = 7

            	const legend = svg.append("g")
            		.attr('id', 'legend')
                   	.attr('height', legendSize.height)
                   	.attr('width', legendSize.width)
                   	.attr('transform', 'translate(5, 5)');

				legend.append('rect')				
					.attr('height', legendSize.height)
					.attr('width',  legendSize.width)
					.attr('x', 0)
					.attr('y', 0)
					.attr('fill', 'white')
					.style("stroke", "lightgrey")
					.style("stroke-width", 3);



				legend.append('circle')
					.attr('r', dotSize)
					.attr('class', 'dot-legend')
					.attr('fill', greenColor)
					.attr('cx', legendSize.posX + 20)
					.attr('cy', legendSize.posY + 5)

				legend.append('circle')
					.attr('r', dotSize)
					.attr('fill', yellowColor)
					.attr('class', 'dot-legend')
					.attr('cx', legendSize.posX + 20)
					.attr('cy', legendSize.posY + 30)

				legend.append('circle')
					.attr('r', dotSize)
					.attr('class', 'dot-legend')
					.attr('fill', redColor)
					.attr('cx', legendSize.posX + 20)
					.attr('cy', legendSize.posY + 55)


                svg.append('text')
                    .attr('x', legendSize.posX + 25 + dotSize + 5)
                    .attr('y', legendSize.posY + 10 + dotSize / 2 + 1)
                    .style("font", "arial")
                    .text('normal data point')

                svg.append('text')
                    .attr('x', legendSize.posX + 25 + dotSize + 5)
                    .attr('y', legendSize.posY + 35 + dotSize / 2 + 1)
                    .style("font", "arial")
                    .text('outliers value stored in database')

				svg.append('text')
                    .attr('x', legendSize.posX + 25 + dotSize + 5)
                    .attr('y', legendSize.posY + 60 + dotSize / 2 + 1)
                    .style("font", "arial")
                    .text('outliers from current cutoff')


               	legend.append("text")
                   .text("Mean: " + mean.toFixed(2))
				   .attr('x', legendSize.posX + 20 - dotSize / 2)
                   .attr('y', legendSize.posY + 85);

               	legend.append("text")
                   .text("Std Dev: " + stdDev.toFixed(2))
				   .style("font", "arial")
                   .attr('x', legendSize.posX + 120 - dotSize / 2)
                   .attr('y', legendSize.posY + 85);

               	legend.append("text")
                   .text(() => {
                       let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
                       let leftCutoff = mean - stdDev * filter;
                       return "L. Cutoff: " + leftCutoff.toFixed(2);
                   })
				   .style("font", "arial")
                   .attr('x', legendSize.posX + 20 - dotSize / 2)
                   .attr('y', legendSize.posY + 110);

               	legend.append("text")
                   .text(() => {
                       let filter = (LocalThis.stdDevMultiplier - 1) / 2 ;
                       let rightCutoff = mean + stdDev * filter;
                       return "R. Cutoff: " +  rightCutoff.toFixed(2);
                   })
				   .style("font", "arial")
                   .attr('x', legendSize.posX + 120 - dotSize / 2)
                   .attr('y', legendSize.posY + 110);

		    }
		}
	}
	const dataset = new Dataset;
	return dataset;
}