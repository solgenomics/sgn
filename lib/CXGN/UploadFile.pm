package CXGN::UploadFile;

=head1 NAME

CXGN::UploadFile - an object to handle uploading files

=head1 USAGE

 my $uploader = CXGN::UploadFile->new();
 my $uploaded_file = $uploader->archive($c,$subdirectory,$tempfile,$archive_filename);
 my $md5 = $uploader->get_md5($uploaded_file);

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use File::Basename qw | basename dirname|;
use Digest::MD5;

sub archive {
    my $self = shift;
    my $c = shift;
    my $subdirectory = shift;
    my $tempfile = shift;
    my $archive_filename = shift;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $archive_path = $c->config->{archive_path};
    my $user_id;
    my $user_name;
    my $user_string;
    my $archived_file_name;
    my $file_destination;
    my $error;
    if (!$c->user()) {		#user must be logged in
	die "You need to be logged in to upload a file.\n";
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	die  "You have insufficient privileges to upload a file.\n";
    }
    if (!$upload) {		#upload file required
	die "File upload failed: no file name received.\n";
    }
    $user_id = $c->user()->get_object()->get_sp_person_id();
    $user_name = $c->user()->get_object()->get_username();
    $user_string = $user_name.'_'.$user_id;
    $archived_file_name = catfile($user_string, $timestamp."_".$archive_filename);
    $file_destination =  catfile($archive_path, $user_string, $subdirectory, $archived_filename);
    try {
	if (!-d $archive_path) {
	    mkdir $archive_path;
	}
	if (! -d catfile($archive_path, $user_string)) {
	    mkdir (catfile($archive_path, $user_string));
	}
	if (! -d catfile($archive_path, $user_string, $subdirectory)) {
	    mkdir (catfile($archive_path, $user_string, $subdirectory));
	}
	copy($tempfile,$file_destination);
    } catch {
	$error = "Error saving archived file: $file_destination\n$_";
    };
    if ($error) {
	die "$error\n";
    }
    return $file_destination;
}

sub get_md5 {
    my $self = shift;
    my $file_name_and_location;
    open(my $F, "<", $file_name_and_location) || die "Can't open file ";
    binmode $F;
    my $md5 = Digest::MD5->new();
    $md5->addfile($F);
    close($F);
    return $md5;
}

###
1;
###
