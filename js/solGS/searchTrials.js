/** 
* search trials
*
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/




jQuery(document).ready(function(){   
    searchTrials();                        
});


function searchTrials() {
 
    jQuery.ajax({  
        type: 'POST',
        dataType: "json",
        url: '/solgs/search/trials/',
        success: function(res) {                                                                                
            var trialsList = listTrials(res.trials);
            var pagination = res.pagination;
            jQuery("#homepage_trials_list").html(trialsList + pagination).show();            
        },
        error: function() {               
            alert('error fetching first 10 trials');
        }
    });

    jQuery("#homepage_trials_list").on('click', "div.paginate_nav a", function(e) { 
        var page = jQuery(this).attr('href');
  
        if (page) {
            jQuery.ajax({  
                type: 'POST',
                dataType: "json",
                url: page,
                success: function(res) {                                                                                 
                    var trialsList = listTrials(res.trials);
                    var pagination = res.pagination;
                    jQuery("#homepage_trials_list").empty();
                    jQuery("#homepage_trials_list").html(trialsList + pagination).show();
                  
                },
                
                error: function() {
                    alert('error fetching trials next pages.');
                }                    
            });                
        }

        return false;
    });                

}



function listTrials (trials)  {
    
    var table = '<table style="text-align:left">';
    table    += '<tr>';
    table += '<th></th><th>Trial</th><th>Description</th><th>Location</th><th>Year</th>';
    table += '</tr>';
   
    for (var i=0; i<10; i++) {
      
        if (trials[i]) {
            table += '<tr>';
            table += '<td>' + trials[i][0] + '</td>' 
                + '<td>' + trials[i][1] + '</td>'
                + '<td>' + trials[i][2] + '</td>'
                + '<td>' + trials[i][3] + '</td>'
                + '<td>' + trials[i][4] + '</td>';
            table += '</tr>';
        }
    }
    
    table += '</table>';

    return table;

}

