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
use File::Basename qw(basename);
use File::Temp ();
use File::Path qw(make_path);
use Text::CSV;
use JSON ();
use List::MoreUtils qw(uniq);
use DateTime;
use CXGN::UploadFile;

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
    isa => 'Str',
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
    my $data = $self->data;
    my $user_id = $self->user_id;
    my $user_type = $self->user_type;
    my $archive_path = $self->archive_path;
    my $tempfiles_subdir = $self->tempfiles_subdir;
    my $error_message;
    my $success_message;

    my $subdirectory = "brapi_observations_upload";
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my ($upload_tempfile, $reserved_archive, $archived_filename_with_path);
    my $archived = eval {
        make_path($tempfiles_subdir) if !-d $tempfiles_subdir;
        my ($fh, $input_path) = File::Temp::tempfile(
            'observations_XXXXXX', DIR => $tempfiles_subdir, SUFFIX => '.csv', UNLINK => 0,
        );
        $upload_tempfile = $input_path;
        binmode($fh, ':encoding(UTF-8)') or die "Could not set request archive encoding: $!";
        my @columns = qw(observationDbId observationUnitDbId observationVariableDbId value observationTimeStamp collector);
        my $csv = Text::CSV->new({binary => 1, always_quote => 1, eol => "\n"});
        # Keep the six established columns. Extra JSON columns preserve accepted
        # metadata and every incoming key without changing their JSON types.
        my $json = JSON->new->canonical->ascii(1)->allow_nonref(1);
        $csv->print($fh, [@columns, qw(additionalInfo externalReferences requestJSON)])
            or die "Could not write request archive header: ".$csv->error_diag;
        foreach my $observation (@$data) {
            my @row = map {
                my $value = $observation->{$_};
                !defined($value) ? '' : ref($value) ? $json->encode($value) : $value;
            } @columns;
            push @row, map {exists($observation->{$_}) ? $json->encode($observation->{$_}) : ''} qw(additionalInfo externalReferences);
            push @row, $json->encode($observation);
            $csv->print($fh, \@row) or die "Could not write request archive record: ".$csv->error_diag;
        }
        close($fh) or die "Could not finish request archive: $!";

        # Reserve the actual destination, not only the input tempfile. Both
        # concurrent requests and serial requests within a second stay distinct.
        my $destination_dir = catdir($archive_path, $user_id, $subdirectory);
        make_path($destination_dir) if !-d $destination_dir;
        my ($reserved, $destination) = File::Temp::tempfile(
            $timestamp.'_observations_XXXXXX', DIR => $destination_dir, SUFFIX => '.csv', UNLINK => 0,
        );
        $reserved_archive = $destination;
        close($reserved) or die "Could not reserve request archive: $!";
        my $uploader = CXGN::UploadFile->new({
            tempfile => $upload_tempfile,
            subdirectory => $subdirectory,
            archive_path => $archive_path,
            archive_filename => basename($reserved_archive),
            timestamp => $timestamp,
            include_timestamp => 0, # the reserved basename already includes it
            user_id => $user_id,
            user_role => $user_type,
        });
        $archived_filename_with_path = $uploader->archive();
        die "No request archive was written" if !$archived_filename_with_path || !-f $archived_filename_with_path;
        die "Request archive copy is incomplete" if $uploader->get_md5($upload_tempfile)->hexdigest ne $uploader->get_md5($archived_filename_with_path)->hexdigest;
        1;
    };
    if ($archived) {
        $success_message = "File for incoming brapi obserations saved in archive.";
    } else {
        print STDERR "Error archiving BrAPI observations: $@\n";
        unlink $reserved_archive if defined($reserved_archive) && -f $reserved_archive;
        $archived_filename_with_path = undef;
        $error_message = "Could not save incoming BrAPI observations in the archive.";
    }
    unlink $upload_tempfile if defined($upload_tempfile) && -f $upload_tempfile;

    return {
        archived_filename_with_path => $archived_filename_with_path,
        error_message => $error_message,
        success_message => $success_message
    };
}

1;
