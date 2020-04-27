package CXGN::Genotype::QcGenotype;

=head1 NAME

CXGN::Genotype::QcGenotype - an object to handle searching genotypes for stocks

=head1 USAGE

my $genotypes_search = CXGN::Genotype::QcGenotype->new({
    bcs_schema=>$schema,
    accession_list=>$accession_list,
    marker_scores_hash=>\%marker_scores_hash,
});
my ($total_count, $genotypes) = $genotypes_search->get_genotype_qc_info();

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

=head2 get_genotype_info

returns: an array with genotype information

=cut

sub get_genotype_qc_info {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $trial_list = $self->trial_list;
    my $protocol_id_list = $self->protocol_id_list;
    my $markerprofile_id_list = $self->markerprofile_id_list;
    my $accession_list = $self->accession_list;
    my @data;
    my %search_params;
    my @where_clause;

    my $q = "SELECT $stock_select, genotype_values.genotypeprop_id, igd_number_genotypeprop.value, nd_protocol.nd_protocol_id, nd_protocol.name, stock.uniquename, stock.type_id, stock_cvterm.name, genotype.genotype_id, genotype.uniquename, genotype.description, project.project_id, project.name, project.description, accession_of_tissue_sample.stock_id, accession_of_tissue_sample.uniquename, count(genotype_values.genotypeprop_id) OVER() AS full_count
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
