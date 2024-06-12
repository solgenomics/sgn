/**
* trait acronyms loader
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};

solGS.acronyms = {

    loadAcronyms: function() {
       var id;
       var page = document.URL;

       if (page.match(/breeders\/trial\//)) {
           id = jQuery('#trial_id').val();
       } else {
          id = jQuery('#training_pop_id').val();
       }

       var acros = jQuery.ajax({
            type    : 'POST',
            dataType: 'json',
            data    : {'id': id},
            url     : '/solgs/load/trait/acronyms/',
        });

        return acros;
    },


    displayAcronyms: function(data) {

        var table = jQuery('#trait_acronyms_table').DataTable({
        'searching' : false,
        'ordering'  : false,
        'processing': true,
        'paging'    : false,
        'info'      : false,
        });

        table.rows.add(data).draw();

    }

/////////////
}
////////////


jQuery(document).ready( function() {
    jQuery('#trait_acronyms_div').show();

    solGS.acronyms.loadAcronyms().done( function(res) {
        solGS.acronyms.displayAcronyms(res.acronyms);
    });

    solGS.acronyms.loadAcronyms().fail( function(res) {
         jQuery('#trait_acronyms_table').hide();
        var errorMsg = 'Error occured loading acronyms';
        jQuery('#acronyms_message')
            .html(errorMsg)
            .show()
            .fadeOut(50000);
    });

});
