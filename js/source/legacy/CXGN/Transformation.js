function deleteTransformationID(transformation_stock_id){

    const confirmation = confirm((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("transformation.helper.are_you_sure_you_want_to_delete_this_transformation_id_the_deletion_", "Are you sure you want to delete this transformation ID? The deletion cannot be undone.") : 'Are you sure you want to delete this transformation ID? The deletion cannot be undone.'));

    if (confirmation) {
        jQuery.ajax({
            url: '/ajax/transformation/delete',
            data: {'transformation_stock_id' : transformation_stock_id},
            method: 'POST',
            destroy: true,
            beforeSend: function(response) {
                jQuery('#working_modal').modal('show');
            },
            success: function(response) {
                jQuery('#working_modal').modal('hide');
                if (response.success == 1) {
                    alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("trial.soil_table.delete_success", "Deletion was successful") : 'Deletion was successful'));
                    location.reload();
                }
                if (response.error) {
                    alert(response.error);
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
                alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("trial.soil_table.delete_error", "An error occurred during deletion") : 'An error occurred during deletion'));
            }
        });
    }
}

function setTransformationControl(transformation_id, control_stock_id, program_name){

    jQuery.ajax({
        url : '/ajax/transformation/set_transformation_control',
        dataType: "json",
        type: 'POST',
        data : {
            'transformation_stock_id': transformation_id,
            'control_stock_id': control_stock_id,
            'program_name': program_name,
        },
        beforeSend: function(response){
            jQuery('#working_modal').modal('show');
        },
        success: function(response) {
            jQuery('#working_modal').modal('hide');
            if (response.success == 1) {
                jQuery('#set_transformation_control_dialog').modal('hide');
                jQuery("#set_transformation_control_saved_dialog_message tbody").html('');
                jQuery("#set_transformation_control_saved_dialog_message tbody").append(jQuery("<span>").text((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("transformation.helper.the_transformation_control_was_stored_successfully", "The transformation control was stored successfully.") : 'The transformation control was stored successfully.')).html());
                jQuery('#set_transformation_control_saved_dialog_message').modal("show");
                return;
            }
            if (response.error) {
                alert(response.error);
            }
        },
        error: function(response){
            jQuery('#working_modal').modal('hide');
            alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("transformation.helper.an_error_occurred_setting_transformation_control", "An error occurred setting transformation control") : 'An error occurred setting transformation control'));
        }
    });

}

function setAsAControl(transformation_id, program_name){
    jQuery.ajax({
        url : '/ajax/transformation/set_as_control',
        dataType: "json",
        type: 'POST',
        data : {
            'transformation_id': transformation_id,
            'is_a_control': 1,
            'program_name': program_name
        },
        beforeSend: function(response){
            jQuery('#working_modal').modal('show');
        },
        success: function(response) {
            jQuery('#working_modal').modal('hide');
            if (response.success == 1) {
                jQuery('#set_as_a_control_dialog').modal('hide');
                jQuery("#set_transformation_control_saved_dialog_message tbody").html('');
                jQuery("#set_transformation_control_saved_dialog_message tbody").append(jQuery("<span>").text((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("transformation.helper.this_transformation_id_was_set_as_a_control_successfully", "This transformation ID was set as a control successfully.") : 'This transformation ID was set as a control successfully.')).html());
                jQuery('#set_transformation_control_saved_dialog_message').modal("show");
                return;
            }
            if (response.error) {
                alert(response.error);
            }
        },
        error: function(response){
            jQuery('#working_modal').modal('hide');
            alert((window.SGN && window.SGN.i18n ? window.SGN.i18n.p("transformation.helper.an_error_occurred_setting_transformation_control", "An error occurred setting transformation control") : 'An error occurred setting transformation control'));
        }
    });

}
