package CXGN::Trial::ParseUpload;

use Moose;
use Data::Dumper;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;

with 'MooseX::Object::Pluggable';


has 'chado_schema' => (
    is       => 'ro',
    isa      => 'DBIx::Class::Schema',
    required => 1
);

has 'trial_id' => (
    is => 'ro',
    isa => 'Str',
    required => 0
);

has 'filename' => (
    is => 'ro',
    isa => 'Str',
    required => 1
);

has 'parse_warnings' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_parse_warnings',
    reader => 'get_parse_warnings',
    predicate => 'has_parse_warnings'
);

has 'parse_errors' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_parse_errors',
    reader => 'get_parse_errors',
    predicate => 'has_parse_errors'
);

has '_parsed_data' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_parsed_data',
    predicate => '_has_parsed_data'
);

has '_validated_data' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_validated_data',
    reader => '_get_validated_data',
    predicate => '_has_validated_data',
    required => 0
);

has '_location_code_map' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_location_code_map',
    reader => '_get_location_code_map',
    predicate => '_has_location_code_map',
    required => 0
);

has 'trial_stock_type' => (
    isa => 'Str',
    is => 'rw',
    predicate => 'has_trial_stock_type',
    required => 0,
    default => 'accession'
);

has 'trial_name' => (
    isa => 'Str',
    is => 'rw',
    writer => '_set_trial_name',
    reader => 'get_trial_name',
    predicate => 'has_trial_name',
    required => 0
);

has 'facility_identifiers_included' => (
    isa => 'Bool',
    is => 'ro',
    default => 0,
);

has 'allowed_tissue_list' => (
    is => 'ro',
    isa => 'Str',
    writer => '_set_allowed_tissue_list',
    reader => 'get_allowed_tissue_list',
    required => 0
);


sub parse {
  my $self = shift;
  my $args = shift;

  if (!$self->_validate_with_plugin($args)) {
		my $errors = $self->get_parse_errors();
    print STDERR "\nCould not validate trial file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
    return;
  }

  # print STDERR "Check 3.1: ".localtime();

  if (!$self->_parse_with_plugin($args)) {
		my $errors = $self->get_parse_errors();
    print STDERR "\nCould not parse trial file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
    return;
  }

  # print STDERR "Check 3.2: ".localtime();

  if (!$self->_has_parsed_data()) {
		my $errors = $self->get_parse_errors();
    print STDERR "\nNo parsed data for trial file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
    return;
  } else {
    return $self->_parsed_data();
  }

  #print STDERR "Check 3.3: ".localtime();

	my $errors = $self->get_parse_errors();
  print STDERR "\nError parsing trial file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
  return;
}


1;
