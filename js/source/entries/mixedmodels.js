

import '../../legacy/jquery.js';

export function init(main_div){
  if (!(main_div instanceof HTMLElement)){
    main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
  }  

    main_div.innerHTML = `
	<div class="container">
	<div class="row">
	<div class="col-md-6">
	
	Choose a dataset: 
	<span style="width:240px" id="mixed_model_dataset_select">
	</span>
	<button class="btn btn-main" id="mixed_model_analysis_prepare_button">Go!</button>
	
	
	<br />
	<br />
	Choose dependent variable:<br />
	<div id="dependent_variable">
	</div>

    </div> <!-- row -->

    <div class="col-md-6">
	<div id="trait_histogram">
	  [Histogram]
        </div>
	</div>
	</div> <!-- container -->
	
        
	
	<div class="container">
	  <div class="row">
        <div id="left-margin" class="col-md-2"></div>
	<div class="col-md-4">
	<div id="model_string">[model]</div>
	<div class="panel panel-default" style="border-width:0px">
	<div class="panel panel-header" style="border-width:0px">Available Factors</div>
             <div id="factors" class="panel panel-body" style="border-style:dotted;border-width:0px;">
	       Available factors
             </div>
        </div>
	</div>
              <div class="col-md-4">
                <div  id="fixed_factors_panel" style="border-width:0;" class="panel panel-default">
	           <div class="panel-header">Fixed factors</div>
	           <div id="fixed_factors" class="panel-body" style="background-color:lightyellow;min-height:100px;height:auto;border-style:dotted;border-width:5px;color:grey"></div>
           
                </div>
	        <div id="fixed_factors_collection_panel" class="panel panel-default" style="border-style:dotted;border-width:0px;margin-top:20px;height:auto;z-index:1" >
	           <div class="panel-header">
	             Fixed factors with interaction
	           <button  id="add_interaction_factor_button">add new interaction</button>         </div>
	            <div id="fixed_factors_collection" class="panel-body">
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
        <br />
        <div id="tempfile" style="display:none" >
        </div>

        <button style="position:relative;" id="run_mixed_model_button" class="btn btn-main">Go!</button>

        <div id="mixed_models_results_div">
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
                html += "<div style=\"z-index:4;border-style:solid;border-radius:8px;width:200px;height:100;border-color:#337ab7;background-color:#337ab7;color:white;margin:4px;text-align:center\" id=\"factor_"+n+"\" class=\"container\">"+r.factors[n]+"</div>";
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

      add_interaction_div();	       
   });


    var divnr;
    function add_interaction_div() {
      
	if (divnr === undefined) { divnr=0;}
	
	var previous_div = divnr;
	divnr++;

	var div_name = "interaction_"+divnr;

	var div = '<div id="'+div_name+'_panel" class="panel panel-default" style="border-width:0px"><div id="'+div_name+'_header" class="panel-header"><span id="close_interaction_div_'+divnr+'" class="remove">X</span> Interaction Term '+divnr+'</div><div id="'+div_name+'" class="panel-body" style="min-height:100px;height:auto;margin-top:0px;border-style:dotted;border-width:5px;color:grey;background-color:lightyellow;"></div></div>';

	$('#fixed_factors_collection').append(div);

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
	    alert("BOO2!");
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
       var html = '<span id="'+e.id+'_remove" class="remove">X</a></span> '+e.html();
       e.html(html);
       $(document).on("click", "span.remove", function(e) { this.parentNode.remove(); get_model_string()});
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
       var tempfile = $('#tempfile').text();
       var dependent_variable = $('#dependent_variable_select').val();
       alert(model + tempfile+ dependent_variable);
       $.ajax( {
           "url": '/ajax/mixedmodels/run',
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
	var fixed_factors = $('#fixed_factors').text();
	fixed_factors = fixed_factors.replace(/X /g, '","');
	fixed_factors = fixed_factors.substr(3);
	var fixed_factors_json;
	if (fixed_factors) {
	    fixed_factors = '["'+fixed_factors+'"]';
	    fixed_factors_json = JSON.parse(fixed_factors);
	}

	
	var fixed_factors_interactions = new Array();
	$('#fixed_factors_collection').children().each( function() {
	    if ($(this).children().size()>0) { 
		var interactions = this.childNodes;
		alert(JSON.stringify(interactions));
		var panel_div = interactions.childNodes;
		var fixed_factors_interaction = panel_div[1];
		var fixed_factors_interaction = fixed_factors_interaction_div.text();
		fixed_factors_interaction = fixed_factors_interaction.replace(/X /g, ',');
		fixed_factors_interaction = fixed_factors_interaction.substr(1);
		fixed_factors_interaction = fixed_factors_interaction.replace(/,/g, '","');
		fixed_factors_interactions.push(fixed_factors_interaction);
	    }
	    
	});
	var fixed_factors_interaction = fixed_factors_interactions.join('"],["');
	var fixed_factors_interaction_json;
	if (fixed_factors_interaction) {
	    fixed_factors_interaction = '[["'+fixed_factors_interaction+'"]]';
	    fixed_factors_interaction_json =   JSON.parse(fixed_factors_interaction) ;
	}
	
        var random_factors = $('#random_factors').text();
        random_factors = random_factors.replace(/X /g, '","');
	random_factors = random_factors.replace(/\s/g, '');
        random_factors = random_factors.substr(3);
	if (random_factors) {
	    random_factors = '["'+random_factors+'"]';
	}
	var random_factors_json;
	if (random_factors) {
	    random_factors_json = JSON.parse(random_factors);
	}

	var dependent_variable = $('#dependent_variable_select').val();

	
        var json =  {
	    'fixed_factors' : fixed_factors_json,
            'fixed_factors_interaction' : fixed_factors_interaction_json,
	    'random_factors' : random_factors_json,
	    'dependent_variable' : dependent_variable
	    
	};
        return json;
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
		    jQuery('#model_string').html(JSON.stringify(r.model));
		}
	    }
	});
    }
};



