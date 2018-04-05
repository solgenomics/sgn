package CXGN::Phenotypes::MetaDataMatrix;

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
    include_row_and_column_numbers=>0,
    exclude_phenotype_outlier=>0,
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


sub get_metadata_matrix {
    my $self = shift;

    my $phenotypes_search = CXGN::Phenotypes::SearchFactory->instantiate(
        $self->search_type,
        {
            bcs_schema=>$self->bcs_schema, 
            data_level=>$self->data_level,
            trial_list=>$self->trial_list,
        }
    );

    my $data = $phenotypes_search->search();
    #print STDERR Dumper $data;

    print STDERR "No of lines retrieved: ".scalar(@$data)."\n";
    print STDERR "Construct Meta-data Matrix Start:".localtime."\n";
    my @unique_plot_list = ();
    my %plot_data;
    #if ($self->data_level eq 'metadata'){
       sub uniq {
         my %seen;
         grep !$seen{$_}++, @_;
       }
       foreach my $d (@$data) {
           my ($year,$project_name,$location,$design,$breeding_program,$trial_desc,$trial_type,$plot_length,$plot_width,$plants_per_plot,$number_of_blocks,$number_of_replicates,$planting_date,$harvest_date) = @$d;
           $plot_data{$project_name}->{metadata} = [$year,$project_name,$location,$design,$breeding_program,$trial_desc,$trial_type,$plot_length,$plot_width,$plants_per_plot,$number_of_blocks,$number_of_replicates,$planting_date,$harvest_date];
           push @unique_plot_list, $project_name;
       }
       @unique_plot_list = uniq(@unique_plot_list);
    # }

    my @info = ();
    my @line;
    @line = ( 'studyYear', 'studyName', 'locationName', 'studyDesign', 'breedingProgram', 'trialDescription', 'trialType', 'plotLength', 'plotWidth', 'plantPerPlot', 'blockNumber', 'repNumber', 'plantingDate', 'harvestDate' );
     
    # generate header line
    #
    push @info, \@line;

    #print STDERR Dumper \@unique_plot_list;

    foreach my $p (@unique_plot_list) {
        my @line = @{$plot_data{$p}->{metadata}};
        push @info, \@line;
    }

    #print STDERR Dumper \@info;
    print STDERR "Construct Meta-data Matrix End:".localtime."\n";
    return @info;
}

1;
