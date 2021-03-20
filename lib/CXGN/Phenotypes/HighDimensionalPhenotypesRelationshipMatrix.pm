package CXGN::Phenotypes::HighDimensionalPhenotypesRelationshipMatrix;

=head1 NAME

CXGN::Phenotypes::HighDimensionalPhenotypesRelationshipMatrix - an object to handle creating a relationship matrix from high dimensional phenotypes (NIRS, Metabolomics, Transcriptomics).

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesRelationshipMatrix->new({
    bcs_schema=>$schema,
    nd_protocol_id=>$nd_protocol_id,
    temporary_data_file=>$temp_data_file, #A temporary file path where to store the data used to create the relationship matrix
    relationship_matrix_file=>$relationship_matrix_file, #A file path where the relationship matrix will be written
    high_dimensional_phenotype_type=>$high_dimensional_phenotype_type, #NIRS, Transcriptomics, or Metabolomics
    high_dimensional_phenotype_identifier_list=>\@high_dimensional_phenotype_identifier_list,
    query_associated_stocks=>$query_associated_stocks, #Query associated plots, plants, tissue samples, etc for accessions that are given
    accession_list=>$accession_ids,
    plot_list=>$plot_ids,
    plant_list=>$plant_ids,
});
my (\%relationship_matrix_data, \@data, \%identifier_metadata, \@identifier_names) = $phenotypes_search->search();

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
use CXGN::Phenotypes::HighDimensionalPhenotypesSearch;
use Text::CSV;

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

has 'temporary_data_file' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'relationship_matrix_file' => (
    isa => 'Str',
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
    my $temporary_data_file = $self->temporary_data_file();
    my $relationship_matrix_file = $self->relationship_matrix_file();
    my $dbh = $schema->storage->dbh();

    if (!$accession_ids && !$plot_ids && !$plant_ids) {
        return { error => "No accessions or plots or plants in your selected dataset!" };
    }

    my $data_term;
    if ($high_dimensional_phenotype_type eq 'NIRS') {
        $data_term = 'spectra';
    }
    elsif ($high_dimensional_phenotype_type eq 'Transcriptomics') {
        $data_term = 'transcriptomics';
    }
    elsif ($high_dimensional_phenotype_type eq 'Metabolomics') {
        $data_term = 'metabolomics';
    }
    else {
        return { error => "$high_dimensional_phenotype_type is not supported!" };
    }

    my $phenotypes_search = CXGN::Phenotypes::HighDimensionalPhenotypesSearch->new({
        bcs_schema=>$schema,
        nd_protocol_id=>$nd_protocol_id,
        high_dimensional_phenotype_type=>$high_dimensional_phenotype_type, #NIRS, Transcriptomics, or Metabolomics
        high_dimensional_phenotype_identifier_list=>$high_dimensional_phenotype_identifier_list,
        query_associated_stocks=>$query_associated_stocks, #Query associated plots, plants, tissue samples, etc for accessions that are given
        accession_list=>$accession_ids,
        plot_list=>$plot_ids,
        plant_list=>$plant_ids,
    });
    my ($data_hash, $identifier_metadata_hash, $identifier_names_array) = $phenotypes_search->search();

    my %high_dimensional_phenotype_identifier_list_hash = map {$_ => 1} @$high_dimensional_phenotype_identifier_list;

    my @data_matrix;
    while (my ($stock_id, $s) = each %$data_hash) {
        my @row = ($stock_id);
        while (my ($ident, $value) = each %{$s->{$data_term}}) {
            if ($high_dimensional_phenotype_identifier_list && scalar(@$high_dimensional_phenotype_identifier_list) > 0) {
                if (exists($high_dimensional_phenotype_identifier_list_hash{$ident})) {
                    push @row, $value;
                }
            }
            else {
                push @row, $value;
            }
        }
        push @data_matrix, \@row;
    }

    open(my $F, ">", $temporary_data_file) || die "Can't open file ".$temporary_data_file;
        foreach (@data_matrix) {
            my $line = join "\t", @$_;
            print $F $line."\n";
        }
    close($F);

    my $cmd = 'R -e "library(data.table);
    mat <- fread(\''.$temporary_data_file.'\', header=FALSE, sep=\'\t\');
    data_mat <- data.matrix(mat[,-1]);
    rel_mat <- data_mat %*% t(data_mat);
    rel_mat <- rel_mat / ncol(data_mat);
    rownames(rel_mat) <- mat\$V1;
    colnames(rel_mat) <- mat\$V1;
    write.table(rel_mat, file=\''.$relationship_matrix_file.'\', row.names=TRUE, col.names=NA, sep=\'\t\');
    "';
    my $cmd_status = system($cmd);

    my %rel_matrix_data;
    my $csv = Text::CSV->new({ sep_char => "\t" });
    open(my $rel_res, '<', $relationship_matrix_file) or die "Could not open file '$relationship_matrix_file' $!";
        print STDERR "Opened $relationship_matrix_file\n";
        my $header_row = <$rel_res>;
        my @header;
        if ($csv->parse($header_row)) {
            @header = $csv->fields();
        }

        while (my $row = <$rel_res>) {
            my @columns;
            if ($csv->parse($row)) {
                @columns = $csv->fields();
            }
            my $stock_id1 = $columns[0];
            my $counter = 1;
            foreach my $stock_id2 (@header) {
                my $val = $columns[$counter];
                $rel_matrix_data{$stock_id1}->{$stock_id2} = $val;
                $counter++;
            }
        }
    close($rel_res);

    # print STDERR Dumper \%rel_matrix_data;
    # print STDERR Dumper \@data_matrix;
    # print STDERR Dumper $identifier_metadata_hash;
    # print STDERR Dumper $identifier_names_array;
    return (\%rel_matrix_data, \@data_matrix, $identifier_metadata_hash, $identifier_names_array);
}

1;
