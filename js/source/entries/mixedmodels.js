

import '../../legacy/jquery.js';

export function init(main_div){
  if (!(main_div instanceof HTMLElement)){
    main_div = document.getElementById(main_div.startsWith("#") ? main_div.slice(1) : main_div);
  }  

    main_div.innerHTML = `
	<div style="width:300px">
	Choose a dataset: 
	<span style="width:240px" id="mixed_model_dataset_select">
	</span>
	<button class="btn btn-main" id="mixed_model_analysis_prepare_button">Go!</button>
	</div>
	
	<br />
	<br />
	Choose dependent variable:<br />
	<div id="dependent_variable">
	</div>
	
	<div id="trait_histogram">
	  [Histogram]
        </div>

        <div id="model_string">[model]</div>
	
	<div class="container">
	  <div class="row">

             <div id="factors" class="col-md-3" style="border-style:dotted;border-width:0px;">
	       Available factors
             </div>

              <div class="col-md-7">
                <div  id="fixed_factors_panel" style="border-width:1px;border-style:dotted;height:100px;" class="panel panel-default">
	           <div class="panel-header">Fixed factors</div>
	           <div id="fixed_factors" class="panel-body"></div>
           
                </div>
	        <div id="fixed_factors_collection_panel" class="panel panel-default" style="border-style:dotted;border-width:1px;margin-top:20px;height:auto;z-index:1" >
	           <div class="panel-header">
	             Fixed factors with interaction
	           <button  id="add_interaction_factor_button">add new interaction</button>
	            <div id="fixed_factors_collection" class="panel-body">
	            </div>
	        </div>
 
                <div id="random_factors_panel" style="border-style:dotted;border-width:1px;margin-top:20px;height:100px;">
          	<div class="panel-header">Random factors</div>
	           <div id="random_factors" class="panel-body">          
                   </div>
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
                html += "<div style=\"z-index:4;border-style:solid;border-radius:8px;width:200px;height:100;border-color:blue;margin:4px;text-align:left\" id=\"factor_"+n+"\" class=\"container\">"+r.factors[n]+"</div>";
             }
             $('#factors').html(html);

	     for (var n=0; n<r.factors.length; n++) { 
	       $('#factor_'+n).draggable({ helper:"clone",revert:"invalid"} );
             }

             $('#tempfile').html(r.tempfile);
           }
	   $('#fixed_factors').droppable( {drop: function( event, ui ) {
					       $( this )
					       .addClass( "ui-state-highlight" )
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
					       .addClass( "ui-state-highlight" )
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
	
       function increment_divnr() {
	   divnr++;
       }

       function get_divnr() {
	   return divnr;
       }

	var previous_div = get_divnr();
	increment_divnr();

	var div_name = "interaction_"+get_divnr();

	var div = '<div id="'+div_name+'" style="border-style:dotted;border-width:2px;height:100px;margin:20px"></div>';

	$('#fixed_factors_collection').append(div);


	$('#'+div_name).droppable( {
	    drop: function( event, ui ) {
		$( this )
		    .addClass( "ui-state-highlight" )
		    .find( "p" )
		    .html( "Dropped!" );
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

   }
    
   function isCloned(e) { 
     if (e.text().includes('X')) { 
   	return true;
     }
  
     return false;
   }

   function setClonedTagProperties(e) { 
     e.id = e.html()+'C';
     e.html('<span id="'+e.id+'_remove" onclick="this.parentNode.parentNode.removeChild(this.parentNode); return false;">X</a></span> '+e.html());
     $('#'+e.id+'_remove').click( function(e) { alert('removing'+e.id); $('#'+e.id).remove(); });
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
           
  //alert("embedding"+ JSON.stringify(v));
           vegaEmbed("#trait_histogram", v);
           //alert("done");
         },
       
       
       error: function(e) { alert('error!'); }
     });
   });

   $('#run_mixed_model_button').click( function() { 
      var dependent_variable = $('#dependent_variable_select').val();
      var fixed_factors = $('#fixed_factors_select').val();
      var random_factors = $('#random_factors_select').val();
      var fixed_factors_interaction = $('#fixed_factors_interaction').val();
      var random_factors_random_slope = $('#random_factor_random_slope').val();
      var tempfile = $('#tempfile').html();

      // alert('Dependent variable: '+ dependent_variable +' Fixed Factors: '+ fixed_factors +' Random Factors: '+ random_factors +' Tempfile: '+tempfile);
      // alert(JSON.stringify(fixed_factors));
      $.ajax( {
        url: '/ajax/mixedmodels/run',
        data: { 
          'dependent_variable': dependent_variable, 
          'fixed_factors': fixed_factors.join(","), 
          'fixed_factors_interaction' : fixed_factors_interaction,
          'random_factors': random_factors.join(","), 
          'random_factors_random_slope': random_factors_random_slope,
          'tempfile' : tempfile 
        },
        success: function(r) { 
          if (r.error) { alert(r.error);}
          else{ 
            // alert('success...');
            $('#mixed_models_results_div').html('<pre>' + r.html + '</pre>');
          }
        },
        error: function(r) { 
          alert(r);
        }
      });      
   });


    function extract_model_parameters() {
	alert("extracting model parameters...");
	var fixed_factors = $('#fixed_factors').text();
	fixed_factors = fixed_factors.replace(/X /g, '","');
	fixed_factors = fixed_factors.substr(3);
	fixed_factors = '["'+fixed_factors+'"]';
	alert("FIXED FACTORS: "+fixed_factors);
	var fixed_factors_json = JSON.parse(fixed_factors);
	alert("fixed_factors (again) "+JSON.stringify(fixed_factors_json));
	
	var fixed_factors_interactions = new Array();
	$('#fixed_factors_collection').children().each( function() {
	    var fixed_factors_interaction = $(this).text();
	    fixed_factors_interaction = fixed_factors_interaction.replace(/X /g, ',');
	    alert(fixed_factors_interaction);
	    fixed_factors_interaction = fixed_factors_interaction.substr(1);
	    alert(fixed_factors_interaction);
	    fixed_factors_interaction = fixed_factors_interaction.replace(/,/g, '\',\'');
	    alert(fixed_factors_interaction);
	    fixed_factors_interaction = '\''+fixed_factors_interaction+'\'';
	    alert(fixed_factors_interaction);
	    fixed_factors_interactions.push(fixed_factors_interaction);
	    
	});
	var fixed_factors_interaction = fixed_factors_interactions.join('],[');
	alert(fixed_factors_interaction);
	fixed_factors_interaction = '[['+fixed_factors_interaction+']]';
	alert(fixed_factors_interaction);
	var fixed_factors_interaction_json =   eval(fixed_factors_interaction) ;
	alert(fixed_factors_interaction);

	
        var random_factors = $('#random_factors').text();
        random_factors = random_factors.replace(/X /g, '","');
	random_factors = random_factors.replace(/\s/g, "");
        random_factors = random_factors.substr(3);
	var random_factors_json;
	if (random_factors) {
	    random_factors_json = JSON.parse(random_factors);
	}
        var json =  {
	    'fixed_factors' : fixed_factors_json,
          'fixed_factors_interaction' : fixed_factors_interaction_json,
	    'random_factors' : random_factors_json };
        alert(JSON.stringify(json));
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
		    jQuery('#model_string').html(r.model);
		}
	    }
	});
    }
};



