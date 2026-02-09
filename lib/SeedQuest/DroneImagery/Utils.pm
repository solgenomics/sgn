package SeedQuest::DroneImagery::Utils;

use strict;
use warnings;
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use Image::ExifTool;
use File::Temp qw(tempdir);
use File::Basename;
use JSON;
use Exporter 'import';

our @EXPORT_OK = qw(
    get_odm_options_for_sensor
    extract_exif_from_zip
    detect_sensor_from_exif
);

=head1 NAME

SeedQuest::DroneImagery::Utils - Utilities for DJI M3M and other drone imagery

=head1 SYNOPSIS

    use SeedQuest::DroneImagery::Utils qw(get_odm_options_for_sensor extract_exif_from_zip);
    
    my $options = get_odm_options_for_sensor('dji_mavic3m');
    my $exif = extract_exif_from_zip('/path/to/images.zip');

=cut

# ODM configuration per sensor type
my %SENSOR_ODM_OPTIONS = (
    'dji_mavic3m' => {
        radiometric   => 'camera+sun',
        flags         => '--dsm --orthophoto-resolution 1.0 --ignore-gsd --pc-quality medium',
        bands         => [
            { name => 'Green',   wavelength => 560 },
            { name => 'Red',     wavelength => 650 },
            { name => 'RedEdge', wavelength => 730 },
            { name => 'NIR',     wavelength => 860 },
        ],
    },
    'micasense_5' => {
        radiometric   => 'camera+sun',
        flags         => '--dsm --min-num-features 10000',
        bands         => [
            { name => 'Blue',    wavelength => 475 },
            { name => 'Green',   wavelength => 560 },
            { name => 'Red',     wavelength => 668 },
            { name => 'RedEdge', wavelength => 717 },
            { name => 'NIR',     wavelength => 840 },
        ],
    },
    'ccd_color' => {
        radiometric   => '',
        flags         => '--dsm',
        bands         => [{ name => 'RGB', wavelength => 0 }],
    },
    'cmos_color' => {
        radiometric   => '',
        flags         => '--dsm',
        bands         => [{ name => 'RGB', wavelength => 0 }],
    },
);

=head2 get_odm_options_for_sensor

Returns ODM command line options for the specified sensor type.

    my $opts = get_odm_options_for_sensor('dji_mavic3m');
    # Returns: "--radiometric-calibration camera+sun --dsm --orthophoto-resolution 1.0 ..."

=cut

sub get_odm_options_for_sensor {
    my $sensor = shift || 'default';
    
    my $config = $SENSOR_ODM_OPTIONS{$sensor};
    return '--pc-quality low' unless $config;
    
    my $options = '';
    if ($config->{radiometric}) {
        $options .= "--radiometric-calibration $config->{radiometric} ";
    }
    $options .= $config->{flags} if $config->{flags};
    
    return $options;
}

=head2 extract_exif_from_zip

Extracts EXIF metadata from the first image in a ZIP file.
Returns hashref with date, sensor, make, model.

    my $exif = extract_exif_from_zip('/path/to/images.zip');
    # Returns: { date => '2024/02/04 10:30:00', sensor => 'dji_mavic3m', make => 'DJI', model => 'M3M' }

=cut

sub extract_exif_from_zip {
    my $zip_path = shift;
    
    my $zip = Archive::Zip->new();
    return { error => "Cannot read ZIP: $zip_path" } unless $zip->read($zip_path) == AZ_OK;
    
    # Find first image in ZIP
    my @members = $zip->members();
    my $first_image;
    for my $member (@members) {
        my $name = $member->fileName();
        if ($name =~ /\.(jpg|jpeg|tif|tiff|png)$/i && $name !~ /^__MACOSX/) {
            $first_image = $member;
            last;
        }
    }
    
    return { error => "No images found in ZIP" } unless $first_image;
    
    # Extract to temp and read EXIF
    my $tempdir = tempdir(CLEANUP => 1);
    my $temp_file = "$tempdir/" . basename($first_image->fileName());
    $zip->extractMember($first_image, $temp_file);
    
    my $exiftool = Image::ExifTool->new();
    $exiftool->ExtractInfo($temp_file);
    
    my $make = $exiftool->GetValue('Make') || '';
    my $model = $exiftool->GetValue('Model') || '';
    my $date = $exiftool->GetValue('DateTimeOriginal') || $exiftool->GetValue('CreateDate') || '';
    
    # Format date to BreedBase format (YYYY/MM/DD HH:mm:ss)
    if ($date =~ /^(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/) {
        $date = "$1/$2/$3 $4:$5:$6";
    } elsif (!$date) {
        # Fallback to current date
        my @t = localtime();
        $date = sprintf("%04d/%02d/%02d %02d:%02d:%02d", 
            $t[5]+1900, $t[4]+1, $t[3], $t[2], $t[1], $t[0]);
    }
    
    # Detect sensor type
    my $sensor = detect_sensor_from_exif($make, $model);
    
    return {
        date   => $date,
        sensor => $sensor,
        make   => $make,
        model  => $model,
        file   => basename($first_image->fileName()),
    };
}

=head2 detect_sensor_from_exif

Detects sensor type from EXIF Make/Model.

    my $sensor = detect_sensor_from_exif('DJI', 'M3M');
    # Returns: 'dji_mavic3m'

=cut

sub detect_sensor_from_exif {
    my ($make, $model) = @_;
    
    $make  = lc($make || '');
    $model = lc($model || '');
    
    # DJI Mavic 3 Multispectral
    if ($make =~ /dji/ && ($model =~ /m3m|mavic\s*3.*multi/i)) {
        return 'dji_mavic3m';
    }
    
    # MicaSense
    if ($make =~ /micasense/i) {
        return 'micasense_5';
    }
    
    # Generic color cameras
    if ($make && $model) {
        return 'cmos_color';
    }
    
    return 'unknown';
}

=head2 get_bands_for_sensor

Returns band definitions for the specified sensor.

=cut

sub get_bands_for_sensor {
    my $sensor = shift;
    
    my $config = $SENSOR_ODM_OPTIONS{$sensor};
    return [] unless $config;
    
    return $config->{bands};
}

1;
