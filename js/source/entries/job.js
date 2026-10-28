/**
* functions for displaying submitted job
* information on the user details page
*
* @author Ryan Preble <rsp98@cornell.edu>
*
*/

export function dismiss_job(job_id) {
    if(confirm((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.dismiss_job_warning", "Job dismissal removes record of this submission, but does not delete any resulting analyses or other data. Are you sure you want to proceed?") : "Job dismissal removes record of this submission, but does not delete any resulting analyses or other data. Are you sure you want to proceed?"))) {
        $.ajax({
            url: '/ajax/job/delete/'+job_id,
            success: function(response) {
                if (response.error) {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_dismissing_job", "Error dismissing job.") : "Error dismissing job."));
                    window.location.reload();
                } else {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.job_record_deleted", "Job record deleted.") : "Job record deleted."));
                    window.location.reload();
                }
            },
            error: function(response) {
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_dismissing_job", "Error dismissing job.") : "Error dismissing job."));
                window.location.reload();
            }
        });
    } 
}

export function dismiss_finished_jobs(user_id) {
    if (confirm((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.dismiss_all_finished_and_canceled_jobs_confirm", "Dismiss all finished and canceled jobs?") : "Dismiss all finished and canceled jobs?"))){

        $.ajax({
            url: '/ajax/job/delete_finished/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_dismissing_jobs", "Error dismissing jobs.") : "Error dismissing jobs."));
                    window.location.reload();
                } else {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.jobs_cleared", "Jobs cleared.") : "Jobs cleared."));
                    window.location.reload();
                }
            },
            error: function(response) {
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_dismissing_jobs", "Error dismissing jobs.") : "Error dismissing jobs."));
                window.location.reload();
            }
        });
    }
}

export function cancel_job(job_id) {
    if(confirm((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.cancel_job_confirm", "Are you sure you want to cancel?") : "Are you sure you want to cancel?"))) {
        $.ajax({
            url: '/ajax/job/cancel/'+job_id,
            success: function(response) {
                if (response.error) {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_canceling_job", "Error canceling job.") : "Error canceling job."));
                } else {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.job_canceled", "Job canceled.") : "Job canceled."));
                    window.location.reload();
                }
            },
            error: function(response) {
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_canceling_job", "Error canceling job.") : "Error canceling job."));
            }
        });
    } 
}

export function keep_recent_jobs(user_id) {
    if (confirm((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.dismiss_old_jobs_confirm", "Dismiss old jobs?") : "Dismiss old jobs?"))){
        var interval = jQuery('#keep_recent_jobs_select').val();

        $.ajax({
            url: '/ajax/job/delete_older_than/'+interval+'/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_dismissing_jobs", "Error dismissing jobs.") : "Error dismissing jobs."));
                    window.location.reload();
                } else {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.jobs_cleared", "Jobs cleared.") : "Jobs cleared."));
                    window.location.reload();
                }
            },
            error: function(response) {
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_dismissing_jobs", "Error dismissing jobs.") : "Error dismissing jobs."));
                window.location.reload();
            }
        });
    }
}

export function dismiss_dead_jobs(user_id) {
    if (confirm((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.failed_timed_out_jobs_confirm", "Dismiss failed and timed out jobs?") : "Dismiss failed and timed out jobs?"))) {
        $.ajax({
            url: '/ajax/job/delete_dead_jobs/'+user_id,
            success: function(response) {
                if (response.error) {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_dismissing_jobs", "Error dismissing jobs.") : "Error dismissing jobs."));
                    window.location.reload();
                } else {
                    alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.jobs_cleared", "Jobs cleared.") : "Jobs cleared."));
                    window.location.reload();
                }
            },
            error: function(response) {
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("jobs.interface.error_dismissing_jobs", "Error dismissing jobs.") : "Error dismissing jobs."));
                window.location.reload();
            }
        });
    }
}

// Localize display copies only; keep API rows, status enums and non-display values canonical.
export function job_display_config(config) {
    if (!config || !Array.isArray(config.columns) || !window.SGN || !SGN.i18n || SGN.i18n.locale === 'en') return config;
    var headings = {
        "user": {source: "Submitted By", label: SGN.i18n.p("jobs.display.submitted_by", "Submitted By")},
        "name": {source: "Name", label: SGN.i18n.p("global.search.bulk.name", "Name")},
        "type": {source: "Type", label: SGN.i18n.p("global.search.features.type.f65b938", "Type")},
        "create_timestamp": {source: "Start Time", label: SGN.i18n.p("jobs.display.start_time", "Start Time")},
        "finish_timestamp": {source: "End Time", label: SGN.i18n.p("jobs.display.end_time", "End Time")},
        "status": {source: "Status", label: SGN.i18n.p("global.dataset_publish.status.heading", "Status")},
        "results_page": {source: "Results", label: SGN.i18n.p("global.library_search.results", "Results")},
        "actions": {source: "Actions", label: SGN.i18n.p("global.dataset_cxgn_dataset.table.actions", "Actions")}
    };
    var statuses = {
        "submitted": SGN.i18n.p("jobs.display.status_submitted", "submitted"),
        "finished": SGN.i18n.p("jobs.display.status_finished", "finished"),
        "canceled": SGN.i18n.p("jobs.display.status_canceled", "canceled"),
        "failed": SGN.i18n.p("jobs.display.status_failed", "failed"),
        "timed_out": SGN.i18n.p("jobs.display.status_timed_out", "timed_out")
    };
    var captions = {
        "Dismiss": SGN.i18n.p("jobs.display.dismiss", "Dismiss"),
        "Cancel": SGN.i18n.p("cross.ui.cancel", "Cancel"),
        "View": SGN.i18n.p("global.est.view", "View"),
        "In progress": SGN.i18n.p("jobs.display.in_progress", "In progress")
    };
    if (statuses.submitted === 'submitted') return config;
    function text(value) {
        var node = document.createElement('span');
        node.textContent = value;
        return node.innerHTML;
    }
    function statusDisplay(value, type) {
        return type === 'display' && Object.prototype.hasOwnProperty.call(statuses, value) ? text(statuses[value]) : value;
    }
    function actionDisplay(value, type) {
        if (type !== 'display' || typeof value !== 'string') return value;
        var node = document.createElement('span');
        node.innerHTML = value;
        var changed = false;
        node.querySelectorAll('button[id]').forEach(function (button) {
            var source = /^dismiss_job_\d+$/.test(button.id) ? 'Dismiss' : /^cancel_job_\d+$/.test(button.id) ? 'Cancel' : null;
            if (source && button.childNodes.length === 1 && button.firstChild.nodeType === 3 && button.textContent === source && captions[source] !== source) {
                button.textContent = captions[source];
                changed = true;
            }
        });
        return changed ? node.innerHTML : value;
    }
    function resultDisplay(value, type) {
        if (type !== 'display' || typeof value !== 'string') return value;
        if (value === 'In progress') return captions['In progress'] === value ? value : text(captions['In progress']);
        var node = document.createElement('span');
        node.innerHTML = value;
        if (node.childNodes.length === 1 && node.firstChild.nodeType === 1 && node.firstChild.nodeName === 'A' && node.firstChild.childNodes.length === 1 && node.firstChild.firstChild.nodeType === 3 && node.firstChild.textContent === 'View' && captions.View !== 'View') {
            node.firstChild.textContent = captions.View;
            return node.innerHTML;
        }
        return value;
    }
    return Object.assign({}, config, {
        columns: config.columns.map(function (column) {
            var heading = headings[column.data];
            if (!heading || column.title !== heading.source) return Object.assign({}, column);
            var copy = Object.assign({}, column, {title: text(heading.label)});
            if (!column.render) {
                if (column.data === 'status') copy.render = statusDisplay;
                else if (column.data === 'actions') copy.render = actionDisplay;
                else if (column.data === 'results_page') copy.render = resultDisplay;
            }
            return copy;
        })
    });
}
