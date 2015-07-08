
function stock_detail_page_init_dialogs() { 
        jQuery('#stock_trials_info_popup').dialog({ 
	'autoOpen' : false,
	'modal' : true,
	'height' : 600,
	'width' : 700,
	'buttons' : {
	    'OK' : function() { 
		jQuery('#stock_trials_info_popup').dialog("close");
	    }
	}
	    
    });

}

function show_stock_trial_detail(stock_id, stock_name, trial_id, trial_name) { 
    jQuery('#stock_trials_info_popup').dialog("option", "title", "Phenotypic data for "+stock_name+" from trial "+trial_name);
    jQuery('#stock_trials_info_popup').dialog("open");
    jQuery('#stock_trials_info_table').DataTable().destroy();

    jQuery('#stock_trials_info_table').DataTable( { 
	ajax: '/stock/'+stock_id+'/datatables/trial/'+trial_id,	
    });
}
