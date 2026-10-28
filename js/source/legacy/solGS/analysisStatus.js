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

        var displayCopy = Array.isArray(data) ? data.map(function(row) {
            if (!Array.isArray(row)) { return row; }
            var copy = row.slice();
            var knownStatusText = {"Done": (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_status_done", "Done") : "Done"), "Submitted": (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_status_submitted", "Submitted") : "Submitted"), "Failed": (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_status_failed", "Failed") : "Failed"), "Timed Out": (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_status_timed_out", "Timed Out") : "Timed Out"), "In progress...": (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_status_in_progress", "In progress...") : "In progress..."), "N/A": (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_result_na", "N/A") : "N/A"), "NA": (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_result_na_alt", "NA") : "NA")};
            if (["Submitted", "Failed", "Timed Out", "Done"].includes(copy[3])) { copy[3] = knownStatusText[copy[3]]; }
            if (["In progress...", "N/A", "NA"].includes(copy[4])) { copy[4] = knownStatusText[copy[4]]; }
            if (typeof copy[4] === "string") { copy[4] = copy[4].replace(/>\[ View \]<\/a>/, ">[ " + (window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_result_view_link", "View") : "View") + " ]</a>"); }
            return copy;
        }) : data;
        table.rows.add(displayCopy).draw();

    },

    keep_recent_jobs: function() {
        var interval = jQuery('#keep_recent_jobs_select').val();
        jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            url: '/solgs/delete/old/analyses/'+interval,
            success: function(response) {
                if (response.error) {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_log_server_error_prefix", "Encountered an error on the server: ") : "Encountered an error on the server: ")+response.error);
                    console.log(response);
                } else {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_log_cleared", "Jobs cleared from recent activity.") : "Jobs cleared from recent activity."));
                    window.location.reload();
                }     
    	    },
            error: function(response) {
                console.log(response);
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_log_clear_old_error", "Error clearing old jobs, check console. ") : "Error clearing old jobs, check console. ") + response);
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
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_log_server_error_prefix", "Encountered an error on the server: ") : "Encountered an error on the server: ")+response.error);
                    console.log(response);
                } else {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_log_cleared", "Jobs cleared from recent activity.") : "Jobs cleared from recent activity."));
                    window.location.reload(); 
                } 
    	    },
            error: function(response) {
                console.log(response);
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("solgs.browser.job_log_clear_dead_error", "Error clearing dead jobs, check console. ") : "Error clearing dead jobs, check console. ") + response);
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
