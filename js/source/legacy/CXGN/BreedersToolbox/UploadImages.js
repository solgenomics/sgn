
jQuery( document ).ready( function() {

    jQuery('#upload_images_submit_verify').click( function() {
        var uploadFormat = jQuery('#upload_images_file_format').val();
        var imageFiles = jQuery("#upload_images_file_input").prop('files');
        console.log(JSON.stringify(imageFiles));
        var phenotypeFile = jQuery("#upload_associated_phenotypes_file_input").val();
        var zipFile = jQuery('#upload_images_zip_file_input').val();

        if (uploadFormat == 'images_with_associated_phenotypes' && phenotypeFile === '') {
            alert('Please select a spreadsheet if you are using the Images with Associated Phenotypes format');
            return false;
        }
        else if (uploadFormat == 'images_with_associated_phenotypes' && zipFile === '') {
            alert("Please select a zipfile");
        }
        else if (uploadFormat == 'images' && imageFiles.length < 1) {
            alert("Please select image files");
        }
        else if (uploadFormat == 'images') {
            // var reader = new FileReader();
            var uploadInfo = {};
            uploadInfo.currentImage = 0;
            uploadInfo.totalImages = imageFiles.length;
            // jQuery('#progress_modal').modal('show');
            jQuery('#progress_msg').text('Preparing images for upload');

            // extract observationUnitNames from image filenames
            // e.g. 21BEDS0809HCRH02_25_809_Covington_G3_RootPhoto1_1_2021-05-13-04-50-36
            var preview = document.getElementById("preview");
            var fileData = [];
            var observationUnitNames = [];
            for (var i = 0; i < imageFiles.length; i++) {
                var file = imageFiles[i];
                var imageURL;
                var reader = new FileReader();
                reader.onload = function(readerEvent) {
                  var listItem = document.createElement("li");
                  imageURL = readerEvent.target.result;
                  console.log("Image url is: "+imageURL);
                  listItem.innerHTML = "<img class='img-responsive' src='" + imageURL + "' />";
                  preview.append(listItem);
                }
                reader.readAsDataURL(file);
                console.log(imageURL);
                var name = file.name;
                // var size = file.size;
                // var type = file.type;
                // console.log("Processing file "+name+" with size "+size+" and type "+type);
                var timestamp = name.substring(name.lastIndexOf('_') + 1);
                var timestampWithoutExtension = timestamp.substr(0, timestamp.lastIndexOf('.'));
                var nameWithoutTimestamp = name.substring(0, name.lastIndexOf('_'));
                var nameWithoutNumber = nameWithoutTimestamp.substring(0, nameWithoutTimestamp.lastIndexOf('_'));
                var justUnitName = nameWithoutNumber.substring(0, nameWithoutNumber.lastIndexOf('_'));
                observationUnitNames.push(justUnitName);
                fileData.push({
                    "imageFileName" : file.name,
                    "imageFileSize" : file.size,
                    "imageTimeStamp" : timestampWithoutExtension,
                    "imageURL" : imageURL,
                    "mimeType" : file.type
                });
                // console.log("Image data is: "+JSON.stringify(fileData));
            }
            console.log("Image data is: "+JSON.stringify(fileData));
            // retrieve observationUnitIds from names
            jQuery.ajax( {
                url: "/list/array/transform",
                method: 'GET',
                data: {
                    "array": JSON.stringify(observationUnitNames),
                    "type": "stocks_2_stock_ids"
                }
            }).done(function(response) {
                console.log(JSON.stringify(response));
                var observationUnitDbIds = response.transform;
                // map images to obsunitids
                var imageData = fileData.map(function (file, i) {
                    file.observationUnitDbId = observationUnitDbIds[i];
                    return file;
                });
                // console.log("Image data is: "+JSON.stringify(imageData));
                // recursively POST images and update progress bar
                // sequentialImageSubmit(imageData, uploadInfo).done(function(upload) {
                //     jQuery('#progress_modal').modal('hide');
                //
                //     if (upload.success) {
                //         jQuery('#upload_images_dialog').modal.find('.modal-body').append(
                //             '<ul class="list-group"><li class="list-group-item list-group-item-success"><span class="badge"><span class="glyphicon glyphicon-remove"></span></span>'+upload.success+'</li></ul>'
                //         );
                //     } else if (upload.error) {
                //         jQuery('#upload_images_dialog').modal.find('.modal-body').append(
                //             '<ul class="list-group"><li class="list-group-item list-group-item-danger"><span class="badge"><span class="glyphicon glyphicon-remove"></span></span>'+upload.error+'</li></ul>'
                //         );
                //     }
                // });
            }).fail(function(error){
                jQuery('#progress_modal').modal('hide');
                jQuery('#upload_images_dialog').modal.find('.modal-body').append(
                    '<ul class="list-group"><li class="list-group-item list-group-item-danger"><span class="badge"><span class="glyphicon glyphicon-remove"></span></span>Error matching images to valid observationUnitNames:'+error+'. Please fix and try again.</li></ul>'
                );

            });
        }
    });

    function sequentialImageSubmit(imageArray, uploadInfo){
        // if(uploadInfo.error) {
        //     return {"error" : uploadInfo.error};
        // }
        if(imageArray.length == 0) {
            // return {"success" : "All "+imageTotal+" images successfully uploaded."};
            jQuery.Deferred().resolve().promise();
        }

        var image = imageArray.shift();
        uploadInfo.currentImage++;
        // update progress bar
        jQuery('#progress_msg').text('Submitting image '+uploadInfo.currentImage+' out of '+uploadInfo.totalImages+' images');
        var progress = ((uploadInfo.currentImage - 1) / uploadInfo.totalImages) * 100;
        jQuery('#progress_bar').css("width", progress + "%")
        .attr("aria-valuenow", progress)
        .text(Math.round(progress) + "%");
        // imageSubmit(image, imageArray, uploadInfo);

        return jQuery.ajax( {
            url: "/brapi/v2/images",
            method: 'POST',
            headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
            data: JSON.stringify([image]),
            contentType: "application/json; charset=utf-8",
        }).done(function(response){
            console.log("Success uploading image: "+image.imageFileName+" with details: "+JSON.stringify(response));
        }).fail(function(error){
            // uploadInfo.error = error;
            // sequentialImageSubmit(imageArray, uploadInfo);
            console.log("error: "+JSON.stringify(error));
            jQuery.Deferred().resolve().promise();
        }).then(function() {
            return sequentialImageSubmit(imageArray, uploadInfo);
        });;

    }

    // function imageSubmit(image, imageArray, uploadInfo) {
    //     jQuery.ajax( {
    //         url: "brapi/v2/image",
    //         method: 'POST',
    //         headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
    //         data: image
    //     }).done(function(response){
    //         sequentialImageSubmit(imageArray, uploadInfo);
    //     }).fail(function(error){
    //         uploadInfo.error = error;
    //         sequentialImageSubmit(imageArray, uploadInfo);
    //     });
    // }
});
