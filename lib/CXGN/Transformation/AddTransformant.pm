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


sub add_transformant {

    my $self = shift;
    my $schema = $self->get_schema();
    my $dbh = $self->get_dbh();
    my $phenome_schema = $self->get_phenome_schema();
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

        my $accession_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type');
        my $transformant_of_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'transformant_of', 'stock_relationship');
        my $transgenic_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'transgenic', 'stock_property');
        my $female_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship');
        my $male_parent_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema,  'male_parent', 'stock_relationship');
        my $number_of_insertions_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'number_of_insertions', 'stock_property');
        my $FEC_batch_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'FEC_batch', 'stock_property');

        my $transformation_obj = CXGN::Transformation::Transformation->new({schema=>$schema, dbh=>$dbh, transformation_stock_id=>$transformation_stock_id});
        my $transformation_info = $transformation_obj->get_basic_transformation_info();
        my $plant_material_stock_id = $transformation_info->[0]->[0];
        my $organism_id = $transformation_info->[0]->[2];
        my $vector_stock_id = $transformation_info->[0]->[3];
        my $FEC_batch = $transformation_info->[0]->[5];

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
                subject_id => $plant_material_stock_id,
            });

            $accession_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $male_parent_cvterm->cvterm_id(),
                object_id => $accession_stock->stock_id(),
                subject_id => $vector_stock_id,
            });

            $accession_stock->create_stockprops({$transgenic_cvterm->name() => 1});

            my $number_of_insertions = $additional_transformant_info->{$name}->{'number_of_insertions'};
            if ($number_of_insertions) {
                $accession_stock->create_stockprops({$number_of_insertions_cvterm->name() => $number_of_insertions});
            }

            if ($FEC_batch) {
                $accession_stock->create_stockprops({$FEC_batch_cvterm->name() => $FEC_batch});
            }
        }
    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        return { error => $transaction_error };
    } else {
        foreach my $stock_id (@added_stock_ids) {
            $phenome_schema->resultset("StockOwner")->find_or_create({
    			stock_id     => $stock_id,
    			sp_person_id =>  $owner_id,
    	    });
        }
    }

    return { success => 1};

}



#######
1;
#######
