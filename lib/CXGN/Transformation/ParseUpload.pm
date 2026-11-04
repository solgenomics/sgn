package CXGN::Transformation::ParseUpload;

=head1 NAME

CXGN::Transformation::ParseUpload - parse transformation upload files

=head1 ATTRIBUTES

=head2 i18n

Optional request-local C<SGN::I18N> translator for human-readable validation
messages. When omitted, the parser and its file reader retain English fallback
text.

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;

with 'MooseX::Object::Pluggable';

has 'i18n' => (
    is => 'ro',
    isa => 'Maybe[Object]',
    reader => 'i18n',
    required => 0,
);

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

has 'vector_stock_id' => (
    isa => 'Maybe[Int]',
    is => 'ro',
    required => 0,
);

has 'vector_construct_genes' => (
    isa => 'ArrayRef|Undef',
    is => 'ro',
    required => 0,
);

has 'endogenous_control' => (
    isa => 'Maybe[Str]',
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
