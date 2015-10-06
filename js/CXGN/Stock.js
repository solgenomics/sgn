
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

    jQuery('#remove_parent_dialog').dialog({ 
	'autoOpen' : false,
	'modal' : true,
	'title' : 'Remove a parent',
	'height' : 300,
	'width' : 400,
	'buttons' : {
	    'Done' : function() { 
		jQuery('#remove_parent_dialog').dialog("close");
	    },

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

function get_remove_parents_list(stock_id) { 
    jQuery.ajax( { 
	url : '/ajax/stock/parents?stock_id='+stock_id,
	success: function(response) { 
	    var html = "";
	    for (var n=0; n<response.parents.length; n++) { 
		html += response.parents[n][1]+ '&nbsp;&nbsp;<a href="javascript:remove_parents('+response.stock_id+','+ response.parents[n][0]+');" ><font color="red" >X</font></a><br /><br />';
		
	    }

	    jQuery('#remove_parent_list').html(html);
	},
	error: function(response) { 
	    alert("an error occurred.");
	}
    });

}

function remove_parents(stock_id, parent_id) { 
    var yes = confirm("Are you sure you want to remove this parent?");
    if (yes) { 
	jQuery.ajax( { 
	    url: '/ajax/stock/parent/remove',
	    data: { 'stock_id' : stock_id, 'parent_id' : parent_id },
	    success : function(response) { 
		if (response.error) { 
		    alert(response.error);
		}
		else { 
		    alert("The parent has been removed.");
		    jQuery('#remove_parent_dialog').dialog("close");
		    window.location.href = '/stock/'+stock_id+'/view';
		    
		}
	    }
	});
	
    }

}
