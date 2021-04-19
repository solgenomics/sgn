
=head1 NAME

=head1 DESCRIPTION

=head1 AUTHOR

=cut

package SGN::Controller::DroneImagery::DroneImageryUpload;

use Moose;
use Data::Dumper;
use JSON;
use SGN::Model::Cvterm;
use DateTime;
use Math::Round;
use Time::Piece;
use Time::Seconds;
use SGN::Image;
use CXGN::DroneImagery::ImagesSearch;
use File::Basename qw | basename dirname|;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Calendar;
use Image::Size;
use CXGN::DroneImagery::ImageTypes;
use LWP::UserAgent;
use CXGN::ZipFile;
use Text::CSV;
use SGN::Controller::AJAX::DroneImagery::DroneImagery;

BEGIN { extends 'Catalyst::Controller'; }

sub upload_drone_imagery_bulk : Path("/drone_imagery/upload_drone_imagery_bulk") :Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();
    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
    my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my %seen_field_trial_drone_run_dates;
    my $drone_run_date_q = "SELECT drone_run_date.value
        FROM project AS drone_run_band_project
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
        JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id);";
    my $drone_run_date_h = $schema->storage->dbh()->prepare($drone_run_date_q);
    $drone_run_date_h->execute();
    while( my ($drone_run_date) = $drone_run_date_h->fetchrow_array()) {
        my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        if ($drone_run_date_formatted) {
            my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
            $seen_field_trial_drone_run_dates{$date_obj->epoch}++;
        }
    }

    my $upload_file = $c->req->upload('upload_drone_imagery_bulk_images_zipfile');
    my $imaging_events_file = $c->req->upload('upload_drone_imagery_bulk_imaging_events');

    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $upload_imaging_events_file = $imaging_events_file->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => "drone_imagery_upload_bulk_orthophoto_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{message} = "Could not save file $upload_original_name in archive.";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    unlink $upload_tempfile;
    print STDERR "Archived Drone Image Bulk Orthophoto Zip File: $archived_filename_with_path\n";

    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$archived_filename_with_path);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        $c->stash->{message} = 'Could not read your orthophoto bulk zipfile. Is it .zip format?';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my %spectral_lookup = (
        blue => "Blue (450-520nm)",
        green => "Green (515-600nm)",
        red => "Red (600-690nm)",
        rededge => "Red Edge (690-750nm)",
        nir => "NIR (780-3000nm)",
        mir => "MIR (3000-50000nm)",
        fir => "FIR (50000-1000000nm)",
        thir => "Thermal IR (9000-14000nm)",
        rgb => "RGB Color Image",
        bw => "Black and White Image"
    );

    my %sensor_map = (
        "MicaSense 5 Channel Camera" => "micasense_5",
        "CCD Color Camera" => "ccd_color",
        "CMOS Color Camera" => "cmos_color"
    );

    my %filename_imaging_event_lookup;
    my %filename_imaging_event_band_check;
    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp)==1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }
        my @filename_comps = split '\.', $filename_wext;
        my $filename_only = $filename_comps[0];
        my @image_spectra = split '\_\_', $filename_only;
        my $temp_file = $image->upload_zipfile_images($_);
        my $imaging_event_name = $image_spectra[0];
        my $band = $image_spectra[1];

        if (!exists($spectral_lookup{$band})) {
            $c->stash->{message} = "The spectral band $band is not allowed in the provided orthophoto $filename_only. Make sure the orthophotos are saved as a concatenation of the imaging event name and the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020__blue.tiff) and the allowed spectral bands are blue,green,red,rededge,nir,mir,fir,thir,rgb,bw.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $spectral_band = $spectral_lookup{$band};
        print STDERR Dumper [$filename_wext, $filename, $temp_file, $imaging_event_name, $spectral_band];
        $filename_imaging_event_lookup{$filename_wext} = {
            file => $temp_file,
            band => $spectral_band,
            band_short => $band
        };
        if (exists($filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band})) {
            $c->stash->{message} = "Do not upload duplicate spectral types for the same imaging event. There is already a $band image for $imaging_event_name in the zipfile! Make sure the orthophotos are saved as a concatenation of the imaging event name and the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020__blue.tiff)";
            $c->stash->{template} = 'generic_message.mas';
            return;
        } else {
            $filename_imaging_event_band_check{$imaging_event_name} = $spectral_band;
        }
    }

    my @parse_csv_errors;
    my %field_trial_name_lookup;
    my %vehicle_name_lookup;

    my $parser = Spreadsheet::ParseExcel->new();
    my $excel_obj = $parser->parse($upload_imaging_events_file);
    if (!$excel_obj) {
        $c->stash->{message} = 'The Excel (.xls) file could not be opened:'.$parser->error();
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        $c->stash->{message} = 'Spreadsheet must be on 1st tab in Excel (.xls) file.';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        $c->stash->{message} = 'Spreadsheet (.xls) is missing header or contains no rows.';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    if ($worksheet->get_cell(0,0)->value() ne 'Imaging Event Name' ||
        $worksheet->get_cell(0,1)->value() ne 'Type' ||
        $worksheet->get_cell(0,2)->value() ne 'Description' ||
        $worksheet->get_cell(0,3)->value() ne 'Date' ||
        $worksheet->get_cell(0,4)->value() ne 'Vehicle Name' ||
        $worksheet->get_cell(0,5)->value() ne 'Vehicle Battery Set' ||
        $worksheet->get_cell(0,6)->value() ne 'Sensor' ||
        $worksheet->get_cell(0,7)->value() ne 'Field Trial Name' ||
        $worksheet->get_cell(0,8)->value() ne 'Image Filenames' ||
        $worksheet->get_cell(0,9)->value() ne 'Coordinate System' ||
        $worksheet->get_cell(0,10)->value() ne 'Base Date' ||
        $worksheet->get_cell(0,11)->value() ne 'Camera Rig') {
            $c->stash->{message} = "The header row in the CSV spreadsheet must be 'Imaging Event Name,Type,Description,Date,Vehicle Name,Vehicle Battery Set,Sensor,Field Trial Name,GeoJSON Filename,Image Filenames,Coordinate System,Base Date,Camera Rig'.";
            $c->stash->{template} = 'generic_message.mas';
            return;
    }

    my %seen_upload_dates;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name;
        if ($worksheet->get_cell($row,0)) {
            $imaging_event_name = $worksheet->get_cell($row,0)->value();
        }
        my $imaging_event_type;
        if ($worksheet->get_cell($row,1)) {
            $imaging_event_type = $worksheet->get_cell($row,1)->value();
        }
        my $imaging_event_desc;
        if ($worksheet->get_cell($row,2)) {
            $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        }
        my $imaging_event_date;
        if ($worksheet->get_cell($row,3)) {
            $imaging_event_date = $worksheet->get_cell($row,3)->value();
        }
        my $vehicle_name;
        if ($worksheet->get_cell($row,4)) {
            $vehicle_name = $worksheet->get_cell($row,4)->value();
        }
        my $vehicle_battery = 'default_battery';
        if ($worksheet->get_cell($row,5)) {
            $vehicle_battery = $worksheet->get_cell($row,5)->value();
        }
        my $sensor;
        if ($worksheet->get_cell($row,6)) {
            $sensor = $worksheet->get_cell($row,6)->value();
        }
        my $field_trial_name;
        if ($worksheet->get_cell($row,7)) {
            $field_trial_name = $worksheet->get_cell($row,7)->value();
        }
        my $image_filenames;
        if ($worksheet->get_cell($row,8)) {
            $image_filenames = $worksheet->get_cell($row,8)->value();
        }
        my $coordinate_system;
        if ($worksheet->get_cell($row,9)) {
            $coordinate_system = $worksheet->get_cell($row,9)->value();
        }
        my $base_date;
        if ($worksheet->get_cell($row,10)) {
            $base_date = $worksheet->get_cell($row,10)->value();
        }
        my $rig_desc;
        if ($worksheet->get_cell($row,11)) {
            $rig_desc = $worksheet->get_cell($row,11)->value();
        }

        if (!$imaging_event_name){
            push @parse_csv_errors, "Please give a new imaging event name!";
        }
        if (!$imaging_event_type){
            push @parse_csv_errors, "Please give an imaging event type!";
        }
        if (!$imaging_event_desc){
            push @parse_csv_errors, "Please give an imaging event description!";
        }
        if (!$imaging_event_date){
            push @parse_csv_errors, "Please give an imaging event date!";
        }
        if (!$vehicle_name){
            push @parse_csv_errors, "Please give a vehicle name!";
        }
        if (!$sensor){
            push @parse_csv_errors, "Please give a sensor name!";
        }
        if (!$field_trial_name){
            push @parse_csv_errors, "Please give a field trial name!";
        }

        if ($coordinate_system ne 'UTM' && $coordinate_system ne 'WGS84' && $coordinate_system ne 'Pixels') {
            push @parse_csv_errors, "The given coordinate system $coordinate_system is not one of: UTM, WGS84, or Pixels!";
        }
        if ($coordinate_system ne 'Pixels') {
            $c->stash->{message} = "Only the Pixels coordinate system is currently supported for this upload. In the future GeoTIFFs will be supported, but for now please only upload simple raster images (.png, .tiff, .jpg).";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }

        my $field_trial_rs = $schema->resultset("Project::Project")->search({name=>$field_trial_name});
        if ($field_trial_rs->count != 1) {
            $c->stash->{message} = "The field trial $field_trial_name does not exist in the database already! Please add it first.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $field_trial_id = $field_trial_rs->first->project_id();
        $field_trial_name_lookup{$field_trial_name} = $field_trial_id;

        if ($imaging_event_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
            $c->stash->{message} = "Please give a new imaging event date in the format YYYY/MM/DD HH:mm:ss! The provided $imaging_event_date is not correct!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if ($imaging_event_type ne 'Aerial Medium to High Res' && $imaging_event_type ne 'Aerial Low Res'){
            $c->stash->{message} = "The imaging event type $imaging_event_type is not one of 'Aerial Low Res' or 'Aerial Medium to High Res'!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if (!exists($sensor_map{$sensor})){
            $c->stash->{message} = "The sensor $sensor is not one of 'MicaSense 5 Channel Camera' or 'CCD Color Camera' or 'CMOS Color Camera'!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }

        my $project_rs = $schema->resultset("Project::Project")->search({name=>$imaging_event_name});
        if ($project_rs->count > 0) {
            push @parse_csv_errors, "Please use a globally unique imaging event name! The name you specified $imaging_event_name has already been used.";
        }
        my $vehicle_prop = $schema->resultset("Stock::Stock")->search({uniquename => $vehicle_name, type_id=>$imaging_vehicle_cvterm_id});
        if ($vehicle_prop->count != 1) {
            push @parse_csv_errors, "Imaging event vehicle $vehicle_name is not already in the database! Please add it first!";
        }
        else {
            $vehicle_name_lookup{$vehicle_name} = $vehicle_prop->first->stock_id;
        }

        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id });
        my $planting_date = $trial->get_planting_date();
        if (!$planting_date) {
            $c->stash->{message} = "The field trial $field_trial_name does not have a planting date set! Please set this first!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");

        if (exists($seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch})) {
            $c->stash->{message} = "An imaging event has already occured on this field trial at the same date and time ($imaging_event_date)! Please give a unique date/time for each imaging event!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        $seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch}++;

        if ($imaging_event_date_time_object->epoch - $planting_date_time_object->epoch <= 0) {
            push @parse_csv_errors, "The date of the imaging event $imaging_event_date is not after the field trial planting date $planting_date!";
        }
        if ($base_date) {
            if ($base_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
                $c->stash->{message} = "Please give a new imaging event base date in the format YYYY/MM/DD HH:mm:ss! The provided $base_date is not correct! Leave empty if not relevant!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            my $imaging_event_base_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");

            if ($imaging_event_date_time_object->epoch - $imaging_event_base_time_object->epoch < 0) {
                push @parse_csv_errors, "The date of the imaging event $imaging_event_date is not after the base date $base_date!";
            }
        }

        my @orthoimage_names = split ',', $image_filenames;
        foreach (@orthoimage_names) {
            if (!exists($filename_imaging_event_lookup{$_})) {
                push @parse_csv_errors, "The orthophoto filename $_ does not exist in the uploaded orthophoto zipfile. Make sure the orthophotos are saved as a concatenation of the ortho filename defined in the spreadsheet and the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020__blue.tiff)";
            }
        }
    }

    if (scalar(@parse_csv_errors) > 0) {
        my $error_string = join "<br/>", @parse_csv_errors;
        $c->stash->{message} = $error_string;
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my @drone_run_project_ids;
    my %drone_run_band_hash;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name = $worksheet->get_cell($row,0)->value();
        my $imaging_event_type = $worksheet->get_cell($row,1)->value();
        my $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        my $imaging_event_date = $worksheet->get_cell($row,3)->value();
        my $vehicle_name = $worksheet->get_cell($row,4)->value();
        my $vehicle_battery = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : 'default_battery';
        my $sensor = $worksheet->get_cell($row,6)->value();
        my $field_trial_name = $worksheet->get_cell($row,7)->value();
        my $image_filenames = $worksheet->get_cell($row,8)->value();
        my $coordinate_system = $worksheet->get_cell($row,9)->value();
        my $base_date = $worksheet->get_cell($row,10) ? $worksheet->get_cell($row,10)->value() : '';
        my $rig_desc = $worksheet->get_cell($row,11) ? $worksheet->get_cell($row,11)->value() : '';

        my $new_drone_run_vehicle_id = $vehicle_name_lookup{$vehicle_name};
        my $selected_trial_id = $field_trial_name_lookup{$field_trial_name};
        my $new_drone_run_camera_info = $sensor_map{$sensor};
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");
        my $drone_run_event = $calendar_funcs->check_value_format($imaging_event_date);
        my $time_diff;
        my $base_date_event;
        if ($base_date) {
            my $imaging_event_base_date_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");
            $time_diff = $imaging_event_date_time_object - $imaging_event_base_date_time_object;
            $base_date_event = $calendar_funcs->check_value_format($base_date);
        }
        else {
            $time_diff = $imaging_event_date_time_object - $planting_date_time_object;
        }
        my $time_diff_weeks = $time_diff->weeks;
        my $time_diff_days = $time_diff->days;
        my $time_diff_hours = $time_diff->hours;
        my $rounded_time_diff_weeks = round($time_diff_weeks);
        if ($rounded_time_diff_weeks == 0) {
            $rounded_time_diff_weeks = 1;
        }

        my $week_term_string = "week $rounded_time_diff_weeks";
        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($week_term_string, 'cxgn_time_ontology');
        my ($week_cvterm_id) = $h->fetchrow_array();

        if (!$week_cvterm_id) {
            my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $week_term_string,
               cv => 'cxgn_time_ontology'
            });
            $week_cvterm_id = $new_week_term->cvterm_id();
        }

        my $day_term_string = "day $time_diff_days";
        $h->execute($day_term_string, 'cxgn_time_ontology');
        my ($day_cvterm_id) = $h->fetchrow_array();

        if (!$day_cvterm_id) {
            my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $day_term_string,
               cv => 'cxgn_time_ontology'
            });
            $day_cvterm_id = $new_day_term->cvterm_id();
        }

        my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
        my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

        my %related_cvterms = (
            week => $week_term,
            day => $day_term
        );

        my $drone_run_projectprops = [
            {type_id => $drone_run_type_cvterm_id, value => $imaging_event_type},
            {type_id => $project_start_date_type_id, value => $drone_run_event},
            {type_id => $design_cvterm_id, value => 'drone_run'},
            {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info},
            {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}
        ];
        if ($base_date) {
            push @$drone_run_projectprops, {type_id => $drone_run_base_date_type_id, value => $base_date_event};
        }
        if ($rig_desc) {
            push @$drone_run_projectprops, {type_id => $drone_run_rig_desc_type_id, value => $rig_desc};
        }

        my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->create({
            nd_geolocation_id => $trial_location_id,
            type_id => $drone_run_experiment_type_id,
            nd_experiment_stocks => [{stock_id => $new_drone_run_vehicle_id, type_id => $drone_run_experiment_type_id}]
        });
        my $drone_run_nd_experiment_id = $nd_experiment_rs->nd_experiment_id();

        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $imaging_event_name,
            description => $imaging_event_desc,
            projectprops => $drone_run_projectprops,
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}],
            nd_experiment_projects => [{nd_experiment_id => $drone_run_nd_experiment_id}]
        });
        my $selected_drone_run_id = $project_rs->project_id();
        push @drone_run_project_ids, $selected_drone_run_id;

        my $vehicle_prop = decode_json $schema->resultset("Stock::Stockprop")->search({stock_id => $new_drone_run_vehicle_id, type_id=>$imaging_vehicle_properties_cvterm_id})->first()->value();
        $vehicle_prop->{batteries}->{$vehicle_battery}->{usage}++;
        my $vehicle_prop_update = $schema->resultset('Stock::Stockprop')->update_or_create({
            type_id=>$imaging_vehicle_properties_cvterm_id,
            stock_id=>$new_drone_run_vehicle_id,
            rank=>0,
            value=>encode_json $vehicle_prop
        },
        {
            key=>'stockprop_c1'
        });

        my @orthoimage_names = split ',', $image_filenames;
        my @ortho_images;
        foreach (@orthoimage_names) {
            push @ortho_images, $filename_imaging_event_lookup{$_};
        }
        foreach my $m (@ortho_images) {
            my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
            my $band = $m->{band};
            my $band_short = $m->{band_short};
            my $file = $m->{file};
            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $imaging_event_name."_".$band_short,
                description => $imaging_event_desc.". ".$band,
                projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $band}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $imaging_event_name."_".$band_short.".png";

            my $uploader = CXGN::UploadFile->new({
                tempfile => $file,
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Bulk Orthophoto File: $archived_filename_with_path\n";

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);

            push @{$drone_run_band_hash{$selected_drone_run_id}}, {
                drone_run_band_project_id => $selected_drone_run_band_id,
                band => $band
            };
        }
    }

    $c->stash->{message} = "Uploaded Successfully!";
    $c->stash->{template} = 'generic_message.mas';
    return;
}

sub upload_drone_imagery_bulk_previous : Path("/drone_imagery/upload_drone_imagery_bulk_previous") :Args(0) {
    my $self = shift;
    my $c = shift;
    $c->response->headers->header( "Access-Control-Allow-Origin" => '*' );
    $c->response->headers->header( "Access-Control-Allow-Methods" => "POST, GET, PUT, DELETE" );
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $dbh = $c->dbc->dbh;
    my ($user_id, $user_name, $user_role) = _check_user_login($c);
    print STDERR Dumper $c->req->params();

    my $imaging_vehicle_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();
    my $imaging_vehicle_properties_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle_json', 'stock_property')->cvterm_id();
    my $drone_run_experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_experiment', 'experiment_type')->cvterm_id();
    my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
    my $geoparam_coordinates_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_geoparam_coordinates', 'project_property')->cvterm_id();
    my $drone_run_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_project_type', 'project_property')->cvterm_id();
    my $drone_run_is_raw_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_is_raw_images', 'project_property')->cvterm_id();
    my $drone_run_camera_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_type', 'project_property')->cvterm_id();
    my $project_start_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_start_date', 'project_property')->cvterm_id();
    my $drone_run_base_date_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_base_date', 'project_property')->cvterm_id();
    my $drone_run_rig_desc_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_camera_rig_description', 'project_property')->cvterm_id();
    my $drone_run_related_cvterms_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_related_time_cvterms_json', 'project_property')->cvterm_id();
    my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_on_field_trial', 'project_relationship')->cvterm_id();
    my $process_indicator_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_in_progress', 'project_property')->cvterm_id();
    my $processed_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_completed', 'project_property')->cvterm_id();
    my $processed_minimal_vi_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_standard_process_vi_completed', 'project_property')->cvterm_id();
    my $drone_run_band_type_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
    my $rotate_angle_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_rotate_angle', 'project_property')->cvterm_id();
    my $cropping_polygon_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_cropped_polygon', 'project_property')->cvterm_id();
    my $plot_polygon_template_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_plot_polygons', 'project_property')->cvterm_id();
    my $project_image_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    my $drone_run_drone_run_band_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
    my $calendar_funcs = CXGN::Calendar->new({});

    my %seen_field_trial_drone_run_dates;
    my $drone_run_date_q = "SELECT drone_run_date.value
        FROM project AS drone_run_band_project
        JOIN project_relationship AS drone_run_band_rel ON (drone_run_band_rel.subject_project_id = drone_run_band_project.project_id AND drone_run_band_rel.type_id = $drone_run_drone_run_band_type_id)
        JOIN project AS drone_run_project ON (drone_run_band_rel.object_project_id = drone_run_project.project_id)
        JOIN projectprop AS drone_run_date ON(drone_run_project.project_id=drone_run_date.project_id AND drone_run_date.type_id=$project_start_date_type_id);";
    my $drone_run_date_h = $schema->storage->dbh()->prepare($drone_run_date_q);
    $drone_run_date_h->execute();
    while( my ($drone_run_date) = $drone_run_date_h->fetchrow_array()) {
        my $drone_run_date_formatted = $drone_run_date ? $calendar_funcs->display_start_date($drone_run_date) : '';
        if ($drone_run_date_formatted) {
            my $date_obj = Time::Piece->strptime($drone_run_date_formatted, "%Y-%B-%d %H:%M:%S");
            $seen_field_trial_drone_run_dates{$date_obj->epoch}++;
        }
    }

    my %spectral_lookup = (
        blue => "Blue (450-520nm)",
        green => "Green (515-600nm)",
        red => "Red (600-690nm)",
        rededge => "Red Edge (690-750nm)",
        nir => "NIR (780-3000nm)",
        mir => "MIR (3000-50000nm)",
        fir => "FIR (50000-1000000nm)",
        thir => "Thermal IR (9000-14000nm)",
        rgb => "RGB Color Image",
        bw => "Black and White Image"
    );

    my %sensor_map = (
        "MicaSense 5 Channel Camera" => "micasense_5",
        "CCD Color Camera" => "ccd_color",
        "CMOS Color Camera" => "cmos_color"
    );

    my $upload_file = $c->req->upload('upload_drone_imagery_bulk_images_zipfile_previous');
    my $upload_geojson_file = $c->req->upload('upload_drone_imagery_bulk_geojson_zipfile_previous');
    my $imaging_events_file = $c->req->upload('upload_drone_imagery_bulk_imaging_events_previous');

    my $upload_original_name = $upload_file->filename();
    my $upload_tempfile = $upload_file->tempname;
    my $upload_geojson_original_name = $upload_geojson_file->filename();
    my $upload_geojson_tempfile = $upload_geojson_file->tempname;
    my $upload_imaging_events_file = $imaging_events_file->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => "drone_imagery_upload_bulk_previous_orthophoto_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
        $c->detach();
    }
    unlink $upload_tempfile;
    print STDERR "Archived Drone Image Bulk Previous Orthophoto Zip File: $archived_filename_with_path\n";

    my $archived_zip = CXGN::ZipFile->new(archived_zipfile_path=>$archived_filename_with_path);
    my $file_members = $archived_zip->file_members();
    if (!$file_members){
        $c->stash->{message} = 'Could not read your orthophoto bulk zipfile. Is it .zip format';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my %filename_imaging_event_lookup;
    my %filename_imaging_event_band_check;
    foreach (@$file_members) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp)==1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }
        my @filename_comps = split '\.', $filename_wext;
        my $filename_only = $filename_comps[0];
        my @image_spectra = split '\_\_', $filename_only;
        my $temp_file = $image->upload_zipfile_images($_);
        my $imaging_event_name = $image_spectra[0];
        my $band = $image_spectra[1];

        if (!exists($spectral_lookup{$band})) {
            $c->stash->{message} = "The spectral band $band is not allowed in the provided orthophoto $filename. Make sure the orthophotos are saved as a concatenation with the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020__blue.tiff) and the allowed spectral bands are blue,green,red,rededge,nir,mir,fir,thir,rgb,bw.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $spectral_band = $spectral_lookup{$band};
        print STDERR Dumper [$filename_wext, $filename, $temp_file, $imaging_event_name, $spectral_band];
        $filename_imaging_event_lookup{$filename_wext} = {
            file => $temp_file,
            band => $spectral_band,
            band_short => $band
        };
        if (exists($filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band})) {
            $c->stash->{message} = "Do not upload duplicate spectral types for the same imaging event. There is already a $band image for $imaging_event_name in the zipfile! Make sure the orthophotos are saved as a concatenation of the imaging event name and the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020__blue.tiff)";
            $c->stash->{template} = 'generic_message.mas';
            return;
        } else {
            $filename_imaging_event_band_check{$imaging_event_name}->{$spectral_band}++;
        }
    }

    my $uploader_geojson = CXGN::UploadFile->new({
        tempfile => $upload_geojson_tempfile,
        subdirectory => "drone_imagery_upload_bulk_previous_geojson_zips",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_geojson_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $geojson_archived_filename_with_path = $uploader_geojson->archive();
    my $md5_geojson = $uploader_geojson->get_md5($geojson_archived_filename_with_path);
    if (!$geojson_archived_filename_with_path) {
        $c->stash->{message} = "Could not save file $upload_geojson_original_name in archive.";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    unlink $upload_geojson_tempfile;
    print STDERR "Archived Drone Image Bulk Previous GeoJSON Zip File: $geojson_archived_filename_with_path\n";

    my $archived_zip_geojson = CXGN::ZipFile->new(archived_zipfile_path=>$geojson_archived_filename_with_path);
    my $file_members_geojson = $archived_zip_geojson->file_members();
    if (!$file_members_geojson){
        $c->stash->{message} = 'Could not read your geojson bulk zipfile. Is it .zip format?';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my %filename_imaging_event_geojson_lookup;
    foreach (@$file_members_geojson) {
        my $image = SGN::Image->new( $dbh, undef, $c );
        my $filename = $_->fileName();
        my $temp_file = $image->upload_zipfile_images($_);

        my @zipfile_comp = split '\/', $filename;
        my $filename_wext;
        if (scalar(@zipfile_comp) == 1) {
            $filename_wext = $zipfile_comp[0];
        }
        else {
            $filename_wext = $zipfile_comp[1];
        }

        print STDERR Dumper [$filename, $temp_file, $filename_wext];
        $filename_imaging_event_geojson_lookup{$filename_wext} = $temp_file;

        open(my $fh_geojson_check, '<', $temp_file) or die "Could not open file '$temp_file' $!";
            print STDERR "Opened $temp_file\n";
            my $geojson_value_check = decode_json <$fh_geojson_check>;
            # print STDERR Dumper $geojson_value_check;
            if (!$geojson_value_check->{features}) {
                $c->stash->{message} = 'The GeoJSON file '.$filename.' does not have a \'features\' key in it. Make sure the GeoJSON is formatted correctly.';
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            foreach (@{$geojson_value_check->{features}}) {
                if (!$_->{properties}) {
                    $c->stash->{message} = 'The GeoJSON file '.$filename.' does not have a \'properties\' key in it. Make sure the GeoJSON is formatted correctly.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!$_->{properties}->{ID}) {
                    $c->stash->{message} = 'The GeoJSON file '.$filename.' does not have an \'ID\' key in the \'properties\' object. Make sure the GeoJSON is formatted correctly.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!$_->{geometry}) {
                    $c->stash->{message} = 'The GeoJSON file '.$filename.' does not have a \'geometry\' key in it. Make sure the GeoJSON is formatted correctly.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (!$_->{geometry}->{coordinates}) {
                    $c->stash->{message} = 'The GeoJSON file '.$filename.' does not have a \'coordinates\' key in the \'geometry\' object. Make sure the GeoJSON is formatted correctly.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
                if (scalar(@{$_->{geometry}->{coordinates}->[0]}) != 5) {
                    $c->stash->{message} = 'The GeoJSON file '.$filename.' \'coordinates\' first object does not have 5 objects in it. The polygons must be rectangular Make sure the GeoJSON is formatted correctly.';
                    $c->stash->{template} = 'generic_message.mas';
                    return;
                }
            }
        close($fh_geojson_check);
    }

    my @parse_csv_errors;
    my %field_trial_name_lookup;
    my %field_trial_layout_lookup;
    my %vehicle_name_lookup;

    my $parser = Spreadsheet::ParseExcel->new();
    my $excel_obj = $parser->parse($upload_imaging_events_file);
    if (!$excel_obj) {
        $c->stash->{message} = 'The Excel (.xls) file could not be opened:'.$parser->error();
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my $worksheet = ( $excel_obj->worksheets() )[0]; #support only one worksheet
    if (!$worksheet) {
        $c->stash->{message} = 'Spreadsheet must be on 1st tab in Excel (.xls) file.';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    my ( $row_min, $row_max ) = $worksheet->row_range();
    my ( $col_min, $col_max ) = $worksheet->col_range();
    if (($col_max - $col_min)  < 1 || ($row_max - $row_min) < 1 ) { #must have header and at least one row of plot data
        $c->stash->{message} = 'Spreadsheet (.xls) is missing header or contains no rows.';
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    if ($worksheet->get_cell(0,0)->value() ne 'Imaging Event Name' ||
        $worksheet->get_cell(0,1)->value() ne 'Type' ||
        $worksheet->get_cell(0,2)->value() ne 'Description' ||
        $worksheet->get_cell(0,3)->value() ne 'Date' ||
        $worksheet->get_cell(0,4)->value() ne 'Vehicle Name' ||
        $worksheet->get_cell(0,5)->value() ne 'Vehicle Battery Set' ||
        $worksheet->get_cell(0,6)->value() ne 'Sensor' ||
        $worksheet->get_cell(0,7)->value() ne 'Field Trial Name' ||
        $worksheet->get_cell(0,8)->value() ne 'GeoJSON Filename' ||
        $worksheet->get_cell(0,9)->value() ne 'Image Filenames' ||
        $worksheet->get_cell(0,10)->value() ne 'Coordinate System' ||
        $worksheet->get_cell(0,11)->value() ne 'Rotation Angle' ||
        $worksheet->get_cell(0,12)->value() ne 'Base Date' ||
        $worksheet->get_cell(0,13)->value() ne 'Camera Rig') {
            $c->stash->{message} = "The header row in the CSV spreadsheet must be 'Imaging Event Name,Type,Description,Date,Vehicle Name,Vehicle Battery Set,Sensor,Field Trial Name,GeoJSON Filename,Image Filenames,Coordinate System,Rotation Angle,Base Date,Camera Rig'.";
            $c->stash->{template} = 'generic_message.mas';
            return;
    }

    my %seen_upload_dates;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name;
        if ($worksheet->get_cell($row,0)) {
            $imaging_event_name = $worksheet->get_cell($row,0)->value();
        }
        my $imaging_event_type;
        if ($worksheet->get_cell($row,1)) {
            $imaging_event_type = $worksheet->get_cell($row,1)->value();
        }
        my $imaging_event_desc;
        if ($worksheet->get_cell($row,2)) {
            $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        }
        my $imaging_event_date;
        if ($worksheet->get_cell($row,3)) {
            $imaging_event_date = $worksheet->get_cell($row,3)->value();
        }
        my $vehicle_name;
        if ($worksheet->get_cell($row,4)) {
            $vehicle_name = $worksheet->get_cell($row,4)->value();
        }
        my $vehicle_battery = 'default_battery';
        if ($worksheet->get_cell($row,5)) {
            $vehicle_battery = $worksheet->get_cell($row,5)->value();
        }
        my $sensor;
        if ($worksheet->get_cell($row,6)) {
            $sensor = $worksheet->get_cell($row,6)->value();
        }
        my $field_trial_name;
        if ($worksheet->get_cell($row,7)) {
            $field_trial_name = $worksheet->get_cell($row,7)->value();
        }
        my $geojson_filename;
        if ($worksheet->get_cell($row,8)) {
            $geojson_filename = $worksheet->get_cell($row,8)->value();
        }
        my $image_filenames;
        if ($worksheet->get_cell($row,9)) {
            $image_filenames = $worksheet->get_cell($row,9)->value();
        }
        my $coordinate_system;
        if ($worksheet->get_cell($row,10)) {
            $coordinate_system = $worksheet->get_cell($row,10)->value();
        }
        my $rotation_angle;
        if ($worksheet->get_cell($row,11)) {
            $rotation_angle = $worksheet->get_cell($row,11)->value();
        }
        my $base_date;
        if ($worksheet->get_cell($row,12)) {
            $base_date = $worksheet->get_cell($row,12)->value();
        }
        my $rig_desc;
        if ($worksheet->get_cell($row,13)) {
            $rig_desc = $worksheet->get_cell($row,13)->value();
        }

        if (!$imaging_event_name){
            push @parse_csv_errors, "Please give a new imaging event name!";
        }
        if (!$imaging_event_type){
            push @parse_csv_errors, "Please give an imaging event type!";
        }
        if (!$imaging_event_desc){
            push @parse_csv_errors, "Please give an imaging event description!";
        }
        if (!$imaging_event_date){
            push @parse_csv_errors, "Please give an imaging event date!";
        }
        if (!$vehicle_name){
            push @parse_csv_errors, "Please give a vehicle name!";
        }
        if (!$sensor){
            push @parse_csv_errors, "Please give a sensor name!";
        }
        if (!$field_trial_name){
            push @parse_csv_errors, "Please give a field trial name!";
        }
        if (defined($rotation_angle) && ($rotation_angle < 0 || $rotation_angle > 360) ) {
            push @parse_csv_errors, "Rotation angle $rotation_angle not valid! Must be clock-wise between 0 and 360!";
        }

        if ($coordinate_system ne 'UTM' && $coordinate_system ne 'WGS84' && $coordinate_system ne 'Pixels') {
            push @parse_csv_errors, "The given coordinate system $coordinate_system is not one of: UTM, WGS84, or Pixels!";
        }
        # if ($coordinate_system ne 'Pixels') {
        #     $c->stash->{rest} = {error => "Only the Pixels coordinate system is currently supported. In the future GeoTIFFs will be supported, but for now please only upload simple raster images (.png, .tiff, .jpg)." };
        #     $c->detach;
        # }

        my $field_trial_rs = $schema->resultset("Project::Project")->search({name=>$field_trial_name});
        if ($field_trial_rs->count != 1) {
            $c->stash->{message} = "The field trial $field_trial_name does not exist in the database already! Please add it first.";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $field_trial_id = $field_trial_rs->first->project_id();
        $field_trial_name_lookup{$field_trial_name} = $field_trial_id;

        if ($imaging_event_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
            $c->stash->{message} = "Please give a new imaging event date in the format YYYY/MM/DD HH:mm:ss! The provided $imaging_event_date is not correct!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if ($imaging_event_type ne 'Aerial Medium to High Res' && $imaging_event_type ne 'Aerial Low Res'){
            $c->stash->{message} = "The imaging event type $imaging_event_type is not one of 'Aerial Low Res' or 'Aerial Medium to High Res'!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        if (!exists($sensor_map{$sensor})){
            $c->stash->{message} = "The sensor $sensor is not one of 'MicaSense 5 Channel Camera' or 'CCD Color Camera' or 'CMOS Color Camera'!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }

        my $project_rs = $schema->resultset("Project::Project")->search({name=>$imaging_event_name});
        if ($project_rs->count > 0) {
            push @parse_csv_errors, "Please use a globally unique imaging event name! The name you specified $imaging_event_name has already been used.";
        }
        my $vehicle_prop = $schema->resultset("Stock::Stock")->search({uniquename => $vehicle_name, type_id=>$imaging_vehicle_cvterm_id});
        if ($vehicle_prop->count != 1) {
            push @parse_csv_errors, "Imaging event vehicle $vehicle_name is not already in the database! Please add it first!";
        }
        else {
            $vehicle_name_lookup{$vehicle_name} = $vehicle_prop->first->stock_id;
        }

        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $field_trial_id });
        my $trial_layout = $trial->get_layout()->get_design();
        $field_trial_layout_lookup{$field_trial_id} = $trial_layout;

        my $planting_date = $trial->get_planting_date();
        if (!$planting_date) {
            $c->stash->{message} = "The field trial $field_trial_name does not have a planting date set! Please set this first!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");

        if (exists($seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch})) {
            $c->stash->{message} = "An imaging event has already occured on this field trial at the same date and time ($imaging_event_date)! Please give a unique date/time for each imaging event!";
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        $seen_field_trial_drone_run_dates{$imaging_event_date_time_object->epoch}++;

        if ($imaging_event_date_time_object->epoch - $planting_date_time_object->epoch <= 0) {
            push @parse_csv_errors, "The date of the imaging event $imaging_event_date is not after the field trial planting date $planting_date!";
        }
        if ($base_date) {
            if ($base_date !~ /^\d{4}\/\d{2}\/\d{2}\s\d\d:\d\d:\d\d$/){
                $c->stash->{message} = "Please give a new imaging event base date in the format YYYY/MM/DD HH:mm:ss! The provided $base_date is not correct! Leave empty if not relevant!";
                $c->stash->{template} = 'generic_message.mas';
                return;
            }
            my $imaging_event_base_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");

            if ($imaging_event_date_time_object->epoch - $imaging_event_base_time_object->epoch < 0) {
                push @parse_csv_errors, "The date of the imaging event $imaging_event_date is not after the base date $base_date!";
            }
        }

        my @orthoimage_names = split ',', $image_filenames;
        foreach (@orthoimage_names) {
            if (!exists($filename_imaging_event_lookup{$_})) {
                push @parse_csv_errors, "The orthophoto filename $_ does not exist in the uploaded orthophoto zipfile. Make sure the orthophotos are saved as a concatenation of the ortho filename defined in the spreadsheet and the spectral band, with a double-underscore (__) as the separator (e.g. Ortho1_01012020__blue.tiff)";
            }
        }
        if (!exists($filename_imaging_event_geojson_lookup{$geojson_filename})) {
            push @parse_csv_errors, "The GeoJSON filename $geojson_filename does not exist in the uploaded GeoJSON zipfile!";
        }
        open(my $fh_geojson_check, '<', $filename_imaging_event_geojson_lookup{$geojson_filename}) or die "Could not open file '".$filename_imaging_event_geojson_lookup{$geojson_filename}."' $!";
            print STDERR "Opened ".$filename_imaging_event_geojson_lookup{$geojson_filename}."\n";
            my $geojson_value_check = decode_json <$fh_geojson_check>;
            foreach (@{$geojson_value_check->{features}}) {
                my $plot_number = $_->{properties}->{ID};
                if (!exists($trial_layout->{$plot_number})) {
                    push @parse_csv_errors, "The ID $plot_number in the GeoJSON file $geojson_filename does not exist in the field trial $field_trial_name!";
                }
            }
        close($fh_geojson_check);
    }

    if (scalar(@parse_csv_errors) > 0) {
        my $error_string = join "<br/>", @parse_csv_errors;
        $c->stash->{message} = $error_string;
        $c->stash->{template} = 'generic_message.mas';
        return;
    }

    my $dir = $c->tempfiles_subdir('/upload_drone_imagery_bulk_previous');

    my @drone_run_project_ids;
    my @drone_run_projects;
    my %drone_run_project_info;
    for my $row ( 1 .. $row_max ) {
        my $imaging_event_name = $worksheet->get_cell($row,0)->value();
        my $imaging_event_type = $worksheet->get_cell($row,1)->value();
        my $imaging_event_desc = $worksheet->get_cell($row,2)->value();
        my $imaging_event_date = $worksheet->get_cell($row,3)->value();
        my $vehicle_name = $worksheet->get_cell($row,4)->value();
        my $vehicle_battery = $worksheet->get_cell($row,5) ? $worksheet->get_cell($row,5)->value() : 'default_battery';
        my $sensor = $worksheet->get_cell($row,6)->value();
        my $field_trial_name = $worksheet->get_cell($row,7)->value();
        my $geojson_filename = $worksheet->get_cell($row,8)->value();
        my $image_filenames = $worksheet->get_cell($row,9)->value();
        my $coordinate_system = $worksheet->get_cell($row,10)->value();
        my $rotation_angle = $worksheet->get_cell($row,11) ? $worksheet->get_cell($row,11)->value() : 0;
        my $base_date = $worksheet->get_cell($row,12) ? $worksheet->get_cell($row,12)->value() : '';
        my $rig_desc = $worksheet->get_cell($row,13) ? $worksheet->get_cell($row,13)->value() : '';

        my $new_drone_run_vehicle_id = $vehicle_name_lookup{$vehicle_name};
        my $selected_trial_id = $field_trial_name_lookup{$field_trial_name};
        my $new_drone_run_camera_info = $sensor_map{$sensor};
        my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $selected_trial_id });
        my $trial_location_id = $trial->get_location()->[0];
        my $planting_date = $trial->get_planting_date();
        my $planting_date_time_object = Time::Piece->strptime($planting_date, "%Y-%B-%d");
        my $imaging_event_date_time_object = Time::Piece->strptime($imaging_event_date, "%Y/%m/%d %H:%M:%S");
        my $drone_run_event = $calendar_funcs->check_value_format($imaging_event_date);
        my $time_diff;
        my $base_date_event;
        if ($base_date) {
            my $imaging_event_base_date_time_object = Time::Piece->strptime($base_date, "%Y/%m/%d %H:%M:%S");
            $time_diff = $imaging_event_date_time_object - $imaging_event_base_date_time_object;
            $base_date_event = $calendar_funcs->check_value_format($base_date);
        }
        else {
            $time_diff = $imaging_event_date_time_object - $planting_date_time_object;
        }
        my $time_diff_weeks = $time_diff->weeks;
        my $time_diff_days = $time_diff->days;
        my $time_diff_hours = $time_diff->hours;
        my $rounded_time_diff_weeks = round($time_diff_weeks);
        if ($rounded_time_diff_weeks == 0) {
            $rounded_time_diff_weeks = 1;
        }

        my $week_term_string = "week $rounded_time_diff_weeks";
        my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($week_term_string, 'cxgn_time_ontology');
        my ($week_cvterm_id) = $h->fetchrow_array();

        if (!$week_cvterm_id) {
            my $new_week_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $week_term_string,
               cv => 'cxgn_time_ontology'
            });
            $week_cvterm_id = $new_week_term->cvterm_id();
        }

        my $day_term_string = "day $time_diff_days";
        $h->execute($day_term_string, 'cxgn_time_ontology');
        my ($day_cvterm_id) = $h->fetchrow_array();

        if (!$day_cvterm_id) {
            my $new_day_term = $schema->resultset("Cv::Cvterm")->create_with({
               name => $day_term_string,
               cv => 'cxgn_time_ontology'
            });
            $day_cvterm_id = $new_day_term->cvterm_id();
        }

        my $week_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $week_cvterm_id, 'extended');
        my $day_term = SGN::Model::Cvterm::get_trait_from_cvterm_id($schema, $day_cvterm_id, 'extended');

        my %related_cvterms = (
            week => $week_term,
            day => $day_term
        );

        my $drone_run_projectprops = [
            {type_id => $drone_run_type_cvterm_id, value => $imaging_event_type},
            {type_id => $project_start_date_type_id, value => $drone_run_event},
            {type_id => $design_cvterm_id, value => 'drone_run'},
            {type_id => $drone_run_camera_type_cvterm_id, value => $new_drone_run_camera_info},
            {type_id => $drone_run_related_cvterms_cvterm_id, value => encode_json \%related_cvterms}
        ];
        if ($base_date) {
            push @$drone_run_projectprops, {type_id => $drone_run_base_date_type_id, value => $base_date_event};
        }
        if ($rig_desc) {
            push @$drone_run_projectprops, {type_id => $drone_run_rig_desc_type_id, value => $rig_desc};
        }

        my $nd_experiment_rs = $schema->resultset("NaturalDiversity::NdExperiment")->create({
            nd_geolocation_id => $trial_location_id,
            type_id => $drone_run_experiment_type_id,
            nd_experiment_stocks => [{stock_id => $new_drone_run_vehicle_id, type_id => $drone_run_experiment_type_id}]
        });
        my $drone_run_nd_experiment_id = $nd_experiment_rs->nd_experiment_id();

        my $project_rs = $schema->resultset("Project::Project")->create({
            name => $imaging_event_name,
            description => $imaging_event_desc,
            projectprops => $drone_run_projectprops,
            project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_trial_id}],
            nd_experiment_projects => [{nd_experiment_id => $drone_run_nd_experiment_id}]
        });
        my $selected_drone_run_id = $project_rs->project_id();
        push @drone_run_project_ids, $selected_drone_run_id;

        my $vehicle_prop = decode_json $schema->resultset("Stock::Stockprop")->search({stock_id => $new_drone_run_vehicle_id, type_id=>$imaging_vehicle_properties_cvterm_id})->first()->value();
        $vehicle_prop->{batteries}->{$vehicle_battery}->{usage}++;
        my $vehicle_prop_update = $schema->resultset('Stock::Stockprop')->update_or_create({
            type_id=>$imaging_vehicle_properties_cvterm_id,
            stock_id=>$new_drone_run_vehicle_id,
            rank=>0,
            value=>encode_json $vehicle_prop
        },
        {
            key=>'stockprop_c1'
        });

        my @orthoimage_names = split ',', $image_filenames;
        my @ortho_images;
        foreach (@orthoimage_names) {
            push @ortho_images, $filename_imaging_event_lookup{$_};
        }
        my @drone_run_band_projects;
        my @drone_run_band_project_ids;
        my @drone_run_band_geoparams_coordinates;
        foreach my $m (@ortho_images) {
            my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();
            my $band = $m->{band};
            my $band_short = $m->{band_short};
            my $file = $m->{file};

            my $time = DateTime->now();
            my $timestamp = $time->ymd()."_".$time->hms();
            my $upload_original_name = $imaging_event_name."_".$band_short.".png";

            my $ortho_file;
            my @geoparams_coordinates;
            if ($coordinate_system eq 'Pixels') {
                $ortho_file = $file;
            }
            else {
                if ($band_short eq 'rgb') {
                    my $outfile_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_r = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_g = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_image_b = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_geoparams = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/fileXXXX').".csv";

                    my $geo_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GDALOpenImageRGBGeoTiff.py --image_path $file --outfile_path_image $outfile_image --outfile_path_image_1 $outfile_image_r --outfile_path_image_2 $outfile_image_g --outfile_path_image_3 $outfile_image_b --outfile_path_geo_params $outfile_geoparams ";
                    print STDERR $geo_cmd."\n";
                    my $geo_cmd_status = system($geo_cmd);
                    $ortho_file = $outfile_image;

                    open(my $fh_geoparams, '<', $outfile_geoparams) or die "Could not open file '".$outfile_geoparams."' $!";
                        print STDERR "Opened ".$outfile_geoparams."\n";
                        my $geoparams = <$fh_geoparams>;
                        chomp $geoparams;
                        @geoparams_coordinates = split ',', $geoparams;
                        print STDERR Dumper [$geoparams, \@geoparams_coordinates];
                    close($fh_geoparams);
                }
                else {
                    my $outfile_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/imageXXXX').".png";
                    my $outfile_geoparams = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'upload_drone_imagery_bulk_previous/fileXXXX').".csv";

                    my $geo_cmd = $c->config->{python_executable}." ".$c->config->{rootpath}."/DroneImageScripts/ImageProcess/GDALOpenSingleChannelImageGeoTiff.py --image_path $file --outfile_path_image $outfile_image --outfile_path_geo_params $outfile_geoparams ";
                    print STDERR $geo_cmd."\n";
                    my $geo_cmd_status = system($geo_cmd);
                    $ortho_file = $outfile_image;

                    open(my $fh_geoparams, '<', $outfile_geoparams) or die "Could not open file '".$outfile_geoparams."' $!";
                        print STDERR "Opened ".$outfile_geoparams."\n";
                        my $geoparams = <$fh_geoparams>;
                        chomp $geoparams;
                        @geoparams_coordinates = split ',', $geoparams;
                        print STDERR Dumper [$geoparams, \@geoparams_coordinates];
                    close($fh_geoparams);
                }
            }
            push @drone_run_band_geoparams_coordinates, \@geoparams_coordinates;

            my $project_rs = $schema->resultset("Project::Project")->create({
                name => $imaging_event_name."_".$band_short,
                description => $imaging_event_desc.". ".$band,
                projectprops => [
                    {type_id => $drone_run_band_type_cvterm_id, value => $band},
                    {type_id => $design_cvterm_id, value => 'drone_run_band'},
                    {type_id => $geoparam_coordinates_cvterm_id, value => encode_json \@geoparams_coordinates}
                ],
                project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $selected_drone_run_id}]
            });
            my $selected_drone_run_band_id = $project_rs->project_id();

            my $uploader = CXGN::UploadFile->new({
                tempfile => $ortho_file,
                subdirectory => "drone_imagery_upload",
                archive_path => $c->config->{archive_path},
                archive_filename => $upload_original_name,
                timestamp => $timestamp,
                user_id => $user_id,
                user_role => $user_role
            });
            my $archived_filename_with_path = $uploader->archive();
            my $md5 = $uploader->get_md5($archived_filename_with_path);
            if (!$archived_filename_with_path) {
                $c->stash->{rest} = { error => "Could not save file $upload_original_name in archive." };
                $c->detach();
            }
            unlink $upload_tempfile;
            print STDERR "Archived Bulk Orthophoto File: $archived_filename_with_path\n";

            my $image = SGN::Image->new( $schema->storage->dbh, undef, $c );
            $image->set_sp_person_id($user_id);
            my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
            my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);

            push @drone_run_band_projects, {
                drone_run_band_project_id => $selected_drone_run_band_id,
                band => $band
            };
            push @drone_run_band_project_ids, $selected_drone_run_band_id;
        }

        my $geojson_temp_filename = $filename_imaging_event_geojson_lookup{$geojson_filename};
        push @drone_run_projects, {
            drone_run_project_id => $selected_drone_run_id,
            drone_run_band_projects => \@drone_run_band_projects,
            drone_run_band_project_ids => \@drone_run_band_project_ids,
            geojson_temp_filename => $geojson_temp_filename,
            time_cvterm_id => $day_cvterm_id,
            field_trial_id => $selected_trial_id,
            coordinate_system => $coordinate_system,
            drone_run_band_geoparams_coordinates => \@drone_run_band_geoparams_coordinates,
            rotation_angle => $rotation_angle
        };

        $drone_run_project_info{$selected_drone_run_id} = {
            name => $project_rs->name()
        };
    }

    my $vegetative_indices = ['VARI', 'TGI', 'NDRE', 'NDVI'];
    my $phenotype_methods = ['zonal'];
    my $standard_process_type = 'minimal';

    foreach (@drone_run_projects) {
        my $drone_run_project_id_in = $_->{drone_run_project_id};
        my $time_cvterm_id = $_->{time_cvterm_id};
        my $apply_drone_run_band_project_ids = $_->{drone_run_band_project_ids};
        my $geojson_filename = $_->{geojson_temp_filename};
        my $field_trial_id = $_->{field_trial_id};
        my $coordinate_system = $_->{coordinate_system};
        my $drone_run_band_geoparams_coordinates = $_->{drone_run_band_geoparams_coordinates};
        my $rotate_value = 0;

        my $drone_run_process_in_progress = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my $drone_run_process_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        my $drone_run_process_minimal_vi_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_minimal_vi_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        my %vegetative_indices_hash;
        foreach (@$vegetative_indices) {
            $vegetative_indices_hash{$_}++;
        }

        my $geojson_value;

        open(my $fh_geojson, '<', $geojson_filename) or die "Could not open file '$geojson_filename' $!";
            print STDERR "Opened $geojson_filename\n";
            $geojson_value = decode_json <$fh_geojson>;
        close($fh_geojson);

        my $trial_lookup = $field_trial_layout_lookup{$field_trial_id};

        my %selected_drone_run_band_types;
        my $q2 = "SELECT project_md_image.image_id, drone_run_band_type.value, drone_run_band.project_id
            FROM project AS drone_run_band
            JOIN projectprop AS drone_run_band_type ON(drone_run_band_type.project_id = drone_run_band.project_id AND drone_run_band_type.type_id = $drone_run_band_type_type_id)
            JOIN phenome.project_md_image AS project_md_image ON(project_md_image.project_id = drone_run_band.project_id)
            JOIN metadata.md_image ON(project_md_image.image_id = metadata.md_image.image_id)
            WHERE project_md_image.type_id = $project_image_type_id
            AND drone_run_band.project_id = ?
            AND metadata.md_image.obsolete = 'f';";

        my $h2 = $schema->storage->dbh()->prepare($q2);

        my $term_map = CXGN::DroneImagery::ImageTypes::get_base_imagery_observation_unit_plot_polygon_term_map();

        my %drone_run_band_info;
        my $drone_run_band_counter = 0;
        foreach my $apply_drone_run_band_project_id (@$apply_drone_run_band_project_ids) {

            my $plot_polygons_value;
            foreach (@{$geojson_value->{features}}) {
                my $plot_number = $_->{properties}->{ID};
                my $coordinates = $_->{geometry}->{coordinates};
                my $stock_name = $trial_lookup->{$plot_number}->{plot_name};
                my @coords;
                foreach my $crd (@{$coordinates->[0]}) {
                    if ($coordinate_system eq 'Pixels') {
                        push @coords, {
                            x => $crd->[0],
                            y => $crd->[1],
                        };
                    }
                    else {
                        my $geocoords = $drone_run_band_geoparams_coordinates->[$drone_run_band_counter];
                        my $xOrigin = $geocoords->[0];
                        my $yOrigin = $geocoords->[3];
                        my $pixelWidth = $geocoords->[1];
                        my $pixelHeight = -1*$geocoords->[5];
                        my $x_pos = round(($crd->[0] - $xOrigin) / $pixelWidth);
                        my $y_pos = round(($yOrigin - $crd->[1] ) / $pixelHeight);
                        push @coords, {
                            x => $x_pos,
                            y => $y_pos,
                        };
                    }
                }
                my $last_point = pop @coords;
                $plot_polygons_value->{$stock_name} = \@coords;
            }
            $plot_polygons_value = encode_json $plot_polygons_value;

            my $h2 = $schema->storage->dbh()->prepare($q2);
            $h2->execute($apply_drone_run_band_project_id);
            my ($image_id, $drone_run_band_type, $drone_run_band_project_id) = $h2->fetchrow_array();
            $selected_drone_run_band_types{$drone_run_band_type} = $drone_run_band_project_id;

            my $image = SGN::Image->new( $schema->storage->dbh, $image_id, $c );
            my $image_fullpath = $image->get_filename('original_converted', 'full');

            my @size = imgsize($image_fullpath);
            my $width = $size[0];
            my $length = $size[1];

            my $cropping_value = encode_json [[{x=>0, y=>0}, {x=>$width, y=>0}, {x=>$width, y=>$length}, {x=>0, y=>$length}]];

            my $apply_image_width_ratio = 1;
            my $apply_image_height_ratio = 1;

            my $dir = $c->tempfiles_subdir('/drone_imagery_rotate');
            my $archive_rotate_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_rotate/imageXXXX');
            $archive_rotate_temp_image .= '.png';

            my $rotate_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_rotate($c, $schema, $metadata_schema, $drone_run_band_project_id, $image_id, $rotate_value, 0, $user_id, $user_name, $user_role, $archive_rotate_temp_image, 0, 0);
            my $rotated_image_id = $rotate_return->{rotated_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_cropped_image');
            my $archive_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_cropped_image/imageXXXX');
            $archive_temp_image .= '.png';

            my $cropping_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_cropping($c, $schema, $drone_run_band_project_id, $rotated_image_id, $cropping_value, $user_id, $user_name, $user_role, $archive_temp_image, $apply_image_width_ratio, $apply_image_height_ratio);
            my $cropped_image_id = $cropping_return->{cropped_image_id};

            $dir = $c->tempfiles_subdir('/drone_imagery_denoise');
            my $archive_denoise_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_denoise/imageXXXX');
            $archive_denoise_temp_image .= '.png';

            my $denoise_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_denoise($c, $schema, $metadata_schema, $cropped_image_id, $drone_run_band_project_id, $user_id, $user_name, $user_role, $archive_denoise_temp_image);
            my $denoised_image_id = $denoise_return->{denoised_image_id};

            $drone_run_band_info{$drone_run_band_project_id} = {
                denoised_image_id => $denoised_image_id,
                rotate_value => $rotate_value,
                cropping_value => $cropping_value,
                drone_run_band_type => $drone_run_band_type,
                drone_run_project_id => $drone_run_project_id_in,
                drone_run_project_name => $drone_run_project_info{$drone_run_project_id_in}->{name},
                plot_polygons_value => $plot_polygons_value
            };

            my @denoised_plot_polygon_type = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{base}};
            my @denoised_background_threshold_removed_imagery_types = @{$term_map->{$drone_run_band_type}->{imagery_types}->{threshold_background}};
            my @denoised_background_threshold_removed_plot_polygon_types = @{$term_map->{$drone_run_band_type}->{observation_unit_plot_polygon_types}->{threshold_background}};

            foreach (@denoised_plot_polygon_type) {
                my $plot_polygon_original_denoised_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_plot_polygon_assign($c, $schema, $metadata_schema, $denoised_image_id, $drone_run_band_project_id, $plot_polygons_value, $_, $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_polygon');
            }

            for my $iterator (0..(scalar(@denoised_background_threshold_removed_imagery_types)-1)) {
                $dir = $c->tempfiles_subdir('/drone_imagery_remove_background');
                my $archive_remove_background_temp_image = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'drone_imagery_remove_background/imageXXXX');
                $archive_remove_background_temp_image .= '.png';

                my $background_removed_threshold_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_image_background_remove_threshold_percentage($c, $schema, $denoised_image_id, $drone_run_band_project_id, $denoised_background_threshold_removed_imagery_types[$iterator], '25', '25', $user_id, $user_name, $user_role, $archive_remove_background_temp_image);

                my $plot_polygon_return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_plot_polygon_assign($c, $schema, $metadata_schema, $background_removed_threshold_return->{removed_background_image_id}, $drone_run_band_project_id, $plot_polygons_value, $denoised_background_threshold_removed_plot_polygon_types[$iterator], $user_id, $user_name, $user_role, 0, 0, $apply_image_width_ratio, $apply_image_height_ratio, 'rectangular_polygon');
            }

            $drone_run_band_counter++;
        }

        print STDERR Dumper \%selected_drone_run_band_types;
        print STDERR Dumper \%vegetative_indices_hash;

        SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_minimal_vi_standard_process($c, $schema, $metadata_schema, \%vegetative_indices_hash, \%selected_drone_run_band_types, \%drone_run_band_info, $user_id, $user_name, $user_role, 'rectangular_polygon');

        $drone_run_process_in_progress = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$process_indicator_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>0
        },
        {
            key=>'projectprop_c1'
        });

        $drone_run_process_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        $drone_run_process_minimal_vi_completed = $schema->resultset('Project::Projectprop')->update_or_create({
            type_id=>$processed_minimal_vi_cvterm_id,
            project_id=>$drone_run_project_id_in,
            rank=>0,
            value=>1
        },
        {
            key=>'projectprop_c1'
        });

        my $return = SGN::Controller::AJAX::DroneImagery::DroneImagery::_perform_phenotype_automated($c, $schema, $metadata_schema, $phenome_schema, $drone_run_project_id_in, $time_cvterm_id, $phenotype_methods, $standard_process_type, 1, undef, $user_id, $user_name, $user_role);
    }

    $c->stash->{message} = "Successfully uploaded!";
    $c->stash->{template} = 'generic_message.mas';
    return;
}

sub _check_user_login {
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{message} = 'You must be logged in to do this!';
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{message} = 'You must be logged in to do this!';
            $c->stash->{template} = 'generic_message.mas';
            return;
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }
    return ($user_id, $user_name, $user_role);
}

1;
