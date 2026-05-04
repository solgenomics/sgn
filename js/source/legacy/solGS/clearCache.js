jQuery(document).ready(function() {
    var clearCacheArgs = {
        analysis_type: jQuery('#analysis_type').val(),
        data_structure: jQuery('#data_structure').val(),
        trial_id: jQuery('#trial_id').val(),
        dataset_id: jQuery('#dataset_id').val()
    };

    jQuery('[id^="clear_cache_"]').click(function(e) {
        clearCacheArgs.analysis_type = e.target.id.replace('clear_cache_', '');

        jQuery.ajax({
            url: '/solgs/cache/clear',
            type: 'POST',
            data: clearCacheArgs,
            success: function(res) {
                if (res.success) {
                    jQuery('[id^="clear_cache_"]').hide();                
                    location.reload();
                }            
            },
            error: function() {
                alert('Error occurred while clearing cache');
            }
        });
    });
});
