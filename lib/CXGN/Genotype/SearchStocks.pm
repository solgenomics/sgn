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

    my $protocol_id;
    my %homozygous_nt;
    my @all_het_pairs;
    my @het_all_accessions;
    my @het_selected_accessions;
    my @selected_accessions;
    my $all_markers_string;


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
            if ($allele_1 eq $allele_2){
                my $homozygous_param = $allele_1.'/'.$allele_2;
                $homozygous_nt{$marker_name} = {'NT' => $homozygous_param}
            }

            if ($allele_1 ne $allele_2){
                my %heterozygous_nt1 = ();
                my %heterozygous_nt2 = ();
                my @het_pair = ();
                my $heterozygous_param1 = $allele_1.'/'.$allele_2;
                my $heterozygous_param2 = $allele_2.'/'.$allele_1;
                $heterozygous_nt1{$marker_name} = {'NT' => $heterozygous_param1};
                my $heterozygous_nt_string1 = encode_json \%heterozygous_nt1;
                $heterozygous_nt2{$marker_name} = {'NT' => $heterozygous_param2};
                my $heterozygous_nt_string2 = encode_json \%heterozygous_nt2;

                push @het_pair, $heterozygous_nt_string1, $heterozygous_nt_string2;
                push @all_het_pairs, \@het_pair;
            }

            my %all_markers;
            my $nt_value = $allele_1.'/'.$allele_2;
            $all_markers{$marker_name} = {'NT' => $nt_value};
            $all_markers_string = encode_json \%all_markers;
        }
    }

    my $het_param_count = @all_het_pairs;

    my $homozygous_nt_string;
    if (%homozygous_nt){
        $homozygous_nt_string = encode_json \%homozygous_nt;
    }


    print STDERR "HOMOZYGOUS NT JSON=" .Dumper($homozygous_nt_string). "\n";
    print STDERR "ALL HET PAIRS=" .Dumper(\@all_het_pairs). "\n";
    print STDERR "HET PARAM COUNT=" .Dumper($het_param_count). "\n";

    my @homozygous_accessions;
    if ($homozygous_nt_string){
        my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM stock JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
            JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
            JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
            WHERE genotypeprop.value @> ?
            AND stock.stock_id IN (" . join(', ', ('?') x @accessions) . ")";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $homozygous_nt_string, @accessions);

        if ($het_param_count == 0){
            while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
                push @selected_accessions, [$selected_id, $selected_uniquename, $all_markers_string]
            }
        } elsif ($het_param_count != 0){
            while (my @row = $h->fetchrow_array()){
                push @homozygous_accessions, $row[0]
            }

            foreach my $pair(@all_het_pairs){
                my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM stock JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
                JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
                JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
                JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
                WHERE genotypeprop.value @> ? or genotypeprop.value @> ?
                AND stock.stock_id IN (" . join(', ', ('?') x @homozygous_accessions) . ")";

                my $h = $schema->storage->dbh()->prepare($q);
                $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $$pair[0], $$pair[1], @homozygous_accessions);

                while (my @row = $h->fetchrow_array()){
                    push @het_all_accessions, $row[0]
                }
            }

            my %accession_count;
            $accession_count{$_}++ foreach @het_all_accessions;

            @het_selected_accessions = grep { $accession_count{$_} eq $het_param_count } keys %accession_count;

            print STDERR "HET HOMO SELECTED ACCESSIONS=" .Dumper(\@het_selected_accessions). "\n";

            my $q = "SELECT stock_id, uniquename FROM stock where stock_id IN (" . join(', ', ('?') x @het_selected_accessions) . ")";
            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute(@het_selected_accessions);
            while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
                push @selected_accessions, [$selected_id, $selected_uniquename, $all_markers_string]
            }
        }
    } elsif (($homozygous_nt_string == 0) && ($het_param_count != 0)){
        foreach my $pair(@all_het_pairs){
            my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM stock JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
                JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
                JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
                JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
                WHERE genotypeprop.value @> ? or genotypeprop.value @> ?
                AND stock.stock_id IN (" . join(', ', ('?') x @accessions) . ")";

            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $$pair[0], $$pair[1], @accessions);

            while (my @row = $h->fetchrow_array()){
                push @het_all_accessions, $row[0]
            }
        }

        print STDERR "HET ALL ACCESSIONS=" .Dumper(\@het_all_accessions). "\n";


        my %accession_count;
        $accession_count{$_}++ foreach @het_all_accessions;

        my @het_selected_accessions = grep { $accession_count{$_} eq $het_param_count } keys %accession_count;

        print STDERR "ONLY HET SELECTED ACCESSIONS=" .Dumper(\@het_selected_accessions). "\n";

        my $q = "SELECT stock_id, uniquename FROM stock where stock_id IN (" . join(', ', ('?') x @het_selected_accessions) . ")";
        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute(@het_selected_accessions);
        while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
            push @selected_accessions, [$selected_id, $selected_uniquename, $all_markers_string]
        }

    }

    return \@selected_accessions;

}



1;
