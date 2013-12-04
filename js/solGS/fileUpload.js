

jQuery(function () {
        var url = '/solgs/upload/prediction/genotypes';
        jQuery('#fileupload').fileupload({
                url: url,
                    dataType: 'json',
                    done: function (e, data) {
                    jQuery.each(data.result.files, function (index, file) {
                            jQuery('<p/>').text(file.name).appendTo(document.body);
                        });
                }
            });
    });
        













