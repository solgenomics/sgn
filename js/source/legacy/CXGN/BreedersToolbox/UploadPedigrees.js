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

    $("[name='pedigrees_upload_spreadsheet_format_info']").click( function () {
        $("#pedigrees_upload_spreadsheet_info_dialog" ).modal("show");
    });

    $("[name='upload_pedigrees_dismiss_button']").click( function () {
        $('#pedigree_file_format_option').val("");
        $('#xlsx_pedigrees_uploaded_file').val("");
        $('#text_pedigrees_uploaded_file').val("");        
        location.reload();
    });

    jQuery("#pedigree_file_format_option").change(function(){
        if (jQuery(this).val() == ""){
            jQuery("#xlsx_pedigrees_upload_section").hide();
            jQuery("#text_pedigrees_upload_section").hide();
            jQuery("#submit_pedigrees_upload_button_section").hide();
      }
        if (jQuery(this).val() == "xlsx_pedigrees"){
            jQuery("#xlsx_pedigrees_upload_section").show();
            jQuery("#text_pedigrees_upload_section").hide();
            jQuery("#submit_pedigrees_upload_button_section").show();
        }
        if(jQuery(this).val() == "text_pedigrees"){
            jQuery("#xlsx_pedigrees_upload_section").hide();
            jQuery("#text_pedigrees_upload_section").show();
            jQuery("#submit_pedigrees_upload_button_section").show();

        }
    });


    var archived_file_name;
    var pedigrees_file_type;
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
            archived_file_name = response.archived_file_name;
            pedigrees_file_type = response.pedigrees_file_type;
            if (response.error) {
                html = '<h3>The Following Issues Were Identified</h3><p class="bg-warning">'+response.error+'</p>';
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
                'overwrite_pedigrees':jQuery('#pedigree_upload_overwrite_pedigrees').is(":checked"),
                'pedigrees_file_type':pedigrees_file_type,
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
