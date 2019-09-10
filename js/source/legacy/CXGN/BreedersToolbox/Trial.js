/*jslint browser: true, devel: true */

/**

=head1 Trial.js

Display for managing trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {



    $(function() {
	$( "#trials_accordion" )
	    .accordion({
		header: "> div > h3",
		collapsible: true,
		active: false,
		heightStyle: "content"
	    })
	    .sortable({
		axis: "y",
		handle: "h3",
		stop: function( event, ui ) {
		    // IE doesn't register the blur when sorting
		    // so trigger focusout handlers to remove .ui-state-focus
		    ui.item.children( "h3" ).triggerHandler( "focusout" );
		}
	    });
    });
});

