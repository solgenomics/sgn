package CXGN::Phenotypes::MetaDataMatrix;

=head1 NAME

CXGN::Phenotypes::MetaDataMatrix - an object to handle creating the meta-data matrix. Uses SearchFactory to handle searching native (MetaData) database.

=head1 USAGE

my $metadata_search = CXGN::Phenotypes::MetaDataMatrix->new(
    bcs_schema=>$schema,
    search_type=>$factory_type,
    data_level=>$data_level,
    trial_list=>$trial_list,    		
);
my @data = $metadata_search->get_metadata_matrix();

=head1 DESCRIPTION


=head1 AUTHORS

Alex Ogbonna <aco46@cornell.edu>

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

#(MetaData)
has 'search_type' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

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

    my @info = ();
    my @line;
    @line = ( 'studyYear', 'studyName', 'locationName', 'studyDesign', 'breedingProgram', 'trialDescription', 'trialType', 'plotLength', 'plotWidth', 'plantPerPlot', 'blockNumber', 'repNumber', 'plantingDate', 'harvestDate' );
     
    # generate header line
    #
    push @info, \@line;

    foreach my $p (@unique_plot_list) {
        my @line = @{$plot_data{$p}->{metadata}};
        push @info, \@line;
    }
    #print STDERR Dumper \@info;
    print STDERR "Construct Meta-data Matrix End:".localtime."\n";
    return @info;
}

1;
