
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

has 'main_production_site_url' => (
    isa => 'Str',
    is => 'rw',
);

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
    isa => 'Maybe[ArrayRef[Str]]',
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

has 'donors' => (
    isa => 'Maybe[ArrayRef[HashRef]]',
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

    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'accession', 'stock_type')->cvterm_id();
    $self->type_id($type_id);

    my $id = $self->SUPER::store();

    if ($self->accessionNumber){
        $self->_store_stockprop('accession number', $self->accessionNumber);
    }
    if ($self->germplasmPUI){
        $self->_store_stockprop('PUI', $self->germplasmPUI);
    } else {
        my $germplasm_pui = $self->main_production_site_url."/stock/".$id."/view";
        $self->_store_stockprop('PUI', $germplasm_pui);
        $self->germplasmPUI($germplasm_pui);
    }
    if ($self->germplasmSeedSource){
        $self->_store_stockprop('seed source', $self->germplasmSeedSource);
    }
    if ($self->synonyms){
        foreach (@{$self->synonyms}){
            $self->_store_stockprop('stock_synonym', $_);
        }
    }
    if ($self->instituteCode){
        $self->_store_stockprop('institute code', $self->instituteCode);
    }
    if ($self->instituteName){
        $self->_store_stockprop('institute name', $self->instituteName);
    }
    if ($self->biologicalStatusOfAccessionCode){
        $self->_store_stockprop('biological status of accession code', $self->biologicalStatusOfAccessionCode);
    }
    if ($self->countryOfOriginCode){
        $self->_store_stockprop('country of origin', $self->countryOfOriginCode);
    }
    if ($self->typeOfGermplasmStorageCode){
        $self->_store_stockprop('type of germplasm storage code', $self->typeOfGermplasmStorageCode);
    }
    if ($self->acquisitionDate){
        $self->_store_stockprop('acquisition date', $self->acquisitionDate);
    }
    if ($self->donors){
        foreach (@{$self->donors}){
            $self->_store_stockprop('donor', $_->{donorGermplasmName});
            $self->_store_stockprop('donor institute', $_->{donorInstituteCode});
            $self->_store_stockprop('donor PUI', $_->{germplasmPUI});
        }
    }

    print STDERR "Saving returned ID $id.\n";
    $self->stock_id($id);

    return $self->stock_id();
}

1;

no Moose;
__PACKAGE__->meta->make_immutable;
