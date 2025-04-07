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

    var pedigree_data;
    $('#upload_pedigrees_form').iframePostForm({
        json: false,
        post: function () {
            var uploadedPedigreesFile = $("#pedigrees_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedPedigreesFile === '') {
                $('#working_modal').modal("hide");
                alert("No file selected");
            }
        },
        complete: function (r) {
//	    alert("RETRIEVED: "+r);
    	    var clean_r = r.replace('<pre>', '');
	    clean_r = clean_r.replace('</pre>', '');
//	    alert("NOW: "+clean_r);
	    console.log(clean_r);
	    var response = JSON.parse(clean_r);
            $('#working_modal').modal("hide");

            var html;
            pedigree_data = response.pedigree_data;
            if (response.error) {
                html = '<h3>The Following Issues Were Identified</h3><p class="bg-warning">'+response.error+'</p>';
                $("#upload_pedigrees_validate_display tbody").html(html);
                $("#upload_pedigrees_validate_display").modal('show');
            } else if (response.error_string) {
                html = '<h3>The Following Issues Were Identified</h3><p class="bg-warning">'+response.error_string+'</p>';
                $("#upload_pedigrees_error_display tbody").html(html);
                $("#upload_pedigrees_error_display").modal('show');
            } else {
                html = '<h3>There Were No Issues Identified</h3>';
                $("#upload_pedigrees_validate_display tbody").html(html);
                $("#upload_pedigrees_validate_display").modal('show');
            }
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
	    type: 'POST',
            data: {
                'pedigree_data':pedigree_data,
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
