function gbTurnOff (a) {
  if (document.getElementById(a+"_a")) { document.getElementById(a+"_a").checked='' };
  if (document.getElementById(a+"_n")) { document.getElementById(a+"_n").checked='' };
}

function gbCheck (button,state) {
  var a         = button.id;
  a             = a.substring(0,a.lastIndexOf("_"));
  var container = document.getElementById(a);
  if (!container) { return false; }
  var checkboxes = container.getElementsByTagName('input');
  if (!checkboxes) { return false; }
  for (var i=0; i<checkboxes.length; i++)
     checkboxes[i].checked=state;
  gbTurnOff(a);
  button.checked="on";
  return false;
}
