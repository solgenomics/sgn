=head1 NAME

CXGN::Stock::AddDerivedAccession - a module for adding new accession derived from another stock type

=cut


package CXGN::Stock::AddDerivedAccession;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Location::LocationLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Stock;

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

has 'derived_accession_name' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'original_stock_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'description' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);


sub existing_accession_name {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $derived_accession_name = $self->get_derived_accession_name();

    if ($schema->resultset('Stock::Stock')->find({ 'uniquename' => $derived_accession_name, 'is_obsolete' => { '!=' => 't' }})){
        return 1;
    } else {
        return;
    }
}


sub add_derived_accession {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $derived_accession_name = $self->get_derived_accession_name();
    my $description = $self->get_description();
    my $original_stock_id = $self->get_original_stock_id();
    my $owner_id = $self->get_owner_id();
    my $derived_accession_stock_id;
    my %return;

    print STDERR "DERIVED ACCESSION NAME =".Dumper($derived_accession_name)."\n";
    print STDERR "STOCK ID =".Dumper($original_stock_id)."\n";


    if ($self->existing_accession_name()){
        return {error => "Error: Accession name: $derived_accession_name already exists in the database."};
    }

    my $coderef = sub {
        my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
        my $cross_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type')->cvterm_id();
        my $family_name_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'family_name', 'stock_type')->cvterm_id();
        my $plant_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'plant', 'stock_type')->cvterm_id();
        my $tissue_sample_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample', 'stock_type')->cvterm_id();
        my $female_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
        my $male_parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();
        my $plant_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'plant_of', 'stock_relationship')->cvterm_id();
        my $tissue_sample_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'tissue_sample_of', 'stock_relationship')->cvterm_id();
        my $derived_from_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'derived_from', 'stock_relationship')->cvterm_id();
        my $derived_accession_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'derived_accession', 'stock_property');

        my $original_stock = $schema->resultset('Stock::Stock')->find({ 'stock_id' => $original_stock_id});
        my $stock_type = $original_stock->type_id();
        my $organism_id = $original_stock->organism_id();

        my $original_accession_stock_id;
        my $cross_type;
        my $female_stock_id;
        my $male_stock_id;
        if ($stock_type == $accession_cvterm_id) {
            $original_accession_stock_id = $original_stock_id;
        } elsif ($stock_type == $plant_cvterm_id) {
            my $stock_plant_relationship = $schema->resultset("Stock::StockRelationship")->find ({
                subject_id => $original_stock_id,
                type_id => $plant_of_cvterm_id,
            });

            $original_accession_stock_id = $stock_plant_relationship->object_id();

        } elsif ($stock_type == $tissue_sample_cvterm_id) {
            my $accession_tissue_sample_relationship = $schema->resultset("Stock::StockRelationship")->find ({
                subject_id => $original_stock_id,
                type_id => $tissue_sample_of_cvterm_id,
            });

            $original_accession_stock_id = $accession_tissue_sample_relationship->object_id();
        }

        my $female_parent_relationship = $schema->resultset("Stock::StockRelationship")->find ({
            object_id => $original_accession_stock_id,
            type_id => $female_parent_cvterm_id,
        });

        if ($female_parent_relationship) {
            $female_stock_id = $female_parent_relationship->subject_id();
            $cross_type = $female_parent_relationship->value();
        }

        my $male_parent_relationship = $schema->resultset("Stock::StockRelationship")->find ({
            object_id => $original_accession_stock_id,
            type_id => $male_parent_cvterm_id,
        });

        if ($male_parent_relationship) {
            $male_stock_id = $male_parent_relationship->subject_id();
        }


        my $derived_accession_stock = $schema->resultset("Stock::Stock")->create({
            organism_id => $organism_id,
            name => $derived_accession_name,
            uniquename => $derived_accession_name,
            type_id => $accession_cvterm_id,
            description => $description,
        });

        $derived_accession_stock_id = $derived_accession_stock->stock_id();
        print STDERR "DERIVED ACCESSION STOCK ID =".Dumper($derived_accession_stock_id)."\n";

        if ($derived_accession_stock_id) {
            $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $derived_from_cvterm_id,
                object_id => $original_stock_id,
                subject_id => $derived_accession_stock_id,
                value => $stock_type
			});

            $derived_accession_stock->create_stockprops({$derived_accession_cvterm->name() => 1});

            if ($female_stock_id) {
                $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $female_parent_cvterm_id,
                    object_id => $derived_accession_stock_id,
                    subject_id => $female_stock_id,
                    value => $cross_type,
                });
            }

            if ($male_stock_id) {
                $derived_accession_stock->find_or_create_related('stock_relationship_objects', {
                    type_id => $male_parent_cvterm_id,
                    object_id => $derived_accession_stock_id,
                    subject_id => $male_stock_id,
                });
            }
        }

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
            stock_id => $derived_accession_stock_id,
            sp_person_id =>  $owner_id,
        });
    }

        return { success=>1, derived_accession_stock_id=>$derived_accession_stock_id };

}



#########
1;
#########
