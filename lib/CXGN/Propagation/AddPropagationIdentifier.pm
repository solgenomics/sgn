=head1 NAME

CXGN::Propagation::AddPropagationIdentifier - a module for adding propagation identifier

=cut


package CXGN::Propagation::AddPropagationIdentifier;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Location::LocationLookup;
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

has 'propagation_identifier' => (
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

has 'source_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'rootstock_accession_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'operator_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'nd_geolocation_id' => (
    isa => 'Int|Undef',
    is => 'rw',
    required => 1,
);

has 'date' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'description' => (
    isa => 'Str',
    is => 'rw',
    required => 1,
);

has 'propagation_project_id' => (
    isa =>'Int',
    is => 'rw',
    required => 1,
);


sub add_propagation_identifier {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $propagation_identifier = $self->get_propagation_identifier();
    my $accession_name = $self->get_accession_name();
    my $material_type = $self->get_material_type();
    my $source_name = $self->get_source_name();
    my $rootstock_accession_name = $self->get_rootstock_accession_name();
    my $nd_geolocation_id = $self->get_nd_geolocation_id();
    my $description = $self->get_description();
    my $propagation_project_id = $self->get_propagation_project_id();
    my $operator_id = $self->get_operator_id();
    my $date = $self->get_date();
    my $metadata_hash = {};
    $metadata_hash->{date} = $date;
    $metadata_hash->{operator} = $operator_id;
    my $metadata_json_string = encode_json $metadata_hash;

    my %return;
    my $propagation_stock_id;
    my $accession_stock_id;
    my $source_stock_id;
    my $rootstock_accession_stock_id;
    my $coderef = sub {
        my $propagation_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation', 'stock_type')->cvterm_id();
        my $propagation_experiment_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_experiment', 'experiment_type')->cvterm_id();
        my $propagation_project_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_project', 'project_type')->cvterm_id();
        my $propagation_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_of', 'stock_relationship')->cvterm_id();
        my $propagation_source_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_source_material_of', 'stock_relationship')->cvterm_id();
        my $propagation_rootstock_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_rootstock_of', 'stock_relationship')->cvterm_id();
        my $propagation_material_type_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_type', 'stock_property');
        my $propagation_metadata_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_metadata', 'stock_property');

        my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

		my $accession_rs = $schema->resultset("Stock::Stock")->find({
			uniquename => $accession_name,
			type_id => $accession_cvterm_id,
		});

		if ($accession_rs) {
            $accession_stock_id = $accession_rs->stock_id();
		}

        my $rootstock_accession_rs;
        if ($rootstock_accession_name) {
            $rootstock_accession_rs = $schema->resultset("Stock::Stock")->find({
                uniquename => $rootstock_accession_name,
                type_id => $accession_cvterm_id,
            });
        }

        if ($rootstock_accession_rs) {
            $rootstock_accession_stock_id = $rootstock_accession_rs->stock_id();
        }

        my $source_rs;
        if ($source_name) {
            my $source_rs = $schema->resultset("Stock::Stock")->find({
    			uniquename => $accession_name,
    		});
        }

		if ($source_rs) {
            $source_stock_id = $source_rs->stock_id();
		}

		my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
			nd_geolocation_id => $nd_geolocation_id,
			type_id => $propagation_experiment_cvterm_id,
		});
		my $nd_experiment_id = $experiment->nd_experiment_id();

		my $propagation_identifier_stock = $schema->resultset("Stock::Stock")->find_or_create({
			name => $propagation_identifier,
			uniquename => $propagation_identifier,
			type_id => $propagation_cvterm_id,
            description => $description
		});

		$propagation_identifier_stock->find_or_create_related('stock_relationship_objects', {
			type_id => $propagation_material_of_cvterm_id,
			object_id => $propagation_identifier_stock->stock_id(),
			subject_id => $accession_stock_id,
		});

        if ($source_stock_id) {
            $propagation_identifier_stock->find_or_create_related('stock_relationship_objects', {
    			type_id => $propagation_source_material_of_cvterm_id,
    			object_id => $propagation_identifier_stock->stock_id(),
    			subject_id => $source_stock_id,
    		});
        }

        if ($rootstock_accession_stock_id) {
            $propagation_identifier_stock->find_or_create_related('stock_relationship_objects', {
    			type_id => $propagation_rootstock_of_cvterm_id,
    			object_id => $propagation_identifier_stock->stock_id(),
    			subject_id => $rootstock_accession_stock_id,
    		});
        }

		$experiment->find_or_create_related('nd_experiment_stocks', {
		    stock_id => $propagation_identifier_stock->stock_id(),
		    type_id  => $propagation_experiment_cvterm_id,
		});

		$experiment->find_or_create_related('nd_experiment_projects', {
			project_id => $propagation_project_id,
		});

        $propagation_identifier_stock->create_stockprops({$propagation_material_type_cvterm->name() => $material_type});
        $propagation_identifier_stock->create_stockprops({$propagation_metadata_cvterm->name() => $metadata_json_string});

        $propagation_stock_id = $propagation_identifier_stock->stock_id();
        print STDERR "PROPAGATION STOCK ID CXGN =".Dumper($propagation_stock_id)."\n";

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
            stock_id => $propagation_stock_id,
            sp_person_id =>  $operator_id,
        });

        return { success=>1, propagation_stock_id=>$propagation_stock_id };
    }

}



#########
1;
#########
