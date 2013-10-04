
package CXGN::Phenotype::ParseUpload::Plugin::FieldBook;

use Moose;

sub name { 
    return "field book";
}

sub validate {
    my $self = shift;
    my $c = shift;
    my $filename = shift;
    my %validate_result;
    return \%validate_result;
}

sub parse {
    my $self = shift;
    my $c = shift;
    my $filename = shift;
    my %parse_result;
    return \%parse_result;
}

1;
