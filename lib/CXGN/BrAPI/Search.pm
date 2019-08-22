package CXGN::BrAPI::Search;

=head1 NAME

CXGN::BrAPI::Search - an object to handle saving and retrieving BrAPI search parameters in the database

=head1 SYNOPSIS

this module is used to save and retrieve parameters for complex BrAPI search requests
=head1 AUTHORS

=cut

use Moose;
use Data::Dumper;
use JSON;
use Digest::MD5;
use File::Slurp;

has 'tempfiles_subdir' => (
    isa => '[Str]',
    is => 'rw',
);

has 'search_type' => (
    isa => '[Str]',
    is => 'rw',
);

has 'search_params' => (
    isa => 'Maybe[HashRef[ArrayRef]]',
    is => 'rw',
);

has 'search_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);

sub BUILD {
	my $self = shift;
	my $search_type = $self->search_type;
    #add types as they are implemented
    my @allowed_types = ['germplasm'];
    my @allowed_types = ['studies'];
    my @allowed_types = ['samples'];
    my @allowed_types = ['trials'];
    my %allowed_types = map { $_ => 1 } @allowed_types;

	unless (exists($allowed_types{$search_type})){
		die "format must be one of: @allowed_types\n";
	}
}

sub save {
	my $self = shift;
	my $search_params = shift;
    my $dir = $self->tempfiles_subdir();

    #get md5 hash as id
    my $md5 = Digest::MD5->new();
    $md5->add($search_json);
    my $search_id = $md5->hexdigest();

    #write to tmp file with id as name
    open my $fh, ">", $dir . "/" . $search_id;
    print $fh encode_json($search_params);
    close $fh;

    return $search_id;
}

sub retrieve {
    my $self = shift;
	my $search_id = shift;
    my $dir = $self->tempfiles_subdir();
    my $search_json;
    my $filename = $dir . "/" . $search_id;

    # check if file exists, if it does retrive and return contents
    if (-e $filename) {
        $search_json = read_file( 'input.txt' ) ;
    }
    my $search_params = decode_json($search_json);
    return $search_params;
}



1;
