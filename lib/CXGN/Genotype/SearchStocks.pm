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
    my %homozygous_nt;
    my @all_het_pairs;
    my @het_all_accessions;
    my @het_selected_accessions;
    my @selected_accessions;
    my %all_markers;
    my $all_markers_string;

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
        my $genotyping_protocol_id = $params{genotyping_protocol_id};

        if ($genotyping_protocol_id){
            $protocol_id = $genotyping_protocol_id
        }

        if ($marker_name){
            my $nt_value = $allele_1.'/'.$allele_2;
            $all_markers{$marker_name} = {'NT' => $nt_value};

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
        }
    }

    my $het_param_count = @all_het_pairs;

    my $homozygous_nt_string;
    if (%homozygous_nt){
        $homozygous_nt_string = encode_json \%homozygous_nt;
    }

    $all_markers_string = encode_json \%all_markers;

#    print STDERR "ALL MARKER=" .Dumper(\%all_markers). "\n";
#    print STDERR "HOMOZYGOUS NT JSON=" .Dumper($homozygous_nt_string). "\n";
#    print STDERR "ALL HET PAIRS=" .Dumper(\@all_het_pairs). "\n";
#    print STDERR "HET PARAM COUNT=" .Dumper($het_param_count). "\n";

    my @loop_accessions;
    if ($homozygous_nt_string){
        my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM dataset_table
            JOIN stock ON (dataset_table.stock_id = stock.stock_id)
            JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
            JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
            JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
            WHERE genotypeprop.value @> ?";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $homozygous_nt_string);

        if ($het_param_count == 0){
            while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
                push @selected_accessions, [$selected_id, $selected_uniquename, $all_markers_string]
            }
        } elsif ($het_param_count != 0){
            while (my @row = $h->fetchrow_array()){
                push @loop_accessions, $row[0]
            }

            for (my $i = 0; $i <= $#all_het_pairs; $i++){
                my $loop_table = "DROP TABLE IF EXISTS loop_table;
                    CREATE TEMP TABLE loop_table(stock_id INT)";
                my $l_t = $schema->storage->dbh()->prepare($loop_table);
                $l_t->execute();

                foreach my $accession(@loop_accessions){
                    my $added_table = "INSERT INTO loop_table (stock_id) VALUES (?)";
                    my $h = $schema->storage->dbh()->prepare($added_table);
                    $h->execute($accession);
                }

                @loop_accessions = ();

                my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM loop_table
                    JOIN stock ON (loop_table.stock_id = stock.stock_id)
                    JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
                    JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
                    JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
                    JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
                    WHERE genotypeprop.value @> ? or genotypeprop.value @> ?";

                my $h = $schema->storage->dbh()->prepare($q);
                $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $all_het_pairs[$i][0], $all_het_pairs[$i][1], @loop_accessions);

                while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
                    if ($i != $#all_het_pairs){
                        push @het_selected_accessions, $selected_id
                    } elsif ($i == $#all_het_pairs) {
                        push @selected_accessions, [$selected_id, $selected_uniquename, $all_markers_string]
                    }
                }
            }
        }
    } elsif (($homozygous_nt_string == 0) && ($het_param_count != 0)){
        my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM dataset_table
            JOIN stock ON (dataset_table.stock_id = stock.stock_id)
            JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
            JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
            JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
            WHERE genotypeprop.value @> ? or genotypeprop.value @> ?";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $all_het_pairs[0][0], $all_het_pairs[0][1]);

        while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
            if ($het_param_count == 1){
                push @selected_accessions, [$selected_id, $selected_uniquename, $all_markers_string]
            } else {
                push @het_selected_accessions, $selected_id
            }

        }

        for (my $i = 1; $i <= $#all_het_pairs; $i++){
            my $loop_table = "DROP TABLE IF EXISTS loop_table;
                CREATE TEMP TABLE loop_table(stock_id INT)";
            my $l_t = $schema->storage->dbh()->prepare($loop_table);
            $l_t->execute();

            foreach my $het_accession(@het_selected_accessions){
                my $added_table = "INSERT INTO loop_table (stock_id) VALUES (?)";
                my $h = $schema->storage->dbh()->prepare($added_table);
                $h->execute($het_accession);
            }

            @het_selected_accessions = ();

            my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM loop_table
                JOIN stock ON (loop_table.stock_id = stock.stock_id)
                JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
                JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
                JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
                JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
                WHERE genotypeprop.value @> ? or genotypeprop.value @> ?";

            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $all_het_pairs[$i][0], $all_het_pairs[$i][1]);

            while (my ($selected_id, $selected_uniquename) = $h->fetchrow_array()){
                if ($i != $#all_het_pairs){
                    push @het_selected_accessions, $selected_id
                } else {
                    push @selected_accessions, [$selected_id, $selected_uniquename, $all_markers_string]
                }
            }
        }

    }

    return \@selected_accessions;

}


1;
