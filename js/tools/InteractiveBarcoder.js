
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
        "10": 10,
        "20": 20,
        "30": 30,
        "39": 39,
        "49": 49,
        "58": 58,
        "66": 66
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
    "Times": "font-family:times;font-weight:bold;",
    "Times-Italic": "font-family:times;font-style: italic;",
    "Times-BoldItalic": "font-family:times;font-weight:bold;font-style: italic;"
}

var add_fields = {};

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

    get_select_box('trials', 'trial_select', {
        'name': 'trial_select_html',
        'id': 'trial_select_html',
        'empty': 1
    });

    // Every time a modal is shown, if it has an autofocus element, focus on it.
    $('.modal').on('shown.bs.modal', function() {
        $(this).find('[autofocus]').focus();
    });

    if (!isLoggedIn()) {
        $('#design_list').html('<select class="form-control" disabled><option>Login to load saved designs</option></select>');
        $('#save_design_div').html('<input class="form-control" placeholder="Login to save designs" disabled></input>');
    } else {
        $('#design_list').html('<select class="form-control" disabled><option>First select a data source</option></select>');
        var save_html = '<input type="text" id="save_design_name" class="form-control" placeholder="Enter a name"></input><span class="input-group-btn"><button class="btn btn-default" id="d3-save-button" type="button">Save</button></span>';
        $('#save_design_div').html(save_html);
    }

    $('#d3-save-button').click(function() {

        var label_elements = document.getElementsByClassName('label-element');
        label_elements = Array.prototype.slice.call(label_elements); // convert to array
        if (label_elements.length < 1) {
            alert("No elements in the design. Please add design elements before saving");
            return;
        }

        var lo = new CXGN.List();
        var new_name = $('#save_design_name').val();
        //console.log("Saving label design to list named " + new_name);
        page_params = JSON.stringify(retrievePageParams());
        var data = page_params.slice(1, -1).split(",").join("\n"); // get key value pairs in list format
        label_params = label_elements.map(getLabelDetails);

        //console.log("label_param length is: "+label_params.length)
        for (i=0; i < label_params.length; i++) { // add numbered element key for each set of label params
            data += '\n"element'+i+'": '+JSON.stringify(label_params[i]);
        }
        console.log("Data for list is: "+data);
        list_id = lo.newList(new_name);
        if (list_id > 0) {
            var elementsAdded = lo.addToList(list_id, data);
            lo.setListType(list_id, 'dataset');
        }
        if (elementsAdded) {
            alert("Saved label design with name " + new_name);
        }

    });

    $('#trial_select').focus();

    $("#edit_additional_settings").on("click", function() {
        $('#editAdditionalSettingsModal').modal('show');
    });

    $(document).on("change", "#trial_select", function() {

        var trial_id = document.getElementById("trial_select").value;
        console.log("trial selected has id " + trial_id);

        jQuery.ajax({
            url: '/barcode/download/retrieve_longest_fields',
            timeout: 60000,
            method: 'POST',
            data: {
                'trial_id': trial_id
            },
            beforeSend: function() {
                disable_ui();
            },
            complete: function() {
                enable_ui();
                $('#page_format').focus();
            },
            success: function(response) {
                if (response.error) {
                    alert("An error occured while retrieving the design elements of this trial: " + JSON.stringify(response.error));
                } else {
                    console.log("Got longest elements: " + JSON.stringify(response));
                    add_fields = response;
                    add_fields["Select a field"] = {};

                    createAdders(add_fields);
                    initializeCustomModal(add_fields);

                    if ( d3.select("#page_format").node().value ) {
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

                    if (!isLoggedIn()) {
                        $('#design_list').html('<select class="form-control" disabled><option>Login to load saved designs</option></select>');
                    } else {
                        var lo = new CXGN.List();
                        $('#design_list').html(lo.listSelect('design_list', ['dataset'], 'Select a saved design', 'refresh'));
                        $('#design_list_list_select').change(
                          function() {
                            disable_ui();
                            load_design(this.value);
                            enable_ui();
                        });
                    }

                }
            },
            error: function(request, status, err) {
                alert("Unable to retrieve design elements of this trial. Please confirm this trial has a design, or try again with a different trial.");
            }
        });
    });

    var page_format_select = d3.select("#page_format");
    page_format_select.on("input", function() {
        var page = d3.select(this).node().value;
        if (!page || page == 'Select a page format') {
            var intro_elements = document.getElementsByClassName("d3-intro-text");
            for (var i=0; i<intro_elements.length; i++) { intro_elements[i].style.display = "inline"; }
            var label_elements = document.getElementsByClassName("label-element");
            for(var i=0; i<label_elements.length; i++) { label_elements[i].style.display = "none"; }
            d3.select("#label_format").selectAll("option").remove();
        } else {
            switchPageDependentOptions(page); // show correct download and text options
        }
    });

    $('#label_format').change(function() {
        var label = $(this).find('option:selected').val();
        if (!label || label == 'Select a label format') {
            var intro_elements = document.getElementsByClassName("d3-intro-text");
            for (var i=0; i<intro_elements.length; i++) { intro_elements[i].style.display = "inline"; }
            var label_elements = document.getElementsByClassName("label-element");
            for(var i=0; i<label_elements.length; i++) { label_elements[i].style.display = "none"; }
        } else {
            switchLabelDependentOptions(label);
        }
    });

    d3.select("#d3-apply-custom-label-size").on("click", function() {

        //save and apply custom label size
        var page = d3.select("#page_format").node().value;
        var custom_label = page_formats[page].label_sizes['Custom'];

        custom_label.label_width = document.getElementById("label_width").value;
        custom_label.label_height = document.getElementById("label_height").value;
        changeLabelSize(custom_label.label_width, custom_label.label_height);
        $("#d3-add-and-download-div").removeAttr('style');
        var intro_elements = document.getElementsByClassName("d3-intro-text");
        for (var i=0; i<intro_elements.length; i++) { intro_elements[i].style.display = "none"; }
        var label_elements = document.getElementsByClassName("label-element");
        for(var i=0; i<label_elements.length; i++) { label_elements[i].style.display = "inline"; }
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
                console.log("token is "+token);
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
        var font = document.getElementById("d3-add-font-input").value;
        addToLabel(field, text, type, size, font);
    });

    $("#d3-pdf-button, #d3-zpl-button").on("click", function() {

        var label_elements = document.getElementsByClassName('label-element');
        label_elements = Array.prototype.slice.call(label_elements); // convert to array
        if (label_elements.length < 1) {
            alert("No elements in the design. Please add design elements before downloading");
            return;
        }
        var download_type = $(this).val();
        //console.log("You clicked the download "+download_type+" button.");

        var ladda = Ladda.create(this);
        ladda.start();
        var token = new Date().getTime(); //use the current timestamp as the token name and value
        manage_dl_with_cookie(token, ladda);

        var trial_id = document.getElementById("trial_select").value;
        var design = retrievePageParams();
        design.label_elements = label_elements.map(getLabelDetails)

        var design_json = JSON.stringify(design);
        console.log("Design json is: \n"+design_json);

        //send to server to build pdf file
        jQuery.ajax({
            url: '/barcode/download/'+download_type,
            timeout: 300000,
            method: 'POST',
            data: {
                'trial_id': trial_id,
                'design_json': design_json,
                'download_token': token
            },
            success: function(response) {
                if (response.error) {} else {
                    console.log("downloading " + response.filename);
                    window.location.href = "/download/" + response.filename;
                }
            },
            error: function(request, status, err) {

            }
        });
    });
});

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
            //"style": "font-family:courier;font-weight:bold;",
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

function switchPageDependentOptions(page) {
     console.log("Page type is: " + page);

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
        //console.log("working through "+label_elements.length+" label elements\n");
        for (var i=0; i<label_elements.length; i++) {
            var element = label_elements[i];
            //console.log("Element type is: "+element.getAttribute("type"));
            if (element.getAttribute("type") == "PDFText") {
                //console.log("Removing element with value: "+element.getAttribute("value"));
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
        //console.log("working through "+label_elements.length+" label elements\n");
        for (var i=0; i<label_elements.length; i++) {
            var element = label_elements[i];
            //console.log("Element type is: "+element.getAttribute("type"));
            if (element.getAttribute("type") == "ZebraText") {
                //console.log("Removing element with value: "+element.getAttribute("value"));
                element.parentNode.removeChild(element);
            }
        }
    }

    if (page == 'Custom') {
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
    } else {
        document.getElementById("d3-page-custom-dimensions-div").style.visibility = "hidden";
        $('#label_format').focus();
    }

    if ( page != 'Custom' && document.getElementById("label_format").value != 'Custom') {
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
        document.getElementById("d3-custom-dimensions-div").style.display = "none";
        document.getElementById("d3-label-custom-dimensions-div").style.visibility = "hidden";
        changeLabelSize( label_sizes[label].label_width,  label_sizes[label].label_height);
        $("#d3-add-and-download-div").removeAttr('style');
        // document.getElementById("d3-draw-div").style.visibility = "visible";
        // document.getElementById("d3-adders").style.visibility = "visible";

        $('#d3-add-type-input').focus();
        var intro_elements = document.getElementsByClassName("d3-intro-text");
        for (var i=0; i<intro_elements.length; i++) { intro_elements[i].style.display = "none"; }
        var label_elements = document.getElementsByClassName("label-element");
        for(var i=0; i<label_elements.length; i++) { label_elements[i].style.display = "inline"; }
    }
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
        //var fonts = label_options[type].fonts;
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
        //$("#d3-add-font-input").val('');
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

function addToLabel(field, text, type, size, font, x, y, scale) {
     //console.log("Field is: "+field+" and text is: "+text+" and type is: "+type+" and size is: "+size+" and font is: "+font);
    svg = d3.select(".d3-draw-svg");

    //get x,y coords and scale
    if ((typeof x || typeof y ) === 'undefined') {
        var page = d3.select("#page_format").node().value;
        var label = d3.select("#label_format").node().value;
        var label_sizes = page_formats[page].label_sizes;
        var label_width = label_sizes[label].label_width;
        var label_height = label_sizes[label].label_height;
        x =  label_width / 4;
        y = label_height / 2;
    }
    scale = (typeof scale === 'undefined') ? [1,1] : scale;
    //console.log(" X is: "+x+" and y is: "+y);

    //set up new element
    var new_element = svg.append("g")
        .classed("draggable", true)
        .classed("selectable", true)
        .call(draggable)
        .call(doTransform, function(state, selection) {
            state.translate = [x,y]
            state.scale = scale
        }, doSnap);

    switch (type) {
        case "Code128":
        case "QRCode":

            //add barcode specific attributes
            disable_ui();
            new_element.classed("barcode", true)
            .call(selectable, true);
            var img = new Image();
            img.src = "/barcode/preview?content=" + encodeURIComponent(text) + "&type=" + encodeURIComponent(type) + "&size=" + encodeURIComponent(size);
            img.onload = function() {
                var width = this.width;
                var height = this.height;
                new_element.append("svg:image")
                .attr({
                    "class": "label-element",
                    "value": field,
                    "size": size,
                    "type": type,
                    "height": height,
                    "width": width,
                    "href": "/barcode/preview?content=" + encodeURIComponent(text) + "&type=" + encodeURIComponent(type) + "&size=" + encodeURIComponent(size),
                });
            }
            enable_ui();
            break;

        default:
        //add text specific attributes
            new_element.classed("text-box", true)
            .call(selectable, false)
            .append("text")
            .attr({
                "class": "label-element",
                "value": field,
                "size": size,
                "type": type,
                "font-size": size,
                "font": font,
                "style": font_styles[font], //(typeof font == 'undefined') ? "font-family:courier;" : label_options[type].fonts[font]
                "dominant-baseline": "mathematical",
            })
            .text(text)
            break;
    }
}

function saveAdditionalOptions(top_margin, left_margin, horizontal_gap, vertical_gap, number_of_columns, number_of_rows, sort_order, copies_per_plot) {
    var page = d3.select("#page_format").node().value;
    var label = d3.select("#label_format").node().value;
    //console.log("page is "+page+" and label is "+label);
    page_formats[page].label_sizes[label].top_margin = top_margin;
    page_formats[page].label_sizes[label].left_margin = left_margin;
    page_formats[page].label_sizes[label].horizontal_gap = horizontal_gap;
    page_formats[page].label_sizes[label].vertical_gap = vertical_gap;
    page_formats[page].label_sizes[label].number_of_columns = number_of_columns;
    page_formats[page].label_sizes[label].number_of_rows = number_of_rows;
    page_formats[page].label_sizes[label].sort_order = sort_order;
    page_formats[page].label_sizes[label].copies_per_plot = copies_per_plot;
    document.getElementById("top_margin").value = top_margin;
    document.getElementById("left_margin").value = left_margin;
    document.getElementById("horizontal_gap").value = horizontal_gap;
    document.getElementById("vertical_gap").value = vertical_gap;
    document.getElementById("number_of_columns").value = number_of_columns;
    document.getElementById("number_of_rows").value = number_of_rows;
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

        // remove text option if page format defined

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

function getLabelDetails(element, index) {

    var transform_attributes = parseTransform(element.parentNode.getAttribute('transform')); // return transform attributes as an object
    //console.log("Transform attributes are: "+JSON.stringify(transform_attributes));
    var coords = transform_attributes.translate;
    var scale = transform_attributes.scale || [1,1];
    var rect = element.getBBox();
    var width = rect.width * scale[0];
    var height = rect.height * scale[1];

    return {
        x: coords[0],
        y: coords[1],
        height: height,
        width: width,
        scale: scale,
        value: element.getAttribute("value"),
        type: element.getAttribute("type"),
        font: element.getAttribute("font"),
        size: element.getAttribute("size")
    };
}

function parseTransform(transform) {
    var attribute_object = {};
    //console.log("transform is: "+JSON.stringify(transform));
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

function manage_dl_with_cookie(token, ladda) {
    var cookie = 'download' + token;
    var fileDownloadCheckTimer = window.setInterval(function() { //checks for response cookie to keep working modal enabled until file is ready for download
        var cookieValue = jQuery.cookie(cookie);
        //console.log("cookieValue="+cookieValue);
        //var allCookies = document.cookie;
        //console.log("allCookies="+allCookies);
        if (cookieValue == token) {
            window.clearInterval(fileDownloadCheckTimer);
            jQuery.removeCookie(cookie); //clears this cookie value
            ladda.stop();
        }
    }, 500);
}

function retrievePageParams() {

    var page = d3.select("#page_format").node().value;
    var label = d3.select("#label_format").node().value;
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
        copies_per_plot: document.getElementById("copies_per_plot").value,
        sort_order: document.getElementById("sort_order").value,
        label_format: label,
        label_width: label_sizes[label].label_width,
        label_height: label_sizes[label].label_height,
    }
    return page_params;

}

function initializeCustomModal(add_fields) {
    //load field options
    //console.log("adding fields"+add_fields);
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
        var value = $(this).find('option:selected').text();
        var custom_field = $("#d3-custom-input").val() + value;

        var result = custom_field.replace(/\{(.*?)\}/g, function(match, token) {
            //console.log("token is "+token);
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

function load_design (list_id) {
    // console.log("Loading design from list with ID "+list_id);
    // clear existing draw area
    initializeDrawArea();

    var lo = new CXGN.List();
    var list_data = lo.getListData(list_id);
    var elements = list_data.elements;

    //parse into javascript object
    var fixed_elements = Object.values(elements).map(function(e){ return e.pop(); });
    var params = JSON.parse("{"+fixed_elements.join(',')+"}");
    // console.log("Params: are: "+params);

    for (var key in params) {
        if (key.match(/element/)) {
            var element_obj = params[key];
            var value = element_obj.value;
            var text = value.replace(/\{(.*?)\}/g, function(match, token) {
                //console.log("token is "+token);
                if (token.match(/Number:/)) {
                    var parts = token.split(':');
                    return parts[1];
                } else {
                    return add_fields[token];
                }
            });
            addToLabel(value, text, element_obj.type, element_obj.size, element_obj.font, element_obj.x, element_obj.y, element_obj.scale);
        }
    }

    var page = params['page_format'];
    document.getElementById('page_format').value = page;
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
    }

    saveAdditionalOptions(
        params['top_margin'],
        params['left_margin'],
        params['horizontal_gap'],
        params['vertical_gap'],
        params['number_of_columns'],
        params['number_of_rows'],
        params['sort_order'],
        params['copies_per_plot']
    );

    console.log("List has been loaded!\n");

}
