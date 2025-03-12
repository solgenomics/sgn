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
    user_role => 'curator', ### deprecated, use has_upload_permissions
    has_upload_permissions => 1, 
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

has 'has_upload_permissions' => (
    isa => "Bool",
    is => 'rw',
    required => 0,
);

has 'include_timestamp' => (
    isa => "Bool",
    is => 'rw',
    required => 0,
    default => 1
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

    if ( !(any { $_ eq "curator" || $_ eq "submitter" || $_ eq "sequencer" } ($self->user_role)) && ! $self->has_upload_permissions()) {
	print STDERR "USER ROLE: ".$self->user_role()." HAS UPLOAD PERMISSIONS: ".$self->has_upload_permissions()."\n";
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

        copy($tempfile,$file_destination);
    }
    catch {
        $error = "Error saving archived file: $file_destination\n$_";
    };
    if ($error) {
        print STDERR  "$error\n";
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

###
1;
###
