
package CXGN::Stock::Seedlot::Transaction;

use Moose;
use JSON::Any;
use SGN::Model::Cvterm;
use Data::Dumper;

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

has 'amount' => (
    isa => 'Num|Str',
    is => 'rw',
);

has 'weight_gram' => (
    isa => 'Num|Str',
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

has 'seedlot_id' => (
    isa => 'Int',
    is => 'rw',
);


sub BUILD {
    my $self = shift;
    my $seedlot_id = $self->seedlot_id();
    if ($self->transaction_id()) {
        my $row = $self->schema()->resultset("Stock::StockRelationship")->find( { stock_relationship_id => $self->transaction_id() }, { join => ['subject', 'object'], '+select' => ['subject.uniquename', 'subject.type_id', 'object.uniquename', 'object.type_id'], '+as' => ['subject_uniquename', 'subject_type_id', 'object_uniquename', 'object_type_id'] } );

        $self->from_stock([$row->object_id(), $row->get_column('object_uniquename'), $row->get_column('object_type_id')]);
        $self->to_stock([$row->subject_id(), $row->get_column('subject_uniquename'), $row->get_column('subject_type_id')]);
        my $data = JSON::Any->decode($row->value());
        $self->amount($data->{amount});
        if ($data->{weight_gram}){
            $self->weight_gram($data->{weight_gram});
        } else {
            $self->weight_gram('NA');
        }
        $self->timestamp($data->{timestamp});
        $self->operator($data->{operator});
        $self->description($data->{description});

        if ($row->subject_id == $row->object_id) {
            $self->factor($data->{factor});
        } else {
	        if ($row->subject_id == $seedlot_id){
                $self->factor(1);
            } elsif ($row->object_id == $seedlot_id){
                $self->factor(-1);
            }
        }
    }
}

# class method
sub get_transactions_by_seedlot_id {
    my $class = shift;
    my $schema = shift;
    my $seedlot_id = shift;

    print STDERR "Get transactions by seedlot...$seedlot_id\n";
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seed transaction", "stock_relationship")->cvterm_id();
    my $rs = $schema->resultset("Stock::StockRelationship")->search(
        { '-or' =>
            [
                subject_id => $seedlot_id,
                object_id => $seedlot_id
            ],
            'me.type_id' => $type_id
        },
        {
            'join' => ['subject', 'object'],
            '+select' => ['subject.uniquename', 'subject.type_id', 'object.uniquename', 'object.type_id'],
            '+as' => ['subject_uniquename', 'subject_type_id', 'object_uniquename', 'object_type_id'],
            'order_by'=>{'-desc'=>'me.stock_relationship_id'}
        }
    );

    print STDERR "Found ".$rs->count()." transactions...\n";
    my @transactions;
    while (my $row = $rs->next()) {
        my $t_obj = CXGN::Stock::Seedlot::Transaction->new( schema => $schema );
        $t_obj->transaction_id($row->stock_relationship_id);
        $t_obj->from_stock([$row->object_id(), $row->get_column('object_uniquename'), $row->get_column('object_type_id')]);
        $t_obj->to_stock([$row->subject_id(), $row->get_column('subject_uniquename'), $row->get_column('subject_type_id')]);
        my $data = JSON::Any->decode($row->value());
        if (defined($data->{weight_gram})){
            $t_obj->weight_gram($data->{weight_gram});
        } else {
            $t_obj->weight_gram('NA');
        }
        if (defined($data->{amount})){
            $t_obj->amount($data->{amount});
        } else {
            $t_obj->amount('NA');
        }
        $t_obj->timestamp($data->{timestamp});
        $t_obj->operator($data->{operator});
        $t_obj->description($data->{description});
        if ($row->subject_id == $seedlot_id){
            $t_obj->factor(1);
        }
        if($row->object_id == $seedlot_id){
            $t_obj->factor(-1);
        }
        #in the special case for a transaction between a single seedlot, factor is stored as 1 or -1 depending on if seed was added or taken.
        if($data->{factor}){
            $t_obj->factor($data->{factor});
        }
        push @transactions, $t_obj;
    }

    return \@transactions;
}

sub get_transactions {
    my $class = shift;
    my $schema = shift;
    my $seedlot_id = shift;
    my $transaction_id = shift;
    my $germplasm_id = shift;
    my $limit = shift;
    my $offset = shift;

    my %filter;
    my @ids;

    if($seedlot_id){
        push @ids, $seedlot_id;
    }
    if($transaction_id){
        $filter{'me.stock_relationship_id'} =  $transaction_id;
    }

    if($germplasm_id){
        my $trial_related_stock = CXGN::Stock::RelatedStocks->new({dbic_schema => $schema, stock_id =>$germplasm_id});
        my $result = $trial_related_stock->get_trial_related_stock();

        foreach (@$result){
            my $id = $_->[0];
            if (!$seedlot_id || $seedlot_id eq $id ){
                push @ids, $id;
            }
        }
    }

    if (@ids){
        $filter{"-or"} = [
                subject_id => { -in => \@ids },
                object_id => { -in => \@ids },
            ];
    }

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seed transaction", "stock_relationship")->cvterm_id();
    $filter{'me.type_id'} =  { '-in' => $type_id };

    my $rs = $schema->resultset("Stock::StockRelationship")->search(
        \%filter,
        {
            'join' => ['subject', 'object'],
            '+select' => ['subject.uniquename', 'subject.type_id', 'object.uniquename', 'object.type_id'],
            '+as' => ['subject_uniquename', 'subject_type_id', 'object_uniquename', 'object_type_id'],
            'order_by'=>{'-desc'=>'me.stock_relationship_id'},
        }
    );
    my $total_count = $rs->count();
    if (defined($limit) && defined($offset)){
        $rs = $rs->slice($offset, $limit);
    }

    my @transactions;
    while (my $row = $rs->next()) {
        my $t_obj = CXGN::Stock::Seedlot::Transaction->new( schema => $schema, transaction_id=> $row->stock_relationship_id());
        #$t_obj->transaction_id($row->stock_relationship_id);
        #$t_obj->from_stock([$row->object_id(), $row->get_column('object_uniquename'), $row->get_column('object_type_id')]);
        #$t_obj->to_stock([$row->subject_id(), $row->get_column('subject_uniquename'), $row->get_column('subject_type_id')]);
        #my $data = JSON::Any->decode($row->value());
        #if (defined($data->{weight_gram})){
        #    $t_obj->weight_gram($data->{weight_gram});
        #} else {
        #    $t_obj->weight_gram('NA');
        #}
        #if (defined($data->{amount})){
        #    $t_obj->amount($data->{amount});
        #} else {
        #    $t_obj->amount('NA');
        #}
        #$t_obj->timestamp($data->{timestamp});
        #$t_obj->operator($data->{operator});
        #$t_obj->description($data->{description});

        push @transactions, $t_obj;
    }

    return \@transactions, $total_count;
}

sub store {
    my $self = shift;
    my $transaction_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seed transaction", "stock_relationship")->cvterm_id();
    my $amount = defined($self->amount()) && length($self->amount()) ? $self->amount() : 'NA';
    my $weight = defined($self->weight_gram()) && length($self->weight_gram()) ? $self->weight_gram() : 'NA';
    my $value = {
        amount => $amount,
        weight_gram => $weight,
        timestamp => $self->timestamp(),
        operator => $self->operator(),
        description => $self->description(),
    };

    #In the special case where the transaction is between the same seedlot
    if($self->from_stock()->[0] == $self->to_stock()->[0]){
        $value->{factor} = $self->factor();
    }
    #print STDERR Dumper $value;
    my $json_value = JSON::Any->encode($value);

    if (!$self->has_transaction_id()) {
        my $row_rs = $self->schema()->resultset("Stock::StockRelationship")
            ->search({
                object_id => $self->from_stock()->[0],
                subject_id => $self->to_stock()->[0],
                type_id => $transaction_type_id,
            }, {order_by => { -desc => 'rank'} });

        my $new_rank = 0;
        if ($row_rs->first) {
            $new_rank = $row_rs->first->rank()+1;
        }
        #print STDERR Dumper $new_rank;

        my $row = $self->schema()->resultset("Stock::StockRelationship")
            ->create({
                object_id => $self->from_stock()->[0],
                subject_id => $self->to_stock()->[0],
                type_id => $transaction_type_id,
                rank => $new_rank,
                value => $json_value,
            });
        return $row->stock_relationship_id();
    }

    else {
        my $row = $self->schema()->resultset("Stock::StockRelationship")->find({ stock_relationship_id => $self->transaction_id });
        $row->update({
            value => $json_value
        });
        return $row->stock_relationship_id();
    }
}

sub update_transaction_subject_id {
    my $self = shift;
    my $new_subject_id = shift;
    my $row = $self->schema()->resultset("Stock::StockRelationship")->find({ stock_relationship_id => $self->transaction_id });
    $row->update({
        subject_id => $new_subject_id
    });
    return $row->stock_relationship_id();
}

sub update_transaction_object_id {
    my $self = shift;
    my $new_object_id = shift;
    my $row = $self->schema()->resultset("Stock::StockRelationship")->find({ stock_relationship_id => $self->transaction_id });
    $row->update({
        object_id => $new_object_id
    });
    return $row->stock_relationship_id();
}

sub delete_transaction {
    my $self = shift;
    my $row = $self->schema()->resultset("Stock::StockRelationship")->find({ stock_relationship_id => $self->transaction_id });
    $row->delete();
    return $row->stock_relationship_id();
}

1;
