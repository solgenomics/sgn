package CXGN::Transformation::ParseUpload;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;

with 'MooseX::Object::Pluggable';


has 'chado_schema' => (
    is => 'ro',
    isa => 'DBIx::Class::Schema',
    required => 1,
);

has 'filename' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'parse_errors' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_parse_errors',
    reader => 'get_parse_errors',
    predicate => 'has_parse_errors',
);

has '_parsed_data' => (
    is => 'ro',
    isa => 'HashRef',
    writer => '_set_parsed_data',
    predicate => '_has_parsed_data',
);

has 'vector_construct_genes' => (
    isa => 'ArrayRef',
    is => 'ro',
    required => 0,
);


sub parse {
    my $self = shift;

    if (!$self->_validate_with_plugin()) {
        print STDERR "\nCould not validate file: ".$self->get_filename()."\n";
        return;
    }

    if (!$self->_parse_with_plugin()) {
        print STDERR "\nCould not parse file: ".$self->get_filename()."\n";
        return;
    }

    if (!$self->_has_parsed_data()) {
        print STDERR "\nNo parsed data for file: ".$self->get_filename()."\n";
        return;
    } else {
        return $self->_parsed_data();
    }

    print STDERR "\nError parsing file: ".$self->get_filename()."\n";
    return;
}


1;
