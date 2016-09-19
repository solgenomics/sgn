jQuery(document).ready(function() {

  jQuery(document)
  .on('show.bs.collapse', '.panel-collapse', function () {
      var $span = jQuery(this).parents('.panel').find('.panel-heading span.clickable');
      $span.find('i').removeClass('glyphicon-chevron-down').addClass('glyphicon-chevron-up');
  })
  .on('hide.bs.collapse', '.panel-collapse', function () {
      var $span = jQuery(this).parents('.panel').find('.panel-heading span.clickable');
      $span.find('i').removeClass('glyphicon-chevron-up').addClass('glyphicon-chevron-down');
  })

    jQuery('#select_trial_for_selection_index').change( // update wizard panels and categories when data selections change
    	function() {

      jQuery('#selection_index').html("");
	    var data = [ [ jQuery(this).val() ] ];

      jQuery.ajax({   // get traits phenotyped in trial
      url: '/ajax/breeder/search',
      method: 'POST',
    	data: {'categories': [ 'trials', 'traits' ], 'data': data, 'querytypes': 0 },
    	    beforeSend: function(){
    		disable_ui();
                },
                complete : function(){
    		enable_ui();
                },
    	    success: function(response) {
            var list = response.list || [];
            var trait_ids = [];
            for (i = 0; i < list.length; i++) {
              trait_ids.push(list[i][0]);
            }

            var synonyms;
            jQuery.ajax({   // get trait synonyms
              url: '/ajax/cvterm/get_synonyms',
              async: false,
              method: 'POST',
          	  data: {'trait_ids': trait_ids },
              success: function(response) {
                synonyms = response.synonyms;
                var trait_html;
                for (i = 0; i < list.length; i++) {
                  var trait_id = list[i][0];
                  var trait_name = list[i][1];
                  var parts = trait_name.split("|");
                  var CO_id = parts[1];
                  var synonym = synonyms[trait_id];
                  synonym_fixed = synonym.replace(/"/g,"");
                  var syn_parts = synonym_fixed.split(" ");
                  synonym_fixed = syn_parts[0];
                  trait_html += '<option value="'+trait_id+'" data-synonym="'+synonym_fixed+'" data-CO_id="'+CO_id+'" title="'+parts[0]+'">'+parts[0]+'</a>\n';
                }
                jQuery('#trait_list').html(trait_html);
                jQuery('#trait_list').focus();
              },
              error: function(response) { alert("An error occurred while retrieving synonyms for traits with ids "+trait_ids); }
            });
          },
    error: function(response) { alert("An error occurred while transforming the list "+list_id); }
    });


     jQuery.ajax({   // get accessions phenotyped in trial
       url: '/ajax/breeder/search',
       method: 'POST',
       data: {'categories': [ 'trials', 'accessions' ], 'data': data, 'querytypes': 0 },
       success: function(response) {
         var accessions = response.list || [];
         var accession_html = '<option value="" title="Select a reference accession">Select a reference accession</a>\n';
         for (i = 0; i < accessions.length; i++) {
           accession_html += '<option value="'+accessions[i][0]+'" title="'+accessions[i][1]+'">'+accessions[i][1]+'</a>\n';
         }
         jQuery('#reference_accession_list').html(accession_html);
       },
       error: function(response) { jQuery('#reference_accession_list').html('<option>No accessions retrieved from this trial</a>'); }
     });

 });

    jQuery('#trait_list').change( // add selected trait to trait table
      function() {
        var trait_id = jQuery('option:selected', this).val();
        var weight_id = trait_id+'_weight';
        var trait_name = jQuery('option:selected', this).text();
        var trait_synonym = jQuery('option:selected', this).data("synonym");
        var trait_CO_id = jQuery('option:selected', this).data("co_id");
        var trait_html = "<tr><td><a href='/cvterm/"+trait_id+"/view' data-value='"+trait_id+"'>"+trait_name+"</a></td><td><p id='"+trait_id+"_CO_id'>"+trait_CO_id+"<p></td><td><p id='"+trait_id+"_synonym'>"+trait_synonym+"<p></td><td><input type='text' id='"+weight_id+"' class='form-control weight' placeholder='Must be a number (+ or -), default = 1'></input></td></tr>";
        jQuery('#trait_table').append(trait_html);
        jQuery('option:selected', this).val('');
        jQuery('option:selected', this).text('Select another trait');
        update_formula();
        jQuery('#'+weight_id).focus();
        jQuery('#'+weight_id).change( //
          function() {
          update_formula();
          jQuery('#trait_list').focus();
        });
        jQuery('#calculate_rankings').removeClass('disabled');
      });

      jQuery('#calculate_rankings').click( function() {
        jQuery('#raw_avgs_div').html("");
        jQuery('#weighted_values_div').html("");
        var trial_id = jQuery("#select_trial_for_selection_index option:selected").val();

        var reference_accession_id;
        if (jQuery("#use_reference_accession").is(':checked')) {
          reference_accession_id = jQuery("#reference_accession_list option:selected").val();
        }

        var selected_trait_rows = jQuery('#trait_table').children();
        var trait_ids = [],
            column_names = [],
            weighted_column_names = [],
            weights = [];
        column_names.push( { title: "Accession" } );
        weighted_column_names.push( { title: "Accession" } );
        jQuery(selected_trait_rows).each(function(index, selected_trait_rows){
            var trait_id = jQuery('a', this).data("value");
            trait_ids.push(trait_id);
            var trait_name = jQuery('a', this).text();
            var weight = jQuery('#'+trait_id+'_weight').val() || 1;  // default = 1
            weights.push(weight);
            var parts = trait_name.split("|");
            column_names.push( { title: parts[0] } );
            weighted_column_names.push( { title: weight+" * ("+parts[0]+")" } );
        });
        weighted_column_names.push( { title: "SIN" }, { title: "SIN Rank" } );
        //weighted_column_names.push( { title: "SIN Rank" } );
        var allow_missing = jQuery("#allow_missing").is(':checked');

      jQuery.ajax({   // get raw averaged and weighted phenotypes from trial
        url: '/ajax/breeder/search/avg_phenotypes',
        method: 'POST',
      	data: {'trial_id': trial_id, 'trait_ids': trait_ids, 'weights': weights, 'allow_missing': allow_missing, 'reference_accession' : reference_accession_id },
      	  success: function(response) {
            var raw_avgs = response.raw_avg_values || [];
            var weighted_values = response.weighted_values || [];
            var trial_name = jQuery('#select_trial_for_selection_index option:selected').text();
            build_table(raw_avgs, column_names, trial_name, 'raw_avgs_div');
            build_table(weighted_values, weighted_column_names, trial_name, 'weighted_values_div');
          },
          error: function(response) {
            alert("An error occurred while retrieving average phenotypes");
          }
        });

      });
    });

function build_table(data, column_names, trial_name, target_div) {

  var table_id = target_div.replace("div", "table");
  var table_type = target_div.replace("_div", "");
  var table_html = '<div class="table-responsive" style="margin-top: 10px;"><table id="'+table_id+'" class="table table-hover table-striped table-bordered" width="100%"><caption class="well well-sm" style="caption-side: bottom;margin-top: 10px;"><center> Table description: <i>'+table_type+' for trial '+trial_name+'.</i></center></caption></table></div>'
  jQuery('#'+target_div).html(table_html);

  var penultimate_column = column_names.length - 2;
  jQuery('#'+table_id).DataTable( {
    dom: 'Bfrtip',
    buttons: ['copy', 'excel', 'csv', 'print' ],
    data: data,
    destroy: true,
    paging: true,
    order: [[ 1, 'asc' ]],
    lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]],
    columns: column_names,
    order: [[ penultimate_column, "desc" ]],
  });
}

function update_formula() {
  var selected_trait_rows = jQuery('#trait_table').children();
  var formula = "SIN = ";
  var term_number = 0;
  jQuery(selected_trait_rows).each(function(index, selected_trait_rows){
      var trait_id = jQuery('a', this).data("value");
      var trait_name = jQuery('a', this).text();
      var weight = jQuery('#'+trait_id+'_weight').val() || 1;  // default = 1
      var parts = trait_name.split("|");
      if (weight >= 0 && term_number > 0) {
        formula += " + "+weight+" * ("+parts[0]+") " ;
      } else {
        formula += weight+" * ("+parts[0]+") " ;
      }
      term_number++;
      console.log("termnumber="+term_number);
  });
  console.log("formula="+formula);
  jQuery('#ranking_formula').text(formula);
  return;
}
