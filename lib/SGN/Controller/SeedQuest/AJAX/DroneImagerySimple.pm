package SGN::Controller::SeedQuest::AJAX::DroneImagerySimple;

use Moose;
use Data::Dumper;
use JSON;
use Try::Tiny;
use File::Temp qw(tempdir tempfile);
use File::Basename;
use CXGN::UploadFile;
use DateTime;
use SGN::Model::Cvterm;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON' },
);

=head1 NAME

SGN::Controller::SeedQuest::AJAX::DroneImagerySimple - Simplified drone imagery upload endpoint

=head1 DESCRIPTION

Provides a simplified upload endpoint that:
- Auto-detects sensor type from EXIF
- Auto-extracts date from EXIF
- Auto-generates imaging event name
- Calls the main DroneImagery controller with detected parameters

=cut

# ============================================================================
# SIMPLE UPLOAD ENDPOINT
# ============================================================================

sub simple_upload : Path('/ajax/seedquest/drone_imagery/simple_upload') : ActionClass('REST') { }

sub simple_upload_POST : Args(0) {
    my $self = shift;
    my $c = shift;

    # Check login
    unless ($c->user) {
        $c->stash->{rest} = { error => 'You must be logged in to upload images' };
        return;
    }

    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $schema = $c->dbic_schema("Bio::Chado::Schema", undef, $user_id);

    # Get parameters
    my $trial_id = $c->req->param('trial_id');
    my $use_odm = $c->req->param('use_odm') || 0;
    my $auto_detect = $c->req->param('auto_detect') || 1;
    my $upload = $c->req->upload('upload_zip');

    unless ($trial_id) {
        $c->stash->{rest} = { error => 'Please select a field trial' };
        return;
    }

    unless ($upload) {
        $c->stash->{rest} = { error => 'Please provide a ZIP file with images' };
        return;
    }

    # Get trial info
    my $trial = $schema->resultset('Project::Project')->find({ project_id => $trial_id });
    unless ($trial) {
        $c->stash->{rest} = { error => 'Trial not found' };
        return;
    }
    my $trial_name = $trial->name();

    # Archive the uploaded file
    my $upload_tempfile = $upload->tempname;
    my $upload_original_name = $upload->filename;
    my $time = DateTime->now();
    my $timestamp = $time->ymd() . "_" . $time->hms();

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => "drone_imagery_simple_upload",
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $c->user->get_object->get_user_type()
    });

    my $archived_filename = $uploader->archive();
    unless ($archived_filename) {
        $c->stash->{rest} = { error => "Could not save uploaded file" };
        return;
    }

    # Extract EXIF from first image in ZIP
    my $exif_info = _extract_exif_from_zip($archived_filename);

    my $detected_sensor = $exif_info->{sensor} || 'cmos_color';
    my $detected_date = $exif_info->{date} || $time->ymd("/") . " " . $time->hms(":");
    my $drone_run_name = "${trial_name}_${timestamp}";

    # Get ODM options for detected sensor
    my $odm_options = _get_odm_options($detected_sensor);

    # Log detection
    print STDERR "DroneImagerySimple: Detected sensor=$detected_sensor, date=$detected_date\n";
    print STDERR "DroneImagerySimple: ODM options=$odm_options, trial=$trial_name, drone_run=$drone_run_name\n";

    # Determine if we need ODM stitching
    my $stitching_mode = $use_odm ? 'yes_open_data_map_stitch' : 'no';
    my $radiocalibration = ($detected_sensor eq 'dji_mavic3m' || $detected_sensor eq 'micasense_5') ? 'Yes' : 'No';

    # Create or get a default imaging vehicle ID (required by main controller)
    my $vehicle_id = _get_or_create_default_vehicle($c, $schema, $user_id);

    # Build result for frontend - the frontend will POST to the main endpoint
    # OR we can do it server-side. For now, return params for frontend to handle.
    $c->stash->{rest} = {
        success => 1,
        message => "Upload prepared. " . ($use_odm ? "ODM processing will begin." : "Orthomosaic mode."),
        detected => {
            sensor => $detected_sensor,
            sensor_display => _sensor_display_name($detected_sensor),
            date => $detected_date,
            drone_run_name => $drone_run_name,
            odm_options => $odm_options,
            make => $exif_info->{make},
            model => $exif_info->{model},
        },
        upload_params => {
            drone_run_field_trial_id => $trial_id,
            drone_run_name => $drone_run_name,
            drone_run_type => 'Aerial Photography',
            drone_run_date => $detected_date,
            drone_run_description => "Auto-uploaded via Simple Upload ($detected_sensor)",
            drone_image_upload_camera_info => $detected_sensor,
            drone_image_upload_drone_run_band_stitching => $stitching_mode,
            drone_image_upload_drone_run_band_stitching_odm_radiocalibration => $radiocalibration,
            drone_run_imaging_vehicle_id => $vehicle_id,
        },
        archived_file => $archived_filename
    };
}

=head2 _get_or_create_default_vehicle

Creates or retrieves a default imaging vehicle for simple uploads.

=cut

sub _get_or_create_default_vehicle {
    my ($c, $schema, $user_id) = @_;

    # Look for existing "Simple Upload Vehicle"
    my $vehicle_name = 'Simple Upload Default Vehicle';
    my $vehicle_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'imaging_event_vehicle', 'stock_type')->cvterm_id();

    my $vehicle = $schema->resultset('Stock::Stock')->find_or_create({
        name => $vehicle_name,
        uniquename => $vehicle_name,
        type_id => $vehicle_type_id
    });

    return $vehicle->stock_id();
}

=head2 _sensor_display_name

Returns a human-readable name for the sensor type.

=cut

sub _sensor_display_name {
    my $sensor = shift;
    my %names = (
        'dji_mavic3m' => 'DJI Mavic 3 Multispectral',
        'micasense_5' => 'MicaSense RedEdge 5-band',
        'cmos_color' => 'RGB Camera',
        'ccd_color' => 'RGB Camera (CCD)',
    );
    return $names{$sensor} || $sensor;
}

=head2 _extract_exif_from_zip

Extracts EXIF metadata from the first image in a ZIP file.

=cut

sub _extract_exif_from_zip {
    my $zip_path = shift;

    my $default = {
        date => undef,
        sensor => 'cmos_color',
        make => '',
        model => ''
    };

    eval {
        require Archive::Zip;
        require Image::ExifTool;

        my $zip = Archive::Zip->new();
        return $default unless $zip->read($zip_path) == Archive::Zip::AZ_OK();

        # Find first image
        my @members = $zip->members();
        my $first_image;
        for my $member (@members) {
            my $name = $member->fileName();
            if ($name =~ /\.(jpg|jpeg|tif|tiff|png)$/i && $name !~ /^__MACOSX/) {
                $first_image = $member;
                last;
            }
        }

        return $default unless $first_image;

        # Extract to temp
        my $tempdir = File::Temp::tempdir(CLEANUP => 1);
        my $temp_file = "$tempdir/" . basename($first_image->fileName());
        $zip->extractMember($first_image, $temp_file);

        # Read EXIF
        my $exiftool = Image::ExifTool->new();
        $exiftool->ExtractInfo($temp_file);

        my $make = $exiftool->GetValue('Make') || '';
        my $model = $exiftool->GetValue('Model') || '';
        my $date = $exiftool->GetValue('DateTimeOriginal') || $exiftool->GetValue('CreateDate') || '';

        # Format date
        if ($date =~ /^(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/) {
            $date = "$1/$2/$3 $4:$5:$6";
        }

        # Detect sensor
        my $sensor = _detect_sensor($make, $model);

        return {
            date => $date,
            sensor => $sensor,
            make => $make,
            model => $model
        };
    };

    if ($@) {
        print STDERR "EXIF extraction error: $@\n";
    }

    return $default;
}

=head2 _detect_sensor

Detects sensor type from EXIF Make/Model.

=cut

sub _detect_sensor {
    my ($make, $model) = @_;

    $make = lc($make || '');
    $model = lc($model || '');

    # DJI Mavic 3 Multispectral
    if ($make =~ /dji/ && ($model =~ /m3m|mavic\s*3.*multi/i)) {
        return 'dji_mavic3m';
    }

    # MicaSense
    if ($make =~ /micasense/i) {
        return 'micasense_5';
    }

    return 'cmos_color';
}

=head2 _get_odm_options

Returns ODM command line options for the specified sensor.

=cut

sub _get_odm_options {
    my $sensor = shift;

    my %options = (
        'dji_mavic3m' => '--radiometric-calibration camera+sun --dsm --orthophoto-resolution 1.0 --ignore-gsd --pc-quality medium',
        'micasense_5' => '--radiometric-calibration camera+sun --dsm --min-num-features 10000',
        'cmos_color'  => '--dsm --pc-quality medium',
        'ccd_color'   => '--dsm --pc-quality medium',
    );

    return $options{$sensor} || '--dsm --pc-quality low';
}

1;
