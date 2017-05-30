
=head1 NAME

CXGN::Seedlot - a class to represent seedlots in the database

=head1 DESCRIPTION

CXGN::Seedlot inherits from CXGN::Stock. The required fields are:

uniquename

location_code

Seed transactions can be added using CXGN::Seedlot::Transaction.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 ACCESSORS & METHODS 

=cut

package CXGN::Seedlot;

use Moose;

extends 'CXGN::Stock';

use Data::Dumper;
use CXGN::Seedlot::Transaction;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;

=head2 Accessor seedlot_id()

the database id of the seedlot. Is equivalent to stock_id.

=cut

has 'seedlot_id' => ( isa => 'Maybe[Int]',
		      is => 'rw',
    );

=head2 Accessor location_code()

A string specifiying where the seedlot is stored. On the backend,
this is stored int he description field.

=cut

has 'location_code' => ( isa => 'Str',
		    is => 'rw',
    );

=head2 Accessor cross()

The cross this seedlot is associated with. Not yet implemented.

=cut

has 'cross' => ( isa => 'CXGN::Cross',
		 is => 'rw',
    );

has 'cross_stock_id' =>   ( isa => 'Int',
			    is => 'rw',
    );

=head2 Accessor accessions()

The accessions this seedlot is associated with.

=cut

has 'accessions' => (
    isa => 'ArrayRef[ArrayRef]',
    is => 'rw',  # for setter, use accession_stock_id
);

has 'accession_stock_ids' => (
    isa => 'ArrayRef[Int]',
    is => 'rw',
);

=head2 Accessor transactions()

a ArrayRef of CXGN::Seedlot::Transaction objects

=cut

has 'transactions' =>     ( isa => 'ArrayRef',
			    is => 'rw',
			    default => sub { [] },
    );


after 'stock_id' => sub { 
    my $self = shift;
    my $id = shift;
    return $self->seedlot_id($id);
};

# class method
=head2 Class method: list_seedlots()

 Usage:        my $seedlots = CXGN::Seedlot->list_seedlots($schema);
 Desc:         Class method that returns information on all seedlots 
               available in the system
 Ret:          ArrayRef of [ seedlot_id, seedlot name, location_code] 
 Args:         $schema - Bio::Chado::Schema object
 Side Effects: accesses the database

=cut

sub list_seedlots { 
    my $class = shift;
    my $schema = shift;
    
    my $seedlots;
    
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "seedlot", "stock_type")->cvterm_id();
    print STDERR "TYPE_ID = $type_id\n";
    my $rs = $schema->resultset("Stock::Stock")->search( { type_id => $type_id });
    while (my $row = $rs->next()) { 
	push @$seedlots, [ $row->stock_id, $row->uniquename, $row->description];
    }
    return $seedlots;
}

sub BUILDARGS { 
    my $orig = shift;
    my %args = @_;
    $args{stock_id} = $args{seedlot_id};
    return \%args;
}

sub BUILD {
    my $self = shift;

    if ($self->seedlot_id()) {
        print STDERR Dumper $self->seedlot_id;
        my $transactions = CXGN::Seedlot::Transaction->get_transactions_by_seedlot_id($self->schema(), $self->seedlot_id());
        #print STDERR Dumper($transactions);
        $self->transactions($transactions);
        $self->name($self->uniquename());
        $self->location_code($self->description());
        $self->seedlot_id($self->stock_id());
        $self->_retrieve_accessions();
        $self->_retrieve_organizations();
        $self->_retrieve_population();
        #$self->cross($self->_retrieve_cross());
    }
    print STDERR Dumper $self->seedlot_id;
}


sub _store_cross { 
    my $self = shift;
    
    


}

sub _retrieve_cross {
    my $self = shift;

}

sub _remove_cross {
    my $self = shift;
    
    
    
}

sub _store_seedlot_relationships {
    my $self = shift;

    foreach my $a (@{$self->accession_stock_ids()}) { 
        my $organism_id = $self->schema->resultset('Stock::Stock')->find({stock_id => $a})->organism_id();
        if ($self->organism_id){
            if ($self->organism_id != $organism_id){
                die "Accessions must all be the same organism, so that a population can group the seed lots.\n";
            }
        }
        $self->organism_id($organism_id);
    }

    eval { 
        my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();

        foreach my $a (@{$self->accession_stock_ids()}) { 
            my $already_exists = $self->schema()->resultset("Stock::StockRelationship")->find({ object_id => $self->seedlot_id(), type_id => $type_id, subject_id=>$a });

            if ($already_exists) { 
                print STDERR "Accession with id $a is already associated with seedlot id ".$self->seedlot_id()."\n";
                next; 
            }
            my $row = $self->schema()->resultset("Stock::StockRelationship")->create({
                object_id => $self->seedlot_id(),
                subject_id => $a,
                type_id => $type_id,
            });
        }
    };

    if ($@) { 
	die $@;
    }    
}

sub _retrieve_accessions {
    my $self = shift;

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "collection_of", "stock_relationship")->cvterm_id();

    my $rs = $self->schema()->resultset("Stock::StockRelationship")->search( { type_id => $type_id, object_id => $self->seedlot_id() } );

    my @accession_ids;
    while (my $row = $rs->next()) { 
	push @accession_ids, $row->subject_id();
    }

    $self->accession_stock_ids(\@accession_ids);

    $rs = $self->schema()->resultset("Stock::Stock")->search( { stock_id => { in => \@accession_ids }});
    my @names;
    while (my $s = $rs->next()) { 
        push @names, [ $s->stock_id(), $s->uniquename() ];
    }
    $self->accessions(\@names);
}

sub _remove_accession {
    my $self = shift;
}

=head2 Method current_count()

 Usage:        my $current_count = $sl->current_count();
 Desc:         returns the current balance of seeds in the seedlot
 Ret:          a number
 Args:         none
 Side Effects: retrieves transactions from db and calculates count
 Example:

=cut

sub current_count { 
    my $self = shift;
    my $transactions = $self->transactions();
    
    my $count = 0;
    foreach my $t (@$transactions) { 
	$count += $t->amount() * $t->factor();
    }
    return $count;
}

sub _add_transaction { 
    my $self = shift;
    my $transaction = shift;

    my $transactions = $self->transactions();
    push @$transactions, $transaction;

    $self->transactions($transactions);
}

=head2 store()

 Usage:        my $seedlot_id = $sl->store();
 Desc:         stores the current state of the object to the db
 Ret:          the seedlot id.
 Args:         none
 Side Effects: accesses the db. Creates a new seedlot ID if not
               already existing.
 Example:

=cut

sub store { 
    my $self = shift;

    print STDERR "storing: UNIQUENAME=".$self->uniquename()."\n";
    $self->description($self->location_code());
    $self->name($self->uniquename());

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'seedlot', 'stock_type')->cvterm_id();
    $self->type_id($type_id);

    my $id = $self->SUPER::store();

    print STDERR "Saving seedlot returned ID $id.\n";
    $self->seedlot_id($id);

    $self->_store_seedlot_relationships();

    foreach my $t (@{$self->transactions()}) { 
	
	print STDERR Dumper($self->transactions());
	$t->store();
    }    
    return $self->seedlot_id();
}

1;

no Moose;
__PACKAGE__->meta->make_immutable;
