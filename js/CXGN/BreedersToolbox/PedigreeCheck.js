var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

$('#check_pedigree_link').click(function () {
    var list = new CXGN.List();
    $('#check_pedigree_dialog').modal("show");
    $("#list_div_check_pedigree").html(list.listSelect("list_div_check_pedigree", ["accessions"] ));
});
