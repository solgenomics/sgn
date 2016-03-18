/** 
* functions for displaying status of solgs related 
* cluster analyses 
*
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/

function getAnalysisStatus (){
 
    jQuery.ajax({
        type: 'POST',
        dataType: 'json',
        url: '/solgs/display/analysis/status/',
        success: function(response) {
            if (response.data[0]) {
		displayAnalysisStatus(res.data);
            } else { 
		jQuery('#analyses_status_message').html(
		    '<p>There is no record any submitted analysis.</p>');	
            }
	}
    }); 
 
}


function displayAnalysisStatus (data) {
    
    jQuery('#analysis_list').dataTable({
	'searching' : false,
	'ordering'  : false,
	'processing': true,
	'paging'    : false,
	'info'      : false,
	"data"      : data
    });
}




