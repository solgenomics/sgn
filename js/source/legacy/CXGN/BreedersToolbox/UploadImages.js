
jQuery( document ).ready( function() {

    document.getElementById('upload_images_file_input').addEventListener('input', function (e) {
        jQuery('#upload_images_status').html('');
        jQuery('#upload_images_submit_store').attr('disabled', true);
        showImagePreview(this.files);
    });

    let barcodeDataResult;

    jQuery('#upload_images_submit_verify').click( function() {
        jQuery('#working_modal').modal("show");
        var type = jQuery('#upload_images_file_format').val();
        var result;
        if (type == 'images') {
            var imageFiles = document.getElementById('upload_images_file_input').files;
            if (imageFiles.length < 1) {
                jQuery('#working_modal').modal("hide");
                alert("Please select image files");
                return false;
            }
            var [fileData, unitType, transformType, parseErrors] = parseImageFilenames(imageFiles);
            if (parseErrors.length) {
                // console.log("parseErrors are "+JSON.stringify(parseErrors));
                reportVerifyResult({ "error" : parseErrors });
                jQuery('#working_modal').modal("hide");
                return;
            }
            verifyImageFiles(fileData, unitType, transformType).then(function(result) {
                reportVerifyResult(result);
                jQuery('#working_modal').modal("hide");
            });

        } else if (type == 'images_with_barcodes') {
            var imageFiles = document.getElementById('upload_images_file_input').files;
            if (imageFiles.length < 1) {
                jQuery('#working_modal').modal("hide");
                alert("Please select image files");
                return false;
            }
            var formData = new FormData();
            for (var i = 0; i < imageFiles.length; i++) {
                formData.append('images', imageFiles[i]);
            }
            jQuery.ajax({
                url: "/ajax/image/scan_barcode",
                method: "POST",
                data: formData,
                processData: false,
                contentType: false,
            }).done(function(result) {
                barcodeDataResult = result;
                const validBarcodes = verifyBarcodeData(result);
                jQuery('#working_modal').modal("hide");

            }).fail(function() {
                reportVerifyResult({ "error": ["Error ocurred during barcode scan"]});
                jQuery('#working_modal').modal("hide");
            })
        } else { // verify associated phenotypes format
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
            submitAssociatedPhenotypes(phenoFile, zipFile, "/ajax/phenotype/upload_verify/spreadsheet").done(function(result) {
                reportVerifyResult(result);
                jQuery('#working_modal').modal("hide");
            });
        }
    });


    jQuery('#upload_images_submit_store').click( function() {
        var type = jQuery('#upload_images_file_format').val();
        if (type == 'images') {
            var imageFiles = document.getElementById('upload_images_file_input').files;
            jQuery('#progress_msg').text('Preparing images for upload');
            jQuery('#progress_bar').css("width", "0%")
            .attr("aria-valuenow", 0)
            .text("0%");
            jQuery('#progress_modal').modal('show');

            var [fileData, unitType, transformType, parseErrors] = parseImageFilenames(imageFiles);
            var observationUnits = Object.values(fileData).map(function(value) {
                return value.observationUnit;
            });

            jQuery.ajax( {
                url: "/list/transform/temp",
                method: 'GET',
                data: {
                    "type": transformType,
                    "items": JSON.stringify(observationUnits),
                }
            }).done(function(response) {
                var observationUnitDbIds;
                if (unitType == "observationUnitName") {
                    observationUnitDbIds = response.transform;
                } else {
                    observationUnitDbIds = observationUnits;
                }

                var imageData = Object.values(fileData).map(function(value, i) {
                    value.observationUnitDbId = observationUnitDbIds[i];
                    return value;
                });

                loadAllImages(imageFiles, imageData).done(function(result) {
                    // console.log("Result from promise is: "+JSON.stringify(result));
                    jQuery('#progress_modal').modal('hide');
                    reportStoreResult(result);
                })
                .fail(function(error) {
                    console.log(error);
                    jQuery('#upload_images_status').append(
                        formatMessage(error, 'error')
                    );
                });
            });
        } else if (type == "images_with_barcodes") {
            var imageFiles = document.getElementById('upload_images_file_input').files;
            jQuery('#progress_msg').text('Preparing images for upload');
            jQuery('#progress_bar').css("width", "0%")
            .attr("aria-valuenow", 0)
            .text("0%");
            jQuery('#progress_modal').modal('show');

            var fileData = parseBarcodeData(barcodeDataResult, imageFiles);

            const observationUnits = Object.values(fileData).map(function(value) {
                return value.observationUnit;
            });
            var observationUnitDbIds;
            observationUnitDbIds = observationUnits;

            console.log("observatioUnits: ", observationUnits);

            const imageData = Object.values(fileData).map(function(value, i) {
                value.observationUnitDbId = observationUnits[i];
                return value;
            });

            loadAllImages(imageFiles, imageData).done(function(result) {
                jQuery('#progress_modal').modal('hide');
                reportStoreResult(result);
            })
        } else { // store associated phenotypes format
            jQuery('#working_modal').modal("show");
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

            submitAssociatedPhenotypes(phenoFile, zipFile, "/ajax/phenotype/upload_store/spreadsheet").done(function(result) {
                reportStoreResult(result);
                jQuery('#working_modal').modal("hide");
            });
        }
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


function reportVerifyResult(result) {
    if (result.success && result.success.length > 0) {
        jQuery('#upload_images_submit_store').attr('disabled', false);
        jQuery('#upload_images_status').html(
            formatMessage(result.success, "success")
        );
    }
    if (result.error && result.error.length > 0) {
        jQuery('#upload_images_submit_store').attr('disabled', true);
        jQuery('#upload_images_status').html(
            formatMessage(result.error, "error")
        );
    }
}


function reportStoreResult(result) {
    // console.log("result is: "+JSON.stringify(result));
    if (result.success && result.success.length > 0) {
        jQuery('#upload_images_status').html(
            formatMessage(result.success, 'success')
        );
    }
    if (result.error && result.error.length > 0) {
        jQuery('#upload_images_status').html(
            formatMessage(result.error, 'error')
        );
    }
    jQuery('#working_modal').modal("hide");
}


function parseImageFilenames(imageFiles) {
    // extract observationUnits from image filenames
    // e.g. 21BEDS0809HCRH02_25_809_Covington_G3_RootPhoto1_1_2021-05-13-04-50-36
    var fileData = {};
    var unitType = '';
    var transformType = '';
    var parseErrors = [];

    var id_format = /^[0-9]+$/;
    var id_count = 0;
    var name_count = 0;

    for (var i = 0; i < imageFiles.length; i++) {
        var file = imageFiles[i];
        var name = file.name;
        var timestamp = name.substring(name.lastIndexOf('_') + 1);
        var timestampWithoutExtension = timestamp.substr(0, timestamp.lastIndexOf('.'));
        var nameWithoutTimestamp = name.substring(0, name.lastIndexOf('_'));
        var nameWithoutNumber = nameWithoutTimestamp.substring(0, nameWithoutTimestamp.lastIndexOf('_'));
        var justUnit = nameWithoutNumber.substring(0, nameWithoutNumber.lastIndexOf('_'));
        justUnit.match(id_format) ? id_count++ : name_count++;
        if (justUnit) {
            fileData[file.name] = {
                "imageFileName" : file.name,
                "imageFileSize" : file.size,
                "imageTimeStamp" : timestampWithoutExtension,
                "mimeType" : file.type,
                "observationUnit" : justUnit
            };
        } else {
            parseErrors.push("Filename <b>" + name + "</b> must start with a valid observationUnitName or observationUnitDbId.")
        }
    }

    if (id_count > 0 && name_count > 0) {
        parseErrors.push("Image filenames include a mix of observationUnitDbIds and observationUnitNames. Please load files with only one naming pattern at a time.");
    }

    if (id_count > 0) {
        unitType = "observationUnitDbId";
        transformType = "stock_ids_2_stocks";
    } else {
        unitType = "observationUnitName";
        transformType = "stocks_2_stock_ids";
    }
    // console.log(JSON.stringify(fileData));
    return [fileData, unitType, transformType, parseErrors];
}

function verifyBarcodeData(result) {
    const successMessages = [];
    const errorMessages = [];
    const finalSuccessMessage = [];

    result.images.forEach((img, index) => {
        const imgName = img.filename || `Image ${index + 1}`;
        
        if (result.images[index].valid_barcode === "false") {
            errorMessages.push(`Barcode not found for ${imgName}`);
            return;
        }

        const stockId = result.images[index].stock_id;

        if (stockId) {
            successMessages.push(`${imgName}: Barcode has valid stock ID: ${stockId}`);
        }

        if (errorMessages.length === 0) {
            finalSuccessMessage.push(`${imgName} barcode scanned successfully. Associated stock ID: ${stockId}. Ready to store image`);
        }
    })

    if (errorMessages.length === 0) {
        jQuery('#upload_images_submit_store').attr('disabled', false);
        jQuery('#upload_images_status').html(
            formatMessage(finalSuccessMessage, "success")
        );
        return true;
    } else {
        jQuery('#upload_images_submit_store').attr('disabled', false);
        jQuery('#upload_images_status').html(
            formatMessage(errorMessages, "error")
        );
        return false;
    }
}

function parseBarcodeData(barcodeData, imageFiles) {
    const fileData = {};

    for (let i = 0; i < imageFiles.length; i++) {
        const file = imageFiles[i];
        const timestamp = undefined;
        const obsUnitId = barcodeData.images[i].stock_id;
        console.log("obsunitid check: ", obsUnitId);

        if (obsUnitId) {
            fileData[file.name] = {
                "imageName" : file.name,
                "imageFileName" : file.name,
                "imageFileSize" : file.size,
                "imageTimeStamp" : timestamp,
                "mimeType" : file.type,
                "observationUnit" : obsUnitId

            };
        }
    }
    return fileData;
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


function verifyImageFiles(fileData, unitType, transformType) {

    var observationUnits = Object.values(fileData).map(function(value) {
        return value.observationUnit;
    });

    return jQuery.ajax( {
      url: "/list/transform/temp",
      method: 'GET',
      data: {
          "type": transformType,
          "items": JSON.stringify(observationUnits),
      }
    }).then(function(response) {
      // console.log("response is "+JSON.stringify(response));
      if (response.missing.length > 0) {
          var errors = response.missing.map(function(name) {
              return "<b>" + name + "</b> is not a valid "+unitType;
          });
          console.log("Errors are "+errors);
          return { "error" : errors };
      } else {
          var successText = "Verification complete. All image files match an existing observationUnit. Ready to store images.";
          return { "success" : successText };
      }
    }).fail(function(error){
       return { "error" : error };
    });
}


function submitAssociatedPhenotypes (phenoFile, zipFile, url) {
    console.log("submitting files for verification to url "+url);
    var formData = new FormData();
    formData.append('upload_spreadsheet_phenotype_file_format', 'associated_images');
    formData.append('upload_spreadsheet_phenotype_file_input', phenoFile);
    formData.append('upload_spreadsheet_phenotype_associated_images_file_input', zipFile);

    return jQuery.ajax( {
        url: url,
        method: 'POST',
        data: formData,
        contentType: false,
        processData: false,
    }).then(function(response){
        console.log("finished verification, response is "+JSON.stringify(response));
        return response;
        // if (response.success) {
        //     return { "success": formatMessage(response.success, 'success') };
        // } else if (response.error) {
        //     return { "error": formatMessage(response.error, 'error') };
        // }
    }).fail(function(error){
        return { "error": error };
        // return { "error": formatMessage(error, 'error') };
    });
}


function loadAllImages(imageFiles, imageData){
    return loadImagesSequentially(imageFiles, imageData, {"success":[],"error":[]} );
}


function loadImagesSequentially(imageFiles, imageData, uploadStatus){

    return loadSingleImage(imageFiles, imageData).then(function(response) {
        // console.log("load single image response is: " +JSON.stringify(response));

        if (response.result) {
            var msg = "Successfly uploaded image "+response.result.data[0].imageFileName;
            uploadStatus.success.push(msg);
        } else {
            // console.log("handling response errors: "+JSON.stringify(response.metadata.status));
            response.metadata.status.forEach(function(msg) {
              if (msg.messageType == "ERROR") { uploadStatus.error.push(msg.message); }
            });
            return uploadStatus;
        }

        imageData.shift();

        if (imageData.length < 1) {
            // console.log("We've shifted through and loaded all "+imageFiles.length+" images");
            return uploadStatus;
        } else {
            return loadImagesSequentially(imageFiles, imageData, uploadStatus);
        }

    });

}

function loadSingleImage(imageFiles, imageData, uploadStatus){

    var currentImage = imageFiles.length - imageData.length;
    var total = imageFiles.length;
    var file = imageFiles[currentImage];
    var image = imageData[0];

    currentImage++;
    jQuery('#progress_msg').html('<p class="form-group text-center">Working on image '+currentImage+' out of '+total+'</p>');
    jQuery('#progress_msg').append('<p class="form-group text-center"><b>'+image.imageFileName+'</b></p>')
    var progress = Math.round((currentImage / total) * 100)
    jQuery('#progress_bar').css("width", progress + "%")
    .attr("aria-valuenow", progress)
    .text(progress + "%");

    return jQuery.ajax( {
        url: "/brapi/v2/images",
        method: 'POST',
        headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
        data: JSON.stringify([image]),
        contentType: "application/json; charset=utf-8"
    }).success(function(response){
        var imageDbId = response.result.data[0].imageDbId;
        jQuery.ajax( {
            url: "/brapi/v2/images/"+imageDbId+"/imagecontent",
            method: 'PUT',
            async: false,
            headers: { "Authorization": "Bearer "+jQuery.cookie("sgn_session_id") },
            data: file,
            processData: false,
            contentType: file.type
        });
    });
}
