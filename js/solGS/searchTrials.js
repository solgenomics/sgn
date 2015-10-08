/** 
* search trials
*
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/




jQuery(document).ready(function(){ 
 
    var url = window.location.pathname;
    
    if (url.match(/solgs\/search\/trials\/trait\//) != null) {
	var traitId = jQuery("input[name='trait_id']").val();
	url = '/solgs/search/result/populations/' + traitId;
    } else {
	url = '/solgs/search/trials/';
    }

    searchTrials(url);               
});


function searchTrials(url) {
   
    jQuery.ajax({
        type: 'POST',
        dataType: "json",
        url: url,
        success: function(res) { 
 
            var trialsList = listTrials(res.trials);
            var pagination = res.pagination;
            jQuery("#homepage_message").hide();
            jQuery("#homepage_trials_list").html(trialsList + pagination).show();           
        },
        error: function() {               
            jQuery("#homepage_message").html('Error occured fetching the first set of GS trials.').show();
          
        }

    });
    
  
    jQuery("#homepage_trials_list").on('click', "div.paginate_nav a", function(e) { 
        var page = jQuery(this).attr('href');
       
        jQuery("#homepage_trials_list").empty();
    
        jQuery("#homepage_message").html('Searching for more GS trials..').show(); 
 
        if (page) {
            jQuery.ajax({ 
                type: 'POST',
                dataType: "json",
                url: page,
                success: function(res) {                                                                                 
                    var trialsList = listTrials(res.trials);
                    var pagination = res.pagination;
                    jQuery("#homepage_trials_list").empty();
                    jQuery("#homepage_message").hide(); 
                    jQuery("#homepage_trials_list").html(trialsList + pagination).show();
                  
                },               
                error: function() {
                    jQuery("#homepage_message").html('Error occured fetching the next set of GS trials.').show();
                }                    
            });                
        }

        return false;
    });                

}


function listTrials (trials)  {
    
    jQuery(function() { 
        jQuery("#color_tip")
            .css({display: "inline-block", width: "5em"})
            .tooltip();
    });

    var table = '<table class="table" style="width:100%;text-align:left">';
    table    += '<tr>';
    table    += '<th></th><th>Trial</th><th>Description</th><th>Location</th>'
              + '<th>Year</th><th id="color_tip" title="You can combine trials sharing the same color.">'
              + 'Tip(?)</th>';
    table    += '</tr>';
   
    
    for (var i=0; i < trials.length; i++) {
      
        if (trials[i]) {
            table += '<tr>';
            table += '<td>' + trials[i][0] + '</td>' 
                + '<td>' + trials[i][1] + '</td>'
                + '<td>' + trials[i][2] + '</td>'
                + '<td>' + trials[i][3] + '</td>'
                + '<td>' + trials[i][4] + '</td>'
                + '<td>' + trials[i][5] + '</td>';
            table += '</tr>';
        }
    }
    
    table += '</table>';

    return table;

}

