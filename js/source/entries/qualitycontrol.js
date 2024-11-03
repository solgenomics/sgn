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
                    updateBoxplot();  // Update the boxplot when the slider value changes
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
                        console.log("AJAX response:", r);  // Log full response for debugging

                        if (r.selected_variable) {
                            console.log("Selected Variable HTML:", r.selected_variable);  // Debugging log
                            populateTraitDropdown(r.selected_variable);  // Populate dropdown with traits
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
    
    let outliers = [];
    $('#selected_variable').on('change', function () {
        var trait_selected = $('#trait_select').val();  // Get the selected trait from the dropdown

        if (!trait_selected) {
            $('#trait_histogram').html('Please select a trait to see the boxplot!');
            return;
        }

        // Fetch tempfile value
        var tempfile = $('#tempfile').html();  

        // Check if tempfile is not empty
        if (!tempfile || tempfile.trim() === '') {
            return; // Exit if tempfile is empty
        }

        var outlierMultiplier = $('#outliers_range').slider("value");
        if (!outlierMultiplier || isNaN(outlierMultiplier)) {
            outlierMultiplier = 1.5; // Set default value
        }

        // Proceed with the AJAX call for grabbing data
        $.ajax({
            url: '/ajax/qualitycontrol/grabdata',
            data: { 'file': tempfile },
            success: function (r) {
                $('#working_modal').modal("hide");
                const result = drawBoxplot(r.data, trait_selected, outlierMultiplier );
                outliers = result.outliers;  // Extract the outliers
                console.log(outliers); 
                populateOutlierTable(outliers);
            },
            error: function (e) {
                alert('Error during AJAX request!');
            }
        });

    });

    $('#store_outliers_button').click(function () {
        $.ajax({
            url: '/ajax/qualitycontrol/storeoutliers',  
            method: "POST",  
            data: {"outliers": JSON.stringify(uniqueOutliers),
            },
            success: function(response) {
                alert('Outliers saved successfully!');  // Success message
                console.log(response);  // Log server response
            },
            error: function(xhr, status, error) {
                alert('Error saving outliers: ' + error);  // Error message
                console.log(xhr, status);  // Log error details
            }
        });
    });


}

let currentPage = 1;
let uniqueOutliers;
const rowsPerPage = 10;


function populateOutlierTable(outliers) {
    const tableBody = document.querySelector("#outlier_table tbody");

    // Clear the current table body
    tableBody.innerHTML = '';

    // Ensure outliers is an array to avoid errors
    if (!Array.isArray(outliers)) {
        console.warn("Expected an array of outliers, but received:", outliers);
        return;
    }

    // Create a Set to track unique identifiers for filtering duplicates
    const uniqueIdentifiers = new Set();
    uniqueOutliers = []; // Store unique outliers for pagination

    // Insert rows with outlier data
    outliers.forEach(outlier => {
        // Create a unique identifier for the outlier
        const identifier = `${outlier.locationDbId}-${outlier.plotName}`;
        
        // Check if this identifier has already been added to the Set
        if (!uniqueIdentifiers.has(identifier)) {
            uniqueIdentifiers.add(identifier); // Mark this identifier as seen
            uniqueOutliers.push(outlier); // Store unique outliers
            
            const row = tableBody.insertRow();
            const cell1 = row.insertCell(0);
            const cell2 = row.insertCell(1);
            const cell3 = row.insertCell(2);
            const cell4 = row.insertCell(3);
            const cell5 = row.insertCell(4);

            cell1.innerHTML = outlier.locationDbId || 'N/A';
            cell2.innerHTML = outlier.locationName || 'N/A';
            cell3.innerHTML = outlier.plotName || 'N/A';
            cell4.innerHTML = outlier.trait || 'N/A';
            cell5.innerHTML = outlier.value || 'N/A';
        }
    });

    // Update pagination controls with the count of unique outliers
    updatePaginationControls(uniqueOutliers.length);
}


function updatePaginationControls(totalItems) {
    const paginationControls = document.getElementById("pagination_controls");
    paginationControls.innerHTML = ''; // Clear previous controls

    const totalPages = Math.ceil(totalItems / rowsPerPage);

    // Create Previous button
    const prevButton = document.createElement('button');
    prevButton.innerHTML = 'Previous';
    prevButton.disabled = currentPage === 1; // Disable if on the first page
    prevButton.addEventListener('click', () => {
        if (currentPage > 1) {
            currentPage--;
            populateOutlierTable(outliersGlobal); // Use the global outliers array
        }
    });
    paginationControls.appendChild(prevButton);

    // Display page numbers
    const pageButtons = [];
    if (totalPages > 1) {
        for (let i = 1; i <= Math.min(totalPages, 3); i++) {
            const pageButton = document.createElement('button');
            pageButton.innerHTML = i;
            pageButton.classList.add('page-button');
            if (i === currentPage) {
                pageButton.disabled = true; // Disable the current page button
            }
            pageButton.addEventListener('click', () => {
                currentPage = i;
                populateOutlierTable(outliersGlobal); // Use the global outliers array
            });
            paginationControls.appendChild(pageButton);
            pageButtons.push(pageButton);
        }

        // Check if there are more pages and add ellipsis if needed
        if (totalPages > 3) {
            const ellipsis = document.createElement('span');
            ellipsis.innerHTML = '...';
            paginationControls.appendChild(ellipsis);

            // Last page button
            const lastPageButton = document.createElement('button');
            lastPageButton.innerHTML = totalPages;
            lastPageButton.addEventListener('click', () => {
                currentPage = totalPages;
                populateOutlierTable(outliersGlobal); // Use the global outliers array
            });
            paginationControls.appendChild(lastPageButton);
        }
    }
}


function updateBoxplot() {
    // Fetch the selected trait and tempfile
    var trait_selected = $('#trait_select').val();
    var tempfile = $('#tempfile').html();

    if (!trait_selected || !tempfile || tempfile.trim() === '') {
        console.log("Either trait or tempfile is missing!");
        return;
    }

    const outlierMultiplier = $("#outliers_range").slider("value") || 1.5;

    // Perform an AJAX call to fetch the actual data
    $.ajax({
        url: '/ajax/qualitycontrol/grabdata',  // Adjust this URL if needed
        data: { 'file': tempfile, 'trait': trait_selected },  // Send both tempfile and trait
        success: function (response) {

            const boxplotData = response.data || [];  // Adjust based on the actual response structure
            drawBoxplot(boxplotData, trait_selected, outlierMultiplier);
            const result = drawBoxplot(boxplotData, trait_selected, outlierMultiplier);

            const outliers = result.outliers || [];
            console.log("Outliers identified:", outliers);

            populateOutlierTable(outliers);

        },

        error: function (jqXHR, textStatus, errorThrown) {
            console.error('AJAX request failed: ', textStatus, errorThrown);
            alert('Error fetching data for boxplot: ' + errorThrown);
        }
    });
}




function drawBoxplot(data, selected_trait, outlierMultiplier) {
    const groupedData = d3.nest()
        .key(d => d.locationDbId)
        .entries(data);
    if (outlierMultiplier === null){outlierMultiplier = 1.5}    
    let allOutliers = [];  // Collect all outliers here

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
                upperBound: null
            };
        }

        values.sort(d3.ascending);
        const q1 = d3.quantile(values, 0.25);
        const q3 = d3.quantile(values, 0.75);
        const iqr = Math.max(0, q3 - q1);
        const lowerBound = q1 - outlierMultiplier * iqr;
        const upperBound = q3 + outlierMultiplier * iqr;

        const outliers = values.filter(v => v < lowerBound || v > upperBound);

        console.log(`Group ${group.key} - Q1: ${q1}, Q3: ${q3}, IQR: ${iqr}, Lower Bound: ${lowerBound}, Upper Bound: ${upperBound}`);

        // Collect outlier data with relevant information
        if (outliers.length > 0) {
            const groupOutliers = outliers.map(value => ({
                locationDbId: group.key,
                locationName: group.values.find(v => parseFloat(v[selected_trait]) === value).locationName,
                plotName: group.values.find(v => parseFloat(v[selected_trait]) === value).observationUnitName,
                trait: selected_trait,
                value: value
            }));
            allOutliers = allOutliers.concat(groupOutliers);
        }

        return {
            locationDbId: group.key,
            values: values,
            min: d3.min(values),
            q1: q1,
            median: d3.median(values),
            q3: q3,
            max: d3.max(values),
            lowerBound: lowerBound,
            upperBound: upperBound,
            outliers: outliers
        };
    });

    // Drawing the boxplot
    const margin = {top: 10, right: 30, bottom: 50, left: 40},
          width = 800 - margin.left - margin.right,
          height = 400 - margin.top - margin.bottom;

    d3.select("#trait_histogram").select("svg").remove();
    
    const svg = d3.select("#trait_histogram")
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

    svg.append("g")
        .attr("transform", "translate(0," + height + ")")
        .call(d3.axisBottom(x));

    svg.append("g")
        .call(d3.axisLeft(y));

    const boxWidth = y.bandwidth() / 2; // Width of the box

    const boxplotGroup = svg.selectAll(".boxplot")
        .data(boxplotData)
        .enter().append("g")
        .attr("class", "boxplot")
        .attr("transform", d => "translate(0," + y(d.locationDbId) + ")");

    // Draw boxes
    boxplotGroup.append("rect")
        .attr("x", d => {
            if (d.q1 !== null && d.q3 !== null) {
                return x(d.q1);
            }
            return 0; // Default to 0 if quartiles are not valid
        })
        .attr("y", boxWidth / 2)
        .attr("height", boxWidth)
        .attr("width", d => {
            if (d.q1 !== null && d.q3 !== null) {
                const width = x(d.q3) - x(d.q1);
                return Math.max(0, width); // Ensure no negative width
            }
            return 0; // Default to 0 if quartiles are not valid
        })
        .attr("fill", "lightgray");

    // Draw median line
    boxplotGroup.append("line")
        .attr("x1", d => x(d.median))
        .attr("x2", d => x(d.median))
        .attr("y1", 0)
        .attr("y2", boxWidth)
        .attr("stroke", "black");

    // Draw whiskers
    boxplotGroup.append("line")
        .attr("x1", d => x(d.min))
        .attr("x2", d => x(d.max))
        .attr("y1", boxWidth / 2)
        .attr("y2", boxWidth / 2)
        .attr("stroke", "black");

    // Draw individual points with jitter
    const pointGroup = svg.selectAll(".point")
        .data(boxplotData)
        .enter().append("g")
        .attr("class", "point")
        .attr("transform", d => "translate(0," + y(d.locationDbId) + ")");

    // Draw circles for all points (including outliers)
    pointGroup.selectAll("circle")
        .data(d => d.values.map(value => ({
            value: value, 
            isOutlier: value < d.lowerBound || value > d.upperBound // Check for outliers
        }))) 
        .enter().append("circle")
        .attr("cx", d => x(d.value))
        .attr("cy", d => boxWidth / 2 + (Math.random() - 0.5) * 10) // Add jitter
        .attr("r", 3) // Set a fixed radius for points
        .attr("fill", d => d.isOutlier ? "#d9534f" : "#5cb85c" ); // Outliers are red, non-outliers are blue

    // Return both the boxplot data and the outliers
    return {
        boxplotData: boxplotData,
        outliers: allOutliers
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

