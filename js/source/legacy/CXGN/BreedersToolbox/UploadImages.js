
jQuery( document ).ready( function() {

    jQuery('#upload_images_submit_verify').click( function() {
        jQuery('#working_modal').modal("show");
        var imageFiles = document.getElementById('upload_images_file_input').files;
        if (imageFiles.length < 1) {
            alert("Please select image files");
        }
        else {
            var fileData = parseImageFiles(imageFiles);
            var observationUnitNames = Object.values(fileData).map(function(value) {
                return value.observationUnitName;
            });
            var message_text = "<hr><ul class='list-group'>";
            jQuery.ajax( {
                url: "/list/array/transform",
                method: 'GET',
                data: {
                    "array": JSON.stringify(observationUnitNames),
                    "type": "stocks_2_stock_ids"
                }
            }).done(function(response) {
                console.log(JSON.stringify(response));
                if (response.missing.length > 0) {
                    jQuery('#upload_images_submit_store').attr('disabled', true);
                    for (var i = 0; i < response.missing.length; i++) {
                        message_text += "<li class='list-group-item list-group-item-danger'>";
                        message_text += "<span class='badge'><span class='glyphicon glyphicon-remove'></span></span>";
                        message_text += response.missing[i] + " is not a valid observationUnitName";
                        message_text += "</li>";
                    }
                } else {
                    jQuery('#upload_images_submit_store').attr('disabled', false);
                    message_text += "<li class='list-group-item list-group-item-success'>";
                    message_text += "<span class='badge'><span class='glyphicon glyphicon-ok'></span></span>";
                    message_text += "Successfully matched all image files to existing observationUnit names. Ready to store images.</li>";
                }
            }).fail(function(error){
                jQuery('#upload_images_submit_store').attr('disabled', true);
                message_text += "<li class='list-group-item list-group-item-danger'>";
                message_text += "<span class='badge'><span class='glyphicon glyphicon-remove'></span></span>";
                message_text += error;
                message_text += "</li>";
            }).always(function(){
                message_text += "</ul>";
                jQuery('#upload_images_status').html(message_text);
                jQuery('#working_modal').modal("hide");
            });
        }
    });

    jQuery('#upload_images_submit_store').click( function() {
        var imageFiles = document.getElementById('upload_images_file_input').files;
        var currentImage = 0;
        jQuery('#progress_msg').text('Preparing images for upload');
        jQuery('#progress_bar').css("width", currentImage + "%")
        .attr("aria-valuenow", currentImage)
        .text(Math.round(currentImage) + "%");
        jQuery('#progress_modal').modal('show');

        var fileData = parseImageFiles(imageFiles);
        var observationUnitNames = Object.values(fileData).map(function(value) {
            return value.observationUnitName;
        });

        jQuery.ajax( {
            url: "/list/array/transform",
            method: 'GET',
            data: {
                "array": JSON.stringify(observationUnitNames),
                "type": "stocks_2_stock_ids"
            }
        }).done(function(response) {

            var observationUnitDbIds = response.transform;
            var imageData = Object.values(fileData).map(function(value, i) {
                value.observationUnitDbId = observationUnitDbIds[i];
                return value;
            });
            var result = loadImagesSequentially(imageFiles, imageData, currentImage);
            // handle success/error

        });
    });
});


function showImagePreview() {
    var imageFiles = document.getElementById('upload_images_file_input').files;
    var file = imageFiles[0];
    var restCount = imageFiles.length - 1;
    var preview = document.getElementById("preview");
    preview.innerHTML = "";

    // for (var i = 0; i < imageFiles.length; i++) {
    //     var file = imageFiles[i];
    var reader = new FileReader();
    reader.onload = function(readerEvent) {
        var imagePreview = document.createElement("div");
        imagePreview.className = "col-sm-4";
        imagePreview.innerHTML = "<img class='img-responsive' src='" + readerEvent.target.result + "' />";
        preview.append(imagePreview);
        var previewText = document.createElement("div");
        previewText.className = "col-sm-8";
        previewText.innerHTML =
        '<p class="font-weight-bold text-center"><b>'+file.name+'</b></p><br>' +
        '<p class="text-center">and '+restCount+' additional image files selected and ready for verification.</p>';
        preview.append(previewText);
    }
    reader.readAsDataURL(file);




    // }
}


function parseImageFiles(imageFiles) {
    // extract observationUnitNames from image filenames
    // e.g. 21BEDS0809HCRH02_25_809_Covington_G3_RootPhoto1_1_2021-05-13-04-50-36
    var fileData = {};
    for (var i = 0; i < imageFiles.length; i++) {
        var file = imageFiles[i];
        var name = file.name;
        var timestamp = name.substring(name.lastIndexOf('_') + 1);
        var timestampWithoutExtension = timestamp.substr(0, timestamp.lastIndexOf('.'));
        var nameWithoutTimestamp = name.substring(0, name.lastIndexOf('_'));
        var nameWithoutNumber = nameWithoutTimestamp.substring(0, nameWithoutTimestamp.lastIndexOf('_'));
        var justUnitName = nameWithoutNumber.substring(0, nameWithoutNumber.lastIndexOf('_'));
        fileData[file.name] = {
            "imageFileName" : file.name,
            "imageFileSize" : file.size,
            "imageTimeStamp" : timestampWithoutExtension,
            // "imageURL" : imageURL,
            "mimeType" : file.type,
            "observationUnitName" : justUnitName
        };
        // console.log("Image data is: "+JSON.stringify(fileData));
    }
    return fileData;
}


function loadImagesSequentially(imageFiles, imageData, currentImage){
    // if(uploadInfo.error) {
    //     return {"error" : uploadInfo.error};
    // }
    if(currentImage == imageFiles.length) {
        console.log("Image number "+currentImage+" matched number of files "+imageFiles.length);
        // return {"success" : "All "+imageTotal+" images successfully uploaded."};
        jQuery('#progress_modal').modal('hide');
        return jQuery.Deferred().resolve().promise();
    }

    var total = imageFiles.length;
    var file = imageFiles[currentImage];
    var image = imageData[currentImage];
    console.log("Image number before bumping: "+currentImage);
    currentImage++;
    console.log("Image number after bumping: "+currentImage);
    // update progress bar
    jQuery('#progress_msg').html('<p class="form-group text-center">Working on image '+currentImage+' out of '+total+'</p>');
    jQuery('#progress_msg').append('<p class="form-group text-center"><b>'+image.imageFileName+'</b></p>')
    var progress = (currentImage / total) * 100;
    jQuery('#progress_bar').css("width", progress + "%")
    .attr("aria-valuenow", progress)
    .text(Math.round(progress) + "%");

    return jQuery.ajax( {
        url: "/brapi/v2/images",
        method: 'POST',
        headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
        data: JSON.stringify([image]),
        contentType: "application/json; charset=utf-8",
    }).done(function(response){
        console.log("Success uploading image metadata: "+image.imageFileName+" with details: "+JSON.stringify(response));
        var imageDbId = response.result.data[0].imageDbId;
        jQuery.ajax( {
            url: "/brapi/v2/images/"+imageDbId+"/imagecontent",
            method: 'PUT',
            async: false,
            headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
            data: file,
            processData: false,
            contentType: file.type
        }).done(function(response){
            console.log("Success uploading image content: "+image.imageFileName+" with details: "+JSON.stringify(response));
        }).fail(function(error){
            console.log("error: "+JSON.stringify(error));
            jQuery.Deferred().resolve().promise();
        });
    }).fail(function(error){
        // uploadInfo.error = error;
        // sequentialImageSubmit(imageArray, uploadInfo);
        console.log("error: "+JSON.stringify(error));
        return jQuery.Deferred().resolve().promise();
    }).then(function() {
        return loadImagesSequentially(imageFiles, imageData, currentImage);
    });
}
