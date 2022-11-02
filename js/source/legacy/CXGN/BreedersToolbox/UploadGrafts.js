/*jslint browser: true, devel: true */

/**

=head1 UploadGrafts.js

Dialogs for uploading grafts


=head1 AUTHORS

Lukas Mueller <lam87@cornell.edu>, based on code by
Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    $('#upload_grafts_link').click(function () {
        open_upload_grafts_dialog();
    });

    $("#upload_graft_dialog_submit").click( function () {
        $('#upload_graft_dialog').modal("hide");
        upload_grafts_file();
    });

    $("#grafts_upload_spreadsheet_format_info").click( function () {
        $('#upload_graft_dialog').modal("hide");
        $("#grafts_upload_spreadsheet_info_dialog" ).modal("show");
    });

    var archived_file_name;
    $('#upload_graft_form').iframePostForm({
        json: false,
        post: function () {
            var uploadedGraftsFile = $("#graft_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedGraftsFile === '') {
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
		$('#upload_graft_store').prop("disabled", true);
            }
            else {

                archived_file_name = response.archived_filename_with_path;

		$('#upload_graft_store').prop("disabled", false);
                html = '<h3>There Were No Issues Identified</h3>Please click the "Store" button to save the grafts to the database.';
            }
            $("#upload_graft_validate_display tbody").html(html);
            $("#upload_graft_validate_display").modal('show');
        }
    });

    function upload_grafts_file() {
        var uploadFile = $("#graft_uploaded_file").val();
        $('#upload_graft_form').attr("action", "/ajax/grafts/upload_verify");
        if (uploadFile === '') {
            alert("Please select a file");
            return;
        }
        $("#upload_graft_form").submit();
    }

    function open_upload_grafts_dialog() {
        $('#upload_graft_dialog').modal("show");
    }

    jQuery('#upload_graft_store').click(function(){
	alert('Archive path: '+archived_file_name);
        jQuery.ajax( {
            url: '/ajax/grafts/upload_store',
            data: {
                'archived_file_name':archived_file_name,
                'overwrite_grafts':jQuery('#graft_upload_overwrite_grafts').is(":checked")
            },
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert('An Error Occured: No grafts were saved! Try Fixing Your File For The Issues Identified In the Validation. '+response.error);
                }
                else {
		    alert("RESPONSE: "+JSON.stringify(response));
                    jQuery('#graft_upload_success_dialog_message').modal('show');
		    jQuery('#list_of_uploaded_grafts').val(response.added_grafts);
		    jQuery('#list_of_already_uploaded_grafts').val(response.already_existing_grafts);
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
		jQuery('#list_of_grafts_with_problems').html(response.list_of_grafts_with_problems);
                alert('An error occurred storing the grafts. None were uploaded.');
            }
        });
    });

});
