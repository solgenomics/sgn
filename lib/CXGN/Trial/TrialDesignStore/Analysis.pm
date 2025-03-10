
package CXGN::Trial::TrialDesignStore::Analysis;

use Moose;
use Try::Tiny;
use SGN::Model::Cvterm;

extends 'CXGN::Trial::TrialDesignStore::AbstractTrial';

sub BUILD {   # adjust the cvterm ids for phenotyping trials
    my $self = shift;

    print STDERR "PhenotypingTrial BUILD setting stock type id etc....\n";
    my @source_stock_types;
    $self->set_nd_experiment_type_id(SGN::Model::Cvterm->get_cvterm_row($self->get_bcs_schema(), 'analysis_experiment', 'experiment_type')->cvterm_id());

    my $analysis_instance_type_id = SGN::Model::Cvterm->get_cvterm_row($self->get_bcs_schema(), 'analysis_instance', 'stock_type')->cvterm_id();
    $self->set_stock_type_id($analysis_instance_type_id);

    my $analysis_of_type_id = SGN::Model::Cvterm->get_cvterm_row($self->get_bcs_schema(), 'analysis_of', 'stock_relationship')->cvterm_id();
    $self->set_stock_relationship_type_id($analysis_of_type_id);
    @source_stock_types = ($self->get_accession_cvterm_id, $self->get_analysis_result_cvterm_id);
    $self->set_source_stock_types(\@source_stock_types);

    $self->set_valid_properties( 
	[
	 'stock_name',
	 'plot_name',
	 'plot_number',
	 'block_number',
	 'rep_number',
	 'is_a_control',
	 'row_number',
	 'col_number',
	]);    
}

sub validate_design {   ####  IMPLEMENT!!!!!
    my $self = shift;
    my $error = "";
    return $error;
}

1;
