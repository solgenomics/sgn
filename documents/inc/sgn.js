var docroot = '/';


// Toggles the layer visibility on 
function showLayer(layerName) { 
  document.getElementById(layerName).style.visibility="visible"; 
}

// Toggles the layer visibility off 
function hideLayer(layerName) { 
  document.getElementById(layerName).style.visibility = "hidden";
}

////////////////////////////////////
// cookie helper
////////////////////////////////////

function getCookie(name) {
    var dc = document.cookie;
    var prefix = name + "=";
    var begin = dc.indexOf("; " + prefix);
    if (begin == -1) {
        begin = dc.indexOf(prefix);
        if (begin != 0) return null;
    } else {
        begin += 2;
    }
    var end = document.cookie.indexOf(";", begin);
    if (end == -1) {
        end = dc.length;
    }
    return unescape(dc.substring(begin + prefix.length, end));
}

////////////////////////////////////////////////////////////
//   clone cart
////////////////////////////////////////////////////////////
function count_clones() 
{
    var n_clones=0;
    var p;
    var cookies;
    cookies=document.cookie;
    if(getCookie('CloneCart')!="") 
    {
        n_clones = 1;//first clone in cookie does not begin with a comma (fencepost problem)
        p+=1;
        while((p=cookies.indexOf(",",p))!=-1) 
        {
            p++;
            n_clones++;
        }
        document.write(n_clones);
    }
    else
    {
        document.write("No");
    }
}

function check_clonecart() 
{
    //if we are on the order routing page, hide cart
    if(document.URL.indexOf("route-order.pl")!=-1) 
    {
        hideLayer('clone_shoppingcart');
        return;
    }
    //if there is something in the cart, show cart
    if(getCookie('CloneCart')!="" && getCookie('CloneCart')!=null) 
    {
        showLayer('clone_shoppingcart');
        return;
    } 
    //otherwise, hide cart
    hideLayer('clone_shoppingcart');
    return;
}


//////////////////////////////////////////////////////////////////////
// page load indicator
//////////////////////////////////////////////////////////////////////
//turn spinning loady things on and off, set toolbar visible and
//invisible
function finishLoad() {
  var logo = document.getElementById('sgnlogo');
  logo.src = docroot + "documents/img/sgn_logo_icon.png";
}
function startLoad() {
  var logo1 = document.getElementById('sgnlogo');
  logo1.src=docroot + 'documents/img/sgn_logo_animated.gif';
}
/* remove loading messages and animations on page load*/

if(window.onload) {
   var old = window.onload;
   window.onload = function () { old(); finishLoad(); };
} else {
   window.onload=finishLoad;
}

