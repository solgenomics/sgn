/*jslint browser: true, devel: true */

/**

=head1 GenerateTrialBarcode.js

Dialogs for generating plots and accessions barcode for a trials


=head1 AUTHOR

Alex Ogbonna <aco46@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {
    $('#generate_trial_barcode_link').click(function () {
        $('#generate_trial_barcode_button_dialog').modal("show");
    });

    $('#trial_plot_barcode').click(function () {
        $('#generate_trial_barcode_button_dialog').modal("hide");
        $('#generate_trial_barcode_dialog').modal("show");
    });

    $('#trial_accession_barcode').click(function () {
        $('#generate_trial_barcode_button_dialog').modal("hide");
        $('#generate_trial_barcode_dialog').modal("show");
    });

});
