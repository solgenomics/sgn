package CXGN::Genotype::Search;

=head1 NAME

CXGN::Genotype::Search - an object to handle searching genotypes for stocks

=head1 USAGE

PLEASE BE AWARE THAT THE DEFAULT OPTIONS FOR genotypeprop_hash_select, protocolprop_top_key_select, protocolprop_marker_hash_select ARE PRONE TO EXCEEDING THE MEMORY LIMITS OF VM. CHECK THE MOOSE ATTRIBUTES BELOW TO SEE THE DEFAULTS, AND ADJUST YOUR MOOSE INSTANTIATION ACCORDINGLY

my $genotypes_search = CXGN::Genotype::Search->new({
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
    protocolprop_top_key_select=>['reference_genome_name', 'header_information_lines', 'marker_names', 'markers'], #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
    protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'], #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
    return_only_first_genotypeprop_for_stock=>0, #THIS IS TO CONSERVE MEMORY USAGE
    limit=>$limit,
    offset=>$offset,
    forbid_cache=>$forbid_cache
    # marker_search_hash_list=>[{'S80_265728' => {'pos' => '265728', 'chrom' => '1'}}], NOT IMPLEMENTED
    # marker_score_search_hash_list=>[{'S80_265728' => {'GT' => '0/0', 'GQ' => '99'}}], NOT IMPLEMENTED
});
# my ($total_count, $genotypes) = $genotypes_search->get_genotype_info();

# RECOMMENDED
If you just want to get a file with the genotype result in a dosage matrix or VCF file, use get_cached_file_dosage_matrix or get_cached_file_VCF functions instead.
If you want results in json format use get_cached_file_search_json
If you want results in json format for only the metadata (no genotype call data), use get_cached_file_search_json()

=head1 DESCRIPTION


=head1 AUTHORS

 Nicolas Morales <nm529@cornell.edu>
 With code moved from CXGN::BreederSearch
 Lukas Mueller <lam87@cornell.edu>
 Aimin Yan <ay247@cornell.edu>

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
use CXGN::Genotype::ComputeHybridGenotype;
use Cache::File;
use Digest::MD5 qw | md5_hex |;
use File::Slurp qw | write_file |;
use File::Temp qw | tempfile |;
use File::Copy;
use POSIX;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'people_schema' => (
    isa => 'CXGN::People::Schema',
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
    default => 0
);

# When using the get_cached_file_dosage_matrix or get_cached_file_VCF functions, need the following three keys.
has 'cache_root' => (
    isa => 'Str',
    is => 'rw',
);

has 'cache' => (
    isa => 'Cache::File',
    is => 'rw',
);

has 'cache_expiry' => (
    isa => 'Int',
    is => 'rw',
    default => 0, # never expires?
);

has 'forbid_cache' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

has 'prevent_transpose' => (
    isa => 'Bool',
    is => 'ro',
    default => 0
);

has '_iterator_query_handle' => (
    isa => 'Ref',
    is => 'rw'
);

has '_iterator_genotypeprop_query_handle' => (
    isa => 'Ref',
    is => 'rw'
);

has '_filtered_markers' => (
    isa => 'HashRef',
    is => 'rw',
    default => sub {{}}
);

has '_snp_genotyping_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_vcf_snp_genotyping_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_vcf_map_details_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_vcf_map_details_markers_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_vcf_map_details_markers_array_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_igd_genotypeprop_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_accession_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_tissue_sample_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_plot_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_plant_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_tissue_sample_of_cvterm_id' => (
    isa => 'Int',
    is => 'rw'
);

has '_protocolprop_markers_h' => (
    isa => 'Ref',
    is => 'rw'
);

has '_protocolprop_top_key_h' => (
    isa => 'Ref',
    is => 'rw'
);

has '_protocolprop_top_key_markers_h' => (
    isa => 'Ref',
    is => 'rw'
);

has '_protocolprop_top_key_markers_array_h' => (
    isa => 'Ref',
    is => 'rw'
);

has '_genotypeprop_h' => (
    isa => 'Ref',
    is => 'rw'
);

has '_protocolprop_marker_hash_select_arr' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has '_protocolprop_top_key_select_arr' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has '_selected_protocol_marker_info' => (
    isa => 'Ref',
    is => 'rw'
);

has '_selected_protocol_top_key_info' => (
    isa => 'Ref',
    is => 'rw'
);

has '_genotypeprop_infos' => (
    isa => 'ArrayRef',
    is => 'rw'
);

has '_genotypeprop_infos_counter' => (
    isa => 'Int',
    is => 'rw'
);

has '_genotypeprop_hash_select_arr' => (
    isa => 'ArrayRef',
    is => 'rw'
);

#NOT IMPLEMENTED
has 'marker_search_hash_list' => (
    isa => 'ArrayRef[HashRef]|Undef',
    is => 'ro',
);

#NOT IMPLEMENTED
has 'marker_score_search_hash_list' => (
    isa => 'ArrayRef[HashRef]|Undef',
    is => 'ro',
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw',
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw',
);

=head2 get_genotype_info

returns: an array with genotype information

=cut

=head2 get_genotype_info()

Function for getting genotype data iteratively.
Should be used like:

my $genotype_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    etc...
});
my ($count, $genotype_data) = $genotype_search->get_genotype_info();

If you want to get results iteratively, use the init and iterator function defined below instead. Iterative retrieval minimizes memory load.

If you just want to get a file with the genotype result in a dosage matrix or VCF file, use get_cached_file_dosage_matrix or get_cached_file_VCF functions instead.
If you want results in json format use get_cached_file_search_json
If you want results in json format for only the metadata (no genotype call data), use get_cached_file_search_json()

=cut

sub get_genotype_info {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_list = $self->trial_list;
    my $genotype_data_project_list = $self->genotype_data_project_list;
    my $protocol_id_list = $self->protocol_id_list;
    my $markerprofile_id_list = $self->markerprofile_id_list;
    my $accession_list = $self->accession_list;
    my $tissue_sample_list = $self->tissue_sample_list;
    my $marker_name_list = $self->marker_name_list;
    my $chromosome_list = $self->chromosome_list;
    my $start_position = $self->start_position;
    my $end_position = $self->end_position;
    my $genotypeprop_hash_select = $self->genotypeprop_hash_select;
    my $protocolprop_top_key_select = $self->protocolprop_top_key_select;
    my $protocolprop_marker_hash_select = $self->protocolprop_marker_hash_select;
    my $marker_search_hash_list = $self->marker_search_hash_list;
    my $marker_score_search_hash_list = $self->marker_score_search_hash_list;
    my $return_only_first_genotypeprop_for_stock = $self->return_only_first_genotypeprop_for_stock;
    my $limit = $self->limit;
    my $offset = $self->offset;
    my @data;
    my %search_params;
    my @where_clause;

    my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    my $vcf_snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details_markers', 'protocol_property')->cvterm_id();
    my $vcf_map_details_markers_array_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details_markers_array', 'protocol_property')->cvterm_id();
    my $igd_genotypeprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'igd number', 'genotype_property')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample', 'stock_type')->cvterm_id();
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

    my @trials_accessions;
    foreach (@$trial_list){
        my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$_});
        my $accessions = $trial->get_accessions();
        foreach (@$accessions){
            push @trials_accessions, $_->{stock_id};
        }
    }

    #If accessions are explicitly given, then accessions found from trials will not be added to the search.
    if (!$accession_list || scalar(@$accession_list)==0) {
        push @$accession_list, @trials_accessions;
    }

    #For projects inserted into database during the addition of genotypes and genotypeprops
    if (scalar(@trials_accessions)==0){
        if ($trial_list && scalar(@$trial_list)>0) {
            my $trial_sql = join ("," , @$trial_list);
            push @where_clause, "project.project_id in ($trial_sql)";
        }
    }

    #For genotyping_data_project
    if ($genotype_data_project_list && scalar($genotype_data_project_list)>0) {
        my $sql = join ("," , @$genotype_data_project_list);
        push @where_clause, "project.project_id in ($sql)";
    }
    if ($protocol_id_list && scalar(@$protocol_id_list)>0) {
        my $protocol_sql = join ("," , @$protocol_id_list);
        push @where_clause, "nd_protocol.nd_protocol_id in ($protocol_sql)";
    }
    if ($accession_list && scalar(@$accession_list)>0) {
        my $accession_sql = join ("," , @$accession_list);
        push @where_clause, " ( stock.stock_id in ($accession_sql) OR (accession_of_tissue_sample.stock_id in ($accession_sql) AND accession_of_tissue_sample.type_id = $accession_cvterm_id) ) ";
        push @where_clause, "stock.type_id in ($accession_cvterm_id, $tissue_sample_cvterm_id)";
    }
    if ($tissue_sample_list && scalar(@$tissue_sample_list)>0) {
        my $stock_sql = join ("," , @$tissue_sample_list);
        push @where_clause, "stock.stock_id in ($stock_sql)";
        push @where_clause, "stock.type_id = $tissue_sample_cvterm_id";
    }
    if ($markerprofile_id_list && scalar(@$markerprofile_id_list)>0) {
        my $markerprofile_sql = join ("," , @$markerprofile_id_list);
        push @where_clause, "genotype.genotype_id in ($markerprofile_sql)";
    }
    if ($marker_name_list && scalar(@$marker_name_list)>0) {
        my $search_vals_sql = "'".join ("','" , @$marker_name_list)."'";
        push @where_clause, "nd_protocolprop.value->'marker_names' \\?& array[$search_vals_sql]";
    }
    if ($marker_search_hash_list && scalar(@$marker_search_hash_list)>0) {
        foreach (@$marker_search_hash_list){
            my $json_val = encode_json $_;
            push @where_clause, "nd_protocolprop.value->'markers' \\@> $json_val"."::jsonb";
        }
    }
    if ($marker_score_search_hash_list && scalar(@$marker_score_search_hash_list)>0) {
        foreach (@$marker_score_search_hash_list){
            my $json_val = encode_json $_;
            push @where_clause, "genotype_values.value \\@> $json_val"."::jsonb";
        }
    }

    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $offset_clause = '';
    my $limit_clause = '';
    if ($limit){
        $limit_clause = " LIMIT $limit ";
    }
    if ($offset){
        $offset_clause = " OFFSET $offset ";
    }

    my $stock_select = '';
    if ($return_only_first_genotypeprop_for_stock) {
        $stock_select = 'distinct on (stock.stock_id) stock.stock_id';
    } else {
        $stock_select = 'stock.stock_id';
    }

    my $q = "SELECT $stock_select, igd_number_genotypeprop.value, nd_protocol.nd_protocol_id, nd_protocol.name, stock.uniquename, stock.type_id, stock_cvterm.name, genotype.genotype_id, genotype.uniquename, genotype.description, project.project_id, project.name, project.description, accession_of_tissue_sample.stock_id, accession_of_tissue_sample.uniquename, count(genotype.genotype_id) OVER() AS full_count
        FROM stock
        JOIN cvterm AS stock_cvterm ON(stock.type_id = stock_cvterm.cvterm_id)
        LEFT JOIN stock_relationship ON(stock_relationship.subject_id=stock.stock_id AND stock_relationship.type_id = $tissue_sample_of_cvterm_id)
        LEFT JOIN stock AS accession_of_tissue_sample ON(stock_relationship.object_id=accession_of_tissue_sample.stock_id)
        JOIN nd_experiment_stock ON(stock.stock_id=nd_experiment_stock.stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_protocol USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        JOIN nd_experiment_genotype USING(nd_experiment_id)
        JOIN nd_protocol USING(nd_protocol_id)
        LEFT JOIN nd_protocolprop ON(nd_protocolprop.nd_protocol_id = nd_protocol.nd_protocol_id AND nd_protocolprop.type_id = $vcf_map_details_cvterm_id)
        JOIN genotype USING(genotype_id)
        LEFT JOIN genotypeprop AS igd_number_genotypeprop ON(igd_number_genotypeprop.genotype_id = genotype.genotype_id AND igd_number_genotypeprop.type_id = $igd_genotypeprop_cvterm_id)
        JOIN project USING(project_id)
        $where_clause
        ORDER BY stock.stock_id, genotype.genotype_id ASC
        $limit_clause
        $offset_clause;";

    #print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my $total_count = 0;
    my @genotype_id_array;
    my @genotypeprop_array;
    my %genotype_hash;
    my %genotypeprop_hash;
    my %protocolprop_hash;
    while (my ($stock_id, $igd_number_json, $protocol_id, $protocol_name, $stock_name, $stock_type_id, $stock_type_name, $genotype_id, $genotype_uniquename, $genotype_description, $project_id, $project_name, $project_description, $accession_id, $accession_uniquename, $full_count) = $h->fetchrow_array()) {
        my $igd_number_hash = $igd_number_json ? decode_json $igd_number_json : undef;
        my $igd_number = $igd_number_hash ? $igd_number_hash->{'igd number'} : undef;
        $igd_number = !$igd_number && $igd_number_hash ? $igd_number_hash->{'igd_number'} : undef;

        my $germplasmName = '';
        my $germplasmDbId = '';
        if ($stock_type_name eq 'accession'){
            $germplasmName = $stock_name;
            $germplasmDbId = $stock_id;
        }
        if ($stock_type_name eq 'tissue_sample'){
            $germplasmName = $accession_uniquename;
            $germplasmDbId = $accession_id;
        }

        my $stock_object = CXGN::Stock::Accession->new({schema=>$self->bcs_schema, stock_id=>$germplasmDbId});

        push @genotype_id_array, $genotype_id;

        $genotype_hash{$genotype_id} = {
            markerProfileDbId => $genotype_id,
            germplasmDbId => $germplasmDbId,
            germplasmName => $germplasmName,
            synonyms => $stock_object->synonyms,
            stock_id => $stock_id,
            stock_name => $stock_name,
            stock_type_id => $stock_type_id,
            stock_type_name => $stock_type_name,
            genotypeDbId => $genotype_id,
            genotypeUniquename => $genotype_uniquename,
            genotypeDescription => $genotype_description,
            analysisMethodDbId => $protocol_id,
            analysisMethod => $protocol_name,
            genotypingDataProjectDbId => $project_id,
            genotypingDataProjectName => $project_name,
            genotypingDataProjectDescription => $project_description,
            igd_number => $igd_number,
        };
        $protocolprop_hash{$protocol_id}++;
        $total_count = $full_count;
    }
    print STDERR "CXGN::Genotype::Search has genotype_ids $total_count\n";

    my @found_protocolprop_ids = keys %protocolprop_hash;
    my @protocolprop_marker_hash_select_arr;
    foreach (@$protocolprop_marker_hash_select){
        push @protocolprop_marker_hash_select_arr, "s.value->>'$_'";
    }
    my @protocolprop_top_key_select_arr;
    my %protocolprop_top_key_select_hash;
    foreach (@$protocolprop_top_key_select){
        if ($_ ne 'markers' && $_ ne 'markers_array') {
            push @protocolprop_top_key_select_arr, "value->>'$_'";
        }
        $protocolprop_top_key_select_hash{$_}++;
    }
    my %selected_protocol_marker_info;
    my %selected_protocol_top_key_info;
    my %filtered_markers;
    my $genotypeprop_chromosome_rank_string = '';
    if (scalar(@found_protocolprop_ids)>0){
        my $protocolprop_id_sql = join ("," , @found_protocolprop_ids);
        my $protocolprop_where_sql = "nd_protocol_id in ($protocolprop_id_sql) and type_id = $vcf_map_details_cvterm_id";
        my $protocolprop_where_markers_sql = "nd_protocol_id in ($protocolprop_id_sql) and type_id = $vcf_map_details_markers_cvterm_id";
        my $protocolprop_where_markers_array_sql = "nd_protocol_id in ($protocolprop_id_sql) and type_id = $vcf_map_details_markers_array_cvterm_id";
        my $protocolprop_hash_select_sql = scalar(@protocolprop_marker_hash_select_arr) > 0 ? ', '.join ',', @protocolprop_marker_hash_select_arr : '';

        my $chromosome_where = '';
        if ($chromosome_list && scalar(@$chromosome_list)>0) {
            my $chromosome_list_sql = '\'' . join('\', \'', @$chromosome_list) . '\'';
            $chromosome_where = " AND (s.value->>'chrom')::text IN ($chromosome_list_sql)";
            #$genotypeprop_chromosome_rank_string = " AND value->>'CHROM' IN ($chromosome_list_sql) ";
        }
        my $start_position_where = '';
        if (defined($start_position)) {
            $start_position_where = " AND (s.value->>'pos')::int >= $start_position";
        }
        my $end_position_where = '';
        if (defined($end_position)) {
            $end_position_where = " AND (s.value->>'pos')::int <= $end_position";
        }

        my $protocolprop_q = "SELECT nd_protocol_id, s.key $protocolprop_hash_select_sql
            FROM nd_protocolprop, jsonb_each(nd_protocolprop.value) as s
            WHERE $protocolprop_where_markers_sql $chromosome_where $start_position_where $end_position_where;";

        my $protocolprop_h = $schema->storage->dbh()->prepare($protocolprop_q);
        $protocolprop_h->execute();
        while (my ($protocol_id, $marker_name, @protocolprop_info_return) = $protocolprop_h->fetchrow_array()) {
            for my $s (0 .. scalar(@protocolprop_marker_hash_select_arr)-1){
                $selected_protocol_marker_info{$protocol_id}->{$marker_name}->{$protocolprop_marker_hash_select->[$s]} = $protocolprop_info_return[$s];
            }
            $filtered_markers{$marker_name}++;
        }
        my $protocolprop_top_key_select_sql = scalar(@protocolprop_top_key_select_arr) > 0 ? ', '.join ',', @protocolprop_top_key_select_arr : '';
        my $protocolprop_top_key_q = "SELECT nd_protocol_id $protocolprop_top_key_select_sql from nd_protocolprop WHERE $protocolprop_where_sql;";
        my $protocolprop_top_key_h = $schema->storage->dbh()->prepare($protocolprop_top_key_q);
        $protocolprop_top_key_h->execute();
        while (my ($protocol_id, @protocolprop_top_key_return) = $protocolprop_top_key_h->fetchrow_array()) {
            for my $s (0 .. scalar(@protocolprop_top_key_select_arr)-1){
                my $protocolprop_i = $protocolprop_top_key_select->[$s];
                my $val;
                if ($protocolprop_i eq 'header_information_lines' || $protocolprop_i eq 'marker_names') {
                    $val = decode_json $protocolprop_top_key_return[$s];
                } else {
                    $val = $protocolprop_top_key_return[$s];
                }
                $selected_protocol_top_key_info{$protocol_id}->{$protocolprop_i} = $val;
            }
        }
        if (exists($protocolprop_top_key_select_hash{'markers'})) {
            my $protocolprop_top_key_q = "SELECT nd_protocol_id, value from nd_protocolprop WHERE $protocolprop_where_markers_sql;";
            my $protocolprop_top_key_h = $schema->storage->dbh()->prepare($protocolprop_top_key_q);
            $protocolprop_top_key_h->execute();
            while (my ($protocol_id, $markers_value) = $protocolprop_top_key_h->fetchrow_array()) {
                $selected_protocol_top_key_info{$protocol_id}->{'markers'} = decode_json $markers_value;
            }
        }
        if (exists($protocolprop_top_key_select_hash{'markers_array'})) {
            my $protocolprop_top_key_q = "SELECT nd_protocol_id, value from nd_protocolprop WHERE $protocolprop_where_markers_array_sql;";
            my $protocolprop_top_key_h = $schema->storage->dbh()->prepare($protocolprop_top_key_q);
            $protocolprop_top_key_h->execute();
            while (my ($protocol_id, $markers_value) = $protocolprop_top_key_h->fetchrow_array()) {
                $selected_protocol_top_key_info{$protocol_id}->{'markers_array'} = decode_json $markers_value;
            }
        }
    }

    my @genotypeprop_hash_select_arr;
    foreach (@$genotypeprop_hash_select){
        push @genotypeprop_hash_select_arr, "s.value->>'$_'";
    }
    if (scalar(@genotype_id_array)>0) {
        my $genotypeprop_id_sql = join ("," , @genotype_id_array);
        my $genotypeprop_hash_select_sql = scalar(@genotypeprop_hash_select_arr) > 0 ? ', '.join ',', @genotypeprop_hash_select_arr : '';

        my $filtered_markers_sql = '';
        if (scalar(keys %filtered_markers) >0 && scalar(keys %filtered_markers) < 10000) {
            $filtered_markers_sql = " AND s.key IN ('". join ("','", keys %filtered_markers) ."')";
        }

        my $q2 = "SELECT genotypeprop_id
            FROM genotypeprop WHERE genotype_id = ? AND type_id=$vcf_snp_genotyping_cvterm_id $genotypeprop_chromosome_rank_string;";
        my $h2 = $schema->storage->dbh()->prepare($q2);

        my $genotypeprop_q = "SELECT s.key $genotypeprop_hash_select_sql
            FROM genotypeprop, jsonb_each(genotypeprop.value) as s
            WHERE genotypeprop_id = ? AND s.key != 'CHROM' AND type_id = $vcf_snp_genotyping_cvterm_id $filtered_markers_sql;";
        my $genotypeprop_h = $schema->storage->dbh()->prepare($genotypeprop_q);

        foreach my $genotype_id (@genotype_id_array){
            $h2->execute($genotype_id);
            while (my ($genotypeprop_id) = $h2->fetchrow_array()) {
                $genotypeprop_h->execute($genotypeprop_id);
                while (my ($marker_name, @genotypeprop_info_return) = $genotypeprop_h->fetchrow_array()) {
                    for my $s (0 .. scalar(@genotypeprop_hash_select_arr)-1){
                        $genotype_hash{$genotype_id}->{selected_genotype_hash}->{$marker_name}->{$genotypeprop_hash_select->[$s]} = $genotypeprop_info_return[$s];
                    }
                }
            }
        }
    }

    foreach (@genotype_id_array) {
        my $info = $genotype_hash{$_};
        my $selected_marker_info = $selected_protocol_marker_info{$info->{analysisMethodDbId}} ? $selected_protocol_marker_info{$info->{analysisMethodDbId}} : {};
        my $selected_protocol_info = $selected_protocol_top_key_info{$info->{analysisMethodDbId}} ? $selected_protocol_top_key_info{$info->{analysisMethodDbId}} : {};
        my @all_protocol_marker_names = keys %$selected_marker_info;
        $selected_protocol_info->{markers} = $selected_marker_info;
        $info->{resultCount} = scalar(keys %{$info->{selected_genotype_hash}});
        $info->{all_protocol_marker_names} = \@all_protocol_marker_names;
        $info->{selected_protocol_hash} = $selected_protocol_info;
        push @data, $info;
    }

    #print STDERR Dumper \@data;
    return ($total_count, \@data);
}

=head2 init_genotype_iterator()

Function for initiating genotype search query and then used to get genotype data iteratively. Iterative search retrieval minimizes memory usage.
Should be used like:

my $genotype_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    etc...
});
$genotype_search->init_genotype_iterator();
while (my ($count, $genotype_data) = $genotype_search->get_next_genotype_info) {
    #Do something with genotype data
}

If you just want to get a file with the genotype result in a dosage matrix or VCF file, use get_cached_file_dosage_matrix or get_cached_file_VCF functions instead.
If you want results in json format use get_cached_file_search_json
If you want results in json format for only the metadata (no genotype call data), use get_cached_file_search_json()

=cut

sub init_genotype_iterator {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_list = $self->trial_list;
    my $genotype_data_project_list = $self->genotype_data_project_list;
    my $protocol_id_list = $self->protocol_id_list;
    my $markerprofile_id_list = $self->markerprofile_id_list;
    my $accession_list = $self->accession_list;
    my $tissue_sample_list = $self->tissue_sample_list;
    my $marker_name_list = $self->marker_name_list;
    my $chromosome_list = $self->chromosome_list;
    my $start_position = $self->start_position;
    my $end_position = $self->end_position;
    my $genotypeprop_hash_select = $self->genotypeprop_hash_select;
    my $protocolprop_top_key_select = $self->protocolprop_top_key_select;
    my $protocolprop_marker_hash_select = $self->protocolprop_marker_hash_select;
    my $marker_search_hash_list = $self->marker_search_hash_list;
    my $marker_score_search_hash_list = $self->marker_score_search_hash_list;
    my $return_only_first_genotypeprop_for_stock = $self->return_only_first_genotypeprop_for_stock;
    my $limit = $self->limit;
    my $offset = $self->offset;
    my @data;
    my %search_params;
    my @where_clause;

    my $snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'snp genotyping', 'genotype_property')->cvterm_id();
    $self->_snp_genotyping_cvterm_id($snp_genotyping_cvterm_id);
    my $vcf_snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
    $self->_vcf_snp_genotyping_cvterm_id($vcf_snp_genotyping_cvterm_id);
    my $vcf_map_details_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    $self->_vcf_map_details_cvterm_id($vcf_map_details_cvterm_id);
    my $vcf_map_details_markers_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details_markers', 'protocol_property')->cvterm_id();
    $self->_vcf_map_details_markers_cvterm_id($vcf_map_details_markers_cvterm_id);
    my $vcf_map_details_markers_array_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details_markers_array', 'protocol_property')->cvterm_id();
    $self->_vcf_map_details_markers_array_cvterm_id($vcf_map_details_markers_array_cvterm_id);
    my $igd_genotypeprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'igd number', 'genotype_property')->cvterm_id();
    $self->_igd_genotypeprop_cvterm_id($igd_genotypeprop_cvterm_id);
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
    $self->_accession_cvterm_id($accession_cvterm_id);
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample', 'stock_type')->cvterm_id();
    $self->_tissue_sample_cvterm_id($tissue_sample_cvterm_id);
    my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plot', 'stock_type')->cvterm_id();
    $self->_plot_cvterm_id($plot_cvterm_id);
    my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'plant', 'stock_type')->cvterm_id();
    $self->_plant_cvterm_id($plant_cvterm_id);
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    $self->_tissue_sample_of_cvterm_id($tissue_sample_of_cvterm_id);

    my @trials_accessions;
    foreach (@$trial_list){
        my $trial = CXGN::Trial->new({bcs_schema=>$schema, trial_id=>$_});
        my $accessions = $trial->get_accessions();
        foreach (@$accessions){
            push @trials_accessions, $_->{stock_id};
        }
    }

    #If accessions are explicitly given, then accessions found from trials will not be added to the search.
    if (!$accession_list || scalar(@$accession_list)==0) {
        push @$accession_list, @trials_accessions;
    }

    #For projects inserted into database during the addition of genotypes and genotypeprops
    if (scalar(@trials_accessions)==0){
        if ($trial_list && scalar(@$trial_list)>0) {
            my $trial_sql = join ("," , @$trial_list);
            push @where_clause, "project.project_id in ($trial_sql)";
        }
    }

    #For genotyping_data_project
    if ($genotype_data_project_list && scalar($genotype_data_project_list)>0) {
        my $sql = join ("," , @$genotype_data_project_list);
        push @where_clause, "project.project_id in ($sql)";
    }
    if ($protocol_id_list && scalar(@$protocol_id_list)>0) {
        my $protocol_sql = join ("," , @$protocol_id_list);
        push @where_clause, "nd_protocol.nd_protocol_id in ($protocol_sql)";
    }
    if ($accession_list && scalar(@$accession_list)>0) {
        my $accession_sql = join ("," , @$accession_list);
        push @where_clause, " ( stock.stock_id in ($accession_sql) OR (accession_of_tissue_sample.stock_id in ($accession_sql) AND accession_of_tissue_sample.type_id = $accession_cvterm_id) ) ";
        push @where_clause, "stock.type_id in ($accession_cvterm_id, $tissue_sample_cvterm_id)";
    }
    if ($tissue_sample_list && scalar(@$tissue_sample_list)>0) {
        my $stock_sql = join ("," , @$tissue_sample_list);
        push @where_clause, "stock.stock_id in ($stock_sql)";
        push @where_clause, "stock.type_id = $tissue_sample_cvterm_id";
    }
    if ($markerprofile_id_list && scalar(@$markerprofile_id_list)>0) {
        my $markerprofile_sql = join ("," , @$markerprofile_id_list);
        push @where_clause, "genotype.genotype_id in ($markerprofile_sql)";
    }
    my %filtered_markers;
    if ($marker_name_list && scalar(@$marker_name_list)>0) {
        my $search_vals_sql = "'".join ("','" , @$marker_name_list)."'";
        push @where_clause, "nd_protocolprop.value->'marker_names' \\?& array[$search_vals_sql]";

        foreach (@$marker_name_list) {
            $filtered_markers{$_}++;
        }
    }
    if ($marker_search_hash_list && scalar(@$marker_search_hash_list)>0) {
        foreach (@$marker_search_hash_list){
            my $json_val = encode_json $_;
            push @where_clause, "nd_protocolprop.value->'markers' \\@> $json_val"."::jsonb";
        }
    }
    if ($marker_score_search_hash_list && scalar(@$marker_score_search_hash_list)>0) {
        foreach (@$marker_score_search_hash_list){
            my $json_val = encode_json $_;
            push @where_clause, "genotype_values.value \\@> $json_val"."::jsonb";
        }
    }

    my $where_clause = scalar(@where_clause)>0 ? " WHERE " . (join (" AND " , @where_clause)) : '';

    my $offset_clause = '';
    my $limit_clause = '';
    if ($limit){
        $limit_clause = " LIMIT $limit ";
    }
    if ($offset){
        $offset_clause = " OFFSET $offset ";
    }

    my $stock_select = '';
    if ($return_only_first_genotypeprop_for_stock) {
        $stock_select = 'distinct on (stock.stock_id) stock.stock_id';
    } else {
        $stock_select = 'stock.stock_id';
    }

    # Setup protocolprop query handles
    my @protocolprop_marker_hash_select_arr;
    foreach (@$protocolprop_marker_hash_select){
        push @protocolprop_marker_hash_select_arr, "s.value->>'$_'";
    }
    $self->_protocolprop_marker_hash_select_arr(\@protocolprop_marker_hash_select_arr);

    my @protocolprop_top_key_select_arr;
    foreach (@$protocolprop_top_key_select){
        if ($_ ne 'markers' && $_ ne 'markers_array') {
            push @protocolprop_top_key_select_arr, "value->>'$_'";
        }
    }
    $self->_protocolprop_top_key_select_arr(\@protocolprop_top_key_select_arr);

    my $protocolprop_hash_select_sql = scalar(@protocolprop_marker_hash_select_arr) > 0 ? ', '.join ',', @protocolprop_marker_hash_select_arr : '';

    my $chromosome_where = '';
    my $genotypeprop_chromosome_rank_string = '';
    if ($chromosome_list && scalar(@$chromosome_list)>0) {
        my $chromosome_list_sql = '\'' . join('\', \'', @$chromosome_list) . '\'';
        $chromosome_where = " AND (s.value->>'chrom')::text IN ($chromosome_list_sql)";
        #$genotypeprop_chromosome_rank_string = " AND value->>'CHROM' IN ($chromosome_list_sql) ";
    }
    my $start_position_where = '';
    if (defined($start_position)) {
        $start_position_where = " AND (s.value->>'pos')::int >= $start_position";
    }
    my $end_position_where = '';
    if (defined($end_position)) {
        $end_position_where = " AND (s.value->>'pos')::int <= $end_position";
    }
    my $marker_name_list_where = '';
    if ($marker_name_list && scalar(@$marker_name_list)>0) {
        my $search_vals_sql = '\''.join ('\', \'' , @$marker_name_list).'\'';
        $marker_name_list_where = "AND (s.value->>'name')::text IN ($search_vals_sql)";
    }

    my $protocolprop_q = "SELECT nd_protocol_id, s.key $protocolprop_hash_select_sql
        FROM nd_protocolprop, jsonb_each(nd_protocolprop.value) as s
        WHERE nd_protocol_id = ? AND type_id = $vcf_map_details_markers_cvterm_id $chromosome_where $start_position_where $end_position_where $marker_name_list_where;";
    #print STDERR Dumper $protocolprop_q;
    my $protocolprop_h = $schema->storage->dbh()->prepare($protocolprop_q);
    $self->_protocolprop_markers_h($protocolprop_h);

    my $protocolprop_top_key_select_sql = scalar(@protocolprop_top_key_select_arr) > 0 ? ', '.join ',', @protocolprop_top_key_select_arr : '';
    my $protocolprop_top_key_q = "SELECT nd_protocol_id $protocolprop_top_key_select_sql from nd_protocolprop WHERE nd_protocol_id = ? AND type_id = $vcf_map_details_cvterm_id;";
    my $protocolprop_top_key_h = $schema->storage->dbh()->prepare($protocolprop_top_key_q);
    $self->_protocolprop_top_key_h($protocolprop_top_key_h);

    my $protocolprop_top_key_markers_q = "SELECT nd_protocol_id, value from nd_protocolprop WHERE nd_protocol_id = ? AND type_id = $vcf_map_details_markers_cvterm_id;";
    my $protocolprop_top_key_markers_h = $schema->storage->dbh()->prepare($protocolprop_top_key_markers_q);
    $self->_protocolprop_top_key_markers_h($protocolprop_top_key_markers_h);

    my $protocolprop_top_key_markers_array_q = "SELECT nd_protocol_id, value from nd_protocolprop WHERE nd_protocol_id = ? AND type_id = $vcf_map_details_markers_array_cvterm_id;";
    my $protocolprop_top_key_markers_array_h = $schema->storage->dbh()->prepare($protocolprop_top_key_markers_array_q);
    $self->_protocolprop_top_key_markers_array_h($protocolprop_top_key_markers_array_h);

    my $q = "SELECT $stock_select, igd_number_genotypeprop.value, nd_protocol.nd_protocol_id, nd_protocol.name, stock.uniquename, stock.type_id, stock_cvterm.name, genotype.genotype_id, genotype.uniquename, genotype.description, project.project_id, project.name, project.description, accession_of_tissue_sample.stock_id, accession_of_tissue_sample.uniquename, count(genotype.genotype_id) OVER() AS full_count
        FROM stock
        JOIN cvterm AS stock_cvterm ON(stock.type_id = stock_cvterm.cvterm_id)
        LEFT JOIN stock_relationship ON(stock_relationship.subject_id=stock.stock_id AND stock_relationship.type_id = $tissue_sample_of_cvterm_id)
        LEFT JOIN stock AS accession_of_tissue_sample ON(stock_relationship.object_id=accession_of_tissue_sample.stock_id)
        JOIN nd_experiment_stock ON(stock.stock_id=nd_experiment_stock.stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_protocol USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        JOIN nd_experiment_genotype USING(nd_experiment_id)
        JOIN nd_protocol USING(nd_protocol_id)
        LEFT JOIN nd_protocolprop ON(nd_protocolprop.nd_protocol_id = nd_protocol.nd_protocol_id AND nd_protocolprop.type_id = $vcf_map_details_cvterm_id)
        JOIN genotype USING(genotype_id)
        LEFT JOIN genotypeprop AS igd_number_genotypeprop ON(igd_number_genotypeprop.genotype_id = genotype.genotype_id AND igd_number_genotypeprop.type_id = $igd_genotypeprop_cvterm_id)
        JOIN project USING(project_id)
        $where_clause
        ORDER BY stock.stock_id, genotype.genotype_id ASC
        $limit_clause
        $offset_clause;";

    print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my @genotypeprop_infos;
    my %seen_protocol_ids;
    while (my ($stock_id, $igd_number_json, $protocol_id, $protocol_name, $stock_name, $stock_type_id, $stock_type_name, $genotype_id, $genotype_uniquename, $genotype_description, $project_id, $project_name, $project_description, $accession_id, $accession_uniquename, $full_count) = $h->fetchrow_array()) {

        my $germplasmName = '';
        my $germplasmDbId = '';

        my $igd_number_hash = $igd_number_json ? decode_json $igd_number_json : undef;
        my $igd_number = $igd_number_hash ? $igd_number_hash->{'igd number'} : undef;
        $igd_number = !$igd_number && $igd_number_hash ? $igd_number_hash->{'igd_number'} : undef;

        if ($stock_type_name eq 'accession'){
            $germplasmName = $stock_name;
            $germplasmDbId = $stock_id;
        }
        if ($stock_type_name eq 'tissue_sample'){
            $germplasmName = $accession_uniquename;
            $germplasmDbId = $accession_id;
        }

        my $stock_object = CXGN::Stock::Accession->new({schema=>$self->bcs_schema, stock_id=>$germplasmDbId});

        my %genotypeprop_info = (
            markerProfileDbId => $genotype_id,
            germplasmDbId => $germplasmDbId,
            germplasmName => $germplasmName,
            synonyms => $stock_object->synonyms,
            stock_id => $stock_id,
            stock_name => $stock_name,
            stock_type_id => $stock_type_id,
            stock_type_name => $stock_type_name,
            genotypeDbId => $genotype_id,
            genotypeUniquename => $genotype_uniquename,
            genotypeDescription => $genotype_description,
            analysisMethodDbId => $protocol_id,
            analysisMethod => $protocol_name,
            genotypingDataProjectDbId => $project_id,
            genotypingDataProjectName => $project_name,
            genotypingDataProjectDescription => $project_description,
            igd_number => $igd_number,
            full_count => $full_count
        );
        $seen_protocol_ids{$protocol_id}++;
        push @genotypeprop_infos, \%genotypeprop_info;
    }
    $self->_genotypeprop_infos(\@genotypeprop_infos);
    $self->_genotypeprop_infos_counter(0);

    my @seen_protocol_ids = keys %seen_protocol_ids;
    my %protocolprop_top_key_select_hash = map {$_ => 1} @protocolprop_top_key_select_arr;
    my %selected_protocol_marker_info;
    my %selected_protocol_top_key_info;

    foreach my $protocol_id (@seen_protocol_ids){
        $protocolprop_h->execute($protocol_id);
        while (my ($protocol_id, $marker_name, @protocolprop_info_return) = $protocolprop_h->fetchrow_array()) {
            for my $s (0 .. scalar(@protocolprop_marker_hash_select_arr)-1){
                $selected_protocol_marker_info{$protocol_id}->{$marker_name}->{$protocolprop_marker_hash_select->[$s]} = $protocolprop_info_return[$s];
            }
            $filtered_markers{$marker_name}++;
        }

        $protocolprop_top_key_h->execute($protocol_id);
        while (my ($protocol_id, @protocolprop_top_key_return) = $protocolprop_top_key_h->fetchrow_array()) {
            for my $s (0 .. scalar(@protocolprop_top_key_select_arr)-1){
                my $protocolprop_i = $protocolprop_top_key_select->[$s];
                my $val;
                if ($protocolprop_i eq 'header_information_lines' || $protocolprop_i eq 'marker_names') {
                    $val = decode_json $protocolprop_top_key_return[$s];
                } else {
                    $val = $protocolprop_top_key_return[$s];
                }
                $selected_protocol_top_key_info{$protocol_id}->{$protocolprop_i} = $val;
            }
        }
        if (exists($protocolprop_top_key_select_hash{'markers'})) {
            $protocolprop_top_key_markers_h->execute($protocol_id);
            while (my ($protocol_id, $markers_value) = $protocolprop_top_key_markers_h->fetchrow_array()) {
                $selected_protocol_top_key_info{$protocol_id}->{'markers'} = decode_json $markers_value;
            }
        }
        if (exists($protocolprop_top_key_select_hash{'markers_array'})) {
            $protocolprop_top_key_markers_array_h->execute($protocol_id);
            while (my ($protocol_id, $markers_value) = $protocolprop_top_key_markers_array_h->fetchrow_array()) {
                $selected_protocol_top_key_info{$protocol_id}->{'markers_array'} = decode_json $markers_value;
            }
        }
    }
    $self->_selected_protocol_marker_info(\%selected_protocol_marker_info);
    $self->_selected_protocol_top_key_info(\%selected_protocol_top_key_info);
    $self->_filtered_markers(\%filtered_markers);

    # Setup genotypeprop query handle
    my @genotypeprop_hash_select_arr;
    foreach (@$genotypeprop_hash_select){
        push @genotypeprop_hash_select_arr, "s.value->>'$_'";
    }
    $self->_genotypeprop_hash_select_arr(\@genotypeprop_hash_select_arr);
    my $genotypeprop_hash_select_sql = scalar(@genotypeprop_hash_select_arr) > 0 ? ', '.join ',', @genotypeprop_hash_select_arr : '';

    my $filtered_markers_sql = '';
    # If filtered markers by providing a location range or chromosome these markers will be in %filered_markers, but we dont want to use this SQL if there are too many markers (>10000) )
    if (scalar(keys %filtered_markers) >0 && scalar(keys %filtered_markers) < 10000) {
        $filtered_markers_sql = " AND s.key IN ('". join ("','", keys %filtered_markers) ."')";
    }

    my $genotypeprop_q = "SELECT s.key $genotypeprop_hash_select_sql
        FROM genotypeprop, jsonb_each(genotypeprop.value) as s
        WHERE genotypeprop_id = ? AND s.key != 'CHROM' AND type_id = $vcf_snp_genotyping_cvterm_id $filtered_markers_sql;";
    my $genotypeprop_h = $schema->storage->dbh()->prepare($genotypeprop_q);
    $self->_genotypeprop_h($genotypeprop_h);

    my $q2 = "SELECT genotypeprop_id
        FROM genotypeprop WHERE genotype_id = ? AND type_id=$vcf_snp_genotyping_cvterm_id $genotypeprop_chromosome_rank_string;";
    my $h2 = $schema->storage->dbh()->prepare($q2);
    $self->_iterator_genotypeprop_query_handle($h2);

    return;
}

=head2 get_next_genotype_info()

Function for getting genotype data iteratively. Iterative search retrieval minimizes memory usage.
Should be used like:

my $genotype_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    ...etc
});
$genotype_search->init_genotype_iterator();
while (my ($count, $genotype_data) = $genotype_search->get_next_genotype_info) {
    #Do something with genotype data
}

If you just want to get a file with the genotype result in a dosage matrix or VCF file, use get_cached_file_dosage_matrix or get_cached_file_VCF instead.
If you want results in json format use get_cached_file_search_json
If you want results in json format for only the metadata (no genotype call data), use get_cached_file_search_json()

=cut

sub get_next_genotype_info {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_list = $self->trial_list;
    my $genotype_data_project_list = $self->genotype_data_project_list;
    my $protocol_id_list = $self->protocol_id_list;
    my $markerprofile_id_list = $self->markerprofile_id_list;
    my $accession_list = $self->accession_list;
    my $tissue_sample_list = $self->tissue_sample_list;
    my $marker_name_list = $self->marker_name_list;
    my $chromosome_list = $self->chromosome_list;
    my $start_position = $self->start_position;
    my $end_position = $self->end_position;
    my $genotypeprop_hash_select = $self->genotypeprop_hash_select;
    my $protocolprop_top_key_select = $self->protocolprop_top_key_select;
    my $protocolprop_marker_hash_select = $self->protocolprop_marker_hash_select;
    my $marker_search_hash_list = $self->marker_search_hash_list;
    my $marker_score_search_hash_list = $self->marker_score_search_hash_list;
    my $return_only_first_genotypeprop_for_stock = $self->return_only_first_genotypeprop_for_stock;
    my $h = $self->_iterator_query_handle();
    my $h_genotypeprop = $self->_iterator_genotypeprop_query_handle();
    my $protocolprop_markers_h = $self->_protocolprop_markers_h();
    my $protocolprop_top_key_h = $self->_protocolprop_top_key_h();
    my $protocolprop_top_key_markers_h = $self->_protocolprop_top_key_markers_h();
    my $genotypeprop_h = $self->_genotypeprop_h();
    my $protocolprop_top_key_markers_array_h = $self->_protocolprop_top_key_markers_array_h();
    my $protocolprop_marker_hash_select_arr = $self->_protocolprop_marker_hash_select_arr();
    my $protocolprop_top_key_select_arr = $self->_protocolprop_top_key_select_arr();
    my $genotypeprop_hash_select_arr = $self->_genotypeprop_hash_select_arr();
    my $snp_genotyping_cvterm_id = $self->_snp_genotyping_cvterm_id();
    my $vcf_snp_genotyping_cvterm_id = $self->_vcf_snp_genotyping_cvterm_id();
    my $vcf_map_details_cvterm_id = $self->_vcf_map_details_cvterm_id();
    my $vcf_map_details_markers_cvterm_id = $self->_vcf_map_details_markers_cvterm_id();
    my $vcf_map_details_markers_array_cvterm_id = $self->_vcf_map_details_markers_array_cvterm_id();
    my $igd_genotypeprop_cvterm_id = $self->_igd_genotypeprop_cvterm_id();
    my $accession_cvterm_id = $self->_accession_cvterm_id();
    my $tissue_sample_cvterm_id = $self->_tissue_sample_cvterm_id();
    my $tissue_sample_of_cvterm_id = $self->_tissue_sample_of_cvterm_id();


    my $total_count = 0;
    my @genotypeprop_array;
    my %protocolprop_hash;

    my %selected_protocol_marker_info = %{$self->_selected_protocol_marker_info};
    my %selected_protocol_top_key_info = %{$self->_selected_protocol_top_key_info};
    my %filtered_markers = %{$self->_filtered_markers};
    my $genotypeprop_infos = $self->_genotypeprop_infos;
    my $genotypeprop_infos_counter = $self->_genotypeprop_infos_counter;

    if ($genotypeprop_infos->[$genotypeprop_infos_counter]) {
        my %genotypeprop_info = %{$genotypeprop_infos->[$genotypeprop_infos_counter]};
        my $genotype_id = $genotypeprop_info{markerProfileDbId};
        my $protocol_id = $genotypeprop_info{analysisMethodDbId};
        my $full_count = $genotypeprop_info{full_count};

        $h_genotypeprop->execute($genotype_id);
        while (my ($genotypeprop_id) = $h_genotypeprop->fetchrow_array) {
            $genotypeprop_h->execute($genotypeprop_id);
            while (my ($marker_name, @genotypeprop_info_return) = $genotypeprop_h->fetchrow_array()) {
                for my $s (0 .. scalar(@$genotypeprop_hash_select_arr)-1){
                    $genotypeprop_info{selected_genotype_hash}->{$marker_name}->{$genotypeprop_hash_select->[$s]} = $genotypeprop_info_return[$s];
                }
            }

        }
        my $selected_marker_info = $selected_protocol_marker_info{$protocol_id} ? $selected_protocol_marker_info{$protocol_id} : {};
        my $selected_protocol_info = $selected_protocol_top_key_info{$protocol_id} ? $selected_protocol_top_key_info{$protocol_id} : {};
        my @all_protocol_marker_names = keys %$selected_marker_info;
        $selected_protocol_info->{markers} = $selected_marker_info;
        $genotypeprop_info{resultCount} = scalar(keys %{$genotypeprop_info{selected_genotype_hash}});
        $genotypeprop_info{all_protocol_marker_names} = \@all_protocol_marker_names;
        $genotypeprop_info{selected_protocol_hash} = $selected_protocol_info;

        $self->_genotypeprop_infos_counter($self->_genotypeprop_infos_counter + 1);

        return ($full_count, \%genotypeprop_info);
    }

    return;
}

sub key {
    my $self = shift;
    my $datatype = shift;

    #print STDERR Dumper($self->_get_dataref());
    my $json = JSON->new();
    #preserve order of hash keys to get same text
    $json = $json->canonical();
    my $accessions = $json->encode( $self->accession_list() || [] );
    my $tissues = $json->encode( $self->tissue_sample_list() || [] );
    my $trials = $json->encode( $self->trial_list() || [] );
    my $protocols = $json->encode( $self->protocol_id_list() || [] );
    my $markerprofiles = $json->encode( $self->markerprofile_id_list() || [] );
    my $genotypedataprojects = $json->encode( $self->genotype_data_project_list() || [] );
    my $markernames = $json->encode( $self->marker_name_list() || [] );
    my $genotypeprophash = $json->encode( $self->genotypeprop_hash_select() || [] );
    my $protocolprophash = $json->encode( $self->protocolprop_top_key_select() || [] );
    my $protocolpropmarkerhash = $json->encode( $self->protocolprop_marker_hash_select() || [] );
    my $chromosomes = $json->encode( $self->chromosome_list() || [] );
    my $start = $self->start_position() || '' ;
    my $end = $self->end_position() || '';
    my $prevent_transpose = $self->prevent_transpose() || '';
    my $key = md5_hex($accessions.$tissues.$trials.$protocols.$markerprofiles.$genotypedataprojects.$markernames.$genotypeprophash.$protocolprophash.$protocolpropmarkerhash.$chromosomes.$start.$end.$self->return_only_first_genotypeprop_for_stock().$prevent_transpose.$self->limit().$self->offset()."_$datatype");
    return $key;
}

=head2 get_cached_file_search_json()

Function for getting the file handle for the genotype search result from cache. Will write the cached file if it does not exist.
Returns the genotype result in a line-by-line json format.
Uses the file iterator to write the cached file, so that it uses little memory.

First line in file has all marker objects, while subsequent lines have markerprofiles for each sample
If you want results in json format for only the metadata (no genotype call data), pass 1 for metadata_only

=cut

sub get_cached_file_search_json {
    my $self = shift;
    my $shared_cluster_dir_config = shift;
    my $metadata_only = shift;
    my $protocol_ids = $self->protocol_id_list;

    my $metadata_only_string = $metadata_only ? "metadata_only" : "all_data";
    my $key = $self->key("get_cached_file_search_json_v03_".$metadata_only_string);
    $self->cache( Cache::File->new( cache_root => $self->cache_root() ));

    my $file_handle;
    if ($self->cache()->exists($key) && !$self->forbid_cache()) {
        $file_handle = $self->cache()->handle($key);
    }
    else {
        # Set the temp dir and temp output file
        my $tmp_output_dir = $shared_cluster_dir_config."/tmp_genotype_download_json";
        mkdir $tmp_output_dir if ! -d $tmp_output_dir;
        my ($tmp_fh, $tempfile) = tempfile(
            "wizard_download_XXXXX",
            DIR=> $tmp_output_dir,
        );

        my @all_marker_objects;
        foreach (@$protocol_ids) {
            my $protocol = CXGN::Genotype::Protocol->new({
                bcs_schema => $self->bcs_schema,
                nd_protocol_id => $_,
                chromosome_list=>$self->chromosome_list,
                start_position=>$self->start_position,
                end_position=>$self->end_position,
                marker_name_list=>$self->marker_name_list
            });
            my $markers = $protocol->markers;
            push @all_marker_objects, values %$markers;
        }

        foreach (@all_marker_objects) {
            $self->_filtered_markers()->{$_->{name}}++;
        }

        $self->init_genotype_iterator();

        #VCF should be sorted by chromosome and position
        no warnings 'uninitialized';
        @all_marker_objects = sort { $a->{chrom} cmp $b->{chrom} || $a->{pos} <=> $b->{pos} || $a->{name} cmp $b->{name} } @all_marker_objects;
        @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);

        my $counter = 0;
        while (my $geno = $self->get_next_genotype_info) {

            # OLD GENOTYPING PROTCOLS DID NOT HAVE ND_PROTOCOLPROP INFO...
            if (scalar(@all_marker_objects) == 0) {
                foreach my $o (sort genosort keys %{$geno->{selected_genotype_hash}}) {
                    push @all_marker_objects, {name => $o};
                }
                @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);
            }

            if ($metadata_only) {
                @all_marker_objects = [];
                delete $geno->{selected_genotype_hash};
                delete $geno->{selected_protocol_hash};
                delete $geno->{all_protocol_marker_names};
            }

            my $genotype_string = encode_json $geno;
            $genotype_string .= "\n";
            if ($counter == 0) {
                my $marker_string = encode_json \@all_marker_objects;
                $marker_string .= "\n";
                write_file($tempfile, {append => 1}, $marker_string);
            }
            write_file($tempfile, {append => 1}, $genotype_string);
            $counter++;
        }
        close $tempfile;

        open my $out_copy, '<', $tempfile or die "Can't open output file: $!";

        $self->cache()->set($key, '');
        $file_handle = $self->cache()->handle($key);
        copy($out_copy, $file_handle);

        close $out_copy;
        $file_handle = $self->cache()->handle($key);
    }
    return $file_handle;
}

=head2 get_cached_file_dosage_matrix()

Function for getting the file handle for the genotype search result from cache. Will write the cached file if it does not exist.
Returns the genotype result as a dosage matrix format.
Uses the file iterator to write the cached file, so that it uses little memory.

=cut

sub get_cached_file_dosage_matrix {
    my $self = shift;
    my $shared_cluster_dir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config = shift;
    my $protocol_ids = $self->protocol_id_list;

    my $key = $self->key("get_cached_file_dosage_matrix_v03");
    $self->cache( Cache::File->new( cache_root => $self->cache_root() ));

    my $file_handle;
    if ($self->cache()->exists($key) && !$self->forbid_cache()) {
        $file_handle = $self->cache()->handle($key);
    }
    else {
        # Set the temp dir and temp output file
        my $tmp_output_dir = $shared_cluster_dir_config."/tmp_genotype_download_dosage_matrix";
        mkdir $tmp_output_dir if ! -d $tmp_output_dir;
        my ($tmp_fh, $tempfile) = tempfile(
            "wizard_download_XXXXX",
            DIR=> $tmp_output_dir,
        );

        my @all_marker_objects;
        foreach (@$protocol_ids) {
            my $protocol = CXGN::Genotype::Protocol->new({
                bcs_schema => $self->bcs_schema,
                nd_protocol_id => $_,
                chromosome_list=>$self->chromosome_list,
                start_position=>$self->start_position,
                end_position=>$self->end_position,
                marker_name_list=>$self->marker_name_list
            });
            my $markers = $protocol->markers;
            push @all_marker_objects, values %$markers;
        }

        foreach (@all_marker_objects) {
            $self->_filtered_markers()->{$_->{name}}++;
        }
        $self->init_genotype_iterator();

        #VCF should be sorted by chromosome and position
        no warnings 'uninitialized';
        @all_marker_objects = sort { $a->{chrom} cmp $b->{chrom} || $a->{pos} <=> $b->{pos} || $a->{name} cmp $b->{name} } @all_marker_objects;
        @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);

        my $counter = 0;
        while (my $geno = $self->get_next_genotype_info) {

            # OLD GENOTYPING PROTCOLS DID NOT HAVE ND_PROTOCOLPROP INFO...
            if (scalar(@all_marker_objects) == 0) {
                foreach my $o (sort genosort keys %{$geno->{selected_genotype_hash}}) {
                    push @all_marker_objects, {name => $o};
                }
                @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);
            }

            my $genotype_string = "";
            if ($counter == 0) {
                $genotype_string .= "Marker\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $m->{name} . "\t";
                }
                $genotype_string .= "\n";
            }
            my $genotype_id = $geno->{germplasmName};
            if (!$self->return_only_first_genotypeprop_for_stock) {
                $genotype_id = $geno->{germplasmName}."|".$geno->{markerProfileDbId};
            }
            my $genotype_data_string = "";
            foreach my $m (@all_marker_objects) {
                my $current_genotype = $geno->{selected_genotype_hash}->{$m->{name}}->{DS};
                $genotype_data_string .= $current_genotype."\t";
            }

            $genotype_string .= $genotype_id."\t".$genotype_data_string."\n";

            write_file($tempfile, {append => 1}, $genotype_string);
            $counter++;
        }

        my $transpose_tempfile = $tempfile . "_transpose";

        my $cmd = CXGN::Tools::Run->new(
            {
                backend => $backend_config,
                submit_host => $cluster_host_config,
                temp_base => $tmp_output_dir,
                queue => $web_cluster_queue_config,
                do_cleanup => 0,
                out_file => $transpose_tempfile,
    #            out_file => $transpose_tempfile,
                # don't block and wait if the cluster looks full
                max_cluster_jobs => 1_000_000_000,
            }
        );

        my $out_copy;
        if ($self->prevent_transpose()) {
            open $out_copy, '<', $tempfile or die "Can't open output file: $!";
        }
        else {
            # Do the transposition job on the cluster
            $cmd->run_cluster(
                    "perl ",
                    $basepath_config."/bin/transpose_matrix.pl",
                    $tempfile,
            );
            $cmd->is_cluster(1);
            $cmd->wait;

            open $out_copy, '<', $transpose_tempfile or die "Can't open output file: $!";
        }

        $self->cache()->set($key, '');
        $file_handle = $self->cache()->handle($key);
        copy($out_copy, $file_handle);

        close $out_copy;
        $file_handle = $self->cache()->handle($key);
    }
    return $file_handle;
}

=head2 get_cached_file_dosage_matrix_compute_from_parents()
Computes the genotypes for the queried accessions computed from the parental dosages. Parents are known from pedigrees of accessions.
Function for getting the file handle for the genotype search result from cache. Will write the cached file if it does not exist.
Returns the genotype result as a dosage matrix format.
Uses the file iterator to write the cached file, so that it uses little memory.
=cut

sub get_cached_file_dosage_matrix_compute_from_parents {
    my $self = shift;
    my $shared_cluster_dir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config = shift;
    my $schema = $self->bcs_schema;
    my $protocol_ids = $self->protocol_id_list;
    my $marker_name_list = $self->marker_name_list;
    my $accession_ids = $self->accession_list;
    my $cache_root_dir = $self->cache_root();

    if (scalar(@$protocol_ids)>1) {
        die "Only one protocol at a time can be done when computing genotypes from parents\n";
    }
    my $protocol_id = $protocol_ids->[0];

    my $key = $self->key("get_cached_file_dosage_matrix_compute_from_parents_v03");
    $self->cache( Cache::File->new( cache_root => $cache_root_dir ));

    my $file_handle;
    if ($self->cache()->exists($key) && !$self->forbid_cache()) {
        $file_handle = $self->cache()->handle($key);
    }
    else {
        # Set the temp dir and temp output file
        my $tmp_output_dir = $shared_cluster_dir_config."/tmp_genotype_download_dosage_matrix_compute_from_parents";
        mkdir $tmp_output_dir if ! -d $tmp_output_dir;
        my ($tmp_fh, $tempfile) = tempfile(
            "wizard_download_XXXXX",
            DIR=> $tmp_output_dir,
        );

        my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
        my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

        my $accession_list_string = join ',', @$accession_ids;
        my $q = "SELECT accession.stock_id, female_parent.stock_id, male_parent.stock_id
            FROM stock AS accession
            JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
            JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
            JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
            JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
            WHERE accession.stock_id IN ($accession_list_string) AND accession.type_id=$accession_cvterm_id ORDER BY accession.stock_id;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute();
        my @accession_stock_ids_found = ();
        my @female_stock_ids_found = ();
        my @male_stock_ids_found = ();
        while (my ($accession_stock_id, $female_parent_stock_id, $male_parent_stock_id) = $h->fetchrow_array()) {
            push @accession_stock_ids_found, $accession_stock_id;
            push @female_stock_ids_found, $female_parent_stock_id;
            push @male_stock_ids_found, $male_parent_stock_id;
        }

        # print STDERR Dumper \@accession_stock_ids_found;
        # print STDERR Dumper \@female_stock_ids_found;
        # print STDERR Dumper \@male_stock_ids_found;

        my %unique_germplasm;
        my $protocol = CXGN::Genotype::Protocol->new({
            bcs_schema => $schema,
            nd_protocol_id => $protocol_id,
            chromosome_list=>$self->chromosome_list,
            start_position=>$self->start_position,
            end_position=>$self->end_position,
            marker_name_list=>$self->marker_name_list
        });
        my $markers = $protocol->markers;
        my @all_marker_objects = values %$markers;

        foreach (@all_marker_objects) {
            $self->_filtered_markers()->{$_->{name}}++;
        }

        no warnings 'uninitialized';
        @all_marker_objects = sort { $a->{chrom} cmp $b->{chrom} || $a->{pos} <=> $b->{pos} || $a->{name} cmp $b->{name} } @all_marker_objects;
        @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);

        my $counter = 0;
        for my $i (0..scalar(@accession_stock_ids_found)-1) {
            my $female_stock_id = $female_stock_ids_found[$i];
            my $male_stock_id = $male_stock_ids_found[$i];
            my $accession_stock_id = $accession_stock_ids_found[$i];

            my $dataset = CXGN::Dataset::Cache->new({
                people_schema=>$self->people_schema,
                schema=>$schema,
                cache_root=>$cache_root_dir,
                accessions=>[$female_stock_id, $male_stock_id]
            });
            my $genotypes = $dataset->retrieve_genotypes($protocol_id, ['DS'], ['markers'], ['name'], 1, $self->chromosome_list, $self->start_position, $self->end_position, $self->marker_name_list);

            # For old protocols with no protocolprop info...
            if (scalar(@all_marker_objects) == 0) {
                foreach my $o (sort genosort keys %{$genotypes->[0]->{selected_genotype_hash}}) {
                    push @all_marker_objects, {name => $o};
                }
                @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);
            }

            my $genotype_string = "";
            if ($counter == 0) {
                $genotype_string .= "Marker\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $m->{name} . "\t";
                }
                $genotype_string .= "\n";
            }

            my $geno = CXGN::Genotype::ComputeHybridGenotype->new({
                parental_genotypes=>$genotypes,
                marker_objects=>\@all_marker_objects
            });
            my $progeny_genotype = $geno->get_hybrid_genotype();
            my $genotype_string_scores = join "\t", @$progeny_genotype;

            my $genotype_id = $accession_stock_id;
            if (!$self->return_only_first_genotypeprop_for_stock) {
                $genotype_id = $accession_stock_id."|".$geno->{markerProfileDbId};
            }

            $genotype_string .= $genotype_id."\t".$genotype_string_scores."\n";
            write_file($tempfile, {append => 1}, $genotype_string);
            $counter++;
        }

        my $transpose_tempfile = $tempfile . "_transpose";

        my $cmd = CXGN::Tools::Run->new(
            {
                backend => $backend_config,
                submit_host => $cluster_host_config,
                temp_base => $tmp_output_dir,
                queue => $web_cluster_queue_config,
                do_cleanup => 0,
                out_file => $transpose_tempfile,
    #            out_file => $transpose_tempfile,
                # don't block and wait if the cluster looks full
                max_cluster_jobs => 1_000_000_000,
            }
        );

        my $out_copy;
        if ($self->prevent_transpose()) {
            open $out_copy, '<', $tempfile or die "Can't open output file: $!";
        }
        else {
            # Do the transposition job on the cluster
            $cmd->run_cluster(
                    "perl ",
                    $basepath_config."/bin/transpose_matrix.pl",
                    $tempfile,
            );
            $cmd->is_cluster(1);
            $cmd->wait;

            open $out_copy, '<', $transpose_tempfile or die "Can't open output file: $!";
        }

        $self->cache()->set($key, '');
        $file_handle = $self->cache()->handle($key);
        copy($out_copy, $file_handle);

        close $out_copy;
        $file_handle = $self->cache()->handle($key);
    }
    return $file_handle;
}

sub get_cached_file_VCF {
    my $self = shift;
    my $shared_cluster_dir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config = shift;

    my $key = $self->key("get_cached_file_VCF_v03");
    $self->cache( Cache::File->new( cache_root => $self->cache_root() ));
    my $protocol_ids = $self->protocol_id_list;

    my $file_handle;
    if ($self->cache()->exists($key) && !$self->forbid_cache()) {
        $file_handle = $self->cache()->handle($key);
    }
    else {
        # Set the temp dir and temp output file
        my $tmp_output_dir = $shared_cluster_dir_config."/tmp_genotype_download_VCF";
        mkdir $tmp_output_dir if ! -d $tmp_output_dir;
        my ($tmp_fh, $tempfile) = tempfile(
            "wizard_download_XXXXX",
            DIR=> $tmp_output_dir,
        );

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        my @all_protocol_info_lines;

        #Get all marker information for the protocol(s) requested. this is important if they are requesting subsets of markers or if they are querying more than one protocol at once. Also important for ordering VCF output. Old genotypes did not have protocolprop marker info so markers are taken from first genotypeprop return below.
        my @all_marker_objects;
        my %unique_germplasm;
        foreach (@$protocol_ids) {
            my $protocol = CXGN::Genotype::Protocol->new({
                bcs_schema => $self->bcs_schema,
                nd_protocol_id => $_,
                chromosome_list=>$self->chromosome_list,
                start_position=>$self->start_position,
                end_position=>$self->end_position,
                marker_name_list=>$self->marker_name_list
            });
            my $markers = $protocol->markers;
            push @all_protocol_info_lines, @{$protocol->header_information_lines};
            push @all_marker_objects, values %$markers;
        }
	push @all_protocol_info_lines, "##INFO=<ID=VCFDownload,Description='VCFv4.2 FILE GENERATED BY BREEDBASE AT ".$timestamp."'>";

        foreach (@all_marker_objects) {
            $self->_filtered_markers()->{$_->{name}}++;
        }

        $self->init_genotype_iterator();

        #VCF should be sorted by chromosome and position
        no warnings 'uninitialized';
        @all_marker_objects = sort { $a->{chrom} cmp $b->{chrom} || $a->{pos} <=> $b->{pos} || $a->{name} cmp $b->{name} } @all_marker_objects;
        @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);

        my $counter = 0;
        while (my $geno = $self->get_next_genotype_info) {

            # OLD GENOTYPING PROTCOLS DID NOT HAVE ND_PROTOCOLPROP INFO...
            if (scalar(@all_marker_objects) == 0) {
                foreach my $o (sort genosort keys %{$geno->{selected_genotype_hash}}) {
                    push @all_marker_objects, {name => $o};
                }
                @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);
            }

            $unique_germplasm{$geno->{germplasmDbId}}++;

            my $genotype_string = "";
            if ($counter == 0) {
                $genotype_string .= "#CHROM\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{chrom} . "\t";
                }
                $genotype_string .= "\n";
                $genotype_string .= "POS\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{pos} . "\t";
                }
                $genotype_string .= "\n";
                $genotype_string .= "ID\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $m->{name} . "\t";
                }
                $genotype_string .= "\n";
                $genotype_string .= "REF\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{ref} . "\t";
                }
                $genotype_string .= "\n";
                $genotype_string .= "ALT\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{alt} . "\t";
                }
                $genotype_string .= "\n";
                $genotype_string .= "QUAL\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{qual} . "\t";
                }
                $genotype_string .= "\n";
                $genotype_string .= "FILTER\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{filter} . "\t";
                }
                $genotype_string .= "\n";
                $genotype_string .= "INFO\t";
                foreach my $m (@all_marker_objects) {
                    $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{info} . "\t";
                }
                $genotype_string .= "\n";
                $genotype_string .= "FORMAT\t";
                foreach my $m (@all_marker_objects) {
                    my $format = $m->{format};
                    my @format_array;
                    #In case of old genotyping protocols where there was no protocolprop marker info
                    if (!$format) {
                        my $first_g = $geno->{selected_genotype_hash}->{$m->{name}};
                        foreach my $k (sort keys %$first_g) {
                            if (defined($first_g->{$k})) {
                                push @format_array, $k;
                            }
                        }
                    } else {
                        @format_array = split ':', $format;
                    }

                    if (scalar(@format_array) > 1) { #ONLY ADD NT FOR NOT OLD GENOTYPING PROTOCOLS
                        my %format_check = map {$_ => 1} @format_array;
                        if (!exists($format_check{'NT'})) {
                            push @format_array, 'NT';
                        }
                        if (!exists($format_check{'DS'})) {
                            push @format_array, 'DS';
                        }
                    }
                    $format = join ':', @format_array;
                    $genotype_string .= $format . "\t";
                    $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{format} = $format;
                    $m->{format} = $format;
                }
                $genotype_string .= "\n";
            }
            my $genotype_id = $geno->{germplasmName};
            if (!$self->return_only_first_genotypeprop_for_stock) {
                $genotype_id = $geno->{germplasmName}."|".$geno->{markerProfileDbId};
            }
            my $genotype_data_string = "";
            foreach my $m (@all_marker_objects) {
                my @current_geno = ();
                my $name = $m->{name};
                my $format = $m->{format};
                my @format;

                #In case of old genotyping protocols where there was no protocolprop marker info
                if (!$format) {
                    my $first_g = $geno->{selected_genotype_hash}->{$name};
                    foreach my $k (sort keys %$first_g) {
                        if (defined($first_g->{$k})) {
                            push @format, $k;
                        }
                    }
                } else {
                    @format = split ':', $format;
                }

                foreach my $format_key (@format) {
                    push @current_geno, $geno->{selected_genotype_hash}->{$m->{name}}->{$format_key};
                }
                my $current_g = join ':', @current_geno;
                $genotype_data_string .= $current_g."\t";
            }
            $genotype_string .= $genotype_id."\t".$genotype_data_string."\n";

            write_file($tempfile, {append => 1}, $genotype_string);
            $counter++;
        }

        my $transpose_tempfile = $tempfile . "_transpose";

        my $cmd = CXGN::Tools::Run->new(
            {
                backend => $backend_config,
                submit_host => $cluster_host_config,
                temp_base => $tmp_output_dir,
                queue => $web_cluster_queue_config,
                do_cleanup => 0,
                out_file => $transpose_tempfile,
    #            out_file => $transpose_tempfile,
                # don't block and wait if the cluster looks full
                max_cluster_jobs => 1_000_000_000,
            }
        );

        # Do the transposition job on the cluster
        $cmd->run_cluster(
                "perl ",
                $basepath_config."/bin/transpose_matrix.pl",
                $tempfile,
        );
        $cmd->is_cluster(1);
        $cmd->wait;

        my $transpose_tempfile_hdr = $tempfile . "_transpose_hdr";

        open my $in,  '<',  $transpose_tempfile or die "Can't read input file: $!";
        open my $out, '>', $transpose_tempfile_hdr or die "Can't write output file: $!";

        #Get synonyms of the accessions
        my $stocklookup = CXGN::Stock::StockLookup->new({schema => $self->bcs_schema});
        my @accession_ids = keys %unique_germplasm;
        my $synonym_hash = $stocklookup->get_stock_synonyms('stock_id', 'accession', \@accession_ids);
        my $synonym_string = "##SynonymsOfAccessions=\"";
        while( my( $uniquename, $synonym_list ) = each %{$synonym_hash}){
            if(scalar(@{$synonym_list})>0){
                if(not length($synonym_string)<1){
                    $synonym_string.=" ";
                }
                $synonym_string.=$uniquename."=(";
                $synonym_string.= (join ", ", @{$synonym_list}).")";
            }
        }
	$synonym_string .= "\"";
        push @all_protocol_info_lines, $synonym_string;

        my $vcf_header = join "\n", @all_protocol_info_lines;
        $vcf_header .= "\n";

        print $out $vcf_header;

        while( <$in> )
            {
            print $out $_;
            }
        close $in;
        close $out;

        open my $out_copy, '<', $transpose_tempfile_hdr or die "Can't open output file: $!";

        $self->cache()->set($key, '');
        $file_handle = $self->cache()->handle($key);
        copy($out_copy, $file_handle);

        close $out_copy;
        $file_handle = $self->cache()->handle($key);
    }
    return $file_handle;
}

=head2 get_cached_file_VCF_compute_from_parents()
Computes the genotypes for the queried accessions computed from the parental dosages. Parents are known from pedigrees of accessions.
Function for getting the file handle for the genotype search result from cache. Will write the cached file if it does not exist.
Returns the genotype result as a dosage matrix format.
Uses the file iterator to write the cached file, so that it uses little memory.
=cut

sub get_cached_file_VCF_compute_from_parents {
    my $self = shift;
    my $shared_cluster_dir_config = shift;
    my $backend_config = shift;
    my $cluster_host_config = shift;
    my $web_cluster_queue_config = shift;
    my $basepath_config = shift;
    my $schema = $self->bcs_schema;
    my $protocol_ids = $self->protocol_id_list;
    my $accession_ids = $self->accession_list;
    my $cache_root_dir = $self->cache_root();
    my $marker_name_list = $self->marker_name_list;

    if (scalar(@$protocol_ids)>1) {
        die "Only one protocol at a time can be done when computing genotypes from parents\n";
    }
    my $protocol_id = $protocol_ids->[0];

    my $key = $self->key("get_cached_file_VCF_compute_from_parents_v03");
    $self->cache( Cache::File->new( cache_root => $cache_root_dir ));

    my $file_handle;
    if ($self->cache()->exists($key) && !$self->forbid_cache()) {
        $file_handle = $self->cache()->handle($key);
    }
    else {
        # Set the temp dir and temp output file
        my $tmp_output_dir = $shared_cluster_dir_config."/tmp_genotype_download_VCF_compute_from_parents";
        mkdir $tmp_output_dir if ! -d $tmp_output_dir;
        my ($tmp_fh, $tempfile) = tempfile(
            "wizard_download_XXXXX",
            DIR=> $tmp_output_dir,
        );

        my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
        my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

        my $accession_list_string = join ',', @$accession_ids;
        my $q = "SELECT accession.stock_id, female_parent.stock_id, male_parent.stock_id
            FROM stock AS accession
            JOIN stock_relationship AS female_parent_rel ON(accession.stock_id=female_parent_rel.object_id AND female_parent_rel.type_id=$female_parent_cvterm_id)
            JOIN stock AS female_parent ON(female_parent_rel.subject_id = female_parent.stock_id AND female_parent.type_id=$accession_cvterm_id)
            JOIN stock_relationship AS male_parent_rel ON(accession.stock_id=male_parent_rel.object_id AND male_parent_rel.type_id=$male_parent_cvterm_id)
            JOIN stock AS male_parent ON(male_parent_rel.subject_id = male_parent.stock_id AND male_parent.type_id=$accession_cvterm_id)
            WHERE accession.stock_id IN ($accession_list_string) AND accession.type_id=$accession_cvterm_id ORDER BY accession.stock_id;";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute();
        my @accession_stock_ids_found = ();
        my @female_stock_ids_found = ();
        my @male_stock_ids_found = ();
        while (my ($accession_stock_id, $female_parent_stock_id, $male_parent_stock_id) = $h->fetchrow_array()) {
            push @accession_stock_ids_found, $accession_stock_id;
            push @female_stock_ids_found, $female_parent_stock_id;
            push @male_stock_ids_found, $male_parent_stock_id;
        }

        # print STDERR Dumper \@accession_stock_ids_found;
        # print STDERR Dumper \@female_stock_ids_found;
        # print STDERR Dumper \@male_stock_ids_found;

        my $time = DateTime->now();
        my $timestamp = $time->ymd()."_".$time->hms();

        my @all_protocol_info_lines;

        my %unique_germplasm;
        my $protocol = CXGN::Genotype::Protocol->new({
            bcs_schema => $schema,
            nd_protocol_id => $protocol_id,
            chromosome_list=>$self->chromosome_list,
            start_position=>$self->start_position,
            end_position=>$self->end_position,
            marker_name_list=>$self->marker_name_list
        });
        my $markers = $protocol->markers;
        my @all_marker_objects = values %$markers;
        push @all_protocol_info_lines, @{$protocol->header_information_lines};
	push @all_protocol_info_lines, "##INFO=<ID=VCFDownload,Description='VCFv4.2 FILE GENERATED BY BREEDBASE AT ".$timestamp."'>";

        foreach (@all_marker_objects) {
            $self->_filtered_markers()->{$_->{name}}++;
        }

        no warnings 'uninitialized';
        @all_marker_objects = sort { $a->{chrom} cmp $b->{chrom} || $a->{pos} <=> $b->{pos} || $a->{name} cmp $b->{name} } @all_marker_objects;
        @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);

        my $counter = 0;
        for my $i (0..scalar(@accession_stock_ids_found)-1) {
            my $female_stock_id = $female_stock_ids_found[$i];
            my $male_stock_id = $male_stock_ids_found[$i];
            my $accession_stock_id = $accession_stock_ids_found[$i];

            my $dataset = CXGN::Dataset::Cache->new({
                people_schema=>$self->people_schema,
                schema=>$schema,
                cache_root=>$cache_root_dir,
                accessions=>[$female_stock_id, $male_stock_id]
            });
            my $genotypes = $dataset->retrieve_genotypes($protocol_id, ['DS'], ['markers'], ['name', 'chrom', 'pos', 'alt', 'ref'], 1, $self->chromosome_list, $self->start_position, $self->end_position, $self->marker_name_list);

            # For old protocols with no protocolprop info...
            if (scalar(@all_marker_objects) == 0) {
                foreach my $o (sort genosort keys %{$genotypes->[0]->{selected_genotype_hash}}) {
                    push @all_marker_objects, {name => $o};
                }
                @all_marker_objects = $self->_check_filtered_markers(\@all_marker_objects);
            }

            if (scalar(@$genotypes)>0) {
                my $geno = $genotypes->[0];
                $unique_germplasm{$accession_stock_id}++;

                my $genotype_string = "";
                if ($counter == 0) {
                    $genotype_string .= "#CHROM\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{chrom} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "POS\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{pos} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "ID\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $m->{name} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "REF\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{ref} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "ALT\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{alt} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "QUAL\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{qual} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "FILTER\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{filter} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "INFO\t";
                    foreach my $m (@all_marker_objects) {
                        $genotype_string .= $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{info} . "\t";
                    }
                    $genotype_string .= "\n";
                    $genotype_string .= "FORMAT\t";
                    foreach my $m (@all_marker_objects) {
                        my $format = 'DS'; #When calculating genotypes from parents, only will return dosages atleast for now
                        $genotype_string .= $format . "\t";
                        $geno->{selected_protocol_hash}->{markers}->{$m->{name}}->{format} = $format;
                        $m->{format} = $format;
                    }
                    $genotype_string .= "\n";
                }
                my $genotype_id = $geno->{germplasmName};
                if (!$self->return_only_first_genotypeprop_for_stock) {
                    $genotype_id = $geno->{germplasmName}."|".$geno->{markerProfileDbId};
                }

                my $geno_h = CXGN::Genotype::ComputeHybridGenotype->new({
                    parental_genotypes=>$genotypes,
                    marker_objects=>\@all_marker_objects
                });
                my $progeny_genotype = $geno_h->get_hybrid_genotype();
                my $genotype_string_scores = join "\t", @$progeny_genotype;

                $genotype_string .= $genotype_id."\t".$genotype_string_scores."\n";

                write_file($tempfile, {append => 1}, $genotype_string);
                $counter++;
            }
        }

        my $transpose_tempfile = $tempfile . "_transpose";

        my $cmd = CXGN::Tools::Run->new(
            {
                backend => $backend_config,
                submit_host => $cluster_host_config,
                temp_base => $tmp_output_dir,
                queue => $web_cluster_queue_config,
                do_cleanup => 0,
                out_file => $transpose_tempfile,
    #            out_file => $transpose_tempfile,
                # don't block and wait if the cluster looks full
                max_cluster_jobs => 1_000_000_000,
            }
        );

        # Do the transposition job on the cluster
        $cmd->run_cluster(
                "perl ",
                $basepath_config."/bin/transpose_matrix.pl",
                $tempfile,
        );
        $cmd->is_cluster(1);
        $cmd->wait;

        my $transpose_tempfile_hdr = $tempfile . "_transpose_hdr";

        open my $in,  '<',  $transpose_tempfile or die "Can't read input file: $!";
        open my $out, '>', $transpose_tempfile_hdr or die "Can't write output file: $!";

        #Get synonyms of the accessions
        my $stocklookup = CXGN::Stock::StockLookup->new({schema => $self->bcs_schema});
        my @accession_ids = keys %unique_germplasm;
        my $synonym_hash = $stocklookup->get_stock_synonyms('stock_id', 'accession', \@accession_ids);
        my $synonym_string = "##SynonymsOfAccessions=\"";
        while( my( $uniquename, $synonym_list ) = each %{$synonym_hash}){
            if(scalar(@{$synonym_list})>0){
                if(not length($synonym_string)<1){
                    $synonym_string.=" ";
                }
                $synonym_string.=$uniquename."=(";
                $synonym_string.= (join ", ", @{$synonym_list}).")";
            }
        }
	$synonym_string .= "\"";
        push @all_protocol_info_lines, $synonym_string;

        my $vcf_header = join "\n", @all_protocol_info_lines;
        $vcf_header .= "\n";

        print $out $vcf_header;

        while( <$in> )
            {
            print $out $_;
            }
        close $in;
        close $out;

        open my $out_copy, '<', $transpose_tempfile_hdr or die "Can't open output file: $!";

        $self->cache()->set($key, '');
        $file_handle = $self->cache()->handle($key);
        copy($out_copy, $file_handle);

        close $out_copy;
        $file_handle = $self->cache()->handle($key);
    }
    return $file_handle;
}

sub genosort {
    my ($a_chr, $a_pos, $b_chr, $b_pos);
    if ($a =~ m/S(\d+)\_(.*)/) {
        $a_chr = $1;
        $a_pos = $2;
    }
    if ($b =~ m/S(\d+)\_(.*)/) {
        $b_chr = $1;
        $b_pos = $2;
    }

    if ($a_chr && $b_chr) {
        if ($a_chr == $b_chr) {
            return $a_pos <=> $b_pos;
        }
        return $a_chr <=> $b_chr;
    } else {
        return -1;
    }
}

sub _check_filtered_markers {
    my $self = shift;
    my $all_marker_objs = shift;
    my @all_marker_objects = @$all_marker_objs;
    my @filtered_marker_objects;
    if ($self->_filtered_markers && scalar(keys %{$self->_filtered_markers}) > 0) {
        my $filtered_markers = $self->_filtered_markers;
        foreach (@all_marker_objects) {
            if (exists($filtered_markers->{$_->{name}})) {
                push @filtered_marker_objects, $_;
            }
        }
        @all_marker_objects = @filtered_marker_objects;
    }
    return @all_marker_objects;
}

1;
