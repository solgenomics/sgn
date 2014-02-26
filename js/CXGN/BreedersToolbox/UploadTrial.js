/*jslint browser: true, devel: true */

/**

=head1 UploadTrial.js

Dialogs for uploading trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    $('#upload_trial_link').click(function () {
	alert("upload dialog happens");
        open_upload_trial_dialog();
    });

});
