/**
* functions for dismissing and canceling submitted jobs, used by the job log
* on the user details page and by the upload factory
*
* @author Ryan Preble <rsp98@cornell.edu>
*
* Each function takes an optional on_done callback, which runs once the request
* has finished (whether or not it succeeded) so the calling page can reload its
* job tables. Nothing runs if the user declines the confirmation.
*
*/

function run_callback(on_done) {
    if (typeof on_done === 'function') {
        on_done();
    }
}

export function dismiss_job(job_id, on_done) {
    if(confirm("Dismissing this job hides it from your job lists. The job record is kept, and no resulting analyses or other data are deleted. Are you sure you want to proceed?")) {
        jQuery.ajax({
            url: '/ajax/job/delete/'+job_id,
            success: function(response) {
                if (response.error) {
                    alert("Error dismissing job.");
                } else {
                    alert("Job dismissed.");
                }
            },
            error: function(response) {
                alert("Error dismissing job.");
            },
            complete: function() {
                run_callback(on_done);
            }
        });
    }
}

export function dismiss_finished_jobs(user_id, on_done) {
    if (confirm("Dismiss all finished, consumed and canceled jobs?")){

        jQuery.ajax({
            url: '/ajax/job/delete_finished/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert("Error dismissing jobs.");
                } else {
                    alert("Jobs dismissed.");
                }
            },
            error: function(response) {
                alert("Error dismissing jobs.");
            },
            complete: function() {
                run_callback(on_done);
            }
        });
    }
}

export function cancel_job(job_id, on_done) {
    if(confirm("Are you sure you want to cancel?")) {
        jQuery.ajax({
            url: '/ajax/job/cancel/'+job_id,
            success: function(response) {
                if (response.error) {
                    alert("Error canceling job.");
                } else {
                    alert("Job canceled.");
                }
            },
            error: function(response) {
                alert("Error canceling job.");
            },
            complete: function() {
                run_callback(on_done);
            }
        });
    }
}

export function keep_recent_jobs(user_id, on_done) {
    if (confirm("Dismiss old jobs?")){
        var interval = jQuery('#keep_recent_jobs_select').val();

        jQuery.ajax({
            url: '/ajax/job/delete_older_than/'+interval+'/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert("Error dismissing jobs.");
                } else {
                    alert("Jobs dismissed.");
                }
            },
            error: function(response) {
                alert("Error dismissing jobs.");
            },
            complete: function() {
                run_callback(on_done);
            }
        });
    }
}

export function dismiss_dead_jobs(user_id, on_done) {
    if (confirm("Dismiss failed and timed out jobs?")) {
        jQuery.ajax({
            url: '/ajax/job/delete_dead_jobs/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert("Error dismissing jobs.");
                } else {
                    alert("Jobs dismissed.");
                }
            },
            error: function(response) {
                alert("Error dismissing jobs.");
            },
            complete: function() {
                run_callback(on_done);
            }
        });
    }
}
