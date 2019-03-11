/**
* @class Hotlist
* A singleton object for easy handling of a user's hotlist.
* Methods: add(buttonId, content), remove(buttonId, content)
* @author Chris Carpita	<csc32@cornell.edu>
*/

JSAN.use("CXGN.Request");
JSAN.use("CXGN.Effects.Hotlist");

//Hotlist is defined as a single object instead of a class. We can't have more than one!
var Hotlist = window.Hotlist || {};
Hotlist = { //buttonId: id of the clicked button, for changing the button
	add: function(buttonId, content) {
		if(!buttonId) { alert("buttonId not sent!"); }
		var waitIndicator;// = new RequestWaitIndicator("hotlistWait:" + content);		
		var request = new Request();
		if(request.isValid()) {
			Effects.Hotlist.switchButton(buttonId, 'remove', content, 1);  //last argument clears onClick to prevent user interaction
 			var parameters = "owner=" + user_id + "&button_id=" + buttonId + "&cookie_string=" + cookie_string + "&action=add&content=" + content;
 			request.send("/scraps/hotlist.pl", parameters, "POST");
		}
		else { alert('invalid request') }
	},
	remove: function (buttonId, content) {
		if(!buttonId) { alert("buttonId not sent!"); }
		var waitIndicator;// = new RequestWaitIndicator("hotlistWait:" + content);		
		var request = new Request();
		if(request.isValid()) {
			Effects.Hotlist.switchButton(buttonId, 'add', content, 1);
			var parameters = "owner=" + user_id + "&button_id=" + buttonId + "&cookie_string=" + cookie_string + "&action=remove&content=" + content;
			request.send("/scraps/hotlist.pl", parameters, "POST");
		}
	},
	_response: function(doc) {
		var newsize = doc.getElementsByTagName("newsize")[0].firstChild.nodeValue;
		var oldsize = doc.getElementsByTagName("oldsize")[0].firstChild.nodeValue;
		var content = doc.getElementsByTagName("content")[0].firstChild.nodeValue;
		var action = doc.getElementsByTagName("action")[0].firstChild.nodeValue;
		var buttonId = doc.getElementsByTagName("buttonId")[0].firstChild.nodeValue;
		if(newsize > oldsize){
			Hotlist._addResponse(buttonId, content, newsize);
		}
		else if(newsize < oldsize) {
			Hotlist._removeResponse(buttonId, content, newsize);
		}
		else {
			Hotlist._nullResponse(buttonId, content, action);
		}
	},
	_addResponse: function(buttonId, content, newsize){
		Effects.Hotlist.switchButton(buttonId, 'remove', content); //will restore onClick attribute
		document.getElementById('hlsize').firstChild.nodeValue = newsize;
	},
	_removeResponse: function(buttonId, content, newsize){
		Effects.Hotlist.switchButton(buttonId, 'add', content);
		document.getElementById('hlsize').firstChild.nodeValue = newsize;
	},
	_nullResponse: function(buttonId, content, action) {
		//probably just jumped the gun...do nothing	
	} 
}



