/**
* functions for displaying submitted job
* information on the user details page
*
* @author Ryan Preble <rsp98@cornell.edu>
*
*/

export function dismiss_job(job_id) {
    if(confirm("Job dismissal removes record of this submission, but does not delete any resulting analyses or other data. Are you sure you want to proceed?")) {
        $.ajax({
            url: '/ajax/job/delete/'+job_id,
            success: function(response) {
                if (response.error) {
                    alert("Error dismissing job.");
                    window.location.reload();
                } else {
                    alert("Job record deleted.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Error dismissing job.");
                window.location.reload();
            }
        });
    } 
}

export function cancel_job(job_id) {
    if(confirm("Are you sure you want to cancel?")) {
        $.ajax({
            url: '/ajax/job/cancel/'+job_id,
            success: function(response) {
                if (response.error) {
                    alert("Error canceling job.");
                } else {
                    alert("Job canceled.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Error canceling job.");
            }
        });
    } 
}

export function keep_recent_jobs(user_id) {
    if (confirm("Dismiss old jobs?")){
        var interval = jQuery('#keep_recent_jobs_select').val();

        $.ajax({
            url: '/ajax/job/delete_older_than/'+interval+'/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert("Error dismissing jobs.");
                    window.location.reload();
                } else {
                    alert("Jobs cleared.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Error dismissing jobs.");
                window.location.reload();
            }
        });
    }
}

export function dismiss_dead_jobs(user_id) {
    if (confirm("Dismiss failed and timed out jobs?")) {
        $.ajax({
            url: '/ajax/job/delete_dead_jobs/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert("Error dismissing jobs.");
                    window.location.reload();
                } else {
                    alert("Jobs cleared.");
                    window.location.reload();
                }
            },
            error: function(response) {
                alert("Error dismissing jobs.");
                window.location.reload();
            }
        });
    }
}

