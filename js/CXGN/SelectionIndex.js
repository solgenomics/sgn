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
      var categories = [ 'trials', 'traits' ];

      jQuery.ajax({   // get traits phenotyped in trial
      url: '/ajax/breeder/search',
      method: 'POST',
    	data: {'categories': categories, 'data': data, 'querytypes': 0 },
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
              },
              error: function(response) { alert("An error occurred while retrieving synonyms for traits with ids "+trait_ids); }
            });
          },
    error: function(response) { alert("An error occurred while transforming the list "+list_id); }
    });
  });

    jQuery('#trait_list').change( // add selected trait to trait table
      function() {
        var trait_id = jQuery('option:selected', this).val();
        var trait_name = jQuery('option:selected', this).text();
        var trait_synonym = jQuery('option:selected', this).data("synonym");
        var trait_CO_id = jQuery('option:selected', this).data("co_id");
        var trait_html = "<tr><td><a href='/cvterm/"+trait_id+"/view' data-value='"+trait_id+"'>"+trait_name+"</a></td><td><p id='"+trait_id+"_CO_id'>"+trait_CO_id+"<p></td><td><p id='"+trait_id+"_synonym'>"+trait_synonym+"<p></td><td><input type='text' id='"+trait_id+"_weight' class='form-control' placeholder='Must be a number (+ or -), default = 1'></input></td></tr>";
        jQuery('#trait_table').append(trait_html);
        jQuery('option:selected', this).val('');
        jQuery('option:selected', this).text('Select another trait');
      });


      jQuery('#submit_trait').click( function() {
        jQuery('#raw_avgs_div').html("");
        jQuery('#weighted_values_div').html("");
        var trial_id = jQuery("#select_trial_for_selection_index option:selected").val();

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
            var weight = jQuery('#'+trait_id+'_weight').val();
            weights.push(weight);
            var parts = trait_name.split("|");
            column_names.push( { title: parts[0] } );
            weighted_column_names.push( { title: weight+" * ("+parts[0]+")" } );
        });
        weighted_column_names.push( { title: "&#931; (weighted values)" } );
        var allow_missing = jQuery("#allow_missing").is(':checked');

      jQuery.ajax({   // get traits phenotyped in trial
        url: '/ajax/breeder/search/avg_phenotypes',
        method: 'POST',
      	data: {'trial_id': trial_id, 'trait_ids': trait_ids, 'weights': weights, 'allow_missing': allow_missing },
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

  var new_table = jQuery('#'+table_id).DataTable( {
    dom: 'Bfrtip',
    buttons: ['copy', 'excel', 'csv', 'print' ],
    data: data,
    destroy: true,
    paging: true,
    lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]],
    columns: column_names
  });
}
