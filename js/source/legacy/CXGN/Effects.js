/** 

=head1 CXGN.Effects

 Visual effects handler.  We will want to sub-class this heavily, as there will exist a myriad of effects. Singleton object.

 Exports object 'Effects' to window namespace

=head1 Author

 Chris Carpita <csc32@cornell.edu>

=cut

*/

JSAN.use("MochiKit.Logging");

var Effects = {
	//Here's an example of a function which should exist in a subclass:
	switchHotlistButton: function(buttonId, switchTo, content, clearOnClick){
		var button = document.getElementById(buttonId);
		var imgAdd = document.getElementById(buttonId + ":imgAdd");
		var imgRemove = document.getElementById(buttonId + ":imgRemove");
	
		var optionalText = "All AGIs on this Page ";
		if(!content.match(/:/)) {optionalText = "";}
		if(switchTo == 'remove'){  
			imgAdd.style.display = "none";
			imgRemove.style.display = "inline";
			button.firstChild.nodeValue = "Remove " + optionalText + "from Hotlist";
			if(clearOnClick){
				button.setAttribute("onClick", "alert('some')");
			}
			else {
				button.setAttribute("onClick", "Hotlist.remove('" + buttonId + "', '" + content + "'); return false;");
			}
		}
		else if (switchTo == 'add'){ 
			imgAdd.style.display = "inline";
			imgRemove.style.display = "none";
			button.firstChild.nodeValue = "Add " + optionalText + "to Hotlist";
			if(clearOnClick){
				button.setAttribute("onClick", "alert('some')");
			}
			else {
				button.setAttribute("onClick", "Hotlist.add('" + buttonId + "', '" + content + "'); return false;");
			}
		}
		else { alert("You sent a bad switchTo variable to switchHotlistButton"); }
	},
	//These, on the other hand, are generic and belong in CXGN.Effects:
	showElement: function(elementId, displayMethod) {
		var element = document.getElementById(elementId);
		var dispMethod;
		if(displayMethod) {
			dispMethod = displayMethod;
		}
		else { dispMethod = "inline"; }
		element.style.display = dispMethod;
	},
	hideElement: function(elementId, displayMethod) {
		var element = document.getElementById(elementId);
		var dispMethod = "";
		if(displayMethod) {
			dispMethod = displayMethod;
		}
		else { dispMethod = "none"; } //alternative is "hidden", which causes it to continue occupying space on the page
		element.style.display = dispMethod;
	},
	swapElements: function(elementIdFrom, elementIdTo, displayMethod){
		try {	
			var dispMethod = displayMethod || "inline";
			var elementFrom = document.getElementById(elementIdFrom);
			var elementTo = document.getElementById(elementIdTo);
			elementFrom.style.display = "none";
			elementTo.style.display = dispMethod;
		}
		catch(e) { MochiKit.Logging.logError("CXGN.Effects.swapElements: " + e); }
	}
};


