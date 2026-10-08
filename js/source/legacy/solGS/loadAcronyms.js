/**
* trait acronyms loader
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

var solGS = solGS || function solGS () {};

solGS.acronyms = {

    loadAcronyms: function() {
       var page = document.URL;
       var id = page.match(/breeders\/trial\//)
            ? jQuery('#trial_id').val()
            : jQuery('#training_pop_id').val();

       return jQuery.ajax({
            type    : 'POST',
            dataType: 'json',
            data    : { id: id },
            url     : '/solgs/load/trait/acronyms/',
        });
    },

    displayAcronyms: function(data) {

        if (!data || !data.length) return;

        var table;
        if (jQuery.fn.DataTable.isDataTable('#trait_acronyms_table')) {
            table = jQuery('#trait_acronyms_table').DataTable();
        } else {
            table = jQuery('#trait_acronyms_table').DataTable({
                searching  : false,
                ordering   : false,
                processing : true,
                paging     : false,
                info       : false,
            });
        }

        table.rows.add(data).draw();
    },

    showError: function() {
        jQuery('#trait_acronyms_table').hide();
        jQuery('#acronyms_message')
            .html('Error occurred loading acronyms')
            .show()
            .fadeOut(5000);
    },
};

jQuery(document).ready(function() {
    jQuery('#trait_acronyms_div').show();

    solGS.acronyms.loadAcronyms()
        .done(function(res) {
            solGS.acronyms.displayAcronyms(res.acronyms);
        })
        .fail(function() {
            solGS.acronyms.showError();
        });
});
