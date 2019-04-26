
jQuery( document ).ready( function() {

    //For Spreadsheet Upload
    jQuery('#upload_spreadsheet_phenotype_submit_verify').click( function() {
        initializeUploadPhenotype(jQuery("#upload_spreadsheet_phenotype_file_input").val(), "Verifying Spreadsheet File and Data", "#upload_spreadsheet_phenotype_file_form", "/ajax/phenotype/upload_verify/spreadsheet");
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

    jQuery('#upload_spreadsheet_phenotype_file_format').change(function(){
        var val = jQuery(this).val();
        if (val == 'simple' || val == 'nirs'){
            jQuery('#upload_spreadsheet_phenotype_data_level_div').hide();
        } else {
            jQuery('#upload_spreadsheet_phenotype_data_level_div').show();
        }
    });

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

function initializeUploadPhenotype(uploadFile, message, file_form, url) {
    if (uploadFile === '') {
	alert("Please select a file");
    } else {
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
	    message_text += "Warnings are shown in yellow. Either fix the file and try again or continue with storing the data.<hr>Warnings notifying you that values already exist in the database can be disregarded if your data is indeed new.<hr>To overwrite previously stored values: <input type='checkbox' id='phenotype_upload_overwrite_values' name='phenotype_upload_overwrite_values' /><br><br>";
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
