package CXGN::Genotype::Search;

=head1 NAME

CXGN::Genotype::Search - an object to handle searching genotypes for stocks

=head1 USAGE

my $genotypes_search = CXGN::Genotype::Search->new({
    bcs_schema=>$schema,
    accession_list=>$accession_list,
    tissue_sample_list=>$tissue_sample_list,
    trial_list=>$trial_list,
    protocol_id_list=>$protocol_id_list,
    marker_name_list=>['S80_265728', 'S80_265723']
    marker_search_hash_list=>[{'S80_265728' => {'pos' => '265728', 'chrom' => '1'}}],
    marker_score_search_hash_list=>[{'S80_265728' => {'GT' => '0/0', 'GQ' => '99'}}],
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
use DBI;
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

has 'marker_search_hash_list' => (
    isa => 'ArrayRef[HashRef]|Undef',
    is => 'ro',
);

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

has 'protocol_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'marker_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'allele_dosage' => (
    isa => 'Str',
    is => 'rw',
);

has 'filtering_parameters' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
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
    my $marker_search_hash_list = $self->marker_search_hash_list;
    my $marker_score_search_hash_list = $self->marker_score_search_hash_list;
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

    my $q = "SELECT genotype_values.genotypeprop_id, genotype_values.value, igd_number_genotypeprop.value, nd_protocol.nd_protocol_id, nd_protocol.name, nd_protocolprop.value, stock.stock_id, stock.uniquename, stock.type_id, stock_cvterm.name, genotype.genotype_id, genotype.uniquename, genotype.description, project.project_id, project.name, project.description, accession_of_tissue_sample.stock_id, accession_of_tissue_sample.uniquename, count(genotype_values.genotypeprop_id) OVER() AS full_count
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
        JOIN genotypeprop AS genotype_values ON(genotype_values.genotype_id = genotype.genotype_id AND genotype_values.type_id = $vcf_snp_genotyping_cvterm_id)
        JOIN project USING(project_id)
        $where_clause
        ORDER BY genotype_values.genotypeprop_id ASC
        $limit_clause
        $offset_clause;";

    print STDERR Dumper $q;
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();

    my $total_count = 0;
    while (my ($genotypeprop_id, $genotypeprop_json, $igd_number_json, $protocol_id, $protocol_name, $protocolprop_json, $stock_id, $stock_name, $stock_type_id, $stock_type_name, $genotype_id, $genotype_uniquename, $genotype_description, $project_id, $project_name, $project_description, $accession_id, $accession_uniquename, $full_count) = $h->fetchrow_array()) {
        my $genotype = decode_json $genotypeprop_json;
        my $protocol = $protocolprop_json ? decode_json $protocolprop_json : undef;
        my $all_protocol_marker_names = $protocol ? $protocol->{'marker_names'} : undef;
        my $igd_number_hash = $igd_number_json ? decode_json $igd_number_json : undef;
        my $igd_number = $igd_number_hash ? $igd_number_hash->{'igd number'} : undef;
        $igd_number = !$igd_number && $igd_number_hash ? $igd_number_hash->{'igd_number'} : undef;

        my %dosage_hash;
        while(my($marker_name, $val) = each %$genotype) {
            $dosage_hash{$marker_name} = $val->{'DS'};
        }

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

        push @data, {
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
            genotype_hash => \%dosage_hash,
            full_genotype_hash => $genotype,
            full_protocol_hash => $protocol,
            all_protocol_marker_names => $all_protocol_marker_names,
            igd_number => $igd_number,
            resultCount => scalar(keys(%$genotype))
        };
        $total_count = $full_count;
    }
    #print STDERR Dumper \@data;

    return ($total_count, \@data);
}

sub get_selected_accessions {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $protocol_id = $self->protocol_id;
    my $accession_list = $self->accession_list;
#    my $marker_name = $self->marker_name;
#    my $allele_dosage = $self->allele_dosage;
    my $filtering_parameters = $self->filtering_parameters;
    my @accessions = @{$accession_list};
    my @parameters = @{$filtering_parameters};

    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();

    my @selected_accessions = ();
    my $marker_dosage;


    foreach my $param (@parameters){
        my $param_ref = decode_json$param;
        my %params = %{$param_ref};
        my $marker_name = $params{marker_name};
        my $allele_dosage = $params{allele_dosage};

        if ($marker_name){
            $marker_dosage->{$marker_name} = $allele_dosage;
        }
    }

    my $marker_dosage_string = encode_json$marker_dosage;

#    print STDERR "MARKER DOSAGE JSON=" .Dumper($marker_dosage_string). "\n";

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM stock JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
        JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
        JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
        WHERE genotypeprop.value @> ?
        AND stock.stock_id IN (" . join(', ', ('?') x @accessions) . ')';

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $marker_dosage_string, @accessions);

    while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
        push @selected_accessions, [$selected_id, $selected_uniquename]
    }

    return \@selected_accessions;

}


1;
