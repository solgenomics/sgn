jQuery(document).ready(function ($) {
  jQuery('#check_pedigree_link').click(function () {
    var list = new CXGN.List();
    jQuery('#check_pedigree_dialog').modal("show");
    jQuery("#list_div_check_pedigree").html(list.listSelect("list_div_check_pedigree", ["accessions"] ));
  });
});

jQuery.ajax({
    type: 'POST',
    url: '/ajax/accession_list/check_pedigree',
    timeout: 36000000,
    dataType: "json",
    data: {
        'accessions': JSON.stringify(accessions),
    },
    beforeSend: function(){
        disable_ui();
    },
    error: function () {
        enable_ui();
        alert('An error occurred in processing. sorry');
    }
});

listen for submit list click
