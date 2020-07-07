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
	
	if (page.match(/solgs\/trait\/|solgs\/model\/combined\/populations\//)) {	    
	    popId = jQuery("#training_pop_id").val();
	} else {
	    popId = jQuery("#selection_pop_id").val();
	}

	var protocolId = jQuery("#genotyping_protocol_id").val();
	var traitId = jQuery("#trait_id").val();
	
	return {
	    'kinship_pop_id' : popId,
	    'genotyping_protocol_id': protocolId,
	    'trait_id': traitId,
	};        
    },

    
   loadKinshipPops: function(selectId, selectName, dataStructure) {
       console.log('loading kiship data') 
	if ( selectId.length === 0) {       
            alert('The list is empty. Please select a list with content.');
	} else {
	              
            var kinshipTable = jQuery("#kinship_pops_table").doesExist();
            console.log('kinshiptable ' + kinshipTable)
	    
            if (!kinshipTable) {
                kinshipTable = this.createTable();
		jQuery("#kinship_pops_section").append(kinshipTable).show();                           
            }

	    
	    var onClickVal =  '<button type="button" class="btn btn-success" onclick="solGS.kinship.runKinship('
                + selectId + ",'" + selectName + "'" +  ",'" + dataStructure
	    	+ "'" + ')">Run Kinship</button>';


	    var dataType = ['Genotype'];
	    var dataTypeOpts = this.createDataTypeSelect(dataType);
	    
	    var addRow = '<tr  name="' + dataStructure + '"' + ' id="' + selectId +  '">'
                + '<td>' + selectName + '</td>'
		+ '<td>' + dataStructure + '</td>'
		+ '<td>' + dataTypeOpts + '</td>'
                + '<td id="list_kinship_page_' + selectId +  '">' + onClickVal + '</td>'          
                + '<tr>';

	    var tdId = '#list_kinship_page_' + selectId;
	    var addedRow = jQuery(tdId).doesExist();

	    if (!addedRow) {
                jQuery("#kinship_pops_table tr:last").after(addRow);
	    }
	}

    },
 
    createTable: function () {
	var kinshipTable ='<table id="kinship_pops_table" class="table table-striped"><tr>'
            + '<th>Population</th>'
            + '<th>Data structure type</th>'
	    + '<th>Data type</th>'
            + '<th>Run Kinship</th>'
            +'</tr>'
            + '</td></tr></table>';
	
	return kinshipTable;
    },
    

    createDataTypeSelect: function(opts) {
	var dataTypeGroup = '<select class="form-control" id="kinship_data_type_select">';

	for (var i=0; i < opts.length; i++) {
	    
	    dataTypeGroup += '<option value="'
		+ opts[i] + '">'
		+ opts[i]
		+ '</option>';
	}
	dataTypeGroup +=  '</select>';
	
	return dataTypeGroup;
    },

   
    runKinship: function (selectId, selectName, dataStructure) {

	var protocolId = jQuery('#genotyping_protocol #genotyping_protocol_id').val();
	console.log('protocol id: ' + protocolId)
	
	var traitId = jQuery('#trait_id').val();

	var kinshipArgs = {
	    'kinship_pop_id' : selectId,
	    'kinship_pop_name' : selectName,
	    'data_structure' : dataStructure,
	    'genotyping_protocol_id' : protocolId,
	    'trait_id' : traitId
	};
	
	jQuery("#kinship_canvas .multi-spinner-container").show();
	jQuery("#kinship_message")
	    .html("Running kinship... please wait...it may take minutes")
	    .show();
//	  url: '/kinship/run/analysis',	
	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    data: kinshipArgs,
	    url: '/solgs/kinship/result',
	    success: function(res) {
		if (res.result == 'success') {
		    jQuery("#kinship_canvas .multi-spinner-container").hide();
		    		    
		    solGS.kinship.plotKinship(res.data);
		    solGS.kinship.addDowloandLinks(res);

		    jQuery("#kinship_message").empty();

		} else {                
		    jQuery("#kinship_message").html(res.result);
		    jQuery("#kinship_canvas .multi-spinner-container").hide();
		    jQuery("#run_kinship").show();		    
		}
	    },
	    error: function(res) {
		jQuery("#kinship_message")
		    .html('Error occured running the clustering.')
		    .show()
		    .fadeOut(8400);
		
		jQuery("#kinship_canvas .multi-spinner-container").hide();
	    }  
	});
   
    },

    
    getKinshipResult: function() {
 
	var popData = this.getPopulationDetails();
		
	jQuery("#kinship_message").html("Running kinship... please wait...");
        
	jQuery.ajax({
            type: 'POST',
            dataType: 'json',
            data: popData,
            url: '/solgs/kinship/result/',
            success: function (res) {
		
                if (res.data_exists) {
			
                    solGS.kinship.plotKinship(res.data);
		    solGS.kinship.addDowloandLinks(res);

		    jQuery("#kinship_message").empty();
                } else {
		    
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

        solGS.heatmap.plot(data, '#kinship_canvas');
		    
    },

    addDowloandLinks: function(res) {
	
	var kinshipFile = res.kinship_table_file;
	console.log('kinshipFile ' + kinshipFile)
	var aveFile = res.kinship_averages_file;
	var inbreedingFile = res.inbreeding_file;

	var fileNameKinship = kinshipFile.split('/').pop();
	var fileNameAve = aveFile.split('/').pop();
	var fileNameInbreeding = inbreedingFile.split('/').pop();
	
	kinshipFile = "<a href=\"" + kinshipFile
	    +  "\" download=" + fileNameKinship + ">Kinship matrix</a>";
	
	aveFile = "<a href=\"" + aveFile
	    +  "\" download=" + fileNameAve + ">Average kinship</a>";
	
	inbreedingFile = "<a href=\"" + inbreedingFile
	    +  "\" download=" + fileNameInbreeding + ">Inbreeding Coefficients</a>";
		
	jQuery("#kinship_canvas")
	    .append('<br /> <strong>Download:</strong> '
		     + kinshipFile + ' | '
		     + aveFile + ' | '
		     + inbreedingFile)
	    .show();
	
    },

///////
}



jQuery(document).ready( function () { 

    jQuery("#run_kinship").click(function () {
	var url = document.URL;
    
	if (url.match(/kinship\/analysis/)) {
	    solGS.kinship.runKinship();
	} else {
            solGS.kinship.getKinshipResult();
	}
	
    	jQuery("#run_kinship").hide();
    }); 
  
});

jQuery(document).ready( function() {
    
    var url = document.URL;
    
    if (url.match(/kinship\/analysis/)) {
    
        var list = new CXGN.List();
        var listMenu = list.listSelect("kinship_pops", ['accessions', 'trials'], undefined, undefined, undefined);

	var dType = ['accessions', 'trials'];	
	var dMenu = solGS.dataset.getDatasetsMenu(dType);
	
	if (listMenu.match(/option/) != null) {
            
            jQuery("#kinship_pops_list").html(listMenu);
	    jQuery("#kinship_pops_list_select").append(dMenu);

        } else {            
            jQuery("#kinship_pops_list").html("<select><option>no lists found - Log in</option></select>");
        }
    }
               
});


jQuery(document).ready( function() { 
     
    var url = document.URL;
    
    if (url.match(/kinship\/analysis/)) {

	
        var selectId;
	var selectName;
        var dataStructure;
	
        jQuery("<option>", {value: '', selected: true}).prependTo("#kinship_pops_list_select");
        
        jQuery("#kinship_pops_list_select").change(function() {        
            selectId = jQuery(this).find("option:selected").val();
            selectName = jQuery(this).find("option:selected").text();    
            dataStructure  = jQuery(this).find("option:selected").attr('name');
	    
	    if (dataStructure == undefined) {
		dataStructure = 'list';
	    }
	   
            if (selectId) {                
                jQuery("#kinship_go_btn").click(function() {
                    solGS.kinship.loadKinshipPops(selectId, selectName, dataStructure);
                });
            }
        });
    } 

    
});
