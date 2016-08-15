jQuery(document).ready(function() {

    jQuery('#select_trial_for_selection_index').change( // update wizard panels and categories when data selections change
    	function() {

      var trial_name = jQuery("option:selected", this).text();
      this.options[this.selectedIndex].innerHTML
	    var data = [ [ jQuery(this).val() ] ];
      //console.log("data="+data);
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
            //console.log("traits="+JSON.stringify(response.list));
            var list = response.list || [];
            data_html = format_options_list(list);
            jQuery('#trait_list').html(data_html);
            add_weights("#weight_list");
            //jQuery('#trait_list2').html(data_html);
            //jQuery('#trait_list3').html(data_html);
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
          var accessions_list = response.list || [];
          build_table(accessions_list);
        },
  error: function(response) { alert("An error occurred while transforming the list "+list_id); }
  });


    });

      jQuery('#submit_trait').click( function() {
        var trial_id = jQuery("#select_trial_for_selection_index option:selected").val();
        var trait_id = jQuery("#trait_list").val();

        jQuery.ajax({   // get traits phenotyped in trial
        url: '/ajax/breeder/search/avg_phenotypes',
        method: 'POST',
      	data: {'trial_id': trial_id, 'trait_id': trait_id },
      	    success: function(response) {
              //console.log("traits="+JSON.stringify(response.list));
              var values = response.values || [];
              console.log("Success! Values ="+JSON.stringify(values));
              build_table(values);
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

function build_table(data, trial_name) {
  var columns = [];
  for (i = 0; i < data.length; i++) {
      columns[i] = [];
      columns[i][0] = '<a href="/stock/'+data[i][0]+'/view">'+data[i][1]+'</a>';
      columns[i][1] = data[i][2] || [];
  }
  console.log("columns="+columns);

  //summary_table.destroy();
  jQuery('#selection_table').empty();
  var summary_table = jQuery('#selection_table').DataTable( {
    dom: 'Bfrtip',
    buttons: ['copy', 'excel', 'csv', 'print' ],
    data: columns,
    destroy: true,
    paging: true,
    lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]],
    columns: [
      { title: "Accession" },
      { title: "Trait 1" }
    ]
  });
}
