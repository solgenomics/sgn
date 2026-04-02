/**
* functions for powering the upload factory
* page at /breeders/upload
*
* @author Ryan Preble <rsp98@cornell.edu>
*
*/

var upload_type_dict = {
    'trials' : "Multiple Trial Upload",
    'trial_metadata' : "Trial Metadata",
    'trial_additional_file' : "Trial Additional File",
    'plants_by_name' : "Plants by name",
    'plants_by_index' : "Plants by index number",
    'plants_per_plot' : "Plants by number of plants per plot",
    'subplot_plants_by_name' : "Subplot plants by name",
    'subplot_plants_by_index' : "Subplot plants by index number",
    'plants_per_subplot' : "Plants by number of plants per subplot",
    'subplots_by_name' : "Subplots by name",
    'subplots_by_index' : "Subplots by index number",
    'subplots_per_plot' : "Subplots by number of subplots per plot",
    'genotyping_plate_excel' : "Genotyping plate design made in Excel",
    'genotyping_plate_default_android' : "Default Coordinate Android Application plate design",
    'genotyping_plate_custom_android' : "Custom Coordinate Android Application plate design",
    'genotype_data_vcf' : "VCF genotyping data",
    'genotype_data_tassel' : "Tassel HDF5 genotyping data",
    'genotype_data_intertek' : "Intertek genotyping data",
    'genotype_data_kasp' : "KASP genotyping data",
    'genotype_data_ssr' : "SSR genotyping data",
    'locations' : "Locations",
    'accessions' : "Accessions",
    'seedlots' : "Seedlots",
    'seedlot_inventory' : "Seedlot inventory",
    'seedlots_exist_to_exist' : "Transact existing seedlots to existing seedlots",
    'seedlots_exist_to_new' : "Transact existing seedlots to new seedlots",
    'seedlots_exist_to_plots' : "Transact existing seedlots to plots",
    'seedlots_exist_to_unspecified' : "Transact existing seedlots to unspecified seeds/plots",
    'pedigrees' : "Pedigrees",
    'crosses' : "Crosses",
    'gps_polygon' : "GPS coordinate polygons",
    'gps_point' : "GPS coordinate points",
    'spatial_layout' : "Trial spatial layout",
    'change_accessions' : "Accession swap",
    'entry_numbers' : "Entry numbers",
    'new_progenies' : 'Progeny relationships for new accessions',
    'existing_progenies' : 'Progeny relationships for existing accessions',
    'family_names' : 'Family names of existing crosses',
    'phenotyping_spreadsheet' : "Phenotyping spreadsheet",
    'fieldbook_phenotypes' : "Field Book phenotypes",
    'datacollector_spreadsheet' : "Datacollector spreadsheet",
    'nirs' : "NIRS data",
    'metabolomics' : "Metabolomic data",
    'transcriptomics' : "Transcriptomic data",
    'images' : "Images",
    'images_barcodes' : "Images with barcodes",
    'images_phenotypes' : "Images with associated phenotypes",
    'soil_data' : "Soil data",
    'vectors' : "Vector constructs",
    'treatments' : "Treatments"
};

export var archived_files_list = [];

export var job_dict = {};

export function load_archived_files_table(user_id) {

    jQuery.ajax({
        url: '/ajax/tools/documents/user_archive/',
        type : 'POST',
        data : {
            user_id: user_id
        },
        success: function(response) {
            if (response.error) {
                alert(response.error);
            } else {
                
                if (jQuery.fn.dataTable && jQuery.fn.dataTable.isDataTable('#upload_factory_archived_files_table')) {
                    let dt = jQuery('#upload_factory_archived_files_table').DataTable();
                    dt.clear().destroy();
                }

                let header_row = jQuery('<tr>');
                header_row.append(jQuery('<th>').text("Timestamp"));
                header_row.append(jQuery('<th>').text("File Name"));

                if (response.data.length > 0 && response.data[0].hasOwnProperty('user_id')) {
                    header_row.append(jQuery('<th>').text("Uploader"));
                }

                header_row.append(jQuery('<th>').text("Upload As"));
                header_row.append(jQuery('<th>').text("Check formatting rules"));
                //header_row.append(jQuery('<th>').text("Delete"));
                header_row.append(jQuery('<th>').text("Process File"));

                jQuery('#upload_factory_archived_files_table').html('<thead></thead><tbody></tbody><tfoot></tfoot>')

                let file_tbody = jQuery('#upload_factory_archived_files_table tbody');
                let file_thead = jQuery('#upload_factory_archived_files_table thead');
                let file_tfoot = jQuery('#upload_factory_archived_files_table tfoot');

                file_thead.append(header_row);

                archived_files_list = response.data;

                if (response.data.length > 0 ) {

                    response.data.forEach(row => {
                        let tr = jQuery("<tr>");
                        tr.append(jQuery("<td>").html("<div id='file_timestamp_"+row.file_id+"'>"+row.timestamp+"</div>"));
                        tr.append(jQuery("<td>").html("<a id='file_name_"+row.file_id+"' href='/breeders/phenotyping/download/"+row.file_id+"'>"+row.filename+"</a> &nbsp; | &nbsp; <a target='_blank' href='/breeders/phenotyping/view/"+row.file_id+"'>View</a>"));
                        if (response.data[0].hasOwnProperty('user_id')) {
                            tr.append(jQuery("<td>").html("<a href='/solpeople/profile/"+row.user_id+"'>"+row.user_name+"</a>"));
                        }
                        tr.append(jQuery("<td>").html("<select class='form-control form-control-sm upload-type-select' id='upload_select_type_"+row.file_id+"'>"+upload_type_options().replace(`value='${row.type}'`, `value='${row.type}' selected`)+"</select>"));
                        if (row.type != null && row.type != "" && row.type != "null_choice") {
                            tr.append(jQuery("<td>").html("<button class='btn btn-sm btn-primary check-format-btn' id='check_format_"+row.file_id+"'>Check format</button>"));
                        } else {
                            tr.append(jQuery("<td>").html("<button class='btn btn-sm btn-primary check-format-btn' id='check_format_"+row.file_id+"'disabled>Check format</button>"));
                        }
                        //tr.append(jQuery("<td>").html("<button class='btn btn-danger'><span class="glyphicon glyphicon-trash"></span></button>"));
                        tr.append(jQuery("<td>").html("<button class='btn btn-success process-file-btn' id='process_file_"+row.file_id+"'><span class='glyphicon glyphicon-play-circle'></span></button>"));
                        file_tbody.append(tr);
                    });
                } 

                let archived_files = jQuery('#upload_factory_archived_files_table').DataTable({
                    order : [[0, 'desc']]
                });
            }
        },
        error : function() {
            alert("Something went terribly wrong, check console.");
        }
    });
}

function load_in_progress_validations_table(user_id) {
    jQuery.ajax({
        url: '/ajax/job/validations_in_progress/' + user_id,
        beforeSend: function() {
            jQuery('#validation-loading-spinner').show();
            jQuery('#upload_factory_validated_files_table').hide();
        },
        success: function(response) {
            if (response.error) {
                alert(response.error);
            } else {

                if (jQuery.fn.dataTable && jQuery.fn.dataTable.isDataTable('#upload_factory_validated_files_table')) {
                    let dt = jQuery('#upload_factory_validated_files_table').DataTable();
                    dt.clear().destroy();
                }

                let header_row = jQuery('<tr>');
                header_row.append(jQuery('<th>').text("Start Time"));
                header_row.append(jQuery('<th>').text("Upload Name"));

                if (response.data.length > 0 && response.data[0].hasOwnProperty('user_id')) {
                    header_row.append(jQuery('<th>').text("Uploader"));
                }

                header_row.append(jQuery('<th>').text("Uploaded As"));
                header_row.append(jQuery('<th>').text("Status"));
                header_row.append(jQuery('<th>').text("Actions"));

                jQuery('#upload_factory_validated_files_table').html('<thead></thead><tbody></tbody><tfoot></tfoot>');

                let file_tbody = jQuery('#upload_factory_validated_files_table tbody');
                let file_thead = jQuery('#upload_factory_validated_files_table thead');
                let file_tfoot = jQuery('#upload_factory_validated_files_table tfoot');

                file_thead.append(header_row);

                if (response.data.length > 0 ) {

                    jQuery("#in_progress_validations_table_section_onswitch").trigger("click");

                    response.data.forEach(row => {
                        job_dict[row.job_id] = row;
                        let tr = jQuery("<tr>");
                        tr.append(jQuery("<td>").html(`${row.create_timestamp}`));
                        tr.append(jQuery("<td>").html(`<div id='job_${row.job_id}'>${row.args.name}</div>`));
                        if (response.data[0].hasOwnProperty('user_id')) {
                            tr.append(jQuery("<td>").html(`<a href='/solpeople/profile/${row.user_id}'>${row.args.additional_args?.user_name}</a>`));
                        }
                        tr.append(jQuery("<td>").html(`<div>${upload_type_dict[row.args.additional_args?.file_type]}</div>`));
                        tr.append(jQuery("<td>").html(`<div>${row.status}</div>`));
                        let commit_validation_btn = '';
                        let cancel_btn = '';
                        let view_report_btn = '';
                        let dismiss_btn = '';
                        if (row.status != "submitted") {
                            dismiss_btn = `<button id='dismiss_job_${row.job_id}' class='btn btn-sm btn-danger job-dismiss-btn'>Dismiss</button>`;
                        }
                        if (row.status != 'submitted' && row.status != 'timed_out' && row.status != 'canceled') {
                            view_report_btn = `<button id='job_report_${row.job_id}' class='btn btn-sm btn-primary view-report-btn'>View Report</button>`; //this could be fail status
                            if (row.status == "finished") { //only show commit button on a success
                                commit_validation_btn = `<button id='validation_commit_${row.job_id}' class='btn btn-sm btn-success validation-commit-btn'>Commit to Database</button>`;
                            }
                        }
                        if (row.status == 'submitted') {
                            cancel_btn = `<button id='cancel_job_${row.job_id}' class='btn btn-sm btn-danger job-cancel-btn'>Cancel</button>`;
                        }
                        tr.append(jQuery("<td>").html(`${view_report_btn} ${commit_validation_btn} ${dismiss_btn} ${cancel_btn}`));
                        file_tbody.append(tr);
                    });
                } else {
                    jQuery("#in_progress_validations_table_section_offswitch").trigger("click");
                }

                jQuery('#validation-loading-spinner').hide();
                jQuery('#upload_factory_validated_files_table').show();

                let uploads_in_progress = jQuery('#upload_factory_validated_files_table').DataTable({
                    order : [[0, 'desc']]
                });
            }
        },
        error : function() {
            alert("Something went terribly wrong, check console.");
        }
    });
}

function load_in_progress_uploads_table(user_id) {
    jQuery.ajax({
        url: '/ajax/job/uploads_in_progress/'+user_id,
        beforeSend: function() {
            jQuery('#uploads-loading-spinner').show();
            jQuery('#upload_factory_in_progress_uploads_table').hide();
        },
        success: function(response) {
            if (response.error) {
                alert(response.error);
            } else {

                if (jQuery.fn.dataTable && jQuery.fn.dataTable.isDataTable('#upload_factory_in_progress_uploads_table')) {
                    let dt = jQuery('#upload_factory_in_progress_uploads_table').DataTable();
                    dt.clear().destroy();
                }

                let header_row = jQuery('<tr>');
                header_row.append(jQuery('<th>').text("Start Time"));
                header_row.append(jQuery('<th>').text("Upload Name"));

                if (response.data.length > 0 && response.data[0].hasOwnProperty('user_id')) {
                    header_row.append(jQuery('<th>').text("Uploader"));
                }

                header_row.append(jQuery('<th>').text("Uploaded As"));
                header_row.append(jQuery('<th>').text("Status"));
                header_row.append(jQuery('<th>').text("Actions"));

                jQuery('#upload_factory_in_progress_uploads_table').html('<thead></thead><tbody></tbody><tfoot></tfoot>');

                let file_tbody = jQuery('#upload_factory_in_progress_uploads_table tbody');
                let file_thead = jQuery('#upload_factory_in_progress_uploads_table thead');
                let file_tfoot = jQuery('#upload_factory_in_progress_uploads_table tfoot');

                file_thead.append(header_row);

                if (response.data.length > 0 ) {

                    jQuery("#in_progress_uploads_table_section_onswitch").trigger("click");

                    response.data.forEach(row => {
                        job_dict[row.job_id] = row;
                        let tr = jQuery("<tr>");
                        tr.append(jQuery("<td>").html(`${row.create_timestamp}`));
                        tr.append(jQuery("<td>").html(`<div id='job_${row.job_id}'>${row.args.name}</div>`));
                        if (response.data[0].hasOwnProperty('user_id')) {
                            tr.append(jQuery("<td>").html(`<a href='/solpeople/profile/${row.user_id}'>${row.args.additional_args?.user_name}</a>`));
                        }
                        tr.append(jQuery("<td>").html(`<div>${upload_type_dict[row.args.additional_args?.file_type]}</div>`));
                        tr.append(jQuery("<td>").html(`<div>${row.status}</div>`));
                        let cancel_btn = '';
                        let dismiss_btn = '';
                        if (row.status != "submitted") {
                            dismiss_btn = `<button id='dismiss_job_${row.job_id}' class='btn btn-sm btn-danger job-dismiss-btn'>Dismiss</button>`;
                        }
                        if (row.status == 'submitted') {
                            cancel_btn = `<button id='cancel_job_${row.job_id}' class='btn btn-sm btn-danger job-cancel-btn'>Cancel</button>`;
                        }
                        tr.append(jQuery("<td>").html(`${dismiss_btn} ${cancel_btn}`));
                        file_tbody.append(tr);
                    });
                } else {
                    jQuery("#in_progress_uploads_table_section_offswitch").trigger("click");
                }

                jQuery('#uploads-loading-spinner').hide();
                jQuery('#upload_factory_in_progress_uploads_table').show();

                let uploads_in_progress = jQuery('#upload_factory_in_progress_uploads_table').DataTable({
                    order : [[0, 'desc']]
                });
            }
        },
        error : function() {
            alert("Something went terribly wrong, check console.");
        }
    });
}

function load_completed_uploads_table(user_id) {
    jQuery.ajax({
        url: '/ajax/job/completed_uploads/'+user_id,
        beforeSend: function() {
            jQuery('#completed-loading-spinner').show();
            jQuery('#upload_factory_completed_uploads_table').hide();
        },
        success: function(response) {
            if (response.error) {
                alert(response.error);
            } else {

                if (jQuery.fn.dataTable && jQuery.fn.dataTable.isDataTable('#upload_factory_completed_uploads_table')) {
                    let dt = jQuery('#upload_factory_completed_uploads_table').DataTable();
                    dt.clear().destroy();
                }

                let header_row = jQuery('<tr>');
                header_row.append(jQuery('<th>').text("Start Time"));
                header_row.append(jQuery('<th>').text("Upload Name"));

                if (response.data.length > 0 && response.data[0].hasOwnProperty('user_id')) {
                    header_row.append(jQuery('<th>').text("Uploader"));
                }

                header_row.append(jQuery('<th>').text("Uploaded As"));
                header_row.append(jQuery('<th>').text("Status"));
                header_row.append(jQuery('<th>').text("Actions"));

                jQuery('#upload_factory_completed_uploads_table').html('<thead></thead><tbody></tbody><tfoot></tfoot>');

                let file_tbody = jQuery('#upload_factory_completed_uploads_table tbody');
                let file_thead = jQuery('#upload_factory_completed_uploads_table thead');
                let file_tfoot = jQuery('#upload_factory_completed_uploads_table tfoot');

                file_thead.append(header_row);

                if (response.data.length > 0 ) {

                    jQuery("#completed_uploads_table_section_onswitch").trigger("click");

                    response.data.forEach(row => {
                        job_dict[row.job_id] = row;
                        let tr = jQuery("<tr>");
                        tr.append(jQuery("<td>").html(`${row.create_timestamp}`));
                        tr.append(jQuery("<td>").html(`<div id='job_${row.job_id}'>${row.args.name}</div>`));
                        if (response.data[0].hasOwnProperty('user_id')) {
                            tr.append(jQuery("<td>").html(`<a href='/solpeople/profile/${row.user_id}'>${row.args.additional_args?.user_name}</a>`));
                        }
                        tr.append(jQuery("<td>").html(`<div>${upload_type_dict[row.args.additional_args?.file_type]}</div>`));
                        tr.append(jQuery("<td>").html(`<div>${row.status}</div>`));
                        let view_report_btn = '';
                        let dismiss_btn = `<button id='dismiss_job_${row.job_id}' class='btn btn-sm btn-danger job-dismiss-btn'>Dismiss</button>`;
                        if (row.status == 'finished' || row.status == 'failed') {
                            view_report_btn = `<button id='job_report_${row.job_id}' class='btn btn-sm btn-primary view-report-btn'>View Report</button>`;
                        }
                        tr.append(jQuery("<td>").html(`${view_report_btn} ${dismiss_btn}`));
                        file_tbody.append(tr);
                    });
                } else {
                    jQuery("#completed_uploads_table_section_offswitch").trigger("click");
                }

                jQuery('#completed-loading-spinner').hide();
                jQuery('#upload_factory_completed_uploads_table').show();

                let uploads_in_progress = jQuery('#upload_factory_completed_uploads_table').DataTable({
                    order : [[0, 'desc']]
                });
            }
        },
        error : function() {
            alert("Something went terribly wrong, check console.");
        }
    });
}

export function refresh_upload_tables(user_id) {
    load_in_progress_validations_table(user_id)
    load_in_progress_uploads_table(user_id);
    load_completed_uploads_table(user_id);
}

export function process_file(file_data, upload_type, config) {

    jQuery('#upload_type_choices_div').html('');

    switch(upload_type) {
        case 'trials' :
        case 'trial_metadata' :
            populate_validate_submit_data(upload_type, file_data);
            break;
        case 'trial_additional_file' :
            display_trial_additional_file_upload_choices();
            jQuery('#trial_additional_file_upload_next_btn').on('click', {file_data : file_data}, populate_trial_additional_file_validate_submit_data);
            get_select_box('breeding_programs', 'trial_additional_file_breeding_program_select_div', { 'name' : 'trial_additional_file_breeding_program_id', 'id' : 'trial_additional_file_breeding_program_id', 'empty': 1 });
            jQuery('#trial_additional_file_breeding_program_select_div').on('change', function () {
                let breeding_program_id = jQuery("#trial_additional_file_breeding_program_id").val();
                if (breeding_program_id != null && breeding_program_id != '') {
                    get_select_box('trials', 'trial_additional_file_trial_select_div', { 'name' : 'trial_additional_file_trial_id', 'id' : 'trial_additional_file_trial_id', 'breeding_program_id' : breeding_program_id, 'empty':1});
                } else {
                    jQuery('#trial_additional_file_trial_select_div').html('');
                }
            });
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'genotyping_plate' : 
            display_genotyping_plate_upload_choices();
            jQuery('#genotype_plate_choices_next_btn_div').show();
            jQuery('#genotype_plate_upload_choices_next_btn').on('click', {file_data : file_data}, populate_genotyping_plate_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'genotyping_data' : 
            display_genotyping_data_upload_choices();
            jQuery('#genotype_data_choices_next_btn_div').show();
            jQuery('#genotype_data_project_select_div').show();
            jQuery('#genotype_data_protocol_select_div').show();
            let dt = jQuery('#genotype_data_project_select').DataTable();
            dt.clear().destroy();
            jQuery('#genotype_data_project_select').DataTable( {
                'ajax': {
                    'url':'/ajax/genotyping_data/projects?select_checkbox_name=upload_genotyping_data_project_select',
                },
            });
            dt = jQuery('#genotype_data_protocol_select').DataTable();
            dt.clear().destroy();
            jQuery('#genotype_data_protocol_select').DataTable( {
                'ajax': {
                    'url':'/ajax/genotyping_data/protocols?select_checkbox_name=upload_genotyping_data_protocol_select',
                },
            });
            // also populate the select dropdown with the file choices
            let intertek_info_select = jQuery('#genotype_data_intertek_info_select');
            intertek_info_select.empty();
            archived_files_list.forEach(item => {
                const opt = jQuery('<option></option>').val(item.file_id).text(item.filename);
                intertek_info_select.append(opt);
            });
            jQuery('#genotype_data_upload_type_choice_select').on('change', display_genotyping_data_upload_additional_choices);
            jQuery('#genotype_data_upload_choices_next_btn').on('click', {file_data : file_data}, populate_genotyping_data_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'locations' : 
            populate_validate_submit_data(upload_type, file_data);
            break;
        case 'accessions' : 
            display_accession_upload_choices(config.user_role);
            jQuery('#accession_upload_choices_next_btn').on('click', {file_data : file_data}, populate_accession_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        // case 'populations' : 
        //     //
        //     break;
        case 'seedlots' : 
            display_seedlot_upload_choices(config.default_seedlot_material_type);
            jQuery('.seedlot-upload-options').each(function() {
                jQuery(this).show();
            });
            get_select_box('material_types', 'upload_seedlot_material_type_div', { 'name' : 'upload_seedlot_material_type', 'id' : 'upload_seedlot_material_type' });
            get_select_box('breeding_programs', 'upload_seedlot_breeding_program_div', { 'name' : 'upload_seedlot_breeding_program_id', 'id' : 'upload_seedlot_breeding_program_id' });
            jQuery('#seedlot_upload_choices_next_btn').on('click', {file_data : file_data}, populate_seedlot_validate_submit_data);
            jQuery("#upload_seedlot_location").autocomplete({
                source: '/ajax/stock/geolocation_autocomplete'
            });
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'seedlot_inventory' : 
            populate_validate_submit_data(upload_type, file_data);
            break;
        case 'seedlot_transaction' : 
            display_seedlot_transaction_choices();
            jQuery('#seedlot_transaction_next_btn_div').show();
            jQuery('#seedlot_transaction_next_btn').on('click', {file_data : file_data}, populate_seedlot_transaction_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'pedigrees' : 
            populate_validate_submit_data(upload_type, file_data);
            break;
        case 'crosses' : 
            display_cross_upload_choices();
            jQuery('#cross_upload_next_btn').on('click', {file_data : file_data}, populate_cross_validate_submit_data);
            get_select_box('breeding_programs', 'upload_crosses_breeding_program_select_div', { 'name' : 'upload_crosses_breeding_program_id', 'id' : 'upload_crosses_breeding_program_id', 'empty': 1 });
            jQuery('#upload_crosses_breeding_program_select_div').on('change', function () {
                let breeding_program_id = jQuery("#upload_crosses_breeding_program_id").val();
                if (breeding_program_id != null && breeding_program_id != '') {
                    get_select_box('projects', 'upload_crosses_crossing_experiment_select_div', { 'name' : 'upload_crosses_crossing_experiment_id', 'id' : 'upload_crosses_crossing_experiment_id', 'breeding_program_id' : breeding_program_id, 'get_crossing_trials': '1', 'empty':1});
                } else {
                    jQuery('#upload_crosses_crossing_experiment_select_div').html('');
                }
            });
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'new_progenies' : 
            populate_validate_submit_data(upload_type, file_data);
            break;
        case 'existing_progenies' : 
            populate_validate_submit_data(upload_type, file_data);
            break;
        case 'family_names' : 
            display_family_names_upload_choices();
            jQuery('#family_names_upload_next_btn').on('click', {file_data:file_data}, populate_family_names_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'phenotyping_spreadsheet' : 
            display_phenotyping_spreadsheet_upload_choices();
            jQuery('#phenotyping_spreadsheet_upload_next_btn').on('click', {file_data:file_data}, populate_phenotyping_spreadsheet_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'fieldbook_phenotypes' : 
            display_fieldbook_upload_choices();
            jQuery('#fieldbook_upload_next_btn').on('click', {file_data:file_data}, populate_fieldbook_validate_submit_data);
            let fieldbook_zipfile_select = jQuery('#upload_fieldbook_images_select');
            archived_files_list.forEach(item => {
                if (item.filename.includes(".zip")) {
                    const opt = jQuery('<option></option>').val(item.file_id).text(item.filename);
                    fieldbook_zipfile_select.append(opt);
                }
            });
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'datacollector_spreadsheet' : 
            display_datacollector_spreadsheet_upload_choices();
            jQuery('#datacollector_spreadsheet_upload_next_btn').on('click', {file_data:file_data}, populate_datacollector_spreadsheet_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'treatments' : 
            display_phenotyping_spreadsheet_upload_choices()
            jQuery('#phenotyping_spreadsheet_upload_next_btn').on('click', {file_data:file_data}, populate_treatment_spreadsheet_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'gps_coords' : 
            display_gps_upload_choices();
            get_select_box('breeding_programs', 'gps_breeding_program_select_div', { 'name' : 'gps_breeding_program_id', 'id' : 'gps_breeding_program_id', 'empty': 1 });
            jQuery('#gps_breeding_program_select_div').on('change', function () {
                let breeding_program_id = jQuery("#gps_breeding_program_id").val();
                if (breeding_program_id != null && breeding_program_id != '') {
                    get_select_box('trials', 'gps_trial_select_div', { 'name' : 'gps_trial_id', 'id' : 'gps_trial_id', 'breeding_program_id' : breeding_program_id, 'empty':1});
                } else {
                    jQuery('#gps_trial_select_div').html('');
                }
            });
            jQuery('#gps_upload_next_btn').on('click', {file_data : file_data}, populate_gps_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'spatial_layout' : 
            populate_validate_submit_data(upload_type, file_data);
            break;
        case 'change_accessions' : 
            display_accession_change_upload_choices();
            get_select_box('breeding_programs', 'change_accessions_breeding_program_select_div', { 'name' : 'change_accessions_breeding_program_id', 'id' : 'change_accessions_breeding_program_id', 'empty': 1 });
            jQuery('#change_accessions_breeding_program_select_div').on('change', function () {
                let breeding_program_id = jQuery("#change_accessions_breeding_program_id").val();
                if (breeding_program_id != null && breeding_program_id != '') {
                    get_select_box('trials', 'change_accessions_trial_select_div', { 'name' : 'change_accessions_trial_id', 'id' : 'change_accessions_trial_id', 'breeding_program_id' : breeding_program_id, 'empty':1});
                } else {
                    jQuery('#change_accessions_trial_select_div').html('');
                }
            });
            jQuery('#change_accessions_upload_next_btn').on('click', {file_data : file_data}, populate_accession_change_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'entry_numbers' : 
            populate_validate_submit_data(upload_type, file_data);
            break;
        case 'nirs' : 
            display_nirs_upload_choices();
            get_select_box('high_dimensional_phenotypes_protocols','upload_nirs_protocol_select', {'checkbox_name':'upload_nirs_protocol_id', 'high_dimensional_phenotype_protocol_type':'high_dimensional_phenotype_nirs_protocol'});
            jQuery('#nirs_upload_next_btn').on('click', {file_data : file_data}, populate_nirs_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'metabolomics' : 
            display_metabolomics_upload_choices();
            get_select_box('high_dimensional_phenotypes_protocols','upload_metabolomics_protocol_select', {'checkbox_name':'upload_metabolomics_protocol_id', 'high_dimensional_phenotype_protocol_type':'high_dimensional_phenotype_metabolomics_protocol'});
            jQuery('#metabolomics_upload_file_format_select_div').hide();
            jQuery('#metabolomics_upload_next_btn_div').show();
            jQuery('#metabolomics_upload_next_btn').on('click', {file_data : file_data}, populate_metabolomics_validate_submit_data);
            let metabolomics_details_select = jQuery('#upload_metabolomics_details_select');
            archived_files_list.forEach(item => {
                const opt = jQuery('<option></option>').val(item.file_id).text(item.filename);
                metabolomics_details_select.append(opt);
            });
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'transcriptomics' : 
            display_transcriptomics_upload_choices();
            get_select_box('high_dimensional_phenotypes_protocols','upload_transcriptomics_protocol_select', {'checkbox_name':'upload_transcriptomics_protocol_id', 'high_dimensional_phenotype_protocol_type':'high_dimensional_phenotype_transcriptomics_protocol'});
            jQuery('#transcriptomics_upload_file_format_select_div').hide();
            jQuery('#transcriptomics_upload_next_btn_div').show();
            jQuery('#transcriptomics_upload_next_btn').on('click', {file_data : file_data}, populate_transcriptomics_validate_submit_data);
            let transcriptomics_details_select = jQuery('#upload_transcriptomics_details_select');
            archived_files_list.forEach(item => {
                const opt = jQuery('<option></option>').val(item.file_id).text(item.filename);
                transcriptomics_details_select.append(opt);
            });
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'images' : 
            display_images_upload_choices();
            let images_select = jQuery('#upload_images_select_more');
            archived_files_list.forEach(item => {
                if (item.filename.includes(".png") || item.filename.includes(".jpg") || item.filename.includes(".jpeg") || item.filename.includes(".webp") || item.filename.includes(".tif") || item.filename.includes(".tiff")) {
                    const opt = jQuery('<option></option>').val(item.file_id).text(item.filename);
                    images_select.append(opt);
                }
            });
            let pheno_select = jQuery('#upload_images_select_pheno');
            archived_files_list.forEach(item => {
                if (item.filename.includes(".xlsx") || item.filename.includes(".xls")) {
                    const opt = jQuery('<option></option>').val(item.file_id).text(item.filename);
                    pheno_select.append(opt);
                }
            });
            jQuery('#upload_images_type').on('change', display_images_additional_upload_choices);
            jQuery('#image_upload_next_btn').on('click', {file_data : file_data}, populate_image_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'soil_data' : 
            display_soil_data_upload_choices();
            jQuery('#soil_data_upload_next_btn').on('click', {file_data : file_data}, populate_soil_data_validate_submit_data);
            jQuery('#soil_data_field_trial').autocomplete({
                source: '/ajax/trials/trial_autocomplete'
            });
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'vectors' : 
            display_vector_upload_choices(config.user_role);
            jQuery('#vector_upload_next_btn').on('click', {file_data : file_data}, populate_vector_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'subplots' : 
            display_subplot_upload_choices();
            get_select_box('breeding_programs', 'subplot_breeding_program_select_div', { 'name' : 'subplot_breeding_program_id', 'id' : 'subplot_breeding_program_id', 'empty': 1 });
            jQuery('#subplot_breeding_program_select_div').on('change', function () {
                let breeding_program_id = jQuery("#subplot_breeding_program_id").val();
                if (breeding_program_id != null && breeding_program_id != '') {
                    get_select_box('trials', 'subplot_trial_select_div', { 'name' : 'subplot_trial_id', 'id' : 'subplot_trial_id', 'breeding_program_id' : breeding_program_id, 'empty':1});
                } else {
                    jQuery('#subplot_trial_select_div').html('');
                }
            });
            jQuery('#subplots_per_plot_div').show();
            jQuery('#subplot_choices_next_btn_div').show();
            jQuery('#subplot_upload_choices_next_btn').on('click', {file_data : file_data}, populate_subplot_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'plants' : 
            display_plant_upload_choices();
            get_select_box('breeding_programs', 'plant_breeding_program_select_div', { 'name' : 'plant_breeding_program_id', 'id' : 'plant_breeding_program_id', 'empty': 1 });
            jQuery('#plant_breeding_program_select_div').on('change', function () {
                let breeding_program_id = jQuery("#plant_breeding_program_id").val();
                if (breeding_program_id != null && breeding_program_id != '') {
                    get_select_box('trials', 'plant_trial_select_div', { 'name' : 'plant_trial_id', 'id' : 'plant_trial_id', 'breeding_program_id' : breeding_program_id, 'empty':1});
                } else {
                    jQuery('#plant_trial_select_div').html('');
                }
            });
            jQuery('#plants_per_plot_div').show();
            jQuery('#plant_choices_next_btn_div').show();
            jQuery('#plant_upload_choices_next_btn').on('click', {file_data : file_data}, populate_plant_validate_submit_data);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        default :
            alert("Select an upload type.");
            break;
    }
    return;
}

export function display_upload_formats(upload_type, config) {

    jQuery('#upload_type_choices_div').html('');

    switch(upload_type) {
        case 'trials' :
            jQuery('#multiple_trial_upload_spreadsheet_info_dialog').modal("show");
            break;
        case 'trial_metadata' :
            jQuery('#trial_metadata_upload_spreadsheet_format_modal').modal("show");
            break;
        case 'trial_additional_file':
            jQuery('#trial_upload_additional_file_info_dialog').modal("show");
            break;
        case 'genotyping_plate' : 
            display_genotyping_plate_upload_choices();
            jQuery('#genotype_plate_upload_type_choice_select').on('change', display_genotyping_plate_upload_formats);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'genotyping_data' : 
            display_genotyping_data_upload_choices();
            jQuery('#genotype_data_upload_type_choice_select').on('change', display_genotyping_data_upload_formats);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'locations' : 
            jQuery('#location_file_upload_form_div').hide();
            jQuery('#upload_locations_dialog_submit_btn_div').hide();
            jQuery('#upload_locations_dialog').modal("show");
            break;
        case 'accessions' : 
            jQuery('#accessions_upload_spreadsheet_format_modal').modal("show");
            break;
        // case 'populations' : 
        //     //
        //     break;
        case 'seedlots' : 
            display_seedlot_upload_choices(config.default_seedlot_material_type);
            jQuery('#upload_seedlots_type_select').on('change', display_seedlot_upload_formats);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'seedlot_inventory' : 
            jQuery('#seedlot_upload_inventory_spreadsheet_info_dialog').modal("show");
            break;
        case 'seedlot_transaction' : 
            display_seedlot_transaction_choices();
            jQuery('#upload_seedlot_transaction_type_select').on('change', display_seedlot_transaction_upload_formats);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'pedigrees' : 
            jQuery('#pedigrees_upload_spreadsheet_info_dialog').modal("show");
            break;
        case 'crosses' : 
            jQuery('#cross_spreadsheet_info_dialog').modal("show");
            break;
        case 'new_progenies' : 
            jQuery('#upload_progenies_new_spreadsheet_info_dialog').modal("show");
            break;
        case 'existing_progenies' : 
            jQuery('#upload_progenies_exist_spreadsheet_info_dialog').modal("show");
            break;
        case 'family_names' : 
            jQuery('#upload_family_name_spreadsheet_info_dialog').modal("show");
            break;
        case 'phenotyping_spreadsheet' : 
            jQuery('#phenotype_upload_spreadsheet_info_dialog').modal("show");
            break;
        case 'datacollector_spreadsheet' : 
            jQuery('#phenotype_upload_datacollector_info_dialog').modal("show");
            break;
        case 'fieldbook_phenotypes' : 
            // nothing, there is no file format since the file has to be exported from the fieldbook app.
            break;
        case 'treatments' : 
            jQuery('#treatment_upload_spreadsheet_info_dialog').modal("show");
            break;
        case 'gps_coords' : 
            jQuery('#upload_plot_gps_spreadsheet_info_dialog').modal("show");
            break;
        case 'spatial_layout' : 
            jQuery('#trial_coord_upload_spreadsheet_info_dialog').modal("show");
            break;
        case 'change_accessions' : 
            jQuery('#change_accessions_upload_file_format').modal("show");
            break;
        case 'entry_numbers' : 
            jQuery('#trial_entry_numbers_upload_format').modal("show");
            break;
        case 'nirs' : 
            jQuery('#upload_nirs_spreadsheet_info_dialog').modal("show");
            break;
        case 'metabolomics' : 
            display_metabolomics_upload_choices();
            jQuery('#metabolomics_upload_type_choice_select').on('change', display_metabolomics_upload_formats);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'transcriptomics' : 
            display_transcriptomics_upload_choices();
            jQuery('#transcriptomics_upload_type_choice_select').on('change', display_transcriptomics_upload_formats);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'images' : 
            jQuery('#upload_images_info_dialog').modal("show");
            break;
        case 'soil_data' : 
            jQuery('#upload_soil_data_spreadsheet_format_dialog').modal("show");
            break;
        case 'vectors' : 
            jQuery('#vectors_upload_spreadsheet_format_modal').modal("show");
            break;
        case 'subplots' : 
            display_subplot_upload_choices();
            jQuery('#subplot_upload_type_choice_select').on('change', display_subplot_upload_formats);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        case 'plants' : 
            display_plant_upload_choices();
            jQuery('#plant_upload_type_choice_select').on('change', display_plant_upload_formats);
            jQuery('#upload_type_choice_dialog').modal("show");
            break;
        default :
            break;
    }
    return;
}

function display_validate_submit_modal(options) {
    let text = ""; 
    console.dir(options);
    for (let key in options) {
        if (key == "parameters_json") {
            console.dir(options[key]);
            jQuery('#upload_validation_parameters').html(options[key]);
        } else {
            text += "<b>" + key + ": </b>&nbsp; <p style='white-space:pre'>" + options[key] + "</p>";
        }
    }
    jQuery('#validate_upload_review_text').html(text);
    jQuery('#validate_upload_confirm_submit').modal("show");
}

function display_plant_upload_formats() {
    let plant_upload_type = jQuery('#plant_upload_type_choice_select').val();
    switch(plant_upload_type) {
        case 'plants_by_name' : 
            jQuery('#upload_plants_spreadsheet_info_dialog').modal("show");
            break;
        case 'plants_by_index' : 
            jQuery('#upload_plants_with_index_number_spreadsheet_info_dialog').modal("show");
            break;
        case 'plants_per_plot' : 
            jQuery('#upload_plants_with_num_plants_spreadsheet_info_dialog').modal("show");
            break;
        case 'subplot_plants_by_name' : 
            jQuery('#upload_plants_subplot_spreadsheet_info_dialog').modal("show");
            break;
        case 'subplot_plants_by_index' : 
            jQuery('#upload_plants_subplot_with_index_number_spreadsheet_info_dialog').modal("show");
            break;
        case 'plants_per_subplot' : 
            jQuery('#upload_plants_subplot_with_num_plants_spreadsheet_info_dialog').modal("show");
            break;
        default : 
            break;
    }
}

function display_subplot_upload_formats() {
    let subplot_upload_type = jQuery('#subplot_upload_type_choice_select').val();
    switch(subplot_upload_type) {
        case 'subplots_by_name' : 
            jQuery('#upload_subplots_spreadsheet_info_dialog').modal("show");
            break;
        case 'subplots_by_index' : 
            jQuery('#upload_subplots_with_index_number_spreadsheet_info_dialog').modal("show");
            break;
        case 'subplots_per_plot' : 
            jQuery('#upload_subplots_with_num_subplots_spreadsheet_info_dialog').modal("show");
            break;
        default : 
            break;
    }
}

function display_genotyping_plate_upload_formats() {
    let genotyping_plate_type = jQuery('#genotype_plate_upload_type_choice_select').val();
    switch (genotyping_plate_type) {
        case 'genotyping_plate_excel' : 
            jQuery('#genotyping_trial_layout_upload_spreadsheet_info_format_dialog').modal("show");
            break;
        case 'genotyping_plate_default_android' : 
            jQuery('#genotyping_trial_layout_upload_coordinate_info_format_dialog').modal("show");
            break; 
        case 'genotyping_plate_custom_android' : 
            jQuery('#genotyping_trial_layout_upload_coordinate_custom_info_format_dialog').modal("show");
            break;
        default:
            break;
    }
}

function display_genotyping_data_upload_formats() {
    let genotyping_data_type = jQuery('#genotype_data_upload_type_choice_select').val();
    switch (genotyping_data_type) {
        case 'genotype_data_vcf' : 
            jQuery('#upload_genotype_vcf_spreadsheet_info_format_dialog').modal("show");
            break;
        case 'genotype_data_tassel' : 
            jQuery('#upload_genotype_tassel_hdf5_spreadsheet_info_format_dialog').modal("show");
            break; 
        case 'genotype_data_intertek' : 
            jQuery('#upload_genotype_intertek_spreadsheet_info_format_dialog').modal("show");
            break;
        case 'genotype_data_ssr' : 
            jQuery('#upload_ssr_spreadsheet_info_dialog').modal("show");
            break;
        case 'genotype_data_kasp' : 
            jQuery('#upload_genotype_kasp_spreadsheet_info_format_dialog').modal("show");
            break;
        default:
            break;
    }
}

function display_seedlot_upload_formats() {
    let seedlot_upload_type = jQuery('#upload_seedlots_type_select').val();
    if (seedlot_upload_type == "from_accession") {
        jQuery('#seedlot_upload_spreadsheet_info_dialog').modal('show');
    } else if (seedlot_upload_type == "from_cross") {
        jQuery('#seedlot_upload_spreadsheet_harvested_info_dialog').modal('show');
    } else {
        return;
    }
}

function display_seedlot_transaction_upload_formats() {
    let seedlot_transaction_type = jQuery('#upload_seedlot_transaction_type_select').val();
    switch (seedlot_transaction_type) {
        case 'seedlots_exist_to_exist' :
            jQuery('#seedlots_to_seedlots_info_dialog').modal("show");
            break;
        case 'seedlots_exist_to_new' : 
            jQuery('#seedlots_to_new_seedlots_info_dialog').modal("show");
            break;
        case 'seedlots_exist_to_plots' : 
            jQuery('#seedlots_to_plots_info_dialog').modal("show");
            break;
        case 'seedlots_exist_to_unspecified' : 
            jQuery('#seedlots_to_unspecified_names_info_dialog').modal("show");
            break;
        default :
            break;
    }
    return;
}

function display_metabolomics_upload_formats() {
    let file_type = jQuery('#metabolomics_upload_type_choice_select').val();
    if (file_type == "metabolomics_spreadsheet"){
        jQuery('#upload_metabolomics_spreadsheet_info_dialog').modal("show");
    } else if (file_type == "metabolite_details") {
        jQuery('#upload_transcriptomics_metabolite_details_spreadsheet_info_dialog').modal("show");
    }
    return;
}

function display_transcriptomics_upload_formats() {
    let file_type = jQuery('#transcriptomics_upload_type_choice_select').val();
    if (file_type == "transcriptomics_spreadsheet"){
        jQuery('#upload_transcriptomics_spreadsheet_info_dialog').modal("show");
    } else if (file_type == "transcript_details") {
        jQuery('#upload_transcriptomics_transcript_details_spreadsheet_info_dialog').modal("show");
    }
    return;
}

function display_plant_upload_choices() {
    jQuery('#upload_type_choices_div').html('<select style="width:50%" class="form-control form-control-sm" id="plant_upload_type_choice_select">'+
                        '<option value="null_choice">Select file type</option>'+
                        '<option value="plants_by_name">Plants by name</option>'+
                        '<option value="plants_by_index">Plants by index number</option>'+
                        '<option value="plants_per_plot">Number of plants per plot</option>'+
                        '<option value="subplot_plants_by_name">Subplot plants by name</option>'+
                        '<option value="subplot_plants_by_index">Subplot plants by index number</option>'+
                        '<option value="plants_per_subplot">Number of plants per subplot</option>'+
                    '</select>' + 
                    '<br>' + 
                    '<div id="plants_per_plot_div" hidden>Maximum number of plants per plot/subplot: '+'<input style="width:25%" id="plant_upload_plants_per_plot" class="form-control" type="number"/></div>' + 
                    '<br>' + 
                    '<div id="plant_breeding_program_select_div"></div>'+
                    '<br>' +
                    '<div id="plant_trial_select_div"></div>'+
                    '<br><br>' + 
                    '<div id="plant_choices_next_btn_div" hidden><button class="btn btn-primary" id="plant_upload_choices_next_btn">Next</button></div>');
}

function display_accession_change_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<div id="change_accessions_breeding_program_select_div"></div>' + 
        '<br>' + 
        '<div id="change_accessions_trial_select_div"></div>' + 
        '<br>' + 
        '<button class="btn btn-primary" id="change_accessions_upload_next_btn">Next</button>'
    );
}

function display_subplot_upload_choices() {
    jQuery('#upload_type_choices_div').html('<select style="width:50%" class="form-control form-control-sm" id="subplot_upload_type_choice_select">'+
                        '<option value="null_choice">Select file type</option>'+
                        '<option value="subplots_by_name">Subplots by name</option>'+
                        '<option value="subplots_by_index">Subplots by index number</option>'+
                        '<option value="subplots_per_plot">Number of subplots per plot</option>'+
                    '</select>' + 
                    '<br>' + 
                    '<div id="subplots_per_plot_div" hidden>Maximum number of subplots per plot: '+'<input style="width:25%" id="subplot_upload_subplots_per_plot" class="form-control" type="number"/></div>' + 
                    '<br>' + 
                    '<div id="subplot_breeding_program_select_div"></div>'+
                    '<br>' +
                    '<div id="subplot_trial_select_div"></div>'+
                    '<br><br>' + 
                    '<div id="subplot_choices_next_btn_div" hidden><button class="btn btn-primary" id="subplot_upload_choices_next_btn">Next</button></div>');
}

function display_genotyping_plate_upload_choices() {
    jQuery('#upload_type_choices_div').html('<select style="width:50%" class="form-control form-control-sm" id="genotype_plate_upload_type_choice_select">'+
                        '<option value="null_choice">Select file type</option>'+
                        '<option value="genotyping_plate_excel">Genotyping plate design made in Excel</option>'+
                        '<option value="genotyping_plate_default_android">Default Coordinate Android Application plate design</option>'+
                        '<option value="genotyping_plate_custom_android">Custom Coordinate Android Application plate design</option>'+
                    '</select>' + 
                    '<br>' + 
                    '<div id="genotype_plate_choices_next_btn_div" hidden><button class="btn btn-primary" id="genotype_plate_upload_choices_next_btn">Next</button></div>');
}

function display_genotyping_data_upload_choices() {
    jQuery('#upload_type_choices_div').html('<select style="width:50%" class="form-control form-control-sm" id="genotype_data_upload_type_choice_select">'+
                '<option value="null_choice">Select file type</option>'+
                '<option value="genotype_data_vcf">VCF</option>'+
                '<option value="genotype_data_tassel">Tassel HDF5</option>'+
                '<option value="genotype_data_intertek">Intertek</option>'+
                '<option value="genotype_data_kasp">KASP (csv)</option>'+
                '<option value="genotype_data_ssr">SSR</option>'+
            '</select>'+
            '<br>'+
            '<div style="overflow-x: auto;" id="genotype_data_project_select_div" hidden>'+
                '<br><br><p><b>Select a genotyping project:</b></p><br><table style="width:100%;" id="genotype_data_project_select"><thead><th>Select</th><th>Genotyping Project</th><th>Description</th><th>Breeding Program</th></thead><tbody></tbody><tfoot></tfoot></table>'+
            '</div>'+
            '<div style="overflow-x: auto;" id="genotype_data_protocol_select_div" hidden>'+
                '<br><br><p><b>Select a genotyping protocol:</b></p><br><table style="width:100%;" id="genotype_data_protocol_select"><thead><th>Select</th><th>Protocol</th></thead><tbody></tbody><tfoot></tfoot></table>'+
            '</div>'+
            '<div id="genotype_data_intertek_info_div" hidden>'+
                '<br><br><p><b>Select Intertek information file:</b></p><br><select id="genotype_data_intertek_info_select"></select>'+
            '</div>'+
            '<br><br><div id="genotype_data_choices_next_btn_div" hidden><button class="btn btn-primary" id="genotype_data_upload_choices_next_btn">Next</button></div>');
}

function display_genotyping_data_upload_additional_choices() {
    let genotyping_data_type = jQuery('#genotype_data_upload_type_choice_select').val();
    switch (genotyping_data_type) {
        case 'genotype_data_intertek' : 
            jQuery('#genotype_data_intertek_info_div').show();
            break;
        default :
            jQuery('#genotype_data_intertek_info_div').hide();
            break;
    }
}

function display_accession_upload_choices(user_role) {
    let fuzzy_search = '<input type="checkbox" id="fuzzy_check_upload_accessions" name="fuzzy_check_upload_accessions" checked disabled></input>';
    if (user_role == "curator"){
        fuzzy_search = '<input type="checkbox" id="fuzzy_check_upload_accessions" name="fuzzy_check_upload_accessions" checked></input>';
    }

    jQuery('#upload_type_choices_div').html('<div class="form-group">' +
        '<label class="col-sm-4 control-label">Use Fuzzy Search: </label>' + 
        '<div class="col-sm-8">' + 
        fuzzy_search + 
        '<br/>' + 
        '<small>Note: Use the fuzzy search to match similar names to prevent uploading of duplicate accessions. Fuzzy searching is much slower than regular search. Only a curator can disable the fuzzy search.</small>' + 
        '</div>' + 
        '</div>' + 
        '<div class="form-group">' + 
        '<label class="col-sm-4 control-label">Append Synonyms:</label>' + 
        '<div class="col-sm-8">' + 
        '<input type="checkbox" id="append_synonyms" name="append_synonyms" checked />' + 
        '<br />' + 
        '<small>When checked, add synonyms of existing accession entries to the synonyms already stored in the database.  When not checked, remove any existing synonyms of existing accession entries and store only the synonyms in the upload file.</small>' + 
        '</div>' + '</div>' + 
        '<button class="btn btn-primary" id="accession_upload_choices_next_btn">Next</button>');
}

function display_seedlot_upload_choices(default_seedlot_material_type) {

    let seedlot_material_type = ' <div class="form-group seedlot-upload-options" hidden>' + 
                                    '<label class="col-sm-3 control-label">Material Type: </label>' + 
                                    '<div class="col-sm-9" >' + 
                                        '<div id="upload_seedlot_material_type_div"></div>' + 
                                    '</div>' + 
                                '</div><br><br>';
    if (default_seedlot_material_type != ""){
        seedlot_material_type = '<div class="form-group seedlot-upload-options" hidden>' + 
                                    '<label class="col-sm-3 control-label" >Material Type: </label>' + 
                                    '<div class="col-sm-9">' + 
                                        '<input class="form-control" name="upload_seedlots_default_material_type" id="upload_seedlots_default_material_type" disabled value="'+default_seedlot_material_type+'">' + 
                                    '</div>' + 
                                '</div><br><br>';
    }

    jQuery('#upload_type_choices_div').html(
        '<div class="form-group seedlot-upload-options">'+
            '<label class="col-sm-3 control-label">Seedlot type: </label>' + 
                '<div class="col-sm-9">' + 
                    '<select class="form-control" id="upload_seedlots_type_select" name="upload_seedlots_type_select">' + 
                        '<option value="">Select...</option>' + 
                        '<option value="from_accession">Seedlots for named accessions</option>' + 
                        '<option value="from_cross">Seedlots harvested from crosses</option>' + 
                    '</select>' + 
                '</div>' + 
        '</div><br><br>' + 
        seedlot_material_type + 
        '<div class="form-group seedlot-upload-options" hidden>' + 
            '<label class="col-sm-3 control-label">Breeding Program: </label>' + 
            '<div class="col-sm-9" >' + 
                '<div id="upload_seedlot_breeding_program_div"></div>' + 
            '</div>' + 
        '</div><br><br>' + 
        '<div class="form-group seedlot-upload-options" hidden>' + 
            '<label class="col-sm-3 control-label">Location of seedlot storage: </label>' + 
            '<div class="col-sm-9" >' + 
                '<input class="form-control" name="upload_seedlot_location" id="upload_seedlot_location" placeholder="Required">' + 
            '</div>' + 
        '</div><br><br>' + 
        '<div class="form-group seedlot-upload-options" hidden>' + 
            '<label class="col-sm-3 control-label">Organization Name: </label>' + 
            '<div class="col-sm-9" >' + 
                '<input class="form-control" name="upload_seedlot_organization_name" id="upload_seedlot_organization_name" placeholder="Optional">' + 
            '</div>' + 
        '</div><br><br>' + '<div class="seedlot-upload-options" hidden><button class="btn btn-primary" id="seedlot_upload_choices_next_btn">Next</button></div>');
}

function display_seedlot_transaction_choices() {
    jQuery('#upload_type_choices_div').html(
        '<select class="form-control" id="upload_seedlot_transaction_type_select">' + 
            '<option value="null_choice">Select a transaction type...</option>' + 
            '<option value="seedlots_exist_to_exist">Existing seedlot to existing seedlot</option>' + 
            '<option value="seedlots_exist_to_new">Existing seedlot to new seedlot</option>' + 
            '<option value="seedlots_exist_to_plots">Existing seedlot to plot</option>' + 
            '<option value="seedlots_exist_to_unspecified">Existing seedlot to unspecified seeds/plots</option>' + 
        '</select><br>' + 
        '<div id="seedlot_transaction_next_btn_div" hidden><button id="seedlot_transaction_next_btn" class="btn btn-primary">Next</button></div>'
    );
}

function display_cross_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<div id="upload_crosses_breeding_program_select_div"></div>' + 
        '<br>' + 
        '<div id="upload_crosses_crossing_experiment_select_div"></div>' + 
        '<br>'  +
        '<button id="cross_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function display_gps_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<div class="form-group">' + 
            '<div id="gps_breeding_program_select_div"></div>'+
            '<br>' +
            '<div id="gps_trial_select_div"></div>'+
            '<br><br>' + 
            '<label class="col-sm-3 control-label">Coordinates Type: </label>' + 
            '<div class="col-sm-9">' + 
                '<select class="form-control" id="upload_gps_coordinate_type" name="upload_gps_coordinate_type">' + 
                    '<option value="polygon">Polygon</option>' + 
                    '<option value="point">Point</option>' + 
                '</select>'+ 
            '</div>' + 
        '</div>' + 
        '<br>' + 
        '<button id="gps_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function display_metabolomics_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<div id="metabolomics_upload_file_format_select_div" class="form-group">' + 
            '<label class="col-sm-7 control-label">There are two metabolomics files uploaded at once. When processing a file, it will be assumed to be the main spreadsheet, and you will be prompted to select an additional details file.  </label>' + 
            '<div class="col-sm-5">' + 
                '<select class="form-control" id="metabolomics_upload_type_choice_select" name="metabolomics_upload_type_choice_select">' + 
                    '<option value>Select...</option>' + 
                    '<option value="metabolomics_spreadsheet">Metabolomics spreadsheet</option>' + 
                    '<option value="metabolite_details">Metabolite details</option>' + 
                '</select>'+ 
            '</div>' + 
        '</div>' + 
        '<br>' + 
        '<div id="metabolomics_upload_next_btn_div" hidden>' + 
            '<div class="form-group">' + 
                '<label class="col-sm-7 control-label">Select a protocol:</label>' + 
                '<br>' + 
                '<div id="upload_metabolomics_protocol_select"></div>' + 
            '</div>' + 
            '<div class="form-group">' + 
                '<label class="col-sm-7 control-label">Select a details file:</label>' + 
                '<br>' + 
                '<select class="form-control" id="upload_metabolomics_details_select" name="upload_metabolomics_details_select">'+
                    '<option value>Select...</option>'+
                '</select>'+
            '</div>' + 
        '   <button id="metabolomics_upload_next_btn" class="btn btn-primary">Next</button>' + 
        '</div>'
    );
}

function display_transcriptomics_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<div id="transcriptomics_upload_file_format_select_div" class="form-group">' + 
            '<label class="col-sm-7 control-label">There are two transcriptomics files uploaded at once. When processing a file, it will be assumed to be the main spreadsheet, and you will be prompted to select an additional details file.  </label>' + 
            '<div class="col-sm-5">' + 
                '<select class="form-control" id="transcriptomics_upload_type_choice_select" name="transcriptomics_upload_type_choice_select">' + 
                    '<option value>Select...</option>' + 
                    '<option value="transcriptomics_spreadsheet">Transcriptomics spreadsheet</option>' + 
                    '<option value="transcript_details">Transcript details</option>' + 
                '</select>'+ 
            '</div>' + 
        '</div>' + 
        '<br>' + 
        '<div id="transcriptomics_upload_next_btn_div" hidden>' + 
            '<div class="form-group">' + 
                '<label class="col-sm-7 control-label">Select a protocol:</label>' + 
                '<br>' + 
                '<div id="upload_transcriptomics_protocol_select"></div>' + 
            '</div>' + 
            '<div class="form-group">' + 
                '<label class="col-sm-7 control-label">Select a details file:</label>' + 
                '<br>' + 
                '<select class="form-control" id="upload_transcriptomics_details_select" name="upload_transcriptomics_details_select">'+
                    '<option value>Select...</option>'+
                '</select>'+
            '</div>' + 
        '   <button id="transcriptomics_upload_next_btn" class="btn btn-primary">Next</button>' + 
        '</div>'
    );
}

function display_family_names_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<div class="form-group">'+
            '<label class="col-sm-3 control-label">Family Type: </label>'+
            '<div class="col-sm-8">'+
                '<select class="form-control" id="family_type_option">'+
                    '<option value>Select a family type</option>'+
                    '<option value="same_parents">Include only crosses with the same female parent and the same male parent</option>'+
                    '<option value="reciprocal_parents">Include reciprocal crosses</option>'+
                '</select>'+
            '</div>'+
        '</div>'+
        '<br><br>' + 
        '<button id="family_names_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function display_phenotyping_spreadsheet_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<form class="form-horizontal" style="width:60%">' + 
        '<div class="form-group">'+
            '<label class="col-sm-6 control-label">Spreadsheet Format: </label>'+
            '<div class="col-sm-6" >'+
                '<select class="form-control" id="upload_spreadsheet_phenotype_file_format" name="upload_spreadsheet_phenotype_file_format">'+
                    '<option value="detailed">Detailed</option>'+
                    '<option value="simple">Simple</option>'+
                '</select>'+
            '</div>'+
        '</div>'+
        '<div class="form-group">'+
            '<label class="col-sm-6 control-label">Timestamps Included: </label>'+
            '<div class="col-sm-6" >'+
                '<input type="checkbox" id="upload_spreadsheet_phenotype_timestamp_checkbox" name="upload_spreadsheet_phenotype_timestamp_checkbox" />'+
            '</div>'+
        '</div>'+
        '<div id="upload_spreadsheet_phenotype_data_level_div">'+
            '<div class="form-group">'+
                '<label class="col-sm-6 control-label">Data Level: </label>'+
                '<div class="col-sm-6" >'+
                    '<select class="form-control" id="upload_spreadsheet_phenotype_data_level" name="upload_spreadsheet_phenotype_data_level">'+
                       ' <option value="plots">Plots</option>'+
                        '<option value="plants">Plants</option>'+
                       ' <option value="subplots">Subplots</option>'+
                        '<option value="tissue_samples">Tissue Samples</option>'+
                    '</select>'+
               ' </div>'+
            '</div>'+
        '</div>' + 
        '</form>' + 
        '<br><br>' + 
        '<button id="phenotyping_spreadsheet_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function display_fieldbook_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<form class="form-horizontal" style="width:60%">' + 
            '<div class="form-group">'+
                '<label class="col-sm-6 control-label">Data Level: </label>'+
                '<div class="col-sm-6" >'+
                    '<select class="form-control" id="upload_fieldbook_data_level" name="upload_fieldbook_data_level">'+
                       ' <option value="plots">Plots</option>'+
                        '<option value="plants">Subplots</option>'+
                       ' <option value="subplots">Plants</option>'+
                    '</select>'+
               ' </div>'+
            '</div>'+
            '<div class="form-group">' +
                '<label class="col-sm-6 control-label">Optional: Images ZipFile (.zip):</label>' + 
                 '<div class="col-sm-6" >'+
                    '<select class="form-control" id="upload_fieldbook_images_select" name="upload_fieldbook_images_select">'+
                       ' <option value>Select...</option>'+
                    '</select>'+
               ' </div>'+
            '</div>' +
        '</form>' + 
        '<br><br>' + 
        '<button id="fieldbook_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function display_datacollector_spreadsheet_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<form class="form-horizontal" style="width:60%">' + 
        '<div class="form-group">'+
            '<label class="col-sm-6 control-label">Timestamps Included: </label>'+
            '<div class="col-sm-6" >'+
                '<input type="checkbox" id="upload_datacollector_phenotype_timestamp_checkbox" name="upload_datacollector_phenotype_timestamp_checkbox" />'+
            '</div>'+
        '</div>'+
            '<div class="form-group">'+
                '<label class="col-sm-6 control-label">Data Level: </label>'+
                '<div class="col-sm-6" >'+
                    '<select class="form-control" id="upload_datacollector_phenotype_data_level" name="upload_datacollector_phenotype_data_level">'+
                       ' <option value="plots">Plots</option>'+
                        '<option value="plants">Plants</option>'+
                       ' <option value="subplots">Subplots</option>'+
                        '<option value="tissue_samples">Tissue Samples</option>'+
                    '</select>'+
               ' </div>'+
            '</div>'+
        '</form>' + 
        '<br><br>' + 
        '<button id="datacollector_spreadsheet_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function display_nirs_upload_choices() {
    jQuery('#upload_type_choices_div').html(
        '<div class="form-group">'+
            '<label class="col-sm-6 control-label">NIRS protocol: </label>'+'<br><br>' + 
            '<div id="upload_nirs_protocol_select"></div>'+ 
        '</div><br><br>'+
        // '<div class="form-group">'+
        //     '<label class="col-sm-6 control-label">Data Level: </label>'+
        //     '<div class="col-sm-6" >'+
        //         '<select class="form-control" id="upload_nirs_data_level" name="upload_nirs_data_level">'+
        //             '<option value="tissue_samples">Tissue samples</option>'+
        //         '</select>'+
        //    ' </div>'+
        // '</div>'+
        '<button id="nirs_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function display_images_upload_choices() {
     jQuery('#upload_type_choices_div').html(
        '<div class="form-group">'+
            '<label class="col-sm-6 control-label">Image upload type: </label>'+
            '<div class="col-sm-6" >'+
                '<select class="form-control" id="upload_images_type" name="upload_images_type">'+
                    '<option value>Select...</option>'+
                    '<option value="images">Images alone</option>'+
                    '<option value="images_barcodes">Images with barcodes</option>'+
                    '<option value="images_phenotypes">Image zipfile with associated phenotypes</option>'+
                '</select>'+
           ' </div>'+
        '</div>'+
        '<br>' + 
        '<div id="upload_images_select_more_div" class="form-group" hidden>'+
            '<label class="col-sm-6 control-label">Select additional images: </label>'+
            '<div class="col-sm-6" >'+
                '<select class="form-control" id="upload_images_select_more" name="upload_images_select_more" multiple>'+
                    '<option value>Select...</option>'+
                '</select>'+
           ' </div>'+
        '</div>'+
        '<div id ="upload_images_select_pheno_spreadsheet_div" class="form-group" hidden>' +
            '<label class="col-sm-6 control-label">Select phenotyping spreadsheet: </label>'+
            '<div class="col-sm-6" >'+
                '<select class="form-control" id="upload_images_select_pheno" name="upload_images_select_pheno" single>'+
                    '<option value>Select...</option>'+
                '</select>'+
           ' </div>'+
        '</div>' +
        '<br>' + 
        '<button id="image_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function display_images_additional_upload_choices() {
    let image_upload_type = jQuery('#upload_images_type').val();
    if (!image_upload_type) {
        jQuery('#upload_images_select_more_div').hide();
        jQuery('#upload_images_select_pheno_spreadsheet_div').hide();
    } else if (image_upload_type == "images_phenotypes") {
        jQuery('#upload_images_select_pheno_spreadsheet_div').show();
        jQuery('#upload_images_select_more_div').hide();
    } else {
        jQuery('#upload_images_select_pheno_spreadsheet_div').hide();
        jQuery('#upload_images_select_more_div').show();
    }
}

function display_soil_data_upload_choices() {
    jQuery('#upload_type_choices_div').html(
    '<div class="form-group">' + 
       ' <label class="col-sm-4 control-label">Field trial: </label>'+
        '<div class="col-sm-8" >'+
            '<input class="form-control" type="text" id="soil_data_field_trial" name="soil_data_field_trial" />'+
        '</div>'+
    '</div>'+
    '<div class="form-group">'+
        '<label class="col-sm-4 control-label">Description:</label>'+
        '<div class="col-sm-8">'+
            '<input class="form-control" type="text" id="soil_data_description" name="soil_data_description" />'+
        '</div>'+
    '</div>'+
    '<div class="form-group">'+
        '<label class="col-sm-4 control-label">Sampling Date:</label>'+
       ' <div class="col-sm-8">'+
           ' <input class="form-control" id="soil_data_date" name="soil_data_date" title="data_date" type="date"/>'+
        '</div>'+
    '</div>'+
    '<div class="form-group">'+
        '<label class="col-sm-4 control-label">GPS (optional):</label>'+
        '<div class="col-sm-8">'+
            '<input class="form-control" type="text" id="soil_data_gps" name="soil_data_gps" />'+
        '</div>'+
    '</div>'+
    '<div class="form-group">'+
        '<label class="col-sm-4 control-label">Type of Sampling:</label>'+
        '<div class="col-sm-8">'+
            '<input class="form-control" type="text" id="type_of_sampling" name="type_of_sampling" />'+
        '</div>'+
    '</div>' + 
    '<br><br>' + 
    '<button id="soil_data_upload_next_btn" class="btn btn-primary">Next</button>');
}

function display_trial_additional_file_upload_choices() {
    jQuery('#upload_type_choices_div').html(
    '<div id="trial_additional_file_breeding_program_select_div"></div>'+
    '<br>' +
    '<div id="trial_additional_file_trial_select_div"></div>'+
    '<br><br>' + 
    '<button id="trial_additional_file_upload_next_btn" class="btn btn-primary">Next</button>');
}

function display_vector_upload_choices(user_role) {
    let fuzzy_search = '<input type="checkbox" id="fuzzy_check_upload_vectors" name="fuzzy_check_upload_vectors" checked disabled></input>';
    if (user_role == "curator"){
        fuzzy_search = '<input type="checkbox" id="fuzzy_check_upload_vectors" name="fuzzy_check_upload_vectors" checked></input>';
    }

    jQuery('#upload_type_choices_div').html(
        '<div class="form-group">' + 
            '<label class="col-sm-4 control-label">Use Fuzzy Search: </label>'+
            '<div class="col-sm-8">'+
                fuzzy_search+
                '<br/>'+
                '<small>Note: Use the fuzzy search to match similar names to prevent uploading of duplicate vectors. Fuzzy searching is much slower than regular search. Only a curator can disable the fuzzy search.</small>'+
            '</div>'+
        '</div>'+
        '<div class="form-group">'+
           ' <label class="col-sm-4 control-label"> Auto generate uniquename</label><br>'+
            '<div class="col-sm-8">'+
                '<input type="checkbox" id="vector_autogenerate_uniquename" name="vector_autogenerate_uniquename">'+
            '</div>'+
        '</div>' + 
        '<br><br>' + 
        '<button id="vector_upload_next_btn" class="btn btn-primary">Next</button>'
    );
}

function populate_plant_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let plant_upload_type = jQuery('#plant_upload_type_choice_select').val();
    let num_plants_per_plot = jQuery('#plant_upload_plants_per_plot').val();
    let trial_select = jQuery('#plant_trial_id option:selected');
    let trial_id = trial_select.val();
    let trial_name = trial_select.text();

    if (!trial_id) {
        alert("Please select a trial.");
        return;
    }
    if (plant_upload_type == "null_choice") {
        alert("Select a plant upload type");
        return;
    }
    if (!num_plants_per_plot || num_plants_per_plot < 1) {
        alert("Enter the maximum number of plants per plot/subplot.");
        return;
    }
    populate_validate_submit_data(plant_upload_type, file_data, {
        plants_per_plot : num_plants_per_plot,
        plants_per_subplot : num_plants_per_plot,
        trial_id : trial_id,
        trial_name : trial_name
    });
}

function populate_subplot_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let subplot_upload_type = jQuery('#subplot_upload_type_choice_select').val();
    let num_subplots_per_plot = jQuery('#subplot_upload_subplots_per_plot').val();
    let trial_select = jQuery('#gps_trial_id option:selected');
    let trial_id = trial_select.val();
    let trial_name = trial_select.text();

    if (!trial_id) {
        alert("Please select a trial.");
        return;
    }
    if (subplot_upload_type == "null_choice") {
        alert("Select a subplot upload type");
        return;
    }
    if (!num_subplots_per_plot || num_subplots_per_plot < 1) {
        alert("Enter the maximum number of subplots per plot/subplot.");
        return;
    }
    populate_validate_submit_data(subplot_upload_type, file_data, {
        subplots_per_plot : num_subplots_per_plot,
        trial_id : trial_id,
        trial_name : trial_name
    });
}

function populate_genotyping_plate_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let genotype_plate_upload_type = jQuery('#genotype_plate_upload_type_choice_select').val();
    if (genotype_plate_upload_type == "null_choice") {
        alert("Select a genotyping plate upload type");
        return;
    }
    populate_validate_submit_data(genotype_plate_upload_type, file_data);
}

function populate_genotyping_data_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let selected_projects = [];
    jQuery('input[name="upload_genotyping_data_project_select"]:checked').each(function() {
        selected_projects.push({id : jQuery(this).val(), name : jQuery(this).attr('trial_name')});
    });
    if (selected_projects.length > 1){
        alert('Only select one genotyping project!');
        return;
    } else if (selected_projects.length < 1) {
        alert ('Please select a genotyping project.');
        return;
    }

    let selected_protocols = [];
    jQuery('input[name="upload_genotyping_data_protocol_select"]:checked').each(function() {
        selected_protocols.push({id : jQuery(this).val(), name : jQuery(this).attr('protocol_name')});
    });
    if (selected_protocols.length > 1){
        alert('Only select one genotyping protocol!');
        return;
    } else if (selected_protocols.length < 1) {
        alert ('Please select a genotyping protocol.');
        return;
    }

    let genotype_data_format = jQuery('#genotype_data_upload_type_choice_select').val();
    if (genotype_data_format == "null_choice") {
        alert("Select a genotyping data upload type");
        return;
    }

    if (genotype_data_format == "genotype_data_intertek") {
        let intertek_info_file = {id: jQuery('#genotype_data_intertek_info_select').val(), name : jQuery('#genotype_data_intertek_info_select option:selected').text()};
        populate_validate_submit_data(genotype_data_format, file_data, {
            intertek_info_file_id : intertek_info_file.id,
            intertek_info_file_name : intertek_info_file.name,
            genotyping_protocol_id : selected_protocols[0].id,
            genotyping_project_id : selected_projects[0].id,
            genotyping_protocol_name : selected_protocols[0].name,
            genotyping_project_name : selected_projects[0].name
        });
    } else {
        populate_validate_submit_data(genotype_data_format, file_data, {
            genotyping_protocol_id : selected_protocols[0].id,
            genotyping_project_id : selected_projects[0].id,
            genotyping_protocol_name : selected_protocols[0].name,
            genotyping_project_name : selected_projects[0].name
        });
    }
}

function populate_accession_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let fuzzy_search = jQuery('#fuzzy_check_upload_accessions').prop('checked');
    let append_synonyms = jQuery('#append_synonyms').prop('checked');

    populate_validate_submit_data('accessions', file_data, {
        use_fuzzy_search : fuzzy_search,
        append_synonyms : append_synonyms
    });
}

function populate_accession_change_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let trial_select = jQuery('#change_accessions_trial_id option:selected');
    let trial_id = trial_select.val();
    let trial_name = trial_select.text();

    if (!trial_id) {
        alert("Please select a trial.");
        return;
    }

    populate_validate_submit_data("change_accessions", file_data, {
        trial_id : trial_id,
        trial_name : trial_name
    });
}

function populate_seedlot_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let seedlot_type = jQuery('#upload_seedlots_type_select').val();
    let material_type = jQuery('#upload_seedlot_material_type').val();
    let breeding_program_select = jQuery('#upload_seedlot_breeding_program_id option:selected');
    let breeding_program_id = breeding_program_select.val();
    let breeding_program_name = breeding_program_select.text();
    let storage_location = jQuery("#upload_seedlot_location").val();
    let organization_name = jQuery('#upload_seedlot_organization_name').val();


    if (seedlot_type != "from_accession" && seedlot_type != "from_cross") {
        alert("Please select a seedlot source type");
        return;
    }
    if (storage_location == null || storage_location == "") {
        alert("Please select a seedlot storage location.");
        return;
    }
    if (!breeding_program_id) {
        alert("Please select a breeding program.");
        return;
    }

    populate_validate_submit_data('seedlots', file_data, {
        seedlot_type : seedlot_type,
        material_type : material_type,
        breeding_program_id : breeding_program_id,
        breeding_program_name : breeding_program_name,
        storage_location : storage_location,
        organization_name : organization_name
    });
}

function populate_seedlot_transaction_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let transaction_type = jQuery('#upload_seedlot_transaction_type_select').val();
    if (transaction_type == "null_choice") {
        alert("Please select a transaction type.");
        return;
    }

    populate_validate_submit_data(transaction_type, file_data, {});
}

function populate_trial_additional_file_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let breeding_program_select = jQuery('#trial_additional_file_breeding_program_id option:selected');
    let breeding_program_id = breeding_program_select.val();
    let breeding_program_name = breeding_program_select.text();
    let trial_select = jQuery('#trial_additional_file_trial_id option:selected');
    let trial_id = trial_select.val();
    let trial_name = trial_select.text();

    if (!breeding_program_id) {
        alert ("Please select a breeding program.");
        return;
    }
    if (!trial_id) {
        alert("Please select a trial.");
        return;
    }
    populate_validate_submit_data('trial_additional_file', file_data, {
        breeding_program_id : breeding_program_id,
        breeding_program_name : breeding_program_name,
        trial_id : trial_id,
        trial_name : trial_name
    });
}

function populate_gps_validate_submit_data(event) { 
    let file_data = event.data.file_data;
    let coord_type = jQuery('#upload_gps_coordinate_type').val();
    let trial_select = jQuery('#gps_trial_id option:selected');
    let trial_id = trial_select.val();
    let trial_name = trial_select.text();

    if (!trial_id) {
        alert("Please select a trial.");
        return;
    }

    if (coord_type == "polygon") { 
        populate_validate_submit_data("gps_polygon", file_data, {
            trial_id : trial_id,
            trial_name : trial_name
        });
    } else {
        populate_validate_submit_data("gps_point", file_data, {
            trial_id : trial_id,
            trial_name : trial_name
        });
    }
}

function populate_family_names_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let family_type = jQuery('#family_type_option').val();
    if (family_type != "same_parents" && family_type != "reciprocal_parents") {
        alert("Select a family type.");
        return;
    } 

    populate_validate_submit_data('family_names', file_data, {family_type : family_type});
}

function populate_phenotyping_spreadsheet_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let include_timestamps = jQuery('#upload_spreadsheet_phenotype_timestamp_checkbox').prop('checked') ? 'yes' : 'no';
    let spreadsheet_format = jQuery('#upload_spreadsheet_phenotype_file_format').val();
    let data_level = jQuery('#upload_spreadsheet_phenotype_data_level').val();

    populate_validate_submit_data('phenotyping_spreadsheet', file_data, {
        include_timestamps : include_timestamps,
        spreadsheet_format : spreadsheet_format,
        data_level : data_level
    });
}

function populate_treatment_spreadsheet_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let include_timestamps = jQuery('#upload_spreadsheet_phenotype_timestamp_checkbox').prop('checked') ? 'yes' : 'no';
    let spreadsheet_format = jQuery('#upload_spreadsheet_phenotype_file_format').val();
    let data_level = jQuery('#upload_spreadsheet_phenotype_data_level').val();

    populate_validate_submit_data('treatments', file_data, {
        include_timestamps : include_timestamps,
        spreadsheet_format : spreadsheet_format,
        data_level : data_level
    });
}

function populate_fieldbook_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let images_zipfile_select = jQuery('#upload_fieldbook_images_select option:selected');
    let images_zipfile_id = images_zipfile_select.val();
    let images_zipfile_name = images_zipfile_select.text();
    let data_level = jQuery('#upload_fieldbook_data_level').val();

    if (images_zipfile_id) {
        populate_validate_submit_data('fieldbook_phenotypes', file_data, {
            images_zipfile_id : images_zipfile_id,
            images_zipfile : images_zipfile_name,
            data_level : data_level
        });
    } else {
        populate_validate_submit_data('fieldbook_phenotypes', file_data, {
            data_level : data_level
        });
    }
}

function populate_datacollector_spreadsheet_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let include_timestamps = jQuery('#upload_datacollector_phenotype_timestamp_checkbox').prop('checked') ? 'yes' : 'no';
    let data_level = jQuery('#upload_datacollector_phenotype_data_level').val();

    populate_validate_submit_data('datacollector_spreadsheet', file_data, {
        include_timestamps : include_timestamps,
        data_level : data_level
    });
}

function populate_nirs_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let selected_protocols = [];
    jQuery('input[name="upload_nirs_protocol_id"]:checked').each(function() {
            selected_protocols.push({id : jQuery(this).val(), name : jQuery(this).attr('protocol_name')});
        });
    if (selected_protocols.length > 1){
        alert('Only select one NIRS protocol!');
        return;
    } else if (selected_protocols.length < 1) {
        alert ('Please select a NIRS protocol.');
        return;
    }

    populate_validate_submit_data('nirs', file_data, {
        nirs_protocol : selected_protocols[0].name,
        nirs_protocol_id : selected_protocols[0].id
    });
}

function populate_metabolomics_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let selected_protocols = [];
    jQuery('input[name="upload_metabolomics_protocol_select"]:checked').each(function() {
            selected_protocols.push({id : jQuery(this).val(), name : jQuery(this).attr('protocol_name')});
        });
    if (selected_protocols.length > 1){
        alert('Only select one metabolomics protocol!');
        return;
    } else if (selected_protocols.length < 1) {
        alert ('Please select a metabolomics protocol.');
        return;
    }
    let metabolomics_details_id = jQuery('#upload_metabolomics_details_select option:selected').val();
    let metabolomics_details_name = jQuery('#upload_metabolomics_details_select option:selected').text();

    if (!metabolomics_details_id) {
        alert("Please select a details file.");
        return;
    }

    populate_validate_submit_data('metabolomics', file_data, {
        details_file : metabolomics_details_name,
        details_file_id : metabolomics_details_id,
        metabolomics_protocol : selected_protocols[0].name,
        metabolomics_protocol_id : selected_protocols[0].id
    });
}

function populate_transcriptomics_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let selected_protocols = [];
    jQuery('input[name="upload_transcriptomics_protocol_select"]:checked').each(function() {
            selected_protocols.push({id : jQuery(this).val(), name : jQuery(this).attr('protocol_name')});
        });
    if (selected_protocols.length > 1){
        alert('Only select one transcriptomics protocol!');
        return;
    } else if (selected_protocols.length < 1) {
        alert ('Please select a transcriptomics protocol.');
        return;
    }
    let transcriptomics_details_id = jQuery('#upload_transcriptomics_details_select option:selected').val();
    let transcriptomics_details_name = jQuery('#upload_transcriptomics_details_select option:selected').text();

    if (!transcriptomics_details_id) {
        alert("Please select a details file.");
        return;
    }

    populate_validate_submit_data('transcriptomics', file_data, {
        details_file : transcriptomics_details_name,
        details_file_id : transcriptomics_details_id,
        transcriptomics_protocol : selected_protocols[0].name,
        transcriptomics_protocol_id : selected_protocols[0].id
    });
}

function populate_image_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let image_upload_type = jQuery('#upload_images_type').val();

    let selected_files = [];
    if (image_upload_type == "images_phenotypes") {
        jQuery('#upload_images_select_pheno option:selected').each(function(){
            selected_files.push({id : jQuery(this).val(), name : jQuery(this).text()});
        });
    } else {
        jQuery('#upload_images_select_more option:selected').each(function(){
            selected_files.push({id : jQuery(this).val(), name : jQuery(this).text()});
        });
    }
    

    if (!image_upload_type) {
        alert("Select an image upload type.");
        return;
    } else {
        populate_validate_submit_data(image_upload_type, file_data, {
            additional_files : selected_files
        });
    }
}

function populate_soil_data_validate_submit_data(event) {
    let file_data = event.data.file_data;

    let field_trial = jQuery('#soil_data_field_trial').val();
    let description = jQuery('#soil_data_description').val();
    let date = jQuery('#soil_data_date').val();
    let gps = jQuery('#soil_data_gps').val();
    let sampling_type = jQuery('#type_of_sampling').val();

    if (!field_trial) {
        alert("Select a field trial.");
        return;
    }
    if (!description) {
        alert("Enter a soil data description");
        return;
    }
    if (!date) {
        alert("Enter a sampling date.");
        return;
    }
    if (!sampling_type) {
        alert("Enter a sampling type.");
        return;
    }

    populate_validate_submit_data("soil_data", file_data, {
        field_trial : field_trial,
        description : description,
        date : date,
        gps : gps,
        sampling_type : sampling_type
    });
}

function populate_vector_validate_submit_data(event) {
    let file_data = event.data.file_data;

    let fuzzy_search = jQuery('#fuzzy_check_upload_vectors').prop('checked');
    let generate_uniquenames = jQuery('#vector_autogenerate_uniquename').prop('checked');

    populate_validate_submit_data("vectors", file_data, {
        use_fuzzy_search : fuzzy_search,
        generate_uniquenames : generate_uniquenames
    });
}

function populate_cross_validate_submit_data(event) {
    let file_data = event.data.file_data;
    let breeding_program_select = jQuery('#upload_crosses_breeding_program_id option:selected');
    let breeding_program_id = breeding_program_select.val();
    let breeding_program_name = breeding_program_select.text();
    let cross_exp_select = jQuery('#upload_crosses_crossing_experiment_id option:selected');
    let cross_exp_id = cross_exp_select.val();
    let cross_exp_name = cross_exp_select.text();

    if (!breeding_program_id) {
        alert ("Please select a breeding program.");
        return;
    }
    if (!cross_exp_id) {
        alert("Please select a crossing experiment.");
        return;
    }
    populate_validate_submit_data('crosses', file_data, {
        breeding_program_id : breeding_program_id,
        breeding_program_name : breeding_program_name,
        crossing_experiment_id : cross_exp_id,
        crossing_experiment_name : cross_exp_name
    });
}

function populate_validate_submit_data(upload_type, file_data, additional_args) {

    display_validate_submit_modal({
        'Upload Type' : upload_type_dict[upload_type],
        'File' : file_data.file_name,
        'File ID' : file_data.file_id,
        'Additional arguments' : additional_args ? JSON.stringify(additional_args, null, 2) : "none",
        parameters_json : {
            upload_type : upload_type,
            file_id : file_data.file_id,
            additional_args : additional_args
        }
    });

    let submit_params = {
        upload_type : upload_type,
        file : file_data.file_name,
        file_id : file_data.file_id,
        additional_args : additional_args
    };

    jQuery('#upload_validation_parameters').text(JSON.stringify(submit_params));
}

export function submit_upload_job() {
    let submit_params = JSON.parse(jQuery('#upload_validation_parameters').text());
    let ignore_warnings = jQuery('#upload_submit_ignore_warnings').prop('checked');

    // 'trial_metadata' : "Trial Metadata",
    // 'trial_additional_file' : "Trial Additional File",
    // 'plants_by_name' : "Plants by name",
    // 'plants_by_index' : "Plants by index number",
    // 'plants_per_plot' : "Plants by number of plants per plot",
    // 'subplot_plants_by_name' : "Subplot plants by name",
    // 'subplot_plants_by_index' : "Subplot plants by index number",
    // 'plants_per_subplot' : "Plants by number of plants per subplot",
    // 'subplots_by_name' : "Subplots by name",
    // 'subplots_by_index' : "Subplots by index number",
    // 'subplots_per_plot' : "Subplots by number of subplots per plot",
    // 'genotyping_plate_excel' : "Genotyping plate design made in Excel",
    // 'genotyping_plate_default_android' : "Default Coordinate Android Application plate design",
    // 'genotyping_plate_custom_android' : "Custom Coordinate Android Application plate design",
    // 'genotype_data_vcf' : "VCF genotyping data",
    // 'genotype_data_tassel' : "Tassel HDF5 genotyping data",
    // 'genotype_data_intertek' : "Intertek genotyping data",
    // 'genotype_data_kasp' : "KASP genotyping data",
    // 'genotype_data_ssr' : "SSR genotyping data",
    // 'locations' : "Locations",
    // 'accessions' : "Accessions",
    // 'seedlots' : "Seedlots",
    // 'seedlot_inventory' : "Seedlot inventory",
    // 'seedlots_exist_to_exist' : "Transact existing seedlots to existing seedlots",
    // 'seedlots_exist_to_new' : "Transact existing seedlots to new seedlots",
    // 'seedlots_exist_to_plots' : "Transact existing seedlots to plots",
    // 'seedlots_exist_to_unspecified' : "Transact existing seedlots to unspecified seeds/plots",
    // 'pedigrees' : "Pedigrees",
    // 'crosses' : "Crosses",
    // 'gps_polygon' : "GPS coordinate polygons",
    // 'gps_point' : "GPS coordinate points",
    // 'spatial_layout' : "Trial spatial layout",
    // 'change_accessions' : "Accession swap",
    // 'entry_numbers' : "Entry numbers",
    // 'new_progenies' : 'Progeny relationships for new accessions',
    // 'existing_progenies' : 'Progeny relationships for existing accessions',
    // 'family_names' : 'Family names of existing crosses',
    // 'phenotyping_spreadsheet' : "Phenotyping spreadsheet",
    // 'fieldbook_phenotypes' : "Field Book phenotypes",
    // 'datacollector_spreadsheet' : "Datacollector spreadsheet",
    // 'nirs' : "NIRS data",
    // 'metabolomics' : "Metabolomic data",
    // 'transcriptomics' : "Transcriptomic data",
    // 'images' : "Images",
    // 'images_barcodes' : "Images with barcodes",
    // 'images_phenotypes' : "Images with associated phenotypes",
    // 'soil_data' : "Soil data",
    // 'vectors' : "Vector constructs",
    // 'treatments' : "Treatments"

    jQuery('.modal.fade').each(function(index, element){
        jQuery(this).modal("hide");
    });

    jQuery('#working_modal').modal("show");

    switch(submit_params.upload_type) {
        case 'trials' : 
            jQuery.ajax({
                url: '/ajax/trial/upload_multiple_trial_designs_file',
                type: 'POST',
                data: {
                    'upload_multiple_trials_ignore_warnings' : 'on',
                    'email_option_to_recieve_trial_upload_status' : 'off',
                    'archived_file_id' : submit_params.file_id,
                    'upload_multiple_trials_ignore_warnings' : ignore_warnings
                },
                success: function(response) {
                    if (response.error) {
                        console.log(response.error);
                    }
                    refresh_upload_tables();
                },
                error: function() {
                    alert("An error occurred processing trial upload, check console.");
                    return;
                }
            });
            break;
        case 'phenotyping_spreadsheet':
            jQuery.ajax({
                url: '/ajax/phenotype/upload_verify/spreadsheet',
                type : 'POST',
                data : {
                    'upload_spreadsheet_phenotype_file_format' : submit_params.additional_args.spreadsheet_format,
                    'upload_spreadsheet_phenotype_timestamp_checkbox' : submit_params.additional_args.include_timestamps,
                    'upload_spreadsheet_phenotype_data_level' : submit_params.additional_args.data_level,
                    'archived_file_id' : submit_params.file_id,
                    'ignore_warnings' : ignore_warnings
                },
                success: function(response) {
                    if (response.error) {
                        //alert(`An error occurred: ${response.error}`); //This always errors for some reason, even if nothing bad happened.
                        console.log(response.error);
                    }
                    refresh_upload_tables();
                },
                error: function() {
                    alert("An error occurred submitting phenotype validation, check console.");
                    return;
                }
            });
            break;
        case 'trial_additional_file' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_additional_file',
                type : 'POST',
                data : {
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred submitting file to trial. Check console.");
                }
            });
            break;
        case 'trial_metadata' :
            jQuery.ajax({
                url : '/ajax/trial/upload_trial_metadata_file',
                type: 'POST',
                data : {
                    'trial_metadata_upload_ignore_warnings' : ignore_warnings,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading trial metadata. Check console.");
                }
            });
            break;
        case 'plants_by_name' : 
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_plants',
                data : {
                    'upload_plants_per_plot_number' : submit_params.additional_args.plants_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading plants. Check console.");
                }
            });
            break;
        case 'plants_by_index' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_plants_with_plant_index_number',
                data : {
                    'upload_plants_with_index_number_per_plot_number' : submit_params.additional_args.plants_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading plants. Check console.");
                }
            });
            break;
        case 'plants_per_plot' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_plants_with_number_of_plants',
                data : {
                    'upload_plants_with_num_plants_per_plot_number' : submit_params.additional_args.plants_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading plants. Check console.");
                }
            });
            break;
        case 'subplot_plants_by_name' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_plants_subplot',
                data : {
                    'upload_plants_per_subplot_number' : submit_params.additional_args.plants_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading plants. Check console.");
                }
            });
            break;
        case 'subplot_plants_by_index' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_plants_subplot_with_plant_index_number',
                data : {
                    'upload_plants_subplot_with_index_number_per_subplot_number' : submit_params.additional_args.plants_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading plants. Check console.");
                }
            });
            break;
        case 'plants_per_subplot' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_plants_subplot_with_number_of_plants',
                data : {
                    'upload_plants_subplot_with_num_plants_per_subplot_number' : submit_params.additional_args.plants_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading plants. Check console.");
                }
            });
            break;
        case 'subplots_by_name' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_subplots',
                data : {
                    'upload_subplots_per_plot_number' : submit_params.additional_args.subplots_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading subplots. Check console.");
                }
            });
            break;
        case 'subplots_by_index' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_subplots_with_subplot_index_number',
                data : {
                    'upload_subplots_with_index_number_per_plot_number' : submit_params.additional_args.subplots_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading subplots. Check console.");
                }
            });
            break;
        case 'subplots_per_plot' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_subplots_with_number_of_subplots',
                data : {
                    'upload_subplots_with_num_subplots_per_plot_number' : submit_params.additional_args.subplots_per_plot,
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading subplots. Check console.");
                }
            });
            break;
        case 'genotyping_plate_excel' :
            break;
        case 'genotyping_plate_default_android' :
            break;
        case 'genotyping_plate_custom_android' :
            break;
        case 'genotype_data_vcf' :
            break;
        case 'genotype_data_tassel' :
            break;
        case 'genotype_data_intertek' :
            break;
        case 'genotype_data_kasp' :
            break;
        case 'genotype_data_ssr' :
            break;
        case 'locations' :
            break;
        case 'accessions' :
            break;
        case 'seedlots' :
            break;
        case 'seedlot_inventory' :
            break;
        case 'seedlots_exist_to_exist' :
            break;
        case 'seedlots_exist_to_new' :
            break;
        case 'seedlots_exist_to_plots' :
            break;
        case 'seedlots_exist_to_unspecified' :
            break;
        case 'pedigrees' :
            break;
        case 'crosses' :
            break;
        case 'gps_polygon' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_plot_gps',
                data : {
                    'upload_gps_coordinate_type' : 'gps_polygon',
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading gps coordinates. Check console.");
                }
            });
            break;
        case 'gps_point' :
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/upload_plot_gps',
                data : {
                    'upload_gps_coordinate_type' : 'gps_point',
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading gps coordinates. Check console.");
                }
            });
            break;
        case 'spatial_layout' :
            break;
        case 'change_accessions' :
            let override = ignore_warnings ? "" : "check";
            jQuery.ajax({
                url : '/ajax/breeders/trial/'+submit_params.additional_args.trial_id+'/change_plot_accessions_using_file/'+override,
                data : {
                    'archived_file_id' : submit_params.file_id
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading gps coordinates. Check console.");
                }
            });
            break;
        case 'entry_numbers' :
            jQuery.ajax({
                url : '/ajax/breeders/trial_entry_numbers/upload',
                data : {
                    ignore_warnings : ignore_warnings,
                    archived_file_id : submit_params.file_id,
                },
                success : function(response) {
                    if (response.error) {
                        console.log(error);
                    }
                    refresh_upload_tables();
                },
                error : function() {
                    alert("An error occurred uploading entry numbers. Check console.");
                }
            });
            break;
        case 'new_progenies' :
            break;
        case 'existing_progenies' :
            break;
        case 'family_names' :
            break;
        case 'fieldbook_phenotypes' :
            jQuery.ajax({
                url: '/ajax/phenotype/upload_verify/fieldbook',
                type : 'POST',
                data : {
                    'upload_fieldbook_phenotype_data_level' : submit_params.additional_args.data_level,
                    'upload_fieldbook_phenotype_images_zipfile' : submit_params.additional_args.images_zipfile_id,
                    'archived_file_id' : submit_params.file_id,
                    'ignore_warnings' : ignore_warnings
                },
                success: function(response) {
                    if (response.error) {
                        //alert(`An error occurred: ${response.error}`); //This always errors for some reason, even if nothing bad happened.
                        console.log(response.error);
                    }
                    refresh_upload_tables();
                },
                error: function() {
                    alert("An error occurred submitting fieldbook validation, check console.");
                    return;
                }
            });
            break;
        case 'datacollector_spreadsheet' :
            jQuery.ajax({
                url: '/ajax/phenotype/upload_verify/datacollector',
                type : 'POST',
                data : {
                    'upload_datacollector_phenotype_timestamp_checkbox' : submit_params.additional_args.include_timestamps,
                    'archived_file_id' : submit_params.file_id,
                    'ignore_warnings' : ignore_warnings
                },
                success: function(response) {
                    if (response.error) {
                        //alert(`An error occurred: ${response.error}`); //This always errors for some reason, even if nothing bad happened.
                        console.log(response.error);
                    }
                    refresh_upload_tables();
                },
                error: function() {
                    alert("An error occurred submitting datacollector validation, check console.");
                    return;
                }
            });
            break;
        case 'nirs' :
            break;
        case 'metabolomics' :
            break;
        case 'transcriptomics' :
            break;
        case 'images' :
            break;
        case 'images_barcodes' :
            break;
        case 'images_phenotypes' :
            
            break;
        case 'soil_data' :
            break;
        case 'vectors' :
            break;
        case 'treatments' :
            jQuery.ajax({
                url: '/ajax/phenotype/upload_verify/spreadsheet/treatment',
                type : 'POST',
                data : {
                    'upload_spreadsheet_treatment_file_format' : submit_params.additional_args.spreadsheet_format,
                    'upload_spreadsheet_treatment_timestamp_checkbox' : submit_params.additional_args.include_timestamps,
                    'upload_spreadsheet_treatment_data_level' : submit_params.additional_args.data_level,
                    'archived_file_id' : submit_params.file_id,
                    'ignore_warnings' : ignore_warnings
                },
                success: function(response) {
                    if (response.error) {
                        //alert(`An error occurred: ${response.error}`); //This always errors for some reason, even if nothing bad happened.
                        console.log(response.error);
                    }
                    refresh_upload_tables();
                },
                error: function() {
                    alert("An error occurred submitting treatment validation, check console.");
                    return;
                }
            });
            break;
        default :
            jQuery('#working_modal').modal("hide");   
            alert("Something strange happened... I got an invalid upload type: "+submit_params.upload_type);
            break;
    }

    jQuery('#working_modal').modal("hide");

    setTimeout(function() {
        refresh_upload_tables();
    }, 1500);
}

export function commit_upload_job(job_id) {
    let job = job_dict[job_id];
    let upload_type = job.args.additional_args.file_type;

    jQuery('#working_modal').modal("show");

    console.dir(job.args);

    switch(upload_type) {
        case 'phenotyping_spreadsheet' :
            jQuery.ajax({
                url: '/ajax/phenotype/upload_store/spreadsheet',
                type : 'POST',
                data : {
                    'upload_spreadsheet_phenotype_file_format' : job.args.additional_args.upload_spreadsheet_phenotype_file_format,
                    'upload_spreadsheet_phenotype_timestamp_checkbox' : job.args.additional_args.upload_spreadsheet_phenotype_timestamp_checkbox,
                    'upload_spreadsheet_phenotype_data_level' : job.args.additional_args.upload_spreadsheet_phenotype_data_level,
                    'archived_file_id' : job.args.additional_args.file_id
                },
                success: function(response) {
                    jQuery('#working_modal').modal("hide");  
                    if (response.error) {
                        //alert(`An error occurred: ${response.error}`); //This always errors for some reason, even if nothing bad happened.
                        console.log(response.error);
                    }
                    refresh_upload_tables();
                },
                error: function() {
                    jQuery('#working_modal').modal("hide");  
                    alert("An error occurred submitting phenotype validation, check console.");
                    return;
                }
            });
            break;
        case 'treatments' : 
            jQuery.ajax({
                url: '/ajax/phenotype/upload_store/spreadsheet/treatment',
                type : 'POST',
                data : {
                    'upload_spreadsheet_treatment_file_format' : job.args.additional_args.upload_spreadsheet_phenotype_file_format,
                    'upload_spreadsheet_treatment_timestamp_checkbox' : job.args.additional_args.upload_spreadsheet_phenotype_timestamp_checkbox,
                    'upload_spreadsheet_treatment_data_level' : job.args.additional_args.upload_spreadsheet_phenotype_data_level,
                    'archived_file_id' : job.args.additional_args.file_id
                },
                success: function(response) {
                    jQuery('#working_modal').modal("hide");  
                    if (response.error) {
                        //alert(`An error occurred: ${response.error}`); //This always errors for some reason, even if nothing bad happened.
                        console.log(response.error);
                    }
                    refresh_upload_tables();
                },
                error: function() {
                    jQuery('#working_modal').modal("hide");  
                    alert("An error occurred submitting phenotype validation, check console.");
                    return;
                }
            });
            break;
        default : 
            jQuery('#working_modal').modal("hide");  
            alert("Something strange happened... I got an invalid job type: "+upload_type);
            break;
    }
}

export function save_file_type(file_id, type) {

    jQuery.ajax({
        url : `/ajax/file/${file_id}/set_file_type/${type}`,
        type : 'POST',
        success : function(response) {
            if (response.error) {
                alert(response.error);
            }
        },
        error : function() {
            alert("An error occurred setting a file type, check console.");
        }
    });
}
