package CXGN::Marker::SearchBrAPI;

=head1 NAME

CXGN::Marker::SearchBrAPI - an object to handle searching for markers given criteria

=head1 USAGE

my $marker_search = CXGN::Marker::SearchBrAPI->new({
    bcs_schema=>$schema,
    marker_ids=>\@marker_ids,
    marker_names=>\@marker_names,
    get_synonyms=>$synonyms,
    match_method=>$method,
    types=>\@types, 
    offset=>$page_size*$page,
    limit=>$page_size
});
my ($result, $total_count) = $marker_search->search();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;

use CXGN::Marker;
use CXGN::Marker::LocMarker;
use CXGN::Marker::Tools qw(clean_marker_name);
use SGN::Model::Cvterm;
use CXGN::Trial;
use JSON;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'nd_protocol_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'marker_ids' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'marker_names' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'marker_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'get_synonyms' => (
    isa => 'Bool|Undef',
    is => 'rw',
    default => 0
);

has 'match_method' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'project_id_list' => (
    isa => 'ArrayRef[Int]',
    is => 'rw',
);

has 'protocol_id_list' => (
    isa => 'ArrayRef[Int]',
    is => 'rw',
);

has 'protocol_name_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
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

has 'types' => (
    isa => 'ArrayRef[Int]|Undef',
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


sub searchv1 {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $marker_ids = $self->marker_ids;
    my $marker_names = $self->marker_names;
    my $get_synonyms = $self->get_synonyms;
    my $match_method = $self->match_method;
    my $types = $self->types;
    my $limit = $self->limit;
    my $offset = $self->offset;
    my @where_clause;
    my $comparison;

    if ($match_method eq 'exact'){ $comparison = 'in';} 
    elsif ($match_method eq 'case_insensitive'){ $comparison = 'ilike'; }
    else { $comparison = 'like'; }

    if ($marker_ids && scalar(@$marker_ids)>0) {
        my $sql = join ("," , @$marker_ids);
        push @where_clause, "marker.marker_id in ($sql)";
    }

    if ($marker_names && scalar(@$marker_names)>0) {
        my $sql = join ("," , @$marker_names);
        push @where_clause, "marker_names.name in ($sql)";
    }

    if ($types && scalar(@$types)>0) {
        my $sql = join ("," , @$types);
        push @where_clause, "protocol in ($sql)";
    }

    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

       
    my $subquery = "SELECT distinct m2m.marker_id,name,alias,protocol,organism_name,common_name.common_name FROM sgn.marker 
        LEFT JOIN sgn.marker_to_map as m2m using(marker_id) 
        INNER JOIN sgn.accession ON(parent_1 = accession.accession_id OR parent_2 = accession.accession_id) 
        INNER JOIN sgn.organism using(organism_id) 
        INNER JOIN sgn.common_name USING(common_name_id) 
        INNER JOIN marker_names ON(m2m.marker_id=marker_names.marker_id) 
        INNER JOIN marker_alias ON(m2m.marker_id=marker_alias.marker_id) $where_clause";

    my $h = $schema->storage->dbh()->prepare($subquery);
    $h->execute();

    my @result;
    my $total_count = 0;
    my $subtract_count = 0;

    while (my ($marker_id, $marker_name, $reference, $alias, $protocol, $full_count) = $h->fetchrow_array()) {
        push @result, {
            marker_id => $marker_id,
            marker_name => $marker_name,
            method => $protocol,
            references => $reference,
            synonyms => $alias,
            type => $protocol
        };
        $total_count = $full_count;
    }

    my @data_window;
    if (($limit && defined($limit) || ($offset && defined($offset)))){
        my $start = $offset;
        my $end = $offset + $limit - 1;
        for( my $i = $start; $i <= $end; $i++ ) {
            if ($result[$i]) {
                push @data_window, $result[$i];
            }
        }
    } else {
        @data_window = @result;
    }

    $total_count = $total_count-$subtract_count;
    return (\@data_window, $total_count);

}


sub search {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $protocol_id_list = $self->protocol_id_list;
    my $protocol_name_list = $self->protocol_name_list;
    my $marker_name_list = $self->marker_name_list;
    my $protocolprop_marker_hash_select = $self->protocolprop_marker_hash_select;
    my $project_id_list = $self->project_id_list;
    my $limit = $self->limit;
    my $offset = $self->offset;
    my @data;
    my %search_params;
    my @where_clause;
    my $where;
    my @or_clause;
    
    my $vcf_snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_vcf_genotyping_cvterm_id($schema, {'protocol_id' => $protocol_id_list->[0]});
    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details_markers', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_array_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details_markers_array', 'protocol_property')->cvterm_id();
    my $igd_genotypeprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'igd number', 'genotype_property')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

    my $protocol_where = "";
    if ($protocol_id_list && scalar(@$protocol_id_list)>0) {
        my $protocol_sql = join ("," , @$protocol_id_list);
        $protocol_where = "nd_protocolprop.nd_protocol_id in ($protocol_sql)";
        push @where_clause, $protocol_where;
    }
   
    if ($marker_name_list && scalar(@$marker_name_list)>0) {
        foreach (@$marker_name_list) {
            push @or_clause, " s.key = '$_'";
        }
    }
    push @where_clause, "nd_protocolprop.type_id = $vcf_map_details_markers_cvterm_id";

    my $where_clause = " WHERE " . (join (" AND " , @where_clause));
    if (scalar(@or_clause) == 1 ) {
        $where_clause .=  " AND " . (join (" OR " , @or_clause))."  ";
    } elsif (scalar(@or_clause) > 1) {
        $where_clause .=  " AND (" . (join (" OR " , @or_clause))." ) ";
    }

    my $project_where = "";
    if ($project_id_list && scalar(@$project_id_list)>0) {
        my $project_sql = join ("," , @$project_id_list);
        $project_where = " and project_id in ($project_sql)";
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

    my $protocolprop_q = "SELECT nd_protocolprop.nd_protocol_id, s.key, array_agg(project.project_id)
        $protocolprop_hash_select_sql
        FROM nd_protocolprop, jsonb_each(nd_protocolprop.value) as s,  (select DISTINCT nd_experiment_project.project_id as project_id, nd_experiment_protocol.nd_protocol_id from  nd_experiment_protocol  
        inner join nd_experiment ON(nd_experiment.nd_experiment_id = nd_experiment_protocol.nd_experiment_id ) 
        inner join nd_experiment_project ON(nd_experiment_project.nd_experiment_id = nd_experiment_protocol.nd_experiment_id))  project
        $where_clause and nd_protocolprop.nd_protocol_id = project.nd_protocol_id  $project_where 
        GROUP BY nd_protocolprop.nd_protocol_id, nd_protocolprop.value, s.key $protocolprop_hash_select_sql
        ORDER BY s.key ASC
        $limit_clause
        $offset_clause;";

    my $protocolprop_h = $schema->storage->dbh()->prepare($protocolprop_q);
    $protocolprop_h->execute();
    my @results;
    my $total_marker_count = 0;

    while (my ($protocol_id, $marker_name, $project_id, @protocolprop_info_return) = $protocolprop_h->fetchrow_array()) {
        my $marker_obj = {
            nd_protocol_id => $protocol_id,
            marker_name => $marker_name,
            project_id => $project_id
        };
        for my $s (0 .. scalar(@protocolprop_marker_hash_select_arr)-1){
            $marker_obj->{$protocolprop_marker_hash_select->[$s]} = $protocolprop_info_return[$s];
        }
        push @results, $marker_obj;
        $total_marker_count++;
    }

    return (\@results, $total_marker_count);
}

1;