//<!-- Copyright 2006,2007 Bontrager Connection, LLC
// http://bontragerconnection.com/ and http://willmaster.com/
// Version: July 28, 2007

var cX = 0; 
var cY = 0; 
var rX = 0; 
var rY = 0;

function UpdateCursorPosition(e){ cX = e.pageX; cY = e.pageY;}

function UpdateCursorPositionDocAll(e){ cX = event.clientX; cY = event.clientY;}

if(document.all) { document.onmousemove = UpdateCursorPositionDocAll; }
else { document.onmousemove = UpdateCursorPosition; }

function AssignPosition(d) {
if(self.pageYOffset) {
rX = self.pageXOffset;
rY = self.pageYOffset;
}
else if(document.documentElement && document.documentElement.scrollTop) {
rX = document.documentElement.scrollLeft;
rY = document.documentElement.scrollTop;
}
else if(document.body) {
rX = document.body.scrollLeft;
rY = document.body.scrollTop;
}
if(document.all) {
cX += rX;
cY += rY;
}
d.style.left = (cX+10) + "px";
d.style.top = (cY+10) + "px";
}
//-------------------------------- END OF Bontrager Connection CODE---------------------


function showPopUp(table_id,content,title)
{
  var  hp = document.getElementById(table_id);
  document.getElementById('org_content').innerHTML=content;
  document.getElementById('org_title').innerHTML=title;
  AssignPosition(hp);
  hp.style.visibility="visible";
}
 
function hidePopUp(id){

var    hp = document.getElementById(id);
       hp.style.visibility = "hidden";
}
