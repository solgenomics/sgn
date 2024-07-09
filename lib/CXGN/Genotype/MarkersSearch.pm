package CXGN::Genotype::MarkersSearch;

=head1 NAME

CXGN::Genotype::MarkersSearch - an object to handle searching markers from genotyping protocols (breeding data)

To get info for a specific protocol:

my $markers_search = CXGN::Genotype::MarkersSearch->new({
    bcs_schema => $schema,
    protocol_id_list => \@protocol_id_list,
    protocol_name_list => \@protocol_name_list,
    marker_name_list => \@marker_names,
    protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'], #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
    limit => $limit,
    offset => $offset
});
my ($result, $total_count) = $markers_search->search();

----------------

=head1 USAGE

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Trial;
use JSON;
use CXGN::Genotype::Protocol;
use List::MoreUtils qw(uniq);

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'protocol_id_list' => (
    isa => 'ArrayRef[Int]',
    is => 'rw',
);

has 'protocol_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'marker_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'protocolprop_marker_hash_select' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
    default => sub {['name', 'chrom', 'pos', 'alt', 'ref', 'qual', 'filter', 'info', 'format']} #THESE ARE ALL POSSIBLE PROTOCOLPROP MARKER HASH KEYS BASED ON VCF LOADING
);

has 'reference_genome_name' => (
    isa => 'Str',
    is => 'rw'
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $protocol_id_list = $self->protocol_id_list;
    my $protocol_name_list = $self->protocol_name_list;
    my $marker_name_list = $self->marker_name_list;
    my $limit = $self->limit;
    my $offset = $self->offset;
    my @data;
    my %search_params;
    my @where_clause;
    my @or_clause;

    my $vcf_snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details_markers', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_array_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details_markers_array', 'protocol_property')->cvterm_id();
    my $igd_genotypeprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'igd number', 'genotype_property')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

    my $protocolprop_marker_hash_select;
    my @all_marker_info_keys = ();
    if ($protocol_id_list && scalar(@$protocol_id_list)>0) {
        foreach my $protocol_id (@$protocol_id_list) {
            my $protocol = CXGN::Genotype::Protocol->new({
                bcs_schema => $schema,
                nd_protocol_id => $protocol_id
            });
            my $marker_info_keys = $protocol->marker_info_keys;
            if (defined $marker_info_keys) {
                push @all_marker_info_keys, @$marker_info_keys;
            }
        }
        @all_marker_info_keys = uniq @all_marker_info_keys;
    }

    if (scalar(@all_marker_info_keys)>0) {
        $protocolprop_marker_hash_select = \@all_marker_info_keys;
    } else {
        $protocolprop_marker_hash_select = $self->protocolprop_marker_hash_select;
    }

    #protocol_id_list is required
    my $protocol_where;
    if ($protocol_id_list && scalar(@$protocol_id_list)>0) {
        my $protocol_sql = join ("," , @$protocol_id_list);
        $protocol_where = "nd_protocolprop.nd_protocol_id in ($protocol_sql)";
    }
    push @where_clause, $protocol_where;

    if ($marker_name_list && scalar(@$marker_name_list)>0) {
        foreach (@$marker_name_list) {
            $_ =~ s/\s+//g;
            push @or_clause, "s.key ILIKE '$_'";
        }
    }
    push @where_clause, "nd_protocolprop.type_id = $vcf_map_details_markers_cvterm_id";

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));
    if (scalar(@or_clause) > 0) {
        $where_clause .=  " AND (" . (join (" OR " , @or_clause))." ) ";
    }

    my $offset_clause = '';
    my $limit_clause = '';
    if ($limit){
        $limit_clause = " LIMIT $limit ";
    }
    if ($offset){
        $offset_clause = " OFFSET $offset ";
    }

    my @protocolprop_marker_hash_select_arr;
    foreach (@$protocolprop_marker_hash_select){
        push @protocolprop_marker_hash_select_arr, "s.value->>'$_'";
    }
    my $protocolprop_hash_select_sql = scalar(@protocolprop_marker_hash_select_arr) > 0 ? ', '.join ',', @protocolprop_marker_hash_select_arr : '';
    my $protocolprop_q = "SELECT nd_protocol_id, s.key $protocolprop_hash_select_sql from nd_protocolprop, jsonb_each(nd_protocolprop.value) as s
        $where_clause
        ORDER BY s.key ASC
        $limit_clause
        $offset_clause;";

    my $protocolprop_h = $schema->storage->dbh()->prepare($protocolprop_q);
    $protocolprop_h->execute();
    my @results;
    while (my ($protocol_id, $marker_name, @protocolprop_info_return) = $protocolprop_h->fetchrow_array()) {
        my $marker_obj = {
            nd_protocol_id => $protocol_id,
            marker_name => $marker_name
        };
        for my $s (0 .. scalar(@protocolprop_marker_hash_select_arr)-1){
            $marker_obj->{$protocolprop_marker_hash_select->[$s]} = $protocolprop_info_return[$s];
        }
        push @results, $marker_obj;
    }

    my $count_q = "SELECT jsonb_array_length(value->'marker_names') FROM nd_protocolprop WHERE $protocol_where;";
    my $count_h = $schema->storage->dbh()->prepare($count_q);
    $count_h->execute();
    my ($total_marker_count) = $count_h->fetchrow_array();
    
    return (\@results, $total_marker_count);
}

1;
