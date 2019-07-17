
/**
 * function - IIFE to create vega deafults object (may be modified)
 */ 
(function() {
    'use strict';
    window.VEGA_DEFAULTS = {
        "defaultStyle":true,
        "renderer":"svg",
        "actions":{
            "export":true, 
            "source":false, 
            "compiled":false, 
            "editor":false
        }
    }
}());
