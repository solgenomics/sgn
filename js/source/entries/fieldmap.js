import "../legacy/d3/d3v4Min.js";
import "../legacy/jquery.js";
import "../legacy/brapi/BrAPI.js";

// Colors to use when labelling multiple trials
const trial_colors = [
    //"#2f4f4f",
    "#ff8c00",
    "#ffff00",
    "#00ff00",
    "#9400d3",
    "#00ffff",
    "#1e90ff",
    "#ff1493",
    "#ffdab9",
    "#228b22",
];
const trial_colors_text = [
    "#ffffff",
    "#000000",
    "#000000",
    "#000000",
    "#ffffff",
    "#000000",
    "#ffffff",
    "#ffffff",
    "#000000",
    "#ffffff",
];

export function init() {
    class FieldMap {
        constructor(trial_id) {
            this.trial_id = String;
            this.plot_arr = Array;
            this.plot_object = Object;
            this.meta_data = {};
            this.brapi_plots = Object;
            this.heatmap_selected = false;
            this.heatmap_selection = String;
            this.heatmap_cached_data = {};
            this.heatmap_object = Object;
            this.display_borders = true;
            this.linked_trials = {};
        }

        set_id(trial_id) {
            this.trial_id = trial_id;
        }

        set_linked_trials(trials = []) {
            this.linked_trials = {};
            trials.forEach((t, i) => {
                const index = i % trial_colors.length;
                this.linked_trials[t.trial_name] = {
                    id: t.trial_id,
                    name: t.trial_name,
                    bg: trial_colors[index],
                    fg: trial_colors_text[index],
                };
            });
        }

        get_linked_trials() {
            return this.linked_trials;
        }

        format_brapi_post_object() {
            let brapi_post_plots = [];
            let count = 1;
            for (let plot of this.plot_arr.filter((plot) => plot.type == "filler")) {
                brapi_post_plots.push({
                    additionalInfo: {
                        invert_row_checkmark: document.getElementById(
                            "invert_row_checkmark"
                        ).checked,
                        top_border_selection: this.meta_data.top_border_selection || false,
                        left_border_selection:
                            this.meta_data.left_border_selection || false,
                        right_border_selection:
                            this.meta_data.right_border_selection || false,
                        bottom_border_selection:
                            this.meta_data.bottom_border_selection || false,
                        plot_layout: this.meta_data.plot_layout || "serpentine",
                    },
                    germplasmDbId: this.meta_data.filler_accession_id,
                    germplasmName: this.meta_data.filler_accession_name,
                    observationUnitName:
                        this.trial_id +
                        " filler " +
                        (parseInt(this.meta_data.max_level_code) + count),
                    observationUnitPosition: {
                        observationLevel: {
                            levelCode: parseInt(this.meta_data.max_level_code) + count,
                            levelName: "plot",
                            levelOrder: 2,
                        },
                        positionCoordinateX:
                            plot.observationUnitPosition.positionCoordinateX,
                        positionCoordinateY:
                            plot.observationUnitPosition.positionCoordinateY,
                    },
                    trialDbId: this.trial_id,
                    studyDbId: this.trial_id,
                });
                count++;
            }
            return brapi_post_plots;
        }

        format_brapi_put_object() {
            let brapi_plots = {};
            for (let plot of this.plot_arr.filter((plot) => plot.type == "data")) {
                brapi_plots[plot.observationUnitDbId] = {
                    additionalInfo: {
                        invert_row_checkmark: document.getElementById(
                            "invert_row_checkmark"
                        ).checked,
                        top_border_selection: this.meta_data.top_border_selection || false,
                        left_border_selection:
                            this.meta_data.left_border_selection || false,
                        right_border_selection:
                            this.meta_data.right_border_selection || false,
                        bottom_border_selection:
                            this.meta_data.bottom_border_selection || false,
                        plot_layout: this.meta_data.plot_layout || "serpentine",
                    },
                    germplasmDbId: plot.germplasmDbId,
                    germplasmName: plot.gerplasmName,
                    observationUnitName: plot.observationUnitName,
                    observationUnitPosition: {
                        observationLevel: {
                            levelCode:
                                plot.observationUnitPosition.observationLevel.levelCode,
                            levelName: "plot",
                            levelOrder: 2,
                        },
                        positionCoordinateX:
                            plot.observationUnitPosition.positionCoordinateX,
                        positionCoordinateY:
                            plot.observationUnitPosition.positionCoordinateY,
                    },
                    trialDbId: this.trial_id,
                };
            }
            return brapi_plots;
        }

        filter_data(data) {
            var pseudo_layout = {};
            var plot_object = {};
            for (let plot of data) {
                plot.type = "data";
                if (isNaN(parseInt(plot.observationUnitPosition.positionCoordinateY))) {
                    plot.observationUnitPosition.positionCoordinateY = isNaN(
                        parseInt(
                            plot.observationUnitPosition.observationLevelRelationships[1]
                                .levelCode
                        )
                    )
                        ? plot.observationUnitPosition.observationLevelRelationships[0]
                            .levelCode
                        : plot.observationUnitPosition.observationLevelRelationships[1]
                            .levelCode;
                    if (
                        plot.observationUnitPosition.positionCoordinateY in pseudo_layout
                    ) {
                        pseudo_layout[
                            plot.observationUnitPosition.positionCoordinateY
                        ] += 1;
                        plot.observationUnitPosition.positionCoordinateX =
                            pseudo_layout[plot.observationUnitPosition.positionCoordinateY];
                    } else {
                        pseudo_layout[plot.observationUnitPosition.positionCoordinateY] = 1;
                        plot.observationUnitPosition.positionCoordinateX = 1;
                    }
                }
                var obs_level = plot.observationUnitPosition.observationLevel;
                if (obs_level.levelName == "plot") {
                    plot.observationUnitPosition.positionCoordinateX = parseInt(
                        plot.observationUnitPosition.positionCoordinateX
                    );
                    plot.observationUnitPosition.positionCoordinateY = parseInt(
                        plot.observationUnitPosition.positionCoordinateY
                    );
                    // if (plot.additionalInfo && plot.additionalInfo.type == "filler") {
                    //     plot.type = "filler";
                    // } else {
                    //     plot.type = "data";
                    // }
                    plot_object[plot.observationUnitDbId] = plot;
                }
            }
            this.plot_object = plot_object;
        }

        filter_heatmap(observations) {
            this.heatmap_object = {};
            for (let observation of observations) {
                let trait_name = observation.observationVariableName;
                if (!this.heatmap_object[trait_name]) {
                    this.heatmap_object[trait_name] = {
                        [observation.observationUnitDbId]: {
                            val: observation.value,
                            plot_name: observation.observationUnitName,
                            id: observation.observationDbId,
                        },
                    };
                } else {
                    this.heatmap_object[trait_name][observation.observationUnitDbId] = {
                        val: observation.value,
                        plot_name: observation.observationUnitName,
                        id: observation.observationDbId,
                    };
                }
            }
        }

        get_plot_order({
            type,
            order,
            start,
            include_borders,
            include_gaps,
            include_subplots,
            include_plants,
            additional_properties
        } = {}) {
            let q = new URLSearchParams({
                trial_ids: [
                    this.trial_id,
                    ...Object.keys(this.linked_trials).map(
                        (e) => this.linked_trials[e].id
                    ),
                ].join(","),
                type: type,
                order: order,
                start: start,
                top_border: !!include_borders && !!this.meta_data.top_border_selection,
                right_border:
                    !!include_borders && !!this.meta_data.right_border_selection,
                bottom_border:
                    !!include_borders && !!this.meta_data.bottom_border_selection,
                left_border:
                    !!include_borders && !!this.meta_data.left_border_selection,
                gaps: !!include_gaps,
                subplots: !!include_subplots,
                plants: !!include_plants,
                ...additional_properties,
            }).toString();
            window.open(`/ajax/breeders/trial_plot_order?${q}`, "_blank");
        }

        set_meta_data() {
            this.plot_arr = Object.values(this.plot_object);
            var min_col = 100000;
            var min_row = 100000;
            var max_col = 0;
            var max_row = 0;
            var max_level_code = 0;
            this.plot_arr.forEach((plot) => {
                max_col =
                    plot.observationUnitPosition.positionCoordinateX > max_col
                        ? plot.observationUnitPosition.positionCoordinateX
                        : max_col;
                min_col =
                    plot.observationUnitPosition.positionCoordinateX < min_col
                        ? plot.observationUnitPosition.positionCoordinateX
                        : min_col;
                max_row =
                    plot.observationUnitPosition.positionCoordinateY > max_row
                        ? plot.observationUnitPosition.positionCoordinateY
                        : max_row;
                min_row =
                    plot.observationUnitPosition.positionCoordinateY < min_row
                        ? plot.observationUnitPosition.positionCoordinateY
                        : min_row;
                max_level_code =
                    parseInt(plot.observationUnitPosition.observationLevel.levelCode) >
                        max_level_code
                        ? plot.observationUnitPosition.observationLevel.levelCode
                        : max_level_code;
            });
            this.meta_data.min_row = min_row;
            this.meta_data.max_row = max_row;
            this.meta_data.min_col = min_col;
            this.meta_data.max_col = max_col;
            this.meta_data.num_rows = max_row - min_row + 1;
            this.meta_data.num_cols = max_col - min_col + 1;
            this.meta_data.max_level_code = max_level_code;
            this.meta_data.display_borders = !jQuery(
                "#include_linked_trials_checkmark"
            ).is(":checked");
            this.meta_data.overlapping_plots = {};
        }

        fill_holes() {
            var fieldmap_hole_fillers = [];
            let last_coord;
            for (let plot of this.plot_arr) {
                if (last_coord === undefined) {
                    last_coord = [0, 1];
                }
                if (plot === undefined) {
                    if (last_coord[0] < this.meta_data.max_col) {
                        fieldmap_hole_fillers.push(
                            this.get_plot_format(
                                `Empty_Space_(${last_coord[0] + 1}_${last_coord[1]})`,
                                last_coord[0] + 1,
                                last_coord[1]
                            )
                        );
                        last_coord = [last_coord[0] + 1, last_coord[1]];
                        this.plot_object[
                            "Empty Space" + String(last_coord[0]) + String(last_coord[1])
                        ] = this.get_plot_format(
                            "empty_space",
                            last_coord[0] + 1,
                            last_coord[1]
                        );
                    } else {
                        fieldmap_hole_fillers.push(
                            this.get_plot_format(
                                `Empty_Space_${this.meta_data.min_col}_${last_coord[1] + 1}`,
                                this.meta_data.min_col,
                                last_coord[1] + 1
                            )
                        );
                        last_coord = [this.meta_data.min_col, last_coord[1]];
                        this.plot_object[
                            "Empty Space" + String(last_coord[0]) + String(last_coord[1])
                        ] = this.get_plot_format(
                            "empty_space",
                            this.meta_data.min_col,
                            last_coord[1] + 1
                        );
                    }
                } else {
                    last_coord = [
                        plot.observationUnitPosition.positionCoordinateX,
                        plot.observationUnitPosition.positionCoordinateY,
                    ];
                }
            }
            this.plot_arr = [
                ...this.plot_arr.filter((plot) => plot !== undefined),
                ...fieldmap_hole_fillers,
            ];
        }

        check_element(selection, element_id) {
            document.getElementById(element_id).checked = selection;
        }

        check_elements(additionalInfo) {
            var elements = [
                "top_border_selection",
                "left_border_selection",
                "right_border_selection",
                "bottom_border_selection",
                "invert_row_checkmark",
            ];
            for (let element of elements) {
                this.check_element(additionalInfo[element], element);
                this.meta_data[element] = additionalInfo[element];
            }
        }

        get_plot_format(type, x, y) {
            // Use the first plot from the trial to get trial-level metadata to give to a border plot
            // NOTE: this will break if plots from multiple trials are loaded
            let p = this.plot_arr[0];
            return {
                type: type,
                observationUnitName: this.trial_id + " " + type,
                observationUnitPosition: {
                    positionCoordinateX: x,
                    positionCoordinateY: y,
                },
                locationName: p.locationName,
                studyName: p.studyName,
            };
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

            if (this.meta_data.retain_layout == false) {
                this.meta_data.max_row = rows + this.meta_data.min_row - 1;
                this.meta_data.max_col = cols + this.meta_data.min_col - 1;
                this.meta_data.plot_layout = this.meta_data.plot_layout
                    ? this.meta_data.plot_layout
                    : "serpentine";

                this.plot_arr = this.plot_arr.filter((plot) => plot.type == "data");
                this.plot_arr.sort(function (a, b) {
                    return (
                        parseFloat(a.observationUnitPosition.observationLevel.levelCode) -
                        parseFloat(b.observationUnitPosition.observationLevel.levelCode)
                    );
                });

                var plot_count = 0;
                var row_count = 0;
                for (
                    let j = this.meta_data.min_row;
                    j < this.meta_data.min_row + rows;
                    j++
                ) {
                    row_count++;
                    var swap_columns =
                        this.meta_data.plot_layout == "serpentine" && j % 2 === 0;
                    var col_count = 0;
                    for (
                        let i = this.meta_data.min_col;
                        i < this.meta_data.min_col + cols;
                        i++
                    ) {
                        col_count++;
                        var row = j;
                        var col = swap_columns ? this.meta_data.max_col - col_count + 1 : i;
                        if (
                            plot_count >= this.plot_arr.length &&
                            this.meta_data.filler_accession_id
                        ) {
                            this.meta_data.post = true;
                            this.plot_arr[plot_count] = this.get_plot_format(
                                "filler",
                                col,
                                row
                            );
                        } else if (
                            plot_count < this.plot_arr.length &&
                            this.plot_arr[plot_count].observationUnitPosition
                        ) {
                            this.plot_arr[
                                plot_count
                            ].observationUnitPosition.positionCoordinateX = col;
                            this.plot_arr[
                                plot_count
                            ].observationUnitPosition.positionCoordinateY = row;
                        }
                        plot_count++;
                    }
                }
            }
        }

        add_corners() {
            var add_corner = (condition_1, condition_2, x, y) => {
                if (condition_1 && condition_2) {
                    this.plot_arr.push(this.get_plot_format("border", x, y));
                }
            };
            add_corner(
                this.meta_data.top_border_selection,
                this.meta_data.left_border_selection,
                this.meta_data.min_col - 1,
                this.meta_data.min_row - 1
            );
            add_corner(
                this.meta_data.top_border_selection,
                this.meta_data.right_border_selection,
                this.meta_data.max_col + 1,
                this.meta_data.min_row - 1
            );
            add_corner(
                this.meta_data.bottom_border_selection,
                this.meta_data.left_border_selection,
                this.meta_data.min_col - 1,
                this.meta_data.max_row + 1
            );
            add_corner(
                this.meta_data.bottom_border_selection,
                this.meta_data.right_border_selection,
                this.meta_data.max_col + 1,
                this.meta_data.max_row + 1
            );
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
                    this.plot_arr.push(
                        this.get_plot_format(
                            "border",
                            row_or_col == "row" ? i : min_or_max,
                            row_or_col == "row" ? min_or_max : i
                        )
                    );
                }
            }
        }

        add_borders() {
            if (this.meta_data.display_borders) {
                this.add_border(
                    "left_border_selection",
                    "col",
                    this.meta_data.min_col - 1
                );
                this.add_border(
                    "top_border_selection",
                    "row",
                    this.meta_data.min_row - 1
                );
                this.add_border(
                    "right_border_selection",
                    "col",
                    this.meta_data.max_col + 1
                );
                this.add_border(
                    "bottom_border_selection",
                    "row",
                    this.meta_data.max_row + 1
                );
                this.add_corners();
            }
        }

        transpose() {
            this.plot_arr = this.plot_arr.filter((plot) => plot.type != "border");
            this.plot_arr.map((plot) => {
                let tempX = plot.observationUnitPosition.positionCoordinateX;
                plot.observationUnitPosition.positionCoordinateX =
                    plot.observationUnitPosition.positionCoordinateY;
                plot.observationUnitPosition.positionCoordinateY = tempX;
            });

            let tempMaxCol = this.meta_data.max_col;
            this.meta_data.max_col = this.meta_data.max_row;
            this.meta_data.max_row = tempMaxCol;

            let tempMinCol = this.meta_data.min_col;
            this.meta_data.min_col = this.meta_data.min_row;
            this.meta_data.min_row = tempMinCol;

            let tempNumCols = this.meta_data.num_cols;
            this.meta_data.num_cols = this.meta_data.num_rows;
            this.meta_data.num_rows = tempNumCols;
            d3.select("svg").remove();
            this.add_borders();
            this.render();
        }

        clickcancel() {

            var event = d3.dispatch("click", "dblclick");
            function cc(selection) {
                var down,
                    tolerance = 5,
                    last,
                    wait = null;
                function dist(a, b) {
                    return Math.sqrt(Math.pow(a[0] - b[0], 2), Math.pow(a[1] - b[1], 2));
                }

                selection.on("mousedown", function () {
                    down = d3.mouse(document.body);
                    last = +new Date();
                });
                selection.on("mouseup", function () {

                    if (dist(down, d3.mouse(document.body)) > tolerance) {
                        return;
                    } else {
                        if (wait) {
                            window.clearTimeout(wait);
                            wait = null;
                            event.call("dblclick", this, d3.event);
                        } else {

                            wait = window.setTimeout(
                                (function (e) {
                                    return function () {
                                        event.call("click", this, e);
                                        wait = null;
                                    };
                                })(d3.event),
                                300
                            );
                        }
                    }
                });
            }
            // return d3.rebind(cc, event, 'on');
            return _rebind(cc, event, "on");

            // Copies a variable number of methods from source to target.
            function _rebind(target, source) {

                var i = 1,
                    n = arguments.length,
                    method;
                while (++i < n)
                    target[(method = arguments[i])] = d3_rebind(
                        target,
                        source,
                        source[method]
                    );
                return target;
            }

            // Method is assumed to be a standard D3 getter-setter:
            // If passed with no arguments, gets the value.
            // If passed with arguments, sets the value and returns the target.
            function d3_rebind(target, source, method) {

                return function () {
                    var value = method.apply(source, arguments);
                    return arguments.length ? target : value;
                };
            }
        }

        heatmap_plot_click(plot, heatmap_object, trait_name) {
            if (d3.event && d3.event.detail > 1) {
                return;
            } else if (
                trait_name in heatmap_object &&
                heatmap_object[trait_name][plot.observationUnitDbId]
            ) {
                let val, plot_name, pheno_id;
                val = heatmap_object[trait_name][plot.observationUnitDbId].val;
                plot_name =
                    heatmap_object[trait_name][plot.observationUnitDbId].plot_name;
                pheno_id = heatmap_object[trait_name][plot.observationUnitDbId].id;
                jQuery("#suppress_plot_pheno_dialog").modal("show");
                jQuery("#myplot_name").html(plot_name);
                jQuery("#pheno_value").html(val);
                jQuery("#mytrait_id").html(trait_name);
                jQuery("#mypheno_id").html(pheno_id);
            }
        }

        fieldmap_plot_click(plot) {
            if (d3.event && d3.event.detail > 1) {
                return;
            } else {
                function btnClick(n) {
                    if (n.length == 0) {
                        jQuery("#hm_view_plot_image_submit").addClass("disabled");
                    } else {
                        jQuery("#hm_view_plot_image_submit").removeClass("disabled");
                    }
                    return true;
                }
                if (plot.type == "data") {
                    var image_ids = plot.plotImageDbIds || [];
                    var replace_accession = plot.germplasmName;
                    var replace_plot_id = plot.observationUnitDbId;
                    var replace_plot_name = plot.observationUnitName;
                    plot;
                    var replace_plot_number =
                        plot.observationUnitPosition.observationLevel.levelCode;

                    jQuery("#plot_image_ids").html(image_ids);
                    jQuery("#hm_replace_accessions_link").find("button").trigger("click");
                    jQuery("#hm_replace_accessions_link").on("click", function () {
                        btnClick(image_ids);
                    });
                    jQuery("#hm_edit_plot_information").html(
                        "<b>Selected Plot Information: </b>"
                    );
                    jQuery("#hm_edit_plot_name").html(replace_plot_name);
                    jQuery("#hm_edit_plot_number").html(replace_plot_number);
                    var old_plot_id = jQuery("#hm_edit_plot_id").html(replace_plot_id);
                    var old_plot_accession = jQuery("#hm_edit_plot_accession").html(
                        replace_accession
                    );
                    jQuery("#hm_replace_plot_accessions_dialog").modal("show");

                    new jQuery.ajax({
                        type: "POST",
                        url: "/ajax/breeders/trial/" + trial_id + "/retrieve_plot_images",
                        dataType: "json",
                        data: {
                            image_ids: JSON.stringify(image_ids),
                            plot_name: replace_plot_name,
                            plot_id: replace_plot_id,
                        },
                        success: function (response) {
                            jQuery("#working_modal").modal("hide");
                            var images = response.image_html;
                            if (response.error) {
                                alert("Error Retrieving Plot Images: " + response.error);
                            } else {
                                jQuery("#show_plot_image_ids").html(images);

                                // jQuery('#view_plot_image_dialog').modal("show");
                            }
                        },
                        error: function () {
                            jQuery("#working_modal").modal("hide");
                            alert("An error occurred retrieving plot images");
                        },
                    });
                }
            }
        }

        addEventListeners() {
            let LocalThis = this;
            let transposeBtn = document.getElementById("transpose_fieldmap");
            transposeBtn.onclick = function () {
                LocalThis.transpose();
            };
        }

        FieldMap() {
            this.addEventListeners();
            var cc = this.clickcancel();
            const colors = [
                "#E4F3F5",
                "#BDE5EA",
                "#9BDCE4",
                "#5CC3D0",
                "#41b6c4",
                "#1d91c0",
                "#225ea8",
                "#253494",
                "#081d58",
            ];
            var trait_name = this.heatmap_selection;
            var heatmap_object = this.heatmap_object;
            var plot_click = !this.heatmap_selected
                ? this.fieldmap_plot_click
                : this.heatmap_plot_click;
            var trait_vals = [];
            var local_this = this;

            if (this.heatmap_selected) {
                let plots_with_selected_trait = heatmap_object[trait_name] || {};
                for (let obs_unit of Object.values(plots_with_selected_trait)) {
                    trait_vals.push(obs_unit.val);
                }

                var colorScale = d3.scaleQuantile().domain(trait_vals).range(colors);
            }

            var is_plot_overlapping = function (plot) {
                if (plot.observationUnitPosition) {
                    let k = `${plot.observationUnitPosition.positionCoordinateX}-${plot.observationUnitPosition.positionCoordinateY}`;
                    return Object.keys(local_this.meta_data.overlapping_plots).includes(
                        k
                    );
                }
                return false;
            };

            var get_fieldmap_plot_color = function (plot) {
                var color;
                if (plot.observationUnitPosition.observationLevelRelationships) {
                    if (is_plot_overlapping(plot)) {
                        color = "#000";
                    } else if (plot.observationUnitPosition.entryType == "check") {
                        color = "#6a5acd";
                    } else if (
                        plot.observationUnitPosition.observationLevelRelationships[1]
                            .levelCode %
                        2 ==
                        0
                    ) {
                        color = "#c7e9b4";
                    } else if (
                        plot.observationUnitName.includes(local_this.trial_id + " filler")
                    ) {
                        color = "lightgrey";
                    } else {
                        color = "#41b6c4";
                    }
                } else {
                    color = "lightgrey";
                }
                return color;
            };

            var get_heatmap_plot_color = function (plot) {
                var color;
                if (is_plot_overlapping(plot)) {
                    color = "#000";
                } else if (!plot.observationUnitPosition.observationLevel) {
                    color = "lightgrey";
                } else {
                    var cs = heatmap_object.hasOwnProperty(trait_name) && heatmap_object[trait_name].hasOwnProperty(plot.observationUnitDbId)
                        ? colorScale(heatmap_object[trait_name][plot.observationUnitDbId].val)
                        : "darkgrey";
                    color = cs ? cs : "lightgrey";
                }
                return color;
            };
            var get_stroke_color = function (plot) {
                var stroke_color;
                if (plot.observationUnitPosition.observationLevel) {
                    if (
                        plot.observationUnitPosition.observationLevelRelationships[0]
                            .levelCode %
                        2 ==
                        0
                    ) {
                        stroke_color = "red";
                    } else {
                        stroke_color = "green";
                    }
                } else {
                    stroke_color = "#666";
                }
                return stroke_color;
            };

            var get_plot_message = function (plot) {
                let html = "";
                if (is_plot_overlapping(plot)) {
                    let k = `${plot.observationUnitPosition.positionCoordinateX}-${plot.observationUnitPosition.positionCoordinateY}`;
                    let plots = local_this.meta_data.overlapping_plots[k];
                    html += `<strong>Overlapping Plots:</strong> ${plots.join(", ")}`;
                } else {
                    html += jQuery("#include_linked_trials_checkmark").is(":checked")
                        ? `<strong>Trial Name:</strong> <span style='padding: 1px 2px; border-radius: 4px; color: ${local_this.linked_trials[plot.studyName].fg
                        }; background-color: ${local_this.linked_trials[plot.studyName].bg
                        }'>${plot.studyName}</span><br />`
                        : "";
                    html += `<strong>Plot Name:</strong> ${plot.observationUnitName}<br />`;
                    if (plot.type == "data") {
                        html += `<strong>Plot Number:</strong> ${plot.observationUnitPosition.observationLevel.levelCode}<br />
                            <strong>Block Number:</strong> ${plot.observationUnitPosition.observationLevelRelationships[1].levelCode}<br />
                            <strong>Rep Number:</strong> ${plot.observationUnitPosition.observationLevelRelationships[0].levelCode}<br />`;
                        if (plot.germplasmName) {
                            html += `<strong>Accession Name:</strong> ${plot.germplasmName}`;
                        } else if (plot.crossName) {
                            html += `<strong>Cross Unique ID:</strong> ${plot.crossName}`;
                        } else if (plot.additionalInfo.familyName) {
                            html += `<strong>Family Name:</strong> ${plot.additionalInfo.familyName}`;
                        }

                        if ( local_this.heatmap_selected ) {
                            let v = '<em>NA</em>';
                            if ( heatmap_object.hasOwnProperty(trait_name) && heatmap_object[trait_name].hasOwnProperty(plot.observationUnitDbId) ) {
                                v = heatmap_object[trait_name][plot.observationUnitDbId].val;
                                v = isNaN(v) ? v : Math.round((parseFloat(v) + Number.EPSILON) * 100) / 100;
                            }
                            html += `<br /><strong>Trait Name:</strong> ${local_this.heatmap_selection}`;
                            html += `<br /><strong>Trait Value:</strong> ${v}`;
                        }
                    }
                }
                return html;
            };

            var handle_mouseover = function (d) {
                if (d.observationUnitPosition.observationLevel) {
                    d3.select(`#fieldmap-plot-${d.observationUnitDbId}`)

                        .style("fill", "green")
                        .style("cursor", "pointer")

                        .style("stroke-width", 3)
                        .style("stroke", "#000000");
                    tooltip
                        .style("opacity", 0.9)
                        .style("left", window.event.clientX + 25 + "px")
                        .style("top", window.event.clientY + "px")
                        .html(get_plot_message(d));
                }
            };


            var handle_mouseout = function (d) {
                d3.select(`#fieldmap-plot-${d.observationUnitDbId}`)
                    .style(
                        "fill",
                        !isHeatMap ? get_fieldmap_plot_color(d) : get_heatmap_plot_color(d)
                    )
                    .style("cursor", "default")
                    .style("stroke-width", 2)
                    .style("stroke", get_stroke_color);
                tooltip.style("opacity", 0);
                plots.exit().remove();
            };

            var plot_x_coord = function (plot) {
                return (
                    plot.observationUnitPosition.positionCoordinateX -
                    min_col +
                    col_increment +
                    1
                );
            };

            var plot_y_coord = function (plot) {
                let y =
                    plot.observationUnitPosition.positionCoordinateY -
                    min_row +
                    row_increment;
                if (
                    plot.type !== "border" &&
                    document.getElementById("invert_row_checkmark").checked !== true
                ) {
                    y = num_rows - y - 1;
                }
                return y;
            };

            var width =
                this.meta_data.display_borders && this.meta_data.left_border_selection
                    ? this.meta_data.num_cols + 3
                    : this.meta_data.num_cols + 2;
            width =
                this.meta_data.display_borders && this.meta_data.right_border_selection
                    ? width + 1
                    : width;
            var height =
                this.meta_data.display_borders && this.meta_data.top_border_selection
                    ? this.meta_data.num_rows + 3
                    : this.meta_data.num_rows + 2;
            height =
                this.meta_data.display_borders && this.meta_data.bottom_border_selection
                    ? height + 1
                    : height;
            var row_increment = this.meta_data.invert_row_checkmark ? 1 : 0;
            row_increment =
                this.meta_data.display_borders &&
                    this.meta_data.top_border_selection &&
                    this.meta_data.invert_row_checkmark
                    ? row_increment + 1
                    : row_increment;
            var y_offset =
                this.meta_data.display_borders &&
                    this.meta_data.top_border_selection &&
                    !this.meta_data.invert_row_checkmark
                    ? 50
                    : 0;
            var col_increment =
                this.meta_data.display_borders && this.meta_data.left_border_selection
                    ? 1
                    : 0;

            // Check the fieldmap for any overlapping plots (plots that share the same x/y coordinates)
            this.meta_data.overlapping_plots = {};
            let plot_positions = {};
            this.plot_arr.forEach((plot) => {
                if (plot.observationUnitPosition) {
                    let x = plot.observationUnitPosition.positionCoordinateX;
                    let y = plot.observationUnitPosition.positionCoordinateY;
                    let p = plot.observationUnitPosition.observationLevel
                        ? plot.observationUnitPosition.observationLevel.levelCode
                        : "";
                    let t = plot.studyName;
                    if (x && y) {
                        let k = `${x}-${y}`;
                        if (!plot_positions.hasOwnProperty(k)) plot_positions[k] = [];
                        plot_positions[k].push(
                            jQuery("#include_linked_trials_checkmark").is(":checked")
                                ? `${p} (${t})`
                                : p
                        );
                        if (plot_positions[k].length > 1) {
                            this.meta_data.overlapping_plots[k] = plot_positions[k];
                        }
                    }
                }
            });

            var min_row = this.meta_data.min_row;
            var max_row = this.meta_data.max_row;
            var min_col = this.meta_data.min_col;
            var max_col = this.meta_data.max_col;
            var num_rows = this.meta_data.num_rows;
            var isHeatMap = this.heatmap_selected;


            var grid = d3
                .select("#fieldmap_chart")
                .append("svg")
                .attr("width", width * 50 + 20 + "px")
                .attr("height", height * 50 + 20 + "px");


            var tooltip = d3
                .select("#fieldmap_chart")
                .append("rect")
                .attr("id", "tooltip")
                .attr("class", "tooltip")
                .style("position", "fixed")
                .style("opacity", 0);

            var plots = grid.selectAll("plots").data(this.plot_arr);
            plots.append("title");
            plots
                .enter()
                .append("rect")
                .attr("x", (d) => {
                    return plot_x_coord(d) * 50;
                })
                .attr("y", (d) => {
                    return plot_y_coord(d) * 50 + 15 + y_offset;
                })
                .attr("rx", 2)
                .attr("id", (d) => {
                    return `fieldmap-plot-${d.observationUnitDbId}`;
                })
                .attr("class", "col bordered")
                .attr("width", 48)
                .attr("height", 48)
                .style("stroke-width", 2)
                .style("stroke", get_stroke_color)
                .style(
                    "fill",
                    !isHeatMap ? get_fieldmap_plot_color : get_heatmap_plot_color
                )
                .on("mouseover", handle_mouseover)
                .on("mouseout", handle_mouseout)
                .call(cc);


            cc.on("click", (el) => {
                var plot = d3.select(el.srcElement).data()[0];
                plot_click(plot, heatmap_object, trait_name);
            });
            cc.on("dblclick", (el) => {
                var me = d3.select(el.srcElement);
                var d = me.data()[0];
                if (d.observationUnitDbId) {
                    window.open("/stock/" + d.observationUnitDbId + "/view");
                }
            });

            // Add a colored band to the bottom of the plot box to indicate different trials
            if (jQuery("#include_linked_trials_checkmark").is(":checked")) {
                plots
                    .enter()
                    .append("rect")
                    .attr("x", (d) => {
                        return plot_x_coord(d) * 50 + 4;
                    })
                    .attr("y", (d) => {
                        return plot_y_coord(d) * 50 + 54 + y_offset;
                    })
                    .attr("rx", 2)
                    .attr("width", 40)
                    .attr("height", 6)
                    .style("fill", (d) => {
                        return local_this.linked_trials[d.studyName].bg;
                    })
                    .style("opacity", (d) => {
                        return is_plot_overlapping(d) ? "0" : "100";
                    });
            }

            plots.append("text");
            plots
                .enter()
                .append("text")
                .attr("x", (d) => {
                    return plot_x_coord(d) * 50 + 10;
                })
                .attr("y", (d) => {
                    return plot_y_coord(d) * 50 + 50 + y_offset;
                })
                .text((d) => {
                    if (
                        !d.observationUnitName.includes(local_this.trial_id + " filler") &&
                        d.type == "data" &&
                        !is_plot_overlapping(d)
                    ) {
                        return d.observationUnitPosition.observationLevel.levelCode;
                    }
                })
                .on("mouseover", handle_mouseover)
                .on("mouseout", handle_mouseout);

            var image_icon = function (d) {
                var image = d.plotImageDbIds || [];
                var plot_image;
                if (image.length > 0) {
                    plot_image = "/static/css/images/plot_images.png";
                } else {
                    plot_image = "";
                }
                return plot_image;
            };

            plots
                .enter()
                .append("image")
                .attr("xlink:href", image_icon)
                .attr("x", (d) => {
                    return plot_x_coord(d) * 50 + 5;
                })
                .attr("y", (d) => {
                    return plot_y_coord(d) * 50 + 15 + y_offset;
                })
                .attr("width", 20)
                .attr("height", 20)
                .on("mouseover", handle_mouseover)
                .on("mouseout", handle_mouseout);

            plots.exit().remove();

            var row_label_arr = [];
            var col_label_arr = [];
            for (let i = min_row; i <= max_row; i++) {
                row_label_arr.push(i);
            }
            for (let i = min_col; i <= max_col; i++) {
                col_label_arr.push(i);
            }

            var row_labels_col = 1;
            var col_labels_row = 0;
            if (!this.meta_data.invert_row_checkmark) {
                col_labels_row =
                    this.meta_data.display_borders &&
                        this.meta_data.bottom_border_selection
                        ? num_rows + 1
                        : num_rows;
                row_label_arr.reverse();
            }

            grid
                .selectAll(".rowLabels")
                .data(row_label_arr)
                .enter()
                .append("text")
                .attr("x", row_labels_col * 50 - 25)
                .attr("y", (label, i) => {
                    let y = this.meta_data.invert_row_checkmark ? i + 1 : i;
                    y =
                        this.meta_data.display_borders &&
                            this.meta_data.top_border_selection &&
                            this.meta_data.invert_row_checkmark
                            ? y + 1
                            : y;
                    return y * 50 + 45 + y_offset;
                })
                .text((label) => {
                    return label;
                });

            grid
                .selectAll(".colLabels")
                .data(col_label_arr)
                .enter()
                .append("text")
                .attr("x", (label, i) => {
                    let x = label - min_col + col_increment + 2;
                    return x * 50 - 30;
                })
                .attr("y", col_labels_row * 50 + 45 + y_offset)
                .text((label) => {
                    return label;
                });
        }

        load() {
            d3.select("svg").remove();
            this.change_dimensions(this.meta_data.num_cols, this.meta_data.num_rows);
            this.add_borders();
            this.render();
        }

        render() {
            jQuery("#working_modal").modal("hide");
            jQuery("#fieldmap_chart").css({ display: "inline-block" });
            jQuery("#container_fm").css({
                display: "inline-block",
                overflow: "auto",
            });
            jQuery("#trait_heatmap").css("display", "none");
            jQuery("#container_heatmap").css("display", "none");
            jQuery("#trait_heatmap").css("display", "none");
            this.FieldMap();
        }
    }

    const mapObj = new FieldMap();
    return mapObj;
}
