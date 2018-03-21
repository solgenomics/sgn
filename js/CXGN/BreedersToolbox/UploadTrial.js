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

    function upload_trial_file() {
        var uploadFile = $("#trial_uploaded_file").val();
        $('#upload_trial_form').attr("action", "/ajax/trial/upload_trial_file");
        if (uploadFile === '') {
	    alert("Please select a file");
	    return;
        }
        $("#upload_trial_form").submit();
    }

    function open_upload_trial_dialog() {
	$('#upload_trial_dialog').modal("show");
	//add a blank line to design method select dropdown that dissappears when dropdown is opened
	$("#trial_upload_design_method").prepend("<option value=''></option>").val('');
	$("#trial_upload_design_method").one('mousedown', function () {
            $("option:first", this).remove();
            $("#trial_design_more_info").show();
	    //trigger design method change events in case the first one is selected after removal of the first blank select item
	    $("#trial_upload_design_method").change();
	});

	//reset previous selections
	$("#trial_upload_design_method").change();
    }

    $('#upload_trial_link').click(function () {
        get_select_box('years', 'trial_upload_year', {'auto_generate': 1 });
        get_select_box('trial_types', 'trial_upload_trial_type', {'empty': 1 });
        open_upload_trial_dialog();
    });

    $('#upload_trial_submit').click(function () {
        upload_trial_file();
    });

    $("#trial_upload_spreadsheet_format_info").click( function () {
	$("#trial_upload_spreadsheet_info_dialog" ).modal("show");
    });

    $('#upload_trial_form').iframePostForm({
	json: true,
	post: function () {
            var uploadedTrialLayoutFile = $("#trial_uploaded_file").val();
	    $('#working_modal').modal("show");
            if (uploadedTrialLayoutFile === '') {
		$('#working_modal').modal("hide");
		alert("No file selected");
            }
	},
    complete: function (response) {
        console.log(response);

        $('#working_modal').modal("hide");
        if (response.error_string) {
            $("#upload_trial_error_display tbody").html('');

            if (response.missing_accessions) {
                var missing_accessions_html = "<div class='well well-sm'><h3>Add the missing accessions to a list</h3><div id='upload_trial_missing_accessions' style='display:none'></div><div id='upload_trial_add_missing_accessions'></div><hr><h4>Go to <a href='/breeders/accessions'>Manage Accessions</a> to add these new accessions. Please create a list of the missing accessions before clicking the link.</h4></div><br/>";
                $("#upload_trial_add_missing_accessions_html").html(missing_accessions_html);

                var missing_accessions_vals = '';
                for(var i=0; i<response.missing_accessions.length; i++) {
                    missing_accessions_vals = missing_accessions_vals + response.missing_accessions[i] + '\n';
                }
                $("#upload_trial_missing_accessions").html(missing_accessions_vals);
                addToListMenu('upload_trial_add_missing_accessions', 'upload_trial_missing_accessions', {
          selectText: true,
          listType: 'accessions'
        });
            }

            $("#upload_trial_error_display tbody").append(response.error_string);
            $('#upload_trial_dialog').modal("hide");
            $('#upload_trial_error_display').modal("show");

		return;
            }
            if (response.error) {
		console.log(response);
		alert(response.error);
		return;
            }
            if (response.success) {
		console.log(response);
		//alert("uploadTrial got success response" + response.success);
		$('#trial_upload_success_dialog_message').modal("show");
		//alert("File uploaded successfully");
            }
	}
    });

});
