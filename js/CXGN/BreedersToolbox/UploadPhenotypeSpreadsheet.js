
jQuery( document ).ready( function() {
    jQuery('#upload_spreadsheet_phenotype_submit_verify').click( function() {
	var uploadFile = jQuery("#upload_spreadsheet_phenotype_file_input").val();
	if (uploadFile === '') {
	    alert("Please select a file");
	} else {
	    jQuery('#working_msg').html("Verifying Phenotype Spreadsheet and Data");
	    jQuery('#working_modal').modal("show");
	    jQuery('#upload_spreadsheet_phenotype_file_form').attr("action", "/ajax/phenotype/upload_verify/spreadsheet");
            jQuery('#upload_spreadsheet_phenotype_file_form').submit();
	}
    });

    jQuery('#upload_spreadsheet_phenotype_file_form').iframePostForm({
	json: true,
	post: function () { },
	complete: function (response) {
	    jQuery('#working_modal').modal("hide");
	    jQuery("#upload_spreadsheet_phenotype_submit_verify").attr('disabled', true);
	    var message_text = "<hr><ul class='list-group'>";
	    if (response.success) {
		var arrayLength = response.success.length;
		for (var i = 0; i < arrayLength; i++) {
		    message_text += "<li class='list-group-item list-group-item-success'>";
		    message_text += "<span class='badge'><span class='glyphicon glyphicon-ok'></span></span>";
    		    message_text += response.success[i];
		    message_text += "</li>";
    	 	}
		jQuery("#upload_spreadsheet_phenotype_submit_store").attr('disabled', false);
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
		   jQuery("#upload_spreadsheet_phenotype_submit_store").attr('disabled', true);
		}
            }
	    if (response.warning) {
	        var warningarrayLength = response.warning.length;
		if (warningarrayLength > 0) {
		    message_text += "<li class='list-group-item list-group-item-danger'>";
		    message_text += "<span class='badge'><span class='glyphicon glyphicon-asterisk'></span></span>";
    		    message_text += "Warnings are shown in yellow. Either fix the file and try again or continue with storing the data.<hr>'This combination exists in the database' can be disregarded if the values in your file are indeed new.";
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
	    jQuery("#upload_phenotype_spreadsheet_verify_status").html(message_text);

	    
	    jQuery('#upload_spreadsheet_phenotype_submit_store').click( function() {
	        var uploadFile = jQuery("#upload_spreadsheet_phenotype_file_input").val();
		if (uploadFile === '') {
	    	    alert("Please select a file");
		} else {
	    	    jQuery('#working_msg').html("Storing Phenotype Spreadsheet Data");
	    	    jQuery('#working_modal').modal("show");
	    	    jQuery('#upload_spreadsheet_phenotype_file_form').attr("action", "/ajax/phenotype/upload_store/spreadsheet");
            	    jQuery('#upload_spreadsheet_phenotype_file_form').submit();
		}
            });

    	    jQuery('#upload_spreadsheet_phenotype_file_form').iframePostForm({
		json: true,
		post: function () { },
	    	complete: function (response) {
	    	    jQuery('#working_modal').modal("hide");
		    jQuery("#upload_phenotype_spreadsheet_verify_status").empty();
		    jQuery("#upload_spreadsheet_phenotype_submit_store").attr('disabled', true);
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
            	    }
	    	    message_text += "</ul><hr><h3>Upload Successfull!</h3>";
	    	    jQuery("#upload_phenotype_spreadsheet_verify_status").html(message_text);
		},
    	    });
	}
    });
});
