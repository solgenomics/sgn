/** 
* @fileoverview This file has been modified for ease of use.  Please download the original from
* http://www.jaaulde.com/test_bed/cookieLib/ for the original (and latest) versions.
*  
* @author James Auldridge,  Copyright (c) 2005
* @version 1.2
*/

/**
* A singleton Cookie-handling object
* @class Cookie
* Methods: get, set, del, test
*/

JSAN.use("MochiKit.Logging");

var Cookie = window.Cookie || {};
Cookie = {
	get: function(cookieName) {
		var cookieNameStart,valueStart,valueEnd,value;
		cookieNameStart = document.cookie.indexOf(cookieName+'=');
		if (cookieNameStart < 0) {return null;}
		valueStart = document.cookie.indexOf(cookieName+'=') + cookieName.length + 1;
		valueEnd = document.cookie.indexOf(";",valueStart);
		if (valueEnd == -1){valueEnd = document.cookie.length;}
		value = document.cookie.substring(valueStart,valueEnd );
		value = unescape(value);
		if (value == "") {return null;}
		return value;
	},
	set: function(cookieName,value,hoursToLive,path,domain,secure) {
		var domainRegEx = /[^.]+\.[^.]+$/;
		domain = window.location.hostname.match(domainRegEx);
		if(domain == 'cornell.edu') domain = 'sgn.cornell.edu';
		var expireString,timerObj,expireAt,pathString,domainString,secureString,setCookieString;
		if (!hoursToLive || typeof hoursToLive != 'number' || parseInt(hoursToLive)=='NaN'){
			expireString = "";
		}
		else {
			timerObj = new Date();
			timerObj.setTime(timerObj.getTime()+(parseInt(hoursToLive)*60*60*1000));
			expireAt = timerObj.toGMTString();
			expireString = "; expires="+expireAt;
		}
		pathString = "; path=";
		(!path || path=="") ? pathString += "/" : pathString += path;
		domainString = "; domain=";
		if(!domain || domain==""){
			domain = window.location.hostname;
		}
//		if(domain=="localhost") domain = "localhost.localdomain";
		domainString += domain;

		(secure === true) ? secureString = "; secure" : secureString = "";
		value = escape(value);
		setCookieString = cookieName+"="+value+expireString+pathString+domainString;
		document.cookie = setCookieString;
	},
	del: function(cookieName,path,domain){
          (!path || !path.length) ? path="" : path=path;
          (!domain || !domain.length) ? domain="" : domain=domain;
		Cookie.set(cookieName,"",-8760,path,domain);
	},
	test: function(){
		Cookie.set('cT','acc');
		var runTest = Cookie.get('cT');
		if (runTest == 'acc'){
			Cookie.del('cT');
			testStatus = true;
		}
		else {
			testStatus = false;
		}
		return testStatus;
	}
};

var test = Cookie.test();
if(test){
	MochiKit.Logging.logDebug("Javascript Cookie Setting: Works!");
}
else {
	MochiKit.Logging.logError("Javascript Cookie Setting: Failed."); 
	var hn = window.location.hostname;
	if(!/\./.test(hn)){
		MochiKit.Logging.log(
			"Cookie failure: You appear to be using a one-word hostname (" + hn + ") without a domain, " +
			"which won't work with cookies.  Try using something like " +
			"localhost.localdomain, and set /etc/hosts accordingly");
	}
}
