/** 
* @class Publiction
* Function used for manipulating publication status, and curating
* @author Naama Menda <nm249@cornell.edu>
*
*/

JSAN.use('MochiKit.DOM');
JSAN.use('MochiKit.Visual');
JSAN.use('MochiKit.Async');

JSAN.use('CXGN.Effects');
JSAN.use('CXGN.Phenome.Tools');


var Publication = {
 
    //update status of pub_crator
    updatePubCuratorStat: function(stat, pub_id) {
	if (stat == '' || !pub_id ) { MochiKit.Logging.log('Cannot update status! '); }
	else {
	    var action = "change_stat";
	    //alert ('About to update pub_curator status to -' +  stat + ' - (pub_id= ' + pub_id + ')') ;
	    new Ajax.Request('/curator/pub_curator.pl', {
		    parameters: {stat: stat, pub_id: pub_id , action: action}, 
		    onException: function(request) {
			var json=request.responseText;
			var x = eval("("+json+")");
			MochiKit.Logging.log("Failed updating  pub_curator", x.error);
		    },
		    onSuccess: function(request) {
			var json=request.responseText;
			var x = eval("("+json+")");
			MochiKit.Logging.log("JSON message:", x.error);
		    }
	    });
	}
    },
    //update assigned curator
    updatePubCuratorAssigned: function(curator_id, pub_id) {
	if (pub_id && curator_id) {
	    var action= "assign_curator";
	    new Ajax.Request('/curator/pub_curator.pl', {
		    parameters: {curator_id: curator_id, pub_id:pub_id, action: action},
		    onSuccess: function(response) {
			var json = response.responseText;
			var x = eval("("+json+")"); 
			//alert(x.error);
			MochiKit.Logging.log("stored pub_curator. " , x.error);
		    },
		    onFailure: function(response) {  //this does not work as expected! 
			var json = response.responseText;
			var x = eval("("+json+")"); 
			alert ("Failed assigning a pub curator! "  + x.error) ; 
		    }
	    });
	}
    },
    /////
}

