package CXGN::Genotype::GRM;

=head1 NAME

CXGN::Genotype::GRM - an object to handle fetching a GRM for stocks

=head1 USAGE

my $geno = CXGN::Genotype::GRM->new({
        bcs_schema=>$schema,
        filename=>$filename,  #file path to write to
        accession_list=>$accession_list,
        tissue_sample_list=>$tissue_sample_list,
        trial_list=>$trial_list,
        protocol_id_list=>$protocol_id_list,
        markerprofile_id_list=>$markerprofile_id_list,
        genotype_data_project_list=>$genotype_data_project_list,
        chromosome_list=>\@chromosome_numbers,
        start_position=>$start_position,
        end_position=>$end_position,
        marker_name_list=>['S80_265728', 'S80_265723'],
        genotypeprop_hash_select=>['DS', 'GT', 'DP'], #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
        protocolprop_top_key_select=>['reference_genome_name', 'header_information_lines', 'marker_names', 'markers'], #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
        protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'], #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
        limit=>$limit,
        offset=>$offset
});
my $grm = $geno->get_grm();

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use JSON;
use CXGN::Stock::Accession;
use CXGN::Genotype::Protocol;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'protocol_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

has 'accession_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

has 'plot_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw'
);

# If the accessions in the plots you are interested have not been genotyped (as in hybrids), can get this boolean to 1 and give a list of plot_id_list and you will get back a GRM built from the parent accessions for those plots (for the plots whose parents were genotyped)
has 'get_grm_for_parental_accessions' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

sub get_grm {
    my $self = shift;
    my $schema = $self->bcs_schema();
    return;
}

1;
