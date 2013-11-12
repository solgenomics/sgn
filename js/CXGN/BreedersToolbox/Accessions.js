/**

=head1 Accessions.js

Dialogs for managing accessions


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


window.onload = function initialize() { 
    jQuery(document).ready(function () {

	jQuery( "#add_accessions_dialog" ).dialog({
	    autoOpen: false,
	    modal: true,
	    autoResize:true,
            width: 500,
            position: ['top', 150],
	    buttons: {
		Ok: function() {
		    jQuery( this ).dialog( "close" );
		    location.reload();
		}
	    }
	});

	jQuery('#add_accessions_link').click(function () {
            jQuery('#add_accessions_dialog').dialog("open");
	});

    });
}

