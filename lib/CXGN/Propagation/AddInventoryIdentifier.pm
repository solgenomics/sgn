=head1 NAME

CXGN::Propagation::AddInventoryIdentifier - a module for adding propagation Inventory Identifier

=cut


package CXGN::Propagation::AddInventoryIdentifier;

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

has 'inventory_identifier' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'propagation_stock_id' => (
    isa =>'Int',
    is => 'rw',
    required => 1,
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);


sub existing_inventory_identifier {
    my $self = shift;
    my $inventory_identifier = $self->get_inventory_identifier();
    my $schema = $self->get_chado_schema();
    if($schema->resultset('Stock::Stock')->find({name=>$inventory_identifier})){
        return 1;
    } else {
        return;
    }
}


sub add {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $inventory_identifier = $self->get_inventory_identifier();
    my $propagation_stock_id = $self->get_propagation_stock_id();
    my $owner_id = $self->get_owner_id();
    my %return;
    my $inventory_stock_id;

    if ($self->existing_inventory_identifier()){
        return {error => "Error: inventory identifier already exists, please use another inventory identifier!"};
    }

    my $coderef = sub {

        my $propagation_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation', 'stock_type')->cvterm_id();
        my $inventory_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'inventory', 'stock_type')->cvterm_id();
        my $propagation_inventory_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_inventory_of', 'stock_relationship')->cvterm_id();

        my $inventory_identifier_stock = $schema->resultset("Stock::Stock")->find_or_create({
            name => $inventory_identifier,
            uniquename => $inventory_identifier,
            type_id => $inventory_cvterm_id,
        });

        $inventory_stock_id = $inventory_identifier_stock->stock_id();

        $inventory_identifier_stock->find_or_create_related('stock_relationship_objects', {
            type_id => $propagation_inventory_of_cvterm_id,
            object_id => $propagation_stock_id,
            subject_id => $inventory_stock_id,
        });
    };
    print STDERR "INVENTORY STOCK ID =".Dumper($inventory_stock_id)."\n";
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
            stock_id => $inventory_stock_id,
            sp_person_id =>  $owner_id,
        });

        return { success=>1, inventory_stock_id=>$inventory_stock_id };
    }

}



#########
1;
#########
