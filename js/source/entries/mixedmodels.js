
import '../legacy/jquery.js';
import '../legacy/d3/d3Min.js';

var version = '0.01';

export function init(main_div) {
    if (!(main_div instanceof HTMLElement)) {
        main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
    }

    var dataset_id;

    // alert("WELCOME TO MIXED MODELS!");
    get_select_box("datasets", "mixed_model_dataset_select", { "checkbox_name": "mixed_model_dataset_select_checkbox", "analysis_type":"Mixed Models", "show_compatibility":"yes" });

    jQuery('#mixed_model_analysis_prepare_button').removeClass('active').addClass('inactive');

    $(document).on('click', 'input[name=select_engine]', function (e) {
        //alert('clicked select engine!');
        get_model_string();
    });


    $(document).on('click', '#open_store_adjusted_blups_dialog_button', function (e) {
        $('#generic_save_analysis_dialog').modal("show");
        $('#generic_save_analysis_model_properties').val(model_properties);
        $('#generic_save_analysis_protocol').val($('#model_string').html());
        $('#generic_save_analysis_dataset_id').val(dataset_id);
        $('#generic_save_analysis_accession_names').val(accession_names);
        $('#generic_save_analysis_dataset_id').val(get_dataset_id());
        $('#generic_save_analysis_trait_names').val(traits);
        $('#generic_save_analysis_statistical_ontology_term').val('Adjusted means from BLUPs using LMER R|SGNSTAT:0000034');
        $('#generic_save_analysis_model_language').val('R');
        $('#generic_save_analysis_model_application_name').val('Breedbase Mixed Model Tool');
        $('#generic_save_analysis_model_application_version').val(version);
        $('#generic_save_analysis_model_type').val('mixed_model_lmer');
        $('#generic_save_analysis_result_values').val(adjusted_blups_data);
        $('#generic_save_analysis_result_values_type').val('analysis_result_values_match_accession_names');
        $('#generic_save_analysis_result_summary_values').val(result_summary);
        $('#generic_save_analysis_model_training_data_file').val(input_file);
        $('#generic_save_analysis_model_archived_training_data_file_type').val('mixed_model_input_data');
    });

    $(document).on('click', '#open_store_blups_dialog_button', function (e) {
        $('#generic_save_analysis_dialog').modal("show");
        $('#generic_save_analysis_model_properties').val(model_properties);
        $('#generic_save_analysis_protocol').val($('#model_string').html());
        $('#generic_save_analysis_dataset_id').val(dataset_id);
        $('#generic_save_analysis_accession_names').val(accession_names);
        $('#generic_save_analysis_dataset_id').val(get_dataset_id());
        $('#generic_save_analysis_trait_names').val(traits);
        $('#generic_save_analysis_statistical_ontology_term').val('Phenotypic BLUPs using LMER R|SGNSTAT:0000035');
        $('#generic_save_analysis_model_language').val('R');
        $('#generic_save_analysis_model_application_name').val('Breedbase Mixed Model Tool');
        $('#generic_save_analysis_model_application_version').val(version);
        $('#generic_save_analysis_model_type').val('mixed_model_lmer');
        $('#generic_save_analysis_result_values').val(blups_data);
        $('#generic_save_analysis_result_values_type').val('analysis_result_values_match_accession_names');
        $('#generic_save_analysis_result_summary_values').val(result_summary);
        $('#generic_save_analysis_model_training_data_file').val(input_file);
        $('#generic_save_analysis_model_archived_training_data_file_type').val('mixed_model_input_data');
    });

    $(document).on('click', '#open_store_adjusted_blues_dialog_button', function (e) {
        $('#generic_save_analysis_dialog').modal("show");
        $('#generic_save_analysis_model_properties').val(model_properties);
        $('#generic_save_analysis_protocol').val($('#model_string').html());
        $('#generic_save_analysis_dataset_id').val(dataset_id);
        $('#generic_save_analysis_accession_names').val(accession_names);
        $('#generic_save_analysis_dataset_id').val(get_dataset_id());
        $('#generic_save_analysis_trait_names').val(traits);
        $('#generic_save_analysis_statistical_ontology_term').val('Adjusted means from BLUEs using LMER R|SGNSTAT:0000036');
        $('#generic_save_analysis_model_language').val('R');
        $('#generic_save_analysis_model_application_name').val('Breedbase Mixed Model Tool');
        $('#generic_save_analysis_model_application_version').val(version);
        $('#generic_save_analysis_model_type').val('mixed_model_lmer');
        $('#generic_save_analysis_result_summary_values').val(result_summary);
        $('#generic_save_analysis_result_values_type').val('analysis_result_values_match_accession_names');
        $('#generic_save_analysis_model_training_data_file').val(input_file);
        $('#generic_save_analysis_model_archived_training_data_file_type').val('mixed_model_input_data');
    });


    $(document).on('click', '#open_store_blues_dialog_button', function (e) {
        $('#generic_save_analysis_dialog').modal("show");
        $('#generic_save_analysis_model_properties').val(model_properties);
        $('#generic_save_analysis_protocol').val($('#model_string').html());
        $('#generic_save_analysis_dataset_id').val(dataset_id);
        $('#generic_save_analysis_accession_names').val(accession_names);
        $('#generic_save_analysis_dataset_id').val(get_dataset_id());
        $('#generic_save_analysis_trait_names').val(traits);
        $('#generic_save_analysis_statistical_ontology_term').val('Phenotypic BLUEs using LMER R|SGNSTAT:0000037');
        $('#generic_save_analysis_model_language').val('R');
        $('#generic_save_analysis_model_application_name').val('Breedbase Mixed Model Tool');
        $('#generic_save_analysis_model_application_version').val(version);
        $('#generic_save_analysis_model_type').val('mixed_model_lmer');
        $('#generic_save_analysis_result_values_type').val('analysis_result_values_match_accession_names');
        $('#generic_save_analysis_result_summary_values').val(result_summary);
        $('#generic_save_analysis_model_training_data_file').val(input_file);
        $('#generic_save_analysis_model_archived_training_data_file_type').val('mixed_model_input_data');
    });

    $('#mixed_model_analysis_prepare_button').click(function () {

        dataset_id = get_dataset_id();
        var dataset_trait_outliers = $('#dataset_trait_outliers').is(':checked') ? 1 : 0;

        if (dataset_id != false) {
            $.ajax({
                url: '/ajax/mixedmodels/prepare',
                data: { 'dataset_id': get_dataset_id(),'dataset_trait_outliers': dataset_trait_outliers, },
                success: function (r) {
                    if (r.error) {
                        alert(r.error);
                    }
                    else {
                        $('#dependent_variable').html(r.dependent_variable);
                        var html = "";

                        for (var n = 0; n < r.factors.length; n++) {
                            html += "<div id=\"factor_" + n + "\" class=\"container factor\">" + r.factors[n] + "</div>";
                        }
                        $('#factors').html(html);

                        for (var n = 0; n < r.factors.length; n++) {
                            $('#factor_' + n).draggable({ helper: "clone", revert: "invalid" });
                        }

                        $('#tempfile').html(r.tempfile);
                        //$('#workflow').

                    }
                    $('#fixed_factors').droppable({
                        drop: function (event, ui) {
                            $(this)
                                //.addClass( "ui-state-highlight" )
                                .find("p")
                                .html("Dropped!");
                            var droppable = $(this);
                            var draggable = ui.draggable;
                            // Move draggable into droppable
                            var clone = draggable.clone();
                            clone.draggable({ revert: "invalid", helper: "clone" });
                            clone.css("z-index", 3);
                            if (!isCloned(clone)) {
                                setClonedTagProperties(clone);
                            }

                            clone.appendTo(droppable);
                            get_model_string();
                        }
                    });

                    $('#random_factors').droppable({
                        drop: function (event, ui) {
                            $(this)
                                //.addClass( "ui-state-highlight" )
                                .find("p")
                                .html("Dropped!");
                            var droppable = $(this);
                            var draggable = ui.draggable;
                            // Move draggable into droppable
                            var clone = draggable.clone();
                            clone.draggable({ revert: "invalid", helper: "clone" });
                            clone.css("z-index", 3);
                            if (!isCloned(clone)) {
                                setClonedTagProperties(clone);
                            }

                            clone.appendTo(droppable);
                            get_model_string();
                        }
                    });

                },
                error: function (r) {
                    alert("ERROR!!!!!");
                }
            });
        }
    });


    $('#add_interaction_factor_button').click(function (e) {

        add_sub_div("interaction_factors_collection", "interaction", "Interaction");
    });

    $('#add_variable_slope_intersect_button').click(function (e) {
        add_sub_div("variable_slope_intersect_collection", "variable_slope_intersect", "Variable slope/intersect");
    });


    var factor_count;
    var accession_names;

    var adjusted_blups_data;
    var blups_data;

    var adjusted_blues_data;
    var blues_data;

    var traits;
    var stat_ontology_term;

    var model_properties;
    var result_summary;
    var input_file;

    function add_sub_div(collection_div, div_prefix, collection_name) {

        if (factor_count === undefined) { factor_count = 0; }

        var previous_div = factor_count;
        factor_count++;

        var div_name = div_prefix + factor_count;

        var div = '<div id="' + div_name + '_panel" class="panel panel-default" style="border-width:0px"><div id="' + div_name + '_header" class="panel-header"><span id="close_interaction_div_' + factor_count + '" class="remove">X</span> ' + collection_name + ' Term ' + factor_count + '</div><div id="' + div_name + '" class="panel-body factor_panel" ></div></div>';

        $('#' + collection_div).append(div);

        $('#' + div_name).droppable({
            drop: function (event, ui) {
                var droppable = $(this);
                var draggable = ui.draggable;
                // Move draggable into droppable
                var clone = draggable.clone();
                clone.draggable({ revert: "invalid", helper: "clone" });
                clone.css("z-index", 2);
                if (!isCloned(clone)) {
                    setClonedTagProperties(clone);
                }

                clone.appendTo(droppable);
                get_model_string();
            }
        });

        $(document).on("click", "span.remove", function (e) {
            this.parentNode.parentNode.remove(); get_model_string();
        });


    }

    function isCloned(e) {
        if (e.text().includes('X')) {
            return true;
        }

        return false;
    }
    //onclick="this.parentNode.parentNode.removeChild(this.parentNode); return false;">
    function setClonedTagProperties(e) {
        e.id = e.html() + 'C';
        var html = '<span id="' + e.id + '_remove" class="remove_factor">X</a></span> ' + e.html();
        e.html(html);
        $(document).on("click", "span.remove_factor", function (e) { this.parentNode.remove(); get_model_string() });
    }

    $('#dependent_variable').click('#dependent_variable_select', function () {
        var tempfile = $('#tempfile').html();
        var trait_selected = [];
        $('.trait_box:checked').each(function () {
            trait_selected.push($(this).val());
        });

        if (trait_selected.length > 1 || trait_selected.length == 0) {
            jQuery('#trait_histogram').html('Please select only one trait at a time to see the histogram!');
        } else {

            var trait = trait_selected[0];


            $.ajax({
                url: '/ajax/mixedmodels/grabdata',
                data: { 'file': tempfile },
                success: function (r) {
                    var v = {
                        "$schema": "https://vega.github.io/schema/vega-lite/v2.json",
                        "width": 200,
                        "height": 100,
                        "padding": 5,
                        "data": { 'values': r.data },
                        "mark": "bar",
                        "encoding": {
                            "x": {
                                "bin": true,
                                "field": trait,
                                "type": "quantitative"
                            },
                            "y": {
                                "aggregate": "count",
                                "type": "quantitative"
                            }
                        }
                    };

                    vegaEmbed("#trait_histogram", v);
                },


                error: function (e) { alert('error!'); }
            });

        }

    });

    $('#run_mixed_model_button').click(function () {
        var model = $('#model_string').text();
        var fixed_factors = parse_simple_factors("fixed_factors");
        //alert("FIXED FACTORS: "+fixed_factors);
        var random_factors = parse_simple_factors("random_factors");
        var engine = $('input[name="select_engine"]:checked').val();
        //alert("Engine is "+engine);
        var tempfile = $('#tempfile').text();

        var dependent_variables = [];

        $('input[name=dependent_variable_select]:checked').each(function () {
            dependent_variables.push(jQuery(this).val());
        });
        console.log(dependent_variables);
        $('#working_modal').modal("show");
        $.ajax({
            "url": '/ajax/mixedmodels/run',
            "method": "POST",
            "data": {
		"model" : model,
		"tempfile" : tempfile,
		"dependent_variables": dependent_variables,
		"fixed_factors" : fixed_factors,
		"random_factors" : random_factors,
		"engine" : engine
	    },
            "success": function(r) {
		$('#working_modal').modal("hide");
		if (r.error) { alert(r.error);}
		else {
		    if (r.method === 'random') {
			$('#mixed_models_adjusted_blups_results_div').html(r.adjusted_blups_html);
			$('#mixed_models_blups_results_div').html( r.blups_html );

			$('#adjusted_blups_tab_link').show();
			$('#adjusted_blups_tab_link').addClass('active');
			$('#blups_tab_link').show();

			$('#adjusted_blues_tab_link').removeClass('active');
			$('#adjusted_blues_tab_link').hide();
			$('#blues_tab_link').hide();
		    }
		    else {
	 		$('#mixed_models_adjusted_blues_results_div').html(r.adjusted_blues_html);
			$('#mixed_models_blues_results_div').html(r.blues_html);


			$('#adjusted_blups_tab_link').removeClass('active');
			$('#adjusted_blups_tab_link').hide();
			$('#blups_tab_link').hide();


			$('#adjusted_blues_tab_link').tab('show');
			$('#adjusted_blues_tab_link').addClass('active');
			$('#blues_tab_link').show();
		    }

		    accession_names = JSON.stringify(r.accession_names);

		    adjusted_blups_data = JSON.stringify(r.adjusted_blups_data);

		    adjusted_blues_data = JSON.stringify(r.adjusted_blues_data);
		    blups_data = JSON.stringify(r.blups_data);
		    blues_data = JSON.stringify(r.blues_data);
		    traits = JSON.stringify(r.traits);
			console.log("Traits: "+traits);
		    input_file = r.input_file;
		    result_summary = '{ "method" : "Breedbase mixed model analysis tool" }';

		    var model_properties_data = { "properties" : { "traits" : traits  } } ;
			console.log("traits: "+traits);
		    model_properties = JSON.stringify(model_properties_data);
			//alert("Model properties: "+model_properties);


		}
            },
            "error": function (r) {
                alert(r);
            }
        });
    });

}

function get_dataset_id() {
    var selected_datasets = [];
    jQuery('input[name="mixed_model_dataset_select_checkbox"]:checked').each(function () {
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

function extract_model_parameters() {

    var fixed_factors = parse_simple_factors("fixed_factors");

    var interaction_factors = parse_factor_collection("interaction_factor_collection_panel");

    var variable_slope_intersects = parse_factor_collection("variable_slope_intersect_collection_panel");

    var random_factors = parse_simple_factors("random_factors");

    var engine = jQuery('input[name=select_engine]:checked').val();

    //alert("ENGINE IS NOW: "+engine);

    // var random_factors = $('#random_factors').text();
    // random_factors = random_factors.replace(/X /g, '","');
    // random_factors = random_factors.replace(/\s/g, '');
    // random_factors = random_factors.substr(3);
    // if (random_factors) {
    //     random_factors = '["'+random_factors+'"]';
    // }
    // var random_factors_json;
    // if (random_factors) {
    //     random_factors_json = JSON.parse(random_factors);
    // }

    var dependent_variables = [];
    $('input[name=dependent_variable_select]:checked').each(function () {
        dependent_variables.push(jQuery(this).val());
    });

    var json = {
        'fixed_factors': fixed_factors,
        'fixed_factors_interaction': interaction_factors,
        'variable_slope_intersects': variable_slope_intersects,
        'random_factors': random_factors,
        'dependent_variables': dependent_variables,
        'engine': engine
    };
    console.log(json);
    return json;
}

function parse_simple_factors(simple_div) {

    var factors = $('#' + simple_div).children();
    var factor_list = new Array();
    for (var n = 0; n < factors.length; n++) {
        var factor_string = $(factors[n]).text();
        factor_string = factor_string.replace(/X /g, '');

        if (factor_string) {
            factor_list.push(factor_string);
        }
    }
    return factor_list;
}

function parse_factor_collection(collection_div) {

    // Structure:
    // interaction_factors_collection panel
    //    interaction_factors_collection panel-header
    //    interaction_1_panel panel
    //       interaction_1_header panel-header
    //       interaction_1  panel-body
    //         factor_1 span X FACTOR_NAME1
    //         factor_2 span X FACTOR_NAME2
    //       interaction_2_header panel-header
    //         factor_3 span X FACTOR_NAME3
    //         factor_4 span X FACTOR_NAME4
    //

    var collection_divs = $('#' + collection_div).children();

    var collection = new Array();
    var grouped_factors = new Array();

    for (var i = 1; i < collection_divs.length; i++) { // skip interaction_factors_collection panel header

        var $div = $(collection_divs[i]);

        var top_panels = $div.children();

        for (var n = 0; n < top_panels.length; n++) {

            var panel_components = $(top_panels[n]).children();
            var $panel_body = $(panel_components[1]);

            var factors = $panel_body.children();

            for (var m = 0; m < factors.length; m++) {
                var $factor = $(factors[m]);
                var label = $factor.text();

                // remove X closing box
                label = label.substr(2);
                grouped_factors.push(label);
            }
            collection.push(grouped_factors);
            grouped_factors = new Array();
        }
    }

    var fixed_factors_interaction_json;
    if (collection) {
        //fixed_factors_interaction_collection = '[["'+fixed_factors_interaction_collection+'"]]';
    }
    return collection;

}

function parse_random_factors() {


}


function get_model_string() {
    var params = extract_model_parameters();

    //alert("PARAMS: "+JSON.stringify(params));
    $.ajax( {
	url  : '/ajax/mixedmodels/modelstring',
	method: 'POST',
	data : params,
	error: function(e) {
	    alert("An error occurred"+e);
	},
	success: function(r) {
	    if (r.error) {
		alert(error);
	    }
	    else {
		alert("MODEL STRING: "+r.model);
		console.log("ENGINE AGAIN: "+r.engine+" "+JSON.stringify(r));
		if (r.engine == 'sommer') {
		    jQuery('#model_string').text(r.model[0]+" , random = " + r.model[1]);
		}
                else {
                    jQuery('#model_string').text(r.model);
                }
            }
        }
    });
}

function store_blup_file() {




}
