=head1 NAME

CXGN::Propagation::AddPropagationIdentifier - a module for adding propagation identifier

=cut


package CXGN::Propagation::AddPropagationIdentifier;

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

has 'propagation_identifier' => (
    isa =>'Str',
    is => 'rw',
    required => 1,
);

has 'rootstock_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'owner_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
);

has 'propagation_group_stock_id' => (
    isa =>'Int',
    is => 'rw',
    required => 1,
);


sub add_propagation_identifier {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $phenome_schema = $self->get_phenome_schema();
    my $propagation_identifier = $self->get_propagation_identifier();
    my $propagation_group_stock_id = $self->get_propagation_group_stock_id();
    my $rootstock_name = $self->get_rootstock_name();
    my $owner_id = $self->get_owner_id();
    my %return;
    my $propagation_stock_id;
    my $rootstock_stock_id;
    my $coderef = sub {
        my $propagation_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation', 'stock_type')->cvterm_id();
        my $propagation_rootstock_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_rootstock_of', 'stock_relationship')->cvterm_id();
        my $propagation_member_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_member_of', 'stock_relationship')->cvterm_id();
        my $propagation_material_of_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema,  'propagation_material_of', 'stock_relationship')->cvterm_id();
        my $accession_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();

        my $propagation_material = $schema->resultset("Stock::StockRelationship")->find ({
            object_id => $propagation_group_stock_id,
            type_id => $propagation_material_of_cvterm_id,
        });

        my $propagation_material_stock_id = $propagation_material->subject_id();

        if ($rootstock_name) {
            my $rootstock_rs = $schema->resultset("Stock::Stock")->find({
                uniquename => $rootstock_name,
                type_id => $accession_cvterm_id,
            });

            if ($rootstock_rs) {
                $rootstock_stock_id = $rootstock_rs->stock_id();
            }
        }

        my $propagation_identifier_stock = $schema->resultset("Stock::Stock")->find_or_create({
            name => $propagation_identifier,
            uniquename => $propagation_identifier,
            type_id => $propagation_cvterm_id,
        });

        $propagation_stock_id = $propagation_identifier_stock->stock_id();

        if ($rootstock_stock_id) {
            $propagation_identifier_stock->find_or_create_related('stock_relationship_objects', {
                type_id => $propagation_rootstock_of_cvterm_id,
                object_id => $propagation_stock_id,
                subject_id => $rootstock_stock_id,
            });            
        }

        $propagation_identifier_stock->find_or_create_related('stock_relationship_objects', {
            type_id => $propagation_member_of_cvterm_id,
            object_id => $propagation_group_stock_id,
            subject_id => $propagation_stock_id,
        });

        $propagation_identifier_stock->find_or_create_related('stock_relationship_objects', {
            type_id => $propagation_material_of_cvterm_id,
            object_id => $propagation_stock_id,
            subject_id => $propagation_material_stock_id,
        });

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
            sp_person_id =>  $owner_id,
        });

        return { success=>1, propagation_stock_id=>$propagation_stock_id };
    }

}



#########
1;
#########
