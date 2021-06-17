/**
* functions for displaying solgs related
* analyses jobs in the user profile page
*
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

var solGS = solGS || function solGS () {};

solGS.log = {

    getUserAnalyses: function() {

        jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            url: '/solgs/display/analysis/status/',
            success: function(res) {
                if (res.data[0]) {
    		        solGS.log.displayUserAnalyses(res.data);
                } else {
    		              jQuery('#analyses_status_message')
                            .html( '<p>No analyses found.</p>');
                }
    	    }
        });

    },


    displayUserAnalyses: function(data) {

        jQuery('#analysis_log_div').show();

        var table = jQuery('#analysis_list').DataTable({
        'searching' : false,
        'ordering'  : false,
        'processing': true,
        'paging'    : false,
        'info'      : false
        });

        table.rows.add(data).draw();

    }

}

jQuery(document).ready(function() {

    solGS.log.getUserAnalyses();
});
