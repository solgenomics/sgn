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

has 'propagation_group_stock_id' => (
    isa => "Int",
    is => 'rw',
);



sub get_propagation_groups_in_project {
    my $self = shift;
    my $schema = $self->schema();
    my $project_id = $self->project_id();

    my $propagation_group_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_group', 'stock_type')->cvterm_id();
    my $propagation_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_experiment', 'experiment_type')->cvterm_id();
    my $propagation_project_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_project', 'project_type')->cvterm_id();
    my $propagation_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_of', 'stock_relationship')->cvterm_id();
    my $propagation_source_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_source_material_of', 'stock_relationship')->cvterm_id();
    my $propagation_material_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_type', 'stock_property')->cvterm_id();
    my $propagation_metadata_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_metadata', 'stock_property')->cvterm_id();
    my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();


    my $q = "SELECT propagation.stock_id, propagation.uniquename, propagation.description, material_type.value, metadata.value, accession.stock_id, accession.uniquename, source.stock_id, source.uniquename
        FROM nd_experiment_project
        JOIN nd_experiment_stock ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN stock AS propagation ON (nd_experiment_stock.stock_id = propagation.stock_id) AND propagation.type_id = ?
        JOIN stockprop AS material_type ON (propagation.stock_id = material_type.stock_id) AND material_type.type_id = ?
        JOIN stockprop AS metadata ON (propagation.stock_id = metadata.stock_id) AND metadata.type_id = ?
        JOIN stock_relationship AS accession_relationship ON (accession_relationship.object_id = propagation.stock_id) AND accession_relationship.type_id = ?
        JOIN stock AS accession ON (accession_relationship.subject_id = accession.stock_id) AND accession.type_id = ?
        LEFT JOIN stock_relationship AS source_relationship ON (source_relationship.object_id = propagation.stock_id) AND source_relationship.type_id = ?
        LEFT JOIN stock AS source ON (source_relationship.subject_id = source.stock_id) AND source.type_id IN (?,?,?)
        WHERE nd_experiment_project.project_id = ? ;";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($propagation_group_cvterm_id, $propagation_material_type_cvterm_id, $propagation_metadata_cvterm_id, $propagation_material_of_cvterm_id, $accession_cvterm_id, $propagation_source_material_of_cvterm_id, $plot_cvterm_id, $plant_cvterm_id, $tissue_sample_cvterm_id, $project_id);

    my @propagation_groups = ();
    while (my ($propagation_stock_id, $propagation_name, $description, $material_type, $metadata, $accession_stock_id, $accession_name, $source_stock_id, $source_name) = $h->fetchrow_array()){
        push @propagation_groups, [$propagation_stock_id, $propagation_name, $description, $material_type, $metadata, $accession_stock_id, $accession_name, $source_stock_id, $source_name]
    }

    return \@propagation_groups;
}


sub get_propagation_group_info {
    my $self = shift;
    my $schema = $self->schema();
    my $propagation_group_stock_id = $self->propagation_group_stock_id();

    my $propagation_group_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_group', 'stock_type')->cvterm_id();
    my $propagation_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_experiment', 'experiment_type')->cvterm_id();
    my $propagation_project_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_project', 'project_type')->cvterm_id();
    my $propagation_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_of', 'stock_relationship')->cvterm_id();
    my $propagation_source_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_source_material_of', 'stock_relationship')->cvterm_id();
    my $propagation_material_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_type', 'stock_property')->cvterm_id();
    my $propagation_metadata_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_metadata', 'stock_property')->cvterm_id();
    my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $plot_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plot', 'stock_type')->cvterm_id();
    my $plant_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
    my $tissue_sample_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();


    my $q = "SELECT propagation.stock_id, propagation.uniquename, propagation.description, material_type.value, metadata.value, accession.stock_id, accession.uniquename, source.stock_id, source.uniquename, project.project_id, project.name
        FROM stock AS propagation
        JOIN stockprop AS material_type ON (propagation.stock_id = material_type.stock_id) AND material_type.type_id = ?
        JOIN stockprop AS metadata ON (propagation.stock_id = metadata.stock_id) AND metadata.type_id = ?
        JOIN stock_relationship AS accession_relationship ON (accession_relationship.object_id = propagation.stock_id) AND accession_relationship.type_id = ?
        JOIN stock AS accession ON (accession_relationship.subject_id = accession.stock_id) AND accession.type_id = ?
        JOIN nd_experiment_stock ON (nd_experiment_stock.stock_id = propagation.stock_id) AND nd_experiment_stock.type_id = ?
        JOIN nd_experiment_project ON (nd_experiment_project.nd_experiment_id = nd_experiment_stock.nd_experiment_id)
        JOIN project ON (nd_experiment_project.project_id = project.project_id)
        LEFT JOIN stock_relationship AS source_relationship ON (source_relationship.object_id = propagation.stock_id) AND source_relationship.type_id = ?
        LEFT JOIN stock AS source ON (source_relationship.subject_id = source.stock_id) AND source.type_id IN (?,?,?)
        WHERE propagation.stock_id = ? ;";

    my $h = $schema->storage->dbh()->prepare($q);

    $h->execute($propagation_material_type_cvterm_id, $propagation_metadata_cvterm_id, $propagation_material_of_cvterm_id, $accession_cvterm_id, $propagation_experiment_cvterm_id, $propagation_source_material_of_cvterm_id, $plot_cvterm_id, $plant_cvterm_id, $tissue_sample_cvterm_id, $propagation_group_stock_id);

    my @propagation_group_info = ();
    while (my ($propagation_group_stock_id, $propagation_group_name, $description, $material_type, $metadata, $accession_stock_id, $accession_name, $source_stock_id, $source_name, $project_id, $project_name) = $h->fetchrow_array()){
        push @propagation_group_info, [$propagation_group_stock_id, $propagation_group_name, $description, $material_type, $metadata, $accession_stock_id, $accession_name, $source_stock_id, $source_name, $project_id, $project_name]
    }
    print STDERR "PROPAGATION INFO =".Dumper(\@propagation_group_info)."\n";
    return \@propagation_group_info;

}



###
1;
###
