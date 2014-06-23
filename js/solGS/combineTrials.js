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
     
            jQuery("#done_selecting input").val('Done selecting');
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
    jQuery("#homepage_message").hide();
    
}

function removeSelectedTrial() {
    
    jQuery("#selected_trials_table tr").on("change", function() {    
        
        jQuery(this).remove();
        
        if( jQuery("#selected_trials_table td").doesExist() == false) {
            jQuery("#selected_trials").hide();
            jQuery("#combine").hide();
            jQuery("#search_again").hide();
            jQuery("#done_selecting input").val('Select');            
            
            searchAgain();
           
        }
    });

}

function searchAgain () {
    jQuery('#homepage_trials_list').empty();
    searchTrials();  
    jQuery("#homepage_message").show();
    jQuery("#done_selecting").show();
    jQuery("#done_selecting input").val('Select');
    
   
}


function downloadData() {

    var trialIds = getSelectedTrials();
    trialIds = trialIds.join(",");
   
    var action = "/solgs/retrieve/populations/data";
     
    jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
    jQuery.blockUI({message: 'Please wait..'});
    
    jQuery.ajax({  
        type: 'POST',
        dataType: "json",
        url: action,
        data: {'trials' : trialIds},
        success: function(res) {                         
            if (res.not_matching_pops == null) {
               
                var combinedPopsId = res.combined_pops_id;
               
                if(combinedPopsId) {
                    goToCombinedTrialsPage(combinedPopsId);
                    jQuery.unblockUI();
                }else if (res.redirect_url) {
                    goToSingleTrialPage(res.redirect_url);
                    jQuery.unblockUI();
                } 
                                     
            } else if(res.not_matching_pops )  {
                            
                jQuery.unblockUI();
                alert('populations ' + res.not_matching_pops + 
                      ' were genotyped using different marker sets. ' + 
                      'Please make new selections to combine.' );
        
            } 
        },
        error: function(res) { 
            jQuery.unblockUI();
            alert('An error occured retrieving phenotype' +
                  'and genotype data for trials..');
        }       
    });   
}


function getSelectedTrials () {
    
    var trialIds = [];
    var selectedTrialsExist = jQuery("#selected_trials_table").doesExist();
  
    if (selectedTrialsExist == true) {      
        jQuery("#selected_trials_table tr").each(function () {       
            var trialId = jQuery(this).find("input[type=checkbox]").val();
              
            if (trialId) {
                trialIds.push(trialId);
            }            
        });       
    }

    trialIds = trialIds.sort();

    return trialIds;

}


function goToCombinedTrialsPage(combinedPopsId) {
     
    var action = '/solgs/populations/combined/' + combinedPopsId;
    
    if(combinedPopsId) {      
        window.location.href = action;
    } else {
        
        
    }
   
}
function goToSingleTrialPage(url) {
    
    if (url) {      
        window.location.href = url;
    }    
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

