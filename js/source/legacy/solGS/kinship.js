/** 
* kinship plotting using d3
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/

var solGS = solGS || function solGS() {};

solGS.kinship = {


    getPopulationDetails: function () {

	var page = document.URL;
	var popId;
	if (page.match(/solgs\/trait\//)) {	    
	    popId = jQuery("#training_pop_id").val();
	} else {
	    popId = jQuery("#selection_pop_id").val();
	}

	var protocolId = jQuery("#genotyping_protocol_id").val();
	
	return {
	    'kinship_pop_id' : popId,
	    'genotyping_protocol_id': protocolId
	};        
    },

    

    getKinshipData: function() {
 
	var popData = this.getPopulationDetails();
		
	jQuery("#kinship_message").html("Running kinship... please wait...");
        
	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: popData,
            url: '/solgs/kinship/data/',
            success: function (res) {
		
                if (res.data_exists) {
		    console.log('kinship data exists ' + res.data_exists)
		   // console.log('kinship data ' + res.data)
                    solGS.kinship.plotKinship(res.data);
		    jQuery("#kinship_message").empty();
                } else {
		      console.log('kinship data does not exist ' + res.data_exists)
                    jQuery("#kinship_message")
                        .css({"padding-left": '0px'})
                        .html("This population has no kinship data.");

		    jQuery("#run_kinship").show();
                }
            },
            error: function (res) {
                jQuery("#kinship_message")
                    .css({"padding-left": '0px'})
                    .html("Error occured preparing the kinship data.");

		jQuery("#run_kinship").show();
            }
	});     
    },


    plotKinship: function (data) {

	var pop = this.getPopulationDetails();
	var popId = pop.kinship_pop_id;

	console.log('calling plotCorrelation')
        solGS.heatmap.plot(data, '#kinship_canvas');
	
	var kinshipDownload = "<a href=\"/download/kinship/population/" 
	    + popId + "\">Download kinship</a>";

	jQuery("#kinship_canvas").append("<br />[ " + kinshipDownload + " ]").show();
		  
		    
    },


///////
}



jQuery(document).ready( function () { 

    jQuery("#run_kinship").click(function () {
        solGS.kinship.getKinshipData();
    	jQuery("#run_kinship").hide();
    }); 
  
});


