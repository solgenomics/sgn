
jQuery( document ).ready( function() {

    document.getElementById('upload_images_file_input').addEventListener('input', function (e) {
        jQuery('#upload_images_status').html('');
        jQuery('#upload_images_submit_store').attr('disabled', true);
        showImagePreview(this.files);
    });

    let barcodeDataResult;
    let exifDataResult = null;
    let exifValid = null;

    jQuery('#upload_images_submit_verify').click( function() {
        jQuery('#working_modal').modal("show");
        var type = jQuery('#upload_images_file_format').val();
        var result;
        if (type == 'images') {
            var imageFiles = document.getElementById('upload_images_file_input').files;
            if (imageFiles.length < 1) {
                jQuery('#working_modal').modal("hide");
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload_select_images", "Please select image files") : "Please select image files"));
                return false;
            }

            var formData = new FormData();
            for (var i = 0; i < imageFiles.length; i++) {
                formData.append('images', imageFiles[i]);
            }
            console.log("AJAX request", imageFiles);
            jQuery.ajax({
                url: "/ajax/image/verify_exif",
                method: "POST",
                data: formData,
                processData: false,
                contentType: false,
            }).done(function(result) {
                exifDataResult = result;
                //console.log("exif data result", result);
                const exifOk = verifyExifData(result);
                exifValid = exifOk;
                console.log("check", exifOk);

                if (!exifOk) {
                    var [fileData, unitType, transformType, parseErrors] = parseImageFilenames(imageFiles);
                    //console.log("non-exif", fileData);
                    if (parseErrors.length) {
                    //console.log("parseErrors are "+JSON.stringify(parseErrors));
                    reportVerifyResult({ "error" : parseErrors });
                    jQuery('#working_modal').modal("hide");
                    return;
                }
                verifyImageFiles(fileData, unitType, transformType).then(function(result) {
                    reportVerifyResult(result);
                    jQuery('#working_modal').modal("hide");
                });    
                }
                jQuery('#working_modal').modal("hide");
            }).fail(function() {
                reportVerifyResult({ "error": [(window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.exif_verification_failure", "Error occurred during EXIF verification.") : "Error occurred during EXIF verification.")]});
                jQuery('#working_modal').modal("hide");
            });
        } else if (type == 'images_with_barcodes') {
            var imageFiles = document.getElementById('upload_images_file_input').files;
            if (imageFiles.length < 1) {
                jQuery('#working_modal').modal("hide");
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload_select_images", "Please select image files") : "Please select image files"));
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
                reportVerifyResult({ "error": [(window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.barcode_scan_failure", "Error occurred during barcode scan") : "Error occurred during barcode scan")]});
                jQuery('#working_modal').modal("hide");
            });
        } else { // verify associated phenotypes format
            var phenoFile =  document.getElementById('upload_associated_phenotypes_file_input').files[0];
            var zipFile =  document.getElementById('upload_images_zip_file_input').files[0];
            if (!(phenoFile instanceof File)) {
                jQuery('#working_modal').modal("hide");
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload_select_spreadsheet", "Please select a phenotype spreadsheet") : "Please select a phenotype spreadsheet"));
                return false;
            } else if (!(zipFile instanceof File)) {
                jQuery('#working_modal').modal("hide");
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.zip_required", "Please select an image zipfile") : 'Please select an image zipfile'));
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
            //console.log("imageFiles", imageFiles);
            jQuery('#progress_msg').text((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload_preparing", "Preparing images for upload") : 'Preparing images for upload'));
            jQuery('#progress_bar').css("width", "0%")
            .attr("aria-valuenow", 0)
            .text("0%");
            jQuery('#progress_modal').modal('show');
            //console.log("exif data result", exifDataResult);

            if (exifValid) {

                const fileData = parseExifData(exifDataResult, imageFiles);
                //console.log("exif data: ", fileData);
                const transformType = "stock_ids_2_stocks";
                const observationUnits = Object.values(fileData).map(function(value) {
                    return value.observationUnit;
                });

                var observationUnitDbIds;
                observationUnitDbIds = observationUnits

                const imageData = Object.values(fileData).map(function(value, i) {
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
              
            } else {
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
            }  
        } else if (type == "images_with_barcodes") {
            var imageFiles = document.getElementById('upload_images_file_input').files;
            jQuery('#progress_msg').text((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload_preparing", "Preparing images for upload") : 'Preparing images for upload'));
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
            }); 
        } else { // store associated phenotypes format
            jQuery('#working_modal').modal("show");
            var phenoFile =  document.getElementById('upload_associated_phenotypes_file_input').files[0];
            var zipFile =  document.getElementById('upload_images_zip_file_input').files[0];
            if (!(phenoFile instanceof File)) {
                jQuery('#working_modal').modal("hide");
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload_select_spreadsheet", "Please select a phenotype spreadsheet") : "Please select a phenotype spreadsheet"));
                return false;
            } else if (!(zipFile instanceof File)) {
                jQuery('#working_modal').modal("hide");
                alert((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.zip_required", "Please select an image zipfile") : 'Please select an image zipfile'));
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

function verifyExifData(result) {
    const successMessages = [];
    const errorMessages = [];
    const finalSuccessMessage = [];
    const validFilenames = [];
    const invalidFilenames = [];
    let exifFiles = 0;
    let nonExifFiles = 0;

    result.images.forEach((img, index) => {
        const imgName = img.filename || `Image ${index + 1}`;
        const exif = img.exif || {};
        const imgErrors = [];

        if (img.status === "no_exif") {
            errorMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.no_exif", "%{image} does not have EXIF data", {"image": String(imgName)}) : `${imgName} does not have EXIF data`));
            invalidFilenames.push(imgName);
            nonExifFiles++;
            return;
        } else {
            exifFiles++;
        }

        const obsUnit = exif.observation_unit;
        const obsVar = exif.observation_variable;
        const hasObsUnit = obsUnit && obsUnit.observation_unit_db_id;
        const hasObsVar = obsVar && obsVar.observation_variable_name;
        const hasTimestamp = exif.timestamp;
        const hasCvtermId = exif.cvterm_id;
        const stockName = exif.stock_name; 
        let traitName = obsVar.observation_variable_name;

        if (hasObsUnit) {
            successMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.observation_unit_id_success", "%{image}: ObservationUnitDbId: %{id}", {"image": String(imgName), "id": String(obsUnit.observation_unit_db_id)}) : `${imgName}: ObservationUnitDbId: ${obsUnit.observation_unit_db_id}`));
        } else {
            imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.missing_observation_unit_id", "%{image}: Missing ObservationUnitDbId", {"image": String(imgName)}) : `${imgName}: Missing ObservationUnitDbId`));
        }

        // Specific: field missing entirely vs. present but empty/not found
        if (!obsVar) {
            imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.trait_field_missing", "%{image}: No trait field found in EXIF data", {"image": String(imgName)}) : `${imgName}: No trait field found in EXIF data`));
        } else if (!hasObsVar && !obsVar.external_db_id) {
            imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.trait_field_incomplete", "%{image}: Trait field is present but is missing both a trait ID and trait name", {"image": String(imgName)}) : `${imgName}: Trait field is present but is missing both a trait ID and trait name`));
        } else {
            successMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.observation_variable_success", "%{image}: Observation Variable: %{name}", {"image": String(imgName), "name": String((obsVar.observation_variable_name || obsVar.external_db_id))}) : `${imgName}: Observation Variable: ${obsVar.observation_variable_name || obsVar.external_db_id}`));
            if (!hasCvtermId) {
                if (img.trait_lookup_type === "id") {
                    imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.trait_id_missing", "%{image}: Trait ID \"%{id}\" does not exist in the database", {"image": String(imgName), "id": String(img.trait_lookup_value)}) : `${imgName}: Trait ID "${img.trait_lookup_value}" does not exist in the database`));
                } else if (img.trait_lookup_type === "name" || img.trait_lookup_type === "synonym") {
                    imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.trait_name_missing", "%{image}: Trait name \"%{name}\" does not exist in the database", {"image": String(imgName), "name": String(img.trait_lookup_value)}) : `${imgName}: Trait name "${img.trait_lookup_value}" does not exist in the database`));
                } else {
                    imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.associated_trait_invalid", "%{image}: Associated trait does not exist in the database", {"image": String(imgName)}) : `${imgName}: Associated trait does not exist in the database`));
                }
            } else if (img.trait_lookup_type === "synonym") {
                traitName = img.trait_matched_name;
                successMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.trait_synonym_match", "%{image}: Trait name \"%{query}\" matched via synonym to \"%{match}\"", {"image": String(imgName), "query": String(img.trait_lookup_value), "match": String(img.trait_matched_name)}) : `${imgName}: Trait name "${img.trait_lookup_value}" matched via synonym to "${img.trait_matched_name}"`));
            }
        }

        if (hasTimestamp) {
            successMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.timestamp_success", "%{image}: Timestamp: %{timestamp}", {"image": String(imgName), "timestamp": String(exif.timestamp)}) : `${imgName}: Timestamp: ${exif.timestamp}`));
        } else {
            imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.timestamp_missing", "%{image}: Missing Timestamp", {"image": String(imgName)}) : `${imgName}: Missing Timestamp`));
        }

        if (img.stock_exists === "false") {
            imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.observation_unit_missing", "%{image}: ObservationUnitDbId %{id} does not exist in the database", {"image": String(imgName), "id": String(obsUnit.observation_unit_db_id)}) : `${imgName}: ObservationUnitDbId ${obsUnit.observation_unit_db_id} does not exist in the database`));
        } else if (hasObsUnit && !stockName) {
            imgErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.stock_for_observation_unit_missing", "%{image}: Stock associated with ObservationUnitDbId %{id} could not be found", {"image": String(imgName), "id": String(obsUnit.observation_unit_db_id)}) : `${imgName}: Stock associated with ObservationUnitDbId ${obsUnit.observation_unit_db_id} could not be found`));
        }

        if (imgErrors.length === 0) {
            finalSuccessMessage.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.exif_valid_summary", "%{image} has valid EXIF data. Associated stock: %{stock}. Associated trait: %{trait}. Ready to store image", {"image": String(imgName), "stock": String(stockName), "trait": String(traitName)}) : `${imgName} has valid EXIF data. Associated stock: ${stockName}. Associated trait: ${traitName}. Ready to store image`));
            validFilenames.push(imgName);
        } else {
            errorMessages.push(...imgErrors);
            invalidFilenames.push(imgName);
        }
    });

    if (errorMessages.length === 0) {
        jQuery('#upload_images_submit_store').attr('disabled', false);
        jQuery('#upload_images_status').html(
            formatMessage(finalSuccessMessage, "success")
        );
        return { valid: true, validFilenames: validFilenames, invalidFilenames: invalidFilenames };
    }

    if (exifFiles > 0 && nonExifFiles > 0) {
        errorMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.exif_or_pattern_required", "Please load files all containing EXIF data or with the same file naming pattern") : "Please load files all containing EXIF data or with the same file naming pattern"));
    }

    jQuery('#upload_images_submit_store').attr('disabled', true);
    jQuery('#upload_images_status').html(
        formatMessage(errorMessages, "error")
    );

    return { valid: false, validFilenames: validFilenames, invalidFilenames: invalidFilenames, errorMessages: errorMessages };
}

function parseExifData(exifData, imageFiles) {
    const fileData = {};
    console.log("passed exif", exifData);
    //console.log("passed image files", imageFiles);
    //console.log("exifdata.images", exifData.images);

    for (let i = 0; i< imageFiles.length; i++) {
        const file = imageFiles[i];
        const timestamp = exifData.images[i].exif.timestamp;
        const timestampWithoutExtension = timestamp.substr(0, timestamp.lastIndexOf(" "));
        const obsUnitId = exifData.images[i].exif.observation_unit.observation_unit_db_id;
        const cvtermId = exifData.images[i].exif.cvterm_id;
        //console.log("obsUnitId", obsUnitId);
        if (obsUnitId) {
            fileData[file.name] = {
                "imageName" : file.name,
                "imageFileName" : file.name,
                "imageFileSize" : file.size,
                "imageTimeStamp" : timestampWithoutExtension,
                "mimeType" : file.type,
                "observationUnit" : obsUnitId,
                "cvtermId" : cvtermId
            };
        }

    }
    //console.log("File data: ", fileData);
    return fileData;
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
            parseErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.filename_prefix", "Filename ") : "Filename ") + "<b>" + String(name) + "</b>" + (window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.filename_suffix", " must start with a valid observationUnitName or observationUnitDbId.") : " must start with a valid observationUnitName or observationUnitDbId."))
        }
    }

    if (id_count > 0 && name_count > 0) {
        parseErrors.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.mixed_unit_filename_patterns", "Image filenames include a mix of observationUnitDbIds and observationUnitNames. Please load files with only one naming pattern at a time.") : "Image filenames include a mix of observationUnitDbIds and observationUnitNames. Please load files with only one naming pattern at a time."));
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

        if (result.images[index].multiple_codes === "true") {
            errorMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.multiple_barcodes", "Multiple barcodes found in %{image}. Please make sure each image only contains one barcode", {"image": String(imgName)}) : `Multiple barcodes found in ${imgName}. Please make sure each image only contains one barcode`));
        }
        
        if (result.images[index].valid_barcode === "false") {
            errorMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.barcode_missing", "Barcode not found for %{image}", {"image": String(imgName)}) : `Barcode not found for ${imgName}`));
            return;
        }

        const stockId = result.images[index].stock_id;

        if (result.images[index].stock_exists === "false") {
            errorMessages.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.stock_id_missing", "Stock ID %{stock_id} found in %{image} does not exist in the database", {"stock_id": String(stockId), "image": String(imgName)}) : `Stock ID ${stockId} found in ${imgName} does not exist in the database`));
        }

        if (errorMessages.length === 0) {
            finalSuccessMessage.push((window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.barcode_valid_summary", "%{image} barcode scanned successfully. Associated stock ID: %{stock_id}. Ready to store image", {"image": String(imgName), "stock_id": String(stockId)}) : `${imgName} barcode scanned successfully. Associated stock ID: ${stockId}. Ready to store image`));
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
        var timestamp = barcodeData.images[i].timestamp;
        if (timestamp) {
            const timestampWithoutExtension = timestamp.split(" ")[0];
            const timestampWithDashes = timestampWithoutExtension.replace(/:/g, '-');
            timestamp = timestampWithDashes;
        }
        
        const obsUnitId = barcodeData.images[i].stock_id;
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
          //console.log("Errors are "+errors);
          return { "error" : errors };
      } else {
          var successText = (window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.verification_complete", "Verification complete. All image files match an existing observationUnit. Ready to store images.") : "Verification complete. All image files match an existing observationUnit. Ready to store images.");
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
            var msg = (window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.image_upload_success", "Successfly uploaded image ") : "Successfly uploaded image ") + String(response.result.data[0].imageFileName);
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
    //console.log("image", image);
    //console.log("file", file);

    currentImage++;
    jQuery('#progress_msg').html('<p class="form-group text-center">' + (window.SGN && window.SGN.i18n ? SGN.i18n.p("drone_imaging.upload.image_progress", "Working on image %{current} out of %{total}", {"current": String(currentImage), "total": String(total)}) : "Working on image " + currentImage + " out of " + total) + '</p>');
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
        //console.log("response:", response);
        var imageDbId = response.result.data[0].imageDbId;
        //console.log("imageDbId: ", imageDbId);
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
