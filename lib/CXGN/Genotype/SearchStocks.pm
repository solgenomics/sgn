package CXGN::Genotype::SearchStocks;

=head1 NAME

CXGN::Genotype::SearchStocks - an object to handle searching stocks with specific genotypes

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

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
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

has 'stock_list' => (
    isa => 'ArrayRef[Int]',
    is => 'ro',
);

sub get_selected_accessions {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $accession_list = $self->stock_list;
    my $filtering_parameters = $self->filtering_parameters;
    my @accessions = @{$accession_list};
    my @parameters = @{$filtering_parameters};

    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();

    my @selected_accessions;
    my %vcf_params;
    my $protocol_id;

    foreach my $param (@parameters){
        my $param_ref = decode_json$param;
        my %params = %{$param_ref};
        my $marker_name = $params{marker_name};
        my $allele_dosage = $params{allele_dosage};
        my $genotyping_protocol_id = $params{genotyping_protocol_id};

        if ($genotyping_protocol_id){
            $protocol_id = $genotyping_protocol_id
        }

        if ($marker_name){
            $vcf_params{$marker_name} = {'DS' => $allele_dosage};
        }
    }

    my $vcf_params_string = encode_json \%vcf_params;

#    print STDERR "VCF PARAMS JSON=" .Dumper($vcf_params_string). "\n";
#    print STDERR "PROTOCOL_ID=" .Dumper($protocol_id). "\n";

    my $dataset_table = "DROP TABLE IF EXISTS dataset_table;
        CREATE TEMP TABLE dataset_table(stock_id INT)";
    my $d_t = $schema->storage->dbh()->prepare($dataset_table);
    $d_t->execute();

    foreach my $accession(@accessions){
        my $added_table = "INSERT INTO dataset_table (stock_id) VALUES (?)";
        my $h = $schema->storage->dbh()->prepare($added_table);
        $h->execute($accession);
    }

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM dataset_table
        JOIN stock ON (dataset_table.stock_id = stock.stock_id)
        JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
        JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
        JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
        WHERE genotypeprop.value @> ? ";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $vcf_params_string);

    while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
        push @selected_accessions, [$selected_id, $selected_uniquename, $vcf_params_string]
    }

    return \@selected_accessions;

}

sub get_accessions_using_snps {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $accession_list = $self->stock_list;
    my $filtering_parameters = $self->filtering_parameters;
    my @accessions = @{$accession_list};
    my @parameters = @{$filtering_parameters};

    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();

    my $protocol_id;
    my %genotype_nt;
    my @selected_accessions;
#    print STDERR "ACCESSION LIST=" .Dumper(\@accessions). "\n";

    my $dataset_table = "DROP TABLE IF EXISTS dataset_table;
        CREATE TEMP TABLE dataset_table(stock_id INT)";
    my $d_t = $schema->storage->dbh()->prepare($dataset_table);
    $d_t->execute();

    foreach my $accession(@accessions){
        my $added_table = "INSERT INTO dataset_table (stock_id) VALUES (?)";
        my $h = $schema->storage->dbh()->prepare($added_table);
        $h->execute($accession);
    }

    foreach my $param (@parameters){
        my $param_ref = decode_json$param;
        my %params = %{$param_ref};
        my $marker_name = $params{marker_name};
        my $allele_1 = $params{allele1};
        my $allele_2 = $params{allele2};
        my @allele_param = ($allele_1, $allele_2);
        my $genotyping_protocol_id = $params{genotyping_protocol_id};

        if ($genotyping_protocol_id){
            $protocol_id = $genotyping_protocol_id
        }

        if ($marker_name){
            my @ref_alt = ();

            my $q = "SELECT value->'markers'->?->>'ref', value->'markers'->?->>'alt'
                FROM nd_protocolprop where nd_protocol_id = ?";

            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute($marker_name, $marker_name, $protocol_id);

            while (my ($ref, $alt) = $h->fetchrow_array()){
                push @ref_alt, $ref, $alt
            }
            print STDERR "REF ALT=" .Dumper(\@ref_alt). "\n";

            my @nt = ();

            if ($allele_1 ne $allele_2){
                foreach my $allele(@allele_param){
                    if (grep{/$allele/}(@ref_alt)){
                        if ($allele eq $ref_alt[0]){
                            $nt[0] = $allele;
                        } elsif ($allele eq $ref_alt[1]){
                            $nt[1] = $allele;
                        }
                        my $nt_string = join(",", @nt);
                        $genotype_nt{$marker_name} = {'NT' => $nt_string};
                    } else {
                        last;
                    }
                }
            } elsif ($allele_1 eq $allele_2){
                if (grep{/$allele_1/}(@ref_alt)){
                    @nt = ($allele_1, $allele_2);
                    my $nt_string = join(",", @nt);
                    $genotype_nt{$marker_name} = {'NT' => $nt_string};
                 } else {
                    last;
                }

            }
        }
    }

    my $all_nt_string;
    if (%genotype_nt){
        $all_nt_string = encode_json \%genotype_nt;
    }

    print STDERR "PARAM HASH=" .Dumper(\%genotype_nt). "\n";
    print STDERR "PARAM STRING=" .Dumper($all_nt_string). "\n";

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM dataset_table
        JOIN stock ON (dataset_table.stock_id = stock.stock_id)
        JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
        JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
        JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
        WHERE genotypeprop.value @> ?";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $all_nt_string);

    while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
        push @selected_accessions, [$selected_id, $selected_uniquename, $all_nt_string]
    }

    return \@selected_accessions;

}


1;
