
jQuery( document ).ready( function() {

    //For Spreadsheet Upload
    jQuery('#upload_spreadsheet_phenotype_submit_verify').click( function() {
        initializeUploadPhenotype(jQuery("#upload_spreadsheet_phenotype_file_input").val(), "Verifying Spreadsheet File and Data", "#upload_spreadsheet_phenotype_file_form", "/ajax/phenotype/upload_verify/spreadsheet", jQuery('#upload_spreadsheet_phenotype_file_format').val());
    });

    jQuery("#upload_spreadsheet_phenotype_file_form").iframePostForm({
        json: true,
        post: function () { },
        timeout: 7200000,
        complete: function (response) {
            hidePhenotypeUploadWorkingModal();
            displayPhenotypeUploadVerifyResponse(response, "spreadsheet");

            jQuery("#upload_spreadsheet_phenotype_submit_store").click( function() {
                initializeUploadPhenotype(jQuery("#upload_spreadsheet_phenotype_file_input").val(), "Storing Spreadsheet File and Data", "#upload_spreadsheet_phenotype_file_form", "/ajax/phenotype/upload_store/spreadsheet");
            });

            jQuery("#upload_spreadsheet_phenotype_file_form").iframePostForm({
                json: true,
                post: function () { },
                timeout: 7200000,
                complete: function (response) {
                    hidePhenotypeUploadWorkingModal();
                    displayPhenotypeUploadStoreResponse(response, "spreadsheet");
                },
            });
        }
    });

    const handlePhenotypeFileFormatChange = function() {
        var val = jQuery('#upload_spreadsheet_phenotype_file_format').val();
        if (val == 'simple') {
            jQuery('#upload_spreadsheet_phenotype_data_level_div').hide();
            jQuery('#upload_phenotype_spreadsheet_info').show();
        } else {
            jQuery('#upload_spreadsheet_phenotype_data_level_div').show();
            jQuery('#upload_phenotype_spreadsheet_info').hide();
        }
    }
    jQuery('#upload_spreadsheet_phenotype_file_format').change(handlePhenotypeFileFormatChange);
    handlePhenotypeFileFormatChange();

    //For Datacollector Upload
    jQuery('#upload_datacollector_phenotype_submit_verify').click( function() {
        initializeUploadPhenotype(jQuery("#upload_datacollector_phenotype_file_input").val(), "Verifying Datacollector File and Phenotype Data", "#upload_datacollector_phenotype_file_form", "/ajax/phenotype/upload_verify/datacollector");
    });

    jQuery("#upload_datacollector_phenotype_file_form").iframePostForm({
        json: true,
        post: function () { },
        timeout: 7200000,
        complete: function (response) {
            hidePhenotypeUploadWorkingModal();
            displayPhenotypeUploadVerifyResponse(response, "datacollector");

            jQuery("#upload_datacollector_phenotype_submit_store").click( function() {
                initializeUploadPhenotype(jQuery("#upload_datacollector_phenotype_file_input").val(), "Storing Datacollector File and Phenotype Data", "#upload_datacollector_phenotype_file_form", "/ajax/phenotype/upload_store/datacollector");
            });

            jQuery("#upload_datacollector_phenotype_file_form").iframePostForm({
                json: true,
                post: function () { },
                timeout: 7200000,
                complete: function (response) {
                    hidePhenotypeUploadWorkingModal();
                    displayPhenotypeUploadStoreResponse(response, "datacollector");
                },
            });
        }
    });

    //For Fieldbook Upload
    jQuery('#upload_fieldbook_phenotype_submit_verify').click( function() {
        initializeUploadPhenotype(jQuery("#upload_fieldbook_phenotype_file_input").val(), "Verifying Fieldbook File and Phenotype Data", "#upload_fieldbook_phenotype_file_form", "/ajax/phenotype/upload_verify/fieldbook");
    });

    jQuery("#upload_fieldbook_phenotype_file_form").iframePostForm({
        json: true,
        post: function () { },
        timeout: 7200000,
        complete: function (response) {
            hidePhenotypeUploadWorkingModal();
            displayPhenotypeUploadVerifyResponse(response, "fieldbook");

            jQuery("#upload_fieldbook_phenotype_submit_store").click( function() {
                initializeUploadPhenotype(jQuery("#upload_fieldbook_phenotype_file_input").val(), "Storing Fieldbook File and Phenotype Data", "#upload_fieldbook_phenotype_file_form", "/ajax/phenotype/upload_store/fieldbook");
            });

            jQuery("#upload_fieldbook_phenotype_file_form").iframePostForm({
                json: true,
                post: function () { },
                timeout: 7200000,
                complete: function (response) {
                    hidePhenotypeUploadWorkingModal();
                    displayPhenotypeUploadStoreResponse(response, "fieldbook");
                },
            });
        }
    });

//	jQuery('#upload_phenotype_spreadsheet_dialog').on('hidden.bs.modal', function () {
//		location.reload();
//	})
//	jQuery('#upload_datacollector_phenotypes_dialog').on('hidden.bs.modal', function () {
//		location.reload();
//	})
//	jQuery('#upload_fieldbook_phenotypes_dialog').on('hidden.bs.modal', function () {
//		location.reload();
//	})

	jQuery('#delete_pheno_file_link').click( function() {
		alert('Deleted successfully.');
        });

});

function initializeUploadPhenotype(uploadFile, message, file_form, url, upload_format) {
    if (uploadFile === '') {
        alert("Please select a file");
    }
    else {
        showPhenotypeUploadWorkingModal(message);
        jQuery(file_form).attr("action", url);
        jQuery(file_form).submit();
    }
}

function showPhenotypeUploadWorkingModal(message) {
    jQuery('#working_msg').html(message);
    jQuery('#working_modal').modal("show");
}

function hidePhenotypeUploadWorkingModal() {
    jQuery('#working_msg').html("");
    jQuery('#working_modal').modal("hide");
}


function displayPhenotypeUploadVerifyResponse(response, upload_type) {
    if (upload_type == "spreadsheet") {
        var submit_verify_button = "#upload_spreadsheet_phenotype_submit_verify";
        var submit_store_button = "#upload_spreadsheet_phenotype_submit_store";
        var upload_phenotype_status = "#upload_phenotype_spreadsheet_verify_status";
    }
    else if (upload_type == "datacollector") {
        var submit_verify_button = "#upload_datacollector_phenotype_submit_verify";
        var submit_store_button = "#upload_datacollector_phenotype_submit_store";
        var upload_phenotype_status = "#upload_phenotype_datacollector_verify_status";
    }
    else if (upload_type == "fieldbook") {
        var submit_verify_button = "#upload_fieldbook_phenotype_submit_verify";
        var submit_store_button = "#upload_fieldbook_phenotype_submit_store";
        var upload_phenotype_status = "#upload_phenotype_fieldbook_verify_status";
    }

    jQuery(submit_verify_button).attr('disabled', true);
    var message_text = "<hr><ul class='list-group'>";
    if (response.success) {
        var arrayLength = response.success.length;
        for (var i = 0; i < arrayLength; i++) {
            message_text += "<li class='list-group-item list-group-item-success'>";
            message_text += "<span class='badge'><span class='glyphicon glyphicon-ok'></span></span>";
            message_text += response.success[i];
            message_text += "</li>";
        }
        jQuery(submit_store_button).attr('disabled', false);
    }
    if (response.error) {
        var errorarrayLength = response.error.length;
        for (var i = 0; i < errorarrayLength; i++) {
            message_text += "<li class='list-group-item list-group-item-danger'>";
            message_text += "<span class='badge'><span class='glyphicon glyphicon-remove'></span></span>";
            message_text += response.error[i];
            message_text += "</li>";
        }
        if (errorarrayLength > 0) {
            jQuery(submit_store_button).attr('disabled', true);
        }
    }
    if (response.warning) {
        var warningarrayLength = response.warning.length;
        if (warningarrayLength > 0) {
            message_text += "<li class='list-group-item list-group-item-warning'>";
            message_text += "<span class='badge'><span class='glyphicon glyphicon-asterisk'></span></span>";
            message_text += "Warnings are shown in yellow. Either fix the file and try again or continue with storing the data.";
            message_text += "<hr>To overwrite previously stored values instead: <input type='checkbox' id='phenotype_upload_overwrite_values' name='phenotype_upload_overwrite_values' />";
            message_text += "<div id='phenotype_upload_remove_values_div' style='display: none'>To remove previously stored values if left blank in your file: <input type='checkbox' id='phenotype_upload_remove_values' name='phenotype_upload_remove_values' /></div>";
            message_text += "<hr><div id='phenotype_upload_details_default'>New values will be uploaded. Any previously stored values will be skipped.</div>";
            message_text += "<div id='phenotype_upload_details_overwrite' style='display: none'>New values will be uploaded. Any previously stored values will be replaced by non-blank values.  Blank values in the upload file will be skipped.</div>";
            message_text += "<div id='phenotype_upload_details_remove' style='display: none'>New values will be uploaded. Any previously stored values will be replaced by non-blank values.  Blank values in the upload file will remove any previously stored values.</div>";
            message_text += "<br>";
            message_text += "</li>";
            for (var i = 0; i < warningarrayLength; i++) {
                message_text += "<li class='list-group-item list-group-item-warning'>";
                message_text += "<span class='badge'><span class='glyphicon glyphicon-asterisk'></span></span>";
                message_text += response.warning[i];
                message_text += "</li>";
            }
        }
    }
    message_text += "</ul>";
    jQuery(upload_phenotype_status).html(message_text);
    jQuery('#phenotype_upload_overwrite_values').off('change').on('change', function() {
        jQuery("#phenotype_upload_remove_values_div").css('display', this.checked ? 'block' : 'none');
        updateDetails();
    });
    jQuery('#phenotype_upload_remove_values').off('change').on('change', updateDetails);
    function updateDetails() {
        const overwrite = jQuery('#phenotype_upload_overwrite_values').is(':checked');
        const remove = jQuery('#phenotype_upload_remove_values').is(':checked');
        jQuery('#phenotype_upload_details_default').css('display', !overwrite && !remove ? 'block' : 'none');
        jQuery('#phenotype_upload_details_overwrite').css('display', overwrite && !remove ? 'block' : 'none');
        jQuery('#phenotype_upload_details_remove').css('display', overwrite && remove ? 'block' : 'none');
    }
}

function displayPhenotypeUploadStoreResponse(response, upload_type) {
    if (upload_type == "spreadsheet") {
        var submit_store_button = "#upload_spreadsheet_phenotype_submit_store";
        var upload_phenotype_status = "#upload_phenotype_spreadsheet_verify_status";
    }
    else if (upload_type == "datacollector") {
        var submit_store_button = "#upload_datacollector_phenotype_submit_store";
        var upload_phenotype_status = "#upload_phenotype_datacollector_verify_status";
    }
    else if (upload_type == "fieldbook") {
        var submit_store_button = "#upload_fieldbook_phenotype_submit_store";
        var upload_phenotype_status = "#upload_phenotype_fieldbook_verify_status";
    }

    jQuery(upload_phenotype_status).empty();
    jQuery(submit_store_button).attr('disabled', true);
    var message_text = "<hr><ul class='list-group'>";
    if (response.success) {
        var arrayLength = response.success.length;
        for (var i = 0; i < arrayLength; i++) {
            message_text += "<li class='list-group-item list-group-item-success'>";
            message_text += "<span class='badge'><span class='glyphicon glyphicon-ok'></span></span>";
            message_text += response.success[i];
            message_text += "</li>";
        }
    }
    if (response.error) {
        var errorarrayLength = response.error.length;
        for (var i = 0; i < errorarrayLength; i++) {
            message_text += "<li class='list-group-item list-group-item-danger'>";
            message_text += "<span class='badge'><span class='glyphicon glyphicon-remove'></span></span>";
            message_text += response.error[i];
            message_text += "</li>";
        }
        if (errorarrayLength == 0) {
            message_text += "<li class='list-group-item list-group-item-success'><hr><h3>Upload Successfull!</h3></li>";
        }
    } else {
        message_text += "<li class='list-group-item list-group-item-success'><hr><h3>Upload Successfull!</h3></li>";
    }
    message_text += "</ul>";
    jQuery(upload_phenotype_status).html(message_text);
}
