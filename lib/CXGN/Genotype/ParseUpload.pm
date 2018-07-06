package CXGN::Genotype::ParseUpload;

use Moose;
use Data::Dumper;
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

sub parse {
    my $self = shift;

    if (!$self->_validate_with_plugin()) {
        my $errors = $self->get_parse_errors();
        #print STDERR "\nCould not validate genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
        return;
    }

    if (!$self->_parse_with_plugin()) {
        my $errors = $self->get_parse_errors();
        #print STDERR "\nCould not parse genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
        return;
    }

    if (!$self->_has_parsed_data()) {
        my $errors = $self->get_parse_errors();
        #print STDERR "\nNo parsed data for genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
        return;
    } else {
        return $self->_parsed_data();
    }

    my $errors = $self->get_parse_errors();
    #print STDERR "\nError parsing genotypes file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
    return;
}


1;
