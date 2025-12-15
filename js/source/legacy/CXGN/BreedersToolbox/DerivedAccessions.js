

jQuery(document).ready(function(){

    jQuery('#upload_derived_accession_file_link').click(function() {
        jQuery("#upload_derived_accessions_dialog").modal("show");
    });

    jQuery('#derived_accession_upload_spreadsheet_format_info').click(function(){
        jQuery("#derived_accession_upload_spreadsheet_info_dialog").modal("show");
    });

    jQuery("#upload_derived_accessions_submit").click(function(){
        var uploadFile = jQuery("#derived_accessions_file").val();

        jQuery('#upload_derived_accessions_form').attr("action", "/stock/upload_derived_accessions_file");

        if (uploadFile === ''){
            alert("Please select a file");
            return;
        }

        jQuery("#upload_derived_accessions_form").submit();
        jQuery("#upload_derived_accessions_dialog").modal("hide");
    });


    jQuery('#upload_derived_accessions_form').iframePostForm({
        json: false,
        post: function(){
            jQuery("#working_modal").modal("show");
        },
        complete: function (r) {
            var clean_r = r.replace('<pre>', '');
            clean_r = clean_r.replace('</pre>', '');
            var response = JSON.parse(clean_r);
            console.log(response);
            jQuery('#working_modal').modal("hide");
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
                jQuery('#derived_accessions_saved_dialog_message').modal("show");
            }
        }
    });

    jQuery("#dismiss_derived_accessions_saved_dialog").click(function(){
        location.reload();
    });

});
