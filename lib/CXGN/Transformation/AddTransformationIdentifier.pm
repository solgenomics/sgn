=head1 NAME

CXGN::Transformation::AddTransformationIdentifier - a module for adding transformation identifier

=cut


package CXGN::Transformation::AddTransformationIdentifier;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Location::LocationLookup;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'chado_schema' => (
    isa => 'DBIx::Class::Schema',
    is => 'rw',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    required => 1,
);

has 'phenome_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    predicate => 'has_phenome_schema',
    required => 1,
);

has 'transformation_identifier' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'plant_material' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'vector_construct' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'notes' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'transformation_project_id' => (
    isa =>'Int',
    is => 'rw',
    required => 1,
);

has 'is_a_control' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);


sub existing_transformation_id {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $transformation_identifier = $self->get_transformation_identifier();

    if ($schema->resultset('Stock::Stock')->find({ 'uniquename' => $transformation_identifier})){
        return 1;
    } else {
        return;
    }
}


sub add_transformation_identifier {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $transformation_identifier = $self->get_transformation_identifier();
    my $plant_material = $self->get_plant_material();
    my $vector_construct = $self->get_vector_construct();
    my $transformation_notes = $self->get_notes();
    my $transformation_project_id = $self->get_transformation_project_id();
    my $is_a_control = $self->get_is_a_control();
    my $plant_material_stock_id;
    my $vector_construct_stock_id;
    my %return;
    my $transformation_stock_id;
    my $owner_id = $self->get_owner_id();

    if ($self->existing_transformation_id()){
        return {error => "Error: Transformation identifier: $transformation_identifier already exists in the database."};
    }

    my $coderef = sub {

        my $transformation_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation', 'stock_type')->cvterm_id();
        my $transformation_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_experiment', 'experiment_type')->cvterm_id();
        my $transformation_project_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation_project', 'project_type')->cvterm_id();
        my $plant_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'plant_material_of', 'stock_relationship')->cvterm_id();
        my $vector_construct_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'vector_construct_of', 'stock_relationship')->cvterm_id();
        my $transformation_notes_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'transformation_notes', 'stock_property');
        my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
        my $vector_construct_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct', 'stock_type')->cvterm_id();
        my $is_a_transformation_control_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'is_a_transformation_control', 'stock_property');

        my $project_location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
        my $geolocation_rs = $schema->resultset("Project::Projectprop")->find({project_id => $transformation_project_id, type_id => $project_location_cvterm_id});

		my $plant_material_rs = $schema->resultset("Stock::Stock")->find({
			uniquename => $plant_material,
			type_id => $accession_cvterm_id,
		});

		if ($plant_material_rs) {
            $plant_material_stock_id = $plant_material_rs->stock_id();
		}

		my $vector_construct_rs = $schema->resultset("Stock::Stock")->find({
			uniquename => $vector_construct,
			type_id => $vector_construct_cvterm_id,
		});

		if ($vector_construct_rs) {
            $vector_construct_stock_id = $vector_construct_rs->stock_id();
		}

		my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
			nd_geolocation_id => $geolocation_rs->value,
			type_id => $transformation_experiment_cvterm_id,
		});
		my $nd_experiment_id = $experiment->nd_experiment_id();

		my $transformation_identifier_stock = $schema->resultset("Stock::Stock")->find_or_create({
			name => $transformation_identifier,
			uniquename => $transformation_identifier,
			type_id => $transformation_cvterm_id,
		});

		$transformation_identifier_stock->find_or_create_related('stock_relationship_objects', {
			type_id => $plant_material_of_cvterm_id,
			object_id => $transformation_identifier_stock->stock_id(),
			subject_id => $plant_material_stock_id,
		});

		$transformation_identifier_stock->find_or_create_related('stock_relationship_objects', {
			type_id => $vector_construct_of_cvterm_id,
			object_id => $transformation_identifier_stock->stock_id(),
			subject_id => $vector_construct_stock_id,
		});

		$experiment->find_or_create_related('nd_experiment_stocks' , {
			  stock_id => $transformation_identifier_stock->stock_id(),
			  type_id  => $transformation_experiment_cvterm_id,
			});

		$experiment->find_or_create_related('nd_experiment_projects', {
			project_id => $transformation_project_id,
		});

        if ($transformation_notes) {
            $transformation_identifier_stock->create_stockprops({$transformation_notes_cvterm->name() => $transformation_notes});
        }

        if ($is_a_control) {
            $transformation_identifier_stock->create_stockprops({$is_a_transformation_control_cvterm->name() => $is_a_control});
        }

        $transformation_stock_id = $transformation_identifier_stock->stock_id();
    };

    my $transaction_error;
    try {
        $schema->txn_do($coderef);
    } catch {
        print STDERR "Transaction Error: $_\n";
        $transaction_error =  $_;
    };

    if ($transaction_error){
        return { error=>$transaction_error };
    } else {
        $phenome_schema->resultset("StockOwner")->find_or_create({
            stock_id => $transformation_stock_id,
            sp_person_id =>  $owner_id,
        });

        return { success=>1, transformation_id=>$transformation_stock_id };
    }

}



#########
1;
#########
