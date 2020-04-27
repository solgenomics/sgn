/**
* @class XMLroute
* A singleton object/function for routing XML responses to the proper handlers, based on the text in the <caller> tag of the XML response.
* @author Chris Carpita <csc32@cornell.edu>
*/

JSAN.use('CXGN.Hotlist');
JSAN.use('CXGN.Fasta');
JSAN.use('CXGN.UserPrefs');

JSAN.use('CXGN.Base');

//JSAN.use('CXGN.blipblop');
//For every possible caller, we should include its module.  More than likely, it's not necessary, since the caller usually exists
//in the first place to make the AJAX call, but it's possible that one object may send an XML response to another object by using the 'wrong'
//<caller> tag.  Mostly for things that I can't imagine.  

function XMLroute (responseXML) {
	var doc = responseXML;
	var callerTag = doc.getElementsByTagName("caller")[0];
	var caller = "";
	if(callerTag){
		caller = callerTag.firstChild.nodeValue;
	}
	if(caller=="Hotlist") {
		Hotlist._response(doc);
	}
	if(caller=="Fasta"){
		Fasta._response(doc);
	}
	if(caller=="UserPrefs"){
		UserPrefs._response(doc);
	}
	//else if (caller == "blipblop" )
	//		blipblop.responseOrSomethingElse(doc)
	//}
}
