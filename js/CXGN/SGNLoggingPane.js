

JSAN.use('MochiKit.LoggingPane');

MochiKit.LoggingPane.LoggingPane.prototype.colorTable = {
    DEBUG: "#151",
    INFO: "black",
    WARNING: "blue",
    ERROR: "red",
    FATAL: "darkred"
};

JSAN.use('CXGN.Effects');

SGNLoggingPane = window.SGNLoggingPane || {};

SGNLoggingPane = {
	inline_create_link_id : 'MKLPinline_create',
	inline_destroy_link_id : 'MKLPinline_destroy',
	window_create_link_id: 'MKLPwindow_create',
	window_destroy_link_id: 'MKLPwindow_destroy',
	LP: '',
	
	create: function (inline) {
		var uid = '_MochiKit_LoggingPane';
		if(!inline){ //determine height of window
			var messages = MochiKit.Logging.logger.getMessages();
			var cr_count = 0;
			for(i = 0; i < messages.length; i++){
				var message = messages[i].info.join(" ");
				cr_count += message.search("\\n"); //count cr's in message
				cr_count++; //implicit cr for message
			}
			var height = cr_count*20; //20 pixels is approximate line-height?
			if(height<200) height=200;
			if(height>500) height=500;
			SGNLoggingPane.LP = MochiKit.LoggingPane.createLoggingPane(false, height);
			//Effects.swapElements(SGNLoggingPane.window_create_link_id, SGNLoggingPane.window_destroy_link_id);	
		}
		else { //Open an Inline Logging Pane
			SGNLoggingPane.LP = MochiKit.LoggingPane.createLoggingPane(true);
			
			//redefine closePane() to perform SGN-related tasks when the 
			//pane is closed using the native button
	 		SGNLoggingPane.LP.closePane = MochiKit.Base.bind(
				function () {
	        		if (this.closed) {
	            		return;
	        		}
			        this.closed = true;
			        if (MochiKit.LoggingPane._loggingPane == this) {
			            MochiKit.LoggingPane._loggingPane = null;
			        }
			        this.logger.removeListener(uid+'_Listener');
			        try {
			            try {
			              debugPane.loggingPane = null;
			            } 
						catch(e) { logFatal("Bookmarklet was closed incorrectly."); }
			            if (inline) {
			                debugPane.parentNode.removeChild(debugPane);

							//This is the stuff we added
							if(Effects){
								Effects.swapElements(SGNLoggingPane.inline_destroy_link_id, SGNLoggingPane.inline_create_link_id);
							}
							if(DeveloperSettings){
								DeveloperSettings.setValue('logging_pane_open', 0);
								DeveloperSettings.save();
							}
							////
			            
						} 
						else {
			                this.win.close();
			            }
			        } 
					catch(e) {
					}
		    	}, SGNLoggingPane.LP);
	
			var debugPane = window.document.getElementById(uid);
			var closeButton = debugPane.getElementsByTagName('button')[3];
			var divBody = debugPane.getElementsByTagName('div')[0];
			closeButton.onclick = SGNLoggingPane.LP.closePane;	

			if(Effects && typeof(Effects.swapElements) == "function"){
				Effects.swapElements(SGNLoggingPane.inline_create_link_id, SGNLoggingPane.inline_destroy_link_id);
			}
			if(DeveloperSettings){
				DeveloperSettings.setValue('logging_pane_open', 1);
				DeveloperSettings.save();
			}
		}
	
	},

	destroy: function () {
		SGNLoggingPane.LP.closePane();
		if(Effects && typeof(Effects.swapElements) == "function") {
			Effects.swapElements(SGNLoggingPane.inline_destroy_link_id, SGNLoggingPane.inline_create_link_id);
		//	Effects.swapElements(SGNLoggingPane.window_destroy_link_id, SGNLoggingPane.window_create_link_id);	
		}
		if(DeveloperSettings){
			DeveloperSettings.setValue('logging_pane_open', 0);
			DeveloperSettings.save();
		}
	},

	//redefine link handles:
	handles: function (ic, id, wc, wd) {
		if(ic){
			SGNLoggingPane.inline_create_link_id = ic;
		}
		if(id){
			SGNLoggingPane.inline_destroy_link_id = id;
		}
		if(wc){
			SGNLoggingPane.window_create_link_id = wc;
		}
		if(wd){
			SGNLoggingPane.window_destroy_link_id = wd;
		}
	}
}
