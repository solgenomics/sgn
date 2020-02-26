
/** 
* Sets genotyping protocol for solGS and related analysis
* Isaak Y Tecle <iyt2@cornell.edu>
*
*/


var solGS = solGS || function solGS () {};

solGS.genotypingProtocol= {

    setGenotypingProtocol: function(arg) {

	var msg = 'You are using genotyping protocol: <b>' + arg.name + '</b>.';

	jQuery('#genotyping_protocol_message').val(arg.protocol_id);
	jQuery('#genotyping_protocol_message').html(msg);
	jQuery('#genotyping_protocol_id').val(arg.protocol_id);
	
	console.log('set args.protocol_id ' + arg.protocol_id)
	var defaultPro = jQuery('#genotyping_protocol_id').val();
	console.log('set defaultPro ' + defaultPro)
	
    },

    getAllProtocols: function() {
	 
	jQuery.ajax({
	    type: 'POST',
	    dataType: 'json',
	    url: '/get/genotyping/protocols/',
	    success: function(res) {
	
		var allProtocols = res.all_protocols;
		console.log(allProtocols[0].protocol_id)
		console.log(allProtocols[0].name)
		console.log('default ' + res.default_protocol.protocol_id)
		solGS.genotypingProtocol.setGenotypingProtocol(res.default_protocol);	
		solGS.genotypingProtocol.populateMenu(allProtocols);
		
	    }
	});
	
    },

     createGenoProtocolsOpts: function(allProtocols) {
	 var genoProtocols;

	 for (var i = 0; i < allProtocols.length; i++) {
	    
	     genoProtocols += '<option value="'
		 + allProtocols[i].protocol_id + '">'
		 + allProtocols[i].name
		 + '</option>';
	 }
	
	return genoProtocols;
     },

    populateMenu: function(allProtocols) {

	var menu = this.createGenoProtocolsOpts(allProtocols);
	console.log('menu ' + menu)
	jQuery('#genotyping_protocols_list_select').append(menu);	
    },
       
}


jQuery(document).ready( function() {
    solGS.genotypingProtocol.getAllProtocols();
});

jQuery(document).ready( function() { 

    jQuery("#genotyping_protocols_change").click(function() {
	jQuery('#genotyping_protocols_list_div').show();
	jQuery('#genotyping_protocols_change').hide();
    });
   
});


jQuery(document).ready( function() { 
  
    jQuery("<option>", {value: '', selected: true}).prependTo('#genotyping_protocols_list_select');
     
    jQuery('#genotyping_protocols_list_select').change( function() {
    
        var selectedId = jQuery(this).find('option:selected').val();
    	var selectedName = jQuery(this).find('option:selected').text();
         
    	var selected = { 'protocol_id': selectedId,
    			 'name'       : selectedName
    		       };	

    	console.log('selectId: ' + selectedId + ' name ' + selectedName)
    	solGS.genotypingProtocol.setGenotypingProtocol(selected);
	jQuery('#genotyping_protocols_list_div').hide();
	jQuery("#genotyping_protocols_list_select option:selected").prop("selected",false);
	jQuery('#genotyping_protocols_change').show();

    
    });
  
});
