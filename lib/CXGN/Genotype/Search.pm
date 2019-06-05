package CXGN::Genotype::Search;

=head1 NAME

CXGN::Genotype::Search - an object to handle searching genotypes for stocks

=head1 USAGE

PLEASE BE AWARE THAT THE DEFAULT OPTIONS FOR genotypeprop_hash_select, protocolprop_top_key_select, protocolprop_marker_hash_select ARE PRONE TO EXCEEDING THE MEMORY LIMITS OF VM. CHECK THE MOOSE ATTRIBUTES BELOW TO SEE THE DEFAULTS, AND ADJUST YOUR MOOSE INSTANTIATION ACCORDINGLY

my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    accession_list=>$accession_list,
    tissue_sample_list=>$tissue_sample_list,
    trial_list=>$trial_list,
    protocol_id_list=>$protocol_id_list,
    marker_name_list=>['S80_265728', 'S80_265723'],
    genotypeprop_hash_select=>['DS', 'GT', 'DP'], #THESE ARE THE KEYS IN THE GENOTYPEPROP OBJECT
    protocolprop_top_key_select=>['reference_genome_name', 'header_information_lines', 'marker_names', 'markers'], #THESE ARE THE KEYS AT THE TOP LEVEL OF THE PROTOCOLPROP OBJECT
    protocolprop_marker_hash_select=>['name', 'chrom', 'pos', 'alt', 'ref'], #THESE ARE THE KEYS IN THE MARKERS OBJECT IN THE PROTOCOLPROP OBJECT
    return_only_first_genotypeprop_for_stock=>0, #THIS IS TO CONSERVE MEMORY USAGE
    # marker_search_hash_list=>[{'S80_265728' => {'pos' => '265728', 'chrom' => '1'}}], NOT IMPLEMENTED
    # marker_score_search_hash_list=>[{'S80_265728' => {'GT' => '0/0', 'GQ' => '99'}}], NOT IMPLEMENTED
});
my ($total_count, $genotypes) = $genotypes_search->get_genotype_info();

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

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
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
    isa => 'Int',
    is => 'rw',
);

has 'offset' => (
    isa => 'Int',
    is => 'rw',
);

=head2 get_genotype_info

returns: an array with genotype information

=cut

sub get_genotype_info {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_list = $self->trial_list;
    my $protocol_id_list = $self->protocol_id_list;
    my $markerprofile_id_list = $self->markerprofile_id_list;
    my $accession_list = $self->accession_list;
    my $tissue_sample_list = $self->tissue_sample_list;
    my $marker_name_list = $self->marker_name_list;
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
    my $igd_genotypeprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'igd number', 'genotype_property')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'accession', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'tissue_sample', 'stock_type')->cvterm_id();
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

    if ($protocol_id_list && scalar(@$protocol_id_list)>0) {
        my $protocol_sql = join ("," , @$protocol_id_list);
        push @where_clause, "nd_protocol.nd_protocol_id in ($protocol_sql)";
    }
    if ($accession_list && scalar(@$accession_list)>0) {
        my $accession_sql = join ("," , @$accession_list);
        push @where_clause, "stock.stock_id in ($accession_sql)";
        push @where_clause, "stock.type_id = $accession_cvterm_id";
    }
    if ($tissue_sample_list && scalar(@$tissue_sample_list)>0) {
        my $stock_sql = join ("," , @$tissue_sample_list);
        push @where_clause, "stock.stock_id in ($stock_sql)";
        push @where_clause, "stock.type_id = $tissue_sample_cvterm_id";
    }
    if ($markerprofile_id_list && scalar(@$markerprofile_id_list)>0) {
        my $markerprofile_sql = join ("," , @$markerprofile_id_list);
        push @where_clause, "genotype_values.genotypeprop_id in ($markerprofile_sql)";
    }
    if ($marker_name_list && scalar(@$marker_name_list)>0) {
        my $search_vals_sql = "'".join ("','" , @$marker_name_list)."'";
        push @where_clause, "nd_protocolprop.value->'markers' \\?& array[$search_vals_sql]";
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

    my $q = "SELECT $stock_select, genotype_values.genotypeprop_id, igd_number_genotypeprop.value, nd_protocol.nd_protocol_id, nd_protocol.name, stock.uniquename, stock.type_id, stock_cvterm.name, genotype.genotype_id, genotype.uniquename, genotype.description, project.project_id, project.name, project.description, accession_of_tissue_sample.stock_id, accession_of_tissue_sample.uniquename, count(genotype_values.genotypeprop_id) OVER() AS full_count
        FROM stock
        JOIN cvterm AS stock_cvterm ON(stock.type_id = stock_cvterm.cvterm_id)
        LEFT JOIN stock_relationship ON(stock_relationship.subject_id=stock.stock_id AND stock_relationship.type_id = $tissue_sample_of_cvterm_id)
        LEFT JOIN stock AS accession_of_tissue_sample ON(stock_relationship.object_id=accession_of_tissue_sample.stock_id AND accession_of_tissue_sample.type_id = $accession_cvterm_id)
        JOIN nd_experiment_stock ON(stock.stock_id=nd_experiment_stock.stock_id)
        JOIN nd_experiment USING(nd_experiment_id)
        JOIN nd_experiment_protocol USING(nd_experiment_id)
        JOIN nd_experiment_project USING(nd_experiment_id)
        JOIN nd_experiment_genotype USING(nd_experiment_id)
        JOIN nd_protocol USING(nd_protocol_id)
        LEFT JOIN nd_protocolprop ON(nd_protocolprop.nd_protocol_id = nd_protocol.nd_protocol_id AND nd_protocolprop.type_id = $vcf_map_details_cvterm_id)
        JOIN genotype USING(genotype_id)
        LEFT JOIN genotypeprop AS igd_number_genotypeprop ON(igd_number_genotypeprop.genotype_id = genotype.genotype_id AND igd_number_genotypeprop.type_id = $igd_genotypeprop_cvterm_id)
        JOIN genotypeprop AS genotype_values ON(genotype_values.genotype_id = genotype.genotype_id AND genotype_values.type_id = $vcf_snp_genotyping_cvterm_id)
        JOIN project USING(project_id)
        $where_clause
        ORDER BY stock.stock_id, genotype_values.genotypeprop_id ASC
        $limit_clause
        $offset_clause;";

    print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my $total_count = 0;
    my @genotypeprop_array;
    my %genotypeprop_hash;
    my %protocolprop_hash;
    while (my ($stock_id, $genotypeprop_id, $igd_number_json, $protocol_id, $protocol_name, $stock_name, $stock_type_id, $stock_type_name, $genotype_id, $genotype_uniquename, $genotype_description, $project_id, $project_name, $project_description, $accession_id, $accession_uniquename, $full_count) = $h->fetchrow_array()) {
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

        push @genotypeprop_array, $genotypeprop_id;
        $genotypeprop_hash{$genotypeprop_id} = {
            markerProfileDbId => $genotypeprop_id,
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
    print STDERR "CXGN::Genotype::Search has genotypeprop_ids $total_count\n";

    my @found_genotypeprop_ids = keys %genotypeprop_hash;
    my @genotypeprop_hash_select_arr;
    foreach (@$genotypeprop_hash_select){
        push @genotypeprop_hash_select_arr, "s.value->>'$_'";
    }
    if (scalar(@found_genotypeprop_ids)>0) {
        my $genotypeprop_id_sql = join ("," , @found_genotypeprop_ids);
        my $genotypeprop_hash_select_sql = scalar(@genotypeprop_hash_select_arr) > 0 ? ', '.join ',', @genotypeprop_hash_select_arr : '';
        my $genotypeprop_q = "SELECT s.key $genotypeprop_hash_select_sql from genotypeprop, jsonb_each(genotypeprop.value) as s WHERE genotypeprop_id = ? and type_id = $vcf_snp_genotyping_cvterm_id;";
        my $genotypeprop_h = $schema->storage->dbh()->prepare($genotypeprop_q);
        foreach my $genotypeprop_id (@found_genotypeprop_ids){
            $genotypeprop_h->execute($genotypeprop_id);
            while (my ($marker_name, @genotypeprop_info_return) = $genotypeprop_h->fetchrow_array()) {
                for my $s (0 .. scalar(@genotypeprop_hash_select_arr)-1){
                    $genotypeprop_hash{$genotypeprop_id}->{selected_genotype_hash}->{$marker_name}->{$genotypeprop_hash_select->[$s]} = $genotypeprop_info_return[$s];
                }
            }
        }
    }
    print STDERR "CXGN::Genotype::Search has genotypeprops\n";

    my @found_protocolprop_ids = keys %protocolprop_hash;
    my @protocolprop_marker_hash_select_arr;
    foreach (@$protocolprop_marker_hash_select){
        push @protocolprop_marker_hash_select_arr, "s.value->>'$_'";
    }
    my @protocolprop_top_key_select_arr;
    foreach (@$protocolprop_top_key_select){
        push @protocolprop_top_key_select_arr, "value->>'$_'";
    }
    my %selected_protocol_marker_info;
    my %selected_protocol_top_key_info;
    if (scalar(@found_protocolprop_ids)>0){
        my $protocolprop_id_sql = join ("," , @found_protocolprop_ids);
        my $protocolprop_where_sql = "nd_protocol_id in ($protocolprop_id_sql) and type_id = $vcf_map_details_cvterm_id";
        my $protocolprop_hash_select_sql = scalar(@protocolprop_marker_hash_select_arr) > 0 ? ', '.join ',', @protocolprop_marker_hash_select_arr : '';
        my $protocolprop_q = "SELECT nd_protocol_id, s.key $protocolprop_hash_select_sql from nd_protocolprop, jsonb_each(nd_protocolprop.value->'markers') as s WHERE $protocolprop_where_sql;";
        my $protocolprop_h = $schema->storage->dbh()->prepare($protocolprop_q);
        $protocolprop_h->execute();
        while (my ($protocol_id, $marker_name, @protocolprop_info_return) = $protocolprop_h->fetchrow_array()) {
            for my $s (0 .. scalar(@protocolprop_marker_hash_select_arr)-1){
                $selected_protocol_marker_info{$protocol_id}->{$marker_name}->{$protocolprop_marker_hash_select->[$s]} = $protocolprop_info_return[$s];
            }
        }
        my $protocolprop_top_key_select_sql = scalar(@protocolprop_top_key_select_arr) > 0 ? ', '.join ',', @protocolprop_top_key_select_arr : '';
        my $protocolprop_top_key_q = "SELECT nd_protocol_id $protocolprop_top_key_select_sql from nd_protocolprop WHERE $protocolprop_where_sql;";
        my $protocolprop_top_key_h = $schema->storage->dbh()->prepare($protocolprop_top_key_q);
        $protocolprop_top_key_h->execute();
        while (my ($protocol_id, @protocolprop_top_key_return) = $protocolprop_top_key_h->fetchrow_array()) {
            for my $s (0 .. scalar(@protocolprop_top_key_select_arr)-1){
                my $protocolprop_i = $protocolprop_top_key_select->[$s];
                my $val;
                if ($protocolprop_i eq 'header_information_lines' || $protocolprop_i eq 'markers_array' || $protocolprop_i eq 'markers' || $protocolprop_i eq 'marker_names') {
                    $val = decode_json $protocolprop_top_key_return[$s];
                } else {
                    $val = $protocolprop_top_key_return[$s];
                }
                $selected_protocol_top_key_info{$protocol_id}->{$protocolprop_i} = $val;
            }
        }
    }
    print STDERR "CXGN::Genotype::Search has protocolprops\n";

    foreach (@genotypeprop_array) {
        my $info = $genotypeprop_hash{$_};
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



1;
