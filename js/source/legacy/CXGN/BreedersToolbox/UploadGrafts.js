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

    var archived_filename;
    $('#upload_graft_form').iframePostForm({
        json: false,
        post: function () {
            var uploadedGraftsFile = $("#graft_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedGraftsFile === '') {
                $('#working_modal').modal("hide");
                alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("cross.ui.no_file_selected", "No file selected") : "No file selected"));
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
                html = ("<h3>" + jQuery("<span>").text((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.rename.issues", "The Following Issues Were Identified") : "The Following Issues Were Identified")).html() + "</h3><p class=\"bg-warning\">")+response.error+'</p>';
		$('#upload_graft_store').prop("disabled", true);
            }
            else {

                archived_filename = response.archived_filename_with_path;

		$('#upload_graft_store').prop("disabled", false);
                html = ("<h3>" + jQuery("<span>").text((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.rename.no_issues", "There Were No Issues Identified") : "There Were No Issues Identified")).html() + "</h3>" + jQuery("<span>").text((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("transformation.helper.please_click_the_store_button_to_save_the_grafts_to_the_database", "Please click the \"Store\" button to save the grafts to the database.") : "Please click the \"Store\" button to save the grafts to the database.")).html() + "");
            }
            $("#upload_graft_validate_display tbody").html(html);
            $("#upload_graft_validate_display").modal('show');
        }
    });

    function upload_grafts_file() {
        var uploadFile = $("#graft_uploaded_file").val();
        $('#upload_graft_form').attr("action", "/ajax/grafts/upload_verify");
        if (uploadFile === '') {
            alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("accession.files.required_file", "Please select a file") : "Please select a file"));
            return;
        }
        $("#upload_graft_form").submit();
    }

    function open_upload_grafts_dialog() {
        $('#upload_graft_dialog').modal("show");
    }

    jQuery('#upload_graft_store').click(function(){
	//alert('Archive path: '+archived_filename);
        jQuery.ajax( {
            url: '/ajax/grafts/upload_store',
            data: {
                'archived_filename':archived_filename,
            },
            beforeSend: function(){
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.error) {
                    alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("transformation.helper.an_error_occured_no_grafts_were_saved_try_fixing_your_file_for_the_i", "An Error Occurred: No grafts were saved! Try Fixing Your File For The Issues Identified In the Validation. ") : 'An Error Occurred: No grafts were saved! Try Fixing Your File For The Issues Identified In the Validation. ')+response.error);
                }
                else {
		    //alert("RESPONSE: "+JSON.stringify(response));
                    jQuery('#graft_upload_success_dialog_message').modal('show');
		    jQuery('#list_of_uploaded_grafts').val(response.added_grafts);
		    jQuery('#list_of_already_uploaded_grafts').val(response.grafts_already_present);
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
		jQuery('#list_of_grafts_with_problems').html(response.list_of_grafts_with_problems);
                alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("transformation.helper.an_error_occurred_storing_the_grafts_none_were_uploaded", "An error occurred storing the grafts. None were uploaded.") : 'An error occurred storing the grafts. None were uploaded.')+response.responseText);
            }
        });
    });

});
