package CXGN::Phenotypes::PhenotypeMatrix;

=head1 NAME

CXGN::Phenotypes::PhenotypeMatrix - an object to handle creating the phenotype matrix. Uses SearchFactory to handle searching native database or materialized views.

=head1 USAGE

my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
    bcs_schema=>$schema,
    search_type=>$search_type,
    data_level=>$data_level,
    trait_list=>$trait_list,
    trial_list=>$trial_list,
    year_list=>$year_list,
    location_list=>$location_list,
    accession_list=>$accession_list,
    plot_list=>$plot_list,
    plant_list=>$plant_list,
    include_timestamp=>$include_timestamp,
    trait_contains=>$trait_contains,
    phenotype_min_value=>$phenotype_min_value,
    phenotype_max_value=>$phenotype_max_value,
    limit=>$limit,
    offset=>$offset
);
my @data = $phenotypes_search->get_phenotype_matrix();

=head1 DESCRIPTION


=head1 AUTHORS


=cut

use strict;
use warnings;
use Moose;
use Data::Dumper;
use SGN::Model::Cvterm;
use CXGN::Stock::StockLookup;
use CXGN::Phenotypes::SearchFactory;

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
);

#(Native or MaterializedView)
has 'search_type' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

#(plot, plant, or all)
has 'data_level' => (
    isa => 'Str|Undef',
    is => 'ro',
);

has 'trial_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'trait_list' => (
    isa => 'ArrayRef[Int]|Undef',
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

has 'subplot_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'location_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'year_list' => (
    isa => 'ArrayRef[Int]|Undef',
    is => 'rw',
);

has 'include_timestamp' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'include_row_and_column_numbers' => (
    isa => 'Bool|Undef',
    is => 'ro',
    default => 0
);

has 'trait_contains' => (
    isa => 'ArrayRef[Str]|Undef',
    is => 'rw'
);

has 'phenotype_min_value' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'phenotype_max_value' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'limit' => (
    isa => 'Int|Undef',
    is => 'rw'
);

has 'offset' => (
    isa => 'Int|Undef',
    is => 'rw'
);

sub get_phenotype_matrix {
    my $self = shift;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        $self->search_type,
        {
            bcs_schema=>$self->bcs_schema,
            data_level=>$self->data_level,
            trait_list=>$self->trait_list,
            trial_list=>$self->trial_list,
            year_list=>$self->year_list,
            location_list=>$self->location_list,
            accession_list=>$self->accession_list,
            plot_list=>$self->plot_list,
            plant_list=>$self->plant_list,
            subplot_list=>$self->subplot_list,
            include_timestamp=>$self->include_timestamp,
            include_row_and_column_numbers=>$self->include_row_and_column_numbers,
            trait_contains=>$self->trait_contains,
            phenotype_min_value=>$self->phenotype_min_value,
            phenotype_max_value=>$self->phenotype_max_value,
            limit=>$self->limit,
            offset=>$self->offset
        }
    );

    my $data = $phenotypes_search->search();
    #print STDERR Dumper $data;
    my %plot_data;
    my %traits;
    my $include_timestamp = $self->include_timestamp;

    print STDERR "No of lines retrieved: ".scalar(@$data)."\n";
    print STDERR "Construct Pheno Matrix Start:".localtime."\n";
    my @unique_plot_list = ();
    my %seen_plots;
    foreach my $d (@$data) {
        my ($year, $project_name, $stock_name, $location, $cvterm, $value, $plot_name, $rep, $block_number, $plot_number, $row_number, $col_number, $trait_id, $project_id, $location_id, $stock_id, $plot_id, $timestamp_value, $synonyms, $design, $stock_type_name, $phenotype_id) = @$d;

        if ($cvterm){
            if (!exists($seen_plots{$plot_id})) {
                push @unique_plot_list, $plot_id;
                $seen_plots{$plot_id} = 1;
            }
 
            #my $cvterm = $trait."|".$cvterm_accession;
            if ($include_timestamp && $timestamp_value) {
                $plot_data{$plot_id}->{$cvterm} = "$value,$timestamp_value";
            } else {
                $plot_data{$plot_id}->{$cvterm} = $value;
            }
            my $synonym_string = $synonyms ? join ("," , @$synonyms) : '';
            if ($self->include_row_and_column_numbers){
                $plot_data{$plot_id}->{metadata} = [$year,$project_id,$project_name,$design,$location_id,$location,$stock_id,$stock_name,$synonym_string,$stock_type_name,$plot_id,$plot_name,$rep,$block_number,$plot_number,$row_number,$col_number];
            } else {
                $plot_data{$plot_id}->{metadata} = [$year,$project_id,$project_name,$design,$location_id,$location,$stock_id,$stock_name,$synonym_string,$stock_type_name,$plot_id,$plot_name,$rep,$block_number,$plot_number];
            }
            $traits{$cvterm}++;
        }
    }
    #print STDERR Dumper \%plot_data;
    #print STDERR Dumper \%traits;

    my @info = ();
    my @line;
    if ($self->include_row_and_column_numbers){
        @line = ( 'studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber', 'rowNumber', 'colNumber' );
    } else {
        @line = ( 'studyYear', 'studyDbId', 'studyName', 'studyDesign', 'locationDbId', 'locationName', 'germplasmDbId', 'germplasmName', 'germplasmSynonyms', 'observationLevel', 'observationUnitDbId', 'observationUnitName', 'replicate', 'blockNumber', 'plotNumber' );
    }

    # generate header line
    #
    my @sorted_traits = sort keys(%traits);
    foreach my $trait (@sorted_traits) {
        push @line, $trait;
    }
    push @info, \@line;

    #print STDERR Dumper \@unique_plot_list;

    foreach my $p (@unique_plot_list) {
        my @line = @{$plot_data{$p}->{metadata}};

        foreach my $trait (@sorted_traits) {
            push @line, $plot_data{$p}->{$trait};
        }
        push @info, \@line;
    }

    #print STDERR Dumper \@info;
    print STDERR "Construct Pheno Matrix End:".localtime."\n";
    return @info;
}

1;
