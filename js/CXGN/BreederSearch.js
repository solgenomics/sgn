

var choices = { '': 'please select', project :'program', year : 'year', location : 'location' };

window.onload = function initialize() { 
    //alert('initialize...');
    
    var html = ''; //<option value="">please select</option>\n';
    html = html + format_options(choices);
    jQuery('#select1').html(html);   
    //alert('done');
    
    jQuery('#select1').change(function() { 
	var select1 = jQuery( this ).val();
	// alert('Getting the data...'+select1);
	jQuery.ajax( { 
	    url: '/ajax/breeder/search',
	    async: false,
	    data: {'select1':select1},
       success: function(response) { 
           if (response.error) { 
               alert(response.error);
           } 
           else {
               var  c1_html = format_options_list(response.list)
           }
	   jQuery('#c1_data').html(c1_html);
	   jQuery('#c2_data').html('');
	   jQuery('#c3_data').html('');
	   jQuery('#stock_data').html('');
	   
	   
       }
	});
	
	//alert("CHOICES = "+ choices);
	var second_choices = copy_hash(choices);
	delete second_choices[select1];
	var html = format_options(second_choices);
	jQuery('#select2').html(html);
	
    });
    
    jQuery('#c1_data').change(function() { 
	jQuery('#c2_data').html('');
	jQuery('#c3_data').html('');
	jQuery('#stock_data').html('');

    });
    
    
    jQuery('#select2').change(function() { 
 	var select1 = jQuery('#select1').val();
	var select2 = jQuery('#select2').val();
	var c1_data = jQuery('#c1_data').val() || [];
	//alert('Select1: '+select1+', select2: '+select2+' c1_data = '+c1_data.join(","));
	
	var c2_data = '';
	var stock_data = '';
	jQuery.ajax( { 
	    url: '/ajax/breeder/search',
	      async: false,
	    data: {'select1':select1, 'select2':select2, 'c1_data': c1_data.join(",") },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		} 
		else {
		    c2_html = format_options_list(response.list);
		    stock_data = format_options_list(response.stocks);
		}
		jQuery('#c2_data').html(c2_html);
		jQuery('#stock_data').html(stock_data);
		
	    }
	});
	
	alert("CHOICES = "+ choices);
	var third_choices = copy_hash(choices);
	delete third_choices[select1];
	  delete third_choices[select2];
	var html = format_options(third_choices);
	jQuery('#select3').html(html);
	
	
    });

    
    jQuery('#c2_data').change(function() { 
	jQuery('#c3_data').html('');
	jQuery('#stock_data').html('');

    });


    jQuery('#select3').change( function() {
 	var select1 = jQuery('#select1').val();
	var select2 = jQuery('#select2').val();
	var select3 = jQuery('#select3').val();
	var c1_data = jQuery('#c1_data').val() || [];
	var c2_data = jQuery('#c2_data').val() || [];
	//alert('Select1: '+select1+', select2: '+select2+' c1_data = '+c1_data.join(","));
	
	var stock_data = '';

	jQuery('#stock_data').html('');
		jQuery.ajax( { 
		    url: '/ajax/breeder/search',
		    async: false,
		    data: {'select1':select1, 'select2':select2, 'c1_data': c1_data.join(","),  'c2_data': c2_data.join(","), 'select3':select3 },
		    success: function(response) { 
			if (response.error) { 
			    alert(response.error);
			} 
			else {
			    c3_html = format_options_list(response.list);
			    stock_data = format_options_list(response.stocks);
			}
			jQuery('#c3_data').html(c3_html);
			jQuery('#stock_data').html(stock_data);
		
		    }
		});
    });

    jQuery('#c3_data').change(function() { 
	jQuery('#stock_data').html('');

	alert('hihi');
	var select1 = jQuery('#select1').val();
	var select2 = jQuery('#select2').val();
	var select3 = jQuery('#select3').val();
	var c1_data = jQuery('#c1_data').val() || [];
	var c2_data = jQuery('#c2_data').val() || [];
	var c3_data = jQuery('#c3_data').val() || [];
	
	var stock_data = "";

    	jQuery.ajax( { 
		    url: '/ajax/breeder/search',
		    async: false,
	    data: {'select1':select1, 'select2':select2, 'c1_data': c1_data.join(","),  'c2_data': c2_data.join(","), 'select3':select3, 'c3_data': c3_data.join(",") },
		    success: function(response) { 
			if (response.error) { 
			    alert(response.error);
			} 
			else {
			    c3_html = format_options_list(response.list);
			    stock_data = format_options_list(response.stocks);
			}
			jQuery('#stock_data').html(stock_data);
		
		    }
		});
    });

    
}



function format_options(items) { 
    var html = '';
    for (var key in items) { 
	html = html + '<option value="'+key+'">'+items[key]+'</a>\n';
    }
    return html;
}

function format_options_list(items) { 
    var html = '';
    for(var i=0; i<items.length; i++) { 
	html = html + '<option value="'+items[i][0]+'">'+items[i][1]+'</a>\n';
    }
    return html;
}


function select_criterion3() { 
    
    
    
}

function copy_hash(hash) { 
    var new_hash = new Array();

    for (var key in hash) { 
	new_hash[key] = hash[key];
    }
    return new_hash;
}


