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

    my %project_data;
    foreach my $d (@$data) {
        my ($project_id, $project_name, $project_description, $trial_type, $breeding_program_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_id, $location_name, $planting_date_value, $harvest_date_value, $plot_width, $plot_length, $plants_per_plot, $number_of_blocks, $number_of_replicates, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $folder_id, $folder_name, $folder_description, $treatments) = @$d;

        my $treatments_string = '';
        while (my($treatment_name, $treatment_description) = each %$treatments){
            $treatments_string .= " ".$treatment_name.": ".$treatment_description;
        }

        $project_data{$project_name}->{metadata} = [$project_id, $project_name, $project_description, $trial_type, $breeding_program_id, $breeding_program_name, $breeding_program_description, $year, $design, $location_id, $location_name, $planting_date_value, $harvest_date_value, $plot_width, $plot_length, $plants_per_plot, $number_of_blocks, $number_of_replicates, $field_size, $field_trial_is_planned_to_be_genotyped, $field_trial_is_planned_to_cross, $folder_id, $folder_name, $folder_description, $treatments_string];
    }

    my @info = ();
    my @line = ( 'studyDbId', 'studyName', 'studyDescription', 'trialType', 'breedingProgramDbId', 'breedingProgramName', 'breedingProgramDescription', 'studyYear', 'studyDesign', 'locationDbId', 'locationName', 'plantingDate', 'harvestDate', 'plotWidth', 'plotLength', 'plantsPerPlot', 'numberBlocks', 'numberReps', 'fieldSize', 'fieldTrialIsPlannedToBeGenotyped', 'fieldTrialIsPlannedToCross', 'folderDbId', 'folderName', 'folderDescription', 'managementFactors' );

    push @info, \@line;

    foreach my $p (sort keys %project_data) {
        my @line = @{$project_data{$p}->{metadata}};
        push @info, \@line;
    }
    #print STDERR Dumper \@info;
    print STDERR "Construct Meta-data Matrix End:".localtime."\n";
    return @info;
}

1;
