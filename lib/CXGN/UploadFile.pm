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
use List::MoreUtils qw /any /;
use File::Copy;
use File::Spec::Functions;
use File::Basename qw | basename dirname|;
use Digest::MD5;

sub archive {
    my $self = shift;
    my $c = shift;
    my $subdirectory = shift;
    my $tempfile = shift;
    my $archive_filename = shift;
    my $timestamp = shift;
    my $archive_path = $c->config->{archive_path};
    my $user_id;
    my $user_name;
    my $archived_file_name;
    my $file_destination;
    my $error;
    if (!$c->user()) {		#user must be logged in
	die "You need to be logged in to archive a file.\n";
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	die  "You have insufficient privileges to archive a file.\n";
    }
    if (!$subdirectory || !$tempfile || !$archive_filename ) {
	die "File archive failed: incomplete information to archive file.\n";
    }
    $user_id = $c->user()->get_object()->get_sp_person_id();
    $user_name = $c->user()->get_object()->get_username();
    $file_destination =  catfile($archive_path, $user_id, $subdirectory,$timestamp."_".$archive_filename);
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
    my $file_name_and_location = shift;
    #print STDERR $file_name_and_location;

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
