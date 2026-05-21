#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::Image;
use SGN::Image;
use CXGN::UploadFile;
use DateTime;
use File::Basename;
use SGN::Model::Cvterm;
use JSON;

my $project_id;
my $archive_path;
my $image_path_remaining;
my $image_path_remaining_host;
my $camera_info;
my $radiocalibration;
my $user_id;
my $user_role;
my $dbhost;
my $dbname;
my $dbuser;
my $dbpass;
my $rootpath;
my $python_executable;
my $temp_file_docker_log;

GetOptions(
    "project_id=i" => \$project_id,
    "archive_path=s" => \$archive_path,
    "image_path_remaining=s" => \$image_path_remaining,
    "image_path_remaining_host=s" => \$image_path_remaining_host,
    "camera_info=s" => \$camera_info,
    "radiocalibration=s" => \$radiocalibration,
    "user_id=i" => \$user_id,
    "user_role=s" => \$user_role,
    "dbhost=s" => \$dbhost,
    "dbname=s" => \$dbname,
    "dbuser=s" => \$dbuser,
    "dbpass=s" => \$dbpass,
    "rootpath=s" => \$rootpath,
    "python_executable=s" => \$python_executable,
    "temp_file_docker_log=s" => \$temp_file_docker_log,
);

print STDERR "Starting ODM Async Worker for Project $project_id\n";

# Database Connection
my $dbh = CXGN::DB::Connection->new({ 
    dbhost => $dbhost, 
    dbname => $dbname, 
    dbuser => $dbuser, 
    dbpass => $dbpass 
});
my $schema = Bio::Chado::Schema->connect( sub { $dbh->get_actual_dbh() } );

# 1. Run Docker ODM (Blocking)
my $odm_radiometric = '';
if ($radiocalibration && $radiocalibration eq 'yes') {
    $odm_radiometric = '--radiometric-calibration camera+sun';
}

# MEMORY FIX v2: Use parallelism limits instead of quality degradation
# --feature-quality lowest caused insufficient feature matching
# Instead: limit Docker RAM and reduce parallel threads
my $memory_flags = "--max-concurrency 2 --mesh-size 200000 --orthophoto-resolution 5.0 --ignore-gsd";
# Docker will be started with --memory 10g to prevent OOM

my $odm_command = '';
my @stitched_bands = ();

if ($camera_info eq 'dji_mavic3m' || $camera_info eq 'multispectral_4band') {
    # DJI Logic
    sleep(5); # Race condition fix
    
    # Added --memory 10g to Docker run command
    $odm_command = 'docker run --rm --memory 10g -v /var/run/docker.sock:/var/run/docker.sock -v '.$image_path_remaining_host.':/datasets/code opendronemap/odm --project-path /datasets --rerun-all --dsm --dtm '.$memory_flags.' '.$odm_radiometric.' > '.$temp_file_docker_log.' 2>&1';
    
    print STDERR "Executing: $odm_command\n";
    system($odm_command);
    
    # Check if successful? System returns exit code.
    if ($? == -1) {
        print STDERR "failed to execute: $!\n";
    }
    elsif ($? & 127) {
        print STDERR "child died with signal %d, %s coredump\n", ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    else {
        print STDERR "child exited with value %d\n", $? >> 8;
    }

    # Post-processing extraction using GDAL CLI (inside ODM container)
    # This replaces Python rasterio/osgeo which are not available in breedbase container
    my $odm_b1 = "$image_path_remaining/odm_orthophoto/green.png";
    my $odm_b2 = "$image_path_remaining/odm_orthophoto/red.png";
    my $odm_b3 = "$image_path_remaining/odm_orthophoto/rededge.png";
    my $odm_b4 = "$image_path_remaining/odm_orthophoto/nir.png";
    
    my $ortho_tif = "$image_path_remaining_host/odm_orthophoto/odm_orthophoto.tif";
    my $out_dir = "$image_path_remaining_host/odm_orthophoto";
    
    # Use ODM container's GDAL to extract bands (runs docker with same mount)
    print STDERR "Extracting bands using GDAL...\n";
    
    # Band extraction commands using gdal_translate
    my @band_cmds = (
        "docker run --rm --entrypoint gdal_translate -v $image_path_remaining_host:/data opendronemap/odm -b 1 -of PNG /data/odm_orthophoto/odm_orthophoto.tif /data/odm_orthophoto/green.png",
        "docker run --rm --entrypoint gdal_translate -v $image_path_remaining_host:/data opendronemap/odm -b 2 -of PNG /data/odm_orthophoto/odm_orthophoto.tif /data/odm_orthophoto/red.png",
        "docker run --rm --entrypoint gdal_translate -v $image_path_remaining_host:/data opendronemap/odm -b 3 -of PNG /data/odm_orthophoto/odm_orthophoto.tif /data/odm_orthophoto/rededge.png",
        "docker run --rm --entrypoint gdal_translate -v $image_path_remaining_host:/data opendronemap/odm -b 4 -of PNG /data/odm_orthophoto/odm_orthophoto.tif /data/odm_orthophoto/nir.png",
    );
    
    foreach my $cmd (@band_cmds) {
        print STDERR "Running: $cmd\n";
        system($cmd);
    }
    
    # DSM/DTM extraction
    my $odm_dsm_png = "$image_path_remaining/odm_dem/dsm.png";
    my $odm_dtm_png = "$image_path_remaining/odm_dem/dtm.png";
    
    my @dem_cmds = (
        "docker run --rm --entrypoint gdal_translate -v $image_path_remaining_host:/data opendronemap/odm -of PNG -scale /data/odm_dem/dsm.tif /data/odm_dem/dsm.png",
        "docker run --rm --entrypoint gdal_translate -v $image_path_remaining_host:/data opendronemap/odm -of PNG -scale /data/odm_dem/dtm.tif /data/odm_dem/dtm.png",
    );
    
    foreach my $cmd (@dem_cmds) {
        print STDERR "Running: $cmd\n";
        system($cmd);
    }

    @stitched_bands = (
        ["Band 1", "OpenDroneMap Green", "Green (560nm)", $odm_b1],
        ["Band 2", "OpenDroneMap Red", "Red (650nm)", $odm_b2],
        ["Band 3", "OpenDroneMap RedEdge", "Red Edge (730nm)", $odm_b3],
        ["Band 4", "OpenDroneMap NIR", "NIR (860nm)", $odm_b4],
        ["DSM", "OpenDroneMap DSM", "Black and White Image", $odm_dsm_png]
    );

} else {
    print STDERR "Unsupported camera type for Async Worker prototype: $camera_info\n";
    exit(1);
}

# 2. Register Images in DB
my $drone_run_band_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_project_type', 'project_property')->cvterm_id();
my $design_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'design', 'project_property')->cvterm_id();
my $project_relationship_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_band_on_drone_run', 'project_relationship')->cvterm_id();

my $parent_project = $schema->resultset("Project::Project")->find({project_id => $project_id});
my $new_drone_run_name = $parent_project->name();
my $new_drone_run_desc = $parent_project->description();

foreach my $m (@stitched_bands) {
    # Check if files exist
    if (! -e $m->[3]) {
        print STDERR "Warning: Output file $m->[3] does not exist. Skipping DB registration for this band.\n";
        next;
    }

    my $project_rs = $schema->resultset("Project::Project")->create({
        name => $new_drone_run_name."_".$m->[1],
        description => $new_drone_run_desc.". ".$m->[0]." ".$m->[1].". Orthomosaic stitched by OpenDroneMap in ImageBreed (Async).",
        projectprops => [{type_id => $drone_run_band_type_cvterm_id, value => $m->[2]}, {type_id => $design_cvterm_id, value => 'drone_run_band'}],
        project_relationship_subject_projects => [{type_id => $project_relationship_type_id, object_project_id => $project_id}]
    });
    my $selected_drone_run_band_id = $project_rs->project_id();

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $upload_original_name = $new_drone_run_name."_ImageBreed_stitched_".$m->[1].".png";

    my $uploader = CXGN::UploadFile->new({
        tempfile => $m->[3],
        subdirectory => "drone_imagery_upload",
        archive_path => $archive_path,
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    
    if (!$archived_filename_with_path) {
        print STDERR "Could not save file $upload_original_name in archive.\n";
        next;
    }
    
    # Use CXGN::Image instead of SGN::Image (SGN::Image requires Catalyst context)
    # image_dir should be the archive path for images
    my $image_dir = $archive_path . "/image_files";
    
    my $image = CXGN::Image->new( 
        dbh => $dbh, 
        image_dir => $image_dir 
    ); 
    
    $image->set_sp_person_id($user_id);
    my $linking_table_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stitched_drone_imagery', 'project_md_image')->cvterm_id();
    
    my $ret = $image->process_image($archived_filename_with_path, 'project', $selected_drone_run_band_id, $linking_table_type_id);
    print STDERR "Image Processed: $ret\n";
    
    # CXGN::Image->process_image() doesn't create project_md_image link,
    # so we need to insert it manually (like SGN::Image->associate_project() does)
    if ($ret && $ret > 0) {
        my $link_sth = $dbh->prepare("INSERT INTO phenome.project_md_image (image_id, project_id, type_id) VALUES (?, ?, ?)");
        $link_sth->execute($ret, $selected_drone_run_band_id, $linking_table_type_id);
        print STDERR "Linked image $ret to project $selected_drone_run_band_id with type $linking_table_type_id\n";
    }
}

# 3. Clear Process Flag
my $odm_check_prop = $schema->resultset("Project::Projectprop")->find({project_id => $project_id, type_id => SGN::Model::Cvterm->get_cvterm_row($schema, 'drone_run_opendronemap_process_running', 'project_property')->cvterm_id()});
if ($odm_check_prop) {
    $odm_check_prop->value('0');
    $odm_check_prop->update();
    print STDERR "Cleared odm_process_running flag.\n";
}

print STDERR "Async Worker Completed Successfully.\n";

# Explicit commit and disconnect to prevent rollback on DESTROY
$schema->storage->dbh->commit();
$dbh->disconnect();

exit(0);
