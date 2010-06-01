

// an image object that possibly should be expanded to retrieving other stuff
// such as description etc... here just a stub to retrieve the html for the
// image itself.

// Author: Lukas Mueller

if (!CXGN) CXGN= function() {};


CXGN.Image = function() { 

};



CXGN.Image.prototype = { 
    
    set_image_id: function(image_id) { 
	this.image_id=image_id;
    },

    get_image_id: function() { 
	return this.image_id;
    },

    image_html: function(div, size) { 
	new Ajax.Request('/cgi-bin/image/ajax/fetch_image.pl', {
		parameters: { image_id: this.get_image_id(), size: size },
		onSuccess: function(response) {
		    var json = response.responseText;
		    //alert('JSON: '+json)
		    var r = eval ("("+json+")");
	
		    var html_div = document.getElementById(div);
	
		    html_div.innerHTML='<center>'+r.html+'</center>';
	
		    if (x.error) { 
			alert(x.error); 
		    } 
		},
		onError: function() {
		    alert('An error occurred! ');
		},
	    });
    }

}


	
	

