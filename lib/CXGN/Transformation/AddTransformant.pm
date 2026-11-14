package CXGN::Transformation::AddTransformant;

=head1 NAME

CXGN::Transformation::AddTransformant - a module to add transformants generated from transformation identifier.

=head1 USAGE


=head1 DESCRIPTION


=head1 AUTHORS

Titima Tantikanjana (tt15@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use CXGN::Pedigree::Parentage;
use Data::Dumper;

has 'schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
	predicate => 'has_schema',
	required => 1,
);

has 'phenome_schema' => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    predicate => 'has_phenome_schema',
    required => 1,
);

has 'dbh' => (
    is  => 'rw',
    predicate => 'has_dbh',
    required => 1,
);

has 'transformation_stock_id' => (
    isa =>'Int',
    is => 'rw',
    predicate => 'has_transformation_stock_id',
    required => 1,
);

has 'transformant_names' => (
    isa =>'ArrayRef[Str]',
    is => 'rw',
    predicate => 'has_transformant_names',
    required => 1,
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
    predicate => 'has_owner_id',
    required => 1,
);

has 'additional_transformant_info' => (
    isa => 'Maybe[HashRef]',
    is => 'rw',
    predicate => 'has_additional_transformant_info',
);


=head2 add_transformant()

Create the requested accessions, transformation and parent relationships,
properties, and ownership rows atomically on the supplied Chado transaction
handle. The public C<phenome_schema> constructor attribute remains supported;
ownership uses the existing qualified C<phenome.stock_owner> table and its
normal column defaults on the owning handle.

Return C<{ success =E<gt> 1 }> when these writes succeed, or
C<{ error =E<gt> $exception }> when they fail and roll back. The error can be a
DBIx::Class exception object; callers must stringify or sanitize it before
encoding a public response. A successful C<eval> alone does not confirm success.

The factory joins an existing caller transaction when present. Its success
result does not commit that outer transaction; a batch caller must propagate
any error result so the complete batch rolls back. Parentage graph writes use
the shared transaction lock and require READ COMMITTED isolation.

=cut

sub add_transformant {

    my $self = shift;
    my $schema = $self->get_schema();
    my $transformation_stock_id = $self->get_transformation_stock_id();
    my @transformant_names = @{$self->get_transformant_names()};
    my $additional_transformant_info = $self->get_additional_transformant_info();
    my $female_parent;
    my $plant_material;
    my $plant_material_stock;
    my $vector_construct;
    my $male_parent;
    my $organism_id;
    my $transaction_error;
    my @added_stock_ids;

    my $owner_id = $self->get_owner_id();;

    my $coderef = sub {
        CXGN::Pedigree::Parentage->lock($schema);

        my $transformation_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'transformation', 'stock_type');
        my $plant_material_of_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'plant_material_of', 'stock_relationship');
        my $vector_construct_of_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'vector_construct_of', 'stock_relationship');
        my $accession_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');
        my $transformant_of_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'transformant_of', 'stock_relationship');
        my $transgenic_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'transgenic', 'stock_property');
        my $female_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship');
        my $male_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'male_parent', 'stock_relationship');
        my $number_of_insertions_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'number_of_insertions', 'stock_property');

        $plant_material = $schema->resultset("Stock::StockRelationship")->find ({
            object_id => $transformation_stock_id,
            type_id => $plant_material_of_cvterm->cvterm_id(),
        });

        $plant_material_stock = $schema->resultset("Stock::Stock")->find ({
            stock_id => $plant_material->subject_id(),
            type_id => $accession_cvterm->cvterm_id(),
        });

        $organism_id = $plant_material_stock->organism_id();

        $vector_construct = $schema->resultset("Stock::StockRelationship")->find ({
            object_id => $transformation_stock_id,
            type_id => $vector_construct_of_cvterm->cvterm_id(),
        });

        foreach my $name (@transformant_names) {
            my $accession_stock = $schema->resultset("Stock::Stock")->create({
                organism_id => $organism_id,
                name       => $name,
                uniquename => $name,
                type_id    => $accession_cvterm->cvterm_id,
            });

            push (@added_stock_ids,  $accession_stock->stock_id());

            $accession_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $transformant_of_cvterm->cvterm_id(),
                object_id => $transformation_stock_id,
                subject_id => $accession_stock->stock_id(),
            });

            $accession_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $female_parent_cvterm->cvterm_id(),
                object_id => $accession_stock->stock_id(),
                subject_id => $plant_material->subject_id(),
            });

            $accession_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $male_parent_cvterm->cvterm_id(),
                object_id => $accession_stock->stock_id(),
                subject_id => $vector_construct->subject_id(),
            });

            $accession_stock->create_stockprops({$transgenic_cvterm->name() => 1});

            my $number_of_insertions = $additional_transformant_info->{$name}->{'number_of_insertions'};
            if ($number_of_insertions) {
                $accession_stock->create_stockprops({$number_of_insertions_cvterm->name() => $number_of_insertions});
            }
        }
        CXGN::Pedigree::Parentage->assert_acyclic($schema, \@added_stock_ids);
        # New stock IDs have no previous owners. Keep the standard owner rows
        # on this transaction's handle so callers can roll back a whole batch.
        for my $stock_id (@added_stock_ids) {
            $schema->storage->dbh->do(
                'INSERT INTO phenome.stock_owner (stock_id, sp_person_id) VALUES (?, ?)',
                undef, $stock_id, $owner_id);
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        return { error => $transaction_error };
    }

    return { success => 1};

}



#######
1;
#######
