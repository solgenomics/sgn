package CXGN::UploadFile;

=head1 NAME

CXGN::UploadFile - an object to handle uploading files

=head1 USAGE

 my $uploader = CXGN::UploadFile->new({
    tempfile => '/tmp/myfile.csv',
    subdirectory => 'some_directory',
    second_subdirectory => 'some_directory',
    archive_path => '/some/path/to/dir',
    archive_filename => 'myfilename.csv',
    timestamp => '2016-09-24_10:30:30',
    user_id => 41,
    user_role => 'curator'
 });
 my $uploaded_file = $uploader->archive();
 my $md5 = $uploader->get_md5($uploaded_file);

 In this example, the tempfile myfile.csv will be saved in: /some/path/to/dir/41/some_directory/2016-09-24_10:30:30_myfilename.csv

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use List::MoreUtils qw /any /;
use File::Copy;
use File::Spec::Functions;
use File::Basename qw | basename dirname|;
use Digest::MD5;
use Data::Dumper;

has 'tempfile' => (isa => "Str",
    is => 'rw',
    required => 0
);

has 'subdirectory' => (isa => "Str",
    is => 'rw',
    required => 0
);

has 'second_subdirectory' => (isa => "Str",
    is => 'rw',
    required => 0
);

has 'third_subdirectory' => (isa => "Str",
    is => 'rw',
    required => 0
);

has 'archive_path' => (isa => "Str",
    is => 'rw',
    required => 0
);

has 'archive_filename' => (isa => "Str",
    is => 'rw',
    required => 0
);

has 'timestamp' => (isa => "Str",
    is => 'rw',
    required => 0
);

has 'user_id' => (isa => "Int",
    is => 'rw',
    required => 0
);

has 'user_role' => (isa => "Str",
    is => 'rw',
    required => 0
);

has 'include_timestamp' => (
    isa => "Bool",
    is => 'rw',
    required => 0,
    default => 1
    );

has 'file_type' => (
    isa => 'Str',
    is => 'rw',
    );

sub archive {
    my $self = shift;
    my $subdirectory = $self->subdirectory;
    my $second_subdirectory = $self->second_subdirectory;
    my $third_subdirectory = $self->third_subdirectory;
    my $tempfile = $self->tempfile;
    my $archive_filename = $self->archive_filename;
    my $timestamp = $self->timestamp;
    my $archive_path = $self->archive_path;
    my $user_id = $self->user_id;
    my $file_destination;
    my $error;

    #    if (!$subdirectory || !$tempfile || !$archive_filename || !$timestamp || !$archive_path || !$user_id){
    if (!$subdirectory || !$tempfile || !$timestamp || !$user_id){
        die "To archive a tempfile you need to provide: tempfile, subdirectory, archive_filename, timestamp, archive_path, and user_id\n";
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" || $_ eq "sequencer" } ($self->user_role)  ) {
        die  "You have insufficient privileges to archive a file.\n". Dumper $self->user_role;
    }
    # if (!$subdirectory || !$tempfile || !$archive_filename ) {
    #     print STDERR "File archive failed: incomplete information to archive file.\n";
    # 	die "File archive failed: incomplete information to archive file.\n";
    # }
    if ($self->include_timestamp){
        $file_destination =  catfile($archive_path, $user_id, $subdirectory, $timestamp."_".$archive_filename);
    }
    else {
        $file_destination =  catfile($archive_path, $user_id, $subdirectory, $archive_filename);
    }
    if ($second_subdirectory) {
        if ($self->include_timestamp){
            $file_destination =  catfile($archive_path, $user_id, $subdirectory, $second_subdirectory, $timestamp."_".$archive_filename);
        }
        else {
            $file_destination =  catfile($archive_path, $user_id, $subdirectory, $second_subdirectory, $archive_filename);
        }
        if ($third_subdirectory) {
            if ($self->include_timestamp){
                $file_destination =  catfile($archive_path, $user_id, $subdirectory, $second_subdirectory, $third_subdirectory, $timestamp."_".$archive_filename);
            }
            else {
                $file_destination =  catfile($archive_path, $user_id, $subdirectory, $second_subdirectory, $third_subdirectory, $archive_filename);
            }
        }
    }

    try {

	print STDERR "GENERATING PATH...\n";
        if (!-d $archive_path) {
            mkdir $archive_path;
        }
        if (! -d catfile($archive_path, $user_id)) {
            mkdir (catfile($archive_path, $user_id));
        }
        if (! -d catfile($archive_path, $user_id, $subdirectory)) {
            mkdir (catfile($archive_path, $user_id, $subdirectory));
        }
        if ($second_subdirectory) {
            if (! -d catfile($archive_path, $user_id, $subdirectory, $second_subdirectory)) {
                mkdir (catfile($archive_path, $user_id, $subdirectory, $second_subdirectory));
            }
        }
        if ($second_subdirectory && $third_subdirectory) {
            if (! -d catfile($archive_path, $user_id, $subdirectory, $second_subdirectory, $third_subdirectory)) {
                mkdir (catfile($archive_path, $user_id, $subdirectory, $second_subdirectory, $third_subdirectory));
            }
        }

	print STDERR "COPYING $tempfile to $file_destination\n";
        copy($tempfile,$file_destination);
    }
    catch {
        $error = "Error saving archived file: $file_destination\n$_";
    };
    if ($error) {
        print STDERR  "ERROR: $error\n";
    }
    print STDERR "ARCHIVED: $file_destination\n";
    return $file_destination;
}

sub get_md5 {
    my $self = shift;
    my $file_name_and_location = shift;
    #print STDERR $file_name_and_location;

    open(my $F, "<", $file_name_and_location) || die "Can't open file $file_name_and_location";
    binmode $F;
    my $md5 = Digest::MD5->new();
    $md5->addfile($F);
    close($F);
    return $md5;
}

sub save_archived_file_metadata {
    my $self = shift;
    my $metadata_schema = shift;

    my $experiment_ids = shift;
    
    #my $archived_file = $self->archived_file();
    #my $archived_file_type = $self->file_type();

#    my $md5checksum;

#    if ($archived_file ne 'none'){
#        my $upload_file = CXGN::UploadFile->new();
    my $md5 = $self->get_md5($self->archived_file);
    my $md5checksum = $md5->hexdigest();
#    }

    my $md_row = $self->metadata_schema->resultset("MdMetadata")->create({create_person_id => $self->user_id,});
    $md_row->insert();
    my $file_row = $self->metadata_schema->resultset("MdFiles")
        ->create({
            basename => basename($self->archived_file),
            dirname => dirname($self->archived_file),
            filetype => $self->file_type, 
            md5checksum => $md5checksum,
            metadata_id => $md_row->metadata_id(),
        });
    $file_row->insert();

    foreach my $nd_experiment_id (keys %$experiment_ids) {
        ## Link the file to the experiment
        my $experiment_files = $self->phenome_schema->resultset("NdExperimentMdFiles")
            ->create({
                nd_experiment_id => $nd_experiment_id,
                file_id => $file_row->file_id(),
            });
        $experiment_files->insert();
        #print STDERR "[StorePhenotypes] Linking file: ".$self->archived_file()." \n\t to experiment id " . $nd_experiment_id . "\n";
    }
}

###
1;
###
