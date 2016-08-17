jQuery(document).ready(function() {

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
            data_html = format_options_list(list);
            jQuery('#trait_list').html(data_html);
          },
    error: function(response) { alert("An error occurred while transforming the list "+list_id); }
    });


    var categories = [ 'trials', 'accessions' ];
    jQuery.ajax({   // get accessions phenotyped in trial
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
          var accessions = response.list || [];
          var links = [];
          for (i = 0; i < accessions.length; i++) {
            links.push(['<a href="/stock/'+accessions[i][0]+'/view">'+accessions[i][1]+'</a>', '']);
          }
          var column_names = [
            { title: "Accession" },
            { title: "Trait" }
          ];
          var trial_name = jQuery('#select_trial_for_selection_index option:selected').text();
          build_table(links, column_names, trial_name);
        },
  error: function(response) { alert("An error occurred while transforming the list "+list_id); }
  });


    });

    jQuery('#trait_list').change( // add selected trait to trait table
      function() {
        var trait_id = jQuery('option:selected', this).val();
        var trait_name = jQuery('option:selected', this).text();
        var trait_html = "<tr><td><a href='/cvterm/"+trait_id+"/view' data-value='"+trait_id+"'>"+trait_name+"</a></td><td><select class='form-control' id='"+trait_id+"_weight'></select></td></tr>";
        jQuery('#trait_table').append(trait_html);
        add_weights("#"+trait_id+"_weight");
        jQuery('option:selected', this).val('');
        jQuery('option:selected', this).text('Select another trait');
      });


      jQuery('#submit_trait').click( function() {
        jQuery('#selection_index').html("");
        var trial_id = jQuery("#select_trial_for_selection_index option:selected").val();

        var selected_trait_rows = jQuery('#trait_table').children();
        console.log("selected_trait_rows="+JSON.stringify(selected_trait_rows));
        var trait_ids = [];
        var column_names = [];
        column_names.push( { title: "Accession" } );
        jQuery(selected_trait_rows).each(function(index, selected_trait_rows){
            console.log("onetrait_id="+JSON.stringify(jQuery('a', this).data("value")));
            trait_ids.push(jQuery('a', this).data("value"));
            console.log("onetrait_name="+JSON.stringify(jQuery('a', this).text()));
            var trait_name = jQuery('a', this).text();
            var parts = trait_name.split("|");
            column_names.push( { title: parts[0] } );
        });
        var allow_missing = jQuery("#allow_missing").is(':checked');

        jQuery.ajax({   // get traits phenotyped in trial
        url: '/ajax/breeder/search/avg_phenotypes',
        method: 'POST',
      	data: {'trial_id': trial_id, 'trait_ids': trait_ids, 'allow_missing': allow_missing },
      	    success: function(response) {
              var values = response.values || [];
              var trial_name = jQuery('#select_trial_for_selection_index option:selected').text();
              build_table(values, column_names, trial_name);
            },
      error: function(response) { alert("An error occurred while retrieving average phenotypes"); }
      });
  });
});




function add_weights(select_id) {
  var weight_html = format_options(range(1,100));
  jQuery(select_id).html(weight_html);
}

function range(start, count) {
  return Array.apply(0, Array(count))
    .map(function (element, index) {
      return index + start;
  });
}

function build_table(data, column_names, trial_name) {

  var table_html = '<div class="table-responsive" style="margin-top: 10px;"><table id="selection_table" class="table table-hover table-striped table-bordered" width="100%"><caption class="well well-sm" style="caption-side: bottom;margin-top: 10px;"><center> Table description: <i>Selection index for trial '+trial_name+'.</i></center></caption></table></div>'
  jQuery('#selection_index').html(table_html);

  var summary_table = jQuery('#selection_table').DataTable( {
    dom: 'Bfrtip',
    buttons: ['copy', 'excel', 'csv', 'print' ],
    data: data,
    destroy: true,
    paging: true,
    lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]],
    columns: column_names
  });
}
