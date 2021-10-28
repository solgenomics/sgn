
jQuery( document ).ready( function() {

    document.getElementById('upload_images_file_input').addEventListener('input', function (e) {
        jQuery('#upload_images_status').html('');
        jQuery('#upload_images_submit_store').attr('disabled', true);
        showImagePreview(this.files);
    });


    jQuery('#upload_images_submit_verify').click( function() {
        jQuery('#working_modal').modal("show");
        var type = jQuery('#upload_images_file_format').val();
        if (type == 'images') {
            var imageFiles = document.getElementById('upload_images_file_input').files;
            if (imageFiles.length < 1) {
                jQuery('#working_modal').modal("hide");
                alert("Please select image files");
                return false;
            }
            var returnMessage = verifyImageFiles(imageFiles);
            if (returnMessage.error) {
                jQuery('#upload_images_submit_store').attr('disabled', true);
                jQuery('#upload_images_status').html(returnMessage.error);
            } else {
                jQuery('#upload_images_submit_store').attr('disabled', false);
                jQuery('#upload_images_status').html(returnMessage.success);
            }
        } else { //handle associated phenotypes

            var phenoFile =  document.getElementById('upload_associated_phenotypes_file_input').files[0];
            var zipFile =  document.getElementById('upload_images_zip_file_input').files[0];
            if (!(phenoFile instanceof File)) {
                jQuery('#working_modal').modal("hide");
                alert("Please select a phenotype spreadsheet");
                return false;
            } else if (!(zipFile instanceof File)) {
                jQuery('#working_modal').modal("hide");
                alert('Please select an image zipfile');
                return false;
            }
            var formData = new FormData();
            formData.append('upload_spreadsheet_phenotype_file_format', 'associated_images');
            formData.append('upload_spreadsheet_phenotype_file_input', phenoFile);
            formData.append('upload_spreadsheet_phenotype_associated_images_file_input', zipFile);
            var returnMessage;
            jQuery.ajax( {
                url: "/ajax/phenotype/upload_verify/spreadsheet",
                method: 'POST',
                async: false,
                data: formData,
                contentType: false,
                processData: false,
            }).done(function(response){
                if (response.success) {
                    returnMessage = formatMessage(response.success, 'success');
                    jQuery('#upload_images_submit_store').attr('disabled', false);
                    jQuery('#upload_images_status').html(returnMessage);
                } else if (response.error) {
                    returnMessage = formatMessage(response.error, 'error');
                    jQuery('#upload_images_submit_store').attr('disabled', true);
                    jQuery('#upload_images_status').html(returnMessage);
                }
            }).fail(function(error){
                returnMessage = formatMessage(error, 'error');
                jQuery('#upload_images_submit_store').attr('disabled', true);
                jQuery('#upload_images_status').html(returnMessage);
            });
        }

        jQuery('#working_modal').modal("hide");

    });


    jQuery('#upload_images_submit_store').click( function() {
        var imageFiles = document.getElementById('upload_images_file_input').files;
        var currentImage = 0;
        jQuery('#progress_msg').text('Preparing images for upload');
        jQuery('#progress_bar').css("width", currentImage + "%")
        .attr("aria-valuenow", currentImage)
        .text(Math.round(currentImage) + "%");
        jQuery('#progress_modal').modal('show');

        var [fileData, parseErrors] = parseImageFilenames(imageFiles);
        var observationUnitNames = Object.values(fileData).map(function(value) {
            return value.observationUnitName;
        });

        jQuery.ajax( {
            url: "/list/transform/temp",
            method: 'GET',
            data: {
                "type": "stocks_2_stock_ids",
                "items": JSON.stringify(observationUnitNames),
            }
        }).done(function(response) {

            var observationUnitDbIds = response.transform;
            var imageData = Object.values(fileData).map(function(value, i) {
                value.observationUnitDbId = observationUnitDbIds[i];
                return value;
            });
            // var result = loadImagesSequentially(imageFiles, imageData, currentImage);
            loadImagesSequentially(imageFiles, imageData, currentImage).done(function(result) {
                console.log(result);
                jQuery('#upload_images_status').append(
                    formatMessage("Success! Upload of all "+imageFiles.length+" images is completed.", 'success')
                );
            })
            .fail(function(error) {
                console.log(error);
                jQuery('#upload_images_status').append(
                    formatMessage(error, 'error')
                );
            });
        });
    });
});


function showImagePreview(imageFiles) {
    // var imageFiles = document.getElementById('upload_images_file_input').files;
    var file = imageFiles[0];
    var restCount = imageFiles.length - 1;
    var preview = document.getElementById("preview");
    preview.innerHTML = "";
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
}


function parseImageFilenames(imageFiles) {
    // extract observationUnitNames from image filenames
    // e.g. 21BEDS0809HCRH02_25_809_Covington_G3_RootPhoto1_1_2021-05-13-04-50-36
    var fileData = {};
    var parseErrors = [];
    for (var i = 0; i < imageFiles.length; i++) {
        var file = imageFiles[i];
        var name = file.name;
        var timestamp = name.substring(name.lastIndexOf('_') + 1);
        var timestampWithoutExtension = timestamp.substr(0, timestamp.lastIndexOf('.'));
        var nameWithoutTimestamp = name.substring(0, name.lastIndexOf('_'));
        var nameWithoutNumber = nameWithoutTimestamp.substring(0, nameWithoutTimestamp.lastIndexOf('_'));
        var justUnitName = nameWithoutNumber.substring(0, nameWithoutNumber.lastIndexOf('_'));
        if (justUnitName) {
            fileData[file.name] = {
                "imageFileName" : file.name,
                "imageFileSize" : file.size,
                "imageTimeStamp" : timestampWithoutExtension,
                "mimeType" : file.type,
                "observationUnitName" : justUnitName
            };
        } else {
            parseErrors.push("Filename <b>" + name + "</b> must start with a valid observationUnitName.")
        }
    }
    // console.log(JSON.stringify(fileData));
    return [fileData, parseErrors];
}


function formatMessage(messageDetails, messageType) {
    var formattedMessage = "<hr><ul class='list-group'>";
    var itemClass = messageType == "success" ? "list-group-item-success" : "list-group-item-danger";
    var glyphicon = messageType == "success" ? "glyphicon glyphicon-ok" : "glyphicon glyphicon-remove";
    messageDetails = Array.isArray(messageDetails) ? messageDetails : [messageDetails];

    for (var i = 0; i < messageDetails.length; i++) {
        formattedMessage += "<li class='list-group-item "+itemClass+"'>";
        formattedMessage += "<span class='badge'><span class='"+glyphicon+"'></span></span>";
        formattedMessage += messageDetails[i] + "</li>";
    }
    formattedMessage += "</ul>";
    return formattedMessage;
}

function verifyImageFiles(imageFiles) {
  var [fileData, parseErrors] = parseImageFilenames(imageFiles);
  var returnMessage;
  if (parseErrors.length) {
      return { "error" : formatMessage(parseErrors, 'error') };
      // jQuery('#upload_images_submit_store').attr('disabled', true);
      // jQuery('#upload_images_status').html(returnMessage);
      // jQuery('#working_modal').modal("hide");
      // return;
  }
  var observationUnitNames = Object.values(fileData).map(function(value) {
      return value.observationUnitName;
  });
  jQuery.ajax( {
      url: "/list/transform/temp",
      method: 'GET',
      data: {
          "type": "stocks_2_stock_ids",
          "items": JSON.stringify(observationUnitNames),
      }
  }).done(function(response) {
      if (response.missing.length > 0) {
          var errors = response.missing.map(function(name) {
              return "<b>" + name + "</b> is not a valid observationUnitName.";
          });
          return { "error" : formatMessage(errors, 'error') };
          // jQuery('#upload_images_submit_store').attr('disabled', true);
      } else {
          // jQuery('#upload_images_submit_store').attr('disabled', false);
          var successText = "Verification complete. All image files match an existing observationUnit. Ready to store images.";
          return { "success" : formatMessage(successText, 'success') };
      }
  }).fail(function(error){
      // jQuery('#upload_images_submit_store').attr('disabled', true);
      return { "error" : formatMessage(error, 'error') };
  });

}


function loadImagesSequentially(imageFiles, imageData, currentImage){
    if(currentImage == imageFiles.length) {
        // console.log("Image number "+currentImage+" matched number of files "+imageFiles.length);
        jQuery('#progress_modal').modal('hide');
        return jQuery.Deferred().resolve().promise();
    }

    var total = imageFiles.length;
    var file = imageFiles[currentImage];
    var image = imageData[currentImage];
    currentImage++;
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
        // console.log("Success uploading image metadata: "+image.imageFileName+" with details: "+JSON.stringify(response));
        if (response.result) {
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
                return jQuery.Deferred().reject(error);
            });
        } else {
            var errors = response.metadata.status.flatMap(function(elem) {
                return elem.messageType == "ERROR" ? elem.message : [];
            });
            console.log("handling response errors: "+JSON.stringify(errors));
            return jQuery.Deferred().reject(errors);
        }
    }).fail(function(error){
        console.log("error: "+JSON.stringify(error));
        return jQuery.Deferred().reject(error);
    }).then(function() {
        return loadImagesSequentially(imageFiles, imageData, currentImage);
    });
}
