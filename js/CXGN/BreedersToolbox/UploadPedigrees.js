/*jslint browser: true, devel: true */

/**

=head1 UploadPedigrees.js

Dialogs for uploading pedigrees


=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>, based on code by
Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {


    $('#upload_pedigrees_link').click(function () {
        open_upload_pedigrees_dialog();
    });

    $("#upload_pedigrees_dialog_submit").click( function () { 
        $('#upload_pedigrees_dialog').modal("hide");
        upload_pedigrees_file();
    });

    $("#pedigrees_upload_spreadsheet_format_info").click( function () {
        $('#upload_pedigrees_dialog').modal("hide");
        $("#pedigrees_upload_spreadsheet_info_dialog" ).modal("show");
    });

    $('#upload_pedigrees_form').iframePostForm({
        json: true,
        post: function () {
            var uploadedPedigreesFile = $("#pedigrees_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedPedigreesFile === '') {
                $('#working_modal').modal("hide");
                alert("No file selected");
            }
        },
        complete: function (response) {
            $('#working_modal').modal("hide");
            if (response.error) {
                $("#upload_pedigrees_error_display tbody").html('');
                $("#upload_pedigrees_error_display tbody").append(response.error);
                $("#upload_pedigrees_error_display").modal('show');
                return;
            }
            if (response.success) {
                $('#pedigrees_upload_success_dialog_message').modal("show");
            }
        }
    });

    function upload_pedigrees_file() {
        var uploadFile = $("#pedigrees_uploaded_file").val();
        $('#upload_pedigrees_form').attr("action", "/ajax/pedigrees/upload");
        if (uploadFile === '') {
            alert("Please select a file");
            return;
        }
        $("#upload_pedigrees_form").submit();
    }

    function open_upload_pedigrees_dialog() {
        $('#upload_pedigrees_dialog').modal("show");
    }

});
