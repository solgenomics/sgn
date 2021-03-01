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
    my $new_transaction_info = $self->get_transaction_info();
    my %new_transaction_info_hash = %{$new_transaction_info};
    my $transaction_error;

    my $coderef = sub {

        #get cross (stock of type cross)
        my $cross_stock = $self->_get_cross($cross_unique_id);
        if (!$cross_stock) {
            print STDERR "Cross could not be found\n";
            return;
        }

        my $cross_transaction_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'cross_transaction_json', 'stock_property');
        my $crossing_metadata_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'crossing_metadata_json', 'stock_property');

        my $previous_stockprop_rs = $cross_stock->stockprops({type_id=>$cross_transaction_cvterm->cvterm_id});
        my $total_number_of_flowers = 0;
        my $total_number_of_fruits = 0;
        my $total_number_of_seeds = 0;
        my %transaction_hash;
        my %summary_info_hash;

        if ($previous_stockprop_rs->count == 1){
            my $transaction_json_string = $previous_stockprop_rs->first->value();
            my $transaction_hash_ref = decode_json $transaction_json_string;
            %transaction_hash = %{$transaction_hash_ref};
            foreach my $new_transaction_id(keys %new_transaction_info_hash) {
                my $activity_info = $new_transaction_info_hash{$new_transaction_id};
                $transaction_hash{$new_transaction_id} = $activity_info;
            }

            my $updated_transaction_json_string = encode_json \%transaction_hash;
            $previous_stockprop_rs->first->update({value => $updated_transaction_json_string});

        } elsif ($previous_stockprop_rs->count > 1) {
            print STDERR "Error: More than one found!\n";
            return;
        } else {
            my $new_transaction_json_string = encode_json $new_transaction_info;
#            print STDERR "NEW TRANSACTION JSON STRING =".Dumper($new_transaction_json_string)."\n";
            $cross_stock->create_stockprops({$cross_transaction_cvterm->name() => $new_transaction_json_string});

            %transaction_hash = %new_transaction_info_hash;
        }

        foreach my $transaction_id(keys %transaction_hash) {
            my $number_of_flowers = $transaction_hash{$transaction_id}{'Number of Flowers'};
            $total_number_of_flowers += $number_of_flowers;

            my $number_of_fruits = $transaction_hash{$transaction_id}{'Number of Fruits'};
            $total_number_of_fruits += $number_of_fruits;

            my $number_of_seeds = $transaction_hash{$transaction_id}{'Number of Seeds'};
            $total_number_of_seeds += $number_of_seeds;
        }

        $summary_info_hash{'Number of Flowers'} = $total_number_of_flowers;
        $summary_info_hash{'Number of Fruits'} = $total_number_of_fruits;
        $summary_info_hash{'Number of Seeds'} = $total_number_of_seeds;

        foreach my $info_type(keys %summary_info_hash){
            my $value = $summary_info_hash{$info_type};
            my $cross_summary_info = CXGN::Pedigree::AddCrossInfo->new({
                chado_schema => $schema,
                cross_name => $cross_unique_id,
                key => $info_type,
                value => $value,
                data_type => 'crossing_metadata_json'
            });
            $cross_summary_info->add_info();
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
