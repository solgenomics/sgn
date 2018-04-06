jQuery(document).ready(function ($) {
  jQuery('#check_pedigree_link').click(function () {
    var list = new CXGN.List();
    jQuery('#check_pedigree_dialog').modal("show");
    jQuery('#list_div_check_pedigree').html(list.listSelect("list_div_check_pedigree", ["accessions"] ));
    });

  jQuery('#check_pedigree_submit').click(function () {
    var accession_list_id = $('#list_div_check_pedigree_list_select').val();
    //verify_accession_list(accession_list_id);
    var accession_list = JSON.stringify(list.getList(accession_list_id));
    jQuery('#add_accessions_dialog').modal("hide");
      jQuery.ajax({
          type: 'POST',
          url: '/ajax/accession_list/pedigree_check',
          timeout: 36000000,
          dataType: "json",
          data: {
              'accession_list': accession_list,
            },
            beforeSend: function(){
              jQuery('#working_modal').modal('show');
              disable_ui();
            },
            success: function (response) {
              console.log(response);
              jQuery('#working_modal').modal('hide');
              enable_ui();
              if (response.error) {
                  alert(response.error);
              }
              else {
                  var return_array = new Array();
                  var missing = response.missing;
                  var calculated = response.calculated;
                  var output_string = "";
                  for (var accession in calculated){
                    var value = calculated[accession];
                    if (value > 3){
                       output_string = "<p>" + accession + " has a pedigree conflict of " + value  + "%. A pedigree error is likely to have occurred.<\p>";
                    }
                    else{
                       output_string = "<p>" + accession + " has a pedigree conflict of " + value + "%. A pedigree error is unlikely to have occurred.<\p>";
                    }
                    return_array.push(output_string);
                    var breaks_return_array = return_array.join("<br>");
                    console.log(breaks_return_array);
                  }
                  for (var accession in missing){
                    return_array.push(missing[accession]);
                  }
                  jQuery("#pedigree_check_body").html(breaks_return_array);
                  jQuery('#pedigree_check_results').modal('show');
              }
            },
            error: function () {
              enable_ui();
              alert('An error occurred in processing. sorry');
            }
    });
  });
});
