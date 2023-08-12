package CXGN::Stock::TissueSample::FacilityIdentifiers;

use strict;
use warnings;
use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'facility_identifier_list' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
);

sub get_tissue_samples {
    my $self = shift;
    my $facility_identifier_list = $self->facility_identifier_list();
    my $schema = $self->bcs_schema();
    my $tissue_sample_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $facility_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'facility_identifier', 'stock_property')->cvterm_id();
    my %stock_hash;

    foreach my $facility_identifier (@$facility_identifier_list) {
        my $stockprop_rs = $schema->resultset("Stock::Stockprop")->find({type_id => $facility_identifier_type_id, value => $facility_identifier});
        my $stock_id = $stockprop_rs->stock_id();

        my $stock_rs = $schema->resultset("Stock::Stock")->find({stock_id => $stock_id, type_id => $tissue_sample_type_id});
        my $stock_name = $stock_rs->uniquename();

         $stock_hash{$facility_identifier} = $stock_name;

    }

    return \%stock_hash;
}


1;
