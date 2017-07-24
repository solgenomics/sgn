
=head1 NAME

CXGN::Stock::Seedlot - a class to represent seedlots in the database

=head1 DESCRIPTION

CXGN::Stock::Seedlot inherits from CXGN::Stock. The required fields are:

uniquename

location_code

Seed transactions can be added using CXGN::Stock::Seedlot::Transaction.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=head1 ACCESSORS & METHODS 

=cut

package CXGN::Stock::Seedlot;

use Moose;

extends 'CXGN::Stock';

use Data::Dumper;
use CXGN::Stock::Seedlot::Transaction;
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
this is stored the nd_geolocation description field.

=cut

has 'location_code' => (
    isa => 'Str',
    is => 'rw',
);

has 'nd_geolocation_id' => (
    isa => 'Int',
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

a ArrayRef of CXGN::Stock::Seedlot::Transaction objects

=cut

has 'transactions' =>     ( isa => 'ArrayRef',
			    is => 'rw',
			    default => sub { [] },
    );

=head2 Accessor breeding_program

The breeding program this seedlot is from. Useful for tracking movement of seedlots across breeding programs
Use breeding_program_id as setter (to save and update seedlots).

=cut

has 'breeding_program_name' => (
    isa => 'Str',
    is => 'rw',
);

has 'breeding_program_id' => (
    isa => 'Int',
    is => 'rw',
);


after 'stock_id' => sub { 
    my $self = shift;
    my $id = shift;
    return $self->seedlot_id($id);
};

# class method
=head2 Class method: list_seedlots()

 Usage:        my $seedlots = CXGN::Stock::Seedlot->list_seedlots($schema);
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
    if ($self->stock_id()) {
        $self->seedlot_id($self->stock_id);
        my $transactions = CXGN::Stock::Seedlot::Transaction->get_transactions_by_seedlot_id($self->schema(), $self->seedlot_id());
        #print STDERR Dumper($transactions);
        $self->transactions($transactions);
        $self->name($self->uniquename());
        $self->_retrieve_location();
        $self->seedlot_id($self->stock_id());
        $self->_retrieve_accessions();
        $self->_retrieve_breeding_program();
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

sub _store_seedlot_location {
    my $self = shift;
    my $nd_geolocation = $self->schema()->resultset("NaturalDiversity::NdGeolocation")->find_or_create({
        description => $self->location_code
    });
    $self->nd_geolocation_id($nd_geolocation->nd_geolocation_id);
}

sub _retrieve_location {
    my $self = shift;
    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
    my $nd_geolocation_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id})->search_related('nd_geolocation');
    if ($nd_geolocation_rs->count != 1){
        die "Seedlot does not have 1 nd_geolocation associated!\n";
    }
    my $nd_geolocation_id = $nd_geolocation_rs->first()->nd_geolocation_id();
    my $location_code = $nd_geolocation_rs->first()->description();
    $self->nd_geolocation_id($nd_geolocation_id);
    $self->location_code($location_code);
}

sub _retrieve_breeding_program {
    my $self = shift;
    my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
    my $project_rs = $self->schema()->resultset('Stock::Stock')->search({'me.stock_id'=>$self->seedlot_id})->search_related('nd_experiment_stocks')->search_related('nd_experiment', {'nd_experiment.type_id'=>$experiment_type_id})->search_related('nd_experiment_projects')->search_related('project');
    if ($project_rs->count != 1){
        die "Seedlot does not have 1 breeding program project associated!\n";
    }
    my $breeding_program_id = $project_rs->first()->project_id();
    my $breeding_program_name = $project_rs->first()->name();
    $self->breeding_program_id($breeding_program_id);
    $self->breeding_program_name($breeding_program_name);
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
        #Save seedlot to accession relationship as collection_of
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

        #Create nd_experiment of type seedlot_experiment and link the breeding program and seedlot
        my $experiment_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), "seedlot_experiment", "experiment_type")->cvterm_id();
        my $experiment = $self->schema->resultset('NaturalDiversity::NdExperiment')->create({
            nd_geolocation_id => $self->nd_geolocation_id,
            type_id => $experiment_type_id
        });
        $experiment->create_related('nd_experiment_stocks', { stock_id => $self->seedlot_id(), type_id => $experiment_type_id  });
        $experiment->create_related('nd_experiment_projects', { project_id => $self->breeding_program_id });
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
    $self->name($self->uniquename());

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'seedlot', 'stock_type')->cvterm_id();
    $self->type_id($type_id);

    my $id = $self->SUPER::store();

    print STDERR "Saving seedlot returned ID $id.\n";
    $self->seedlot_id($id);

    $self->_store_seedlot_location();
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
