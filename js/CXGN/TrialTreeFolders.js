
jQuery(document).ready(function($) {

    jQuery("[name='refresh_jstree_html']").click( function() {
        jQuery.ajax( {
            url: '/ajax/breeders/get_trials_with_folders',
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                jQuery("#working_modal").modal("hide");
                location.reload();
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred refreshing trial jstree html');
            }
        });
    });

    jQuery("[name='refresh_crosses_jstree_html']").click( function() {
        jQuery.ajax( {
            url: '/ajax/breeders/get_crosses_with_folders',
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                jQuery("#working_modal").modal("hide");
                location.reload();
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred refreshing crosses jstree html');
            }
        });
    });

});
