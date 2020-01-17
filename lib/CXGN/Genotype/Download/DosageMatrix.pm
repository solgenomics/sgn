package CXGN::Genotype::Download::DosageMatrix;

=head1 NAME

CXGN::Genotype::Download::DosageMatrix - an object to handle downloading genotypes in dosage matrix format

=head1 USAGE

SHOULD BE USED VIA CXGN::Genotype::DownloadFactory

PLEASE BE AWARE THAT THE DEFAULT OPTIONS FOR genotypeprop_hash_select, protocolprop_top_key_select, protocolprop_marker_hash_select ARE PRONE TO EXCEEDING THE MEMORY LIMITS OF VM. CHECK THE MOOSE ATTRIBUTES BELOW TO SEE THE DEFAULTS, AND ADJUST YOUR MOOSE INSTANTIATION ACCORDINGLY

my $genotypes_search = CXGN::Genotype::Download::DosageMatrix->new({
    bcs_schema=>$schema,
    cache_root_dir=>$cache_root,
    accession_list=>$accession_list,
    tissue_sample_list=>$tissue_sample_list,
    trial_list=>$trial_list,
    protocol_id_list=>$protocol_id_list,
    markerprofile_id_list=>$markerprofile_id_list,
    genotype_data_project_list=>$genotype_data_project_list,
    marker_name_list=>['S80_265728', 'S80_265723'],
    genotypeprop_hash_select=>['DS', 'GT', 'DP'], #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
    limit=>$limit,
    offset=>$offset
});
my ($total_count, $genotypes) = $genotypes_search->get_genotype_info();

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>

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

has 'cache_root_dir' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'protocol_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'markerprofile_id_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'tissue_sample_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'genotype_data_project_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'ro',
);

has 'chromosome_list' => (
    isa => 'ArrayRef[Int]|ArrayRef[Str]|Undef',
    is => 'ro',
);

has 'start_position' => (
    isa => 'Int|Undef',
    is => 'ro',
);

has 'end_position' => (
    isa => 'Int|Undef',
    is => 'ro',
);

has 'marker_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'ro',
);

has 'genotypeprop_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['DS']} #THESE ARE THE GENERIC AND EXPECTED VCF ATRRIBUTES. For dosage matrix we only need DS
);

has 'protocolprop_top_key_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['markers']} #THESE ARE ALL POSSIBLE TOP LEVEL KEYS IN PROTOCOLPROP BASED ON VCF LOADING. For dosage matrix we only need markers
);

has 'protocolprop_marker_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['name']} #THESE ARE ALL POSSIBLE PROTOCOLPROP MARKER HASH KEYS BASED ON VCF LOADING. For dosage matrix we only need name
);

has 'return_only_first_genotypeprop_for_stock' => (
    isa => 'Bool',
    is => 'ro',
    default => 1
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw',
);

sub download {
    my $self = shift;
    my $c = shift;
    my $schema = $self->bcs_schema;
    my $cache_root_dir = $self->cache_root_dir,
    my $trial_list = $self->trial_list;
    my $genotype_data_project_list = $self->genotype_data_project_list;
    my $protocol_id_list = $self->protocol_id_list;
    my $markerprofile_id_list = $self->markerprofile_id_list;
    my $accession_list = $self->accession_list;
    my $tissue_sample_list = $self->tissue_sample_list;
    my $marker_name_list = $self->marker_name_list;
    my $genotypeprop_hash_select = $self->genotypeprop_hash_select;
    my $protocolprop_top_key_select = $self->protocolprop_top_key_select;
    my $protocolprop_marker_hash_select = $self->protocolprop_marker_hash_select;
    my $return_only_first_genotypeprop_for_stock = $self->return_only_first_genotypeprop_for_stock;
    my $limit = $self->limit;
    my $offset = $self->offset;
    my $chromosome_list = $self->chromosome_list;
    my $start_position = $self->start_position;
    my $end_position = $self->end_position;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        cache_root=>$cache_root_dir,
        accession_list=>$accession_list,
        tissue_sample_list=>$tissue_sample_list,
        trial_list=>$trial_list,
        protocol_id_list=>$protocol_id_list,
        markerprofile_id_list=>$markerprofile_id_list,
        genotype_data_project_list=>$genotype_data_project_list,
        marker_name_list=>$marker_name_list,
        genotypeprop_hash_select=>$genotypeprop_hash_select,
        protocolprop_top_key_select=>$protocolprop_top_key_select,
        protocolprop_marker_hash_select=>$protocolprop_marker_hash_select,
        return_only_first_genotypeprop_for_stock=>$return_only_first_genotypeprop_for_stock,
        chromosome_list=>$chromosome_list,
        start_position=>$start_position,
        end_position=>$end_position,
        limit=>$limit,
        offset=>$offset
    });
    return $genotypes_search->get_cached_file_dosage_matrix($c);
}

1;
