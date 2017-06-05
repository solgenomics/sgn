
=head1 NAME

CXGN::Stock::Accession - a class to represent accessions in the database

=head1 DESCRIPTION


CXGN::Stock::Accession inherits from CXGN::Stock. The required fields are:

uniquename

Code structure copied from CXGN::Stock::Seedlot, with inheritance from CXGN::Stock

=head1 AUTHOR


=head1 ACCESSORS & METHODS 

=cut

package CXGN::Stock::Accession;

use Moose;

extends 'CXGN::Stock';

use Data::Dumper;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;


has 'accessionNumber' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'germplasmPUI' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'pedigree' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'germplasmSeedSource' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'synonyms' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'commonCropName' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'instituteCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'instituteName' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'biologicalStatusOfAccessionCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'countryOfOriginCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'typeOfGermplasmStorageCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'speciesAuthority' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'subtaxa' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'subtaxaAuthority' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'donors' => (
    isa => 'Maybe[ArrayRef]',
    is => 'rw',
);

has 'acquisitionDate' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);


sub BUILD {
    my $self = shift;

    if ($self->stock_id()) {
    }
}


sub _store_accession_relationships {
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


=head2 store()

 Usage:        my $stock_id = $accession->store();
 Desc:         stores the current state of the object to the db
 Ret:          the created stock id.
 Args:         none
 Side Effects:
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
