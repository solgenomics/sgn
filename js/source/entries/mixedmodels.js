
import '../../legacy/jquery.js';
import '../../legacy/d3/d3Min.js';

export function init(main_div){
  if (!(main_div instanceof HTMLElement)){
    main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
  }  

    main_div.innerHTML = `
	<div class="container">
	<div class="row">
	<div class="col-md-6">

        1. Choose a dataset

	<span style="width:240px" id="mixed_model_dataset_select">
	</span>
	<button class="btn btn-main" id="mixed_model_analysis_prepare_button">Go!</button>
	<br />
	<br />

            <hr />
        2. Select the dependent variable

	<div id="dependent_variable" style="margin-bottom:50px">
        [ select dataset first ]
	</div>

    </div> <!-- row -->

	<div class="col-md-6">

	<div id="trait_histogram">
	  [Histogram]
       </div>

	</div>
	</div> <!-- container -->

         3. Build model
	<hr />
	<div style="margin-left:30px; margin-right:30px;background-color:#FFEEEE;min-height:80px;padding-top:10px;padding-left:10px; padding-bottom:10px;border-radius:8px">
	<div id="model_string" style="margin-top:10px;margin-bottom:10px;text-align:center;font-weight:bold">[model will appear here in lme4 format]</div>
	<button id="store_model_formula" class="btn btn-default btn-sm">Save model</button>
	</div>


    <hr />	
	<div class="container">
	  <div class="row">
        <div id="left-margin" class="col-md-2"></div>
	<div class="col-md-4">
	<div class="panel panel-default" style="border-width:0px">
	<div class="panel panel-header" style="border-width:0px">Available Factors</div>
	     <hr />
             <div id="factors" class="panel panel-body" style="border-style:dotted;border-width:0px;">
	       [ Choose dataset and dependent variable first ]
             </div>
        </div>
	</div>
              <div class="col-md-4">
                <div  id="fixed_factors_panel" style="border-width:0;" class="panel panel-default">
	           <div class="panel-header">Fixed factors</div>
	           <div id="fixed_factors" class="panel-body" style="background-color:lightyellow;min-height:100px;height:auto;border-style:dotted;border-width:5px;color:grey"></div>
           
                </div>
	       <div id="interaction_factor_collection_panel" class="panel panel-default" style="border-style:dotted;border-width:0px;margin-top:20px;height:auto;z-index:1" >
                   <div class="panel-header">
	               Fixed factors with interaction<br />
                       <button  id="add_interaction_factor_button">add new interaction</button>
	           </div>
	           <div id="interaction_factors_collection" name="interaction_factors_collection" class="panel-body">
	           </div>
                </div>
		<div id="variable_slope_intersect_collection_panel" class="panel panel-default" style="border-style:dotted;border-width:0px;margin-top:20px;height:auto;z-index:1" >

	           <div class="panel-header">
	              Fixed factors with variable slope/intersects<br />
                      <button  id="add_variable_slope_intersect_button">add new variable slope/intersect</button>
	            </div>
	            <div id="variable_slope_intersect_collection" class="panel-body">
	
	            </div>
	         </div>
             
	         <div style="height:30">&nbsp;</div>
                  <div id="random_factors_panel" class="panel panel-default" style="border-width:0px">
          	     <div class="panel-header">Random factors</div>
	             <div id="random_factors" class="panel-body" style="background-color:lightyellow;min-height:100px;height:auto;border-style:dotted;border-width:5px;color:grey">          
                     </div>
                   </div>
	       </div>
            </div>
	</div>
	
        <br />
        <div id="tempfile" style="display:none" >
        </div>

        <button style="position:relative;" id="run_mixed_model_button" class="btn btn-main">Go!</button>
	<hr />
	4. Results
    
        BLUPs
        <div id="mixed_models_results_div">
	[ go throught steps 1-3 first ]
</div>
	     <button id="store_blups_button">Save BLUPs</button>
    </div>`


	
    var mm = $(main_div);
    
    get_select_box("datasets", "mixed_model_dataset_select", {});
  
     $('#mixed_model_analysis_prepare_button').click( function() { 
       var dataset_id=$('#available_datasets').val();
       $.ajax({
         url: '/ajax/mixedmodels/prepare',
         data: { 'dataset_id' : dataset_id },
         success: function(r) { 
           if (r.error) { 
             alert(r.error);
           }
             else {
             $('#dependent_variable').html(r.dependent_variable);
             var html = "";

             for (var n=0; n<r.factors.length; n++) { 
                html += "<div style=\"z-index:4;border-style:solid;border-radius:8px;width:200px;height:100;border-color:#337ab7;background-color:#337ab7;color:white;margin:4px;text-align:center\" id=\"factor_"+n+"\" class=\"container factor\">"+r.factors[n]+"</div>";
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

	var div = '<div id="'+div_name+'_panel" class="panel panel-default" style="border-width:0px"><div id="'+div_name+'_header" class="panel-header"><span id="close_interaction_div_'+factor_count+'" class="remove">X</span> '+collection_name+' Term '+factor_count+'</div><div id="'+div_name+'" class="panel-body interaction_factor_group" style="min-height:100px;height:auto;margin-top:0px;border-style:dotted;border-width:5px;color:grey;background-color:lightyellow;"></div></div>';

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

   $('#dependent_variable').on('change', '#dependent_variable_select', function() { 
      var tempfile = $('#tempfile').html();
      var trait = $('#dependent_variable_select').val();
      $.ajax( {
         url: '/ajax/mixedmodels/grabdata',
         data: { 'file' : tempfile },
         success: function(r)  { 
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
   });

   $('#run_mixed_model_button').click( function() { 
       var model = $('#model_string').text();
       //alert('Model: '+model);
       var tempfile = $('#tempfile').text();
       var dependent_variable = $('#dependent_variable_select').val();
       //alert(model + " "+tempfile+" "+ dependent_variable);
       $.ajax( {
           "url": '/ajax/mixedmodels/run',
	   "method": "POST",
           "data": { "model" : model, "tempfile" : tempfile, "dependent_variable": dependent_variable },
           "success": function(r) { 
               if (r.error) { alert(r.error);}
               else{ 
		   $('#mixed_models_results_div').html('<pre>' + r.html + '</pre>');
               }
           },
           "error": function(r) { 
               alert(r);
           }
       });      
   });
    

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

	var dependent_variable = $('#dependent_variable_select').val();

        var json =  {
	    'fixed_factors' : fixed_factors,
            'fixed_factors_interaction' : interaction_factors,
	    'variable_slope_intersects' : variable_slope_intersects, 
	    'random_factors' : random_factors,
	    'dependent_variable' : dependent_variable
	    
	};
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
		    alert(r.model);
		    jQuery('#model_string').text(r.model);
		}
	    }
	});
    }
    };



