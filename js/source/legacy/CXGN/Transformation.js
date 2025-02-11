function deleteTransformationID(transformation_stock_id){

    const confirmation = confirm('Are you sure you want to delete this transformation ID? The deletion cannot be undone.');

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
                    alert('Deletion was successful');
                    location.reload();
                }
                if (response.error) {
                    alert(response.error);
                }
            },
            error: function(response) {
                jQuery('#working_modal').modal('hide');
                alert('An error occurred during deletion');
            }
        });
    }
}
