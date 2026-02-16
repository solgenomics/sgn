
jQuery( document ).ready( function() {

    function verifyData(formSelector, fileSelector, url, upload_type, div_type) {
        jQuery(`#upload_spreadsheet_${div_type}_submit_store`).attr('disabled', true);
        jQuery(`#upload_${div_type}_spreadsheet_verify_status`).html("");
        if (div_type !== 'treatment') {
            jQuery(`#upload_datacollector_${div_type}_submit_store`).attr('disabled', true);
            jQuery(`#upload_${div_type}_datacollector_verify_status`).html("");
            jQuery(`#upload_fieldbook_${div_type}_submit_store`).attr('disabled', true);
            jQuery(`#upload_${div_type}_fieldbook_verify_status`).html("");
        }

        let file = jQuery(fileSelector).val();
        if ( !file || file === '' ) {
            return alert("Please select a file");
        }

        showPhenotypeUploadWorkingModal("Verifying file and data");
        jQuery.ajax({
            url: url,
            type: 'POST',
            data: new FormData(jQuery(formSelector)[0]),
            processData: false,
            contentType: false,
            timeout: 0,
            success: function(response) {
                hidePhenotypeUploadWorkingModal();
                displayPhenotypeUploadVerifyResponse(response, upload_type, div_type);
            },
            error: function(response) {
                hidePhenotypeUploadWorkingModal();
                alert("An error occurred while trying to verify this file. Please check the formatting and try again");
            }
        });
    }

    function storeData(formSelector, fileSelector, url, upload_type, div_type) {
        let file = jQuery(fileSelector).val();
        if ( !file || file === '' ) {
            return alert("Please select a file");
        }

        showPhenotypeUploadWorkingModal("Storing file and data");
        jQuery.ajax({
            url: url,
            type: 'POST',
            data: new FormData(jQuery(formSelector)[0]),
            processData: false,
            contentType: false,
            timeout: 0,
            success: function(response) {
                hidePhenotypeUploadWorkingModal();
                displayPhenotypeUploadStoreResponse(response, upload_type, div_type);
            },
            error: function(response) {
                hidePhenotypeUploadWorkingModal();
                alert("An error occurred while trying to store this file. Please check the formatting and try again");
            }
        });
    }

    //For Spreadsheet Upload
    jQuery('#upload_spreadsheet_phenotype_submit_verify').click(function() {
        verifyData(
            "#upload_spreadsheet_phenotype_file_form",
            "#upload_spreadsheet_phenotype_file_input",
            "/ajax/phenotype/upload_verify/spreadsheet",
            "spreadsheet",
            "phenotype"
        );
    });

    jQuery("#upload_spreadsheet_phenotype_submit_store").click(function() {
        storeData(
            "#upload_spreadsheet_phenotype_file_form",
            "#upload_spreadsheet_phenotype_file_input",
            "/ajax/phenotype/upload_store/spreadsheet",
            "spreadsheet",
            "phenotype"
        );
    });

    jQuery('#upload_spreadsheet_treatment_submit_verify').click(function() {
        verifyData(
            "#upload_spreadsheet_treatment_file_form",
            "#upload_spreadsheet_treatment_file_input",
            "/ajax/phenotype/upload_verify/spreadsheet/treatment",
            "spreadsheet",
            "treatment"
        );
    });

    jQuery("#upload_spreadsheet_treatment_submit_store").click(function() {
        storeData(
            "#upload_spreadsheet_treatment_file_form",
            "#upload_spreadsheet_treatment_file_input",
            "/ajax/phenotype/upload_store/spreadsheet/treatment",
            "spreadsheet",
            "treatment"
        );
    });

    //For Datacollector Upload
    jQuery('#upload_datacollector_phenotype_submit_verify').click(function() {
        verifyData(
            "#upload_datacollector_phenotype_file_form",
            "#upload_datacollector_phenotype_file_input",
            "/ajax/phenotype/upload_verify/datacollector",
            "datacollector",
            "phenotype"
        );
    });

    jQuery("#upload_datacollector_phenotype_submit_store").click(function() {
        storeData(
            "#upload_datacollector_phenotype_file_form",
            "#upload_datacollector_phenotype_file_input",
            "/ajax/phenotype/upload_store/datacollector",
            "datacollector",
            "phenotype"
        );
    });

    //For Fieldbook Upload
    jQuery('#upload_fieldbook_phenotype_submit_verify').click(function() {
        verifyData(
            "#upload_fieldbook_phenotype_file_form",
            "#upload_fieldbook_phenotype_file_input",
            "/ajax/phenotype/upload_verify/fieldbook",
            "fieldbook",
            "phenotype"
        );
    });

    jQuery("#upload_fieldbook_phenotype_submit_store").click( function() {
        storeData(
            "#upload_fieldbook_phenotype_file_form",
            "#upload_fieldbook_phenotype_file_input",
            "/ajax/phenotype/upload_store/fieldbook",
            "fieldbook",
            "phenotype"
        );
    });

    const handlePhenotypeFileFormatChange = function(div_type) {
        var val = jQuery(`#upload_spreadsheet_${div_type}_file_format`).val();
        if (val == 'simple') {
            jQuery(`#upload_spreadsheet_${div_type}_data_level_div`).hide();
            jQuery(`#upload_${div_type}_spreadsheet_info`).show();
        } else {
            jQuery(`#upload_spreadsheet_${div_type}_data_level_div`).show();
            jQuery(`#upload_${div_type}_spreadsheet_info`).hide();
        }
    }
    jQuery(`#upload_spreadsheet_phenotype_file_format`).change( function () {
        handlePhenotypeFileFormatChange('phenotype')
    });
    jQuery(`#upload_spreadsheet_treatment_file_format`).change( function () {
        handlePhenotypeFileFormatChange('treatment')
    });

    jQuery('#delete_pheno_file_link').click(function() {
        alert('Deleted successfully.');
    });

    jQuery('#phenotype_reset_dialog').click( function() {
        reset_dialog(jQuery('#upload_spreadsheet_phenotype_file_format').val(), 'phenotype');
    });

    jQuery('#treatment_reset_dialog').click( function() {
        reset_dialog(jQuery('#upload_spreadsheet_treatment_file_format').val(), 'treatment');
    });

});

function showPhenotypeUploadWorkingModal(message) {
    jQuery('#working_msg').html(message);
    jQuery('#working_modal').modal("show");
}

function hidePhenotypeUploadWorkingModal() {
    jQuery('#working_msg').html("");
    jQuery('#working_modal').modal("hide");
}


function displayPhenotypeUploadVerifyResponse(response, upload_type, div_type) {
    let submit_store_button, submit_verify_button, upload_phenotype_status;
    if (upload_type == "spreadsheet") {
        submit_verify_button = `#upload_spreadsheet_${div_type}_submit_verify`;
        submit_store_button = `#upload_spreadsheet_${div_type}_submit_store`;
        upload_phenotype_status = `#upload_${div_type}_spreadsheet_verify_status`;
    }
    else if (upload_type == "datacollector") {
        submit_verify_button = `#upload_datacollector_${div_type}_submit_verify`;
        submit_store_button = `#upload_datacollector_${div_type}_submit_store`;
        upload_phenotype_status = `#upload_${div_type}_datacollector_verify_status`;
    }
    else if (upload_type == "fieldbook") {
        submit_verify_button = `#upload_fieldbook_${div_type}_submit_verify`;
        submit_store_button = `#upload_fieldbook_${div_type}_submit_store`;
        upload_phenotype_status = `#upload_${div_type}_fieldbook_verify_status`;
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
            message_text += `<hr>To overwrite previously stored values instead: <input type='checkbox' id='${div_type}_upload_overwrite_values' name='phenotype_upload_overwrite_values' />`;
            message_text += `<div id='${div_type}_upload_remove_values_div' style='display: none'>To remove previously stored values if left blank in your file: <input type='checkbox' id='${div_type}_upload_remove_values' name='${div_type}_upload_remove_values' /></div>`;
            message_text += `<hr><div id='${div_type}_upload_details_default'>New values will be uploaded. Any previously stored values will be skipped.</div>`;
            message_text += `<div id='${div_type}_upload_details_overwrite' style='display: none'>New values will be uploaded. Any previously stored values will be replaced by non-blank values.  Blank values in the upload file will be skipped.</div>`;
            message_text += `<div id='${div_type}_upload_details_remove' style='display: none'>New values will be uploaded. Any previously stored values will be replaced by non-blank values.  Blank values in the upload file will remove any previously stored values.</div>`;
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
    jQuery(`#${div_type}_upload_overwrite_values`).off('change').on('change', function() {
        jQuery(`#${div_type}_upload_remove_values_div`).css('display', this.checked ? 'block' : 'none');
        updateDetails();
    });
    jQuery(`#${div_type}_upload_remove_values`).off('change').on('change', updateDetails);
    function updateDetails() {
        const overwrite = jQuery(`#${div_type}_upload_overwrite_values`).is(':checked');
        const remove = jQuery(`#${div_type}_upload_remove_values`).is(':checked');
        jQuery(`#${div_type}_upload_details_default`).css('display', !overwrite && !remove ? 'block' : 'none');
        jQuery(`#${div_type}_upload_details_overwrite`).css('display', overwrite && !remove ? 'block' : 'none');
        jQuery(`#${div_type}_upload_details_remove`).css('display', overwrite && remove ? 'block' : 'none');
    }
}

function displayPhenotypeUploadStoreResponse(response, upload_type, div_type) {
    let submit_store_button, upload_phenotype_status;
    if (upload_type == "spreadsheet") {
        submit_store_button = `#upload_spreadsheet_${div_type}_submit_store`;
        upload_phenotype_status = `#upload_${div_type}_spreadsheet_verify_status`;
    }
    else if (upload_type == "datacollector") {
        submit_store_button = `#upload_datacollector_${div_type}_submit_store`;
        upload_phenotype_status = `#upload_${div_type}_datacollector_verify_status`;
    }
    else if (upload_type == "fieldbook") {
        submit_store_button = `#upload_fieldbook_${div_type}_submit_store`;
        upload_phenotype_status = `#upload_${div_type}_fieldbook_verify_status`;
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
            message_text += "<li class='list-group-item list-group-item-success'><hr><h3>Upload Successful!</h3></li>";
        }
    } else {
        message_text += "<li class='list-group-item list-group-item-success'><hr><h3>Upload Successful!</h3></li>";
    }
    message_text += "</ul>";
    jQuery(upload_phenotype_status).html(message_text);
}

function reset_dialog(upload_type, div_type) {
    jQuery(`#upload_spreadsheet_${div_type}_file_input`).val("");
    jQuery(`#upload_spreadsheet_${div_type}_submit_verify`).attr('disabled', false);
    jQuery(`#upload_spreadsheet_${div_type}_submit_store`).attr('disabled', true);
    jQuery(`#upload_${div_type}_spreadsheet_verify_status`).html("");

    jQuery(`#upload_datacollector_${div_type}_file_input`).val("");
    jQuery(`#upload_datacollector_${div_type}_submit_verify`).attr('disabled', false);
    jQuery(`#upload_datacollector_${div_type}_submit_store`).attr('disabled', true);
    jQuery(`#upload_${div_type}_datacollector_verify_status`).html("");

    jQuery(`#upload_fieldbook_${div_type}_file_input`).val("");
    jQuery(`#upload_fieldbook_${div_type}_submit_verify`).attr('disabled', false);
    jQuery(`#upload_fieldbook_${div_type}_submit_store`).attr('disabled', true);
    jQuery(`#upload_${div_type}_fieldbook_verify_status`).html("");
}
