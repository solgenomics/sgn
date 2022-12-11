/*jslint browser: true, devel: true */

/**

=head1 UploadRenameAccessions.js

Dialogs for uploading accessions to be renamed


=head1 AUTHORS

Lukas Mueller <lam87@cornell.edu>, based on code by
Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    $('#upload_rename_accessions_link').click(function () {
        open_upload_rename_accessions_dialog();
    });

    $("#upload_rename_accessions_dialog_submit").click( function () {
        $('#upload_rename_accessions_dialog').modal("hide");
        upload_rename_accessions_file();
    });

    $("#rename_accessions_upload_spreadsheet_format_info_link").click( function () {
        $('#upload_rename_accessions_dialog').modal("hide");
        $("#rename_accessions_upload_spreadsheet_format_info_dialog" ).modal("show");
    });
    
    var archived_filename;
    $('#upload_rename_accessions_form').iframePostForm({
        json: false,
        post: function () {
            var uploadedRenameAccessionsFile = $("#rename_accessions_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedRenameAccessionsFile === '') {
                $('#working_modal').modal("hide");
                alert("No file selected");
            }
        },
        complete: function (r) {
    	    var clean_r = r.replace('<pre>', '');
	    clean_r = clean_r.replace('</pre>', '');
	    console.log(clean_r);
	    var response = JSON.parse(clean_r);
            $('#working_modal').modal("hide");

            var html;

            if (response.error) {
                html = '<h3>The Following Issues Were Identified</h3><p class="bg-warning">'+response.error+'</p>';
		$('#upload_rename_accessions_store').prop("disabled", true);
            }
            else {

                archived_filename = response.archived_filename_with_path;

		$('#upload_rename_accessions_store').prop("disabled", false);
                html = '<h3>There Were No Issues Identified</h3>Please click the "Rename" button to renamee the accessions in the database.';
            }
            $("#upload_rename_accessions_validate_display tbody").html(html);
            $("#upload_rename_accessions_validate_display").modal('show');
        }
    });

    function upload_rename_accessions_file() {
        var uploadFile = $("#rename_accessions_uploaded_file").val();
        $('#upload_rename_accessions_form').attr("action", "/ajax/rename_accessions/upload_verify");
        if (uploadFile === '') {
            alert("Please select a file");
            return;
        }
        $("#upload_rename_accessions_form").submit();
    }

    function open_upload_rename_accessions_dialog() {
        $('#upload_rename_accessions_dialog').modal("show");
    }

    jQuery('#upload_rename_accessions_store').click(function(){

	
        jQuery.ajax( {
            url: '/ajax/rename_accessions/upload_store',
            data: {
                'archived_filename':archived_filename,
		'store_old_name_as_synonym' : jQuery('#store_old_name_as_synonym').val()
            },
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert('An Error Occured: No accessions were renamed! Try Fixing Your File For The Issues Identified In the Validation. '+response.error);
                }
                else {
		    //alert("RESPONSE: "+JSON.stringify(response));
                    jQuery('#rename_accessions_upload_success_dialog_message').modal('show');
		    jQuery('#list_of_uploaded_rename_accessions').val(response.renamed_accessions);
		    //jQuery('#list_of_already_uploaded_rename_accessions').val(response.grafts_already_present);
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
		jQuery('#list_of_rename_accessions_with_problems').html(response.list_of_grafts_with_problems);
                alert('An error occurred storing the accession data. None were renamed.'+response.responseText);
            }
        });
    });

});
