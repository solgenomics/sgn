
jQuery(document).ready(function($) {

    jQuery("[name='refresh_jstree_html']").click(function(){
        refreshTrailJsTree(1);
    });

    jQuery("[name='refresh_crosses_jstree_html']").click(function(){
        refreshCrossJsTree(1);
    });

    jQuery("[name='refresh_genotyping_trial_jstree_html']").click( function() {
        refreshGenotypingTrialJsTree(1);
    });

});

function refreshTrailJsTree(refreshpage){
    jQuery.ajax( {
        url: '/ajax/breeders/get_trials_with_folders?type=trial',
        beforeSend: function() {
            jQuery("#working_modal").modal("show");
        },
        success: function(response) {
            jQuery("#working_modal").modal("hide");
            if (refreshpage == 1){
                location.reload();
            }
        },
        error: function(response) {
            jQuery("#working_modal").modal("hide");
            alert('An error occurred refreshing trial jstree html');
        }
    });
}

function refreshCrossJsTree(refreshpage){
    jQuery.ajax( {
        url: '/ajax/breeders/get_trials_with_folders?type=cross',
        beforeSend: function() {
            jQuery("#working_modal").modal("show");
        },
        success: function(response) {
            jQuery("#working_modal").modal("hide");
            if (refreshpage == 1){
                location.reload();
            }
        },
        error: function(response) {
            jQuery("#working_modal").modal("hide");
            alert('An error occurred refreshing crosses jstree html');
        }
    });
}

function refreshGenotypingTrialJsTree(refreshpage){
    jQuery.ajax({
        url: '/ajax/breeders/get_trials_with_folders?type=genotyping_trial',
        beforeSend: function() {
            jQuery("#working_modal").modal("show");
        },
        success: function(response) {
            jQuery("#working_modal").modal("hide");
            if (refreshpage == 1){
                location.reload();
            }
        },
        error: function(response) {
            jQuery("#working_modal").modal("hide");
            alert('An error occurred refreshing genotype trial jstree html');
        }
    });
}
