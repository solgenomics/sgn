/*jslint browser: true, devel: true */

/**

=head1 UploadTrial.js

Dialogs for uploading trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {


    $("#upload_trial_dialog").dialog({
	autoOpen: false,	
	modal: true,
	autoResize:true,
        width: 500,
        position: ['top', 75],
	buttons: {
            "Cancel": function () {
                $('#upload_trial_dialog').dialog("close");
            },
	    "Add": function () {
		alert("adding trial");
	    },
	}
    });

    function open_upload_trial_dialog() {
	$('#upload_trial_dialog').dialog("open");
    }

    $('#upload_trial_link').click(function () {
	//alert("upload dialog happens");
        open_upload_trial_dialog();
    });

    $("#trial_upload_spreadsheet_format_info").click( function () { 
	$("#trial_upload_spreadsheet_info_dialog" ).dialog("open");
    });

    $("#trial_upload_spreadsheet_info_dialog").dialog( {
	autoOpen: false,
	buttons: { "OK" :  function() { $("#trial_upload_spreadsheet_info_dialog").dialog("close"); },},
	modal: true,
	width: 900,
	autoResize:true,
    });

});
