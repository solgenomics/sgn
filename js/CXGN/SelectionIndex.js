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

    jQuery('#select_trial_for_selection_index').change( // update selection index options when trial selection changes
    	function() {

      jQuery('#selection_index').html("");
      jQuery('#trait_table').html("");
      jQuery('#weighted_values_div').html("");
      jQuery('#raw_avgs_div').html("");
      update_formula();

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
                var trait_html = '<option id="select_message" value="" title="Select a trait">Select a trait</a>\n';
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
                if (jQuery('#trait_list_label').length==0) {
                  jQuery('#trait_list_div').html('<label id="trait_list_label" for="trait_list">Trait select: </label>');
                  var trait_select = jQuery('#trait_list').detach();
                  trait_select.appendTo('#trait_list_div');
                  jQuery('#additional_traits').html("");
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
        var trait_html = "<tr id='"+trait_id+"_row'><td><a href='/cvterm/"+trait_id+"/view' data-value='"+trait_id+"'>"+trait_name+"</a></td><td><p id='"+trait_id+"_CO_id'>"+trait_CO_id+"<p></td><td><p id='"+trait_id+"_synonym'>"+trait_synonym+"<p></td><td><input type='text' id='"+weight_id+"' class='form-control weight' placeholder='Must be a number (+ or -), default = 1'></input></td><td align='center'><a title='Remove' id='"+trait_id+"_remove' href='javascript:remove_trait("+trait_id+")'><span class='glyphicon glyphicon-remove'></span></a></td></tr>";
        jQuery('#trait_table').append(trait_html);
        jQuery('#select_message').text('Add another trait');
        jQuery('#select_message').attr('selected',true);
        update_formula();
        jQuery('#'+weight_id).focus();
        jQuery('#'+weight_id).change( //
          function() {
          update_formula();
          jQuery('#trait_list').focus();
        });
        jQuery('#calculate_rankings').removeClass('disabled');
        jQuery('#trait_list_label').remove();
        var trait_select = jQuery('#trait_list').detach();
        trait_select.appendTo('#additional_traits');
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
  var table_html = '<br><br><div class="table-responsive" style="margin-top: 10px;"><table id="'+table_id+'" class="table table-hover table-striped table-bordered" width="100%"><caption class="well well-sm" style="caption-side: bottom;margin-top: 10px;"><center> Table description: <i>'+table_type+' for trial '+trial_name+'.</i></center></caption></table></div>'
  if (table_type == 'weighted_values') { table_html += '<div class="col-sm-12 col-md-12 col-lg-12"><hr><label>Save top ranked accessions to a list: </label><br><br><div class="col-sm-3 col-md-3 col-lg-3" style="display: inline-block"><label>By number:</label>&nbsp;<select class="form-control" id="top_number"></select></div><div class="col-sm-3 col-md-3 col-lg-3" style="display: inline-block"><label>Or percent:</label>&nbsp;<select class="form-control" id="top_percent"></select></div><div class="col-sm-6 col-md-6 col-lg-6"><div style="text-align:right" id="ranking_to_list_menu"></div><div id="top_ranked_names" style="display: none;"></div></div><br><br><br><br><br></div>'; }

  // <input type="text" class="col-sm-6 form-control" id="top_number">  <label class="col-sm-3 control-label">Use #: </label><div class="col-sm-9" ><input type="text" class="form-control" id="top_number"></div><br><label class="col-sm-3 control-label">Use %: </label><div class="col-sm-9" ><input type="text" class="form-control" id="top_percent"></div>
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

  if (table_type == 'weighted_values') {

    var table = $('#weighted_values_table').DataTable();
    var name_links = table.column(0).data();
    jQuery("#top_number").append('<option value="">Select a number</option>');
    jQuery("#top_percent").append('<option value="">Select a percent</option>');

    for (i=1;i<=name_links.length;i++){
      jQuery("#top_number").append('<option value='+i+'>'+i+'</option>');
    }
    for (i=1;i<=100;i++){
      jQuery("#top_percent").append('<option value='+i+'>'+i+'%</option>');
    }

    jQuery('select[id^="top_"]').change( // save top # or % of accession to add to lists
      function() {
      var type = this.id.split("_").pop();
      var number = jQuery('#top_'+type).val();
      var names = [];

      if (type == 'number') {
        jQuery("#top_percent").val(''); // reset other select
        for (var i = 0; i < number; i++) { //extract names from anchor tags
          names.push(name_links[i].match(/<a [^>]+>([^<]+)<\/a>/)[1]+'\n');
        }
        //console.log("retrieved top "+number+" names: "+names);
      }
      else if (type == 'percent') {
        jQuery("#top_number").val(''); // reset other select
        var adjusted_number = Math.round((number / 100 ) * name_links.length);
        for (var i = 0; i < adjusted_number; i++) { //extract names from anchor tags
          names.push(name_links[i].match(/<a [^>]+>([^<]+)<\/a>/)[1]+'\n');
        }
        //console.log("retrieved top "+number+" percent of names: "+names);
      }
      jQuery('#top_ranked_names').html(names);
      addToListMenu('ranking_to_list_menu', 'top_ranked_names', { listType: 'accessions', });
    });

  }
}

function remove_trait(trait_id) {
  //console.log("remove with id "+trait_id+" has been clicked!");
  jQuery('#'+trait_id+'_row').remove();
  update_formula();
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
