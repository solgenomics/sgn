/**

=head1 FieldBook.js

Dialogs for field book tools


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


window.onload = function initialize() { 


    jQuery(document).ready(function () {

	var list = new CXGN.List();


	jQuery("#select_list").append(list.listSelect("select_list"));

	jQuery('#create_new_trait_file_link').click(function () {
            jQuery('#create_trait_file_dialog').dialog("open");
            //alert("something");
	});
	//function create_trait_file_dialog() {
	//  alert("something");
	//}
	jQuery( "#create_trait_file_dialog" ).dialog({
	    autoOpen: false,
	    modal: true,
	    autoResize:true,
            width: 500,
            position: ['top', 150],
	    buttons: {
		Ok: function() {
                    generate_trait_file();
		    jQuery( this ).dialog( "close" );
		    location.reload();
		}
	    }
	});

	function generate_trait_file() {
	    var trait_list_id = jQuery('#select_list_list_select').val();
	    var trait_list = JSON.stringify(list.getList(trait_list_id));
	    var trait_file_name = jQuery('#trait_file_name').val();

	    new jQuery.ajax({
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
                    }
		},
		error: function () {
                    alert('An error occurred. sorry');
		}
            });
	}

	jQuery('#upload_tablet_phenotype_file_link').click(function () {
            jQuery('#upload_fieldbook_phenotypes_dialog').dialog("open");
            //jQuery( this ).dialog( "close" );
	    //location.reload();
	});

	jQuery( "#upload_fieldbook_phenotypes_dialog" ).dialog({
	    autoOpen: false,
	    modal: true,
	    autoResize:true,
            width: 500,
            position: ['top', 150],
	    buttons: {
		Ok: function() {
                    upload_fieldbook_phenotype_file();
		    //jQuery( this ).dialog( "close" );
		    //location.reload();
		}
	    }
	});

	function upload_fieldbook_phenotype_file() {
            var uploadFile = jQuery("#fieldbook_upload_file").val();
            jQuery('#upload_fieldbook_form').attr("action", "/ajax/fieldbook/upload_phenotype_file");
            if (uploadFile === '') {
		alert("Please select a file");
		return;
            }
            jQuery("#upload_fieldbook_form").submit();
	}

	jQuery('#upload_fieldbook_form').iframePostForm({
	    json: true,
	    post: function () {
		var uploadFile = jQuery("#fieldbook_upload_file").val();
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
		}
	    }
	});




    });


}
