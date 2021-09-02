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
use Sort::Key::Natural qw(natsort);

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
    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $vcf_map_details_markers_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details_markers', 'protocol_property')->cvterm_id();

    my @selected_stocks;
    my $protocol_id;
    my $data_type;

    my %chrom_hash;
    foreach my $param (@parameters){
        my $param_ref = decode_json$param;
        my %params = %{$param_ref};
        my $marker_name = $params{marker_name};
        my $genotyping_protocol_id = $params{genotyping_protocol_id};
        my $genotyping_data_type = $params{genotyping_data_type};
#        print STDERR "DATA TYPE =".Dumper($genotyping_data_type)."\n";
        if ($genotyping_protocol_id){
            $protocol_id = $genotyping_protocol_id
        }

        if ($genotyping_data_type){
            $data_type = $genotyping_data_type;
        }

        if ($data_type eq 'Dosage') {
            if ($marker_name){
                my $allele_dosage = $params{allele_dosage};

                my $chrom_key;
                my $q = "SELECT value->?->>'chrom' FROM nd_protocolprop WHERE nd_protocol_id = ? AND type_id =? ";

                my $h = $schema->storage->dbh()->prepare($q);
                $h->execute($marker_name, $protocol_id, $vcf_map_details_markers_cvterm_id);

                while (my ($chrom) = $h->fetchrow_array()){
                    if ($chrom) {
                        print STDERR "CHROMOSOME NO =".Dumper($chrom)."\n";
                        $chrom_hash{$chrom}{$marker_name}{'DS'} = $allele_dosage
                    }
                }
            }
        } elsif ($data_type eq 'SNP') {
            if ($marker_name) {
                my $allele_1 = $params{allele1};
                my $allele_2 = $params{allele2};
                my @allele_param = ($allele_1, $allele_2);

                my @ref_alt_chrom = ();

                my $q = "SELECT value->?->>'ref', value->?->>'alt', value->?->>'chrom'
                FROM nd_protocolprop WHERE nd_protocol_id = ? AND type_id =? ";

                my $h = $schema->storage->dbh()->prepare($q);
                $h->execute($marker_name, $marker_name, $marker_name, $protocol_id, $vcf_map_details_markers_cvterm_id);

                while (my ($ref, $alt, $chrom) = $h->fetchrow_array()){
                    if ($ref) {
                        push @ref_alt_chrom, $ref
                    }
                    if ($alt) {
                        push @ref_alt_chrom, $alt
                    }
                    if ($chrom) {
                        push @ref_alt_chrom, $chrom
                    }
                }
                print STDERR "REF ALT CHROM=" .Dumper(\@ref_alt_chrom). "\n";
                my @nt = ();

                if ($allele_1 ne $allele_2){
                    foreach my $allele(@allele_param){
                        if (grep{/$allele/}(@ref_alt_chrom)){
                            if ($allele eq $ref_alt_chrom[0]){
                                $nt[0] = $allele;
                            } elsif ($allele eq $ref_alt_chrom[1]){
                                $nt[1] = $allele;
                            }
                            my $nt_string = join(",", @nt);
                            $chrom_hash{$ref_alt_chrom[2]}{$marker_name} = {'NT' => $nt_string};
                        } else {
                            last;
                        }
                    }
                } elsif ($allele_1 eq $allele_2){
                    if (grep{/$allele_1/}(@ref_alt_chrom)){
                        @nt = ($allele_1, $allele_2);
                        my $nt_string = join(",", @nt);
                        $chrom_hash{$ref_alt_chrom[2]}{$marker_name} = {'NT' => $nt_string};
                    } else {
                        last;
                   }
               }
            }
        }
    }

    my @formatted_parameters;
    if (%chrom_hash) {
        foreach my $chromosome (keys %chrom_hash) {
            my $marker_params = $chrom_hash{$chromosome};
            my $each_chrom_markers_string = encode_json $marker_params;
            push @formatted_parameters, $each_chrom_markers_string
        }
    }

    my @sorted_markers = natsort @formatted_parameters;
    my $genotype_string = join("<br>", @sorted_markers);

#    my $number_of_param_sets = @formatted_parameters;

#    my $stock_table = "DROP TABLE IF EXISTS stock_table;
#        CREATE TEMP TABLE stock_table(stock_name Varchar(100))";
#    my $s_t = $schema->storage->dbh()->prepare($stock_table);
#    $s_t->execute();

#    foreach my $st(@stocks){
#        my $added_table = "INSERT INTO stock_table (stock_name) VALUES (?)";
#        my $h = $schema->storage->dbh()->prepare($added_table);
#        $h->execute($st);
#    }

#    my @all_selected_stocks;
#    foreach my $param (@formatted_parameters) {
#        my $q = "SELECT DISTINCT stock.stock_id FROM stock_table
#            JOIN stock ON (stock_table.stock_name = stock.uniquename)
#            JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
#            JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
#            JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
#            JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
#            WHERE genotypeprop.value @> ? ";

#        my $h2 = $schema->storage->dbh()->prepare($q);
#        $h2->execute($genotyping_experiment_cvterm_id, $protocol_id, $param);

#        while (my ($selected_stock_id) = $h2->fetchrow_array()){
#            push @all_selected_stocks, $selected_stock_id
#        }
#    }

#    my %count;
#    $count{$_}++ foreach @all_selected_stocks;

#    while (my ($stock_id, $value) = each(%count)) {
#        if ($value == $number_of_param_sets) {
#            push @selected_stocks, $stock_id
#        }
#    }

#        print STDERR "SELECTED STOCKS =".Dumper(\@selected_stocks)."\n";
    my @selected_stocks_details;
    foreach my $param (@formatted_parameters) {
        my $stock_table = "DROP TABLE IF EXISTS stock_table;
            CREATE TEMP TABLE stock_table(stock_name Varchar(100))";
        my $s_t = $schema->storage->dbh()->prepare($stock_table);
        $s_t->execute();

        foreach my $st(@stocks){
            my $added_table = "INSERT INTO stock_table (stock_name) VALUES (?)";
            my $h = $schema->storage->dbh()->prepare($added_table);
            $h->execute($st);
        }

        @stocks = ();
        @selected_stocks_details = ();
        my $q = "SELECT DISTINCT stock.stock_id, stock.uniquename FROM stock_table
            JOIN stock ON (stock_table.stock_name = stock.uniquename)
            JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
            JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
            JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
            JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
            WHERE genotypeprop.value @> ? ";

        my $h2 = $schema->storage->dbh()->prepare($q);
        $h2->execute($genotyping_experiment_cvterm_id, $protocol_id, $param);

        while (my ($selected_stock_id, $selected_stock_name) = $h2->fetchrow_array()){
            push @selected_stocks_details, [$selected_stock_id, $selected_stock_name, $genotype_string ];
            push @stocks, $selected_stock_name
        }
    }

#    my @selected_stocks_details;

#    if (scalar(@stocks) > 0) {
#        my $selected_stocks_sql = join ("," , @stocks);

#        my $q2 = "SELECT stock.stock_id, stock.uniquename FROM stock where stock.stock_id in ($selected_stocks_sql)  ORDER BY stock.stock_id ASC";
#        my $q2 = "SELECT stock.stock_id, stock.uniquename FROM stock where stock.uniquename in ($selected_stocks_sql)  ORDER BY stock.stock_id ASC";

#        my $h4 = $schema->storage->dbh()->prepare($q2);
#        $h4->execute();

#        while (my ($selected_id, $selected_uniquename) = $h4->fetchrow_array()){
#            push @selected_stocks_details, [$selected_id, $selected_uniquename, $genotype_string ]
#        }
#    }

    return \@selected_stocks_details;

}


sub get_accessions_using_snps {
    my $self = shift;
    my $schema = $self->bcs_schema;
    my $accession_list = $self->stock_list;
    my $filtering_parameters = $self->filtering_parameters;
    my @accessions = @{$accession_list};
    my @parameters = @{$filtering_parameters};

    my $genotyping_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'genotyping_experiment', 'experiment_type')->cvterm_id();
    my $vcf_map_details_markers_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->bcs_schema, 'vcf_map_details_markers', 'protocol_property')->cvterm_id();

    my $protocol_id;
    my %genotype_nt;
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

    my %chrom_hash;
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
        print STDERR "PROTOCOL ID PARAM =".Dumper($genotyping_protocol_id)."\n";
        if ($marker_name){
            my @ref_alt_chrom = ();

            my $q = "SELECT value->?->>'ref', value->?->>'alt', value->?->>'chrom'
                FROM nd_protocolprop WHERE nd_protocol_id = ? AND type_id =? ";

            my $h = $schema->storage->dbh()->prepare($q);
            $h->execute($marker_name, $marker_name, $marker_name, $protocol_id, $vcf_map_details_markers_cvterm_id);

            while (my ($ref, $alt, $chrom) = $h->fetchrow_array()){
                if ($ref) {
                    push @ref_alt_chrom, $ref
                }
                if ($alt) {
                    push @ref_alt_chrom, $alt
                }
                if ($chrom) {
                    push @ref_alt_chrom, $chrom
                }
            }
            print STDERR "REF ALT CHROM=" .Dumper(\@ref_alt_chrom). "\n";

            my @nt = ();

            if ($allele_1 ne $allele_2){
                foreach my $allele(@allele_param){
                    if (grep{/$allele/}(@ref_alt_chrom)){
                        if ($allele eq $ref_alt_chrom[0]){
                            $nt[0] = $allele;
                        } elsif ($allele eq $ref_alt_chrom[1]){
                            $nt[1] = $allele;
                        }

                        my $nt_string = join(",", @nt);
                        $genotype_nt{$ref_alt_chrom[2]}{$marker_name} = {'NT' => $nt_string};
                    } else {
                        last;
                    }
                }
            } elsif ($allele_1 eq $allele_2){
                if (grep{/$allele_1/}(@ref_alt_chrom)){
                    @nt = ($allele_1, $allele_2);
                    my $nt_string = join(",", @nt);
                    $genotype_nt{$ref_alt_chrom[2]}{$marker_name} = {'NT' => $nt_string};
                 } else {
                    last;
                }
            }
        }
    }

    my @formatted_parameters;
    if (%genotype_nt) {
        foreach my $chromosome (keys %genotype_nt) {
            my $marker_params = $genotype_nt{$chromosome};
            my $each_chrom_markers_string = encode_json $marker_params;
            push @formatted_parameters, $each_chrom_markers_string
        }
    }

    my @sorted_markers = natsort @formatted_parameters;
    my $genotype_string = join("<br>", @sorted_markers);

    my $number_of_param_sets = @formatted_parameters;

    my @all_selected_stocks;
    foreach my $param (@formatted_parameters) {
        my $q = "SELECT DISTINCT stock.stock_id FROM dataset_table
        JOIN stock ON (dataset_table.stock_id = stock.stock_id)
        JOIN nd_experiment_stock ON (stock.stock_id = nd_experiment_stock.stock_id)
        JOIN nd_experiment_protocol ON (nd_experiment_stock.nd_experiment_id = nd_experiment_protocol.nd_experiment_id) AND nd_experiment_stock.type_id = ? AND nd_experiment_protocol.nd_protocol_id =?
        JOIN nd_experiment_genotype on (nd_experiment_genotype.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN genotypeprop on (nd_experiment_genotype.genotype_id = genotypeprop.genotype_id)
        WHERE genotypeprop.value @> ? ORDER BY stock.stock_id ASC";

        my $h = $schema->storage->dbh()->prepare($q);
        $h->execute($genotyping_experiment_cvterm_id, $protocol_id, $param);

        while (my ($selected_id) = $h->fetchrow_array()){
            push @all_selected_stocks, $selected_id
        }
    }

    my @selected_stocks;
    my %count;
    $count{$_}++ foreach @all_selected_stocks;

    while (my ($stock_id, $value) = each(%count)) {
        if ($value == $number_of_param_sets) {
            push @selected_stocks, $stock_id
        }
    }
#    print STDERR "SELECTED STOCKS =".Dumper(\@selected_stocks)."\n";
    my @selected_stocks_details;

    if (scalar(@selected_stocks) > 0) {
        my $selected_stocks_sql = join ("," , @selected_stocks);

        my $q2 = "SELECT stock.stock_id, stock.uniquename FROM stock where stock.stock_id in ($selected_stocks_sql)  ORDER BY stock.stock_id ASC";

        my $h2 = $schema->storage->dbh()->prepare($q2);
        $h2->execute();

        while (my ($selected_id, $selected_uniquename) = $h2->fetchrow_array()){
            push @selected_stocks_details, [$selected_id, $selected_uniquename, $genotype_string ]
        }
    }

    return \@selected_stocks_details;

}

1;
