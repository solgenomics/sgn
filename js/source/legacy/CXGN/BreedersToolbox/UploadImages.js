
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
                    message_text += "Successfully matched all images to existing observationUnit names. Ready to store images.</li>";
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
        var imageData = [];
        var errors = [];
        jQuery('#progress_modal').modal('show');
        jQuery('#progress_msg').text('Preparing images for upload');

        var fileData = parseImageFiles(imageFiles);
        var observationUnitNames = Object.values(fileData).map(function(value) {
            return value.observationUnitName;
        });

        jQuery.ajax( {
            url: "/list/array/transform",
            method: 'GET',
            beforeSend: jQuery('#progress_modal').modal('show'),
            data: {
                "array": JSON.stringify(observationUnitNames),
                "type": "stocks_2_stock_ids"
            }
        }).done(function(response) {
            console.log(JSON.stringify(response));
            var observationUnitDbIds = response.transform;
            imageData = Object.values(fileData).map(function(value, i) {
                value.observationUnitDbId = observationUnitDbIds[i];
                return value;
            });
        }).then(function() {
            for (var i = 0; i < imageFiles.length; i++) {
                console.log("Working on image number "+i);
                var file = imageFiles[i];
                var imageDbId;
                var reader = new FileReader();
                reader.onload = function(readerEvent) {
                    var listItem = document.createElement("li");
                    listItem.className = "list-group list-group-horizontal col-sm-3";
                    var imageDatum = imageData.shift();
                    var imageURL = readerEvent.target.result;
                    imageDatum.imageURL = imageURL;
                    listItem.innerHTML = "<img class='img-responsive' src='" + imageURL + "' />";
                    // jQuery('#current_task').html(listItem);
                    // jQuery('#progress_msg').text('Submitting image '+i+' out of '+imageFiles.length+' images');
                    // var progress = ((i + 1) / imageFiles.length) * 100;
                    // jQuery('#progress_bar').css("width", progress + "%")
                    // .attr("aria-valuenow", progress)
                    // .text(Math.round(progress) + "%");

                    jQuery.ajax( {
                        url: "/brapi/v2/images",
                        method: 'POST',
                        async: false,
                        headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
                        data: JSON.stringify([imageDatum]),
                        contentType: "application/json; charset=utf-8",
                    }).done(function(response){
                        imageDbId = response.result.data[0].imageDbId;

                    }).then(function() {

                        // PUT Image Content
                        jQuery('#current_task').html(listItem);
                        jQuery('#progress_msg').text('Submitting image '+i+' out of '+imageFiles.length+' images');
                        var progress = ((i + 1) / (imageFiles.length + 1)) * 100;
                        jQuery('#progress_bar').css("width", progress + "%")
                        .attr("aria-valuenow", progress)
                        .text(Math.round(progress) + "%");
                        console.log("ImageDbId is "+imageDbId);
                        jQuery.ajax( {
                            url: "/brapi/v2/images/"+imageDbId+"/imagecontent",
                            method: 'PUT',
                            async: false,
                            headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
                            data: file,
                            processData: false,
                            contentType: file.type
                        }).done(function(response){
                            console.log("Success uploading image: "+imageDatum.imageFileName+" with details: "+JSON.stringify(response));
                        }).fail(function(error){
                            console.log("error: "+JSON.stringify(error));
                            errors.push(error);
                        });
                    }).fail(function(error){
                        console.log("error: "+JSON.stringify(error));
                        errors.push(error);
                    });

                }
                reader.readAsDataURL(file);
            }
            var message_text = "<hr><ul class='list-group'>";
            if (errors.length) {
                for (var i = 0; i < errors.length; i++) {
                    message_text += "<li class='list-group-item list-group-item-danger'>";
                    message_text += "<span class='badge'><span class='glyphicon glyphicon-remove'></span></span>";
                    message_text += errors[i];
                    message_text += "</li>";
                }
            } else {
                message_text += "<li class='list-group-item list-group-item-success'>";
                message_text += "<span class='badge'><span class='glyphicon glyphicon-ok'></span></span>";
                message_text += "All images successfully uploaded!</li>";

            }
            jQuery('#upload_images_status').html(message_text);
        });
        jQuery('#progress_modal').modal('hide');
    });
});

            // for (var i = 0; i < imageFiles.length; i++) {
            //     var file = imageFiles[i];
            //     var imageURL;
            //     var reader = new FileReader();
            //     reader.onload = function(readerEvent) {
            //       var listItem = document.createElement("li");
            //       listItem.className = "list-group list-group-horizontal col-sm-3";
            //       imageURL = readerEvent.target.result;
            //       console.log("Image url is: "+imageURL);
            //       listItem.innerHTML = "<img class='img-responsive' src='" + imageURL + "' />";
            //       preview.append(listItem);
            //     }
            //     reader.readAsDataURL(file);
            //     console.log(imageURL);
            //     var name = file.name;
            //     // var size = file.size;
            //     // var type = file.type;
            //     // console.log("Processing file "+name+" with size "+size+" and type "+type);
            //     var timestamp = name.substring(name.lastIndexOf('_') + 1);
            //     var timestampWithoutExtension = timestamp.substr(0, timestamp.lastIndexOf('.'));
            //     var nameWithoutTimestamp = name.substring(0, name.lastIndexOf('_'));
            //     var nameWithoutNumber = nameWithoutTimestamp.substring(0, nameWithoutTimestamp.lastIndexOf('_'));
            //     var justUnitName = nameWithoutNumber.substring(0, nameWithoutNumber.lastIndexOf('_'));
            //     observationUnitNames.push(justUnitName);
            //     fileData.push({
            //         "imageFileName" : file.name,
            //         "imageFileSize" : file.size,
            //         "imageTimeStamp" : timestampWithoutExtension,
            //         "imageURL" : imageURL,
            //         "mimeType" : file.type
            //     });
            //     // console.log("Image data is: "+JSON.stringify(fileData));
            // }
            // console.log("Image data is: "+JSON.stringify(fileData));
            // // retrieve observationUnitIds from names
            // jQuery.ajax( {
            //     url: "/list/array/transform",
            //     method: 'GET',
            //     data: {
            //         "array": JSON.stringify(observationUnitNames),
            //         "type": "stocks_2_stock_ids"
            //     }
            // }).done(function(response) {
            //     console.log(JSON.stringify(response));
            //     var observationUnitDbIds = response.transform;
            //     // map images to obsunitids
            //     var imageData = fileData.map(function (file, i) {
            //         file.observationUnitDbId = observationUnitDbIds[i];
            //         return file;
            //     });
                // console.log("Image data is: "+JSON.stringify(imageData));
    //             recursively POST images and update progress bar
    //             sequentialImageSubmit(imageData, uploadInfo).done(function(upload) {
    //                 jQuery('#progress_modal').modal('hide');
    //
    //                 if (upload.success) {
    //                     jQuery('#upload_images_dialog').modal.find('.modal-body').append(
    //                         '<ul class="list-group"><li class="list-group-item list-group-item-success"><span class="badge"><span class="glyphicon glyphicon-remove"></span></span>'+upload.success+'</li></ul>'
    //                     );
    //                 } else if (upload.error) {
    //                     jQuery('#upload_images_dialog').modal.find('.modal-body').append(
    //                         '<ul class="list-group"><li class="list-group-item list-group-item-danger"><span class="badge"><span class="glyphicon glyphicon-remove"></span></span>'+upload.error+'</li></ul>'
    //                     );
    //                 }
    //             });
    //         }).fail(function(error){
    //             jQuery('#progress_modal').modal('hide');
    //             jQuery('#upload_images_dialog').modal.find('.modal-body').append(
    //                 '<ul class="list-group"><li class="list-group-item list-group-item-danger"><span class="badge"><span class="glyphicon glyphicon-remove"></span></span>Error matching images to valid observationUnitNames:'+error+'. Please fix and try again.</li></ul>'
    //             );
    //
    //         });
    //     }
    // });



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
// });

function showImagePreviews() {
    var imageFiles = document.getElementById('upload_images_file_input').files;
    var preview = document.getElementById("preview");

    for (var i = 0; i < imageFiles.length; i++) {
        var file = imageFiles[i];
        var reader = new FileReader();
        reader.onload = function(readerEvent) {
            var listItem = document.createElement("li");
            listItem.className = "list-group list-group-horizontal col-sm-3";
            listItem.innerHTML = "<img class='img-responsive' src='" + readerEvent.target.result + "' />";
            preview.append(listItem);
        }
        reader.readAsDataURL(file);
    }
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
        // observationUnitNames.push(justUnitName);
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

// function sequentialImageSubmit(imageArray, uploadInfo){
//     // if(uploadInfo.error) {
//     //     return {"error" : uploadInfo.error};
//     // }
//     if(imageArray.length == 0) {
//         // return {"success" : "All "+imageTotal+" images successfully uploaded."};
//         jQuery.Deferred().resolve().promise();
//     }
//
//     var image = imageArray.shift();
//     uploadInfo.currentImage++;
//     // update progress bar
//     jQuery('#progress_msg').text('Submitting image '+uploadInfo.currentImage+' out of '+uploadInfo.totalImages+' images');
//     var progress = ((uploadInfo.currentImage - 1) / uploadInfo.totalImages) * 100;
//     jQuery('#progress_bar').css("width", progress + "%")
//     .attr("aria-valuenow", progress)
//     .text(Math.round(progress) + "%");
//     // imageSubmit(image, imageArray, uploadInfo);
//
//     return jQuery.ajax( {
//         url: "/brapi/v2/images",
//         method: 'POST',
//         headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
//         data: JSON.stringify([image]),
//         contentType: "application/json; charset=utf-8",
//     }).done(function(response){
//         console.log("Success uploading image: "+image.imageFileName+" with details: "+JSON.stringify(response));
//     }).fail(function(error){
//         // uploadInfo.error = error;
//         // sequentialImageSubmit(imageArray, uploadInfo);
//         console.log("error: "+JSON.stringify(error));
//         jQuery.Deferred().resolve().promise();
//     }).then(function() {
//         return sequentialImageSubmit(imageArray, uploadInfo);
//     });;
//
// }
