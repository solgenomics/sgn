function showPopUp(hoveritem,id)
{
  var  hp = document.getElementById(id);

  hp.style.top = hoveritem.offsetTop+100;
  hp.style.left = hoveritem.offsetLeft+100;

       hp.style.visibility="visible";
}
 
function hidePopUp(id){

var    hp = document.getElementById(id);
       hp.style.visibility = "hidden";
}
