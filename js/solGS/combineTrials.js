/**
* trials search, selections to combine etc...
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

JSAN.use("Prototype");
JSAN.use('jquery.blockUI');


function getPopIds () {

    jQuery('#homepage_trials_list tr').filter(':has(:checkbox:checked)')
        .bind('click',  function() {
    
            var td =  jQuery(this).html();
            //alert(td);
            var selectedTrial = '<tr>' + td + '</tr>';
        
            jQuery("#selected_trials_table tr:last").after(selectedTrial);
       
            jQuery("#selected_trials_table tr").each( function() {
                jQuery(this).find("input[type=checkbox]")
                    .attr('onclick', 'removeSelectedTrial()')
                    .prop('checked', true); 
            });
        });
  
    jQuery("#selected_trials").show();
    jQuery("#combine").show();
    jQuery("#search_again").show();
   
}

function doneSelecting() {
    jQuery("#homepage_trials_list").hide();
    jQuery("#done_selecting").hide();
    
}

function removeSelectedTrial() {
    
    jQuery("#selected_trials_table tr").on("change", function() {    
        
        jQuery(this).remove();
        
        if( jQuery("#selected_trials_table td").doesExist() == false) {
            jQuery("#selected_trials").hide();
            jQuery("#combine").hide();
            jQuery("#search_again").hide();
            searchAgain();
        }
    });

}

function searchAgain () {
    searchTrials();
    jQuery("#done_selecting").show();
}

Array.prototype.unique =
    function() {
    var a = [];
    var l = this.length;
    for(var i=0; i<l; i++) {
      for(var j=i+1; j<l; j++) {
        // If this[i] is found later in the array
        if (this[i] === this[j])
          j = ++i;
      }
      a.push(this[i]);
    }
    return a;
  };

