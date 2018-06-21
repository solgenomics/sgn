package CXGN::BrAPI::FileRequest;

=head1 NAME

CXGN::BrAPI::FileRequest - an object to handle creating and archiving files for BrAPI requests that store data .

=head1 SYNOPSIS

this module is used to create and archive files for BrAPI requests that store data. It stores the file on fileserver and saves the file to a user, allowing them to access it later on.

=head1 AUTHORS

=cut

use Moose;
use Data::Dumper;

has 'bcs_schema' => (
    isa => "Bio::Chado::Schema",
    is => 'ro',
    required => 1,
);

has 'metadata_schema' => (
    isa => "CXGN::Metadata::Schema",
    is => 'ro',
    required => 1,
);

has 'phenome_schema' => (
    isa => "CXGN::Phenome::Schema",
    is => 'ro',
    required => 1,
);

has 'user_id' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

has 'user_name' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'format' => (
	isa => 'Str',
	is => 'rw',
	required => 1,
);

has 'data' => (
	isa => 'ArrayRef[ArrayRef]',
	is => 'rw',
	required => 1,
);

sub BUILD {
	my $self = shift;
	my $format = $self->format;
	if ($format ne 'Fieldbook'){
		die "format must be Fieldbook\n";
	}
}

sub get_file {
	my $self = shift;
	my $format = $self->format;
	if ($format eq 'Fieldbook'){
		return $self->fieldbook;
	}
}

sub fieldbook {
	my $self = shift;
	my $data = $self->data;
    my $user_id = $self->user_id;

    my $subdirectory_name = "brapi_observations";
    my $archive_path = $self->archive_path();
    my $archive_filename =

    if (!-d $archive_path) {
        mkdir $archive_path;
    }

    if (! -d catfile($archive_path, $user_id)) {
        mkdir (catfile($archive_path, $user_id));
    }

    if (! -d catfile($archive_path, $user_id,$subdirectory_name)) {
        mkdir (catfile($archive_path, $user_id, $subdirectory_name));
    }

    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $file_path =  catfile($archive_path, $user_id, $subdirectory,$timestamp."_".$archive_filename);
    #
	# my $file_path = $self->absolute_file_path;

	my $num_col = scalar(@{$data->[0]});
	open(my $fh, ">", $file_path);
		print STDERR $file_path."\n";
		foreach my $cols (@$data){
			my $step = 1;
			for(my $i=0; $i<$num_col; $i++) {
				if ($cols->[$i]) {
					print $fh "\"$cols->[$i]\"";
				} else {
					print $fh "\"\"";
				}
				if ($step < $num_col) {
					print $fh ",";
				}
				$step++;
			}
			print $fh "\n";
		}
	close $fh;

	return $file_path;
}

1;
