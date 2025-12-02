package CXGN::BrAPI::FileRequest;

=head1 NAME

CXGN::BrAPI::FileRequest - an object to handle creating and archiving files for BrAPI requests that store data .

=head1 SYNOPSIS

this module is used to create and archive files for BrAPI requests that store data. It stores the file on fileserver and saves the file to a user, allowing them to access it later on.

=head1 AUTHORS

=cut

use Moose;
use Data::Dumper;
use File::Spec::Functions;
use List::MoreUtils qw(uniq);
use DateTime;
use CXGN::UploadFile;
use CXGN::People::Schema;

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'user_id' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

has 'user_type' => (
    is => 'ro',
    isa => 'Maybe[Str]',
    required => 1,
);

has 'format' => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has 'tempfiles_subdir' => (
    isa => "Str",
    is => 'rw',
    required => 1,
);

has 'archive_path' => (
    isa => "Str",
    is => 'rw',
    required => 1,
);

has 'data' => (
	isa => 'ArrayRef',
	is => 'rw',
	required => 1,
);

sub BUILD {
	my $self = shift;
	my $format = $self->format;
	if ($format ne 'observations'){
		die "format must be observations\n";
	}
}

sub get_path {
	my $self = shift;
	my $format = $self->format;
	if ($format eq 'observations'){
		return $self->observations;
	}
}

sub observations {
    my $self = shift;
    my $schema = $self->schema;
    my $data = $self->data;
    my $user_id = $self->user_id;
    my $user_type = $self->user_type;
    my $archive_path = $self->archive_path;
    my $tempfiles_subdir = $self->tempfiles_subdir;
    my $error_message;
    my $success_message;

    my $subdirectory = "brapi_observations_upload";
    my $archive_filename = "observations.csv";
    my $upload_tempfile = $tempfiles_subdir."/".$archive_filename;

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();

    open(my $fh, ">", $upload_tempfile) or die "Couldn't open file $upload_tempfile: $!";
    print $fh '"observationDbId","observationUnitDbId","observationVariableDbId","value","observationTimeStamp","collector"'."\n";
        foreach my $plot (@$data){
            print $fh "\"$plot->{'observationDbId'}\"," || "\"\",";
            print $fh "\"$plot->{'observationUnitDbId'}\",";
            print $fh "\"$plot->{'observationVariableDbId'}\",";
            print $fh "\"$plot->{'value'}\",";
            print $fh "\"$plot->{'observationTimeStamp'}\"," || "\"\",";
            print $fh "\"$plot->{'collector'}\"" || "\"\"";
            print $fh "\n";
        }
    close $fh;

    my $people_schema = CXGN::People::Schema->connect( sub { return $schema->storage->dbh(); } );
    my $access = CXGN::Access->new( { schema => $schema, people_schema => $people_schema });
    my $write_access = $access->grant($user_id, "write", "phenotyping") || $access->grant($user_id, "write", "genotyping") || $access->grant($user_id, "write", "trials");

    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $archive_path,
        archive_filename => $archive_filename,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_type,
	has_upload_permissions => $write_access,
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $error_message = "Could not save incoming brapi observations into file for archive.";
    } else {
        $success_message = "File for incoming brapi obserations saved in archive.";
    }
    unlink $upload_tempfile;

    return {
        archived_filename_with_path => $archived_filename_with_path,
        error_message => $error_message,
        success_message => $success_message
    };
}

1;
