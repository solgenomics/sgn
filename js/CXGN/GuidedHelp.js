
jQuery(document).ready(function(){
    jQuery('#guided_help_begin_button').click(function(){
        jQuery('#guided_help_begin_dialog').modal('show');
    });

    jQuery('#guided_help_seedlot_inventory_button').click(function(){
        jQuery('#guided_help_seedlot_inventory_dialog').modal('show');
    });
    jQuery('#guided_help_upload_phenotypes_button').click(function(){
        jQuery('#guided_help_upload_phenotypes_dialog').modal('show');
    });
    jQuery('#guided_help_genotyping_trial_button').click(function(){
        jQuery('#guided_help_genotyping_trial_dialog').modal('show');
    });
    jQuery('#guided_help_barcode_trial_button').click(function(){
        jQuery('#guided_help_trial_barcoding_dialog').modal('show');
    });
    jQuery('#guided_help_trial_comparison_button').click(function(){
        jQuery('#guided_help_trial_comparison_dialog').modal('show');
    });
});


