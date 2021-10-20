import '../legacy/d3/d3Min.js';
import '../legacy/jquery.js';
import '../legacy/brapi/BrAPI.js';


export function init() {
    class FieldMap {
        constructor(trial_id) {
            this.trial_id = String;
            this.plot_arr = Array;
            this.plot_object = Object;
            this.meta_data = {};
            this.brapi_plots = Object;
        }

        set_id(trial_id) {
            this.trial_id = trial_id;
        }

        format_brapi_post_object() {
            let brapi_post_plots = {};
            for (let plot of this.plot_arr.filter(plot => plot.type == "filler")) {
                console.log(plot);
            }
        }

        format_brapi_put_object() {
            let brapi_plots = {};
            console.log(this.plot_arr);
            for (let plot of this.plot_arr.filter(plot => plot.type == "data")) {
                brapi_plots[plot.observationUnitDbId] = {
                    "additionalInfo": {
                        "invert_row_checkmark": document.getElementById("invert_row_checkmark").checked,
                        "top_border_selection": this.meta_data.top_border_selection || false,
                        "left_border_selection": this.meta_data.left_border_selection || false,
                        "right_border_selection": this.meta_data.right_border_selection || false,
                        "bottom_border_selection": this.meta_data.bottom_border_selection || false,
                        "plot_layout": this.meta_data.plot_layout || "serpentine",
                    },
                    "germplasmDbId": plot.germplasmDbId,
                    "germplasmName": plot.gerplasmName,
                    "observationUnitName": plot.observationUnitName,
                    "observationUnitPosition": {
                        "observationLevel": {
                            "levelCode": plot.observationUnitPosition.observationLevel.levelCode,
                            "levelName": "plot",
                            "levelOrder": 2
                        },
                        "positionCoordinateX": plot.observationUnitPosition.positionCoordinateX,
                        "positionCoordinateY": plot.observationUnitPosition.positionCoordinateY,
                    },
                    "trialDbId": this.trial_id,
                }
            }
            return brapi_plots;
        }

        filter_data(data) {
            console.log('incoming data', data);
            var plants = [];
            var plant_obj = {};
            var plot_object = {};
            for (let plot of data) {
                var obs_level = plot.observationUnitPosition.observationLevel;
                if (obs_level.levelName == "plot") {
                    plot.observationUnitPosition.positionCoordinateX = parseInt(plot.observationUnitPosition.positionCoordinateX);
                    plot.observationUnitPosition.positionCoordinateY = parseInt(plot.observationUnitPosition.positionCoordinateY);
                    plot.type = "data";
                    plot.plants = [];
                    plot_object[obs_level.levelCode] = plot;
                } else if (obs_level.levelName == "plant") {
                    plot_object[plot.additionalInfo.observationUnitParent];
                }
            }
            this.plot_object = plot_object;
        }

        invert_rows() {
            if (this.meta_data.invert_row_checkmark) {
                console.log('inverting');
                for (let i = 0; i < this.plot_arr.length; i++) {
                    this.plot_arr[i].observationUnitPosition.positionCoordinateY = this.meta_data.max_row - this.plot_arr[i].observationUnitPosition.positionCoordinateY + 1;
                }
            }

        }

        set_meta_data() {
            // this.plot_arr = JSON.parse(JSON.stringify(Object.values(this.plot_object)));
            this.plot_arr = Object.values(this.plot_object);
            console.log('test', this.plot_arr);
            var min_col = 100000;
            var min_row = 100000;
            var max_col = 0;
            var max_row = 0;
            for (let plot of this.plot_arr) {
                max_col = plot.observationUnitPosition.positionCoordinateX > max_col ? plot.observationUnitPosition.positionCoordinateX : max_col;
                min_col = plot.observationUnitPosition.positionCoordinateX < min_col ? plot.observationUnitPosition.positionCoordinateX : min_col;
                max_row = plot.observationUnitPosition.positionCoordinateY > max_row ? plot.observationUnitPosition.positionCoordinateY : max_row;
                min_row = plot.observationUnitPosition.positionCoordinateY < min_row ? plot.observationUnitPosition.positionCoordinateY : min_row;
            }
            this.meta_data.min_row = min_row;
            this.meta_data.max_row = max_row;
            this.meta_data.min_col = min_col;
            this.meta_data.max_col = max_col;
            this.meta_data.num_rows = max_row - min_row + 1;
            this.meta_data.num_cols = max_col - min_col + 1;
            console.log('dims', this.meta_data);
        }

        check_element(selection, element_id) {
            document.getElementById(element_id).checked = selection;
        }

        check_elements(additionalInfo) {
            var elements = ["top_border_selection", "left_border_selection", "right_border_selection", "bottom_border_selection", "invert_row_checkmark"];
            for (let element of elements) {
                this.check_element(additionalInfo[element], element);
                this.meta_data[element] = additionalInfo[element];
                console.log('meta data', this.meta_data);
            }
        }

        get_plot_format(type, x, y) {
            return { 
                type: type, observationUnitPosition: { positionCoordinateX: x, positionCoordinateY: y, } 
            }
        }

        change_dimensions(cols, rows) {
            var cols = parseInt(cols);
            var rows = parseInt(rows);
            this.meta_data.post = false;
            this.meta_data.num_cols = cols;
            this.meta_data.num_rows = rows;
            this.plot_arr = [
                ...this.plot_arr.slice(0, Object.entries(this.plot_object).length),
            ];
            var count = 0;
            var column;

            if (!this.meta_data.plot_layout) {
                this.meta_data.plot_layout = "serpentine";
            }
            for (let j = 0; j < (rows); j++) {
                for (let i = 0; i < (cols); i++) {
                    column = this.meta_data.plot_layout == "serpentine" && j % 2 == 1 ? this.meta_data.max_col - i : this.meta_data.min_col + i;
                    if (!this.plot_arr[count]) {
                        this.meta_data.post = true;
                        this.plot_arr[count] = this.get_plot_format('filler', column, this.meta_data.max_row - j, );
                    } else if (this.plot_arr[count].observationUnitPosition) {
                        this.plot_arr[count].observationUnitPosition.positionCoordinateX = column;
                        this.plot_arr[count].observationUnitPosition.positionCoordinateY = this.meta_data.max_row - j;
                    }
                        count += 1;
                }
            }
            this.meta_data.max_row = rows + this.meta_data.min_row - 1;
            this.meta_data.max_col = cols + this.meta_data.min_col - 1;


        }
        add_corners() {
            var add_corner = (condition_1, condition_2, x,y) => {
                if (condition_1 && condition_2) {
                    this.plot_arr.push(this.get_plot_format("border", x, y));
                }
            }
            add_corner(this.meta_data.top_border_selection, this.meta_data.left_border_selection, this.meta_data.min_col - 1, this.meta_data.min_row - 1);
            add_corner(this.meta_data.top_border_selection, this.meta_data.right_border_selection, this.meta_data.max_col + 1, this.meta_data.min_row - 1);
            add_corner(this.meta_data.bottom_border_selection, this.meta_data.left_border_selection, this.meta_data.min_col - 1, this.meta_data.max_row + 1);
            add_corner(this.meta_data.bottom_border_selection, this.meta_data.right_border_selection, this.meta_data.max_col + 1, this.meta_data.max_row + 1);

        }
        add_border(border_element, row_or_col, min_or_max) {
            var start_iter;
            var end_iter;
            if (row_or_col == "row") {
                start_iter = this.meta_data.min_col;
                end_iter = this.meta_data.max_col;
            } else if (row_or_col == "col") {
                start_iter = this.meta_data.min_row;
                end_iter = this.meta_data.max_row;
            }

            if (this.meta_data[border_element]) {
                for (let i = start_iter; i <= end_iter; i++) {
                    this.plot_arr.push(this.get_plot_format("border", row_or_col == "row" ? i : min_or_max, row_or_col == "row" ? min_or_max : i));
                }
            }
        }

        add_borders() {
            this.add_border("top_border_selection", "row", this.meta_data.min_row - 1);
            this.add_border("bottom_border_selection", "row", this.meta_data.max_row + 1);
            this.add_border("left_border_selection", "col", this.meta_data.min_col - 1);
            this.add_border("right_border_selection", "col", this.meta_data.max_col + 1);
            this.add_corners();
        }

        clickcancel() {
            var event = d3.dispatch('click', 'dblclick');
            function cc(selection) {
                var down,
                    tolerance = 5,
                    last,
                    wait = null;
                function dist(a, b) {
                    return Math.sqrt(Math.pow(a[0] - b[0], 2), Math.pow(a[1] - b[1], 2));
                }
                selection.on('mousedown', function() {
                    down = d3.mouse(document.body);
                    last = +new Date();
                });
                selection.on('mouseup', function() {
                    if (dist(down, d3.mouse(document.body)) > tolerance) {
                        return;
                    } else {
                        if (wait) {
                            window.clearTimeout(wait);
                            wait = null;
                            event.dblclick(d3.event);
                        } else {
                            wait = window.setTimeout((function(e) {
                                return function() {
                                    event.click(e);
                                    wait = null;
                                };
                            })(d3.event), 300);
                        }
                    }
                });
            };
            return d3.rebind(cc, event, 'on');
        }
        plot_click(plot) {
            if (d3.event && d3.event.detail > 1) {
                console.log(d3.event);
                return;
            } else {
                function btnClick(n){
                    if (n.length == 0){
                        jQuery("#hm_view_plot_image_submit").addClass("disabled");
                    } else {
                        jQuery("#hm_view_plot_image_submit").removeClass("disabled");
                    }
                    return true; 
                }
                if (plot.type == "data") {
                    var image_ids = plot.imageDbIds || [];
                    var replace_accession = plot.germplasmName;
                    var replace_plot_id = plot.observationUnitDbId;
                    var replace_plot_name = plot.observationUnitName;
                    var replace_plot_number = plot.observationUnitPosition.observationLevel.levelCode;

                    jQuery('#plot_image_ids').html(image_ids);
                    jQuery('#hm_replace_accessions_link').find('button').trigger('click');
                    jQuery("#hm_replace_accessions_link").on("click", function(){ btnClick(image_ids); });
                    jQuery('#hm_edit_plot_information').html('<b>Selected Plot Information: </b>');
                    jQuery('#hm_edit_plot_name').html(replace_plot_name);
                    jQuery('#hm_edit_plot_number').html(replace_plot_number);
                    var old_plot_id = jQuery('#hm_edit_plot_id').html(replace_plot_id);
                    var old_plot_accession = jQuery('#hm_edit_plot_accession').html(replace_accession);
                    jQuery('#hm_replace_plot_accessions_dialog').modal('show');

                    new jQuery.ajax({
                        type: 'POST',
                        url: '/ajax/breeders/trial/'+ trial_id +'/retrieve_plot_images',
                        dataType: "json",
                        data: {
                                'image_ids': JSON.stringify(image_ids),
                                'plot_name': replace_plot_name,
                                'plot_id': replace_plot_id,
                        },
                        success: function (response) {
                        jQuery('#working_modal').modal("hide");
                        var images = response.image_html;
                        if (response.error) {
                            alert("Error Retrieving Plot Images: "+response.error);
                        }
                        else {
                            jQuery("#show_plot_image_ids").html(images);

                        // jQuery('#view_plot_image_dialog').modal("show"); 
                        }
                        },
                        error: function () {
                            jQuery('#working_modal').modal("hide");
                            alert('An error occurred retrieving plot images');
                        }
                    });
                }
            }
        }
        
        FieldMap() {
            var cc = this.clickcancel();
            var plot_click = this.plot_click;
            var get_plot_color = function(plot) {
                var color;
                if (plot.observationUnitPosition.observationLevelRelationships) {
                    if (plot.observationUnitPosition.entryType == "check") {
                        color = "#6a5acd";
                    } else if (plot.observationUnitPosition.observationLevelRelationships[1].levelCode % 2 == 0) {
                        color = "#c7e9b4";
                    } else {
                        color = "#41b6c4";
                    }
                } else if (plot.type == "filler") {
                    color = "#41b6c4";
                } else {
                    color = "lightgrey";
                }
                return color;
            }
    
            var get_stroke_color = function(plot) {
                var stroke_color;
                if (plot.observationUnitPosition.observationLevel) {
                    if (plot.observationUnitPosition.observationLevelRelationships[0].levelCode % 2 == 0) {
                        stroke_color = "red"
                    } else {
                        stroke_color = "green";
                    }
                } else {
                    stroke_color = "black";
                }
                return stroke_color;
            }

            var get_plot_message = function(plot) {
                return plot.observationUnitName;
            }
            var width = this.meta_data.left_border_selection ? this.meta_data.max_col + 3 : this.meta_data.max_col + 2;
            width = this.meta_data.right_border_selection ? width + 1 : width;
            var height = this.meta_data.top_border_selection ? this.meta_data.max_row + 3 : this.meta_data.max_row + 2;
            height = this.meta_data.bottom_border_selection ? height + 1 : height;
            var grid = d3.select("#container_fm")
            .append("svg")
            .attr("width", width * 50 + 20 + "px")
            .attr("height", height * 50 + 20 + "px");
            var plots = grid.selectAll("plots")
            .data(this.plot_arr);
            plots.append("title");
            plots.enter().append("rect")
                .attr("x", function(d) { return (d.observationUnitPosition.positionCoordinateX + 1) * 50 + 15; })
                .attr("y", function(d) { return (d.observationUnitPosition.positionCoordinateY + 1) * 50 + 15; })
                .attr("rx", 4)
                .attr("class", "col bordered")
                .attr("width", 50)
                .attr("height", 50)
                .style("stroke-width", 2)
                .style("stroke", function(d) { return get_stroke_color(d)})
                .style("fill", function(d) {return get_plot_color(d)})
                .on("mouseover", function(d) { if (d.observationUnitPosition.observationLevel) { d3.select(this).style('fill', 'green').style('cursor', 'pointer'); }})
                .on("mouseout", function(d) { 
                    d3.select(this).style('fill', get_plot_color(d)).style('cursor', 'default')
                    plots.exit().remove();
                }).call(cc);

            cc.on("click", function(el) { var plot = d3.select(el.srcElement).data()[0]; plot_click(plot) });
            cc.on("dblclick", function(el) { var me = d3.select(el.srcElement);
                var d = me.data()[0];
                if (d.observationUnitDbId) {
                    window.open('/stock/'+d.observationUnitDbId+'/view');        
                }
            });
            plots.append("text");
                    plots.enter().append("text")
                    .attr("x", function(d) { return (d.observationUnitPosition.positionCoordinateX + 1) * 50 + 25; })
                    .attr("y", function(d) { return (d.observationUnitPosition.positionCoordinateY + 1) * 50 + 45; })
                    .text(function(d) { if (d.observationUnitPosition.observationLevel) { return d.observationUnitPosition.observationLevel.levelCode; }});
            plots.select("title").text(function(d) { return get_plot_message(d); }) ;

            var row_label_arr = [];
            var col_label_arr = [];
            for (let i = 1; i <= this.meta_data.num_rows; i++) {
                row_label_arr.push(i);
            }
            for (let i = 1; i <= this.meta_data.num_cols; i++) {
                col_label_arr.push(i);
            }

            var rowLabels = grid.selectAll(".rowLabels") 
            .data(row_label_arr)
            .enter().append("text")
            .attr("x", ((this.meta_data.left_border_selection ? this.meta_data.min_col - 1 : this.meta_data.min_col) * 50) + 35)
            .attr("y", function(label) {return (label+1) * 50 + 45})
            .text(function(label) {return label});

            var colLabels = grid.selectAll(".colLabels") 
            .data(col_label_arr)
            .enter().append("text")
            .attr("x", function(label) {return (label+1) * 50 + 35})
            .attr("y", ((this.meta_data.top_border_selection ? this.meta_data.min_row - 1 : this.meta_data.min_row) * 50) + 45)
            .text(function(label) {return label});


        }


        load() {
            d3.select("svg").remove();
            this.change_dimensions(this.meta_data.num_cols, this.meta_data.num_rows);
            this.change_dimensions(this.meta_data.num_cols, this.meta_data.num_rows);
            this.invert_rows();
            this.add_borders();
            this.render();
            console.log('meta data', this.meta_data);
            console.log(this.plot_arr);
        }

        render() {
            jQuery("#working_modal").modal("hide");
            jQuery("#chart_fm").css({ "display": "inline-block" });
            jQuery("#container_fm").css({ "display": "inline-block", "overflow": "auto" });
            jQuery("#trait_heatmap").css("display", "none");
            jQuery("#container_heatmap").css("display", "none");
            jQuery("#trait_heatmap").css("display", "none");
            this.FieldMap();

        }
    }

    const mapObj = new FieldMap();
    return mapObj;
}