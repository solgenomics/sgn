
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
	var commentUiI18n = (window.SGN && window.SGN.i18n) || { p: function (context, source, variables) {
	    return source.replace(/%\{([^}]+)\}/g, function (match, name) { return variables && Object.prototype.hasOwnProperty.call(variables, name) ? String(variables[name]) : match; });
	} };
	commentdiv.textContent = commentUiI18n.p("global.comments.loading", "Please wait, checking for comments about %{type} %{id}", {type: thingtype, id: thingid});
	
 	if(!MochiKit.Async.doSimpleXMLHttpRequest) {
        alert(commentUiI18n.p("global.comments.simple_request_unavailable", "cannot do simple request"));
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
    localizeCommentCaptions(document.getElementById("commentsarea"));
    
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


// Translate only the known metadata captions after preserving the raw comment response.
function localizeCommentCaptions(root) {
    if (!root || !window.SGN || !SGN.i18n || SGN.i18n.locale === 'en') return;
    var captions = {
        title: SGN.i18n.p('community.people.user_comments', 'User comments'),
        empty: SGN.i18n.p("global.comments.empty", "None"),
        add: SGN.i18n.p('community.people.add_comment', '[Add comment]'),
        remove: SGN.i18n.p('community.people.delete', 'Delete'),
        anonymous: SGN.i18n.p('community.people.anonymous', 'anonymous'),
        postedBy: SGN.i18n.p('community.people.posted_by', 'Posted by '),
        postedOn: SGN.i18n.p('community.people.posted_on', ' on ')
    };
    if (captions.title === 'User comments' && captions.empty === 'None' && captions.add === '[Add comment]' &&
        captions.remove === 'Delete' && captions.anonymous === 'anonymous' &&
        captions.postedBy === 'Posted by ' && captions.postedOn === ' on ') return;
    function replaceText(node, source, target) {
        if (!node) return;
        for (var i = 0; i < node.childNodes.length; i++) {
            var child = node.childNodes[i];
            if (child.nodeType === 3 && child.nodeValue === source) child.nodeValue = target;
            else if (child.nodeType === 1) replaceText(child, source, target);
        }
    }
    var heading = root.querySelector('table.infosectionhead, table.infosectionhead_empty');
    if (heading) {
        replaceText(heading.querySelector('.infosectiontitle, .infosectiontitle_empty'), 'User comments', captions.title);
        var empty = heading.querySelector('.infosection_emptymessage');
        if (heading.classList.contains('infosectionhead_empty') && empty && !empty.children.length && empty.textContent === 'None') empty.textContent = captions.empty;
        var subtitle = heading.querySelector('.infosectionsubtitle, .infosectionsubtitle_empty');
        if (subtitle) Array.prototype.forEach.call(subtitle.querySelectorAll('a'), function (link) {
            if (/^\/forum\/add_post\.pl\?page_type=/.test(link.getAttribute('href') || '') &&
                !link.children.length && link.textContent === '[Add comment]') link.textContent = captions.add;
        });
    }
    Array.prototype.forEach.call(root.querySelectorAll('div.boxbgcolor2'), function (bar) {
        for (var parent = bar.parentNode; parent && parent !== root; parent = parent.parentNode) {
            if (parent.nodeType === 1 && parent.classList.contains('boxbgcolor5')) return;
        }
        var table = bar.firstElementChild;
        if (!table || table.tagName !== 'TABLE' || !table.rows.length || table.rows[0].cells.length !== 2) return;
        var meta = table.rows[0].cells[0];
        Array.prototype.forEach.call(meta.childNodes, function (node) {
            if (node.nodeType !== 3) return;
            if (node.nodeValue === 'Posted by ') node.nodeValue = captions.postedBy;
            else if (node.nodeValue.slice(0, 4) === ' on ') node.nodeValue = captions.postedOn + node.nodeValue.slice(4);
        });
        var poster = meta.querySelector('b');
        if (poster && !poster.children.length && poster.textContent === 'anonymous') poster.textContent = captions.anonymous;
        Array.prototype.forEach.call(table.rows[0].cells[1].querySelectorAll('a'), function (link) {
            if (/^\/forum\/forum_post_delete\.pl\?post_id=\d+(?:&|$)/.test(link.getAttribute('href') || '') &&
                !link.children.length && link.textContent === 'Delete') link.textContent = captions.remove;
        });
    });
}
