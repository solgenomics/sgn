
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

    jQuery("[name='refresh_genotyping_project_jstree_html']").click( function() {
        refreshGenotypingProjectJsTree(1);
    });

    jQuery("[name='refresh_activity_jstree_html']").click(function(){
        refreshActivityJsTree(1);
    });

    jQuery("[name='refresh_transformation_project_jstree_html']").click( function() {
        refreshTransformationProjectJsTree(1);
    });

    jQuery("[name='refresh_propagation_project_jstree_html']").click( function() {
        refreshPropagationProjectJsTree(1);
    });

});

function refreshTrailJsTree(refreshpage) {
    setTimeout(() => {
        jQuery.ajax({
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
    }, 500);
}

function refreshCrossJsTree(refreshpage){
    setTimeout(() => {
        jQuery.ajax( {
            url: '/ajax/breeders/get_trials_with_folders?type=cross',
            beforeSend: function() {
                if (refreshpage == 1){
                    jQuery("#working_modal").modal("show");
                }
            },
            success: function(response) {
                if (refreshpage == 1){
                    jQuery("#working_modal").modal("hide");
                    location.reload();
                }
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred refreshing crosses jstree html');
            }
        });
    }, 500);
}

function refreshGenotypingTrialJsTree(refreshpage){
    setTimeout(() => {
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
    }, 500);
}

function refreshGenotypingProjectJsTree(refreshpage){
    setTimeout(() => {
        jQuery.ajax({
            url: '/ajax/breeders/get_trials_with_folders?type=genotyping_project',
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
                alert('An error occurred refreshing genotype project jstree html');
            }
        });
    }, 500);
}

function refreshActivityJsTree(refreshpage){
    setTimeout(() => {
        jQuery.ajax( {
            url: '/ajax/breeders/get_trials_with_folders?type=activity',
            beforeSend: function() {
                if (refreshpage == 1){
                    jQuery("#working_modal").modal("show");
                }
            },
            success: function(response) {
                if (refreshpage == 1){
                    jQuery("#working_modal").modal("hide");
                    location.reload();
                }
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred refreshing activity jstree html');
            }
        });
    }, 500);
}

function refreshTransformationProjectJsTree(refreshpage){
    setTimeout(() => {
        jQuery.ajax({
            url: '/ajax/breeders/get_trials_with_folders?type=transformation',
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
                alert('An error occurred refreshing transformation project jstree html');
            }
        });
    }, 500);
}

function refreshPropagationProjectJsTree(refreshpage){
    setTimeout(() => {
        jQuery.ajax({
            url: '/ajax/breeders/get_trials_with_folders?type=propagation',
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
                alert('An error occurred refreshing propagation project jstree html');
            }
        });
    }, 500);
}
