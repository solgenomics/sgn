/*jslint browser: true, devel: true */

/**

=head1 Trial.js

Display for managing genotyping trials


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
        var html = l.listSelect('accession_select_box', [ 'accessions', 'plots', 'plants', 'tissue_samples' ]);
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

    function submit_plate_to_gdf(brapi_plate_data) {
        console.log(brapi_plate_data);
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

        if (access_token) {
            auth_data.token = access_token;

            alert("Sending genotyping experiment entry to genotyping facility...");

            $.ajax( { 
                url: auth_data.host+'/brapi/v2/plate-register',
                method: 'POST',
                data: {
                    token: auth_data.token,
                    plates: [
                        brapi_plate_data
                    ]
                },
                success: function(response) {
                    console.log(response);
                    if (response.metadata.status) {
                        alert(response.metadata.status);
                    }
                    else {
                        alert("Successfully submitted the plate to GDF.");
                    }
                }
            });
        }
    }

    function load_genotyping_status_info(auth_data, plate_id) {
        $.ajax({
            url: auth_data.host+'/brapi/v1/plate/'+plate_id,
            success: function(response) {

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
        //console.log(plate_data);
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
        if (selected == 'igd'){
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
                        jQuery.ajax({
                            url: '/ajax/breeders/trial/'+trial_id+'/delete/entry',
                            beforeSend: function(){
                                jQuery('#working_msg').html("Removing the project entry...");
                            },
                            success: function(response) {
                                jQuery('#working_modal').modal("hide");
                                jQuery('#working_msg').html('');
                                if (response.error) {
                                    alert(response.error);
                                }
                                else {
                                    alert('The project entry has been deleted.'); // to do: give some idea how many items were deleted.
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
            if (response.error) {
                alert(response.error);
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
            }
            if (response.success) {
                Workflow.complete('#upload_genotype_submit');
                Workflow.focus("#upload_genotypes_workflow", -1); //Go to success page
            }
        }
    });

});
