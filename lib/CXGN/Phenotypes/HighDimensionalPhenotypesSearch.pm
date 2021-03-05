package CXGN::Phenotypes::HighDimensionalPhenotypesSearch;

=head1 NAME

CXGN::Phenotypes::HighDimensionalPhenotypesSearch - an object to handle searching high dim phenotypes (NIRS, Trnascriptomics, Metabolomics) across database.

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
    bcs_schema=>$schema,
    nd_protocol_id=>$nd_protocol_id,
    high_dimensional_phenotype_type=>$high_dimensional_phenotype_type, #NIRS, Transcriptomics, or Metabolomics
    high_dimensional_phenotype_identifier_list=>\@high_dimensional_phenotype_identifier_list,
    query_associated_stocks=>$query_associated_stocks, #Query associated plots, plants, tissue samples, etc for accessions that are given
    accession_list=>$accession_ids,
    plot_list=>$plot_ids,
    plant_list=>$plant_ids,
});
my (\%data, \%identifier_metadata, \@identifier_names) = $phenotypes_search->search();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Try::Tiny;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Trial::TrialLayout;
use CXGN::Calendar;
use JSON;
use CXGN::Phenotypes::HighDimensionalPhenotypeProtocol;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'high_dimensional_phenotype_type' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'nd_protocol_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

has 'query_associated_stocks' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 1
);

has 'high_dimensional_phenotype_identifier_list' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw',
);

has 'accession_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'plot_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'plant_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

sub search {
    my $self = shift;
    my $schema = $self->bcs_schema();
    my $nd_protocol_id = $self->nd_protocol_id();
    my $high_dimensional_phenotype_type = $self->high_dimensional_phenotype_type();
    my $high_dimensional_phenotype_identifier_list = $self->high_dimensional_phenotype_identifier_list();
    my $accession_ids = $self->accession_list();
    my $plot_ids = $self->plot_list();
    my $plant_ids = $self->plant_list();
    my $query_associated_stocks = $self->query_associated_stocks();
    my $dbh = $schema->storage->dbh();

    if (!$accession_ids && !$plot_ids && !$plant_ids) {
        return { error => "No accessions or plots or plants in your selected dataset!" };
    }

    my @all_stock_ids;
    if ($query_associated_stocks) {
        if ($accession_ids && scalar(@$accession_ids) > 0) {
            push @all_stock_ids, @$accession_ids;
        }
        if ($plot_ids && scalar(@$plot_ids) > 0) {
            push @all_stock_ids, @$plot_ids;
        }
        if ($plant_ids && scalar(@$plant_ids) > 0) {
            push @all_stock_ids, @$plant_ids;
        }

        my $accession_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
        my $plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
        my $plant_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
        my $tissue_sample_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();

        my $plot_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_of', 'stock_relationship')->cvterm_id();
        my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
        my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();

        if ($accession_ids && scalar(@$accession_ids) > 0) {
            my $accession_ids_sql = join ',', @$accession_ids;
            my $accession_q = "SELECT subject_id FROM stock_relationship WHERE object_id IN ($accession_ids_sql) AND type_id IN ($plot_of_cvterm_id, $plant_of_cvterm_id, $tissue_sample_of_cvterm_id);";
            my $accession_h = $dbh->prepare($accession_q);
            $accession_h->execute();
            while (my ($stock_id) = $accession_h->fetchrow_array()) {
                push @all_stock_ids, $stock_id;
            }
        }
        if ( ($plot_ids && scalar(@$plot_ids) > 0) || ($plant_ids && scalar(@$plant_ids) > 0) ) {
            my @plot_plant_ids;
            if ($plot_ids && scalar(@$plot_ids) > 0) {
                push @plot_plant_ids, @$plot_ids;
            }
            if ($plant_ids && scalar(@$plant_ids) > 0) {
                push @plot_plant_ids, @$plant_ids;
            }
            my $plot_ids_sql = join ',', @plot_plant_ids;
            my $plot_q = "SELECT object_id FROM stock_relationship WHERE subject_id IN ($plot_ids_sql) AND type_id IN ($plot_of_cvterm_id, $plant_of_cvterm_id, $tissue_sample_of_cvterm_id);";
            my $plot_h = $dbh->prepare($plot_q);
            $plot_h->execute();
            while (my ($stock_id) = $plot_h->fetchrow_array()) {
                push @all_stock_ids, $stock_id;
            }

            my $accession_ids_sql = join ',', @all_stock_ids;
            my $accession_q = "SELECT subject_id FROM stock_relationship WHERE object_id IN ($accession_ids_sql) AND type_id IN ($plot_of_cvterm_id, $plant_of_cvterm_id, $tissue_sample_of_cvterm_id);";
            my $accession_h = $dbh->prepare($accession_q);
            $accession_h->execute();
            while (my ($stock_id) = $accession_h->fetchrow_array()) {
                push @all_stock_ids, $stock_id;
            }
        }
    }
    else {
        if ($accession_ids && scalar(@$accession_ids) > 0) {
            push @all_stock_ids, @$accession_ids;
        }
        if ($plot_ids && scalar(@$plot_ids) > 0) {
            push @all_stock_ids, @$plot_ids;
        }
        if ($plant_ids && scalar(@$plant_ids) > 0) {
            push @all_stock_ids, @$plant_ids;
        }
    }

    # print STDERR Dumper \@all_stock_ids;
    my $stock_ids_sql = join ',', @all_stock_ids;

    my %data_matrix;
    my $protocol_type_cvterm_id;

    if ($high_dimensional_phenotype_type eq 'NIRS') {
        my $q = "SELECT stock.uniquename, stock.stock_id, metadata.md_json.json->>'spectra', metadata.md_json.json->>'device_type'
            FROM stock
            JOIN nd_experiment_phenotype_bridge USING(stock_id)
            JOIN metadata.md_json USING(json_id)
            WHERE stock.stock_id IN ($stock_ids_sql) AND nd_experiment_phenotype_bridge.nd_protocol_id = ? AND metadata.md_json.json_type = 'nirs_spectra';";
        print STDERR Dumper $q;
        my $h = $dbh->prepare($q);
        $h->execute($nd_protocol_id);
        while (my ($stock_uniquename, $stock_id, $spectra, $device_type) = $h->fetchrow_array()) {
            $spectra = decode_json $spectra;
            $data_matrix{$stock_id}->{spectra} = $spectra;
            $data_matrix{$stock_id}->{device_type} = $device_type;
        }

        $protocol_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_nirs_protocol', 'protocol_type')->cvterm_id();
    }
    elsif ($high_dimensional_phenotype_type eq 'Transcriptomics') {
        my $q = "SELECT stock.uniquename, stock.stock_id, metadata.md_json.json
            FROM stock
            JOIN nd_experiment_phenotype_bridge USING(stock_id)
            JOIN metadata.md_json USING(json_id)
            WHERE stock.stock_id IN ($stock_ids_sql) AND nd_experiment_phenotype_bridge.nd_protocol_id = ? AND metadata.md_json.json_type = 'transcriptomics';";
        print STDERR Dumper $q;
        my $h = $dbh->prepare($q);
        $h->execute($nd_protocol_id);
        while (my ($stock_uniquename, $stock_id, $transcriptomics) = $h->fetchrow_array()) {
            $transcriptomics = decode_json $transcriptomics;
            $data_matrix{$stock_id}->{transcriptomics} = $transcriptomics;
        }

        $protocol_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_transcriptomics_protocol', 'protocol_type')->cvterm_id();
    }
    elsif ($high_dimensional_phenotype_type eq 'Metabolomics') {
        my $q = "SELECT stock.uniquename, stock.stock_id, metadata.md_json.json
            FROM stock
            JOIN nd_experiment_phenotype_bridge USING(stock_id)
            JOIN metadata.md_json USING(json_id)
            WHERE stock.stock_id IN ($stock_ids_sql) AND nd_experiment_phenotype_bridge.nd_protocol_id = ? AND metadata.md_json.json_type = 'metabolomics';";
        print STDERR Dumper $q;
        my $h = $dbh->prepare($q);
        $h->execute($nd_protocol_id);
        while (my ($stock_uniquename, $stock_id, $metabolomics) = $h->fetchrow_array()) {
            $metabolomics = decode_json $metabolomics;
            $data_matrix{$stock_id}->{metabolomics} = $metabolomics;
        }

        $protocol_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'high_dimensional_phenotype_metabolomics_protocol', 'protocol_type')->cvterm_id();
    }
    else {
        die "NOT A VALID HIGHDIMENSIONAL PHENOTYPE TYPE $high_dimensional_phenotype_type\n";
    }

    my $protocol = CXGN::Phenotypes::HighDimensionalPhenotypeProtocol->new({
        bcs_schema => $schema,
        nd_protocol_id => $nd_protocol_id,
        nd_protocol_type_id => $protocol_type_cvterm_id
    });
    my $identifier_metadata = $protocol->header_column_details;
    my $identifier_names = $protocol->header_column_names;

    # print STDERR Dumper \%data_matrix;
    # print STDERR Dumper $identifier_metadata;
    # print STDERR Dumper $identifier_names;
    return (\%data_matrix, $identifier_metadata, $identifier_names);
}

1;
