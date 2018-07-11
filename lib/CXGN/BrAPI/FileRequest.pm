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

    #check that user type is adequate to archive file

    my $subdirectory = "brapi_observations_upload";
    my $archive_filename = "observations.csv";

    if (!-d $archive_path) {
        mkdir $archive_path;
    }

    if (! -d catfile($archive_path, $user_id)) {
        mkdir (catfile($archive_path, $user_id));
    }

    if (! -d catfile($archive_path, $user_id,$subdirectory)) {
        mkdir (catfile($archive_path, $user_id, $subdirectory));
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $file_path =  catfile($archive_path, $user_id, $subdirectory,$timestamp."_".$archive_filename);

    my @data = @{$data};
    # my %parse_result = ();

    # Check validity of submitted data
    # my @observations = uniq map { $_->{observationDbId} } @data;
    # my @units = uniq map { $_->{observationUnitDbId} } @data;
    # my @variables = uniq map { $_->{observationVariableDbId} } @data;
    # my @timestamps = uniq map { $_->{observationTimeStamp} } @data;
    #
    # my $validator = CXGN::List::Validate->new();
    # if (scalar @observations) {
    #     my @observations_missing = @{$validator->validate($schema,'phenotypes',\@observations)->{'missing'}};
    # }
    # my @units_missing = @{$validator->validate($schema,'plots_or_subplots_or_plants',\@units)->{'missing'}};
    # my @variables_missing = @{$validator->validate($schema,'traits',\@variables)->{'missing'}};
    # foreach my $timestamp (@timestamps) {
    #     if (!$timestamp =~ m/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})(\S)(\d{4})/) {
    #         $parse_result{'error'} = "Timestamp $timestamp is not of form YYYY-MM-DD HH:MM:SS-0000 or YYYY-MM-DD HH:MM:SS+0000";
    #         print STDERR "Invalid Timestamp: $timestamp\n";
    #         return \%parse_result;
    #     }
    # }

	open(my $fh, ">", $file_path) or die "Couldn't open file $file_path: $!";
    print $fh '"observationDbId","observationUnitDbId","observationVariableDbId","value","observationTimeStamp","collector"'."\n";
		foreach my $plot (@data){
            print $fh "\"$plot->{'observationDbId'}\"," || "\"\",";
            print $fh "\"$plot->{'observationUnitDbId'}\",";
            print $fh "\"$plot->{'observationVariableId'}\",";
            print $fh "\"$plot->{'value'}\",";
            print $fh "\"$plot->{'observationTimeStamp'}\"," || "\"\",";
            print $fh "\"$plot->{'collector'}\"" || "\"\"";
            print $fh "\n";
		}
	close $fh;

	return $file_path;
}

1;
