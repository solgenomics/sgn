

jQuery(document).ready(function(){

    jQuery('#upload_derived_accession_file_link').click(function() {
        jQuery("#upload_derived_accessions_dialog").modal("show");
    });

    jQuery('#derived_accession_upload_spreadsheet_format_info').click(function(){
        jQuery("#derived_accession_upload_spreadsheet_info_dialog").modal("show");
    });

    jQuery("#upload_derived_accessions_submit").click(function(){
        upload_derived_accessions_file();
    });

    function upload_derived_accessions_file() {
        var uploadFile = jQuery("#derived_accessions_file").val();
        if (uploadFile === '') {
            alert("Please select a file");
            return;
        }

        jQuery("#working_modal").modal("show");
        jQuery.ajax({
            url: "/stock/upload_derived_accessions_file",
            type: 'POST',
            data: new FormData(jQuery("#upload_derived_accessions_form")[0]),
            processData: false,
            contentType: false,
            success: function(response) {
                jQuery("#working_modal").modal("hide");
            var html;
            if (response.error_string) {
                html = '<h4>The following issues were identified</h4><p class="bg-warning">'+response.error_string+'</p>';
                jQuery("#upload_derived_accessions_error_display tbody").html(html);
                jQuery("#upload_derived_accessions_error_display").modal('show');
            }
            if (response.error) {
                alert(response.error);
                return;
            }
            if (response.success) {
                jQuery("#upload_derived_accessions_dialog").modal("hide");
                jQuery('#derived_accessions_saved_dialog_message').modal("show");
            }
        }
    });

    jQuery("#dismiss_derived_accessions_saved_dialog").click(function(){
        location.reload();
    });

};

});
