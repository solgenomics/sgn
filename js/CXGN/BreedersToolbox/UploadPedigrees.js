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

    var archived_file_name;
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
            console.log(response);
            var html;
            archived_file_name = response.archived_file_name;
            if (response.error) {
                html = '<h3>The Following Issues Were Identified</h3><div class="well">To Overwrite Parents In the Case That An Accession Already Has Male or Female Parents <input type="checkbox" id="pedigree_upload_overwrite_pedigrees" /></div><p class="bg-warning">'+response.error+'</p>';
            }
            else {
                html = '<h3>There Were No Issues Identified</h3>';
            }
            $("#upload_pedigrees_validate_display tbody").html(html);
            $("#upload_pedigrees_validate_display").modal('show');
        }
    });

    function upload_pedigrees_file() {
        var uploadFile = $("#pedigrees_uploaded_file").val();
        $('#upload_pedigrees_form').attr("action", "/ajax/pedigrees/upload_verify");
        if (uploadFile === '') {
            alert("Please select a file");
            return;
        }
        $("#upload_pedigrees_form").submit();
    }

    function open_upload_pedigrees_dialog() {
        $('#upload_pedigrees_dialog').modal("show");
    }

    jQuery('#upload_pedigrees_store').click(function(){
        jQuery.ajax( {
            url: '/ajax/pedigrees/upload_store',
            data: {
                'archived_file_name':archived_file_name,
                'overwrite_pedigrees':jQuery('#pedigree_upload_overwrite_pedigrees').is(":checked")
            },
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert('An Error Occured: No pedigrees were saved! Try Fixing Your File For The Issues Identified In the Validation. '+response.error);
                }
                else {
                    jQuery('#pedigrees_upload_success_dialog_message').modal('show');
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
                alert('An error occurred storing the pedigrees. None were uploaded.');
            }
        });
    });

});
