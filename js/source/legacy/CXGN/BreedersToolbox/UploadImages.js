
jQuery( document ).ready( function() {

    jQuery('#upload_images_submit_verify').click( function() {
        initializeUploadImages(
            jQuery("#upload_images_file_input").val(),
            "Verifying Image Data",
            "#upload_images_file_form",
            "/ajax/phenotype/upload_verify/images",
            jQuery('#upload_images_file_format').val(),
            jQuery("#upload_associated_phenotypes_file_input").val(),
        );
    });

    jQuery("#upload_images_file_form").iframePostForm({
        json: true,
        post: function () { },
        timeout: 7200000,
        complete: function (response) {
            hideImageUploadWorkingModal();
            displayImageUploadVerifyResponse(response);

            jQuery("#upload_images_submit_store").click( function() {
                initializeUploadImages(
                    jQuery("#upload_images_file_input").val(),
                    "Storing Image Data",
                    "#upload_images_file_form",
                    "/ajax/phenotype/upload_store/images");
            });

            jQuery("#upload_images_file_form").iframePostForm({
                json: true,
                post: function () { },
                timeout: 7200000,
                complete: function (response) {
                    hideImageUploadWorkingModal();
                    displayImageUploadStoreResponse(response);
                },
            });
        }
    });

});

function initializeUploadImages(zipFile, message, form, urluploadFormat, phenotypeFile) {
    if (uploadFormat == 'images_with_associated_phenotypes' && phenotypeFile === '') {
        alert('Please select a spreadsheet if you are using the Images with Associated Phenotypes format');
        return false;
    }
    else if (zipFile === '') {
        alert("Please select a zipfile");
    }
    else {
        showImageUploadWorkingModal(message);
        jQuery(form).attr("action", url);
        jQuery(form).submit();
    }
}

function showImageUploadWorkingModal(message) {
    jQuery('#working_msg').html(message);
    jQuery('#working_modal').modal("show");
}

function hideImageUploadWorkingModal() {
    jQuery('#working_msg').html("");
    jQuery('#working_modal').modal("hide");
}

function displayImageUploadVerifyResponse(response) {
    jQuery('#upload_images_submit_verify').attr('disabled', true);
    var message_text = "<hr><ul class='list-group'>";
    if (response.success) {
        var arrayLength = response.success.length;
        for (var i = 0; i < arrayLength; i++) {
            message_text += "<li class='list-group-item list-group-item-success'>";
            message_text += "<span class='badge'><span class='glyphicon glyphicon-ok'></span></span>";
            message_text += response.success[i];
            message_text += "</li>";
        }
        jQuery('#upload_images_submit_store').attr('disabled', false);
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
            jQuery('#upload_images_submit_store').attr('disabled', true);
        }
    }
    if (response.warning) {
        var warningarrayLength = response.warning.length;
        if (warningarrayLength > 0) {
            message_text += "<li class='list-group-item list-group-item-warning'>";
            message_text += "<span class='badge'><span class='glyphicon glyphicon-asterisk'></span></span>";
            message_text += "Warnings are shown in yellow. Either fix the file and try again or continue with storing the data.<hr>If you continue, by default any new values will be uploaded and any previously stored values will be skipped.<hr>To overwrite previously stored values instead: <input type='checkbox' id='phenotype_upload_overwrite_values' name='phenotype_upload_overwrite_values' /><br><br>";
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
    jQuery('#upload_images_status').html(message_text);
}

function displayImageUploadStoreResponse(response) {
    jQuery('#upload_images_status').empty();
    jQuery('#upload_images_submit_store').attr('disabled', true);
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
    jQuery('#upload_images_status').html(message_text);
}
