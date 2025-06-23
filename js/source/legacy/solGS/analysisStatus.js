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
    		    solGS.log.displayUserAnalyses(res.data);            
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
        'info'      : false,
        'destroy'   : true
        });

        table.rows.add(data).draw();

    },

    keep_recent_jobs: function() {
        var interval = jQuery('#keep_recent_jobs_select').val();
        jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            url: '/solgs/delete/old/analyses/'+interval,
            success: function(response) {
                if (response.error) {
                    alert("Encountered an error on the server: "+response.error);
                    console.log(response);
                } else {
                    alert("Jobs cleared from recent activity."); 
                    window.location.reload();
                }     
    	    },
            error: function(response) {
                console.log(response);
                alert("Error clearing old jobs, check console. " + response);
                window.location.reload();
            }
        });
    }, 

    remove_dead_jobs: function() {
        jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            url: '/solgs/delete/dead/analyses',
            success: function(response) {
                if (response.error) {
                    alert("Encountered an error on the server: "+response.error);
                    console.log(response);
                } else {
                    alert("Jobs cleared from recent activity."); 
                    window.location.reload(); 
                } 
    	    },
            error: function(response) {
                console.log(response);
                alert("Error clearing dead jobs, check console. " + response);
                window.location.reload();
            }
        });
    }
}

jQuery(document).ready(function() {

    solGS.log.getUserAnalyses();

    jQuery('#clear_dead_jobs_button').click(function(){solGS.log.remove_dead_jobs()});
    jQuery('#clear_jobs_cache_button').click(function(){solGS.log.keep_recent_jobs()});
});
