/*jslint browser: true, devel: true */

/**

=head1 Trial.js

Display for managing genotyping plates


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>
Lukas Mueller <lam87@cornell.edu>

=cut

*/


var $j = jQuery.noConflict();

jQuery(document).ready(function ($) {

    // defined in CXGN.BreedersToolbox.HTMLSelect
    get_select_box("locations", "location_select_div", {});
    get_select_box("breeding_programs", "breeding_program_select_div", {});
    get_select_box("years", "year_select_div", {'auto_generate': 1});

    get_select_box("locations", "upload_genotype_location_select_div", {'id': 'upload_genotype_location_select', 'name': 'upload_genotype_location_select'});
    get_select_box("breeding_programs", "upload_genotype_breeding_program_select_div", {'id': 'upload_genotype_breeding_program_select', 'name': 'upload_genotype_breeding_program_select'});
    get_select_box("years", "upload_genotype_year_select_div", {'auto_generate': 1, 'id': 'upload_genotype_year_select', 'name': 'upload_genotype_year_select'});

    jQuery("#upload_genotypes_species_name_input").autocomplete({
        source: '/organism/autocomplete'
    });

    jQuery(function() {
        jQuery( "#genotyping_trials_accordion" ).accordion({
            header: "> div > h3",
            collapsible: true,
            active: false,
            heightStyle: "content"
        }).sortable({
            axis: "y",
            handle: "h3",
            stop: function( event, ui ) {
                // IE doesn't register the blur when sorting
                // so trigger focusout handlers to remove .ui-state-focus
                ui.item.children( "h3" ).triggerHandler( "focusout" );
            }
        });
    });


    var plate_data = new Object();
    jQuery('#add_geno_trial_submit').click(function () {
        plate_data = new Object();
        plate_data.breeding_program = jQuery('#breeding_program_select').val();
        plate_data.year = jQuery('#year_select').val();
        plate_data.location = jQuery('#location_select').val();
        plate_data.description = jQuery('#genotyping_trial_description').val();
        plate_data.project_name = jQuery('#genotyping_project_name').val();
        plate_data.name = jQuery('#genotyping_trial_name').val();
        plate_data.plate_format = jQuery('#genotyping_trial_plate_format').val();
        plate_data.sample_type = jQuery('#genotyping_trial_plate_sample_type').val();
        plate_data.blank_well = jQuery('#genotyping_blank_well').val();
        plate_data.well_concentration = jQuery('#genotyping_well_concentration').val();
        plate_data.ncbi_taxonomy_id = jQuery('#genotyping_well_ncbi_taxonomy_id').val();
        plate_data.well_extraction = jQuery('#genotyping_well_extraction').val();
        plate_data.well_date = jQuery('#genotyping_well_date').val();
        plate_data.well_dna_person = jQuery('#genotyping_well_dna_person').val();
        plate_data.well_volume = jQuery('#genotyping_well_volume').val();
        plate_data.well_tissue = jQuery('#genotyping_well_tissue').val();
        plate_data.well_notes = jQuery('#genotyping_well_notes').val();
        plate_data.genotyping_facility = jQuery('#genotyping_trial_facility_select').val();
        plate_data.genotyping_facility_submit = jQuery('#genotyping_trial_facility_submit_select').val();

        if (plate_data.name == '') {
            alert("A name is required and it should be unique in the database. Please try again.");
            return;
        }

        var uploadFileXLS = jQuery("#genotyping_trial_layout_upload").val();
        if (uploadFileXLS === ''){
            var uploadFileCoordinate = jQuery("#genotyping_trial_layout_upload_coordinate").val();
            if (uploadFileCoordinate === ''){
                var uploadFileCoordinateCustom = jQuery("#genotyping_trial_layout_upload_coordinate_template").val();
                if (uploadFileCoordinateCustom === ''){
                    submit_genotype_trial_create(plate_data);
                } else {
                    submit_genotype_trial_upload(plate_data);
                }
            } else {
                submit_genotype_trial_upload(plate_data);
            }
        } else {
            submit_genotype_trial_upload(plate_data);
        }
    });

    jQuery('#genotyping_trial_dialog').on('show.bs.modal', function (e) {
        var l = new CXGN.List();
        var html = l.listSelect('accession_select_box', [ 'accessions', 'plots', 'plants', 'tissue_samples' ], undefined, undefined, undefined);
        jQuery('#accession_select_box_span').html(html);
    })

    function open_genotyping_trial_dialog () {
        jQuery('#genotyping_trial_dialog').modal("show");
    }

    jQuery('[name="create_genotyping_trial_link"]').click(function() {
        open_genotyping_trial_dialog();
    });

    function submit_genotype_trial_create(plate_data) {
        plate_data.list_id = jQuery('#accession_select_box_list_select').val();

        var l = new CXGN.List();
        if (! l.validate(plate_data.list_id, 'accessions', true) && ! l.validate(plate_data.list_id, 'plots', true) && ! l.validate(plate_data.list_id, 'plants', true) && ! l.validate(plate_data.list_id, 'tissue_samples', true)) {
            alert('The list contains elements that are not accessions or plots or plants or tissue_samples.');
            return;
        }

        var elements = l.getList(plate_data.list_id);
        if (typeof elements == 'undefined' ) {
            alert("There are no elements in the list provided.");
            return;
        }

        if (elements.length > plate_data.plate_format) {
            alert("The list needs to have less than 96 or 384 elements depending on the plate format you selected");
            return;
        }

        plate_data.elements = elements;
        generate_plate(plate_data);
    }

    function genotyping_facility_login(auth_data) {
        var access_token;
        $.ajax({
            url: auth_data.host+'/brapi/v1/token',
            method: 'POST',
            async: false,
            data: {
                username: auth_data.username,
                password: auth_data.password,
            },
            success: function(response) {
                if (response.metadata.status[0].message) {
                    alert('Login failed. '+JSON.stringify(response.metadata.status[0].message));
                }
                else {
                    alert("Success!"+ JSON.stringify(response)+" which is "+response.result.access_token);
                    access_token = response.result.access_token;
                }
            },
            error: function(response) {
                alert("An error occurred trying to log into the sequencing facility server. Please try again later.");
            }
        });
        return access_token;
    }

    function submit_plate_to_gdf(brapi_plate_data,facility,plate_id) {

        var auth_data = new Object();
        auth_data = get_genotyping_server_credentials();
        var order;

        if (auth_data.error) {
            alert("Genotyping server credentials are not available. Stop.");
            return;
        }

        var access_token;
        if (auth_data.token){
            access_token = auth_data.token;
        } else {
            access_token = genotyping_facility_login(auth_data);
        }

        if (access_token) {
            auth_data.token = access_token;

            var facility_url = get_facility_url(facility);
            // alert("Sending genotyping experiment entry to genotyping facility...");

            if (facilty = "dart"){
                facility_url += '/brapi/v2/vendor/plates';
            } else {
                facility_url += '/brapi/v2/vendor/orders';
            }
            // var response = { "@context": null, "metadata": {   "datafiles": [], "status": [],   "pagination": {     "pageSize": 0, "totalCount": 0, "totalPages": 0, "currentPage": 0 } }, "result": {   "orderId": "c6b65661-5216-48e6-9260-a5f61006341447",   "shipmentForms": null }};
            $.ajax( {
                url: facility_url,
                method: 'POST',
                headers: {"Authorization": 'Bearer ' + 'YYYY', "Content-type":"application/json"},
                data: JSON.stringify(brapi_plate_data),
                success: function(response) {
                    const orderId = ((response || {}).result || {}).orderId;
                    const submissionId = ((response || {}).result || {}).submissionId;
                    if ( orderId || submissionId) {
                        order = response.result;
                        alert("Successfully!. Plate submitted to facility.");
                        store_gdf_order(order,parseInt(plate_id));

                        Workflow.complete('#submit_plate_btn');
                        Workflow.focus("#plates_to_facilities_workflow", -1); //Go to success page
                        Workflow.check_complete("#plates_to_facilities_workflow");
                    }
                    else {
                        alert(response.metadata.status);
                        return;
                    }
                },
                error: function(response) {
                    alert("An error occurred trying to submit your plate to the facility.");
                    return;
                }
            });
        }
    }

    function load_genotyping_status_info(facility, order_id) {
        var facility_url = get_facility_url(facility);
        $.ajax({
            url: facility_url +'/brapi/v2/vendor/orders/'+ order_id + '/status',
            success: function(response) {
                var status = response.result.status;
                jQuery('#genotyping_trial_status_info').html(status);
            }
        });
    }

    function shipping_label_pdfs(plate_ids) {
        $.ajax({
            url: '/brapi/v2/plate_pdf',
            data: { 'plate_ids' : plate_ids },
            success: function(response) {
                if (response.metadata.status) {
                    alert(response.metadata.status);
                }
                else {
                    $('#download_trial_pdf').html(response.results.url)
                }
            },
            error: function(response) {
                alert("An error occurred. Please try again later.");
            }
        });
    }

    function generate_plate(plate_data) {
        console.log('generating genotype tirial plate');
        $.ajax({
            url: '/ajax/breeders/generategenotypetrial',
            method: 'POST',
            beforeSend: function(){
                jQuery("working_modal").modal('show');
            },
            data: {
                'plate_data': JSON.stringify(plate_data)
            },
            success : function(response) {
                jQuery("working_modal").modal('hide');
                if (response.error) {
                    alert(response.error);
                }
                else {
                    plate_data.design = response.design;
                    store_plate(plate_data);
                }
            },
            error: function(response) {
                alert('An error occurred trying the create the layout.');
                jQuery("working_modal").modal('hide');
            }
        });
    }

    function submit_genotype_trial_upload(plate_data) {
        console.log('uploading genotype trial file');
        plate_data = plate_data;
        jQuery('#upload_genotyping_trials_form').attr("action", "/ajax/breeders/parsegenotypetrial");
        jQuery("#upload_genotyping_trials_form").submit();
    }

    jQuery('#upload_genotyping_trials_form').iframePostForm({
        json: true,
        post: function () {
        },
        complete: function (response) {

            if (response.error) {
                alert(response.error);
                return;
            }
            if (response.error_string) {
                alert(response.error_string);
                return;
            }
            if (response.success) {
                plate_data.design = response.design;
                store_plate(plate_data);
            }
        }
    });

    function store_plate(plate_data) {

        var brapi_plate_data = new Object();

        jQuery.ajax({
            url: '/ajax/breeders/storegenotypetrial',
            method: 'POST',
            beforeSend: function(){
                jQuery("#working_modal").modal('show');
            },
            data: {
                'plate_data': JSON.stringify(plate_data)
            },
            success : function(response) {
                jQuery("#working_modal").modal('hide');
                if (response.error) {
                    alert(response.error);
                }
                else {
                    alert(response.message);
                    brapi_plate_data = response.plate_data;
                    if (plate_data.genotyping_facility_submit == 'yes'){
                        submit_plate_to_gdf(brapi_plate_data);
                    } else {
                        Workflow.complete('#add_geno_trial_submit');
                        Workflow.focus("#genotyping_trial_create_workflow", -1); //Go to success page
                        Workflow.check_complete("#genotyping_trial_create_workflow");
                    }
                }
            },
            error: function(response) {
                alert('An error occurred trying the create the layout.');
                jQuery("#working_modal").modal('hide');
            }
        });
        return brapi_plate_data;
    }

    function get_genotyping_server_credentials() {
        var auth_data;
        jQuery.ajax({
            url: '/ajax/breeders/genotyping_credentials',
            async: false,
            success: function(response) {
                auth_data =  {
                    host : response.host,
                    username : response.username,
                    password : response.password,
                    token : response.token
                };
            },
            error: function(response) {
                return {
                    error : "An error occurred",
                };
            }
        });
        return auth_data;
    }

    jQuery('#genotyping_trial_facility_select').change(function(){
        var selected = jQuery('#genotyping_trial_facility_select').val();
        if (selected == 'Cornell IGD'){
            jQuery.ajax({
                url: 'https://slimstest.biotech.cornell.edu/brapi/v2/vendor-specifications',
                success: function(response) {
                    console.log(response);
                },
                error: function(response) {
                    alert("BrAPI vendor specifications call to IGD did not work.");
                }
            });
        }
    });

    $('#delete_layout_data_by_trial_id').click(function() {
        var trial_id = get_trial_id();
        var yes = confirm("Are you sure you want to delete this experiment with id "+trial_id+" ? This action cannot be undone.");
        if (yes) {
            jQuery.ajax({
                url: '/ajax/breeders/trial/'+trial_id+'/delete/layout',
                beforeSend: function(){
                    jQuery('#working_modal').modal("show");
                    jQuery('#working_msg').html("Deleting genotyping experiment...<br />");
                },
                success: function(response) {
                    if (response.error) {
                        alert(response.error);
                    }
                    else {
                        jQuery('#working_modal').modal("hide");
                        jQuery('#working_msg').html('');
                        alert('The genotyping plate has been deleted.'); // to do: give some idea how many items were deleted.
                        window.location.href="/breeders/trial/"+trial_id;
                    }
                },
                error: function(response) {
                    jQuery('#working_modal').modal("hide");
                    jQuery('#working_msg').html('');
                    alert("An error occurred.");
                }
            });
        }
    });

    jQuery('#generate_genotyping_trial_barcode_link').click(function () {
        jQuery('#generate_genotyping_trial_barcode_button_dialog').modal("show");
    });

    jQuery('#geno_trial_accession_barcode').click(function () {
        $('#generate_genotyping_trial_barcode_button_dialog').modal("hide");
        $('#generate_genotrial_barcode_dialog').modal("show");
    });

    jQuery('#trial_tissue_sample_barcode').click(function () {
        $('#generate_genotyping_trial_barcode_button_dialog').modal("hide");
        $('#generate_genotrial_barcode_dialog').modal("show");
    });

    jQuery('#trial_plateID_barcode').click(function () {
        $('#generate_genotyping_trial_barcode_button_dialog').modal("hide");
        $('#genotrial_barcode_dialog').modal("show");
    });

    jQuery('button[name="manage_tissue_samples_create_field_trial_samples"]').click(function(){
        jQuery('#field_trial_tissue_sample_dialog').modal("show");
    });

    jQuery('button[name="upload_genotyping_data_link"]').click(function(){
        jQuery('#upload_genotypes_dialog').modal('show');
    });

    jQuery('#upload_genotype_submit').click(function () {
        submit_genotype_data_upload()
    });

    function submit_genotype_data_upload() {
        jQuery('#working_modal').modal('show');
        jQuery('#upload_genotypes_form').attr("action", "/ajax/genotype/upload");
        jQuery("#upload_genotypes_form").submit();
    }

    jQuery('#upload_genotypes_form').iframePostForm({
        json: true,
        post: function () {
        },
        complete: function (response) {
            console.log(response);
            jQuery('#working_modal').modal('hide');
            if (response.error || response.errors || response.error_string) {
                //alert(response.error_string);
                var error_html = '';
                if (response.error){
                    error_html = error_html + response.error;
                }
                if (response.error_string){
                    error_html = error_html + response.error_string;
                }
                jQuery('#upload_genotypes_errors_div').html(error_html);

                if (response.missing_stocks && response.missing_stocks.length > 0){
                    jQuery('#upload_genotypes_missing_stocks_div').show();
                    var missing_stocks_html = "<div class='well well-sm'><h3>Add the missing stocks to a list as accessions</h3><div id='upload_genotypes_missing_stock_vals' style='display:none'></div><div id='upload_genotypes_add_missing_stocks'></div></div><br/>";
                    jQuery("#upload_genotypes_add_missing_stocks_html").html(missing_stocks_html);

                    var missing_stocks_vals = '';
                    for(var i=0; i<response.missing_stocks.length; i++) {
                        missing_stocks_vals = missing_stocks_vals + response.missing_stocks[i] + '\n';
                    }
                    jQuery("#upload_genotypes_missing_stock_vals").html(missing_stocks_vals);
                    addToListMenu('upload_genotypes_add_missing_stocks', 'upload_genotypes_missing_stock_vals', {
                        selectText: true,
                        listType: 'accessions'
                    });
                }
                return;
            } else {
                jQuery('#upload_genotypes_errors_div').html('');
            }

            if (response.warning) {
                jQuery('#upload_genotypes_warnings_html').html(response.warning);
                jQuery('#upload_genotypes_warnings_div').show();
                return;
            }
            if (response.success) {
                Workflow.complete('#upload_genotype_submit');
                Workflow.focus("#upload_genotypes_workflow", -1); //Go to success page
            }
        }
    });


    jQuery('#submit_plate_btn').click(function () {
        var order_info = new Object();

        order_info.plate_id = jQuery('#plate_id').html();
        order_info.client_id = jQuery('#client_id').val();
        order_info.service_ids = jQuery('#service_id_select').val();
        order_info.facility_id = jQuery('#genotyping_facility').html();
        
        if (order_info.plate_id == '' || order_info.client_id == '') {
            alert("A plate id, client facility id and service are required. Please try again.");
            return;
        }

        var requeriments = {};

        $("input[id^=req-").each(function(){
            let idd = $(this).attr('id');
            requeriments[idd.replace("req-", "")] = $(this).val();
        });

        order_info.requeriments = requeriments;

        submit_samples_facilities(order_info);

    });

   function submit_samples_facilities(order_info) {

        var brapi_order = new Object();

        // Submit samples
        jQuery.ajax({
            url: '/ajax/breeders/createplateorder',
            method: 'POST',
            beforeSend: function(){
                jQuery("#working_modal").modal('show');
            },
            data: {
                'order_info': JSON.stringify(order_info)
            },
            success : function(response) {
                jQuery("#working_modal").modal('hide');
                if (response.error) {
                    alert(response.error);
                }
                else {
                    
                    brapi_order = response.order;
                    
                    submit_plate_to_gdf(brapi_order,order_info.facility_id,order_info.plate_id);
                }
            },
            error: function(response) {
                alert('An error occurred trying to submit the order.');
                jQuery("#working_modal").modal('hide');
            }
        });
    }

   function store_gdf_order(gdf_order,plate_id) {

        // Submit samples
        jQuery.ajax({
            url: '/ajax/breeders/storeplateorder',
            method: 'POST',
            data: {
                'order': JSON.stringify(gdf_order),
                'plate_id': JSON.stringify(plate_id)
            },
            success : function(response) {
                if (response.error) {
                    alert(response.error);
                } else {
                    alert('Order stored successfully.');
                }
            },
            error: function(response) {
                alert('An error occurred trying to store the order.');
                jQuery("#working_modal").modal('hide');
            }
        });
    }

    function get_facility_services_id(){
        var facility = document.getElementById('genotyping_facility').innerHTML;

        var auth_data = new Object();
        auth_data = get_genotyping_server_credentials();

        if (auth_data.error) {
            alert("Genotyping server credentials are not available. Stop.");
            return;
        }

        var access_token;
        if (auth_data.token){
            access_token = auth_data.token;
        } else {
            access_token = genotyping_facility_login(auth_data);
        }

        var facility_url = get_facility_url(facility);        

        if (facility_url){
            var url = facility_url + '/brapi/v2/vendor/specifications';

            auth_data.token = access_token;

            jQuery.ajax({
                url: url,
                type: 'GET',
                headers: {"Authorization": 'Bearer ' + 'YYYY' },
                //token: auth_data.token,
                success: function(response) {
                    console.log(response);
                    var options = response.result.services;

                    jQuery('#service_id_select').empty();
                
                    jQuery.each(options, function(i, p) {
                        jQuery('#service_id_select').append(jQuery('<option></option>').val(p.serviceId).html(p.serviceName));
                        p.specificRequirements.forEach(function(object2) {
                            console.log(object2.key);                        
                            let type = document.createElement('label'); 
                            type.setAttribute("class","col-sm-3 control-label");
                            type.appendChild(document.createTextNode(object2.key)); 
                            document.getElementById("required_services").appendChild(type);

                            let input = document.createElement("input");
                            input.type = "text";
                            input.name = object2.key;
                            input.setAttribute("id", "req-" + object2.key);
                            input.setAttribute("class", "form-control");

                            let div_input = document.createElement('div');
                            div_input.setAttribute("class", "col-sm-9");
                            div_input.appendChild(input);

                            let div = document.createElement('div');
                            div.setAttribute("class", "col-sm-12");
                            div.appendChild(type);
                            div.appendChild(div_input);
                            document.getElementById("required_services").appendChild(div);
                        });
                    });
                },
                error: function(response) {
                    alert('An error occurred getting services for GDF.');
                    jQuery("#review_order_link").prop("disabled", true);
                }
            });
        }
    }

    function get_facility_order_status(){
        var order_id = document.getElementById('genotyping_vendor_order_id_tab').innerHTML;
        var facility = document.getElementById('genotyping_facility_tab').innerHTML;
        var status;

        if(order_id){
            var auth_data = new Object();
            auth_data = get_genotyping_server_credentials();

            if (auth_data.error) {
                alert("Genotyping server credentials are not available. Stop.");
                return;
            }

            var access_token;
            if (auth_data.token){
                access_token = auth_data.token;
            } else {
                access_token = genotyping_facility_login(auth_data);
            }

            var facility_url = get_facility_url(facility);        

            if (facility_url){
                var url = facility_url + '/brapi/v2/vendor/orders/' + order_id + '/status';

                auth_data.token = access_token;

                jQuery.ajax({
                    url: url,
                    type: 'GET',
                    headers: {"Authorization": 'Bearer ' + 'YYYY' },
                    success: function(response) {
                        status = response.result.status;       
                        jQuery('#genotyping_trial_status_info').html(status);
                        if ( status == 'completed'){
                            get_facility_vcf(order_id,facility_url);
                        }
                    },
                    error: function(response) {
                        alert("An error occurred trying to get the order status.");
                    }
                });
            }
        }
        return status;
    }

    function get_facility_vcf(order_id,facility_url){

            if (facility_url){
                var url = facility_url + '/brapi/v2/vendor/orders/' + order_id + '/results';
                jQuery.ajax({
                    url: url,
                    type: 'GET',
                    headers: {"Authorization": 'Bearer ' + 'YYYY' },
                    success: function(response) {
                        var data = response.result.data;
                        var links = "";
                        data.forEach(function (item) { 
                            links += "<b>File Name:</b> " + item.fileName + "<br>" + 
                                    "<b>File url:</b> " + item.fileURL + "<br>" +
                                    "<b>md5sum:</b> " + item.md5sum + "<br><br>";
                        });
                        jQuery('#raw_data_tab').html(links);
                    },
                    error: function(response) {

                    }
                });
            }

    }

    function get_facility_url(name){

        if (name == 'Cornell IGD'){
            return 'https://test-server.brapi.org';
        } else if (name == 'dart'){
            return 'https://test-server.brapi.org';
        } else if (name == 'BGI'){
            return 'https://test-server.brapi.org';
        } else if (name == 'Intertek'){
            return 'https://test-server.brapi.org';
        } else {
            alert("Invalid genotyping facility.");
            return;
        }
    }

    jQuery('#facility_info_link').click(function () {
        get_facility_services_id(); 
    });

    jQuery('#genotyping_trial_facility_submit_select').on('change', function() {
         
        jQuery("#submit_plate_btn").prop("disabled", this.value == 1);
    });

    jQuery('#genotyping_facilities_section_onswitch').click( function() {
        var order_id = document.getElementById('genotyping_vendor_order_id_tab').innerHTML;
        if(order_id){
            jQuery('#genotyping_facility_submitted_tab').html("yes");
            jQuery('#submit_plate_link').attr("disabled", true);
            get_facility_order_status();
        } else {
            jQuery('#genotyping_facility_submitted_tab').html("no");
            jQuery('#submit_plate_link').attr("disabled", false);
        }
        
    });

});

function edit_genotyping_trial_details(){

    jQuery('[id^="edit_genotyping_"]').change(function (){
        var this_element = jQuery(this);
        highlight_changed_details(this_element);
    });

    //save dialog body html for resetting on close
    var edit_details_body_html = document.getElementById('genotyping_trial_details_edit_body').innerHTML;

    //populate breeding_program dropdown and save default
    var default_bp = document.getElementById("edit_genotyping_trial_breeding_program").getAttribute("value");
    get_select_box('breeding_programs', 'edit_genotyping_trial_breeding_program', { 'default' : default_bp });
    jQuery('#edit_trial_breeding_program').data("originalValue", default_bp);

    jQuery('#edit_genotyping_trial_details_cancel_button').click(function(){
        reset_dialog_body('genotyping_trial_details_edit_body', edit_details_body_html);
    });

    jQuery('#save_genotyping_trial_details').click(function(){
        var changed_elements = document.getElementsByName("changed");
        var categories = [];
        var new_details = {};
        var success_message = '';
        for(var i=0; i<changed_elements.length; i++){
            var id = changed_elements[i].id;
            var type = changed_elements[i].title;
            var new_value = changed_elements[i].value;
            categories.push(type);
            new_details[type] = new_value;
            if(jQuery('#'+id).is("select")){
                new_value = changed_elements[i].options[changed_elements[i].selectedIndex].text
            }
            success_message += "<li class='list-group-item list-group-item-success'> Changed "+type+" to: <b>"+new_value+"</b></li>";
        }

        save_genotyping_trial_details(categories, new_details, success_message);

    });

    jQuery('#genotyping_trial_details_error_close_button').click( function() {
        document.getElementById('trial_details_error_message').innerHTML = "";
    });

    jQuery('#genotyping_trial_details_saved_close_button').click( function() {
        location.reload();
    });

}

function save_genotyping_trial_details (categories, details, success_message) {
  var trial_id = get_trial_id();
  jQuery.ajax( {
    url: '/ajax/breeders/trial/'+trial_id+'/details/',
    type: 'POST',
    data: { 'categories' : categories, 'details' : details },

    success: function(response) {
      if (response.success) {
        document.getElementById('genotyping_trial_details_saved_message').innerHTML = success_message;
        jQuery('#genotyping_trial_details_saved_dialog').modal("show");
        return;
      }
      else {
        document.getElementById('genotyping_trial_details_error_message').innerHTML = "<li class='list-group-item list-group-item-danger'>"+response.error+"</li>";
        jQuery('#genotyping_trial_details_error_dialog').modal("show");
      }
    },
    error: function(response) {
      document.getElementById('genotyping_trial_details_error_message').innerHTML = "<li class='list-group-item list-group-item-danger'> Trial detail update AJAX request failed. Update not completed.</li>";
      jQuery('#genotyping_trial_details_error_dialog').modal("show");
    },
  });
}


function save_replace_well_accession () {
    var trial_id = get_trial_id();

    var new_accession = jQuery('#new_cell_accession').val();
    var old_accession = jQuery('#cell_accession').html();
    var old_plot_id = jQuery('#plot_id').html();
    var old_plot_name = jQuery('#plot_name').html();

    var yes = confirm("Are you sure you want to replace accession "+ old_accession +" with "+ new_accession +" in sample " + old_plot_name + " ?");
    if (yes) {
        jQuery('#replace_plate_accessions_dialog').modal("hide");
        jQuery('#working_modal').modal("show");

        new jQuery.ajax({
            type: 'POST',
            url: '/ajax/breeders/trial/'+trial_id+'/replace_well_accessions',
            dataType: "json",
            data: {
                    'new_accession': new_accession,
                    'old_accession': old_accession,
                    'old_plot_id': old_plot_id,
                    'old_plot_name': old_plot_name,
            },

            success: function (response) {
              jQuery('#working_modal').modal("hide");

              if (response.error) {
                alert("Error Replacing Plot Accession: "+response.error);
              }
              else {
                jQuery('#replace_accessions_dialog_message').modal("show");
              }
            },
            error: function () {
              jQuery('#working_modal').modal("hide");
              alert('An error occurred replacing plot accession');
            }
        });
    }
}



function close_message_dialog () {
    location.reload();
}