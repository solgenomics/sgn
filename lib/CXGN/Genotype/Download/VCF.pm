package CXGN::Genotype::Download::VCF;

=head1 NAME

CXGN::Genotype::Download::VCF - an object to handle downloading genotypes in VCF format

=head1 USAGE

SHOULD BE USED VIA CXGN::Genotype::DownloadFactory

PLEASE BE AWARE THAT THE DEFAULT OPTIONS FOR genotypeprop_hash_select, protocolprop_top_key_select, protocolprop_marker_hash_select ARE PRONE TO EXCEEDING THE MEMORY LIMITS OF VM. CHECK THE MOOSE ATTRIBUTES BELOW TO SEE THE DEFAULTS, AND ADJUST YOUR MOOSE INSTANTIATION ACCORDINGLY

my $genotypes_search = CXGN::Genotype::Download::VCF->new({
    bcs_schema=>$schema,
    people_schema=>$people_schema,
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
    limit=>$limit,
    offset=>$offset,
    compute_from_parents=>0, #Whether to look at the pedigree to see if parents are genotyped and to calculate genotype from parents
    forbid_cache=>0, #If you want to get a guaranteed fresh result not from the file cache
    return_only_first_genotypeprop_for_stock=>1
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

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
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
    default => sub {['GT', 'AD', 'DP', 'GQ', 'DS', 'PL', 'NT']} #THESE ARE THE GENERIC AND EXPECTED VCF ATRRIBUTES
);

has 'protocolprop_top_key_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['reference_genome_name', 'species_name', 'header_information_lines', 'sample_observation_unit_type_name', 'marker_names', 'markers', 'markers_array']} #THESE ARE ALL POSSIBLE TOP LEVEL KEYS IN PROTOCOLPROP BASED ON VCF LOADING
);

has 'protocolprop_marker_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['name', 'chrom', 'pos', 'alt', 'ref', 'qual', 'filter', 'info', 'format']} #THESE ARE ALL POSSIBLE PROTOCOLPROP MARKER HASH KEYS BASED ON VCF LOADING
);

has 'return_only_first_genotypeprop_for_stock' => (
    isa => 'Bool',
    is => 'ro',
    default => 1
);

has 'compute_from_parents' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

has 'forbid_cache' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
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
    my $cluster_shared_tempdir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config = shift;
    my $schema = $self->bcs_schema;
    my $people_schema = $self->people_schema;
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
    my $forbid_cache = $self->forbid_cache;
    my $compute_from_parents = $self->compute_from_parents;

    my $genotypes_search = CXGN::Genotype::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
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
        offset=>$offset,
        forbid_cache=>$forbid_cache
    });
    my @required_config = (
        $cluster_shared_tempdir_config,
        $backend_config,
        $cluster_host_config,
        $web_cluster_queue_config,
        $basepath_config
    );
    if ($compute_from_parents) {
        print STDERR Dumper "Computing genotype dosages VCF From Parents......";
        return $genotypes_search->get_cached_file_VCF_compute_from_parents(@required_config);
    }
    else {
        return $genotypes_search->get_cached_file_VCF(@required_config);
    }
}

1;
