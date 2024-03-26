package CXGN::Stock::TrackingActivity::TrackingIdentifier;

=head1 NAME

CXGN::Stock::TrackingActivity::TrackingIdentifier - a module to handle tracking identifier.

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

has 'material_type' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'activity_type' => (
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
    my $material_type = $self->get_material_type();
    my $activity_type = $self->get_activity_type();
    my $project_id = $self->get_project_id();
    my $user_id = $self->get_user_id();
    my $error;
    my $trial_id;
    if ($material_type eq 'trials') {
        $trial_id = $schema->resultset("Project::Project")->find({name => $material_name})->project_id();
    }

    my $tracking_identifier_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_identifier', 'stock_type')->cvterm_id();
    my $material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'material_of', 'stock_relationship')->cvterm_id();
    my $experiment_type_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tracking_activity', 'experiment_type')->cvterm_id();
    my $project_location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
    my $data_type_cvterm= SGN::Model::Cvterm->get_cvterm_row($schema, 'data_type', 'stock_property');
    my $material_type_cvterm= SGN::Model::Cvterm->get_cvterm_row($schema, 'material_type', 'stock_property');
    my $project_tracking_identifier_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project_tracking_identifier', 'experiment_type')->cvterm_id();

    my $geolocation_rs = $schema->resultset("Project::Projectprop")->find({project_id => $project_id, type_id => $project_location_cvterm_id});

    my $tracking_id;

    my $check_id_rs = $schema->resultset("Stock::Stock")->search({
        uniquename => $tracking_identifier,
    });
    if ($check_id_rs->count() > 0){
        return { error_string => "$tracking_identifier already used in the database! " };
    }

    my $coderef = sub {
        my $tracking_id_rs = $schema->resultset("Stock::Stock")->create({
            name => $tracking_identifier,
            uniquename => $tracking_identifier,
            type_id => $tracking_identifier_cvterm_id,
        });

        $tracking_id_rs->create_stockprops({$data_type_cvterm->name() => $activity_type});
        $tracking_id_rs->create_stockprops({$material_type_cvterm->name() => $material_type});

        $tracking_id = $tracking_id_rs->stock_id();

        if ($material_type eq 'accessions' || $material_type eq 'seedlots') {
            my $material_rs = $schema->resultset("Stock::Stock")->find({ uniquename => $material_name});
            my $tracking_material = $schema->resultset("Stock::StockRelationship")->find_or_create({
                subject_id => $material_rs->stock_id,
                object_id => $tracking_id,
                type_id => $material_of_cvterm_id,
            });
        }

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

        if ($trial_id) {
            my $tracking_identifier_experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
                nd_geolocation_id => $geolocation_rs->value,
                type_id => $project_tracking_identifier_cvterm_id,
            });

            $tracking_identifier_experiment->find_or_create_related('nd_experiment_stocks' , {
                stock_id => $tracking_id,
                type_id  => $project_tracking_identifier_cvterm_id,
            });

            $tracking_identifier_experiment->find_or_create_related('nd_experiment_projects', {
                project_id => $trial_id,
            });
        }

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

    return $tracking_id;

}


#######
1;
#######
