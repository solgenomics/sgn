export function init(datasetId, datasetName) {
    class Dataset {
        constructor() {
            this.datasets = {};
            this.data = [];
            // store phenotype id, trait, value
            this.outliers = [];
            this.outlierCutoffs = new Set();
            this.firstRefresh = true;
            this.stdDevMultiplier = $("#outliers_range").slider("value");
            this.selection = "default";
            this.datasetId = datasetId;
            this.observations = {};
            this.traits = {};
            this.traitsIds = {};
            this.phenoIds = [];
            this.traitVals = [];
            this.storedOutliersIds = [];
            this.metricValue = document.querySelector('input[name="dataset_metric"]:checked').value;
        }

        getPhenotypes() {
            const LocalThis = this;
            this.firstRefresh = false;
            new jQuery.ajax({
                url: '/ajax/dataset/retrieve/' + this.datasetId + '/phenotypes?include_phenotype_primary_key=1',
                success: function (response) {
                    LocalThis.observations = response.phenotypes;
                    LocalThis.setDropDownTraits();
                },
                error: function (response) {
                    alert('Error');
                }
            })
        }

        getTraits() {
            const LocalThis = this;
            this.firstRefresh = false;
            new jQuery.ajax({
                url: '/ajax/dataset/retrieve/' + this.datasetId + '/traits',
                success: function (response) {
                    LocalThis.traitsIds = response.traits.map(
                        trait => trait[0]
                    );
                    // console.log(LocalThis.traitsIds);
                },
                error: function (response) {
                    alert('Error');
                }
            })
        }

        getStoredOutliers() {
            const LocalThis = this;
            new jQuery.ajax({
                type: 'POST',
                url: '/ajax/dataset/retrieve_outliers/' + LocalThis.datasetId,
                success: function (response) {
                    LocalThis.storedOutliersIds = response.outliers !== null ? response.outliers : [];
                },
                error: function (response) {
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
                        this.traits[keys[j]][this.observations[i][j + 1]] = this.observations[i][j];
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

                // console.log(this.traits);
                this.phenoIds = Object.keys(this.traits[this.selection])
                    .filter((phenoId) => !isNaN(parseFloat(this.traits[this.selection][phenoId])))
                    .sort((a, b) => this.traits[this.selection][a] - this.traits[this.selection][b]);

                // console.log(this.phenoIds);

                this.traitVals = this.phenoIds.map((id) => parseFloat(this.traits[this.selection][id]));
                // console.log(this.traitVals);
                // Debugging check: You should see a list of ids and the corresponding values, logs should be sorted by increasing values.
                // for (let id of this.phenoIds) {
                //   console.log(id, this.traits[this.selection][id].value);
                // }
            }
        }

        standardDeviation(values) {
            var average = function (data) {
                var sum = data.reduce(function (sum, value) {
                    return sum + value;
                }, 0);

                var avg = sum / data.length;
                return avg;
            }

            var avg = average(values);

            var squareDiffs = values.map(function (value) {
                var diff = value - avg;
                var sqrDiff = diff * diff;
                return sqrDiff;
            });

            var avgSquareDiff = average(squareDiffs);

            var stdDev = Math.sqrt(avgSquareDiff);
            return [avg, stdDev];
        }

        median(values) {
            if (!Array.isArray(values)) return 0;
            let sorted = [...values].sort((a, b) => a - b);
            let middle = Math.floor(sorted.length / 2);

            if (sorted.length % 2 === 0) {
                return (sorted[middle - 1] + sorted[middle]) / 2;
            }

            return sorted[middle];
        } // OK - tested

        mad(values) {
            // MAD = Median(|Xi - Median(Xi)|)
            if (!Array.isArray(values)) return 0;
            let medianValue = this.median(values);
            let medianMap = values.map(x => Math.abs(x - medianValue));

            return this.median(medianMap);
        } // OK - tested


        quartile(values, factor) {
            if (!Array.isArray(values)) return 0;

            let sorted = [...values].sort((a, b) => a - b);
            let index = (sorted.length - 1) * factor;
            let lowerIndex = Math.floor(index);
            let upperIndex = Math.ceil(index);
            let interpolation = index - lowerIndex;
            return sorted[lowerIndex] * (1 - interpolation) + sorted[upperIndex] * interpolation;
        }


        iqr(values) {
            let q1 = this.quartile(values, 0.25);
            let q3 = this.quartile(values, 0.75);
            return q3 - q1;
        }

        addEventListeners() {
            let LocalThis = this;

            // Handle Slider Events
            var sliderSelector = $("#outliers_range");
            sliderSelector.on("slidechange", (event, ui) => {
                LocalThis.stdDevMultiplier = ui.value;
                LocalThis.outliers = [];
                LocalThis.outlierCutoffs = new Set();
                d3.select("svg").remove();
                LocalThis.render();
            })
            // Handle Metric Radio 			
            var metricSelectors = document.querySelectorAll('input[type=radio][name="dataset_metric"]');

            Array.prototype.forEach.call(metricSelectors, (metricRadio) => {
                metricRadio.addEventListener("change", (event) => {


                    LocalThis.metricValue = document.querySelector('input[name="dataset_metric"]:checked').value;
                    d3.select("svg").remove();
                    LocalThis.render();
                })
            })

            // Handle Select Events
            let selection = document.getElementById("trait_selection");
            selection.addEventListener("change", (event) => {
                d3.select("svg").remove();
                LocalThis.selection = event.target.value;
                LocalThis.setData();
                LocalThis.outliers = [];
                LocalThis.outlierCutoffs = new Set();
                sliderSelector.slider("option", "value", 3);
                LocalThis.stdDevMultiplier = sliderSelector.slider("value");
                if (!this.firstRefresh) {
                    d3.select("svg").remove();
                    LocalThis.render();
                    removeRosnserTable();
                }
            });

            let storeOutliersButton = document.getElementById("store_outliers");
            storeOutliersButton.onclick = function () {
                let allOutliers = new Set(LocalThis.storedOutliersIds.concat(LocalThis.outliers));
                let stringOutliers = [...allOutliers].join(',');
                let stringOutlierCutoffs = [...LocalThis.outlierCutoffs].join(',');
                new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/store_outliers/' + LocalThis.datasetId,
                    data: { outliers: stringOutliers, outlier_cutoffs: stringOutlierCutoffs },
                    success: function (response) {
                        alert('outliers successfully stored!');
                        LocalThis.storedOutliersIds = [...allOutliers];
                        d3.select("svg").remove();
                        LocalThis.render();
                    },
                    error: function (response) {
                        alert('Error');
                    }
                })
            }

            let resetOutliersButton = document.getElementById("reset_outliers");
            resetOutliersButton.onclick = function () {
                new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/store_outliers/' + LocalThis.datasetId,
                    data: { outliers: "", outlier_cutoffs: "" },
                    success: function (response) {
                        alert('outliers successfully reseted!');
                        LocalThis.storedOutliersIds = [];
                        d3.select("svg").remove();
                        LocalThis.render();
                        removeRosnserTable();
                    },
                    error: function (response) {
                        alert('Error');
                    }
                })
            }

            let resetTraitOutliersButton = document.getElementById("reset_trait");
            resetTraitOutliersButton.onclick = function () {
                let filteredNonTrait = LocalThis.storedOutliersIds.filter(elem => !LocalThis.phenoIds.includes(elem));
                let stringFilteredNonTrait = filteredNonTrait.join(',');
                new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/store_outliers/' + LocalThis.datasetId,
                    data: { outliers: stringFilteredNonTrait, outlier_cutoffs: "" },
                    success: function (response) {
                        alert('outliers successfully reseted!');
                        LocalThis.storedOutliersIds = filteredNonTrait;
                        d3.select("svg").remove();
                        LocalThis.render();
                        removeRosnserTable();
                    },
                    error: function (response) {
                        alert('Error');
                    }
                })
            }

            let rosnersTestButton = document.getElementById("rosner_test");
            rosnersTestButton.onclick = function () {
                if (document.getElementById("trait_selection").value == 'default') return;
                // add spinner 
                document.getElementById("loading-spinner").style.visibility = 'visible';
                new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/rosner_test/' + LocalThis.datasetId,
                    data: { dataset_trait: document.getElementById("trait_selection").value },
                    success: function (response) {
                        // alert(response.message);
                        createOutlierTable(response.file);
                        document.getElementById("loading-spinner").style.visibility = 'hidden';
                    },
                    error: function (response) {
                        alert('Error');
                        document.getElementById("loading-spinner").style.visibility = 'visible';
                    }
                })
            }

            function createOutlierTable(file) {
                // check if exist and remove
                let data_rows = file.slice(1, file.length);
                let column_names = file[0].map(value => ({ "title": value }));
                let outliers = data_rows.filter((elem) => { return elem[7] == 'TRUE' }).map((elem) => elem[4]);

                removeRosnserTable();

                let table = document.createElement("table");
                table.setAttribute("id", "rosner_table");
                table.classList = "display";
                document.getElementById("statistic_tests").appendChild(table);

                let addRosnerButton = document.createElement("button");
                if (outliers.length == 0) {
                    addRosnerButton.disabled = true;
                }
                addRosnerButton.setAttribute("id", "rosner_add");
                addRosnerButton.classList = "btn btn-sm btn-success btn-dataset";
                addRosnerButton.textContent = "Add Rosner test outliers";
                addRosnerButton.addEventListener('click', function () {
                    addRosnserOutliers(outliers);
                });

                document.getElementById("statistic_tests").appendChild(addRosnerButton);

                jQuery('#rosner_table').DataTable({
                    columns: column_names,
                    data: data_rows,
                    searching: false,
                    paging: false,
                    info: false
                });

                return false;
            }

            function addRosnserOutliers(rosnerOutliers) {
                if (rosnerOutliers.length == 0) {
                    return;
                }
                // console.log(rosnerOutliers);

                let allOutliers = new Set(LocalThis.storedOutliersIds.concat(rosnerOutliers));
                let stringOutliers = [...allOutliers].join(',');
                let stringOutlierCutoffs = [...LocalThis.outlierCutoffs].join(',');
                new jQuery.ajax({
                    type: 'POST',
                    url: '/ajax/dataset/store_outliers/' + LocalThis.datasetId,
                    data: { outliers: stringOutliers, outlier_cutoffs: stringOutlierCutoffs },
                    success: function (response) {
                        alert('outliers successfully stored!');
                        LocalThis.storedOutliersIds = [...allOutliers];
                        d3.select("svg").remove();
                        LocalThis.render();
                    },
                    error: function (response) {
                        alert('Error');
                    }
                })

                return false;
            }

            function removeRosnserTable() {
                if ($.fn.DataTable.isDataTable("#rosner_table")) {
                    jQuery('#rosner_table').DataTable().destroy();
                }
                if (document.getElementById("rosner_table")) {
                    document.getElementById("rosner_table").remove();
                    document.getElementById("rosner_add").remove();
                }
            }
        }



        render() {
            if (this.firstRefresh) {
                this.getPhenotypes();
                this.getTraits();
                this.getStoredOutliers();
                this.addEventListeners();
            } else if (this.selection != "default") {

                const LocalThis = this;

                const [mean, stdDev] = this.standardDeviation(this.traitVals);
                const [median, mad] = [this.median(this.traitVals), this.mad(this.traitVals)];
                const [quartiles, factor] = [[this.quartile(this.traitVals, 0.25), this.quartile(this.traitVals, 0.75)], this.iqr(this.traitVals)];

                let settings;
                switch (LocalThis.metricValue) {
                    case "mean":
                        settings = [mean, stdDev, "Mean", "Std Dev"];
                        break;
                    case "median":
                        settings = [median, mad, "Median", "MAD"];
                        break;
                    case "iqr":
                        settings = [quartiles, factor, "Q1,Q3", "IQR"];
                        break;
                    default:
                        settings = [median, mad, "Median", "MAD"];
                }
                const [metric, deviation, metricString, deviationString] = settings;

                let filter = LocalThis.stdDevMultiplier;

                function rightCutoffCalc() {
                    if (LocalThis.metricValue == "iqr") {
                        return quartiles[1] + factor * filter;
                    } else {
                        return metric + deviation * filter;
                    }
                }

                function leftCutoffCalc() {
                    if (LocalThis.metricValue == "iqr") {
                        return quartiles[0] - factor * filter;
                    } else {
                        return Math.max(metric - deviation * filter, 0);
                    }
                }

                let rightCutoff = rightCutoffCalc();
                let leftCutoff = leftCutoffCalc();

                this.outliers = [];

                const margin = { top: 10, right: 30, bottom: 30, left: 60 },
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
                    , redColor = "#f7756c"
                    , blueColor = "#337ab7";

                var isOutlier = function (id, value, leftCutoff, rightCutoff) {

                    let color = "";
                    let stroke;

                    if (value >= leftCutoff && value <= rightCutoff) {
                        color = greenColor;
                    }

                    if (LocalThis.storedOutliersIds.includes(id.toString())) {
                        stroke = "black";
                    }

                    if (value <= leftCutoff || value >= rightCutoff) {
                        if (leftCutoff >= 0) { LocalThis.outlierCutoffs.add(leftCutoff) };
                        LocalThis.outlierCutoffs.add(rightCutoff);
                        LocalThis.outliers.push(id);
                        color = redColor;
                    }

                    return [color, stroke];
                }

                // Add ackground ggplot2 like
                svg.append("rect")
                    .attr("x", 0)
                    .attr("y", 0)
                    .attr("height", height)
                    .attr("width", width)
                    .style("fill", "#ebebeb")

                // Add X axis
                var x = d3.scaleLinear()
                    .domain([0, this.phenoIds.length])
                    .range([0, width]);

                // Add Y axis
                var y = d3.scaleLinear()
                    .domain([Math.min(...this.traitVals), Math.max(...this.traitVals)])
                    .range([height, 0]);
                svg.append("g")
                    .call(d3.axisLeft(y).tickSize(-width * 1).ticks(10))
                    .style("font", "16px arial")

                // Customization
                svg.selectAll(".tick line").attr("stroke", "white")

                svg.append("text")
                    .attr("transform", "rotate(-90)")
                    .attr("y", 0 - margin.left)
                    .attr("x", 0 - (height / 2))
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

                var mouseover = function (d) {
                    tooltip
                        .style("opacity", 1)
                    d3.select(this)
                        .style("fill", "white")
                        .style("opacity", 1)
                }

                var mousemove = function (d) {
                    tooltip
                        .html("id: " + LocalThis.phenoIds[d] + "<br>" + "val: " + LocalThis.traitVals[d])
                        .style("left", (d3.mouse(this)[0] + 50) + "px")
                        .style("top", (d3.mouse(this)[1] + 40) + "px")
                }

                var mouseleave = function (d) {
                    tooltip
                        .style("opacity", 0)
                    d3.select(this)
                        .style("fill", function (d) { return isOutlier(LocalThis.phenoIds[d], LocalThis.traitVals[d], leftCutoff, rightCutoff)[0] })
                        .style("stroke-width", 2)
                        .style("stroke", function (d) { return isOutlier(LocalThis.phenoIds[d], LocalThis.traitVals[d], leftCutoff, rightCutoff)[1] })
                        .style("fill-opacity", (d) => { return (LocalThis.traitVals[d] <= leftCutoff || LocalThis.traitVals[d] >= rightCutoff ? 0.2 : 0.8) })
                        .style("stroke-opacity", (d) => { return (LocalThis.traitVals[d] <= leftCutoff || LocalThis.traitVals[d] >= rightCutoff ? 0.4 : 0.8) })
                }

                svg.append('g')
                    .selectAll("dot")
                    .data([...Array(this.phenoIds.length).keys()])
                    .enter()
                    .append("circle")
                    .attr("cx", function (d) { return x(d); })
                    .attr("cy", function (d) { return y(LocalThis.traitVals[d]); })
                    .attr("r", 6)
                    .style("fill", function (d) { return isOutlier(LocalThis.phenoIds[d], LocalThis.traitVals[d], leftCutoff, rightCutoff)[0] })
                    .style("stroke-width", 2)
                    .style("stroke", function (d) { return isOutlier(LocalThis.phenoIds[d], LocalThis.traitVals[d], leftCutoff, rightCutoff)[1] })
                    .style("fill-opacity", (d) => { return (LocalThis.traitVals[d] <= leftCutoff || LocalThis.traitVals[d] >= rightCutoff ? 0.2 : 0.8) })
                    .style("stroke-opacity", (d) => { return (LocalThis.traitVals[d] <= leftCutoff || LocalThis.traitVals[d] >= rightCutoff ? 0.4 : 0.8) })
                    .on("mouseover", mouseover)
                    .on("mousemove", mousemove)
                    .on("mouseleave", mouseleave);

                let metricArray;
                if (LocalThis.metricValue != "iqr") {
                    metricArray = [metric];
                } else {
                    metricArray = metric;
                }

                metricArray.forEach((number) => {
                    svg.append("line")
                        .attr("class", "mean-line")
                        .attr("x1", 0)
                        .attr("y1", y(number))
                        .attr("x2", width)
                        .attr("y2", y(number))
                        .attr("fill", "none")
                        .attr("stroke", "black");
                })

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
                const dotSize = 7

                const legend = svg.append("g")
                    .attr('id', 'legend')
                    .attr('height', legendSize.height)
                    .attr('width', legendSize.width)
                    .attr('transform', 'translate(5, 5)');

                legend.append('rect')
                    .attr('height', legendSize.height)
                    .attr('width', legendSize.width)
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
                    .attr('stroke', "black")
                    .style("stroke-width", 2)
                    .style("fill", "none")
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
                    .text(metricString + ": " + (LocalThis.metricValue == "iqr" ? "(" + metric[0].toFixed(1) + ", " + metric[1].toFixed(1) + ")" : metric.toFixed(2)))
                    .attr('x', legendSize.posX + 20 - dotSize / 2)
                    .attr('y', legendSize.posY + 85);

                legend.append("text")
                    .text(deviationString + ": " + deviation.toFixed(2))
                    .style("font", "arial")
                    .attr('x', legendSize.posX + (LocalThis.metricValue == "iqr" ? 165 : 130) - dotSize / 2)
                    .attr('y', legendSize.posY + 85);

                legend.append("text")
                    .text(() => {
                        return "L. Cutoff: " + leftCutoff.toFixed(2);
                    })
                    .style("font", "arial")
                    .attr('x', legendSize.posX + 20 - dotSize / 2)
                    .attr('y', legendSize.posY + 110);

                legend.append("text")
                    .text(() => {
                        return "R. Cutoff: " + rightCutoff.toFixed(2);
                    })
                    .style("font", "arial")
                    .attr('x', legendSize.posX + 130 - dotSize / 2)
                    .attr('y', legendSize.posY + 110);
            }
        }
    }
    const dataset = new Dataset;
    return dataset;
}