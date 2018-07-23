jQuery(document).ready(function(){

    jQuery('#crosses_in_trial').DataTable({
        'ajax':'/ajax/breeders/trial/'+ <% $trial_id %> + '/crosses_in_trial',
    });

    jQuery('#cross_properties_trial').DataTable({
        'ajax':'/ajax/breeders/trial/'+ <% $trial_id %> + '/cross_properties_trial',
    });

    jQuery('#cross_progenies_trial').DataTable({
        'ajax':'/ajax/breeders/trial/'+ <% $trial_id %> + '/cross_progenies_trial',
    });

});
