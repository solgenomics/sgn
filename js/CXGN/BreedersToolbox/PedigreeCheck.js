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
              disable_ui();
            },
            success: function (response) {
                enable_ui();
                if (response.error) {
                    alert(response.error);
                } else {
                    var score = response.conflict_score;
                    jQuery ('check_pedigree_dialog').modal("show");
                    //print score

                }
            },
            error: function () {
              enable_ui();
              alert('An error occurred in processing. sorry');
            }
    });
  });
});
