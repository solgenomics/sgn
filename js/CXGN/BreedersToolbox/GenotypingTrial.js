/*jslint browser: true, devel: true */

/**

=head1 Trial.js

Display for managing genotyping trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {



    $(function() {
	$( "#genotyping_trials_accordion" )
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

  $('#genotyping_trial_dialog').dialog( {
      autoOpen: false,
      autoResize:true,
      width: 600,
      position: ['top', 150],
      title: 'Create a genotyping trial',
      buttons: {
       'OK': function() {
	   alert("ok");
       },
	  'Cancel': function() { $('#genotyping_trial_dialog').dialog("close"); }
     }
  });

    function open_genotyping_trial_dialog () {
	alert ("will create a genotyping trial");
	$('#genotyping_trial_dialog').dialog("open");
    }

    $('#create_genotyping_trial_link').click(function () {
        open_genotyping_trial_dialog();
    });

});

