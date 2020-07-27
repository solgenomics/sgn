
import '../legacy/jquery.js';
import '../legacy/d3/d3Min.js';




export function init(main_div){
  if (!(main_div instanceof HTMLElement)){
    main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
  }
    var dataset_id;
    
//     main_div.innerHTML = `

// 	<style>
// 	.factor {
// 	    z-index:4;
// 	    border-style:solid;
// 	    border-radius:8px;
// 	    width:200px;
// 	    height:100;
// 	    border-color:#337ab7;
// 	    background-color:#337ab7;
// 	    color:white;
// 	    margin:4px
// 	}
//         .factor_panel {
// 	    min-height:100px;
// 	    height:auto;
// 	    margin-top:0px;
// 	    border-style:dotted;
// 	    border-width:5px;
// 	    color:grey;
// 	    background-color:lightyellow;
// 	}
//         .factor_interaction_panel {
// 	    border-style:dotted;
// 	    border-width:0px;
// 	    margin-top:20px;
// 	    height:auto;
// 	    z-index:1;
// 	}
//         .model_bg {
// 	    margin-left:30px;
// 	    margin-right:30px;
// 	    background-color:#DDEEEE;
// 	    min-height:80px;
// 	    padding-top:10px;
// 	    padding-left:10px;
// 	    padding-bottom:10px;
// 	    border-radius:8px;
// 	}
// 	</style>

// 	<div class="container">
// 	<div class="row">
// 	<div class="col-md-6">

//         1. Choose a dataset

// 	<span style="width:240px" id="mixed_model_dataset_select">
// 	</span>
// 	<button class="btn btn-main" id="mixed_model_analysis_prepare_button">Go!</button>
// 	<br />
// 	<br />

//             <hr />
//         2. Select the dependent variable

// 	<div id="dependent_variable" style="margin-bottom:50px">
//         [ select dataset first ]
// 	</div>

//     </div> <!-- row -->

// 	<div class="col-md-6">

// 	<div id="trait_histogram">
// 	  [Histogram]
//        </div>

// 	</div>
// 	</div> <!-- container -->

//          3. Build model
// 	<hr />
// 	<div class="model_bg" >
// 	<div id="model_string" style="margin-top:10px;margin-bottom:10px;text-align:center;font-weight:bold">[model will appear here in lme4 format]</div>
// 	<button id="store_model_formula" class="btn btn-default btn-sm">Save model</button>
// 	</div>


//     <hr />
// 	<div class="container">
// 	  <div class="row">
//         <div id="left-margin" class="col-md-2"></div>
// 	<div class="col-md-4">
// 	<div class="panel panel-default" style="border-width:0px">
// 	<div class="panel panel-header" style="border-width:0px">Available Factors</div>
// 	     <hr />
//              <div id="factors" class="panel panel-body" style="border-style:dotted;border-width:0px;">
// 	       [ Choose dataset and dependent variable first ]
//              </div>
//         </div>
// 	</div>
//               <div class="col-md-4">
//                 <div  id="fixed_factors_panel" style="border-width:0;" class="panel panel-default">
// 	           <div class="panel-header">Fixed factors</div>
// 	<div id="fixed_factors" class="panel-body factor_panel">

//     <!-- style="background-color:lightyellow;min-height:100px;height:auto;border-style:dotted;border-width:5px;color:grey" --></div>

//                 </div>
// 	<div id="interaction_factor_collection_panel" class="panel panel-default factor_interaction_panel">
//     <!-- style="border-style:dotted;border-width:0px;margin-top:20px;height:auto;z-index:1" -->
//                    <div class="panel-header">
// 	               Fixed factors with interaction<br />
//                        <button  id="add_interaction_factor_button">add new interaction</button>
// 	           </div>
// 	           <div id="interaction_factors_collection" name="interaction_factors_collection" class="panel-body">
// 	           </div>
//                 </div>
// 	<div id="variable_slope_intersect_collection_panel" class="panel panel-default factor_interaction_panel">

// <!--    style="border-style:dotted;border-width:0px;margin-top:20px;height:auto;z-index:1" -->

//         <div class="panel-header">
//               Fixed factors with variable slope/intersects<br />
//               <button  id="add_variable_slope_intersect_button">add new variable slope/intersect</button>
// 	            </div>
// 	            <div id="variable_slope_intersect_collection" class="panel-body">

// 	            </div>
// 	         </div>

// 	         <div style="height:30">&nbsp;</div>
//                   <div id="random_factors_panel" class="panel panel-default" style="border-width:0px">
//           	     <div class="panel-header">Random factors</div>
// 	<div id="random_factors" class="panel-body factor_panel">

//     <!-- style="background-color:lightyellow;min-height:100px;height:auto;border-style:dotted;border-width:5px;color:grey" -->
//                      </div>
//                    </div>
// 	       </div>
//             </div>
// 	</div>

//         <br />
//         <div id="tempfile" style="display:none" >
//         </div>

//         <button style="position:relative;" id="run_mixed_model_button" class="btn btn-main">Go!</button>
// 	<hr />

//     4. Results

// 	<table>
// 	<tr><td>
// 	<div id="mixed_models_anova_results_div">&nbsp;</div>
// 	</td></tr>
// 	<tr><td>
// 	<div id="mixed_models_varcomp_results_div">&nbsp;</div>
// 	</td></tr>
// 	<tr><td>
//         Adjusted means 	     <button id="open_store_adjusted_means_dialog_button" class="btn btn-primary" data-toggle="modal" data-analysis_type="adjusted_means" data-target="#save_analysis_dialog">Save adjusted means</button>
//         <div id="mixed_models_adjusted_means_results_div">[loading...]</div>
// 	</td></tr>
// 	<tr>
// 	<td>
//             BLUPs 	     <button id="open_store_blups_dialog_button" class="btn btn-primary" data-toggle="modal" data-analysis_type="blup" data-target="#save_analysis_dialog">Save BLUPs</button>
//         <div id="mixed_models_blup_results_div">[not available]</div>
//         </td>
// 	</tr>
// 	<tr><td>
// 	    BLUEs
// 	<div id="mixed_models_blues_results_div">[not available]</div>
// 	</td>
// 	</tr>
// 	</table>

// 	[ go throught steps 1-3 first ]
// </div>

//     </div>

// <div id="save_analysis_dialog" class="modal fade">
//   <div class="modal-dialog">
//     <div class="modal-content">
//       <div class="modal-header">
//         <button type="button" class="close" data-dismiss="modal" aria-hidden="true"></button>
//         <h4 class="modal-title">Save analysis results</h4>
// 	</div>
// 	<div class="modal-body">
// 	  <div class="form_group">
//    	    <label class="control-label" for="analysis_name">Analysis name</label> <input name="analysis_name" id="analysis_name" class="form-control" ></input><br />
// 	    <label class="control-label" for="analysis_description">Analysis description</label>
//         <textarea name="description" rows="4" cols="30" class="form-control" id="description"></textarea>
// 	<input type="hidden" name="analysis_file" id="analysis_file" />
// 	<input type="hidden" name="analysis_dir" id="analysis_dir" value="mixedmodels" />
// 	<input type="hidden" name="analysis_protocol" id="analysis_protocol" value="[not set]" />
// 	<div name="analysis_type" id="analysis_type" value="?" style="display:none;"></div>
// 	</div> <!-- form-group -->
//       </div> <!-- modal-body -->
//       <div class="modal-footer">
//         <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
//         <button type="button" id="save_blups_button" class="btn btn-primary">Save changes</button>
//       </div>
//     </div><!-- /.modal-content -->
//   </div><!-- /.modal-dialog -->
// </div><!-- /.modal -->`

//    var mm = $(main_div);

    get_select_box("datasets", "mixed_model_dataset_select", {"checkbox_name":"mixed_model_dataset_select_checkbox"});

    var analysis_type;
    $('#save_analysis_dialog').on('show.bs.modal', function(e) {
	analysis_type = e.relatedTarget.dataset.analysis_type;
	//alert(analysis_type);
	$('#analysis_type').val(analysis_type);
    });

    $('#save_blups_button').click( function() {
	var name = $('#analysis_name').val();
	var description = $('#description').val();
	var file = $('#tempfile').html();
	var basename = file.split('/').reverse()[0];
	var analysis_type = $('#analysis_type').val();
	//alert("analysis type"+analysis_type);
	var final_filename = basename+"."+analysis_type;
	//alert(final_filename);
	
	var selected_datasets = $('#available_datasets').val();
	alert('Calling /ajax/analysis/store/file');
	jQuery.ajax( {
	    'method' : 'POST',
	    'url': '/ajax/analysis/store/file',
	    'dir': 'mixedmodels',
	    'data' : { 'file': final_filename,
		       'dir' : 'mixedmodels',
		       'analysis_type': 'mixed_model_analysis',
		       'analysis_name': name,
		       'dataset_id' : get_dataset_id(),
		       'analysis_protocol' : $('#model_string').val(),
		       'analysis_description' : description
		     },
	    'success' :	function(r) {
		if (r.error) {
		    alert("An error occurred. ("+r.error+")");
		}
		else {
		    if (r.warning) {
			alert("Warning, "+r.warning);
		    }

		    alert("Successfully saved results from " + file + " " +name);
		    return;
		}
	    },
	    'error' : function(r) {
		alert("A protocol error occurred. The system may not be available right now ("+r.responseText+")");
		return;
	    }
	});
    });

    $('#save_adjusted_means_button').click( function() {
	var name = $('#analysis_name').val();
	var file = $('#tempfile').html();
	alert("Successfully saved analysis results. (" + file + " " +name+")");
    });

    $('#mixed_model_analysis_prepare_button').click( function() {

	dataset_id=get_dataset_id();
	if (dataset_id != false) { 
            $.ajax({
                url: '/ajax/mixedmodels/prepare',
                data: { 'dataset_id' : get_dataset_id() },
                success: function(r) {
                    if (r.error) {
                        alert(r.error);
                    }
                    else {
                        $('#dependent_variable').html(r.dependent_variable);
                        var html = "";
			
                        for (var n=0; n<r.factors.length; n++) {
                            html += "<div id=\"factor_"+n+"\" class=\"container factor\">"+r.factors[n]+"</div>";
                        }
                        $('#factors').html(html);
			
                        for (var n=0; n<r.factors.length; n++) {
                            $('#factor_'+n).draggable({ helper:"clone",revert:"invalid"} );
                        }
			
                        $('#tempfile').html(r.tempfile);
                    }
                    $('#fixed_factors').droppable( {drop: function( event, ui ) {
                        $( this )
                        //.addClass( "ui-state-highlight" )
                            .find( "p" )
                            .html( "Dropped!" );
                        var droppable = $(this);
                        var draggable = ui.draggable;
                        // Move draggable into droppable
                        var clone = draggable.clone();
                        clone.draggable({ revert: "invalid", helper:"clone" });
                        clone.css("z-index",3);
                        if (!isCloned(clone)) {
                            setClonedTagProperties(clone);
                        }

                        clone.appendTo(droppable);
                        get_model_string();
                    }});

                    $('#random_factors').droppable( {drop: function( event, ui ) {
                        $( this )
                        //.addClass( "ui-state-highlight" )
                        .find( "p" )
                        .html( "Dropped!" );
                        var droppable = $(this);
                        var draggable = ui.draggable;
                        // Move draggable into droppable
                        var clone = draggable.clone();
                        clone.draggable({ revert: "invalid", helper:"clone" });
                        clone.css("z-index",3);
                        if (!isCloned(clone)) {
                            setClonedTagProperties(clone);
                        }

                        clone.appendTo(droppable);
                        get_model_string();
                    }});

                },
                error: function(r) {
                    alert("ERROR!!!!!");
                }
            });
           }
    });


   $('#add_interaction_factor_button').click( function(e) {

       add_sub_div("interaction_factors_collection", "interaction", "Interaction");
   });

    $('#add_variable_slope_intersect_button').click( function(e) {
	add_sub_div("variable_slope_intersect_collection", "variable_slope_intersect", "Variable slope/intersect");
    });


    var factor_count;

    function add_sub_div(collection_div, div_prefix, collection_name) {

	if (factor_count === undefined) { factor_count=0;}

	var previous_div = factor_count;
	factor_count++;

	var div_name = div_prefix + factor_count;

	var div = '<div id="'+div_name+'_panel" class="panel panel-default" style="border-width:0px"><div id="'+div_name+'_header" class="panel-header"><span id="close_interaction_div_'+factor_count+'" class="remove">X</span> '+collection_name+' Term '+factor_count+'</div><div id="'+div_name+'" class="panel-body factor_panel" ></div></div>';

	$('#'+collection_div).append(div);

	$('#'+div_name).droppable( {
	    drop: function( event, ui ) {
                var droppable = $(this);
		var draggable = ui.draggable;
		// Move draggable into droppable
		var clone = draggable.clone();
                clone.draggable({ revert: "invalid", helper:"clone" });
		clone.css("z-index",2);
                if (!isCloned(clone)) {
		    setClonedTagProperties(clone);
                }

		clone.appendTo(droppable);
		get_model_string();
            }});

        $(document).on("click", "span.remove", function(e) {
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
       e.id = e.html()+'C';
       var html = '<span id="'+e.id+'_remove" class="remove_factor">X</a></span> '+e.html();
       e.html(html);
       $(document).on("click", "span.remove_factor", function(e) { this.parentNode.remove(); get_model_string()});
   }

   $('#dependent_variable').click('#dependent_variable_select', function() {
     var tempfile = $('#tempfile').html();
     var trait_selected = [];
     $('.trait_box:checked').each(function() {
       trait_selected.push($(this).val());
    });

     if(trait_selected.length > 1 || trait_selected.length == 0){
       jQuery('#trait_histogram').html('Please select only one trait at a time to see the histogram!');
     //alert("Histogram can only be displayed for one trait");
     //var trait = trait_selected;
   }else{
      //alert("trait selected is : " + trait_selected);
      var trait = trait_selected[0];


      $.ajax( {
         url: '/ajax/mixedmodels/grabdata',
         data: { 'file' : tempfile },
         success: function(r) {
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


       error: function(e) { alert('error!'); }
     });

  }

   });

    $('#run_mixed_model_button').click( function() {
	//alert("RUNNING!");
        var model = $('#model_string').text();
	var fixed_factors = parse_simple_factors("fixed_factors");
	var random_factors = parse_simple_factors("random_factors");;
	
	var tempfile = $('#tempfile').text();

	var dependent_variables = [];
	$('input[name=dependent_variable_select]:checked').each(function(){
            dependent_variables.push(jQuery(this).val());
	});
	console.log(dependent_variables);
	//alert(model + " "+tempfile+" "+ dependent_variable);
	$.ajax( {
            "url": '/ajax/mixedmodels/run',
	    "method": "POST",
            "data": {
		"model" : model,
		"tempfile" : tempfile,
		"dependent_variables": dependent_variables,
		"fixed_factors" : fixed_factors,
		"random_factors" : random_factors
	    },
            "success": function(r) {
		if (r.error) { alert(r.error);}
		else{
		    $('#mixed_models_adjusted_means_results_div').html('<pre>' + r.adjusted_means_html + '</pre>');
		    $('#mixed_models_blup_results_div').html('<pre>' + r.blups_html+'</pre>');
		    $('#mixed_models_blue_results_div').html('<pre>' + r.blues_html + '</pre>');
		    $('#mixed_models_anova_results_div').html('<pre>'+ r.anova_html+'</pre>');
		    $('#mixed_models_varcomp_results_div').html('<pre>'+r.varcomp_html+'</pre>');
		    
		}
            },
            "error": function(r) {
		alert(r);
            }
	});
    });

}

function get_dataset_id() {
    var selected_datasets = [];
    jQuery('input[name="mixed_model_dataset_select_checkbox"]:checked').each(function() {
        selected_datasets.push(jQuery(this).val());
    });
    if (selected_datasets.length < 1){
        alert('Please select at least one dataset!');
        return false;
    } else if (selected_datasets.length > 1){
        alert('Please select only one dataset!');
        return false;
    } else {	
	var dataset_id=selected_datasets[0];
	return dataset_id;
    }
}

    function extract_model_parameters() {

	var fixed_factors = parse_simple_factors("fixed_factors");

	var interaction_factors = parse_factor_collection("interaction_factor_collection_panel");

	var variable_slope_intersects = parse_factor_collection("variable_slope_intersect_collection_panel");

	var random_factors = parse_simple_factors("random_factors");

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
  $('input[name=dependent_variable_select]:checked').each(function(){
    dependent_variables.push(jQuery(this).val());
  });

        var json =  {
	    'fixed_factors' : fixed_factors,
            'fixed_factors_interaction' : interaction_factors,
	    'variable_slope_intersects' : variable_slope_intersects,
	    'random_factors' : random_factors,
	    'dependent_variables' : dependent_variables

	};
  console.log(json);
        return json;
    }

    function parse_simple_factors(simple_div) {
	//alert("parsing div "+simple_div);
	//alert($('#'+simple_div).html());

	var factors = $('#'+simple_div).children();
	var factor_list = new Array();
	for(var n=0; n<factors.length; n++) {
	    var factor_string = $(factors[n]).text();
	    //alert("FACTOR = "+factor_string);
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

	var collection_divs = $('#'+collection_div).children();
	//alert("COLLECTION PANEL: "+collection_div+" content: "+$('#'+collection_div).html());
	var collection = new Array();
	var grouped_factors = new Array();

	//alert("DIV COUNT = "+collection_divs.length);
	for (var i=1; i< collection_divs.length; i++) { // skip interaction_factors_collection panel header

	    var $div = $(collection_divs[i]);

	    //alert("DIV = "+ $div.text()+" ID="+$div.attr('id'));

	    var top_panels = $div.children();

	    for (var n=0; n< top_panels.length; n++) {
		//alert('top_panel '+$(top_panels[n]).text()+ ' LEN:'+$(top_panels[n]).length +' ID: '+$(top_panels[n]).attr('id'));

		var panel_components = $(top_panels[n]).children();
		var $panel_body = $(panel_components[1]);
		//alert("parsing interaction body..."+$panel_body.text()+ " ID: " +$panel_body.attr('id'));

		var factors = $panel_body.children();

		for (var m=0; m<factors.length; m++) {
		    var $factor = $(factors[m]);
		    var label = $factor.text();

		    // remove X closing box
		    label = label.substr(2);
		    //alert("FACTOR"+label);
		    grouped_factors.push(label);
		}
		collection.push(grouped_factors);
		grouped_factors = new Array();
	    }
	}

	///var fixed_factors_interaction_collection = interaction_collection.join('"],["');
	//alert("finally: "+ JSON.stringify(collection));

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
		    //alert(r.model);
		    jQuery('#model_string').text(r.model);
		}
	    }
	});
    }

    function store_blup_file() {




    }

