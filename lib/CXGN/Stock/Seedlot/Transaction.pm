
package CXGN::Stock::Seedlot::Transaction;

use Moose;
use JSON::Any;
use SGN::Model::Cvterm;

has 'schema' => ( isa => 'Bio::Chado::Schema',
		  is => 'rw',
		  required => 1,
    );

has 'transaction_id' => ( isa => 'Int',
			  is => 'rw',
			  predicate => 'has_transaction_id',
    );

has 'from_stock' =>  ( isa => 'ArrayRef',
		       is => 'rw',
    );

has 'to_stock' => (isa => 'ArrayRef',
				is => 'rw',
    );

has 'amount' => (isa => 'Num',
			     is => 'rw',

    );

has 'operator' => ( isa => 'Maybe[Str]',
				is => 'rw',
    );

has 'timestamp' => ( isa => 'Maybe[Str]',
		is => 'rw',
    );

has 'factor' => ( isa => 'Int',
		  is => 'rw',
		  default => 1,
    );

has 'description' => ( isa => 'Maybe[Str]',
        is => 'rw',
    );

sub BUILD { 
    my $self = shift;
    
    if ($self->transaction_id()) { 
	my $row = $self->schema()->resultset("Stock::StockRelationship")
	    ->find( { stock_relationship_id => $self->transaction_id() }, { join => ['subject', 'object'], '+select' => ['subject.uniquename', 'subject.type_id', 'object.uniquename', 'object.type_id'], '+as' => ['subject_uniquename', 'subject_type_id', 'object_uniquename', 'object_type_id'] } );

	$self->from_stock([$row->object_id(), $row->get_column('object_uniquename'), $row->get_column('object_type_id')]);
	$self->to_stock([$row->subject_id(), $row->get_column('subject_uniquename'), $row->get_column('subject_type_id')]);
	my $data = JSON::Any->decode($row->value());
	$self->amount($data->{amount});
	$self->timestamp($data->{timestamp});
	$self->operator($data->{operator});
	$self->description($data->{description});
    }
}

# class method
sub get_transactions_by_seedlot_id { 
    my $class = shift;
    my $schema = shift;
    my $seedlot_id = shift;

    print STDERR "Get transactions by seedlot...$seedlot_id\n";
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seed transaction", "stock_relationship")->cvterm_id();
    my $rs = $schema->resultset("Stock::StockRelationship")->search({ subject_id => $seedlot_id , type_id => $type_id }, {'order_by'=>'stock_relationship_id'});
    print STDERR "Found ".$rs->count()." transactions...\n";    
    my @transactions;
    while (my $row = $rs->next()) { 

	my $t_obj = CXGN::Stock::Seedlot::Transaction->new( schema => $schema, transaction_id => $row->stock_relationship_id() );

	push @transactions, $t_obj;
    }

    $rs = $schema->resultset("Stock::StockRelationship")->search({ object_id => $seedlot_id, type_id => $type_id }, {'order_by'=>'stock_relationship_id'});

    while (my $row = $rs->next()) { 
	my $t_obj = CXGN::Stock::Seedlot::Transaction->new( schema => $schema, transaction_id => $row->stock_relationship_id() );
	print STDERR "Found negative transaction...\n";
	$t_obj->factor(-1);
	push @transactions, $t_obj;
    }

    return \@transactions;
}

sub store { 
    my $self = shift;    
    my $transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seed transaction", "stock_relationship")->cvterm_id();

    if (!$self->has_transaction_id()) {
        my $row = $self->schema()->resultset("Stock::StockRelationship")
            ->find({
                object_id => $self->from_stock()->[0],
                subject_id => $self->to_stock()->[0],
                type_id => $transaction_type_id,
            });

        my $new_rank = 0;
        if ($row) { 
            $new_rank = $row->rank()+1;
        }

        $row = $self->schema()->resultset("Stock::StockRelationship")
            ->create({
                object_id => $self->from_stock()->[0],
                subject_id => $self->to_stock()->[0],
                type_id => $transaction_type_id,
                rank => $new_rank,
                value => JSON::Any->encode({
                    amount => $self->amount(),
                    timestamp => $self->timestamp(),
                    operator => $self->operator(),
                    description => $self->description()
                }),
            });
        return $row->stock_relationship_id();
    }
    
    else { 
        # update not implemented yet.
    }	
}

sub delete {
    

}

1;



