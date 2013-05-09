

var choices = { '': 'please select', project :'program', year : 'year', location : 'location', trait: 'trait' };

window.onload = function initialize() { 
    //alert('initialize...');
    
    var html = ''; 
    var c1_html = '';
    var stock_data;
    html = html + format_options(choices);
    jQuery('#select1').html(html);   

    jQuery('#select1').change(function() { 
	var select1 = jQuery( this ).val();
	//alert('Getting the data...'+select1);
	jQuery.ajax( { 
	    url: '/ajax/breeder/search',
	    async: true,
	    timeout: 60000,
	    data: {'select1':select1},
	    success: function(response) { 
           if (response.error) { 
               alert(response.error);
           } 
           else {
               c1_html = format_options_list(response.list);
	       update_stocks(response.stocks);
           }
	   jQuery('#c1_data').html(c1_html);
	   jQuery('#c2_data').html('');
	   jQuery('#c3_data').html('');

	   
	   
       }
	});
	
	var second_choices = copy_hash(choices);
	delete second_choices[select1];
	var html = format_options(second_choices);
	jQuery('#select2').html(html);
	
    });
    
    jQuery('#c1_data').change(function() { 
	jQuery('#select2').val('please select');
	jQuery('#select3').val('please select');
	jQuery('#c2_data').html('');
	jQuery('#c3_data').html('');
	jQuery('#stock_data').html('');
	var select1 = jQuery('#select1').val();
	var c1_data = jQuery('#c1_data').val() || [];
	//alert("HELLO!");
	jQuery.ajax( { 
	    url: '/ajax/breeder/search',
	    async: true,
	    timeout: 60000,
	    data: {'select1':select1, 'c1_data': c1_data.join(",")  },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		} 
		else {
		    update_stocks(response.stocks);
		}
	    }
	});


    });
    
    
    jQuery('#select2').change(function() { 
 	var select1 = jQuery('#select1').val();
	var select2 = jQuery('#select2').val();
	var c1_data = jQuery('#c1_data').val() || [];
	jQuery('#select3').val('please select');
	jQuery('#c2_data').val('');
//	alert('Select1: '+select1+', select2: '+select2+' c1_data = '+c1_data.join(","));
	
	var c2_data = '';
	var stock_data = '';
	jQuery.ajax( { 
	    url: '/ajax/breeder/search',
	    async: true,
	    timeout: 60000,
	    data: {'select1':select1, 'select2':select2, 'c1_data': c1_data.join(",") },
	    success: function(response) { 
		if (response.error) { 
		    alert("ERROR: "+response.error);
		} 
		else {
		    c2_html = format_options_list(response.list);

		    jQuery('#c2_data').html(c2_html);
		    update_stocks(response.stocks);
		    		    
		}
		
	    } 
	});
	
	var third_choices = copy_hash(choices);
	delete third_choices[select1];
	delete third_choices[select2];
	var html = format_options(third_choices);
	jQuery('#select3').html(html);
	
	
    });

    
    jQuery('#c2_data').change(function() { 
	jQuery('#c3_data').html('');
	jQuery('#stock_data').html('');

	var select1 = jQuery('#select1').val();
	var select2 = jQuery('#select2').val();
	var c1_data = jQuery('#c1_data').val() || [];
	var c2_data = jQuery('#c2_data').val() || [];

	jQuery.ajax( { 
	    url: '/ajax/breeder/search',
	    async: true,
	    timeout: 60000,
	    data: {'select1':select1, 'c1_data': c1_data.join(","), 'select2':select2, 'c2_data':c2_data.join(",")  },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		} 
		else {
		    c3_html = format_options_list(response.list);
		    update_stocks(response.stocks);
		    //jQuery('#c3_data').html(c3_html);
		}
	    }
	});

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
	    async: true,
	    timeout: 60000,
	    data: {'select1':select1, 'select2':select2, 'c1_data': c1_data.join(","),  'c2_data': c2_data.join(","), 'select3':select3 },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		} 
		else {
		    c3_html = format_options_list(response.list);
		    update_stocks(response.stocks);
		    jQuery('#c3_data').html(c3_html);
		}
	    },
	    error: function(response) { 
		alert("An error occurred. Timeout?");
	    }
	});


    });
    
    jQuery('#c3_data').change(function() { 
	jQuery('#stock_data').html('');

	var select1 = jQuery('#select1').val();
	var select2 = jQuery('#select2').val();
	var select3 = jQuery('#select3').val();
	var c1_data = jQuery('#c1_data').val() || [];
	var c2_data = jQuery('#c2_data').val() || [];
	var c3_data = jQuery('#c3_data').val() || [];
	
	var stock_data;

    	jQuery.ajax( { 
	    url: '/ajax/breeder/search',
	    async: true,
	    timeout: 30000,
	    data: {'select1':select1, 'select2':select2, 'c1_data': c1_data.join(","),  'c2_data': c2_data.join(","), 'select3':select3, 'c3_data': c3_data.join(",") },
	    success: function(response) { 
		if (response.error) { 
		    alert(response.error);
		} 
		else {
		    update_stocks(response.stocks);
		}		
	    },
	    error: function(response) { 
		alert("an error occurred. (possible timeout)");
	    }
	});
    });    
}


function update_stocks(stocks) { 
    var stock_data = format_options_list(stocks);
    jQuery('#stock_data').html(stock_data);
    jQuery('#stock_count').html('Stocks: '+stocks.length);
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

function copy_hash(hash) { 
    var new_hash = new Array();

    for (var key in hash) { 
	new_hash[key] = hash[key];
    }
    return new_hash;
}


