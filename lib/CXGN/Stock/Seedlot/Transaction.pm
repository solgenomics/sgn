
package CXGN::Stock::Seedlot::Transaction;

use Moose;
use JSON::Any;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::JSONUtils qw(decode_stored_json);

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
        my $data = decode_stored_json($row->value());
        $self->amount($data->{amount});
        if (defined($data->{weight_gram})){
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
        my $data = decode_stored_json($row->value());
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
        #my $data = decode_stored_json($row->value());
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

# Mutations use the same stock-row semaphore as shared seedlot recounts.
# Direct layout projects precede old/current/requested lot and relationship
# locks, including when
# this method is nested inside a creator/upload transaction.
sub _mutation_scope {
    my ($self,$endpoints)=@_;
    return {projects=>[],lots=>[]} if !@$endpoints;
    my $schema=$self->schema;
    my $lot_type=SGN::Model::Cvterm->get_cvterm_row($schema,'seedlot','stock_type')->cvterm_id;
    my $lots=$schema->storage->dbh->selectcol_arrayref(
        'SELECT stock_id FROM stock WHERE stock_id=ANY(?) AND type_id=? ORDER BY stock_id',undef,$endpoints,$lot_type);
    # Only direct physical-layout membership on this same BCS handle applies.
    # Phenotyping/analysis associations and standalone lot transfers do not
    # acquire unrelated project locks.
    my $projects=$schema->storage->dbh->selectcol_arrayref(q{
        SELECT DISTINCT nep.project_id FROM nd_experiment_stock nes
        JOIN stock unit ON unit.stock_id=nes.stock_id
        JOIN cvterm st ON st.cvterm_id=unit.type_id
        JOIN cv scv ON scv.cv_id=st.cv_id AND scv.name='stock_type'
        JOIN nd_experiment ne USING(nd_experiment_id)
        JOIN cvterm et ON et.cvterm_id=ne.type_id
        JOIN cv ecv ON ecv.cv_id=et.cv_id AND ecv.name='experiment_type'
        JOIN nd_experiment_project nep USING(nd_experiment_id)
        WHERE nes.stock_id=ANY(?)
          AND st.name IN ('plot','plant','subplot','tissue_sample')
          AND et.name IN ('field_layout','genotyping_layout','sampling_layout')
        ORDER BY nep.project_id
    },undef,$endpoints);
    return {projects=>$projects,lots=>$lots};
}

# Batch creators/uploaders must lock their complete union before entering a
# mutation loop. Read the same direct-layout scope used by individual writes;
# this method does not acquire locks or change any transaction value.
sub mutation_scope {
    my ($self,$endpoint_ids)=@_;
    return $self->_mutation_scope($endpoint_ids);
}

sub _with_mutation_locks {
    my ($self, $extra_endpoints, $operation) = @_;
    my $schema=$self->schema;
    my $result;
    $schema->txn_do(sub {
        my $before;
        if ($self->has_transaction_id) {
            $before=$schema->resultset('Stock::StockRelationship')->find($self->transaction_id);
            die "The seed transaction no longer exists; reload it before editing.\n" if !$before;
        }
        my @endpoints=(
            ($self->from_stock ? $self->from_stock->[0] : ()),
            ($self->to_stock ? $self->to_stock->[0] : ()),
            ($before ? ($before->object_id,$before->subject_id) : ()),
            @$extra_endpoints,
        );
        my %seen;
        @endpoints=grep {defined($_) && !$seen{$_}++} @endpoints;
        my $scope=$self->_mutation_scope(\@endpoints);
        $schema->storage->dbh->selectcol_arrayref(
            'SELECT project_id FROM project WHERE project_id=ANY(?) ORDER BY project_id FOR UPDATE',undef,$scope->{projects})
            if @{$scope->{projects}};
        require CXGN::Stock::Seedlot;
        CXGN::Stock::Seedlot::lock_for_recount($schema,$scope->{lots});
        my $current_scope=$self->_mutation_scope(\@endpoints);
        die "The seed transaction layout or lot membership changed while locking; reload it before editing.\n"
            if join(',',@{$scope->{projects}}) ne join(',',@{$current_scope->{projects}}) ||
               join(',',@{$scope->{lots}}) ne join(',',@{$current_scope->{lots}});
        my $row;
        if ($before) {
            my $locked=$schema->storage->dbh->selectrow_hashref(
                'SELECT object_id,subject_id,type_id FROM stock_relationship WHERE stock_relationship_id=? FOR UPDATE',undef,$self->transaction_id);
            die "The seed transaction changed or was removed; reload it before editing.\n"
                if !$locked || $locked->{object_id}!=$before->object_id || $locked->{subject_id}!=$before->subject_id || $locked->{type_id}!=$before->type_id;
            my $type=SGN::Model::Cvterm->get_cvterm_row($schema,'seed transaction','stock_relationship')->cvterm_id;
            die "The selected relationship is not a seed transaction.\n" if $locked->{type_id}!=$type;
            die "The seed transaction endpoints changed; reload it before editing.\n"
                if ($self->from_stock && $self->from_stock->[0]!=$locked->{object_id}) ||
                   ($self->to_stock && $self->to_stock->[0]!=$locked->{subject_id});
            # Read JSON after locks. A constructor-time copy can be stale and
            # must not overwrite a later correction's packet provenance.
            $row=$schema->resultset('Stock::StockRelationship')->find($self->transaction_id);
        }
        $result=$operation->($row);
    });
    return $result;
}

sub store {
    my $self=shift;
    return $self->_with_mutation_locks([],sub {
        my $existing=shift;
        my $value=$existing ? decode_stored_json($existing->value) : {};
        die "The seed transaction value must be a JSON object.\n" if ref($value) ne 'HASH';
        $value={%$value};
        $value->{amount}=defined($self->amount) && length($self->amount) ? $self->amount : 'NA';
        $value->{weight_gram}=defined($self->weight_gram) && length($self->weight_gram) ? $self->weight_gram : 'NA';
        $value->{timestamp}=$self->timestamp;
        $value->{operator}=$self->operator;
        $value->{description}=$self->description;
        $value->{factor}=$self->factor if $self->from_stock->[0]==$self->to_stock->[0];
        my $json=JSON::Any->encode($value);
        if ($existing) {
            $existing->update({value=>$json});
            return $existing->stock_relationship_id;
        }
        my $type=SGN::Model::Cvterm->get_cvterm_row($self->schema,'seed transaction','stock_relationship')->cvterm_id;
        my $previous=$self->schema->resultset('Stock::StockRelationship')->search({object_id=>$self->from_stock->[0],subject_id=>$self->to_stock->[0],type_id=>$type},{order_by=>{-desc=>'rank'}})->first;
        my $row=$self->schema->resultset('Stock::StockRelationship')->create({object_id=>$self->from_stock->[0],subject_id=>$self->to_stock->[0],type_id=>$type,rank=>$previous ? $previous->rank+1 : 0,value=>$json});
        return $row->stock_relationship_id;
    });
}

sub _update_endpoint {
    my ($self,$column,$new_id)=@_;
    return $self->_with_mutation_locks([$new_id],sub {
        my $row=shift;
        die "An existing seed transaction is required.\n" if !$row;
        $row->update({$column=>$new_id});
        my $stock=$self->schema->resultset('Stock::Stock')->find($new_id);
        my $value=[$stock->stock_id,$stock->uniquename,$stock->type_id];
        $column eq 'subject_id' ? $self->to_stock($value) : $self->from_stock($value);
        return $row->stock_relationship_id;
    });
}

sub update_transaction_subject_id {
    my ($self,$new_id)=@_;
    return $self->_update_endpoint('subject_id',$new_id);
}

sub update_transaction_object_id {
    my ($self,$new_id)=@_;
    return $self->_update_endpoint('object_id',$new_id);
}

sub delete_transaction {
    my $self=shift;
    return $self->_with_mutation_locks([],sub {
        my $row=shift;
        die "An existing seed transaction is required.\n" if !$row;
        my $id=$row->stock_relationship_id;
        $row->delete;
        return $id;
    });
}

1;
