
var page_formats = {};
page_formats["Select a page format"] = {};
page_formats["US Letter PDF"] = {
    page_width: 611,
    page_height: 790.7,
    label_sizes: {
            'Select a label format' : {},
            '1" x 2 5/8"': {
                label_width: 189,
                label_height: 72,
                left_margin: 13.68,
                top_margin: 36.7,
                horizontal_gap: 10,
                vertical_gap: 0,
                number_of_columns: 3,
                number_of_rows: 10
            },
            '1" x 4"': {
                label_width: 288,
                label_height: 72,
                left_margin: 13.68,
                top_margin: 36.7,
                horizontal_gap: 10,
                vertical_gap: 0,
                number_of_columns: 2,
                number_of_rows: 10
            },
            '1 1/3" x 4"': {
                label_width: 288,
                label_height: 96,
                left_margin: 13.68,
                top_margin: 36.7,
                horizontal_gap: 10,
                vertical_gap: 0,
                number_of_columns: 2,
                number_of_rows: 7
            },
            '2" x 2 5/8"': {
                label_width: 189,
                label_height: 144,
                left_margin: 13.68,
                top_margin: 36.7,
                horizontal_gap: 10,
                vertical_gap: 0,
                number_of_columns: 3,
                number_of_rows: 5
            },
            'Custom': {
                label_width: 0,
                label_height: 0,
                left_margin: 13.68,
                top_margin: 36.7,
                horizontal_gap:0,
                vertical_gap:0,
                number_of_columns:1,
                number_of_rows:1
            }
        }
};


page_formats["A4 PDF"] = {
    page_width: 595.3,
    page_height: 841.9,
    label_sizes: {
            'Select a label format' : {},
            'Custom' : {
                label_width: 0,
                label_height: 0,
                left_margin: 0,
                top_margin: 0,
                horizontal_gap:0,
                vertical_gap:0,
                number_of_columns:1,
                number_of_rows:1
            }
        }
};

page_formats["Zebra printer file"] = {
    label_sizes: {
            'Select a label format' : {},
            '1 1/4" x 2"': {
                label_width: 144,
                label_height: 90,
            },
            'Custom' : {
                label_width: 0,
                label_height: 0,
                left_margin: 0,
                top_margin: 0,
                horizontal_gap:0,
                vertical_gap:0,
                number_of_columns:1,
                number_of_rows:1
            }
        }
};

page_formats["Custom"] = {
    label_sizes: {
            'Select a label format' : {},
            'Custom' : {
                label_width: 0,
                label_height: 0,
                left_margin: 0,
                top_margin: 0,
                horizontal_gap:0,
                vertical_gap:0,
                number_of_columns:1,
                number_of_rows:1
            }
        }
};

var label_options = {};
label_options["Select an element type"] = { name: "Select an element type" };
label_options["PDFText"] = {
    name: "Text (PDF)",
    sizes: {
        min: 1,
        max: 144,
        step: 1,
        value: 32,
    },
};

label_options["ZebraText"] = {
    name: "Text (Zebra)",
    sizes: {
        "10": 9,
        "20": 18,
        "30": 27,
        "40": 36,
        "50": 45,
        "60": 54,
        "70": 63,
        "80": 72
    }
};

label_options["Code128"] = {
    name: "1D Barcode (Code128)",
    sizes: {
        "One": 1,
        "Two": 2,
        "Three": 3,
        "Four": 4
    }
};

label_options["QRCode"] = {
    name: "2D Barcode (QRCode)",
    sizes: {
        "Four": 4,
        "Five": 5,
        "Six": 6,
        "Seven": 7,
        "Eight": 8,
        "Nine": 9,
        "Ten": 10
    }
};

font_styles = {
    "Courier": "font-family:courier;",
    "Courier-Bold": "font-family:courier;font-weight:bold;",
    "Courier-Oblique": "font-family:courier;font-style: oblique;",
    "Courier-BoldOblique": "font-family:courier;font-weight:bold;font-style: oblique;",
    "Helvetica": "font-family:helvetica;",
    "Helvetica-Bold": "font-family:helvetica;font-weight:bold;",
    "Helvetica-Oblique": "font-family:helvetica;font-style: oblique;",
    "Helvetica-BoldOblique": "font-family:helvetica;font-weight:bold;font-style: oblique;",
    "Times": "font-family:times;",
    "Times-Bold": "font-family:times;font-weight:bold;",
    "Times-Italic": "font-family:times;font-style: italic;",
    "Times-BoldItalic": "font-family:times;font-weight:bold;font-style: italic;"
}

var add_fields = {}; // retrieved when data source is selected
var num_units = 0; // updated when data source is selected

resizer_behaviour = d3.behavior.drag().on(
    "drag",
    function(d, i) {
        var target = d;
        var bb = getTransGroupBounds(target.node())
        var mx = d3.event.x;
        var my = d3.event.y;
        // if (d3.select("#d3-snapping-check").property("checked")){
        mx = Math.round(mx / doSnap.size) * doSnap.size
        my = Math.round(my / doSnap.size) * doSnap.size
            // }
        var xexpand = (mx - bb.x) / bb.width
        var yexpand = (my - bb.y) / bb.height
        expand = Math.max(xexpand, yexpand)
        if (!isNaN(expand)) {
            target.call(doTransform, function(state, selection) {
                var expX = state.scale[0] * expand;
                var expY = state.scale[1] * expand;
                var mi = Math.min(expX * bb.width, expY * bb.height);
                if (mi <= 3) {
                    expX = state.scale[0];
                    expY = state.scale[1];
                }
                state.scale[0] = expX;
                state.scale[1] = expY;
            });
        }
        var newbb = getTransGroupBounds(target.node())
        d3.select(this.parentNode).select(".selection-tool-outline")
            .attr({
                x: newbb.x,
                y: newbb.y,
                width: newbb.width,
                height: newbb.height,
            })
        d3.select(this.parentNode).select(".selection-tool-resizer")
            .attr({
                x: newbb.x + newbb.width - 3,
                y: newbb.y + newbb.height - 3,
            })
        d3.select(this.parentNode).select(".selection-tool-remover")
            .attr({
                x: newbb.x - 3,
                y: newbb.y - 3,
            })
    });

//set up drag behaviour
var drag_behaviour = d3.behavior.drag().on(
    "drag",
    function() {
        var o = d3.select(this)
            .call(doTransform, function(state, selection) {
                state.translate[0] += d3.event.dx;
                state.translate[1] += d3.event.dy;
            });
    });

$(document).ready(function($) {

    initializeDrawArea();
    $('#source_select').focus();

    //Add link to docs
    // jQuery('#pagetitle_h3').append('&nbsp;<a id="label_designer_docs_link" href="http://solgenomics.github.io/sgn/03_managing_breeding_data/03_12.html"><span class="glyphicon glyphicon-info-sign"></span></a>');

    // Always focus on autofocus elements when modals are opened.
    $('.modal').on('shown.bs.modal', function() {
        $(this).find('[autofocus]').folabel
    });

    $('#d3-save-button').click(function() {
        saveLabelDesign();
    });

    $('#design_label_button').click(function() {
        $("#d3-draw-area").prependTo("#save_and_download");
    });

    $('#design_label_button').click(function() {
        $("#d3-draw-area").prependTo("#save_and_download");
        $(".workflow-complete").click(function() {
            var title = $(this).children().text();
            //console.log("workflow element with title "+title+" was just clicked\n");

            if (title == "Design Your Label") {
                $("#d3-draw-area").prependTo("#d3-draw-div");
            } else if (title == "More Options, Save, And Download") {
                $("#d3-draw-area").prependTo("#save_and_download");
            }

        });
        $("ol.workflow-prog li").click(function() {
            var title = $(this).children().text();
            //console.log("workflow element with title "+title+" was just clicked\n");
            if (title == "More Options, Save, And Download") {
                $("#d3-draw-area").prependTo("#save_and_download");
            }

        });
    });

    getDataSourceSelect();

    $("#edit_additional_settings").on("click", function() {
        $('#editAdditionalSettingsModal').modal('show');
    });

    $(document).on("change", "#source_select", function() {

        var name = jQuery('#source_select :selected').text();
        jQuery('#selected_data_source').text(name);

        var data_type = $('#source_select :selected').parent().attr('label');

        // updateFields(data_type, this.value, '');

        if (data_type == 'Field Trials') {
            jQuery.ajax({
                url: '/ajax/breeders/trial/'+this.value+'/has_data_levels',
                method: 'GET',
                beforeSend: function() {
                    disable_ui();
                },
                complete: function() {
                    enable_ui();
                    jQuery('#page_format').focus();
                },
                success: function(response) {
                    var html = '<select class="form-control" id="label_designer_data_level" ><option value="" selected>Select a Level</option><option value="plots">Plot</option>';
                    if(response.has_plants){
                        html = html + '<option value="plants">Plant</option>';
                    }
                    if(response.has_subplots){
                        html = html + '<option value="subplots">Subplot</option>';
                    }
                    if(response.has_tissue_samples){
                        html = html + '<option value="tissue_samples">Tissue Sample</option>';
                    }
                    html = html + '</select>';
                    jQuery('#label_designer_data_level_select_div').html(html);
                    jQuery("#label_designer_data_level").focus();
                },
                error: function(response) {
                    alert('There was a problem checking the data levels available for your field trial. Please contact us.');
                }
            });
        } else if (data_type == 'Genotyping Plates') {

            jQuery('#label_designer_data_level_select_div').html('<select class="form-control" id="label_designer_data_level" ><option value="" selected>Select a Level</option><option value="plate">Plate</option></select>');
            jQuery("#label_designer_data_level").focus();

        } else if (data_type == 'Crossing Experiments') {

            jQuery('#label_designer_data_level_select_div').html('<select class="form-control" id="label_designer_data_level" ><option value="" selected>Select a Level</option><option value="crosses">Cross</option></select>');
            jQuery("#label_designer_data_level").focus();

        } else if ((data_type == 'Lists') || (data_type == 'Public Lists')) {

            var html = '<select class="form-control" id="label_designer_data_level" ><option value="" selected>Select a Level</option><option value="list">List Items</option>';
            // Check list type, if Plot, Plant, or Tissue Sample add details option
            var name = $('#source_select :selected').text();

            jQuery.ajax({
                url: '/list/exists',
                data: { 'name': name },
                beforeSend: function() {
                    disable_ui();
                },
                complete: function() {
                    enable_ui();
                    jQuery('#page_format').focus();
                },
                success: function(response) {
                    if (response.list_type == 'plots') {
                        html = html + '<option value="plots">Plot Details</option>';
                    } else if (response.list_type == 'subplots') {
                        html = html + '<option value="subplots">Subplot Details</option>';
                    } else if (response.list_type == 'plants') {
                        html = html + '<option value="plants">Plant Details</option>';
                    } else if (response.list_type == 'tissue_samples') {
                        html = html + '<option value="tissue_samples">Tissue Sample Details</option>';
                    } else if (response.list_type == 'crosses') {
                        html = html + '<option value="crosses">Cross Details</option>';
                    } else if (response.list_type == 'identifier_generation') {
                        // remove list item select options and add options for each id batch
                        html = '<select class="form-control" id="label_designer_data_level" ><option value="" selected>Select a Level</option>';
                        var lo = new CXGN.List();
                        var list_data = lo.getListData(response.list_id);
                        var elements = list_data.elements;
                        var identifier_object = JSON.parse(elements[0][1]);
                        var records = identifier_object.records;
                        for (var x = 0; x < records.length; x++) {
                            var generated_identifiers = records[x].generated_identifiers;
                            if (generated_identifiers) {
                                //console.log("current identifiers are: "+generated_identifiers);
                                var min = generated_identifiers.shift();
                                var max = generated_identifiers.pop();
                                var id = records[x].next_number;
                                html = html + '<option value="batch-'+id+'">ID Batch '+min+' - '+max+'</option>';
                            }
                        }
                    }
                    html = html + '</select>';
                    jQuery('#label_designer_data_level_select_div').html(html);
                    jQuery("#label_designer_data_level").focus();
                },
                error: function(response) {
                    alert('There was a problem checking the data levels available for your field trial. Please contact us.');
                }
            });
        }
    });

    jQuery(document).on('change', '#label_designer_data_level', function(){
        var data_type = $('#source_select :selected').parent().attr('label');
        var source_id = jQuery('#source_select').val();

        var name = jQuery('#label_designer_data_level :selected').text();
        jQuery('#selected_data_level').text(name);

        if (this.value) { jQuery('#select_datasource_button').prop('disabled', false); }
        updateFields(data_type, source_id, this.value);
    });

    jQuery(document).on('change', 'input[type=radio][name=optradio]', function(){
        if (this.value == 'saved') {
            document.getElementById("design_list").style.display = "inline";
        } else {
            document.getElementById("design_list").style.display = "none";
        }
    });

    var page_format_select = d3.select("#page_format");
    page_format_select.on("input", function() {
        var page = d3.select(this).node().value;
        if (!page || page == 'Select a page format') {
            disableDrawArea();
            d3.select("#label_format").selectAll("option").remove();
        } else {
            switchPageDependentOptions(page); // show correct download and text options
        }
    });

    $('#label_format').change(function() {
        var label = $(this).find('option:selected').val();
        if (!label || label == 'Select a label format') {
            disableDrawArea();
            jQuery('#select_layout_button').prop('disabled',true)
        } else {
            switchLabelDependentOptions(label);
        }
    });

    d3.select("#d3-apply-custom-label-size").on("click", function() {

        //save and apply custom label size
        jQuery('#select_layout_button').prop('disabled', false)
        var page = d3.select("#page_format").node().value;
        var custom_label = page_formats[page].label_sizes['Custom'];

        custom_label.label_width = document.getElementById("label_width").value;
        custom_label.label_height = document.getElementById("label_height").value;
        changeLabelSize(custom_label.label_width, custom_label.label_height);
        $("#d3-add-and-download-div").removeAttr('style');
        enableDrawArea();
        $('#d3-add-type-input').focus();
    });

    $('#d3-add-field-input').change(function() {
        $("#d3-add-size-input").focus();
    });

    $("#d3-custom-field").on("click", function() {
        $("#d3-custom-input").val('');
        $('#customFieldModal').modal('show');
    });

    d3.select("#d3-custom-field-save")
        .on("click", function() {
            var custom_text = $("#d3-custom-input").val();
            var custom_value = custom_text.replace(/\{(.*?)\}/g, function(match, token) {
                //console.log("token is "+token);
                if (token.match(/Number:/)) {
                    var parts = token.split(':');
                    return parts[1];
                } else {
                    return add_fields[token];
                }
            });

            $("#d3-add-field-input").append($('<option>', {
                value: custom_value,
                text: custom_text,
                selected: "selected"
            }));
        });

    $('#d3-add-type-input').change(function() {
        if (!this.value || this.value == 'Select an element type') {
            return;
        } else {
            switchTypeDependentOptions(this.value);
            $("#d3-add-field-input").focus();
        }

    });

    $("#d3-edit-additional-settings").on("click", function() {
        saveAdditionalOptions(
            document.getElementById("top_margin").value,
            document.getElementById("left_margin").value,
            document.getElementById("horizontal_gap").value,
            document.getElementById("vertical_gap").value,
            document.getElementById("number_of_columns").value,
            document.getElementById("number_of_rows").value,
            document.getElementById("plot_filter").value,
            document.getElementById("sort_order").value,
            document.getElementById("copies_per_plot").value
        );
    });

    $("#d3-add").on("click", function() {
        var type = document.getElementById("d3-add-type-input").value;
        if (!type || type == 'Select an element type') {
            alert("A valid type must be selected.");
            return;
        }
        var field = $('#d3-add-field-input').find('option:selected').text();
        if (!field || field == 'Select a field') {
            alert("A valid field must be selected.");
            return;
        }
        // check if add_fields[field] is defined. If so, add {}s
        if (add_fields[field]) {
            field = "{"+field+"}";
        }
        var text = document.getElementById("d3-add-field-input").value;
        var size = document.getElementById("d3-add-size-input").value;
        var font = document.getElementById("d3-add-font-input").value || 'Courier';
        addToLabel(field, text, type, size, font);
        jQuery('#design_label_button').prop('disabled', false)
    });

    $("#d3-pdf-button, #d3-zpl-button").on("click", function() {
        var design = retrievePageParams();
        var download_type = $(this).val();
        console.log("Design is "+JSON.stringify(design));

        // if over 1,000 to download, throw warning with editable start and end number and text recommending to download in batches of 1,000 or less
        var label_count = num_units * design.copies_per_plot;
        var labels_to_download = design.labels_to_download;
        if (label_count < 1000 || (labels_to_download && labels_to_download < 1000)) {
            downloadLabels(design, download_type);
        } else if (label_count > 1000) {
            //show warning with editable inputs for start and end
            var message = "You are trying to download "+label_count+ " labels ("+label_count+" "+jQuery('#label_designer_data_level :selected').text()+"s x "+design.copies_per_plot+" copy(ies) each). Due to slow speeds it is not recommended to download more than 1000 labels at a time. Please use the input boxes below to download your labels in batches.";
            $("#batch_download_message").text(message);
            $("#d3-batch-download-submit").val(download_type);
            $('#batchDownloadModal').modal('show');
        }

    });

    $("#d3-batch-download-submit").on("click", function() {
        var download_type = $(this).val();
        var design = retrievePageParams();
        downloadLabels(design, download_type);
    });

});

function downloadLabels (design, download_type) {
    var label_elements = document.getElementsByClassName('label-element');
    label_elements = Array.prototype.slice.call(label_elements); // convert to array
    if (label_elements.length < 1) {
        alert("No elements in the design. Please add design elements before downloading");
        return;
    }
    var data_type = $('#source_select :selected').parent().attr('label');
    var source_id = $("#source_select").val();
    var source_name = $("#source_select :selected").text();
    //console.log("Id is "+source_id+" and name is "+source_name);
    if (!source_id || source_id == 'Please select a trial' || source_id == 'Select a plot list') {
        alert("No data source selected. Please select a data source before downloading");
        return;
    }

    if (!design) {
        alert("No design. Please define a design before downloading");
        return;
    }
    design.label_elements = label_elements.filter(checkIfVisible).map(getLabelDetails);

    var design_json = JSON.stringify(design);
    console.log("design is"+design_json);
    var data_level = jQuery('#label_designer_data_level').val();

    //send to server to build pdf file
    jQuery.ajax({
        url: '/tools/label_designer/download',
        timeout: 300000,
        method: 'POST',
        data: {
            'download_type': download_type,
            'data_type' : data_type,
            'source_id': source_id,
            'source_name': source_name,
            'design_json': design_json,
            'data_level': data_level
        },
        beforeSend: function() {
            console.log("Downloading "+download_type+" file . . . ");
            disable_ui();
        },
        complete: function() {
            enable_ui();
        },
        success: function(response) {
            if (response.error) {
                enable_ui();
                alert(response.error);
            } else {
                console.log("Got file "+response.filename);
                enable_ui();
                window.location.href = "/download/" + response.filename;
            }
        },
        error: function(request, status, err) {
            enable_ui();
            alert("Error. Unable to download labels.");
        }
    });
}

function updateFields(data_type, source_id, data_level){

    //console.log("running update fields");
    if (data_type.match(/List/)) {
        jQuery('#sort_order').val('list_order');
    }

    jQuery.ajax({
        url: '/tools/label_designer/retrieve_longest_fields',
        timeout: 60000,
        method: 'POST',
        data: {
            data_type: data_type,
            source_id: source_id,
            data_level: data_level
        },
        beforeSend: function() {
            disable_ui();
        },
        complete: function() {
            enable_ui();
            jQuery('#page_format').focus();
        },
        success: function(response) {
            if (response.error) {
                alert("An error occured while retrieving the design elements of this trial: " + JSON.stringify(response.error));
                getDataSourceSelect();
            } else {
                add_fields = response.fields;
                add_fields["Select a field"] = {};

                // if reps, add reps as options for filtering
                reps = response.reps;
                num_units = response.num_units;
                addPlotFilter(reps);
                addSortOrders(add_fields);
                createAdders(add_fields);
                initializeCustomModal(add_fields);
                showLoadOption();

                if ( d3.select("#page_format").node().value && d3.select("#page_format").node().value != 'Select a page format') {
                    switchPageDependentOptions( d3.select("#page_format").node().value );
                } else {
                    var page_format_select = d3.select("#page_format");
                    page_format_select.selectAll("option")
                    .data(Object.keys(page_formats))
                    .enter().append("option")
                    .text(function(d) {
                        return d
                    });
                }
            }
        },
        error: function(request, status, err) {
            alert("Unable to retrieve design elements of this trial. Please confirm this trial has a design, or try again with a different trial. Please contact us!");
        }
    });
}

function changeLabelSize(width, height) {
    var width = width * 2.83 //convert from pixels to dots (72/inch to 8/mm)
    var height = height * 2.83 //convert from pixels to dots (72/inch to 8/mm)
    d3.select(".label-template").attr("viewBox", "0 0 " + width + " " + height);
    d3.select(".d3-bg").attr("width", width);
    d3.select(".d3-bg").attr("height", height);
    updateGrid(7);
}

function initializeDrawArea() {

    //create svg canvas
    d3.select(".label-template").remove();
    var svg = d3.select("#d3-draw-area")
        .append('svg')
        .classed("label-template", true)
        .attr({
            id: "d3-label-area",
            viewBox: "0 0 510 204"
        }).classed("d3-draw-svg", true);

    //set up background
    var rect = svg.append('rect')
        .classed("d3-bg", true)
        .attr({
            x: 0,
            y: 0,
            width: 510,
            height: 204,
            fill: "#FFF",
            stroke: "#D3D3D3",
            "stroke-width": "2px"
        })
        .on("click", clearSelection);
        svg.append('text')
        .classed("d3-intro-text", true)
        .attr({
            "x": "50%",
            "y": "38%",
            "font-size": 30,
            "text-anchor": "middle",
            "alignment-baseline": "central",
        })
        .text('Label Design Area')
        svg.append('text')
        .classed("d3-intro-text", true)
        .attr({
            "x": "50%",
            "y": "55%",
            "font-size": 16,
            "style": "font-style: oblique;",
            "text-anchor": "middle",
            "alignment-baseline": "central",
        })
        .text('Set source, page, and label formats above to start designing.');

    //set up grid
    var grid = svg.append("g").classed("d3-bg-grid", true);
    grid.append('g').classed("d3-bg-grid-vert", true);
    grid.append('g').classed("d3-bg-grid-horz", true);
    updateGrid(7);

}

function draggable(d, i) {
    var bb = this.node().getBBox();
    this.attr({
            "s-x": bb.x,
            "s-y": bb.y
        })
        .call(doTransform, function(state, selection) {
            state.translate = [-bb.x, -bb.y]
        })
        .call(drag_behaviour);
}

function selectable(selection, resizeable) {
    this.on("mousedown", function() {
        d3.select(".selection-tools").remove();
    })
    this.on("click", function() {
        var o = d3.select(".d3-draw-svg");
        var bb = getTransGroupBounds(this);
        var target = d3.select(this);
        var tools = o.append('g')
            .classed("selection-tools", true)
            .datum(target);
        tools.append("rect")
            .classed("selection-tool-outline", true)
            .attr({
                x: bb.x,
                y: bb.y,
                width: bb.width,
                height: bb.height,
                fill: "none",
                stroke: "black",
                "stroke-dasharray": ("3,3"),
                "stroke-width": "1"
            })
        tools.append("rect")
            .classed("selection-tool-remover", true)
            .attr({
                x: bb.x - 4,
                y: bb.y - 4,
                width: 8,
                height: 8,
                fill: "red",
                stroke: "none"
            })
            .on("click", function() {
                d3.event.stopPropagation();
                target.remove();
                clearSelection();
            })
        if (resizeable) {
            tools.append("rect")
                .classed("selection-tool-resizer", true)
                .on("click", function() {
                    d3.event.stopPropagation();
                })
                .attr({
                    x: bb.x + bb.width - 4,
                    y: bb.y + bb.height - 4,
                    width: 8,
                    height: 8,
                    fill: "green",
                    stroke: "none"
                }).call(resizer_behaviour);
        }
    })
}

function doTransform(selection, transformFunc) {
    var state = d3.transform(selection.attr("transform"));
    transformFunc(state, selection);
    selection.attr("transform", state.toString());
}

function clearSelection() {
    d3.select(".selection-tools").remove();
}

function getTransGroupBounds(node) {
    var bb = node.getBBox()
    var state = d3.transform(d3.select(node).attr("transform"));
    bb.x = bb.x * state.scale[0]
    bb.y = bb.y * state.scale[1]
    bb.width = bb.width * state.scale[0]
    bb.height = bb.height * state.scale[1]
    bb.x += state.translate[0]
    bb.y += state.translate[1]
    return bb
}

function updateGrid(size) {
    //set snapping distance
    doSnap.size = size;
    //make x-lines
    var width = document.getElementById("d3-label-area").viewBox.baseVal.width; //.getBoundingClientRect().width();
    var height = document.getElementById("d3-label-area").viewBox.baseVal.height;
    var x_lines = [];
    for (var x = size; x < width; x += size) {
        x_lines.push(x);
    }
    var vert = d3.select(".d3-bg-grid-vert").selectAll("line")
        .data(x_lines);
    vert.exit().remove()
    vert.enter().append('line')
    vert.attr({
            y1: 0,
            y2: height,
            stroke: "rgba(0,0,0,0.2)",
            "stroke-width": 1
        })
        .attr("x1", function(d) {
            return d
        })
        .attr("x2", function(d) {
            return d
        })
        .on("click", clearSelection);
    //make y-lines
    var y_lines = [];
    for (var y = size; y < height; y += size) {
        y_lines.push(y);
    }
    var horz = d3.select(".d3-bg-grid-horz").selectAll("line")
        .data(y_lines);
    horz.exit().remove()
    horz.enter().append('line')
    horz.attr({
            x1: 0,
            x2: width,
            stroke: "rgba(0,0,0,0.2)",
            "stroke-width": 1
        })
        .attr("y1", function(d) {
            return d
        })
        .attr("y2", function(d) {
            return d
        })
        .on("click", clearSelection);
}

function doSnap(state, selection) {
    var bb = getTransGroupBounds(selection.node());
    var left_snap_d = (Math.round(bb.x / doSnap.size)) * doSnap.size - bb.x
    var right_snap_d = (Math.round((bb.x + bb.width) / doSnap.size) * doSnap.size - bb.width) - bb.x
    var top_snap_d = (Math.round(bb.y / doSnap.size)) * doSnap.size - bb.y
    var bottom_snap_d = (Math.round((bb.y + bb.height) / doSnap.size) * doSnap.size - bb.height) - bb.y
    state.translate[0] += Math.abs(left_snap_d) < Math.abs(right_snap_d) ? left_snap_d : right_snap_d
    state.translate[1] += Math.abs(top_snap_d) < Math.abs(bottom_snap_d) ? top_snap_d : bottom_snap_d
}

function getDataSourceSelect() {
    get_select_box('label_data_sources', 'data_source',
        {
            name: 'source_select',
            id: 'source_select',
            default: 'Select a data source',
            live_search: 1,
            // workflow_trigger: 1,
        });
}

function switchPageDependentOptions(page) {
     // load label size and label field options based on page type
     var label_sizes = page_formats[page].label_sizes;
     d3.select("#label_format").selectAll("option").remove();
     d3.select("#label_format").selectAll("option")
         .data(Object.keys(label_sizes))
         .enter().append("option")
         .text(function(d) {
             return d
         });

         d3.select("#d3-add-type-input").selectAll("option").remove();
         d3.select("#d3-add-type-input").selectAll("option")
             .data(Object.keys(label_options))
             .enter().append("option")
             .text(function(d) {
                 return label_options[d].name
             })
             .attr("value", function(d) {
                 return d
             });

    if (page == 'Zebra printer file') { // disable PDF text option and pdf download, clear pdf text elements
        $("#d3-add-type-input option[value='PDFText']").remove();
        switchTypeDependentOptions('ZebraText');
        document.getElementById("d3-pdf-button").style.display = "none";
        document.getElementById("d3-zpl-button").style.display = "inline";
        document.getElementById("d3-add-font-input").value = "Courier"; // default for Zebra

        var label_elements = document.getElementsByClassName("label-element");
        label_elements = Array.prototype.slice.call(label_elements); // convert to array
        for (var i=0; i<label_elements.length; i++) {
            var element = label_elements[i];
            if (element.getAttribute("type") != "ZebraText") { // remove all non-Zebra elements, barcodes too in case they have been scaled
               element.parentNode.removeChild(element);
            }
        }

    } else { // disable Zebra text option and zpl download, clear zpl text elements
        switchTypeDependentOptions('PDFText');
        $("#d3-add-type-input option[value='ZebraText']").remove();
        document.getElementById("d3-zpl-button").style.display = "none";
        document.getElementById("d3-pdf-button").style.display = "inline";

        var label_elements = document.getElementsByClassName("label-element");
        label_elements = Array.prototype.slice.call(label_elements); // convert to array
        for (var i=0; i<label_elements.length; i++) {
            var element = label_elements[i];
             if (element.getAttribute("type") == "ZebraText") { // remove only text, barcodes can stay
                element.parentNode.removeChild(element);
             }
        }
    }

    if (page == 'Custom') { // show Custom inputs and attach handlers
        document.getElementById("d3-custom-dimensions-div").style.display = "inline";
        document.getElementById("d3-page-custom-dimensions-div").style.visibility = "visible";
        document.getElementById("d3-label-custom-dimensions-div").style.visibility = "visible";
        document.getElementById("label_format").value = 'Custom';
        $('#page_width').focus();

        $('#page_width').on("change", function() {
            page_formats[page].page_width = this.value;
        });

        $('#page-height').on("change", function() {
            page_formats[page].page_height = this.value;
        });
    } else { //hide page custom input
        document.getElementById("d3-page-custom-dimensions-div").style.visibility = "hidden";
        $('#label_format').focus();
    }

    if ( page != 'Custom' && document.getElementById("label_format").value != 'Custom') { //hide all Custom inputs
        document.getElementById("d3-custom-dimensions-div").style.display = "none";
        document.getElementById("d3-page-custom-dimensions-div").style.visibility = "hidden";
        document.getElementById("d3-label-custom-dimensions-div").style.visibility = "hidden";
    }

}

function switchLabelDependentOptions(label) {

    var page = d3.select("#page_format").node().value;
    var label_sizes = page_formats[page].label_sizes;

    if (label == 'Custom') {
        document.getElementById("d3-custom-dimensions-div").style.display = "inline";
        document.getElementById("d3-label-custom-dimensions-div").style.visibility = "visible";
        $('#label_width').focus();
    } else {
        jQuery('#select_layout_button').prop('disabled', false)
        document.getElementById("d3-custom-dimensions-div").style.display = "none";
        document.getElementById("d3-label-custom-dimensions-div").style.visibility = "hidden";
        changeLabelSize( label_sizes[label].label_width,  label_sizes[label].label_height);
        $("#d3-add-and-download-div").removeAttr('style');
        $('#d3-add-type-input').focus();
        enableDrawArea();
    }
    //set addtional options
    document.getElementById("top_margin").value = label_sizes[label].top_margin;
    document.getElementById("left_margin").value = label_sizes[label].left_margin;
    document.getElementById("horizontal_gap").value = label_sizes[label].horizontal_gap;
    document.getElementById("vertical_gap").value = label_sizes[label].vertical_gap;
    document.getElementById("number_of_columns").value = label_sizes[label].number_of_columns;
    document.getElementById("number_of_rows").value = label_sizes[label].number_of_rows;
}

function switchTypeDependentOptions(type){

    var sizes = label_options[type].sizes;
    if (type == "PDFText") {

        // set up font select
        d3.select("#d3-add-font-input").selectAll("option").remove();
        d3.select("#d3-add-font-input").selectAll("option")
            .data(Object.keys(font_styles).sort())
            .enter().append("option")
            .text(function(d) {
                return d
            })
            .attr("style", function(d) {
                return font_styles[d]
            })
            .attr("value", function(d) {
                return d
            });
        document.getElementById("d3-add-font-div").style.visibility = "visible";

        // set up size input and slider
        $("#d3-add-size-input").replaceWith('<input type="number" id="d3-add-size-input" class="form-control"></input>');
        var size_input = d3.select("#d3-add-size-input");
        var size_slider = d3.select("#d3-add-size-slider");
        size_input.attr(sizes);
        size_slider.attr(sizes);
        size_slider.on("input", function() {
            size_input.property("value", this.value)
        });
        size_input.on("change", function() {
            size_slider.node().value = this.value;
        });
        $("#d3-add-size-slider").show();

    } else {
        document.getElementById("d3-add-font-div").style.visibility = "hidden";
        $("#d3-add-size-input").replaceWith('<select id="d3-add-size-input" class="form-control"></select>&nbsp&nbsp');
        d3.select("#d3-add-size-input").selectAll("option")
            .data(Object.keys(sizes))
            .enter().append("option")
            .text(function(d) {
                return d
            })
            .attr("value", function(d) {
                return sizes[d]
            });
        $("#d3-add-size-slider").hide();
    }
}

function addToLabel(field, text, type, size, font, x, y, width, height) {
     //console.log("Field is: "+field+" and text is: "+text+" and type is: "+type+" and size is: "+size+" and font is: "+font);
    svg = d3.select(".d3-draw-svg");

    //get x,y coords and scale
    if ((typeof x || typeof y ) === 'undefined') {
        x = document.getElementById("d3-label-area").viewBox.baseVal.width/2;
        y = document.getElementById("d3-label-area").viewBox.baseVal.height/2;
    }
    //console.log(" X is: "+x+" and y is: "+y);

    //count existing elements
    var label_elements = document.getElementsByClassName('label-element');
    label_elements = Array.prototype.slice.call(label_elements); // convert to array
    var count = label_elements.length;

    //set up new element
    var new_element = svg.append("g")
        .classed("draggable", true)
        .classed("selectable", true)
        .call(draggable)

    switch (type) {
        case "Code128":
        case "QRCode":
            //console.log("Adding barcode of type "+type);
            //add barcode specific attributes
            disable_ui();
            var page = d3.select("#page_format").node().value;
            new_element.classed("barcode", true)
            if ( page.match(/Zebra/) ) {
                new_element.call(selectable, false);
            } else {
                new_element.call(selectable, true);
            }
            var img = new Image();
            img.src = "/tools/label_designer/preview?content=" + encodeURIComponent(text) + "&type=" + encodeURIComponent(type) + "&size=" + encodeURIComponent(size);
            img.onload = function() {
                var element_width = width || this.width;
                var element_height = height || this.height;
                x = x - (element_width /2);
                y = y - (element_height /2);
                //console.log("Final x is "+x+" and final y is "+y);
                new_element.call(doTransform, function(state, selection) {
                    state.translate = [x,y]
                }, doSnap)
                .append("svg:image")
                .attr({
                    "id": "element"+count,
                    "class": "label-element",
                    "value": field,
                    "size": size,
                    "type": type,
                    "width": element_width,
                    "height": element_height,
                    "href": "/tools/label_designer/preview?content=" + encodeURIComponent(text) + "&type=" + encodeURIComponent(type) + "&size=" + encodeURIComponent(size),
                });
                enable_ui();
            }
            break;

        default:
            //add text specific attributes
            //console.log("Adding text of type "+type);
            var font_size = parseInt(size);
            if (type =="ZebraText") {
                font_size = font_size + parseInt(font_size/9);
            }
            new_element.classed("text-box", true)
            .call(selectable, false)
            .call(doTransform, function(state, selection) {
                state.translate = [x,y]
            })
            .append("text")
            .attr({
                "id": "element"+count,
                "class": "label-element",
                "value": field,
                "size": size,
                "type": type,
                "font-size": font_size,
                "font": font,
                "style": font_styles[font],
                "text-anchor": "middle",
                "alignment-baseline": "middle",
            })
            .text(text)
            //console.log("Field is: "+field+" and size is: "+size+" and type is: "+type+" and font size is: "+font_size+" and font is: "+font+" and style is: "+font_styles[font]+" and text is: "+text);

            break;
    }
}

function saveAdditionalOptions(top_margin, left_margin, horizontal_gap, vertical_gap, number_of_columns, number_of_rows, plot_filter, sort_order, copies_per_plot) {
    // save options in javascript object and in html elements
    var page = d3.select("#page_format").node().value;
    var label = d3.select("#label_format").node().value;
    page_formats[page].label_sizes[label].top_margin = top_margin;
    page_formats[page].label_sizes[label].left_margin = left_margin;
    page_formats[page].label_sizes[label].horizontal_gap = horizontal_gap;
    page_formats[page].label_sizes[label].vertical_gap = vertical_gap;
    page_formats[page].label_sizes[label].number_of_columns = number_of_columns;
    page_formats[page].label_sizes[label].number_of_rows = number_of_rows;
    page_formats[page].label_sizes[label].plot_filter = plot_filter;
    page_formats[page].label_sizes[label].sort_order = sort_order;
    page_formats[page].label_sizes[label].copies_per_plot = copies_per_plot;
    document.getElementById("top_margin").value = top_margin;
    document.getElementById("left_margin").value = left_margin;
    document.getElementById("horizontal_gap").value = horizontal_gap;
    document.getElementById("vertical_gap").value = vertical_gap;
    document.getElementById("number_of_columns").value = number_of_columns;
    document.getElementById("number_of_rows").value = number_of_rows;
    document.getElementById("plot_filter").value = plot_filter || 'all';
    document.getElementById("sort_order").value = sort_order;
    document.getElementById("copies_per_plot").value = copies_per_plot;
}

function dragSnap() {
    d3.select(this).call(doTransform, doSnap);
}

function createAdders(add_fields) {
    // load type select options
    d3.select("#d3-add-type-input").selectAll("option").remove();
    d3.select("#d3-add-type-input").selectAll("option")
        .data(Object.keys(label_options))
        .enter().append("option")
        .text(function(d) {
            return label_options[d].name
        })
        .attr("value", function(d) {
            return d
        });

    //load field options
    d3.select("#d3-add-field-input").selectAll("option").remove();
    d3.select("#d3-add-field-input").selectAll("option")
        .data(Object.keys(add_fields).sort())
        .enter().append("option")
        .text(function(d) {
            return d
        })
        .attr("value", function(d) {
            return add_fields[d]
        });

}

function addPlotFilter(reps) {

    Object.keys(reps).forEach(function(key) {
        var newkey = "Rep "+key+" only";
        reps[newkey] = key;
        delete reps[key];
    });
    reps['All'] = 'all';

    d3.select("#plot_filter").selectAll("option").remove();
    d3.select("#plot_filter").selectAll("option")
        .data(Object.keys(reps).sort())
        .enter().append("option")
        .text(function(d) {
            return d
        })
        .attr("value", function(d) {
            return reps[d]
        });

}

function addSortOrders(add_fields) {
    //load options
    d3.select("#sort_order").selectAll("option").remove();
    d3.select("#sort_order").selectAll("option")
        .data(Object.keys(add_fields).sort())
        .enter().append("option")
        .text(function(d) {
            return d
        })
        .attr("value", function(d) {
            return d
        });
}

function checkIfVisible(element) {
    var label_width = document.getElementById("d3-label-area").viewBox.baseVal.width;
    var label_height = document.getElementById("d3-label-area").viewBox.baseVal.height;
    var transform_attributes = parseTransform(element.parentNode.getAttribute('transform')); // return transform attributes as an object
    var coords = transform_attributes.translate;
    var type = element.getAttribute("type");
    if (coords[0] > label_width || coords[1] > label_height) { // ignore elements not visible in draw area
        return false; // skip
    } else {
        return true;
    }
}

function getLabelDetails(element) {
    var transform_attributes = parseTransform(element.parentNode.getAttribute('transform')); // return transform attributes as an object
    //console.log("Transform attributes are: "+JSON.stringify(transform_attributes));
    var coords = transform_attributes.translate;
    var scale = transform_attributes.scale || new Array(1,1);
    var rect = element.getBBox();
    var width = rect.width * scale[0];
    var height = rect.height * scale[1];
    //console.log("Height is: "+height+" and width is: "+width);
    var type = element.getAttribute("type");
    var x;
    var y;
    if (type.match(/Text/)) {
        x = parseInt(coords[0])
        y = parseInt(coords[1])
    } else {
        x = parseInt(coords[0]) + (width/2);
        y = parseInt(coords[1]) + (height/2);
    }

    return {
        x: x,
        y: y,
        height: height,
        width: width,
        value: element.getAttribute("value"),
        type: element.getAttribute("type"),
        font: element.getAttribute("font") || 'Courier',
        size: element.getAttribute("size")
    };
}

function parseTransform(transform) {
    var attribute_object = {};
    var attributes = transform.split(')');

    for (var i = 0; i < attributes.length; i++) {
        var attribute = attributes[i];
        var parts = attribute.split('(');
        var name = parts.shift();
        var values = parts.join(',');
        attribute_object[name] = values.split(',');
    }

    return attribute_object;
}

function retrievePageParams() {

    var page = d3.select("#page_format").node().value;
    if (!page || page == 'Select a page format') {
        alert("No page format select. Please select a page format");
        return;
    }
    var label = d3.select("#label_format").node().value;
    if (!label || label == 'Select a label format') {
        alert("No label format select. Please select a label format");
        return;
    }
    var label_sizes = page_formats[page].label_sizes;

    var page_params = {
        page_format: page,
        page_width: page_formats[page].page_width || document.getElementById("page_width").value,
        page_height: page_formats[page].page_height || document.getElementById("page_height").value,
        left_margin: label_sizes[label].left_margin,
        top_margin: label_sizes[label].top_margin,
        horizontal_gap: label_sizes[label].horizontal_gap,
        vertical_gap: label_sizes[label].vertical_gap,
        number_of_columns: label_sizes[label].number_of_columns,
        number_of_rows: label_sizes[label].number_of_rows,
        plot_filter: document.getElementById("plot_filter").value,
        sort_order: document.getElementById("sort_order").value,
        copies_per_plot: document.getElementById("copies_per_plot").value,
        labels_to_download: document.getElementById("label_designer_labels_to_download").value,
        start_number: document.getElementById("label_designer_start_number").value,
        end_number: document.getElementById("label_designer_end_number").value,
        label_format: label,
        label_width: label_sizes[label].label_width,
        label_height: label_sizes[label].label_height,
        start_col: document.getElementById("start_col").value,
        start_row: document.getElementById("start_row").value,
    }
    return page_params;

}

function initializeCustomModal(add_fields) {
    //load field options
    d3.select("#d3-custom-add-field-input").selectAll("option").remove();
    d3.select("#d3-custom-add-field-input").selectAll("option")
        .data(Object.keys(add_fields).sort())
        .enter().append("option")
        .text(function(d) {
            return d
        })
        .attr("value", function(d) {
            return add_fields[d]
        });

    $('#d3-custom-add-field-input').on("change", function() {

        var value = $(this).find('option:selected').text();
        if (!value || value == 'Select a field') {
            return;
        } else {
            var custom_field = $("#d3-custom-input").val() + "{" + value + "}";
            $("#d3-custom-input").val(custom_field);
        }

    });

    $("#d3-custom-preview").on("click", function() {
        var custom_field = $("#d3-custom-input").val();
        var result = custom_field.replace(/\{(.*?)\}/g, function(match, token) {
            console.log("token is "+token);
            if (token.match(/Number:/)) {
                var parts = token.split(':');
                return parts[1];
            } else {
                return add_fields[token];
            }
        });
        $("#d3-custom-content").text(result);
    });

    $("#d3-add-number").on("click", function() {
        var custom_field = $("#d3-custom-input").val() + "{Number:" + $('#start_number').val() +":"+ $('#increment_number').val()+"}";
        $("#d3-custom-input").val(custom_field);
    });

}

function enableDrawArea() {
    var intro_elements = document.getElementsByClassName("d3-intro-text");
    for (var i=0; i<intro_elements.length; i++) { intro_elements[i].style.display = "none"; }
    var label_elements = document.getElementsByClassName("label-element");
    for(var i=0; i<label_elements.length; i++) { label_elements[i].style.display = "inline"; }
}

function disableDrawArea() {
    var intro_elements = document.getElementsByClassName("d3-intro-text");
    for (var i=0; i<intro_elements.length; i++) { intro_elements[i].style.display = "inline"; }
    var label_elements = document.getElementsByClassName("label-element");
    for(var i=0; i<label_elements.length; i++) { label_elements[i].style.display = "none"; }
}

function saveLabelDesign() {
    var label_elements = document.getElementsByClassName('label-element');
    label_elements = Array.prototype.slice.call(label_elements); // convert to array
    if (label_elements.length < 1) {
        alert("No elements in the design. Please add design elements before saving");
        return;
    }

    var lo = new CXGN.List();
    var new_name = $('#save_design_name').val();
    page_params = JSON.stringify(retrievePageParams());

    if (!page_params) {return;}
    var data = page_params.slice(1, -1).split(",").join("\n"); // get key value pairs in list format
    label_params = label_elements.filter(checkIfVisible).map(getLabelDetails);

    for (i=0; i < label_params.length; i++) { // add numbered element key for each set of label params
        data += '\n"element'+i+'": '+JSON.stringify(label_params[i]);
    }

    list_id = lo.newList(new_name);
    if (list_id > 0) {
        var elementsAdded = lo.addToList(list_id, data);
        lo.setListType(list_id, 'label_design');
    }
    if (elementsAdded) {
        alert("Saved label design with name " + new_name);
    }
}

function fillInPlaceholders(match, placeholder) { // replace placeholders with actual values
        var filled = add_fields[placeholder];
        // console.log("Filling "+placeholder+" with "+filled);
        if (typeof filled === 'undefined' && !placeholder.match(/Number:/)) {
            // console.log(placeholder+" is undefined. Alerting with warning");
            alert("Missing field. Your selected design includes the field "+placeholder+" which is not available from the selected data source. Please pick a different saved design or data source, or remove the undefined field from the design area.")
        }
        return filled;
}

function showLoadOption() {
    // document.getElementById('design_label').style.display = "inline";
    // document.getElementById('design_list').style.display = "inline";
    var lo = new CXGN.List();
    $('#design_list').html(lo.listSelect('design_list', ['label_design'], 'Select a saved design', 'refresh', undefined));
    $('#design_list_list_select').change(
      function() {
        Workflow.complete(this);
        loadDesign(this.value);
        jQuery('#design_label_button').prop('disabled', false);
    });
}

function loadDesign (list_id) {
    // console.log("Loading design from list with ID "+list_id);
    // clear existing draw area
    initializeDrawArea();

    var lo = new CXGN.List();
    var list_data = lo.getListData(list_id);
    var elements = list_data.elements;

    //parse into javascript object
    var fixed_elements = Object.values(elements).map(function(e){ return e.pop(); });
    var params = JSON.parse("{"+fixed_elements.join(',')+"}");

    for (var key in params) {
        if (key.match(/element/)) {
            var element_obj = params[key];
            var value = element_obj.value;
            var text = value.replace(/\{(.*?)\}/g, fillInPlaceholders);
            //console.log("Width is "+element_obj.width);
            addToLabel(value, text, element_obj.type, element_obj.size, element_obj.font, element_obj.x, element_obj.y, element_obj.width, element_obj.height);
        }
    }

    var page = params['page_format'];
    document.getElementById('page_format').value = page;
    //console.log("page is "+page);
    switchPageDependentOptions(page);
    if (page == 'Custom') {
        document.getElementById("page_width").value = params['page_width'];
        document.getElementById("page_height").value = params['page_height'];
    }

    var label = params['label_format'];
    document.getElementById('label_format').value = label;
    switchLabelDependentOptions(label);
    if (label == 'Custom') {
        document.getElementById("label_width").value = params['label_width'];
        document.getElementById("label_height").value = params['label_height'];
        page_formats[page].label_sizes['Custom'].label_width = params['label_width'];
        page_formats[page].label_sizes['Custom'].label_height = params['label_height'];
        changeLabelSize(params['label_width'], params['label_height']);
        $("#d3-add-and-download-div").removeAttr('style');
        enableDrawArea();
    }

    saveAdditionalOptions(
        params['top_margin'],
        params['left_margin'],
        params['horizontal_gap'],
        params['vertical_gap'],
        params['number_of_columns'],
        params['number_of_rows'],
        params['plot_filter'],
        params['sort_order'],
        params['copies_per_plot']
    );

}
