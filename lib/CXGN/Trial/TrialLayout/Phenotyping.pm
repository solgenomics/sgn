
package CXGN::Trial::TrialLayout::Phenotyping;

use Moose;
use namespace::autoclean;

extends 'CXGN::Trial::TrialLayout::AbstractLayout';

has 'block_numbers' => (isa => 'ArrayRef', is => 'ro', predicate => 'has_block_numbers', reader => 'get_block_numbers', writer => '_set_block_numbers');


sub BUILD {
    my $self = shift;

    print STDERR "BUILD CXGN::Trial::TrialLayout::Phenotyping...\n";
    $self->set_source_primary_stock_types( [ "accession", "cross", "family_name" ] );
    $self->set_source_stock_types([ 'accession', 'cross', 'family_name', 'subplot', 'plant', 'grafted_accession' ] );
    $self->set_relationship_types([ 'plot_of', 'member_of', 'plant_of_subplot', 'tissue_sample_of']);
    $self->set_target_stock_types( [ 'plot'] );

    #print STDERR "Set source stock types to ".join(", ", @{$self->get_source_stock_types()});
        # probably better to lazy load the action design...
    #
    $self->convert_source_stock_types_to_ids();
    $self->_lookup_trial_id();
    #$self->_get_design_from_trial();
}

has 'plot_dimensions' => (
    isa => 'ArrayRef',
    is => 'ro',
    predicate => 'has_plot_dimensions', reader => 'get_plot_dimensions', writer => '_set_plot_dimensions',
    lazy     => 1,
    builder  => '_retrieve_plot_dimensions',
);

after '_lookup_trial_id' => sub {
    my $self = shift;
    $self->_set_block_numbers($self->_get_plot_info_fields_from_trial("block_number") || []);
};



sub _retrieve_plot_dimensions {
    my $self = shift;
    $self->_set_plot_dimensions($self->_get_plot_dimensions_from_trial());
}

sub _get_plot_dimensions_from_trial {
    my $self = shift;
    if (!$self->has_trial_id()) {
	return;
    }
    my $project = $self->get_project();
    if (!$project) {
	return;
    }

    my $schema = $self->get_schema();
    my $plot_width = '';
    my $plot_width_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_width', 'project_property')->cvterm_id();
    my $plot_width_row = $schema->resultset('Project::Projectprop')->find({project_id => $self->get_trial_id(), type_id => $plot_width_cvterm_id});
    if ($plot_width_row) {
        $plot_width = $plot_width_row->value();
    }

    my $plot_length = '';
    my $plot_length_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plot_length', 'project_property')->cvterm_id();
    my $plot_length_row = $schema->resultset('Project::Projectprop')->find({project_id => $self->get_trial_id(), type_id => $plot_length_cvterm_id});
    if ($plot_length_row) {
        $plot_length = $plot_length_row->value();
    }

    my $plants_per_plot = '';
    my $plants_per_plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_has_plant_entries', 'project_property')->cvterm_id();
    my $plants_per_plot_row = $schema->resultset('Project::Projectprop')->find({project_id => $self->get_trial_id(), type_id => $plants_per_plot_cvterm_id});
    if ($plants_per_plot_row) {
        $plants_per_plot = $plants_per_plot_row->value();
    }

    my $subplots_per_plot = '';
    my $subplots_per_plot_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_has_subplot_entries', 'project_property')->cvterm_id();
    my $subplots_per_plot_row = $schema->resultset('Project::Projectprop')->find({project_id => $self->get_trial_id(), type_id => $subplots_per_plot_cvterm_id});
    if ($subplots_per_plot_row) {
        $subplots_per_plot = $subplots_per_plot_row->value();
    }
    return [$plot_length, $plot_width, $plants_per_plot, $subplots_per_plot];
}

###

__PACKAGE__->meta()->make_immutable();

1;
