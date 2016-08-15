jQuery(document).ready(function() {

    jQuery('#select_trial_for_selection_index').change( // update wizard panels and categories when data selections change
    	function() {

      var trial_name = jQuery("option:selected", this).text();
      this.options[this.selectedIndex].innerHTML
	    var data = [ [ jQuery(this).val() ] ];
      console.log("data="+data);
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
            console.log("traits="+JSON.stringify(response.list));
            var list = response.list || [];
            data_html = format_options_list(list);
            jQuery('#trait_list1').html(data_html);
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
          for (i = 0; i < accessions_list.length; i++) {
              accessions_list[i][0] = '<a href="/stock/'+accessions_list[i][0]+'/view">'+accessions_list[i][1]+'</a>';
              accessions_list[i][1] = [];
          }
          //console.log("accessions_list="+accessions_list);
          jQuery('#table_panel').html('');
          var table_html = '<ul class="nav nav-tabs"><li class="active"><a data-toggle="tab" href="#summary">Selection Index</a></li><li><a data-toggle="tab" href="#raw">Ranking</a></li></ul><div class="tab-content">';
          table_html += '<div id="selection_index" class="tab-pane fade in active"><div class="table-responsive" style="margin-top: 10px;"><table id="selection_table" class="table table-hover table-striped table-bordered" width="100%"><caption class="well well-sm" style="caption-side: bottom;margin-top: 10px;"><center> Table description: <i>Selection index for trial '+trial_name+'.</i></center></caption></table></div></div>';
          table_html += '<div id="ranking" class="tab-pane fade"><div class="table-responsive" style="margin-top: 10px;"><table id="ranking_table" class="table table-hover table-striped table-bordered" width="100%"><thead><tr>';
          jQuery('#table_panel').html(table_html);

          var summary_table = jQuery('#selection_table').DataTable( {
            dom: 'Bfrtip',
            buttons: ['copy', 'excel', 'csv', 'print' ],
            data: accessions_list,
            destroy: true,
            paging: true,
            lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]],
            columns: [
              { title: "Accession" },
              { title: "Trait 1" }
            ]
          });
        },
  error: function(response) { alert("An error occurred while transforming the list "+list_id); }
  });


    });
      });




function display_tables(summary_data, raw_data, values, metadata, location, start_date, end_date, interval) {
  jQuery('#table_panel').html('');
  var averages = " averages";
  if (interval == 'individual') { averages = " measurements";}
  var table_html = '<ul class="nav nav-tabs"><li class="active"><a data-toggle="tab" href="#summary">Summary</a></li><li><a data-toggle="tab" href="#raw">Raw Data</a></li></ul><div class="tab-content">';
  table_html += '<div id="summary" class="tab-pane fade in active"><div class="table-responsive" style="margin-top: 10px;"><table id="summary_stats" class="table table-hover table-striped table-bordered" width="100%"><caption class="well well-sm" style="caption-side: bottom;margin-top: 10px;"><center> Table description: <i>Summary of '+interval+averages+' from '+location+' between '+start_date+' and '+end_date+'.</i></center></caption></table></div></div>';
  table_html += '<div id="raw" class="tab-pane fade"><div class="table-responsive" style="margin-top: 10px;"><table id="raw_data" class="table table-hover table-striped table-bordered" width="100%"><thead><tr>';
  table_html += '<th>Time</th>';
  var types= [];
  for (var type in values) {
    if (values.hasOwnProperty(type)) {
      types.push(type);
    }
  }
  types.sort ();
  for (i in types) {
    var type = types[i]
    var type_hash = metadata[type];
    table_html += '<th>'+type_hash['description']+'</th>';
  }
  table_html += '</tr></thead><caption class="well well-sm" style="caption-side: bottom;margin-top: 10px;"><center> Table description: <i>All '+interval+averages+' from '+location+' between '+start_date+' and '+end_date+'.</i></center></caption></table></div></div></div>';
  jQuery('#table_panel').html(table_html);
  var summary_table = jQuery('#summary_stats').DataTable( {
    dom: 'Bfrtip',
    buttons: ['copy', 'excel', 'csv', 'print' ],
    data: summary_data,
    destroy: true,
    paging: true,
    lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]],
    columns: [
      { title: "Data Type" },
      { title: "Unit" },
      { title: "Minimum" },
      { title: "Maximum" },
      { title: "Average" },
      { title: "Std Deviation" },
      { title: "Total Sum" },
      { title: "Location" },
      { title: "Start Date" },
      { title: "End Date" },
      { title: "Measurement Interval" }
    ],
    columnDefs: [
      { visible: false, targets: [7,8,9,10] }
    ]
  });
  var full_table = jQuery('#raw_data').DataTable( {
    dom: 'Bfrtip',
    buttons: ['copy', 'excel', 'csv', 'print' ],
    data: raw_data,
    destroy: true,
    paging: true,
    lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "All"]]
  });
}
