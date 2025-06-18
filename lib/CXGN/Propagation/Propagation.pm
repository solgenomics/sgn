=head1 NAME

CXGN::Propagation::Propagation - an object representing Propagation identifier in the database

=head1 DESCRIPTION


=head1 AUTHORS

    Titima Tantikanjana <tt15@cornell.edu>

=head1 METHODS

=cut

package CXGN::Propagation::Propagation;

use Moose;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

has 'schema' => (
    isa => 'DBIx::Class::Schema',
    is => 'rw',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'project_id' => (
    isa => "Int",
    is => 'rw',
);

has 'propagation_stock_id' => (
    isa => "Int",
    is => 'rw',
);



sub get_propagations_in_project {
    my $self = shift;
    my $schema = $self->schema();
    my $project_id = $self->project_id();

    my $propagation_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation', 'stock_type')->cvterm_id();
    my $propagation_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_experiment', 'experiment_type')->cvterm_id();
    my $propagation_project_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_project', 'project_type')->cvterm_id();
    my $propagation_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_of', 'stock_relationship')->cvterm_id();
    my $propagation_source_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_source_material_of', 'stock_relationship')->cvterm_id();
    my $propagation_rootstock_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_rootstock_of', 'stock_relationship')->cvterm_id();
    my $propagation_material_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_type', 'stock_property')->cvterm_id();
    my $propagation_metadata_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_metadata', 'stock_property')->cvterm_id();
    my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();


    my $q = "SELECT nd_experiment.nd_geolocation_id, propagation.stock_id, propagation.uniquename, propagation.description, material_type.value, metadata.value, accession.stock_id, accession.uniquename, source.stock_id, source.uniquename,  rootstock.stock_id, rootstock.uniquename
        FROM nd_experiment_project
        JOIN nd_experiment ON (nd_experiment_project.nd_experiment_id = nd_experiment.nd_experiment_id)
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS propagation ON (nd_experiment_stock.stock_id = propagation.stock_id) AND propagation.type_id = ?
        JOIN stockprop AS material_type ON (propagation.stock_id = material_type.stock_id) AND material_type.type_id = ?
        JOIN stockprop AS metadata ON (propagation.stock_id = metadata.stock_id) AND metadata.type_id = ?
        JOIN stock_relationship AS accession_relationship ON (accession_relationship.object_id = propagation.stock_id) AND accession_relationship.type_id = ?
        JOIN stock AS accession ON (accession_relationship.subject_id = accession.stock_id) AND accession.type_id = ?
        LEFT JOIN stock_relationship AS source_relationship ON (source_relationship.object_id = propagation.stock_id) AND source_relationship.type_id = ?
        LEFT JOIN stock AS source ON (source_relationship.subject_id = source.stock_id) AND source.type_id IN (?,?,?)
        LEFT JOIN stock_relationship AS rootstock_relationship ON (rootstock_relationship.object_id = propagation.stock_id) AND rootstock_relationship.type_id = ?
        LEFT JOIN stock AS rootstock ON (rootstock_relationship.subject_id = rootstock.stock_id) AND rootstock.type_id = ?
        WHERE nd_experiment_project.project_id = ? ;";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($propagation_cvterm_id, $propagation_material_type_cvterm_id, $propagation_metadata_cvterm_id, $propagation_material_of_cvterm_id, $accession_cvterm_id, $propagation_source_material_of_cvterm_id, $plot_cvterm_id, $plant_cvterm_id, $tissue_sample_cvterm_id, $propagation_rootstock_of_cvterm_id, $accession_cvterm_id, $project_id);

    my @propagations = ();
    while (my ($nd_geolocation_id,  $propagation_stock_id, $propagation_name, $description, $material_type, $metadata, $accession_stock_id, $accession_name, $source_stock_id, $source_name, $rootstock_stock_id, $rootstock_name ) = $h->fetchrow_array()){
        push @propagations, [$propagation_stock_id, $propagation_name, $description, $material_type, $metadata, $accession_stock_id, $accession_name, $source_stock_id, $source_name, $rootstock_stock_id, $rootstock_name, $nd_geolocation_id]
    }
    print STDERR "PROPAGATIONS =".Dumper(\@propagations)."\n";
    return \@propagations;
}


###
1;
###
