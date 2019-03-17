/**

=head1 CXGN.Calendar

 Simplified handler for Dynarch.Calendar.  The actual Dynarch Calendar will be exported to
 the namespace as 'Calendar', whereas this module will be exported as CXGN.Calendar.

 Most of the handlers were adapted from the Dynarch demo, although some modifications have
 been made in order to use our own default options, which can be found at the top of
 the object specification.

=head1 Author

 Chris Carpita <ccarpita@gmail.com>

=cut

*/

JSAN.use('Dynarch.Calendar');


var CXGN = window.CXGN || {};
CXGN.Calendar = {
/**

=head1 Properties

 Universal Options
 *stylesheet: Name of stylesheet to import by default
 *stylesheetId: Id of link statement in document to stylesheet
 *format: default date format that calendar will return

 Options for pop-up calendars:
 *closeOnSelected:  close pop-up when a date is clicked, true/false

 Options for non pop-up calendars:
 *flatTargetId: Element to change on flat calendar selection
 *flatCalendarId: Element that encapsulates flat (static) calendar
 *flatDayLimit: # of days within current date that are enabled.

=cut

*/
	stylesheet: "brown",
	stylesheetId: "dynarch_calendar_stylesheet",	
	format: "%m/%d/%Y",
	weekNumbers: false,

	//popup calendar options
    closeOnSelect: true, 

	//flat calendar options
	flatTargetId: "dynarch_flat_target",
	flatCalendarId: "dynarch_flat_calendar",
	flatDayLimit: 30,

	_init: function() {
		CXGN.Calendar.importStylesheet();
	},

/**

=head1 Methods

 The following methods are called as: CXGN.Calendar.method();


=head2 importStylesheet(name)

 Create a link to the stylesheet in the DOM, if the Id
 in CXGN.Calendar.stylesheetId is not present.

 Name refers to the stylesheet, default is CXGN.Calendar.stylesheet

=cut

*/
	importStylesheet: function (name) {
		var existing = document.getElementById(CXGN.Calendar.stylesheetId);
		if(existing && existing.rel) return;
		if(!name) name = CXGN.Calendar.stylesheet;
		if(!/\.css$/.test(name)) name += ".css";
		var linkElem = document.createElement("link");
		linkElem.id = CXGN.Calendar.stylesheetId;
		linkElem.type = "text/css";
		linkElem.rel = "stylesheet";
		linkElem.media = "all";
		linkElem.href = "js/Dynarch/style/" + name;
		document.getElementsByTagName('head')[0].appendChild(linkElem);
	},
	setupCalendar: function(cal) {
		var forward = ["weekNumbers"];
		for(var i = 0; i < forward.length; i++){
			cal[forward[i]] = CXGN.Calendar[forward[i]];
		}
	},
/*

=head2 popupDateSelected(cal obj, date)

 Called when a date is selected, added as event handler automatically

=cut

*/
	popupDateSelected: function (cal, date) {
	  cal.sel.value = date; // just update the date in the input field.
	  if(cal.dateClicked && CXGN.Calendar.closeOnSelect) cal.callCloseHandler();
	},
/*

=head2 popupCloseHandler(cal obj)

 This gets called when the end-user clicks on the _selected_ date,
 or clicks on the "Close" button.  It just hides the calendar without
 destroying it.

=cut

*/
	popupCloseHandler: function(cal) {
	  cal.hide();                       
	//  cal.destroy();
	  window._dynarch_popupCalendar = null;
	},
/*

=head2 showCalendar(id, format, showsTime, showsOtherMonths)

 This function shows the calendar under the element having the given id.
 It takes care of catching "mousedown" signals on document and hiding the
 calendar if the click was outside.

 The variable format is a date-format string, like "%m/%d/%Y", which will 
 show up as the form input when a date is selected. To learn about formatting,
 Google "man strftime", or see if there is a manpage on your system.

 showsTime can be boolean, or will show 24-hour format if equal to '24'

 showsOtherMonths is a boolean that allows display of alternate months

=cut

*/
	showCalendar: function (id, format, showsTime, showsOtherMonths) {
		var el = document.getElementById(id);
		if (window._dynarch_popupCalendar != null) {
		    // we already have some calendar created
			window._dynarch_popupCalendar.hide();  
		} 
		else {
		    // first-time call, create the calendar.
		    var cal = new Calendar ( 1, null, 
				CXGN.Calendar.popupDateSelected, 
				CXGN.Calendar.popupCloseHandler );
			CXGN.Calendar.setupCalendar(cal);
		    // uncomment the following line to hide the week numbers
		    // cal.weekNumbers = false;
		    if (showsTime) {
		      cal.showsTime = true;
		      cal.time24 = (showsTime == "24");
		    }
		    if (showsOtherMonths) {
		      cal.showsOtherMonths = true;
		    }
		    window._dynarch_popupCalendar = cal;                  // remember it in the global var
		    cal.setRange(1900, 2070);        // min/max year allowed.
		    cal.create();
		}
		if(!format) format = CXGN.Calendar.format;
		window._dynarch_popupCalendar.setDateFormat(format);    // set the specified date format
		window._dynarch_popupCalendar.parseDate(el.value);      // try to parse the text in field
		window._dynarch_popupCalendar.sel = el;                 // inform it what input field we use
	
	  // the reference element that we pass to showAtElement is the button that
	  // triggers the calendar.  In this example we align the calendar bottom-right
	  // to the button.
//	  	window._dynarch_popupCalendar.showAtElement(el.nextSibling, "Br");        // show the calendar
		window._dynarch_popupCalendar.showAtElement(el, "Br");
		return false;
	},
/*

=head2 flatIsDisabled(date)

 Given a date, determine which days are disabled, from CXGN.Calendar.flatDayLimit

=cut

*/
	flatIsDisabled: function (date) {
		var today = new Date();
		return 
			( Math.abs(date.getTime() - today.getTime() ) 
			  / 
			  ( 60*1000*60*24 )  //number  of days difference
			   > CXGN.Calendar.flatDayLimit);
	},
/*

=head2 flatDateSelected(cal, date)

 Action for selection of flat-calendar date

=cut

*/
	flatDateSelected: function(cal, date) {
		var el = document.getElementById(CXGN.Calendar.flatTargetId);
		el.innerHTML = date;
	},
/*

=head2 showFlatCalendar([format])

 Shows the flat (non-popup) calendar in the document, under
 the element with ID CXGN.Calendar.flatCalendarId

 Variable format defaults to '%m/%d/%Y', which will fill the
 innerHTML of element with id CXGN.Calendar.flatTargetId 

*/
	showFlatCalendar: function(format) {
		var parent = document.getElementById(CXGN.Calendar.flatCalendarId);
		
		// construct a calendar giving only the "selected" handler.
		var cal = new Calendar(0, null, CXGN.Calendar.flatDateSelected);
		CXGN.Calendar.setupCalendar(cal);
	
		// We want some dates to be disabled; see function isDisabled above
		cal.setDisabledHandler(CXGN.Calendar.flatIsDisabled);
		if(!format) format = CXGN.Calendar.format;
		cal.setDateFormat(format);
	
		// this call must be the last as it might use data initialized above; if
		// we specify a parent, as opposite to the "showCalendar" function above,
		// then we create a flat calendar -- not popup.  Hidden, though, but...
		cal.create(parent);
	
		// ... we can show it here.
		cal.show();
	}
}
CXGN.Calendar._init();
