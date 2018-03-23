
jQuery(document).ready(function($) {

    jQuery("[name='refresh_jstree_html']").click(function(){
        refreshTrailJsTree();
    });

    jQuery("[name='refresh_crosses_jstree_html']").click(function(){
        refreshCrossJsTree();
    });

    jQuery("[name='refresh_genotyping_trial_jstree_html']").click( function() {
        refreshGenotypingTrialJsTree();
    });

});

function refreshTrailJsTree(){
    jQuery.ajax( {
        url: '/ajax/breeders/get_trials_with_folders?type=trial',
        beforeSend: function() {
            jQuery("#working_modal").modal("show");
        },
        success: function(response) {
            jQuery("#working_modal").modal("hide");
            //location.reload();
        },
        error: function(response) {
            jQuery("#working_modal").modal("hide");
            alert('An error occurred refreshing trial jstree html');
        }
    });
}

function refreshCrossJsTree(){
    jQuery.ajax( {
        url: '/ajax/breeders/get_trials_with_folders?type=cross',
        beforeSend: function() {
            jQuery("#working_modal").modal("show");
        },
        success: function(response) {
            jQuery("#working_modal").modal("hide");
            //location.reload();
        },
        error: function(response) {
            jQuery("#working_modal").modal("hide");
            alert('An error occurred refreshing crosses jstree html');
        }
    });
}

function refreshGenotypingTrialJsTree(){
    jQuery.ajax({
        url: '/ajax/breeders/get_trials_with_folders?type=genotyping_trial',
        beforeSend: function() {
            jQuery("#working_modal").modal("show");
        },
        success: function(response) {
            jQuery("#working_modal").modal("hide");
            //location.reload();
        },
        error: function(response) {
            jQuery("#working_modal").modal("hide");
            alert('An error occurred refreshing crosses jstree html');
        }
    });
}
