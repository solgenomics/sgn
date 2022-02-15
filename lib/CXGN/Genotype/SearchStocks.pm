package CXGN::Genotype::SearchStocks;

=head1 NAME

CXGN::Genotype::SearchStocks - an object to handle searching stocks containing specific genotypes

=head1 USAGE

=head1 DESCRIPTION


=head1 AUTHORS

Titima Tantikanjana <tt15@cornell.edu>

=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use JSON;
use Sort::Key::Natural qw(natsort);

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

has 'filtering_parameters' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
);

has 'stock_list' => (
    isa => 'ArrayRef[Str]',
    is => 'ro',
);

sub get_selected_stocks {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $stock_list = $self->stock_list;
    my $filtering_parameters = $self->filtering_parameters;
    my @stocks = @{$stock_list};
    my @parameters = @{$filtering_parameters};
    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $vcf_map_details_markers_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details_markers', 'protocol_property')->cvterm_id();
    my $vcf_map_details_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_map_details', 'protocol_property')->cvterm_id();
    my $vcf_snp_genotyping_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'vcf_snp_genotyping', 'genotype_property')->cvterm_id();
    my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
    my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
    my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
    my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $protocol_info = $parameters[0];
    my $info_ref = decode_json$protocol_info;
    my %info = %{$info_ref};
    my $protocol_id = $info{genotyping_protocol_id};
    my $protocol_name = $info{genotyping_protocol_name};
    my $data_type = $info{genotyping_data_type};

    my $type_q= "SELECT value->>'sample_observation_unit_type_name'
    FROM nd_protocolprop WHERE nd_protocol_id = ? AND type_id =? ";

    my $type_h = $schema->storage->dbh()->prepare($type_q);
    $type_h->execute($protocol_id, $vcf_map_details_id);

    my ($sample_type) = $type_h->fetchrow_array();

    my %chrom_hash;
    my @incorrect_marker_names;
    for (my $i=1; $i<@parameters; $i++) {
        my $param_ref = decode_json$parameters[$i];
        my %params = %{$param_ref};
        my $marker_name = $params{marker_name};

        if ($data_type eq 'Dosage') {
            my $allele_dosage = $params{allele_dosage};
            my $chrom_key;
            my $q = "SELECT value->?->>'chrom' AS chromosome_no FROM nd_protocolprop WHERE nd_protocol_id = ? AND type_id =? AND value->?->>'chrom' IS NOT NULL";

            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute($marker_name, $protocol_id, $vcf_map_details_markers_cvterm_id, $marker_name);
            my ($chrom) = $h->fetchrow_array();

            if ($chrom){
                $chrom_hash{$chrom}{$marker_name}{'DS'} = $allele_dosage;
            } else {
                push @incorrect_marker_names, "Marker name: $marker_name is not in genotyping protocol: $protocol_name. \n";
            }
        } elsif ($data_type eq 'SNP') {
            my $allele_1 = $params{allele1};
            my $allele_2 = $params{allele2};
            my @allele_param = ($allele_1, $allele_2);

            my @ref_alt_chrom = ();
            my $q = "SELECT value->?->>'ref', value->?->>'alt', value->?->>'chrom'
            FROM nd_protocolprop WHERE nd_protocol_id = ? AND type_id =? AND value->?->>'ref' IS NOT NULL";

            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute($marker_name, $marker_name, $marker_name, $protocol_id, $vcf_map_details_markers_cvterm_id, $marker_name);

            while (my ($ref, $alt, $chrom) = $h->fetchrow_array()){
                push @ref_alt_chrom, ($ref, $alt, $chrom);
                if (!@ref_alt_chrom) {
                    push @incorrect_marker_names, "Marker name: $marker_name is not in genotyping protocol: $protocol_name. \n";
                }
            }

            my @nt = ();
            if (@ref_alt_chrom) {
                my $q_gt = "SELECT genotypeprop.value->?->>'GT' FROM nd_experiment_protocol
                    JOIN nd_experiment_genotype ON (nd_experiment_genotype.nd_experiment_id = nd_experiment_protocol.nd_experiment_id)
                    JOIN genotypeprop ON (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id) AND genotypeprop.type_id = ?
                    where nd_experiment_protocol.nd_protocol_id = ? AND genotypeprop.value->?->>'GT' IS NOT NULL LIMIT 1";

                my $h_gt = $schema->storage->dbh()->prepare($q_gt);
                $h_gt->execute($marker_name, $vcf_snp_genotyping_cvterm_id, $protocol_id, $marker_name);
                my ($gt_value) = $h_gt->fetchrow_array();
                my $separator = ',';
                my @gt_alleles = split (/\//, $gt_value);
                if (scalar(@gt_alleles) <= 1){
                    @gt_alleles = split (/\|/, $gt_value);
                    if (scalar(@gt_alleles) > 1) {
                        $separator = '|';
                    }
                }

                if ($allele_1 ne $allele_2){
                    foreach my $allele(@allele_param){
                        if (grep{/$allele/}(@ref_alt_chrom)){
                            if ($allele eq $ref_alt_chrom[0]){
                                $nt[0] = $allele;
                            } elsif ($allele eq $ref_alt_chrom[1]){
                                $nt[1] = $allele;
                            }
                            my $nt_string = join $separator, @nt;

                            $chrom_hash{$ref_alt_chrom[2]}{$marker_name} = {'NT' => $nt_string};
                        } else {
                            last;
                        }
                    }
                } elsif ($allele_1 eq $allele_2){
                    if (grep{/$allele_1/}(@ref_alt_chrom)){
                        @nt = ($allele_1, $allele_2);
                        my $nt_string = join $separator, @nt;
                        $chrom_hash{$ref_alt_chrom[2]}{$marker_name} = {'NT' => $nt_string};
                    } else {
                        last;
                    }
                }
            }
        }
    }

    if (scalar(@incorrect_marker_names) > 0) {
        return {incorrect_marker_names=> \@incorrect_marker_names};
    }
    my @formatted_parameters;
    my @rank_and_params;
    if (%chrom_hash) {
        foreach my $chromosome (keys %chrom_hash) {
            my $rank_q= "SELECT value->'chromosomes'->?->>'rank'
            FROM nd_protocolprop WHERE nd_protocol_id = ? AND type_id =? ";

            my $rank_h = $schema->storage->dbh()->prepare($rank_q);
            $rank_h->execute($chromosome, $protocol_id, $vcf_map_details_id);

            my ($rank) = $rank_h->fetchrow_array();
            my $marker_params = $chrom_hash{$chromosome};
            my $each_chrom_markers_string = encode_json $marker_params;
            push @formatted_parameters, $each_chrom_markers_string;
            push @rank_and_params, [$rank, $each_chrom_markers_string]
        }
    }

    my @sorted_markers = natsort @formatted_parameters;
    my $genotype_string = join("<br>", @sorted_markers);

    my $join_type;
    if ($sample_type eq 'accession') {
        $join_type = "JOIN nd_experiment_stock ON (stock1.stock_id = nd_experiment_stock.stock_id)";
    } elsif ($sample_type eq 'tissue_sample') {
        $join_type = "JOIN stock_relationship ON (stock_relationship.object_id = stock1.stock_id) AND stock_relationship.type_id = $tissue_sample_of_cvterm_id
            JOIN nd_experiment_stock ON stock_relationship.subject_id = nd_experiment_stock.stock_id"
    }

    my @selected_stocks_details;
    foreach my $param (@rank_and_params) {
        my $stock_table = "DROP TABLE IF EXISTS stock_table;
            CREATE TEMP TABLE stock_table(stock_name Varchar(100))";
        my $s_t = $schema->storage->dbh()->prepare($stock_table);
        $s_t->execute();

        foreach my $st(@stocks){
            my $added_table = "INSERT INTO stock_table (stock_name) VALUES (?)";
            my $table_h = $schema->storage->dbh()->prepare($added_table);
            $table_h->execute($st);
        }

        @stocks = ();
        @selected_stocks_details = ();

        if (($sample_type eq 'accession') || ($sample_type eq 'tissue_sample')) {
            my $q2 = "SELECT DISTINCT stock1.stock_id, stock1.uniquename, stock2.stock_id, stock2.uniquename, cvterm.name FROM stock_table
                JOIN stock AS stock1 ON (stock_table.stock_name = stock1.uniquename) AND stock1.type_id = ?
                $join_type
                JOIN stock AS stock2 ON (nd_experiment_stock.stock_id = stock2.stock_id)
                JOIN cvterm ON (stock2.type_id = cvterm.cvterm_id)
                JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
                JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
                JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id) AND genotypeprop.type_id = ? AND genotypeprop.rank = ?
                WHERE genotypeprop.value @> ? ";

            my $h2 = $schema->storage->dbh()->prepare($q2);
            $h2->execute($accession_cvterm_id, $genotyping_experiment_cvterm_id, $protocol_id, $vcf_snp_genotyping_cvterm_id, $param->[0], $param->[1]);

            while (my ($selected_accession_id, $selected_accession_name, $selected_sample_id, $selected_sample_name, $sample_type) = $h2->fetchrow_array()){
                push @selected_stocks_details, [$selected_accession_id, $selected_accession_name, $selected_sample_id, $selected_sample_name, $sample_type, $genotype_string ];
                push @stocks, $selected_accession_name
            }
        } elsif ($sample_type eq 'stocks') {
            my $q2 = "SELECT DISTINCT stock1.stock_id, stock1.uniquename, stock2.stock_id, stock2.uniquename, cvterm.name FROM stock_table
                JOIN stock AS stock1 ON (stock_table.stock_name = stock1.uniquename) AND stock1.type_id = ?
                JOIN nd_experiment_stock ON (stock1.stock_id = nd_experiment_stock.stock_id)
                JOIN stock AS stock2 ON (nd_experiment_stock.stock_id = stock2.stock_id)
                JOIN cvterm ON (stock2.type_id = cvterm.cvterm_id)
                JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
                JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
                JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id) AND genotypeprop.type_id = ? AND genotypeprop.rank = ?
                WHERE genotypeprop.value @> ?

                UNION ALL

                SELECT DISTINCT stock1.stock_id, stock1.uniquename, stock2.stock_id, stock2.uniquename, cvterm.name FROM stock_table
                JOIN stock AS stock1 ON (stock_table.stock_name = stock1.uniquename) AND stock1.type_id = ?
                JOIN stock_relationship ON (stock_relationship.object_id = stock1.stock_id) AND stock_relationship.type_id IN (?,?,?)
                JOIN nd_experiment_stock ON stock_relationship.subject_id = nd_experiment_stock.stock_id
                JOIN stock AS stock2 ON (nd_experiment_stock.stock_id = stock2.stock_id)
                JOIN cvterm ON (stock2.type_id = cvterm.cvterm_id)
                JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
                JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
                JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id) AND genotypeprop.type_id = ? AND genotypeprop.rank = ?
                WHERE genotypeprop.value @> ?";

            my $h2= $schema->storage->dbh()->prepare($q2);
            $h2->execute($accession_cvterm_id, $genotyping_experiment_cvterm_id, $protocol_id, $vcf_snp_genotyping_cvterm_id, $param->[0], $param->[1], $accession_cvterm_id, $plot_of_cvterm_id, $plant_of_cvterm_id, $tissue_sample_of_cvterm_id, $genotyping_experiment_cvterm_id, $protocol_id, $vcf_snp_genotyping_cvterm_id, $param->[0], $param->[1]);

            while (my ($selected_accession_id, $selected_accession_name, $selected_sample_id, $selected_sample_name, $sample_type) = $h2->fetchrow_array()){
                push @selected_stocks_details, [$selected_accession_id, $selected_accession_name, $selected_sample_id, $selected_sample_name, $sample_type, $genotype_string ];
                push @stocks, $selected_accession_name
            }
        }
    }

    return {selected_stocks=> \@selected_stocks_details};

}


1;
