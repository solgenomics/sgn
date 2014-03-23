jQuery(document).ready(function() {    
    
    display_progeny(get_cross_id());
    
    cross_properties(get_cross_id());
    
    function get_cross_id() { 
	var cross_id = jQuery('#cross_id').html();
	var regex = /\n|\r/g;
	
	cross_id = cross_id.replace(regex, "");
	return cross_id;

    }

    function get_cross_name() { 
	var cross_name = jQuery('#cross_name').html();
	var regex = /\n|\r/g;
	cross_name = cross_name.replace(regex, "");
	return cross_name;
    }
    
    function display_progeny(cross_id) { 
	
	jQuery.ajax( { 
	    type: 'POST',
	    url: '/cross/ajax/relationships/'+cross_id,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		    return;
		}
		var html = "<table>";
		if (response.progeny) { 
		    for (var i=0; i<response.progeny.length; i++) { 
			html += '<td><a href="/stock/'+response.progeny[i][1]+'/view">'+response.progeny[i][0]+'</a></td></tr>';
		    }
		}						 
		html += "</table>";
		jQuery('#progeny_information_div').html(html);
		
		var parent_html = "";
		if (response.maternal_parent) { 
		    parent_html = '<img src="/img/Venus_symbol.svg" width="20" /> <a href="/stock/'+response.maternal_parent[1] +'/view">'+response.maternal_parent[0]+'</a><br />';
		}
		if (response.paternal_parent) { 						   
		    parent_html += '<img src="/img/Mars_symbol.svg" width="20" /> <a href="/stock/'+response.paternal_parent[1] +'/view">'+response.paternal_parent[0]+'</a><br />';						   }
		jQuery('#parents_information_div').html(parent_html);
	    },
	    
	    error: function(response, a, b) { 
		jQuery('#progeny_information_div').html('An error occurred. '+a +' '+ b);
	    }
	});
	
    }
    
    function display_parents(cross_id) { 
	jQuery.ajax( { 
	    type: 'POST',
	    url: '/cross/ajax/parents/'+cross_id,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		    return;
		}
		var html = "<table>";
		if (response.parents) { 
		    for (var i=0; i<response.parents.length; i++) { 
			html += '<td><a href="/stock/'+response.parents[i][1]+'/view">'+response.parents[i][0]+'</a></td></tr>';
		    }
		}
		html += "</table>";
		jQuery('#parents_information_div').html(html);					   
      },
      error: function(response, a, b) { 
	  jQuery('#parents_information_div').html('An error occurred. '+a +' '+ b);
      }
	});
    }
    
    function cross_properties(cross_id) { 
	
	jQuery.ajax( { 
	    type: 'POST',
	    url: '/cross/ajax/properties/'+cross_id,
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		    return;
		}
		var html = "<table>";
		if (response.props) { 
		    for (var k in response.props) { 
			html += '<tr><td>'+k+'</td><td>...</td>';
			var edit_link = "";					
			for (var n=0; n<response.props[k].length; n++) { 
			    if (isLoggedIn()) { 
				edit_link = '<a id="edit_link_prop_'+response.props[k][n][1]+'">[edit]</a>'; 
			    }
			    html += '<td><b>'+response.props[k][n][0]+'</b></td><td>'+edit_link+'</td></tr>';
			}
			
			
		    }
    		    html += '</table>';
		    jQuery('#cross_properties_div').html(html);
		}
	    },
	    error: function(response) { alert("An error occurred") }
	} );						 
    
	
	
	
    }
    
    jQuery('#add_more_progeny_link').click( function() { 
	jQuery('#add_more_progeny_dialog').dialog("open");
	jQuery('#progeny_count').focus();
    });
    
    jQuery('#add_more_progeny_dialog').dialog( { 
	height: 250,
	width: 500,
	buttons: { 'OK': {
            id: 'add_more_progeny_dialog_ok_button', 
	    click: function() { 
		jQuery('#working').dialog("open");
		add_more_progeny(get_cross_id(), get_cross_name(), jQuery('#basename').val(), jQuery('#start_number').val(), jQuery('#progeny_count').val());
                
	    },
            text: "OK" 
	} , 
		   'Cancel': {  id: 'add_more_progeny_dialog_cancel_button',
				click:  function() { jQuery('#add_more_progeny_dialog').dialog("close") }, text: "Cancel" } },
	autoOpen: false,
	title: 'Add more progeny'
	
    });
    
    function add_more_progeny(cross_id, cross_name, basename, start_number, progeny_count) { 
	
	jQuery.ajax({ 
	    url: '/cross/progeny/add/'+cross_id,
	    data: { 'cross_name': cross_name, 'basename': basename, 'start_number': start_number, 'progeny_count': progeny_count },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error); 
		}
		else { alert('Added '+progeny_count+' new progeny'); 
		       jQuery('#working').dialog("close");
                       display_progeny(get_cross_id());
		       jQuery('#add_more_progeny_dialog').dialog("close");
		     }
	    },
	    error: function(response, code, error) { alert('error: '+error); }
	});
    }

    jQuery('#edit_properties_dialog').dialog( { 
	height: 250,
	width: 500,
	buttons: { 'OK': 
		   {
		       id: 'edit_properties_dialog_ok_button', 
		       click: function() { 
			   jQuery('#working').dialog("open");
		           
		       },
		       text: "OK" 
		   } , 
		   'Cancel': {  
		       id: 'edit_properties_dialog_cancel_button',
		       click:  function() { jQuery('#edit_properties_dialog').dialog("close") }, 
		       text: "Cancel" } },
	autoOpen: false,
	title: 'Edit cross properties'
	
	

    });

    jQuery('#edit_properties_link').click( function() { 
	jQuery('#edit_properties_dialog').dialog("open");

    });
    
});
