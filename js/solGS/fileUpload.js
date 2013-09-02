

//JSAN.use('flot.jquery');
//JSAN.use('jqueryfileupload.fileupload');
//JSAN.use('Prototype');

/*jslint unparam: true */
/*global window, $ */
jQuery(function () {
         'use strict';
         var url = '/solgs/upload/prediction/genotypes';
         jQuery('#fileupload').fileupload({
                     url: url,
                     dataType: 'json',
                     done: function (e, data) {
                     jQuery.each(data.result.files, function (index, file) {
                             jQuery('<p/>').text(file.name).appendTo('#files');
                         });
                 },
                     progressall: function (e, data) {
                     var progress = parseInt(data.loaded / data.total * 100, 10);
                     jQuery('#progress .progress-bar').css(
                                                           'width',
                                                           progress + '%'
                                                           );
                 }
             }).prop('disabled', !jQuery.support.fileInput)
             .parent().addClass(jQuery.support.fileInput ? undefined : 'disabled');
    });













