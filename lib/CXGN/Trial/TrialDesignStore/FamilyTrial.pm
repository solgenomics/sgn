package CXGN::Trial::TrialDesignStore::FamilyTrial;

use Moose;
use Try::Tiny;

extends 'CXGN::Trial::TrialDesignStore::PhenotypingTrial';

sub BUILD {   # adjust the cvterm ids for FamilyTrials, from phenotyping trials
    my $self = shift;

    #print STDERR "PhenotypingTrial BUILD setting stock type id etc....\n";
    my @source_stock_types;
    $self->set_nd_experiment_type_id(SGN::Model::Cvterm->get_cvterm_row($self->get_bcs_schema(), 'field_layout', 'experiment_type')->cvterm_id());
    $self->set_stock_type_id($self->get_plot_cvterm_id() );
    $self->set_source_stock_types([ $self->get_family_name_cvterm_id() ] );
    $self->set_stock_relationship_type_id($self->get_plot_of_cvterm_id() );
    $self->set_valid_properties( 
	[
	 'seedlot_name',
	 'num_seed_per_plot',
	 'weight_gram_seed_per_plot',
	 'stock_name',
	 'plot_name',
	 'plot_number',
	 'block_number',
	 'rep_number',
	 'is_a_control',
	 'range_number',
	 'row_number',
	 'col_number',
	 'plant_names',
	 'plot_num_per_block',
	 'subplots_names', #For splotplot
	 'treatments', #For splitplot
	 'subplots_plant_names', #For splitplot
	]);
    
}

1;
