=head1 NAME

CXGN::Propagation::AddPropagationGroup - a module for adding propagation group

=cut


package CXGN::Propagation::AddPropagationGroup;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Trial;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;


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

has 'propagation_group_identifier' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'accession_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'material_type' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'material_source_type' => (
    isa => 'Str',
    is => 'rw',
);

has 'source_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'sub_location' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'date' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'description' => (
    isa => 'Str',
    is => 'rw',
);

has 'operator_name' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'propagation_project_id' => (
    isa =>'Int',
    is => 'rw',
    required => 1,
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
);


sub add_propagation_group_identifier {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $propagation_group_identifier = $self->get_propagation_group_identifier();
    my $accession_name = $self->get_accession_name();
    my $material_type = $self->get_material_type();
    my $material_source_type = $self->get_material_source_type();
    my $source_name = $self->get_source_name();
    my $sub_location = $self->get_sub_location();
    my $description = $self->get_description();
    my $propagation_project_id = $self->get_propagation_project_id();
    my $operator_name = $self->get_operator_name();
    my $owner_id = $self->get_owner_id();
    my $date = $self->get_date();
    my $metadata_hash = {};
    $metadata_hash->{date} = $date;
    $metadata_hash->{operator} = $operator_name;
    $metadata_hash->{sub_location} = $sub_location;
    $metadata_hash->{material_source_type} = $material_source_type;
    my $metadata_json_string = encode_json $metadata_hash;
    my %return;
    my $propagation_group_stock_id;
    my $accession_stock_id;
    my $source_stock_id;
    my $coderef = sub {
        my $propagation_group_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_group', 'stock_type')->cvterm_id();
        my $propagation_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_experiment', 'experiment_type')->cvterm_id();
        my $propagation_project_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_project', 'project_type')->cvterm_id();
        my $propagation_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_of', 'stock_relationship')->cvterm_id();
        my $propagation_source_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_source_material_of', 'stock_relationship')->cvterm_id();
        my $propagation_material_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_type', 'stock_property');
        my $propagation_metadata_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_metadata', 'stock_property');

        my $project_location_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'project location', 'project_property')->cvterm_id();
        my $geolocation_rs = $schema->resultset("Project::Projectprop")->find({project_id => $propagation_project_id, type_id => $project_location_cvterm_id});
        my $nd_geolocation_id = $geolocation_rs->value();

        my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

        my $accession_rs = $schema->resultset("Stock::Stock")->find({
            uniquename => $accession_name,
            type_id => $accession_cvterm_id,
        });

        if ($accession_rs) {
            $accession_stock_id = $accession_rs->stock_id();
        }

        if ($source_name) {
            my $source_rs = $schema->resultset("Stock::Stock")->find({uniquename => $source_name});
            $source_stock_id = $source_rs->stock_id();
        }

        my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
            nd_geolocation_id => $nd_geolocation_id,
            type_id => $propagation_experiment_cvterm_id,
        });
        my $nd_experiment_id = $experiment->nd_experiment_id();

        my $propagation_group_identifier_stock = $schema->resultset("Stock::Stock")->find_or_create({
            name => $propagation_group_identifier,
            uniquename => $propagation_group_identifier,
            type_id => $propagation_group_cvterm_id,
            description => $description
        });

        $propagation_group_identifier_stock->find_or_create_related('stock_relationship_objects', {
            type_id => $propagation_material_of_cvterm_id,
            object_id => $propagation_group_identifier_stock->stock_id(),
            subject_id => $accession_stock_id,
        });

        if ($source_stock_id) {
            $propagation_group_identifier_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $propagation_source_material_of_cvterm_id,
                object_id => $propagation_group_identifier_stock->stock_id(),
                subject_id => $source_stock_id,
            });
        }

        $experiment->find_or_create_related('nd_experiment_stocks', {
            stock_id => $propagation_group_identifier_stock->stock_id(),
            type_id  => $propagation_experiment_cvterm_id,
        });

        $experiment->find_or_create_related('nd_experiment_projects', {
            project_id => $propagation_project_id,
        });

        $propagation_group_identifier_stock->create_stockprops({$propagation_material_type_cvterm->name() => $material_type});
        $propagation_group_identifier_stock->create_stockprops({$propagation_metadata_cvterm->name() => $metadata_json_string});

        $propagation_group_stock_id = $propagation_group_identifier_stock->stock_id();
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
            stock_id => $propagation_group_stock_id,
            sp_person_id =>  $owner_id,
        });

        return { success=>1, propagation_group_stock_id=>$propagation_group_stock_id };
    }

}



#########
1;
#########
