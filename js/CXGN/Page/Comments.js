
//////////////////////////////////////////////////////////////////////
// ajax for comments
//////////////////////////////////////////////////////////////////////

// written by Beth Skwarecki, ca 2005. Moved form sgn.js to its own 
// file by Lukas, 2/2010.

// many SGN pages have comments

function addComments() {
    if(document.getElementById("commentstype")){
	//	alert(document.getElementById("commentstype").innerHTML + " : " + document.getElementById("commentsid").innerHTML);
		
	var thingtype = document.getElementById("commentstype").innerHTML;
	var thingid = document.getElementById("commentsid").innerHTML;
	var given_referer = document.getElementById("referer").innerHTML;
	
	var commentdiv = document.getElementById("commentsarea");
	commentdiv.innerHTML = "Please wait, checking for comments about " + thingtype + " " + thingid;
	
 	if(!MochiKit.Async.doSimpleXMLHttpRequest) {
 	    alert("cannot do simple request");
 	    return true;
 	}
	
	var req = MochiKit.Async.getXMLHttpRequest();
	
	/* THIS IS WHERE THE REQUEST COMES FROM */
	req.open("GET", '/forum/return_comments.pl?' + "type=" + thingtype + "&id=" + thingid + "&referer=" + given_referer, true);
	
	req.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
	
	/* ajaxify! */
	var def = MochiKit.Async.sendXMLHttpRequest(req);

	if(def) {
	    def.addCallback(myXmlRequestResponse);
	    def.addErrback(myXmlRequestErr);
	    return false;
	} else {
	    return true;
	}
    }
}

function myXmlRequestResponse(req) {
    
    //    alert ("got a response");
    
    var response = req.responseText;
    document.getElementById("commentsarea").innerHTML = req.responseText;
    
}


function myXmlRequestErr(req) {
    //alert("the xml request didn't work. Status: " + req.status + " " + req.number);
}  


/* THIS PART ADDS THE SUCCESS AND FAILURE CALLBACKS */
// can these both be right?
//d.addCallbacks(myXmlRequestResponse, myXmlRequestErr);
//def.addCallbacks(myXmlRequestResponse, myXmlRequestErr);
 

// want comments ajax to run after page load
if(window.onload) {
    var old = window.onload;
    window.onload = function () { old(); addComments(); };
} else {
    window.onload = function () { addComments(); };
}
//alert("things are going fine");

