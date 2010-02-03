// x_cook.js, X v3.15.3, Cross-Browser.com DHTML Library
// Copyright (c) 2004 Michael Foster, Licensed LGPL (gnu.org)

// cookie implementations based on code from Netscape Javascript Guide

function xSetCookie(name, value, expire, path)
{
  var cook = name + "=" + escape(value) +
                    ((!expire) ? "" : ("; expires=" + expire.toGMTString())) +
                    "; path=" + ((!path) ? "/" : path);
  document.cookie = cook;
}

function xGetCookie(name)
{
  var value=null, search=name+"=";
  if (document.cookie.length > 0) {
    var offset = document.cookie.indexOf(search);
    if (offset != -1) {
      offset += search.length;
      var end = document.cookie.indexOf(";", offset);
      if (end == -1) end = document.cookie.length;
      value = unescape(document.cookie.substring(offset, end));
    }
  }
  return value;
}

function xDeleteCookie(name, path)
{
  if (xGetCookie(name)) {
    document.cookie = name + "=" +
                    "; path=" + ((!path) ? "/" : path) +
                    "; expires=Thu, 01-Jan-70 00:00:01 GMT";
  }
}
