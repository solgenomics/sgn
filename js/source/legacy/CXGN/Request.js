/** 

=head1 NAME

Class: Request 

=head1 SYNOPSIS

A simple handler for Async Requests

The returned XML file should contain all information needed to cause a page effect,
rather than creating a custom response for each request, which is not possible due
to the security issues that prevent the creation of instances of XMLHttpRequest() 
with unique properties.  It's better this way, anyhow :-/

See XMLRoute.js to write handlers for async responses. 

=head1 USAGE

var req = new Request();
if(req.isValid()){
	req.send("scraps/add.pl", "?first=3&second=2", "POST");
}

=head1 AUTHOR

Chris Carpita <csc32@cornell.edu>

=cut

*/

JSAN.use("CXGN.Base");
JSAN.use("CXGN.XMLroute");

function Request() {
	
	var req = null;
	this.valid = false;
	var loader = this;
		
	this.isValid = function() { return this.valid }
	this._onReadyState = function() {
		if(req.readyState==4){
//			document.write(req.responseText);
			XMLroute.call(this, req.responseXML);	
		}
	}	
	this.send = function(url, parameters, method) {
		if(!method) { method = "POST" }
		if(method == "POST") {
			req.open("POST", url, true);
			req.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
      		req.setRequestHeader("Content-length", parameters.length);
	        req.setRequestHeader("Connection", "close");
			req.send(parameters);
		}
		else if(method == "GET") {
			req.open("GET", url + parameters, true);
			req.send(null);
		}
	}
	if(window.XMLHttpRequest) {
		req = new XMLHttpRequest();
	}
	else if (window.ActiveXObject) {
		try { req = new ActiveXObject("Msxml2.XMLHTTP");}
		catch(e) {
			try { req = new ActiveXObject ("Microsoft.XMLHTTP");}
			catch (e) { return false }
		}
	}
	if(req) { 
		this.valid = true;
		req.onreadystatechange = function() { loader._onReadyState.call() }
		return true;
	}
	else { return false }
}

