
package CXGN::Seedlot;

use Moose;
use Data::Dumper;

has 'schema' => ( isa => 'Bio::Chado::Schema',
		  is => 'rw',
		  required => 1,
    );

has 'seedlot_id' => ( isa => 'Int',
		      is => 'rw',
		      predicate => 'has_seedlot_id',
    );

has 'name' => ( isa => 'Str',
		is  => 'rw',
    );

has 'location_code' => ( isa => 'Str',
		    is => 'rw',
    );

has 'cross' => ( isa => 'CXGN::Cross',
		 is => 'rw',
    );

has 'cross_stock_id' =>   ( isa => 'Int',
			    is => 'rw',
    );

has 'accession' =>        ( isa => 'CXGN::Chado::Stock',
			    is => 'rw',
    );

has 'accession_stock_id' => (isa => 'Int',
			     is => 'rw',
    );

has 'organism_id' =>      ( isa => 'Int',
			    is => 'rw',
			    default => 1,
    );

has 'transactions' =>     ( isa => 'ArrayRef',
			    is => 'rw',
			    default => sub { [] },
    );

has 'breeding_program' => ( isa => 'Str',
			    is => 'rw',
			    
    );


sub BUILD {
    my $self = shift;
    
    if ($self->has_seedlot_id()) { 
	my $row = $self->schema()->resultset("Stock::Stock")->find({ stock_id => $self->seedlot_id() });
	$self->name($row->uniquename());
	$self->location_code($row->description());
	
	$self->transactions( 
	    CXGN::Seedlot::Transaction->get_transactions_by_seedlot_id(
		$self->schema(), $self->seedlot_id()
	    ));
    }
}

sub associate_breeding_program { 
    my $self = shift;

}

sub current_count { 
    my $self = shift;
    my $transactions = $self->transactions();
    
    my $count = 0;
    foreach my $t (@$transactions) { 
	$count += $t->amount() * $t->factor();
    }
    return $count;
}
 
sub add_transaction { 
    my $self = shift;
    my $transaction = shift;

    my $transactions = $self->transactions();
    push @$transactions, $transaction;

    $self->transactions($transactions);
}

sub store { 
    my $self = shift;

    my $type_id = $self->schema()->resultset("Cv::Cvterm")->
	find( { name => "seedlot" })->cvterm_id();

    
    
    if (! $self->has_seedlot_id()) { 
	my $row = $self->schema()->resultset("Stock::Stock")->create( 
	    { 
		description => $self->location_code(),
		uniquename => $self->name(),
		name => $self->name(),
		type_id => $type_id,	
	    });
	
	$row->update();
	
	my $stock_id = $row->stock_id();
	$self->seedlot_id($stock_id);

	foreach my $t (@{$self->transactions()}) { 

	    print STDERR Dumper($self->transactions());
	    $t->store();
	}
	
	return $stock_id;
    }
    
    else { 
    
	die "Update not implemented yet.";

    }
	

}

1;
