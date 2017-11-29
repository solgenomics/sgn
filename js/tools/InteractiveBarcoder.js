
var page_formats = {};
page_formats["Select a page format"] = {};
page_formats["US Letter PDF"] = {
    page_width: 611,
    page_height: 790.7,
    label_sizes: {
            'Select a label size': {
            },
            '1" x 2 5/8"': {
                label_width: 533.4,
                label_height: 203.2,
                left_margin: 13.68,
                top_margin: 36.7,
                horizontal_gap: 10,
                vertical_gap: 0,
                number_of_columns: 3,
                number_of_rows: 10
            },
            '1" x 4"': {
                label_width: 812.8,
                label_height: 203.2,
                left_margin: 13.68,
                top_margin: 36.7,
                horizontal_gap: 10,
                vertical_gap: 0,
                number_of_columns: 2,
                number_of_rows: 10
            },
            '1 1/3" x 4"': {
                label_width: 812.8,
                label_height: 270.93,
                left_margin: 13.68,
                top_margin: 36.7,
                horizontal_gap: 10,
                vertical_gap: 0,
                number_of_columns: 2,
                number_of_rows: 7
            },
            '2" x 2 5/8"': {
                label_width: 533.4,
                label_height: 406.4,
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
            'Select a label size': {
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

page_formats["Zebra printer file"] = {
    label_sizes: {
            'Select a label size': {
            },
            '1 1/4" x 2"': {
                label_width: 401.4,
                label_height: 245,
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
            'Select a label size': {
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

var label_options = {};
label_options["Select add type"] = {};
label_options["PDF Text"] = {
    value: "Text",
    sizes: {
        min: 1,
        max: 72,
        step: 1,
        value: 32
    },
    fonts: [{
        style: "",
        value: "Select a font"
    }, {
        style: "font-family:courier;",
        value: "Courier"
    }, {
        style: "font-family:courier;font-weight:bold;",
        value: "Courier-Bold"
    }, {
        style: "font-family:courier;font-style: oblique;",
        value: "Courier-Oblique"
    }, {
        style: "font-family:courier;font-weight:bold;font-style: oblique;",
        value: "Courier-BoldOblique"
    }, {
        style: "font-family:helvetica;",
        value: "Helvetica"
    }, {
        style: "font-family:helvetica;font-weight:bold;",
        value: "Helvetica-Bold"
    }, {
        style: "font-family:helvetica;font-style: oblique;",
        value: "Helvetica-Oblique"
    }, {
        style: "font-family:helvetica;font-weight:bold;font-style: oblique;",
        value: "Helvetica-BoldOblique"
    }, {
        style: "font-family:times;",
        value: "Times"
    }, {
        style: "font-family:times;font-weight:bold;",
        value: "Times-Bold"
    }, {
        style: "font-family:times;font-style: italic;",
        value: "Times-Italic"
    }, {
        style: "font-family:times;font-weight:bold;font-style: italic;",
        value: "Times-BoldItalic"
    }]
};

label_options["Zebra Text"] = {
    value: "Text",
    sizes: [{
        name: "Select a size",
        value: ""
    }, {
        name: "10",
        value: "10"
    }, {
        name: "20",
        value: "20"
    }, {
        name: "30",
        value: "30"
    }, {
        name: "39",
        value: "39"
    }, {
        name: "49",
        value: "49"
    }, {
        name: "58",
        value: "58"
    }, {
        name: "66",
        value: "66"
    }]
};

label_options["1D Barcode"] = {
    value: "Code128",
    sizes: [{
        name: "Select a size",
        value: ""
    }, {
        name: "1",
        value: "1"
    }, {
        name: "2",
        value: "2"
    }, {
        name: "3",
        value: "3"
    }, {
        name: "4",
        value: "4"
    }]
};

label_options["2D Barcode"] = {
    value: "QR",
    sizes: [{
        name: "Select a size",
        value: ""
    }, {
        name: "4",
        value: "4"
    }, {
        name: "5",
        value: "5"
    }, {
        name: "6",
        value: "6"
    }, {
        name: "7",
        value: "7"
    }, {
        name: "8",
        value: "8"
    }, {
        name: "9",
        value: "9"
    }, {
        name: "10",
        value: "10"
    }]
};

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
    
    var lo = new CXGN.List();
    $('#design_list').html(lo.listSelect('design_list', ['dataset'], 'Select a saved_design', 'refresh'));
    $('#design_list_list_select').change(
      function() {
        load_design();
    });
    
    $('#d3-save-button').click(function() {
        var lo = new CXGN.List();
        var new_name = $('#save_design_name').val();
        console.log("Saving label design to list named " + new_name);
        var page_params = retrievePageParams();
        page_params = JSON.stringify(page_params);
        console.log("Page params are" + JSON.stringify(page_params));
        
        var label_elements = document.getElementsByClassName('label-element');
        label_elements = Array.prototype.slice.call(label_elements); // convert to array
        label_params = label_elements.map(getLabelDetails);
        console.log("Label params are" + JSON.stringify(label_params));
        //label_params = JSON.stringify(label_params);

        var data = page_params.slice(1, -1).split(",").join("\n");
        console.log("label_param length is: "+label_params.length)
        for (i=0; i < label_params.length; i++) {
            data += "\nelement"+i+": "+JSON.stringify(label_params[i]);
        }

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
    
    // var builder = textTemplater.builder("#d3-custom-templater", fields);
    
    $("#edit_print_settings").on("click", function() { 
        $('#editPrintSettingsModal').modal('show');
    });
    
    $(document).on("change", "#d3-custom-templater", function() {
        var tstring = builder.getTemplate();
        $("#d3-custom-content").val(tstring);
    });

    $(document).on("change", "#trial_select", function() {

        var trial_id = document.getElementById("trial_select").value;
        console.log("trial selected has id " + trial_id);
        d3.select("#d3-text-field-input").selectAll("option").remove();
        d3.select("#d3-barcode-text-input").selectAll("option").remove();

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
            },
            success: function(response) {
                if (response.error) {
                    alert("An error occured while retrieving the design elements of this trial: " + JSON.stringify(response.error));
                } else {
                    console.log("Got longest elements: " + JSON.stringify(response));
                    var add_fields = [{
                        name: "Select a field",
                        value: ""
                    }, {
                        value: response.Accession,
                        name: "Accession"
                    }, {
                        value: response.Plot_Name,
                        name: "Plot_Name"
                    }, {
                        value: response.Plot_Number,
                        name: "Plot_Number"
                    }, {
                        value: response.Rep_Number,
                        name: "Rep_Number"
                    }, {
                        value: response.Row_Number,
                        name: "Row_Number"
                    }, {
                        value: response.Col_Number,
                        name: "Col_Number"
                    }, {
                        value: response.Trial_Name,
                        name: "Trial_Name"
                    }, {
                        value: response.Year,
                        name: "Year"
                    }, {
                        value: response.Pedigree_String,
                        name: "Pedigree_String"
                    }, {
                        value: "Custom",
                        name: "Custom"
                    },];
                    
                    createAdders(add_fields);
                    
                    var fields = [response.Accession, response.Plot_Name, response.Plot_Number, response.Rep_Number, response.Row_Number, response.Col_Number, response.Trial_Name, response.Year,response.Pedigree_String];
                    var builder = textTemplater.builder("#d3-custom-templater", fields);

                    document.getElementById("d3-page-format").style.display = "inline";
                    document.getElementById("d3-load-design").style.display = "inline";
                    
                    var page_type_select = d3.select("#d3-page-type-select");
                    page_type_select.selectAll("option")
                        .data(Object.keys(page_formats))
                        .enter().append("option")
                        .text(function(d) {
                            return d
                        });
                    $('#d3-page-type-select').focus();
                }
            },
            error: function(request, status, err) {
                alert("Unable to retrieve design elements of this trial. Please confirm this trial has a design, or try again with a different trial.");
            }
        });
    });

    var page_type_select = d3.select("#d3-page-type-select");
    page_type_select.on("input", function() {
        
        var page_type = d3.select(this).node().value;
        
        switchPageDependentOptions(page_type); // show correct download and text options
        
        if (page_type == 'Custom') {
            document.getElementById("d3-page-custom-dimensions-div").style.display = "inline";
        } else {
            document.getElementById("d3-page-custom-dimensions-div").style.display = "none";
        }
            
        // load label size and label field options based on page type
        var label_sizes = page_formats[page_type].label_sizes;
        d3.select("#d3-label-size-select").selectAll("option").remove();
        d3.select("#d3-label-size-select").selectAll("option")
            .data(Object.keys(label_sizes))
            .enter().append("option")
            .text(function(d) {
                return d
            })   
        document.getElementById("d3-label-format").style.display = "inline";
        $('#d3-label-size-select').focus();
    });

    // Resize draw area according to selected label size
    $('#d3-label-size-select').change(function() {
        var val = $(this).find('option:selected').val();
        
        if (val == 'Custom') {
            document.getElementById("d3-label-custom-dimensions-div").style.display = "inline";
        } else {
            document.getElementById("d3-label-custom-dimensions-div").style.display = "none";
            
            var page_type = d3.select("#d3-page-type-select").node().value;
            var label_sizes = page_formats[page_type].label_sizes;
            var width = label_sizes[val].label_width;
            var height = label_sizes[val].label_height;
            changeLabelSize(width, height);
            document.getElementById("d3-draw-div").style.display = "inline";
            document.getElementById("d3-adders").style.display = "inline";
        }
        
        // set print settings in modal
        document.getElementById("d3-top-margin").value = label_sizes[val].top_margin;
        document.getElementById("d3-left-margin").value = label_sizes[val].left_margin;
        document.getElementById("d3-horizontal-gap").value = label_sizes[val].horizontal_gap;
        document.getElementById("d3-vertical-gap").value = label_sizes[val].vertical_gap;
        document.getElementById("d3-column-number").value = label_sizes[val].number_of_columns;
        document.getElementById("d3-row-number").value = label_sizes[val].number_of_rows;

    });

    d3.select("#d3-apply-custom-label-size").on("click", function() { 
        
        //save and apply custom label size
        var page_type = d3.select("#d3-page-type-select").node().value;
        var custom_label = page_formats[page_type].label_sizes['Custom'];
        width = document.getElementById("d3-label-custom-width").value;
        width = width * 8;
        height = document.getElementById("d3-label-custom-height").value;
        height = height * 8;
        custom_label.label_width = width;
        custom_label.label_height = height;
        changeLabelSize(width, height);
        document.getElementById("d3-draw-div").style.display = "inline";
        document.getElementById("d3-adders").style.display = "inline";
        $('#d3-add-field-input').focus();
    });

    // $('#d3-custom-field-input').change(function(){
    //     console.log("Change noticed, text is "+$(this).find('option:selected').text());
    //     $('#d3-text-content').append($(this).find('option:selected').val());
    // });


    $('#d3-add-field-input').change(function() {
        console.log("Change noticed, text is " + $(this).find('option:selected').text());
        if ($(this).find('option:selected').val() == 'Custom') {
            $('#customFieldModal').modal('show');
        }
    });

    d3.select(".d3-add-custom-text")
        .style("margin-left", "1em");
    d3.select("#d3-custom-field")
        .on("click", function() {
            var custom_content = d3.select("#d3-custom-content").text();
            //$("#d3-text-field-input").find('option:selected').text(text_content);
            // $("#d3-text-field-input").find('option:selected').val(text_content);
            $("#d3-add-field-input").find('option:selected').text(custom_content);
            // text_content.selectAll(".d3-text-placeholder").each(function(d,i){
            //   var th = d3.select(this)
            //   th.html("").text(th.attr("key"))
            //   
            // });
            // var text = text_content.text();
            // var fontSize = _x.invert(d3.select("#d3-font-size-input").node().value);
            // addText(text,fontSize)
        });
    $('#d3-add-type-input').change(function() {
        var type = $(this).find('option:selected').text();
        var value = label_options[type].value;
        var sizes = label_options[type].sizes;
        if (type == "PDF Text") {
            
            // set up font select
            var fonts = label_options[type].fonts;
            d3.select("#d3-add-font-input").selectAll("option").remove();
            d3.select("#d3-add-font-input").selectAll("option")
                .data(fonts)
                .enter().append("option")
                .text(function(d) {
                    return d.value
                })
                .attr("style", function(d) {
                    return d.style
                })
                .attr("value", function(d) {
                    return d.value
                });
            document.getElementById("d3-add-font-div").style.display = "inline";
            
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
                grid_slider.node().value = this.value;
            });
            $("#d3-add-size-slider").show();
            
        } else {
            document.getElementById("d3-add-font-div").style.display = "none";
            $("#d3-add-size-input").replaceWith('<select id="d3-add-size-input" class="form-control"></select>&nbsp&nbsp');
            d3.select("#d3-add-size-input").selectAll("option")
                .data(sizes)
                .enter().append("option")
                .text(function(d) {
                    return d.name
                })
                .attr("value", function(d) {
                    return d.value
                });
            $("#d3-add-size-slider").hide();
        }
    
    });

    $("#d3-edit-print-settings").on("click", function() {
        var page_type = d3.select("#d3-page-type-select").node().value;
        var label_type = d3.select("#d3-label-size-select").node().value;
        page_formats[page_type].label_sizes[label_type].top_margin = document.getElementById("d3-top-margin").value;
        page_formats[page_type].label_sizes[label_type].left_margin = document.getElementById("d3-left-margin").value;
        page_formats[page_type].label_sizes[label_type].horizontal_gap = document.getElementById("d3-horizontal-gap").value;
        page_formats[page_type].label_sizes[label_type].vertical_gap = document.getElementById("d3-vertical-gap").value;
        page_formats[page_type].label_sizes[label_type].number_of_columns = document.getElementById("d3-column-number").value;
        page_formats[page_type].label_sizes[label_type].number_of_rows = document.getElementById("d3-row-number").value;
    });

    $("#d3-add").on("click", function() {
        var field_select = document.getElementById("d3-add-field-input");
        var selected_option = field_select.options[field_select.selectedIndex];
        var display_text = selected_option.value;
        var field = selected_option.text;
        var type = document.getElementById("d3-add-type-input").value;
        // 
        if (field != 'Custom') {
            field = '{$' + selected_option.text + '}';
        } else {
            field = display_text;
        }

        var style;
        var font;
        if (document.getElementById("d3-add-font-div").style.display == "inline") {
            var font_select = document.getElementById("d3-add-font-input");
            var selected_font_option = font_select.options[font_select.selectedIndex];
            style = selected_font_option.getAttribute("style")
            font = selected_font_option.getAttribute("value");
        }
        var size = document.getElementById("d3-add-size-input").value;
        console.log("addToLabel args include text: " + display_text + "\nfield: " + field + "\ntype: " + type + "\nsize: " + size + "\nstyle: " + style + "\nfont: " + font);
        addToLabel(display_text, field, type, size, style, font);
    });
    
    $("#d3-save-button").on("click", function() {
        
    });
    
    $("#d3-pdf-button, #d3-zpl-button").on("click", function() {
        var download_type = $(this).val();
        console.log("You clicked the download "+download_type+" button.");

        var ladda = Ladda.create(this);
        ladda.start();
        var token = new Date().getTime(); //use the current timestamp as the token name and value
        manage_dl_with_cookie(token, ladda);

        var trial_id = document.getElementById("trial_select").value;
        var design = retrievePageParams();
        var label_elements = document.getElementsByClassName('label-element');
        label_elements = Array.prototype.slice.call(label_elements); // convert to array
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
            id: "d3-label-area"
        }).classed("d3-draw-svg", true);

    //set up background
    svg.append('rect')
        .classed("d3-bg", true)
        .attr({
            x: 0,
            y: 0,
            fill: "#FFF",
            border:"1px solid black;"
        })
        .on("click", clearSelection);

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
    var label_elements = document.getElementsByClassName('label-element');
    label_elements = Array.prototype.slice.call(label_elements);
    if (label_elements.length < 1) {
        document.getElementById("d3-download").style.display = "none";
    }
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

function switchPageDependentOptions(page_type) {
     console.log("Page type is: " + page_type);
    if (page_type == 'Zebra printer file') { // disable PDF text option and pdf download
        d3.select("#d3-add-type-input").selectAll("option")
        .each(function(d) {
            console.log("d is: "+JSON.stringify(d));
            if (d === "PDF Text") {
              d3.select(this).property("disabled", true)
            }
            if (d === "Zebra Text") {
              d3.select(this).property("disabled", false)
            }
        });
        document.getElementById("d3-pdf-button").style.display = "none";
        document.getElementById("d3-zpl-button").style.display = "inline";
    } else { // disable Zebra text option and zpl download
        d3.select("#d3-add-type-input").selectAll("option")
        .each(function(d) {
            if (d === "Zebra Text") {
              d3.select(this).property("disabled", true)
            }
            if (d === "PDF Text") {
              d3.select(this).property("disabled", false)
            }
        });
        document.getElementById("d3-zpl-button").style.display = "none";
        document.getElementById("d3-pdf-button").style.display = "inline";
    }
}

function addToLabel(display_text, field, type, size, style, font) {
    svg = d3.select(".d3-draw-svg");

    switch (type) {
        case "Text":
            var newTB = svg.append("g")
                .classed("text-box", true);
            var newText = newTB
                .append("text")
                .attr({
                    "font-size": size,
                    "size": size,
                    "type": font,
                    "style": style || "font-family:courier;",
                    "dominant-baseline": "mathematical",
                    text: display_text,
                    value: field,
                    class: "label-element",
                })
                .text(display_text);
            newTB.classed("draggable", true)
                .classed("selectable", true)
                .call(draggable)
                .call(selectable, false)
                .on("mouseup", dragSnap);
            break;

        case "Code128":
        case "QR":
            var page_type = d3.select("#d3-page-type-select").node().value;
            var label = d3.select("#d3-label-size-select").node().value;
            var label_sizes = page_formats[page_type].label_sizes;
            var width = label_sizes[label].label_width;
            var height = label_sizes[label].label_height;
            var new_barcode = svg.append("g")
                .classed("barcode", true)
                .classed("draggable", true)
                .classed("selectable", true)
                .call(draggable)
                .call(selectable, true)
                .call(doTransform, function(state, selection) {
                    state.translate[0] += ( width / 2) - (100 / 2)
                    state.translate[1] += ( height / 2) - (100 / 2)
                })
                .on("mouseup", dragSnap)
                .append("svg:image")
                .attr({
                    x: 0,
                    y: 0,
                    class: "label-element",
                    value: field,
                    size: size,
                    type: type
                })
                .attr("xlink:href", "/barcode/preview?content=" + encodeURIComponent(display_text) + "&type=" + encodeURIComponent(type) + "&size=" + encodeURIComponent(size));
            new_barcode.call(doTransform, doSnap);
            break;
    }

    var label_elements = document.getElementsByClassName('label-element');
    label_elements = Array.prototype.slice.call(label_elements);
    if (label_elements.length > 0) {
        document.getElementById("d3-download").style.display = "inline";
    }

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
            return d
        })
        .attr("value", function(d) {
            return label_options[d].value
        });
        
    //load field options
    d3.select("#d3-add-field-input").selectAll("option").remove();
    d3.select("#d3-add-field-input").selectAll("option")
        .data(add_fields)
        .enter().append("option")
        .text(function(d) {
            return d.name
        })
        .attr("value", function(d) {
            return d.value
        });

}

function getLabelDetails(element, index) {

    var transform_attributes = parseTransform(element.parentNode.getAttribute('transform')); // return transform attributes as an object
    //console.log("Transform attributes are: "+JSON.stringify(transform_attributes));
    var coords = transform_attributes.translate;
    var scale = transform_attributes.scale || [1, 1];
    var rect = element.getBBox();
    var width = rect.width * scale[0];
    var height = rect.height * scale[1];

    return {
        x: coords[0],
        y: coords[1],
        height: height,
        width: width,
        value: element.getAttribute("value"),
        type: element.getAttribute("type"),
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

    var page_type = d3.select("#d3-page-type-select").node().value;
    var label_type = d3.select("#d3-label-size-select").node().value;
    var label_sizes = page_formats[page_type].label_sizes;
    
    var page_params = {
        page_type: d3.select("#d3-page-type-select").node().value,
        page_width: page_formats[page_type].page_width || document.getElementById("d3-page-custom-width").value,
        page_height: page_formats[page_type].page_height || document.getElementById("d3-page-custom-height").value,
        starting_x: label_sizes[label_type].left_margin,
        starting_y: page_formats[page_type].page_height - label_sizes[label_type].top_margin,
        x_increment: (label_sizes[label_type].label_width/2.83)  + label_sizes[label_type].horizontal_gap,
        y_increment: - ((label_sizes[label_type].label_height/2.83) + label_sizes[label_type].vertical_gap), // adjusted for pdf caretesian coords
        number_of_columns: label_sizes[label_type].number_of_columns - 1, // for 0 indexing
        number_of_rows: label_sizes[label_type].number_of_rows -1, // for 0 indexing
        copies_per_plot: document.getElementById("num_labels").value,
        sort_order: document.getElementById("sort_order").value,
        label_type: d3.select("#d3-label-size-select").node().value,
        label_width: label_sizes[label_type].label_width,
        label_height: label_sizes[label_type].label_height,
    }
    return page_params;
    
}

function load_design() {
    //parse JSON
    //set params
    //create elements
    
}
