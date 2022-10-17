JSAN.use('jquery');

jQuery( function() {
	var sfEls = document.getElementById("icon_nav").getElementsByTagName("LI");
	for (var i=0; i<sfEls.length; i++) {
		sfEls[i].onmouseover=function() {
			this.className += " sfhover";
		}
		sfEls[i].onmouseout=function() {
			this.className = this.className.replace(new RegExp(" sfhover\\b"), "");
		}
	}
});

// for IE below 8, screw up lots of z-Indexes to work around the
// z-Index bug
//if( jQuery.browser.msie && jQuery.browser.version < 8 ) {
//  jQuery( function() {
//            var zIndexNumber = 1000;
//            jQuery('#siteheader div, #icon_nav div, #icon_nav li, #icon_nav ul')
//              .each( function() {
//                       jQuery(this).css('zIndex', zIndexNumber);
//                       zIndexNumber -= 10;
//                     });
//          });

//}
