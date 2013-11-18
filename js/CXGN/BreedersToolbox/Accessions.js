/**

=head1 Accessions.js

Dialogs for managing accessions


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/

jQuery(document).ready(function () {

    var list = new CXGN.List();

    jQuery( "#add_accessions_dialog" ).dialog({
	autoOpen: false,
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 150],
	buttons: {
	    Ok: function() {
		verify_accession_list();
		//jQuery(this).dialog( "close" );
		//location.reload();
	    }
	}
    });

    jQuery('#add_accessions_link').click(function () {
        jQuery('#add_accessions_dialog').dialog("open");
	jQuery("#list_div").append(list.listSelect("accessions"));
    });

    function verify_accession_list () {
	var accession_list_id = jQuery('#accessions_list_select').val();
	var accession_list = JSON.stringify(list.getList(accession_list_id));
	alert(accession_list);

	new jQuery.ajax({
	    type: 'POST',
	    url: '/ajax/accession_list/verify',
	    dataType: "json",
	    data: {
                'accession_list': accession_list,
	    },
	    success: function (response) {
                if (response.error) {
		    alert(response.error);
                } else {
		    alert('success');
                }
	    },
	    error: function () {
                alert('An error occurred in processing. sorry');
	    }
        });
    }

});
