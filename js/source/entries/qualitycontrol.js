import '../legacy/jquery.js';
import '../legacy/d3/d3v4Min.js';

var version = '0.01';

export function init(main_div) {
    if (!(main_div instanceof HTMLElement)) {
        main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
    }

    var dataset_id;
    get_select_box("datasets", "qc_dataset_select", { "checkbox_name": "qc_dataset_select_checkbox" });

    jQuery('#qc_analysis_prepare_button').removeClass('active').addClass('inactive');

    $(document).on('click', 'input[name=select_engine]', function (e) {
        get_model_string();
    });

    let outliers = [];
    var trait_selected;
    var tempfile;
    let allData = [];
    var all_traits;

    $('#qc_analysis_prepare_button').click(function () {
        dataset_id = get_dataset_id();
        if (dataset_id != false) {
            $.ajax({
                url: '/ajax/qualitycontrol/prepare',
                data: { 'dataset_id': get_dataset_id() },
                success: function (r) {
                    if (r.error) {
                        alert(r.error);
                    }  else {

                        if (r.tempfile) {
                            $('#tempfile').html(r.tempfile);
                        }
                        updateBoxplot();
                }
            },
                error: function (jqXHR, textStatus, errorThrown) {
                    console.error('AJAX request failed: ', textStatus, errorThrown);
                    alert('Error in AJAX request: ' + errorThrown);
                }
            });
        }
    });
    $(function() {
            var handle = $("#custom-handle");
            $("#outliers_range").slider({
                orientation: "horizontal",
                range: "min",
                max: 10,
                min: 0,
                value: 1.5,
                step: 0.1,
                create: function() {
                    handle.text($(this).slider("value"));
                },
                slide: function(event, ui) {
                    handle.text(ui.value);
                    isFixedMinMax = false;
                    updateBoxplot(isFixedMinMax, minVal, maxVal);  // Update the boxplot when the slider value changes
                }
            });
        });

    $('#qc_analysis_prepare_button').click(function () {
        dataset_id = get_dataset_id();
        if (dataset_id != false) {
            $.ajax({
                url: '/ajax/qualitycontrol/prepare',
                data: { 'dataset_id': dataset_id },  // No need to call get_dataset_id() again
                success: function (r) {
                    if (r.error) {
                        alert(r.error);
                    } else {
                          if (r.selected_variable) {
                            populateTraitDropdown(r.selected_variable);  // Populate dropdown with traits
                            all_traits = r.selected_variable;
                        }
                        if (r.tempfile) {
                            $('#tempfile').html(r.tempfile);
                        }
                    }
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    alert('Error in AJAX request: ' + errorThrown);
                }
            });
        }
    });

    let isFixedMinMax = false;
    let minVal;
    let maxVal;
    
    $('#selected_variable').on('change', function () {
        trait_selected = $('#trait_select').val();  // Get the selected trait from the dropdown

        if (!trait_selected) {
            $('#trait_boxplot').html('Please select a trait to see the boxplot!');
            return;
        }

        // Fetch tempfile value
        tempfile = $('#tempfile').html();  

        // Check if tempfile is not empty
        if (!tempfile || tempfile.trim() === '') {
            return; // Exit if tempfile is empty
        }

        var outlierMultiplier = $('#outliers_range').slider("value");
        if (!outlierMultiplier || isNaN(outlierMultiplier)) {
            outlierMultiplier = 1.5;         }

        $.ajax({
            url: '/ajax/qualitycontrol/grabdata',
            data: { 'file': tempfile, 'trait': trait_selected },
            success: function (r) {
                $('#working_modal').modal("hide");
                if (r.message) {
                    alert(r.message);
                    return;
                } else {
                    const result = drawBoxplot(r.data, trait_selected, outlierMultiplier, isFixedMinMax, minVal, maxVal );
                    outliers = result.outliers;  // Extract the outliers
                    globalOutliers = outliers;
                    allData = r.data;
                    populateOutlierTable(r.data, trait_selected);
                    populateCleanTable(r.data, outliers, trait_selected);
                }
                
            },
            error: function (e) {
                alert('Error during AJAX request!');
            }
        });

    });
    
    $("#fixed-min-max").click(function() {
        isFixedMinMax = true;  

        let dataset_id = get_dataset_id();
        minVal = parseFloat(document.getElementById("min-limit").value);
        maxVal = parseFloat(document.getElementById("max-limit").value);

        if (dataset_id) {
            $.ajax({
                url: '/ajax/qualitycontrol/prepare',
                data: { 'dataset_id': dataset_id },
                success: function (r) {
                    if (r.error) {
                        alert(r.error);
                    } else {
                        if (r.selected_variable) {
                            updateBoxplot(isFixedMinMax, minVal, maxVal);
                        }
                        if (r.tempfile) {
                            $('#tempfile').html(r.tempfile);
                        }
                    }
                },
                error: function (jqXHR, textStatus, errorThrown) {
                    alert('Error in AJAX request: ' + errorThrown);
                }
            });
        }
    });
    
    const checkedTraits = [];
    $('#select_traits_button').on('click', function () {
        populateOtherTraits(all_traits, trait_selected);
        $(document).on('change', 'input[name="new_trait_options"]', function() {
            $('input[name="new_trait_options"]:checked').each(function() {
                checkedTraits.push($(this).val());  // Get the value of each checked checkbox
            });
        });
    });

        
    $('#store_outliers_button').click(function () {
        $.ajax({
            url: '/ajax/qualitycontrol/storeoutliers',  
            method: "POST",  
            data: {"outliers": JSON.stringify(globalOutliers), "trait":trait_selected, "othertraits": JSON.stringify(checkedTraits)
            },
            success: function(response) {
                if(response.is_curator === 1) {
                    $('#store_outliers_button').prop("disabled", false);
                    alert('Outliers successfully stored!');
                } else {
                    $('#store_outliers_button').prop("disabled", true);
                    alert("Only curators or breeders are allowed to validated trials. Please contact a curator.", response.is_curator);
                }
                

            },
            error: function(xhr, status, error) {
                alert('Error saving outliers: ' + error);
                console.log(xhr, status);
            }
        });
    });

    $('#restore_outliers_button').click(function () {
        $.ajax({
            url: '/ajax/qualitycontrol/datarestore',
            data: { 'file': tempfile, 'trait': trait_selected },
            success: function (r) {
                $('#working_modal').modal("hide");
                if (r.message) {
                    alert(r.message); 
                    return;
                } else {
                    var trialNames = r.data;
                    $.ajax({
                        url: '/ajax/qualitycontrol/restoreoutliers',
                        method: "POST",
                        data: {"outliers": JSON.stringify(trialNames), "trait":trait_selected,
                        },
                        success: function (r) {
                            if (r.is_curator === 1) {
                                $('#restore_outliers_button').prop("disabled", false);
                                alert("Data successfully restored!");
                            } else {
                                $('#restore_outliers_button').prop("disabled", true);
                                alert("Only curators are allowed undo validated trial. Please contact a curator.");
                            }
                        },
                        error: function () {
                            alert('Error during restore!');
                        }
                    });
                }
            },
            error: function () {
                alert('Error during AJAX request!');
            }
        });
    });

}

function populateOtherTraits(traitsHTML, traitSelected) {
    const $traitContainer = $('#other_traits');
    $traitContainer.empty();

    const $traits = $(traitsHTML);  // Parse the HTML into jQuery elements
    const traitsArray = $traits.map(function() {
        return $(this).val();  // Get the value of each trait input element
    }).get();  // Convert jQuery object to a regular array

    const filteredTraits = traitsArray.filter(trait => !traitSelected.includes(trait));

    filteredTraits.forEach(trait => {
        const $checkbox = $('<input>', {
            type: 'checkbox',
            name: 'new_trait_options',
            value: trait
        });

        const $label = $('<label>').text(trait);

        const $div = $('<div>').append($checkbox).append($label);
        $traitContainer.append($div);
    });
}

var globalOutliers = [];

function updateBoxplot(isFixed, minValue, maxValue) {
    // Fetch the selected trait and tempfile
    var trait_selected = $('#trait_select').val();
    var tempfile = $('#tempfile').html();

    const outlierMultiplier = $("#outliers_range").slider("value") || 1.5;

    // Perform an AJAX call to fetch the actual data
    $.ajax({
        url: '/ajax/qualitycontrol/grabdata',  // Adjust this URL if needed
        data: { 'file': tempfile, 'trait': trait_selected },  // Send both tempfile and trait
        success: function (response) {
            const boxplotData = response.data || [];  // Adjust based on the actual response structure
            const result = drawBoxplot(boxplotData, trait_selected, outlierMultiplier, isFixed, minValue, maxValue);
            const outliers = result.outliers || [];
            populateCleanTable(boxplotData, outliers, trait_selected);
            globalOutliers = outliers;
        },

        error: function (jqXHR, textStatus, errorThrown) {
            console.error('AJAX request failed: ', textStatus, errorThrown);
            alert('Error fetching data for boxplot: ' + errorThrown);
        }
    });
}

function calculateStatistics(values) {
    if (values.length === 0) return { min: null, max: null, sd: null, cv: null };

    const min = Math.min(...values);
    const max = Math.max(...values);
    const mean = values.reduce((acc, val) => acc + val, 0) / values.length;
    const sd = Math.sqrt(values.reduce((acc, val) => acc + Math.pow(val - mean, 2), 0) / values.length);
    const cv = (sd / mean) * 100;

    return { min, max, mean, sd, cv };
}


function populateOutlierTable(data, trait) {
    const tableBody = document.querySelector("#outlier_table tbody"); 

    tableBody.innerHTML = ''; // Clear existing table content
    const groupedData = {};

    data.forEach(item => {
        const valueStr = item[trait] || '';
        const value = parseFloat(valueStr.replace(',', '.'));


        if (item.locationDbId && item.studyName && !isNaN(value)) {
            const identifier = `${item.locationDbId}-${item.studyName}`;

            if (!groupedData[identifier]) {
                groupedData[identifier] = {
                    locationDbId: item.locationDbId,
                    locationName: item.locationName,
                    studyName: item.studyName,
                    values: [] 
                };
            }
            groupedData[identifier].values.push(value);
        }
    });


    for (const key in groupedData) {
        const dataGroup = groupedData[key];
        const stats = calculateStatistics(dataGroup.values); 
        const row = tableBody.insertRow();
        const cell1 = row.insertCell(0);
        const cell2 = row.insertCell(1);
        const cell3 = row.insertCell(2);
        const cell4 = row.insertCell(3);
        const cell5 = row.insertCell(4);
        const cell6 = row.insertCell(5);
        const cell7 = row.insertCell(6);
        const cell8 = row.insertCell(7);

        // Populate the cells with data, checking for null or undefined values
        cell1.innerHTML = dataGroup.locationDbId || 'N/A';
        cell2.innerHTML = dataGroup.locationName || 'N/A';
        cell3.innerHTML = dataGroup.studyName || 'N/A';
        cell4.innerHTML = stats.min !== null ? stats.min.toFixed(2) : 'N/A';
        cell5.innerHTML = stats.max !== null ? stats.max.toFixed(2) : 'N/A';
        cell6.innerHTML = stats.mean !== null ? stats.mean.toFixed(2) : 'N/A';
        cell7.innerHTML = stats.sd !== null && !isNaN(stats.sd) ? stats.sd.toFixed(2) : 'N/A';
        cell8.innerHTML = stats.cv !== null && !isNaN(stats.cv) ? stats.cv.toFixed(2) + '%' : 'N/A';
    }
}


function populateCleanTable(data, outliers, trait) {
    const tableBody = document.querySelector("#clean_table tbody");
    tableBody.innerHTML = ''; // Clear existing table content

    // Create a Set of outlier plot names for quick lookup
    const outlierPlotNames = new Set(outliers.map(outlier => outlier.plotName));
    const groupedData = {};

    data.forEach(item => {
        if (outlierPlotNames.has(item.observationUnitName)) {
            return; // Skip this item if it's an outlier
        }

        // Extract the value from the specified trait
        const valueStr = item[trait] || ''; 
        const value = parseFloat(valueStr.replace(',', '.')); 

        if (item.locationDbId && item.studyName) {
            const identifier = `${item.locationDbId}-${item.studyName}`;
            if (!groupedData[identifier]) {
                groupedData[identifier] = {
                    locationDbId: item.locationDbId,
                    locationName: item.locationName,
                    studyName: item.studyName,
                    values: []
                };
            }
            groupedData[identifier].values.push(value);
        }
    });

    for (const key in groupedData) {
        const dataGroup = groupedData[key];
        const stats = calculateStatistics(dataGroup.values); 
        const row = tableBody.insertRow();
        const cell1 = row.insertCell(0);
        const cell2 = row.insertCell(1);
        const cell3 = row.insertCell(2);
        const cell4 = row.insertCell(3);
        const cell5 = row.insertCell(4);
        const cell6 = row.insertCell(5);
        const cell7 = row.insertCell(6);
        const cell8 = row.insertCell(7);

        // Populate the cells with data, checking for null or undefined values
        cell1.innerHTML = dataGroup.locationDbId || 'N/A';
        cell2.innerHTML = dataGroup.locationName || 'N/A';
        cell3.innerHTML = dataGroup.studyName || 'N/A';
        cell4.innerHTML = stats.min !== null ? stats.min.toFixed(2) : 'N/A';
        cell5.innerHTML = stats.max !== null ? stats.max.toFixed(2) : 'N/A';
        cell6.innerHTML = stats.mean !== null ? stats.mean.toFixed(2) : 'N/A';
        cell7.innerHTML = stats.sd !== null && !isNaN(stats.sd) ? stats.sd.toFixed(2) : 'N/A';
        cell8.innerHTML = stats.cv !== null && !isNaN(stats.cv) ? stats.cv.toFixed(2) + '%' : 'N/A';
    }
}



function drawBoxplot(data, selected_trait, outlierMultiplier, isFixedMinMax, minVal, maxVal) {
  const groupedData = d3.nest()
    .key(d => d.locationDbId)
    .entries(data);
  if (outlierMultiplier === null) { outlierMultiplier = 1.5; }

  let allOutliers = [];

  const boxplotData = groupedData.map(group => {
    const values = group.values.map(d => parseFloat(d[selected_trait])).filter(d => d != null && !isNaN(d));

    if (values.length < 4) {
      return {
        locationDbId: group.key,
        values: [],
        outliers: [],
        q1: null,
        q3: null,
        iqr: null,
        lowerBound: null,
        upperBound: null,
        min: null,
        max: null,
        median: null
      };
    }

    values.sort(d3.ascending);
    const q1 = d3.quantile(values, 0.25);
    const q3 = d3.quantile(values, 0.75);
    const iqr = Math.max(0, q3 - q1);

    // Calculate lower and upper bounds based on isFixedMinMax
    let lowerBound, upperBound;
    if (isFixedMinMax) {
      // Use the provided minVal and maxVal for all locations
      lowerBound = minVal;
      upperBound = maxVal;
    } else {
      lowerBound = q1 - outlierMultiplier * iqr;
      upperBound = q3 + outlierMultiplier * iqr;
    }
    

    const median = d3.quantile(values, 0.5);

    const outliers = values.filter(v => v < lowerBound || v > upperBound);

    const groupOutliers = outliers.flatMap(value => {
      return group.values
        .filter(v => parseFloat(v[selected_trait]) === value)
        .map(match => ({
          locationDbId: group.key,
          studyName: match.studyName,
          locationName: match.locationName,
          plotName: match.observationUnitName,
          trait: selected_trait,
          value: value
        }));
    });

    allOutliers = allOutliers.concat(groupOutliers);

    return {
      locationDbId: group.key,
      values,
      outliers,
      q1,
      q3,
      iqr,
      lowerBound,
      upperBound,
      min: d3.min(values),
      max: d3.max(values),
      median
    };
  });


    // Drawing the boxplot
    const margin = {top: 10, right: 30, bottom: 50, left: 40},
          width = 800 - margin.left - margin.right,
          height = 400 - margin.top - margin.bottom;

    d3.select("#trait_boxplot").select("svg").remove();
    
    const svg = d3.select("#trait_boxplot")
        .append("svg")
        .attr("width", width + margin.left + margin.right)
        .attr("height", height + margin.top + margin.bottom)
        .append("g")
        .attr("transform", "translate(" + margin.left + "," + margin.top + ")");

    const x = d3.scaleLinear()
    .domain([d3.min(boxplotData, d => d.min), d3.max(boxplotData, d => d.max)])
    .range([0, width]);

    const y = d3.scaleBand()
        .domain(boxplotData.map(d => d.locationDbId))
        .range([0, height])
        .padding(0.1);

    const boxWidth = y.bandwidth() / 2; 

    const boxplotGroup = svg.selectAll(".boxplot")
        .data(boxplotData.filter(d => d.values.length > 0)) // Skip empty groups
        .enter().append("g")
        .attr("class", "boxplot")
        .attr("transform", d => "translate(0," + (y(d.locationDbId) + y.bandwidth() / 2) + ")");

    // Draw boxes
    boxplotGroup.append("rect")
        .attr("x", d => x(d.q1))
        .attr("y", -boxWidth / 2)
        .attr("width", d => x(d.q3) - x(d.q1))
        .attr("height", boxWidth)
        .attr("stroke", "black")
        .attr("fill", "#9c9ede");

    // Draw median line
    boxplotGroup.append("line")
        .attr("x1", d => x(d.median))
        .attr("x2", d => x(d.median))
        .attr("y1", -boxWidth / 2)
        .attr("y2", boxWidth / 2)
        .attr("stroke", "black");

    // Draw whiskers
    boxplotGroup.append("line")
        .attr("x1", d => x(d.min))
        .attr("x2", d => x(d.max))
        .attr("y1", 0)
        .attr("y2", 0)
        .attr("stroke", "black");

    // X-axis
    svg.append("g")
        .attr("transform", `translate(0,${height})`) // Position at the bottom
        .call(d3.axisBottom(x))
        .selectAll("text") // Add rotation if labels overlap
        .attr("transform", "translate(0,5)")
        .style("text-anchor", "middle");

    // X-axis label
    svg.append("text")
        .attr("class", "x-label")
        .attr("text-anchor", "middle")
        .attr("x", width / 2)
        .attr("y", height + margin.bottom - 10) // Ensure it's visible within margins
        .text(selected_trait); // Add trait name

    // Y-axis
    svg.append("g")
        .call(d3.axisLeft(y));

    // Y-axis label
    svg.append("text")
        .attr("class", "y-label")
        .attr("text-anchor", "middle")
        .attr("x", -height / 2) // Position in the center of the Y-axis
        .attr("y", -margin.left + 10) // Ensure it's within margins
        .attr("transform", "rotate(-90)") // Rotate to match Y-axis orientation
        .text("Location ID");


    // Draw individual points with jitter
    const pointGroup = svg.selectAll(".point")
        .data(boxplotData.filter(d => d.values.length > 0)) // Skip empty groups
        .enter().append("g")
        .attr("class", "point")
        .attr("transform", d => "translate(0," + y(d.locationDbId) + ")");

    // Create a tooltip div
    const tooltip = d3.select("body").append("div")
        .attr("class", "tooltip")
        .style("opacity", 0)
        .style("position", "absolute") // Ensure it's positioned relative to the cursor
        .style("background", "#fff") // Tooltip background color
        .style("border", "1px solid #ccc") // Border for better visibility
        .style("border-radius", "4px")
        .style("padding", "5px") // Add padding for text readability
        .style("pointer-events", "none"); // Prevent mouse interaction with the tooltip

    // Draw circles for all points (including outliers)
    pointGroup.selectAll("circle")
        .data(d => d.values.map((value, index) => ({
            value: value,
            isOutlier: value < d.lowerBound || value > d.upperBound, // Check for outliers
            plotName: d.plotName // Ensure this is correct
        })))
        .enter().append("circle")
        .attr("cx", d => x(d.value))
        .attr("cy", d => (Math.random() - 0.5) * boxWidth + boxWidth / 2) // Center and add jitter
        .attr("r", 3) // Set a fixed radius for points
        .attr("fill", d => d.isOutlier ? "#d9534f" : "#5cb85c") // Outliers are red, non-outliers are green
        .on("mouseover", function(event, d) {
            tooltip.transition()
                .duration(200)
                .style("opacity", .9); // Fade in the tooltip

            // Add plotName and value to the tooltip content
            tooltip.html(`<strong>Plot:</strong> ${d.plotName}<br><strong>Value:</strong> ${d.value}`)
                .style("left", (event.pageX + 10) + "px") // Position tooltip near the cursor
                .style("top", (event.pageY - 28) + "px");
        })
        .on("mouseout", function(d) {
            tooltip.transition()
                .duration(500)
                .style("opacity", 0); // Fade out the tooltip
        });




    // Return both the boxplot data and the outliers
    return {
        boxplotData: boxplotData,
        outliers: allOutliers.length > 0 ? allOutliers : [{
            studyName: data.length > 0 ? data[0].studyName : null, // Preserve study name if data exists
            trait: selected_trait,
            locationDbId: null,
            locationName: null,
            plotName: null,
            value: null
        }]
    };

}



function get_dataset_id() {
    var selected_datasets = [];
    jQuery('input[name="qc_dataset_select_checkbox"]:checked').each(function () {
        selected_datasets.push(jQuery(this).val());
    });
    if (selected_datasets.length < 1) {
        alert('Please select at least one dataset!');
        return false;
    } else if (selected_datasets.length > 1) {
        alert('Please select only one dataset!');
        return false;
    } else {
        var dataset_id = selected_datasets[0];
        return dataset_id;
    }
}

function populateTraitDropdown(selectedVariableHTML) {
    var traitSelect = $('#trait_select');  // Dropdown element
    traitSelect.empty();  // Clear previous options

    // Add default "Select a trait" option
    traitSelect.append('<option disabled selected value="">Select a trait</option>');

    // Create a temporary div to hold the HTML string
    var tempDiv = $('<div>').html(selectedVariableHTML);

    // Extract values from the checkboxes in the HTML
    tempDiv.find('input.trait_box').each(function () {
        var traitValue = $(this).val(); 
        traitSelect.append($('<option>', {
            value: traitValue,  
            text: traitValue    
        }));
    });
}
