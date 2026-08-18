#!/usr/bin/perl

=head1

store_images.pl

=head1 SYNOPSIS

store_images.pl -H [dbhost] -D [dbname] -U [dbuser] -P [dbpass] -w [basepath] -ap [archive_path] -id [image_dir] -i [file_ids] -un [username] -t [image_type] -j [sp_job_id]

=head1 COMMAND-LINE OPTIONS

ARGUMENTS
 -H host name (required) Ex: "breedbase_db"
 -D database name (required) Ex: "breedbase"
 -U database username (required) Ex: "postgres"
 -P database userpass (required) Ex: "postgres"
 -w basepath (required) Ex: /home/production/cxgn/sgn
 -ap archive path (required) Ex: /home/production/volume/archive
 -id image directory (required) Ex: /export/prod/public/images/image_files
 -i comma separated list of archived file ids (required) Ex: "112,113,114"
 -un username of the uploader (required)
 -t image type, either "images" or "images_barcodes" (required)
 -j sp_job_id of the job that submitted this script (required)

=head2 DESCRIPTION

perl bin/store_images.pl -H breedbase_db -D breedbase -U postgres -P postgres -w /home/cxgn/sgn -ap /archive -id /export/prod/public/images/image_files -i "112,113,114" -un janedoe -t images -j 42

Stores a batch of already archived image files in the database and associates each one with its
observation unit. The observation unit is taken from the image's EXIF metadata ("images") or from
the barcode printed in the image ("images_barcodes"). Images with EXIF metadata are also associated
with the trait recorded in that metadata.

Each image is stored independently, so one bad image does not stop the rest of the batch. Anything
that goes wrong with a single image is reported against that image's filename and the script moves
on to the next one. All messages are written back to the submitting job, so partial batches report
both what was stored and what failed.

After an image has been stored, its copy in the file archive is deleted, since the image itself now
lives in the image directory.

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use DBI;
use File::Basename;
use File::Copy;
use File::Spec;
use File::Temp qw | tempdir |;
use JSON;
use Try::Tiny;

use Bio::Chado::Schema;
use CXGN::DB::InsertDBH;
use CXGN::File;
use CXGN::Image;
use CXGN::Job;
use CXGN::Metadata::Metadbdata;
use CXGN::Metadata::Schema;
use CXGN::People::Person;
use CXGN::People::Schema;
use SGN::Model::Cvterm;

my ( $help, $dbhost, $dbname, $dbuser, $dbpass, $basepath, $archive_path, $image_dir, $file_id_list, $username, $image_type, $sp_job_id );
GetOptions(
    'dbhost|H=s'       => \$dbhost,
    'dbname|D=s'       => \$dbname,
    'dbuser|U=s'       => \$dbuser,
    'dbpass|P=s'       => \$dbpass,
    'basepath|w=s'     => \$basepath,
    'archive_path|ap=s'=> \$archive_path,
    'image_dir|id=s'   => \$image_dir,
    'i=s'              => \$file_id_list,
    'user|un=s'        => \$username,
    'image_type|t=s'   => \$image_type,
    'jobid|j=s'        => \$sp_job_id,
    'help'             => \$help,
);
pod2usage(1) if $help;
if (!$file_id_list || !$username || !$basepath || !$dbname || !$dbhost || !$archive_path || !$image_dir || !$image_type || !defined($sp_job_id)) {
    pod2usage({ -msg => 'Error. Missing options!', -verbose => 1, -exitval => 1 });
}
if ($image_type ne 'images' && $image_type ne 'images_barcodes') {
    pod2usage({ -msg => "Error. Unknown image type $image_type!", -verbose => 1, -exitval => 1 });
}

# Connect to databases. Everything shares one handle so that the raw association statements
# below run inside the same transaction as the DBIx::Class work.
my $dbh;
if ($dbpass && $dbuser) {
    $dbh = DBI->connect(
        "dbi:Pg:database=$dbname;host=$dbhost",
        $dbuser,
        $dbpass,
        {AutoCommit => 1, RaiseError => 1}
    );
}
else {
    $dbh = CXGN::DB::InsertDBH->new({
        dbhost => $dbhost,
        dbname => $dbname,
        dbargs => {AutoCommit => 1, RaiseError => 1}
    });
}

my $chado_schema = Bio::Chado::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, sgn, metadata, phenome;'] } );
my $metadata_schema = CXGN::Metadata::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, metadata;'] } );
my $people_schema = CXGN::People::Schema->connect( sub { $dbh }, { on_connect_do => ['SET search_path TO public, sgn, sgn_people;'] } );

my @success_messages;
my @warning_messages;
my @error_messages;

# Any uncaught failure below would otherwise leave the job looking successful, because the finish
# timestamp is recorded whether or not this script exits cleanly.
try {
    store_all_images();
} catch {
    push @error_messages, "The image upload failed: $_";
};

finish();

=head2 store_all_images()

Stores every image in the batch.

=cut

sub store_all_images {
    my $sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $username);
    if (!$sp_person_id) {
        die "User not found in the database for username $username.\n";
    }

    my @file_ids = split(",", $file_id_list);

    foreach my $file_id (@file_ids) {
        store_one_image($file_id, $sp_person_id);
    }
}

=head2 store_one_image($file_id, $sp_person_id)

Stores a single archived image. Errors are recorded against this image only, so that the rest of
the batch can still be stored.

=cut

sub store_one_image {
    my $file_id = shift;
    my $sp_person_id = shift;

    # Best label available until the archive record has been read.
    my $filename = "Archived file $file_id";

    try {
        my $archived_file = CXGN::File->new({
            file_id => $file_id,
            metadata_schema => $metadata_schema,
            archive_path => $archive_path
        });

        my $file_path = $archived_file->get_path();
        $filename = $archived_file->filename() || $archived_file->basename();

        if (! -e $file_path) {
            die "the archived image could not be found at $file_path.\n";
        }

        # Look everything up before processing the image. Processing copies, converts and resizes
        # files on disk, and a rolled back transaction cannot undo any of that, so an image that
        # can't be stored never gets that far.
        my $image_info = $image_type eq 'images_barcodes'
            ? read_barcode_info($file_path)
            : read_exif_info($file_path);

        my ($image_id, $is_duplicate) = store_image_file($file_path, $filename, $image_info, $sp_person_id);

        if ($is_duplicate) {
            push @warning_messages, "$filename is already in the database as image ID $image_id. The image was not stored a second time, and the existing image was associated with ".$image_info->{stock_name}." instead.";
        } else {
            my $trait_message = $image_info->{trait_name} ? " and trait ".$image_info->{trait_name} : "";
            push @success_messages, "$filename was stored as image ID $image_id and associated with ".$image_info->{stock_name}.$trait_message.".";
        }

        # The image lives in the image directory now, so the archived copy is no longer needed.
        # A cleanup failure is not worth failing a stored image over.
        try {
            $archived_file->delete_file();
        } catch {
            push @warning_messages, "$filename was stored, but its file could not be removed from the archive: $_";
        };

    } catch {
        push @error_messages, "$filename: $_";
    };
}

=head2 read_exif_info($file_path)

Reads the observation unit and trait recorded in an image's EXIF metadata. Dies with the reason if
the image cannot be stored.

=cut

sub read_exif_info {
    my $file_path = shift;

    my $comment = CXGN::Image->extract_exif_info_class($file_path);
    if (!$comment) {
        die "no EXIF metadata was found in this image.\n";
    }

    my $exif;
    try {
        $exif = decode_json($comment);
    } catch {
        die "the EXIF metadata in this image is not valid JSON.\n";
    };

    my $observation_unit = $exif->{observation_unit}->{observation_unit_db_id};
    if (!$observation_unit) {
        die "the EXIF metadata has no ObservationUnitDbId.\n";
    }

    # The metadata identifies the observation unit either by name or by id, depending on what the
    # study was set up with.
    my $id_type = $exif->{study}->{study_unique_id_name} || '';
    my $stock;
    if ($id_type ne 'ObservationUnitDbId' && $id_type ne 'plot_id') {
        $stock = $chado_schema->resultset('Stock::Stock')->find({ uniquename => $observation_unit });
        if (!$stock) {
            die "the observation unit $observation_unit does not exist in the database.\n";
        }
    } else {
        $stock = $chado_schema->resultset('Stock::Stock')->find({ stock_id => $observation_unit });
        if (!$stock) {
            die "the ObservationUnitDbId $observation_unit does not exist in the database.\n";
        }
    }

    my $trait_name = $exif->{observation_variable}->{observation_variable_name} || '';
    my $trait_id = $exif->{observation_variable}->{external_db_id};
    my $cvterm_id = $trait_id ? SGN::Model::Cvterm->find_trait_by_id($chado_schema, $trait_id) : undef;
    if (!$cvterm_id) {
        my $trait_label = $trait_name ? $trait_name : "recorded in the EXIF metadata";
        die "the associated trait $trait_label does not exist in the database.\n";
    }

    return {
        stock_id => $stock->stock_id(),
        stock_name => $stock->uniquename(),
        cvterm_id => $cvterm_id,
        trait_name => $trait_name
    };
}

=head2 read_barcode_info($file_path)

Reads the observation unit from the barcode printed in an image. Dies with the reason if the image
cannot be stored.

=cut

sub read_barcode_info {
    my $file_path = shift;

    my @barcode_data = CXGN::Image->read_barcode($file_path);

    if (scalar(@barcode_data) > 1) {
        die "multiple barcodes were found. Each image must contain only one barcode.\n";
    }
    if (scalar(@barcode_data) < 1) {
        die "no barcode was found in this image.\n";
    }

    my $stock_id = $barcode_data[0]->{data};
    if (!$stock_id) {
        die "the barcode in this image could not be read.\n";
    }

    my $stock = $chado_schema->resultset('Stock::Stock')->find({ stock_id => $stock_id });
    if (!$stock) {
        die "the stock ID $stock_id found in the barcode does not exist in the database.\n";
    }

    return {
        stock_id => $stock->stock_id(),
        stock_name => $stock->uniquename(),
        cvterm_id => undef,
        trait_name => undef
    };
}

=head2 store_image_file($file_path, $filename, $image_info, $sp_person_id)

Processes the image into the image directory and associates it with its observation unit, and with
its trait if there is one. Returns the image id and whether the image was already in the database.

=cut

sub store_image_file {
    my $file_path = shift;
    my $filename = shift;
    my $image_info = shift;
    my $sp_person_id = shift;

    # Images are processed under the name they were uploaded with, not the timestamped name they
    # were archived under, since the processed image is stored on disk under its original filename.
    my $processing_source = tempdir( "store_images_XXXXXX", TMPDIR => 1, CLEANUP => 1 );
    my $source_path = File::Spec->catfile($processing_source, $filename);
    File::Copy::copy($file_path, $source_path)
        || die "the image could not be prepared for processing: $!\n";

    my $image_id;
    my $is_duplicate;

    my $coderef = sub {
        my $image = CXGN::Image->new( dbh => $chado_schema->storage->dbh(), image_dir => $image_dir );
        $image->set_sp_person_id($sp_person_id);
        $image->set_name($filename);
        $image->set_description("Image uploaded by $username");
        $image->set_obsolete("f");

        # An image that is already in the database is not stored again. It gets associated with the
        # observation unit from this upload instead, so the same photo can be linked to more than
        # one place.
        my ($stored_image_id, $message) = $image->process_image($source_path, undef, undef, 1);

        if (!$stored_image_id) {
            die "the image could not be processed.\n";
        }

        $image_id = $stored_image_id;
        $is_duplicate = $message =~ m/duplicate/i ? 1 : 0;

        associate_stock($image_id, $image_info->{stock_id});

        if ($image_info->{cvterm_id}) {
            associate_cvterm($image_id, $image_info->{cvterm_id}, $sp_person_id);
        }
    };

    $chado_schema->txn_do($coderef);

    return ($image_id, $is_duplicate);
}

=head2 associate_stock($image_id, $stock_id)

Links an image to an observation unit. Written out here rather than done through SGN::Image, which
needs a Catalyst context that a background script has no way to supply.

=cut

sub associate_stock {
    my $image_id = shift;
    my $stock_id = shift;

    my $stored_dbh = $chado_schema->storage->dbh();

    my $existing_q = "SELECT stock_image_id FROM phenome.stock_image WHERE stock_id=? AND image_id=?";
    my $existing_h = $stored_dbh->prepare($existing_q);
    $existing_h->execute($stock_id, $image_id);
    my ($existing_id) = $existing_h->fetchrow_array();
    if ($existing_id) {
        return $existing_id;
    }

    my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema, $username);
    my $metadata_id = $metadata->store()->get_metadata_id();

    my $q = "INSERT INTO phenome.stock_image (stock_id, image_id, metadata_id) VALUES (?,?,?) RETURNING stock_image_id";
    my $h = $stored_dbh->prepare($q);
    $h->execute($stock_id, $image_id, $metadata_id);
    my ($stock_image_id) = $h->fetchrow_array();

    return $stock_image_id;
}

=head2 associate_cvterm($image_id, $cvterm_id, $sp_person_id)

Links an image to the trait it records.

=cut

sub associate_cvterm {
    my $image_id = shift;
    my $cvterm_id = shift;
    my $sp_person_id = shift;

    my $stored_dbh = $chado_schema->storage->dbh();

    my $existing_q = "SELECT md_image_cvterm_id FROM metadata.md_image_cvterm WHERE image_id=? AND cvterm_id=?";
    my $existing_h = $stored_dbh->prepare($existing_q);
    $existing_h->execute($image_id, $cvterm_id);
    my ($existing_id) = $existing_h->fetchrow_array();
    if ($existing_id) {
        return $existing_id;
    }

    my $q = "INSERT INTO metadata.md_image_cvterm (image_id, sp_person_id, cvterm_id) VALUES (?,?,?) RETURNING md_image_cvterm_id";
    my $h = $stored_dbh->prepare($q);
    $h->execute($image_id, $sp_person_id, $cvterm_id);
    my ($image_cvterm_id) = $h->fetchrow_array();

    return $image_cvterm_id;
}

=head2 finish()

Reports everything that happened back to the submitting job and exits. Images are stored one at a
time, so a batch can both store images and report errors.

=cut

sub finish {
    foreach (@success_messages) {
        print STDOUT "SUCCESS: $_\n";
    }
    foreach (@warning_messages) {
        print STDERR "WARNING: $_\n";
    }
    foreach (@error_messages) {
        print STDERR "ERROR: $_\n";
    }

    try {
        my $job = CXGN::Job->new({
            sp_job_id => $sp_job_id,
            schema => $chado_schema,
            people_schema => $people_schema
        });

        if (!$job->additional_args()) {
            $job->additional_args({});
        }

        if (scalar(@success_messages) > 0) {
            $job->additional_args->{success_messages} = join("<br>", @success_messages);
        }
        if (scalar(@warning_messages) > 0) {
            $job->additional_args->{warning_messages} = join("<br>", @warning_messages);
        }
        if (scalar(@error_messages) > 0) {
            $job->additional_args->{error_messages} = join("<br>", @error_messages);
        }

        $job->update_status(scalar(@error_messages) > 0 ? "failed" : "finished");
    } catch {
        print STDERR "Could not report the results of this upload to job $sp_job_id: $_\n";
    };

    exit(scalar(@error_messages) > 0 ? 1 : 0);
}

1;
