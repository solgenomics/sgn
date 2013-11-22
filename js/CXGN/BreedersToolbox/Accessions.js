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


    $("#review_fuzzy_matches_dialog").dialog({
	autoOpen: false,	
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 150],
	buttons: {
	    Ok: function() {
	    	alert("reviewed fuzzy matches");
	    },
	}
    });

    function review_verification_results(verifyResponse){

	if (verifyResponse.fuzzy) {
	    alert(verifyResponse.fuzzy[0].name);
	    var fuzzy_html = '';
	    for( var i=0; i < verifyResponse.fuzzy.length; i++) {
		fuzzy_html = fuzzy_html + '<div class="left">'+ verifyResponse.fuzzy[i].name + '</div>';
		fuzzy_html = fuzzy_html + '<div class="right"><select id ="fuzzyselect'+i+'">';
		for( var j=0; j < verifyResponse.fuzzy[i].matches.length; j++){
		    fuzzy_html = fuzzy_html + '<option value="">' + verifyResponse.fuzzy[i].matches[j].name + '</option>';
		}
		fuzzy_html = fuzzy_html + '</select>';
	    }
	    fuzzy_html = fuzzy_html + '</div>';
	    $('#view_fuzzy_matches').html(fuzzy_html);
	    $('#review_fuzzy_matches_dialog').dialog('open');
	} else {

	}

	
	//if (verifyResponse.found) {
	//    alert("found");
	//}
	//if (verifyResponse.absent) {
	//    alert("absent");
	//}
	//alert("done");
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
		    //var text = JSON.stringify(response, null, '\t');
		    //alert(text);
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
	//$( "#fuzzy_check" ).button();
    });

    
});
