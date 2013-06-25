/** 
* @class solgs
* general solGS app wide functions
* @author Isaak Y Tecle <iyt2@cornell.edu>
*
*/


JSAN.use('jquery.blockUI');
JSAN.use('jquery');

var solGS = {
             
    waitPage: function() 
    {                    
        jQuery.blockUI.defaults.applyPlatformOpacityRules = false;
        jQuery.blockUI({message: 'Please wait..'});
         

        jQuery(window).unload(function()  {
                jQuery.unblockUI();            
            });
    }, 
                         
///////
}
////
