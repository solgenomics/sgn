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

    my @selected_accessions = ();
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

    my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM stock JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
        JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
        JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
        WHERE genotypeprop.value @> ?
        AND stock.stock_id IN (" . join(', ', ('?') x @accessions) . ")";

    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $vcf_params_string, @accessions);

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

    my @selected_accessions = ();
    my %vcf_params;
    my $protocol_id;
    my @het_params;
    my @gt_pair;
    my $gt_pair1_string;
    my $gt_pair2_string;
    print STDERR "ACCESSION LIST=" .Dumper(\@accessions). "\n";

    foreach my $param (@parameters){
        my $param_ref = decode_json$param;
        my %params = %{$param_ref};
        my $marker_name = $params{marker_name};
        my $allele_1 = $params{allele1};
        my $allele_2 = $params{allele2};
        my $genotyping_protocol_id = $params{genotyping_protocol_id};

        if ($genotyping_protocol_id){
            $protocol_id = $genotyping_protocol_id
        }

        if ($marker_name){

            my $q = "SELECT value->'markers'->?->>'ref', value->'markers'->?->>'alt' FROM nd_protocolprop WHERE nd_protocol_id=?";

            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute($marker_name, $marker_name, $protocol_id);
            my($ref, $alt) = $h->fetchrow_array();

            print STDERR "REF=" .Dumper($ref). "\n";
            print STDERR "ALT=" .Dumper($alt). "\n";
            my @requested_alleles = ($allele_1, $allele_2);

            my $ref_count = grep (/$ref/, @requested_alleles);
            my $alt_count = grep (/$alt/, @requested_alleles);

            print STDERR "REF COUNT=" .Dumper($ref_count). "\n";
            print STDERR "ALT_COUNT=" .Dumper($alt_count). "\n";

            my $genotype;
            if ($ref_count == 2){
                $genotype = "0/0"
            } elsif ($alt_count == 2){
                $genotype = "1/1"
            } elsif ($ref_count == 1 && $alt_count == 1){
                my %gt_pair1;
                my %gt_pair2;
                $gt_pair1{$marker_name} = {'GT' => "0/1"};
                $gt_pair2{$marker_name} = {'GT' => "1/0"};
                $gt_pair1_string = encode_json \%gt_pair1;
                $gt_pair2_string = encode_json \%gt_pair2;
                @gt_pair = ($gt_pair1_string, $gt_pair2_string);
                push (@het_params, [@gt_pair]);
            } else {
                $genotype = undef;
            }

            if ($genotype ne undef){
                $vcf_params{$marker_name} = {'GT' => $genotype};
            }
        }
    }

    my $vcf_params_string;
    if (%vcf_params){
        $vcf_params_string = encode_json \%vcf_params;
    }

    print STDERR "VCF PARAMS JSON=" .Dumper($vcf_params_string). "\n";
    print STDERR "HET PARAMS=" .Dumper(\@het_params). "\n";

    if ($vcf_params_string){
        my @first_round_accessions;
        my $first_q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM stock JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
            JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
            JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
            WHERE genotypeprop.value @> ?
            AND stock.stock_id IN (" . join(', ', ('?') x @accessions) . ")";

        my $h = $schema->storage->dbh()->prepare($first_q);
        $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $vcf_params_string, @accessions);

        while (my @row = $h->fetchrow_array()){
            push @first_round_accessions, $row[0]
        }

        print STDERR "HOMOZYGOUS TEST=" .Dumper(\@first_round_accessions). "\n";
    }

    if (@het_params){
        my @pair;
        my $pair_ref = \@pair;
        foreach my $pair_ref(@het_params){
            my $next_q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM stock JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
                JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
                JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
                JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
                WHERE genotypeprop.value @> ? OR genotypeprop.value @> ?
                AND stock.stock_id IN (" . join(', ', ('?') x @accessions) . ")";

            my $h = $schema->storage->dbh()->prepare($next_q);
            $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $pair_ref->[0], $pair_ref->[1], @accessions);
            while (my @row = $h->fetchrow_array()){
                push @selected_accessions, [$row[0]];

            }
        }
        print STDERR "HETEROZYGOUS TEST=" .Dumper(\@selected_accessions). "\n";

    }

    return \@selected_accessions;


}



1;
