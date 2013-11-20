/*jslint browser: true, devel: true */
/**

=head1 Accessions.js

Dialogs for managing accessions


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var list = new CXGN.List();

    $( "#add_accessions_dialog" ).dialog({
	autoOpen: false,
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 150],
	buttons: {
	    Ok: function() {
		verify_accession_list();
		//$(this).dialog( "close" );
		//location.reload();
	    }
	}
    });

    $('#add_accessions_link').click(function () {
        $('#add_accessions_dialog').dialog("open");
	$("#list_div").append(list.listSelect("accessions"));
    });

    function verify_accession_list () {
	var accession_list_id = $('#accessions_list_select').val();
	var accession_list = JSON.stringify(list.getList(accession_list_id));
	alert(accession_list);

	$.ajax({
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
    $( "${0:my_dialog_div_id}" ).dialog({
	autoOpen: false,	
	modal: true,
	autoResize:true,
	width: 500,
	position: ['top', 150],
	buttons: {
	    Ok: function() {
		
	    },
	}
    });
    
});
