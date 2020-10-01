/** 
* @class CXGN.Effects.Hotlist
* Visual effects pertaining to Hotlist buttons
* @author Chris Carpita <csc32@cornell.edu>
*
*/
JSAN.use("CXGN.Base");
JSAN.use("CXGN.Effects");

Effects.Hotlist = {
	//Here's an example of a function which should exist in a subclass:
	switchButton: function(buttonId, switchToType, content, deactivate){

		var baseId = buttonId.match("[^:]+:[^:]+");
		var maxId = 0;
		while(document.getElementById(baseId + ":" + maxId)){
			maxId++;
		}
		maxId -= 1;
		if(maxId == -1) maxId = 0;
		//We just found the highest number of button for this particular content element
		//This allows you to make several hotlist buttons for one particular AGI on a given page ,
		//and all the buttons will be changed at once when you click just one of the buttons.
	
		var optionalText = "All AGIs on this Page ";
		if(!content.match(/:/)) optionalText = "";
		
		var iter = 0;
		while(iter <= maxId) {
			var button = document.getElementById(baseId + ":" + iter);
			var imgAdd = document.getElementById(baseId + ":" + iter + ":imgAdd");
			var imgRemove = document.getElementById(baseId + ":" + iter + ":imgRemove");
			iter++;
			if(switchToType == 'remove'){  
				imgAdd.style.display = "none";
				imgRemove.style.display = "inline";
				button.firstChild.nodeValue = "Remove " + optionalText + "from Hotlist";
				if(deactivate){
					button.setAttribute("onClick", "notify('Please Hold')");
				}
				else {
					button.setAttribute("onClick", "Hotlist.remove('" + buttonId + "', '" + content + "'); return false;");
				}
			}
			else if (switchToType == 'add'){ 
				imgAdd.style.display = "inline";
				imgRemove.style.display = "none";
				button.firstChild.nodeValue = "Add " + optionalText + "to Hotlist";
				if(deactivate){
					button.setAttribute("onClick", "notify('Please Hold')");
				}
				else {
					button.setAttribute("onClick", "Hotlist.add('" + buttonId + "', '" + content + "'); return false;");
				}
			}
			else { alert("You sent a bad switchTo variable to switchHotlistButton"); }
		}
	}
}


