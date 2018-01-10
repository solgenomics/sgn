     jQuery(function () {
         jsKeyboard.init("virtualKeyboard");

         //first input focus
         var $firstInput =jQuery(':input').first().focus();
         jsKeyboard.currentElement = $firstInput;
         jsKeyboard.currentElementCursorPosition = 0;
     });
