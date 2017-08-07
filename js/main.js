    var k = jQuery.noConflict();
     jQuery(function () {
         jsKeyboard.init("virtualKeyboard");

         //first input focus
         var $firstInput = k(':input').first().focus();
         jsKeyboard.currentElement = $firstInput;
         jsKeyboard.currentElementCursorPosition = 0;
     });
