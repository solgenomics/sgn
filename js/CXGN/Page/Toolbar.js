/** 
* @class Toolbar
* Functions used with the perl module of the same name
* @author Robert Buels <rmb32@cornell.edu>
*
*/

var CXGN;
if(!CXGN) CXGN = {};
if(!CXGN.Page) CXGN.Page = {};
if(!CXGN.Page.Toolbar)
  CXGN.Page.Toolbar = {
    timerID: null,
    timerOn: false,
    timecount: 400,
    menulist: new Array()
  };

CXGN.Page.Toolbar.showmenu = function(menu) {
  CXGN.Page.Toolbar.hideall();
  document.getElementById(menu).style.visibility = "visible";
  CXGN.Page.Toolbar.stopTime();
};

CXGN.Page.Toolbar.hidemenu = function() {
  CXGN.Page.Toolbar.startTime();
};

CXGN.Page.Toolbar.addmenu = function(menu) {
  CXGN.Page.Toolbar.menulist[CXGN.Page.Toolbar.menulist.length] = menu;
};

CXGN.Page.Toolbar.startTime = function() { 
  if (CXGN.Page.Toolbar.timerOn == false) { 
    CXGN.Page.Toolbar.timerID = setTimeout( "CXGN.Page.Toolbar.hideall()" , CXGN.Page.Toolbar.timecount); 
    CXGN.Page.Toolbar.timerOn = true; 
  } 
}

CXGN.Page.Toolbar.stopTime = function() { 
  if (CXGN.Page.Toolbar.timerOn == true) { 
    clearTimeout(CXGN.Page.Toolbar.timerID); 
    CXGN.Page.Toolbar.timerID = null; 
    CXGN.Page.Toolbar.timerOn = false; 
  } 
};

CXGN.Page.Toolbar.hideall = function() {
  for(var i=0; i<CXGN.Page.Toolbar.menulist.length; i++) {
    document.getElementById(CXGN.Page.Toolbar.menulist[i]).style.visibility = "hidden";
  }
};

