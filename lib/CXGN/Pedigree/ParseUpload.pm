package CXGN::Pedigree::ParseUpload;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;

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

has 'cross_properties' => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 0,
);

has 'cross_additional_info' => (
    is => 'ro',
    isa => 'ArrayRef',
    required => 0,
);


sub parse {
    my $self = shift;

    if (!$self->_validate_with_plugin()) {
        print STDERR "\nCould not validate cross file: ".$self->get_filename()."\n";
        return;
    }

    if (!$self->_parse_with_plugin()) {
        print STDERR "\nCould not parse cross file: ".$self->get_filename()."\n";
        return;
    }

    if (!$self->_has_parsed_data()) {
        print STDERR "\nNo parsed data for cross file: ".$self->get_filename()."\n";
        return;
    } else {
        return $self->_parsed_data();
    }

    print STDERR "\nError parsing cross file: ".$self->get_filename()."\n";
    return;
}


1;
