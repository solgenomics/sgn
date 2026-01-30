package CXGN::Propagation::Status;


=head1 NAME

CXGN::Propagation::Status - a class to manage propagation status

=head1 DESCRIPTION

The stock_property of type "propagation_status" is stored as JSON.

=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut


use Moose;

#use JSON::Any;
#use Data::Dumper;
#use SGN::Model::Cvterm;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::Stock::StockLookup;
use SGN::Model::Cvterm;
use Data::Dumper;
use JSON;

has 'chado_schema' => (
    isa => 'DBIx::Class::Schema',
    is => 'rw',
    required => 1,
);

has 'propagation_stock_id' => (
    isa => 'Int',
    is => 'rw',
    required => 1
);

has 'status_type' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'update_person' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'update_date' => (
    isa => 'Str',
    is => 'rw',
    required => 1
);

has 'update_notes' => (
    isa => 'Str',
    is => 'rw'
);


sub add_status_info {
    my $self = shift;
    my $schema = $self->get_chado_schema();
    my $transaction_error;

    my $coderef = sub {
        my $propagation_stock_id = $self->get_propagation_stock_id();
        my $status_type = $self->get_status_type();
        my $update_person = $self->get_update_person();
        my $update_date = $self->get_update_date();
        my $update_notes = $self->get_update_notes();
        my %new_status_hash;
        $new_status_hash{'status_type'} = $status_type;
        $new_status_hash{'update_date'} = $update_date;
        $new_status_hash{'update_person'} = $update_person;
        $new_status_hash{'update_notes'} = $update_notes;            

        my $propagation_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation', 'stock_type');
        my $propagation_status_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'propagation_status', 'stock_property');

        my $status_string;
        my @status_array;
        my $previous_status_rs = $schema->resultset("Stock::Stockprop")->search({ stock_id => $propagation_stock_id, type_id => $propagation_status_cvterm->cvterm_id});
        if ($previous_status_rs->count == 1){
            my $status_history = $previous_status_rs->first->value();
            my $all_statuses = decode_json $status_history;
            print STDERR "STATUS HISTORY =".Dumper($status_history)."\n";
            @status_array = @$all_statuses;
            push @status_array, \%new_status_hash;
            $status_string = encode_json \@status_array;
            print STDERR "STATUS STRING 1 =".Dumper($status_string)."\n";
            $previous_status_rs->first->update({value=>$status_string});
        } elsif ($previous_status_rs->count > 1) {
            print STDERR "More than one found!\n";
            return;
        } else {
            @status_array = (\%new_status_hash);
            $status_string = encode_json \@status_array;
            print STDERR "STATUS STRING 2 =".Dumper($status_string)."\n";
            my $propagation_identifier = $schema->resultset("Stock::Stock")->find({ stock_id => $propagation_stock_id, type_id => $propagation_cvterm->cvterm_id});
            $propagation_identifier->create_stockprops({$propagation_status_cvterm->name() => $status_string});
        }

    };

    try {
        $schema->txn_do($coderef);
    } catch {
        $transaction_error =  $_;
    };

    if ($transaction_error) {
        print STDERR "Transaction error storing status information: $transaction_error\n";
        return;
    }

    return 1;
}



1;
