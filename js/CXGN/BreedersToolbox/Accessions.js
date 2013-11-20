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


    function review_verification_results(verifyResponse){
	if (verifyResponse.found) {
	    alert("found");
	}
	if (verifyResponse.fuzzy) {
	    alert("fuzzy");
	}
	if (verifyResponse.absent) {
	    alert("absent");
	}
	alert("done");
    } 

    function verify_accession_list() {
	var accession_list_id = $('#accessions_list_select').val();
	var accession_list = JSON.stringify(list.getList(accession_list_id));
	alert(accession_list);

	$.ajax({
	    type: 'POST',
	    url: '/ajax/accession_list/verify',
	    async: false,
	    dataType: "json",
	    data: {
                'accession_list': accession_list,
	    },
	    success: function (response) {
                if (response.error) {
		    alert(response.error);
                } else {
		    //alert('success');
		    review_verification_results(response);
                }
	    },
	    error: function () {
                alert('An error occurred in processing. sorry');
	    }
        });
    }

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

    
});
