package CXGN::TrackingActivity::AddTrackingIdentifier;

=head1 NAME

CXGN::TrackingActivity::AddTrackingIdentifier - a module to add tracking identifier.

=head1 USAGE


=head1 DESCRIPTION

=head1 AUTHORS

Titima Tantikanjana (tt15@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    required => 1,
);

has 'phenome_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    required => 1,
);

has 'tracking_identifier' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'material' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'project_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'user_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

sub store {
    my $self = shift;
    my $schema = $self->get_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $tracking_identifier = $self->get_tracking_identifier();
    my $material_name = $self->get_material();
    my $project_id = $self->get_project_id();
    my $user_id = $self->get_user_id();
    my $error;

    my $tracking_identifier_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();
    my $material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id();
    my $experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_activity', 'experiment_type')->cvterm_id();
    my $project_location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $geolocation_rs = $schema->resultset("Project::Projectprop")->find({project_id => $project_id, type_id => $project_location_cvterm_id});

    my $tracking_id;

    my $check_id_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => $tracking_identifier,
    });
    if ($check_id_rs->count() > 0){
        return { error => "$tracking_identifier already used in the database! " };
    }

    my $coderef = sub {
        my $tracking_id_rs = $schema->resultset("Stock::Stock")->create({
            name => $tracking_identifier,
            uniquename => $tracking_identifier,
            type_id => $tracking_identifier_cvterm_id,
        });
        $tracking_id = $tracking_id_rs->stock_id();

        my $material_rs = $schema->resultset("Stock::Stock")->find({ uniquename => $material_name});
        my $tracking_material = $schema->resultset("Stock::StockRelationship")->find_or_create({
            subject_id => $material_rs->stock_id,
            object_id => $tracking_id,
            type_id => $material_of_cvterm_id,
        });

        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
            nd_geolocation_id => $geolocation_rs->value,
            type_id => $experiment_type_cvterm_id,
        });

        $experiment->find_or_create_related('nd_experiment_stocks' , {
            stock_id => $tracking_id,
            type_id  => $experiment_type_cvterm_id,
        });

        $experiment->find_or_create_related('nd_experiment_projects', {
            project_id => $project_id,
        });

    };

    my $error;
    try {
        $schema->txn_do($coderef);
    } catch {
        $error =  $_;
    };

    if ($error) {
        return { error => "Error creating a tracking identifier: $error\n" };
    }

    $phenome_schema->resultset("StockOwner")->find_or_create({
        stock_id => $tracking_id,
        sp_person_id => $user_id,
    });

    return {tracking_id => $tracking_id};

}



#######
1;
#######
