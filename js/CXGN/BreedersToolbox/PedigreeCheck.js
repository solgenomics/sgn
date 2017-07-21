jQuery(document).ready(function ($) {
  jQuery('#check_pedigree_link').click(function () {
    var list = new CXGN.List();
    jQuery('#check_pedigree_dialog').modal("show");
    jQuery("#list_div_check_pedigree").html(list.listSelect("list_div_check_pedigree", ["accessions"] ));
    });

  jQuery('#check_pedigree_submit').click(function () {
    accession_list_id = $('#list_div_check_pedigree_list_select').val();
    verify_accession_list(accession_list_id);
    jQuery('#add_accessions_dialog').modal("hide");
      jQuery.ajax({
          type: 'POST',
          url: '/ajax/accession_list/check_pedigree',
          timeout: 36000000,
          dataType: "json",
          data: {
              'accessions_list_id': accessions_list_id,
            },
            beforeSend: function(){
              disable_ui();
            },
            error: function () {
              enable_ui();
              alert('An error occurred in processing. sorry');
            }
    });
  });
});
success handler
