package CXGN::Pedigree::AddCrossTransaction;

=head1 NAME

CXGN::Pedigree::AddCrossTransaction - a module to store crossing activities based on transaction ids.

=head1 USAGE

my $cross_transaction = CXGN::Pedigree::AddCrossTransaction->new({ chado_schema => $chado_schema, cross_name => $cross_name, transaction_info => $transaction_info} );
$cross_transaction->add_transaction();

=head1 DESCRIPTION

Stores crossing activities based on transaction_ids in json string format as stockprop of each cross. The cross must already exist in the database.

=head1 AUTHORS

Titima Tantikanjana <tt15@cornell.edu>

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

has 'chado_schema' => (isa => 'DBIx::Class::Schema', is => 'rw', predicate => 'has_chado_schema', required => 1);
has 'cross_unique_id' => (isa =>'Str', is => 'rw', predicate => 'has_cross_unique_id', required => 1);
has 'transaction_info' => (isa => "HashRef", is => 'rw', predicate => 'has_transaction_info', required => 1);

sub add_intercross_transaction {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $cross_unique_id = $self->get_cross_unique_id();
    my $transaction_info = $self->get_transaction_info();
    my %transaction_info_hash = %{$transaction_info};
    my $transaction_error;

    #add all cross transaction in a single transaction
    my $coderef = sub {

        #get cross (stock of type cross)
        my $cross_stock = $self->_get_cross($self->get_cross_name());
        if (!$cross_stock) {
            print STDERR "Cross could not be found\n";
            return;
        }

        my $cross_transaction_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_transaction_json', 'stock_property');

        my $transaction_json_string;
        my $transaction_json_hash = {};
        my $previous_stockprop_rs = $cross_stock->stockprops({type_id=>$cross_transaction_cvterm->cvterm_id});
        if ($previous_stockprop_rs->count == 1){
            $transaction_json_string = $previous_stockprop_rs->first->value();
            $transaction_json_hash = decode_json $transaction_json_string;

            foreach my $transaction_id(keys %transaction_info_hash) {
                my $activity_info = $transaction_info_hash{$transaction_id};
                $transaction_json_hash->{$transaction_id} = $activity_info;
            }

            my $update_transaction_json_string = encode_json $transaction_json_hash;
            $previous_stockprop_rs->first->update({value => $update_transaction_json_string});

        } elsif ($previous_stockprop_rs->count > 1) {
            print STDERR "Error: More than one found!\n";
            return;
        } else {
            my $new_transaction_json_string = encode_json %transaction_info_hash;
            $cross_stock->create_stockprops({$cross_transaction_cvterm->name() => $new_transaction_json_string});
        }

    };

    #try to add all cross info in a transaction
    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error storing crossing activities: $transaction_error\n";
        return;
    }

    return 1;
}

sub _get_cross {
    my $self = shift;
    my $cross_name = shift;
    my $schema = $self->get_chado_schema();
    my $stock_lookup = CXGN::Stock::StockLookup->new(schema => $schema);
    my $stock;
    my $cross_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'cross', 'stock_type');

    $stock_lookup->set_stock_name($cross_name);
    $stock = $stock_lookup->get_cross_exact();

    if (!$stock) {
        print STDERR "Cross name does not exist\n";
        return;
    }
    return $stock;
}

#######
1;
#######
