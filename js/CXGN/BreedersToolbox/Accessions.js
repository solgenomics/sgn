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

    
    
    $("#review_absent_dialog").dialog({
	autoOpen: false,	
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 150],
	buttons: {
	    Add: function() {
		alert("Warning: use caution adding accessions.  Slight differences in spelling can cause undesired duplication.  Please send your list of accessions to add to a curator if you are unsure.");
		$(this).dialog( "close" );
	    },
	    Close: function() {
		$(this).dialog( "close" );
	    },
	}
    });

    $("#review_found_matches_dialog").dialog({
	autoOpen: false,	
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 150],
	buttons: {
	    Ok: function() {
		$(this).dialog( "close" );
	    },
	}
    });

    $("#review_fuzzy_matches_dialog").dialog({
	autoOpen: false,	
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 150],
	buttons: {
	    Ok: function() {
		$(this).dialog( "close" );
	    },
	}
    });

    function review_verification_results(verifyResponse){
	var i;
	var j;
	if (verifyResponse.fuzzy) {
	    var fuzzy_html = '';
	    for( i=0; i < verifyResponse.fuzzy.length; i++) {
		fuzzy_html = fuzzy_html + '<div class="left">'+ verifyResponse.fuzzy[i].name + '</div>';
		fuzzy_html = fuzzy_html + '<div class="right"><select id ="fuzzyselect'+i+'">';
		for(j=0; j < verifyResponse.fuzzy[i].matches.length; j++){
		    fuzzy_html = fuzzy_html + '<option value="">' + verifyResponse.fuzzy[i].matches[j].name + '</option>';
		}
		fuzzy_html = fuzzy_html + '</select>';
	    }
	    fuzzy_html = fuzzy_html + '</div>';
	    $('#view_fuzzy_matches').html(fuzzy_html);
	    //$('#review_fuzzy_matches_dialog').dialog('open');
	}

	if (verifyResponse.found) {
	    var found_html = '';
	    for( i=0; i < verifyResponse.found.length; i++){
		found_html = found_html 
		    +'<div class="left">'+verifyResponse.found[i].matched_string
		    +'</div>';
		if (verifyResponse.found[i].matched_string != verifyResponse.found[i].unique_name){
		    found_html = found_html 
		    +'<div class="right">'
		    +verifyResponse.found[i].unique_name
		    +'</div>';
		}
	    }
	    $('#view_found_matches').html(found_html);
	    $('#review_found_matches_dialog').dialog('open');
	}

	if (verifyResponse.absent) {
	    var absent_html = '';
	    for( i=0; i < verifyResponse.absent.length; i++){
		absent_html = absent_html 
		    +'<div class="left">'+verifyResponse.absent[i]
		    +'</div>' 
		    +'<div class="right">'
		    +verifyResponse.absent[i]
		    +'</div>';
	    }
	    $('#view_absent').html(absent_html);
	    $('#review_absent_dialog').dialog('open');
	}

    } 

    function verify_accession_list() {
	var accession_list_id = $('#accessions_list_select').val();
	var accession_list = JSON.stringify(list.getList(accession_list_id));
	var doFuzzySearch = $('#fuzzy_check').val();
	alert(accession_list);

	$.ajax({
	    type: 'POST',
	    url: '/ajax/accession_list/verify',
	    async: false,
	    dataType: "json",
	    data: {
                'accession_list': accession_list,
		'do_fuzzy_search': doFuzzySearch,
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
