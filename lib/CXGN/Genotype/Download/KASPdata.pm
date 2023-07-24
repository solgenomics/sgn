package CXGN::Genotype::Download::KASPdata;

=head1 NAME

CXGN::Genotype::Download::KASPdata - an object to handle downloading KASP genotyping data in csv format

=head1 USAGE


=head1 DESCRIPTION


=head1 AUTHORS

Titima Tantikanjana <tt15@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;
use Text::CSV;
use CXGN::Genotype::Search;
use CXGN::Stock::StockLookup;
use DateTime;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1,
);

has 'protocol_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'genotypeprop_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
);

has 'return_only_first_genotypeprop_for_stock' => (
    isa => 'Bool',
    is => 'ro',
    default => 1
);

has 'filename' => (
    isa => 'Str',
    is => 'ro',
    required => 1,
);


sub download {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $people_schema = $self->people_schema;
    my $protocol_id_list = $self->protocol_id_list;
    my $genotypeprop_hash_select = ['NT', 'XV', 'YV'];
    my $return_only_first_genotypeprop_for_stock = $self->return_only_first_genotypeprop_for_stock;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        protocol_id_list=>$protocol_id_list,
        genotypeprop_hash_select=>$genotypeprop_hash_select
    });

    my $data = $genotypes_search->get_genotype_info();
}

1;
