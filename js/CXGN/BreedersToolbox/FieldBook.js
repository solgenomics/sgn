/*jslint browser: true, devel: true */

/**

=head1 FieldBook.js

Dialogs for field book tools


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    var list = new CXGN.List();

    function generate_trait_file() {
	var trait_list_id = $('#select_list_list_select').val();
	var trait_list = JSON.stringify(list.getList(trait_list_id));

	var trait_file_name = $('#trait_file_name').val();

	if (trait_file_name == '')  { 
	    alert("A trait file name is required.");
	    return;
	}

	$.ajax({
	    type: 'POST',
	    url: '/ajax/fieldbook/traitfile/create',
	    dataType: "json",
	    data: {
                'trait_list': trait_list,
                'trait_file_name': trait_file_name,
	    },
	    success: function (response) {
                if (response.error) {
		    alert(response.error);
                } else {
		    alert('The trait file was saved.');
		    location.reload();
                }
	    },
	    error: function (response) {
                alert('An error occurred generating the trait file.'+response.error);
	    },
        });
    }

    function upload_fieldbook_phenotype_file() {
        var uploadFile = $("#fieldbook_upload_file").val();
        $('#upload_fieldbook_form').attr("action", "/ajax/fieldbook/upload_phenotype_file");
        if (uploadFile === '') {
	    alert("Please select a file");
	    return;
        }
        $("#upload_fieldbook_form").submit();
    }

    //$("#select_list").append(list.listSelect("select_list"));
    var list = new CXGN.List();
    var html = list.listSelect('select_list', [ 'traits' ]);

    $('#select_list_div').html(html);

    $("#create_trait_file_dialog").dialog({
	autoOpen: false,
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 150],
	buttons: {
	    Ok: function() {
                generate_trait_file();
	    },
	    Cancel: function() { 
		$("#create_trait_file_dialog").dialog("close");
	    }
	}
    });

    $('#create_new_trait_file_link').click(function () {
        $('#create_trait_file_dialog').dialog("open");
    });

    $( "#upload_fieldbook_phenotypes_dialog" ).dialog({
	autoOpen: false,
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 150],
	buttons: {
	    Ok: function() {
                upload_fieldbook_phenotype_file();
		//$( this ).dialog( "close" );
		//location.reload();
	    }
	}
    });

    $('#upload_tablet_phenotype_file_link').click(function () {
        $('#upload_fieldbook_phenotypes_dialog').dialog("open");
        //$( this ).dialog( "close" );
	//location.reload();
    });

    $('#upload_fieldbook_form').iframePostForm({
	json: true,
	post: function () {
	    var uploadFile = $("#fieldbook_upload_file").val();
	    if (uploadFile === '') {
		alert("No file selected");
	    }
	},
	complete: function (response) {
	    if (response.error) {
		alert(response.error);
		return;
	    }
	    if (response.success) {
		alert("File uploaded successfully");
		$( this ).dialog( "close" );
		location.reload();
	    }
	}
    });

});
