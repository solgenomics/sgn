
=head1 NAME

CXGN::Stock::Vector - a class to represent vectors in the database

=head1 DESCRIPTION


CXGN::Stock::Vectors inherits from CXGN::Stock. The required fields are:

uniquename

Code structure copied from CXGN::Stock::Accession, with inheritance from CXGN::Stock

=head1 AUTHOR


=head1 ACCESSORS & METHODS 

=cut

package CXGN::Stock::Vector;

use Moose;

extends 'CXGN::Stock';

use Data::Dumper;
use CXGN::BreedersToolbox::Projects;
use SGN::Model::Cvterm;


has 'owner_sp_person' => (
    isa => 'ArrayRef',
    is => 'rw',
    lazy    => 1,
    builder => '_build_owner_sp_person',
);

has 'Strain' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_Strain',
);

has 'Backbone' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_Backbone',
);

has 'CloningOrganism' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_CloningOrganism',
);

has 'InherentMarker' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_InherentMarker',
);

has 'SelectionMarker' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_SelectionMarker',
);

has 'CassetteName' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_CassetteName',
);

has 'VectorType' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_VectorType',
);

has 'Gene' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_Gene',
);

has 'Promotors' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_Promotors',
);

has 'Terminators' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_Terminators',
);

has 'BacterialResistantMarker' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_BacterialResistantMarker',
);

has 'PlantAntibioticResistantMarker' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_PlantAntibioticResistantMarker',
);

has 'other_editable_stock_props' => (
    isa => 'Maybe[HashRef]',
    is => 'rw'
);

sub BUILD {
    my $self = shift;

}



sub _retrieve_Strain {
    my $self = shift;
    $self->Strain($self->_retrieve_stockprop('Strain'));
}
sub _retrieve_Backbone {
    my $self = shift;
    $self->Backbone($self->_retrieve_stockprop('Backbone'));
}
sub _retrieve_CloningOrganism {
    my $self = shift;
    $self->CloningOrganism($self->_retrieve_stockprop('CloningOrganism'));
}

sub _retrieve_InherentMarker {
    my $self = shift;
    $self->InherentMarker($self->_retrieve_stockprop('InherentMarker'));
}
sub _retrieve_SelectionMarker {
    my $self = shift;
    $self->SelectionMarker($self->_retrieve_stockprop('SelectionMarker'));
}
sub _retrieve_CassetteName {
    my $self = shift;
    $self->CassetteName($self->_retrieve_stockprop('CassetteName'));
}

sub _retrieve_VectorType {
    my $self = shift;
    $self->VectorType($self->_retrieve_stockprop('VectorType'));
}
sub _retrieve_Gene {
    my $self = shift;
    $self->Gene($self->_retrieve_stockprop('Gene'));
}
sub _retrieve_Promotors {
    my $self = shift;
    $self->Promotors($self->_retrieve_stockprop('Promotors'));
}

sub _retrieve_Terminators {
    my $self = shift;
    $self->Terminators($self->_retrieve_stockprop('Terminators'));
}

sub _retrieve_PlantAntibioticResistantMarker {
    my $self = shift;
    $self->PlantAntibioticResistantMarker($self->_retrieve_stockprop('PlantAntibioticResistantMarker'));
}

sub _retrieve_BacterialResistantMarker {
    my $self = shift;
    $self->BacterialResistantMarker($self->_retrieve_stockprop('BacterialResistantMarker'));
}

=head2 store()

 Usage:        my $stock_id = $vector->store();
 Desc:         stores the current state of the object to the db
 Ret:          the created stock id.
 Args:         none
 Side Effects:
 Example:

=cut

sub store {
    my $self = shift;

    print STDERR "storing: UNIQUENAME=".$self->uniquename()."\n";

    my $id = $self->SUPER::store();

    if ($self->Strain){
        $self->_store_stockprop('Strain', $self->Strain);
    }

    if ($self->Backbone){
        $self->_store_stockprop('Backbone', $self->Backbone);
    }

    if ($self->CloningOrganism){
        $self->_store_stockprop('CloningOrganism', $self->CloningOrganism);
    }
    if ($self->InherentMarker){
        $self->_store_stockprop('InherentMarker', $self->InherentMarker);
    }
    if ($self->SelectionMarker){
        $self->_store_stockprop('SelectionMarker', $self->SelectionMarker);
    }

    if ($self->CassetteName){
        $self->_store_stockprop('CassetteName', $self->CassetteName);
    }
    if ($self->VectorType){
        $self->_store_stockprop('VectorType', $self->VectorType);
    }
    if ($self->Gene){
        $self->_store_stockprop('Gene', $self->Gene);
    }

    if ($self->Promotors){
        $self->_store_stockprop('Promotors', $self->Promotors);
    }
    if ($self->Terminators){
        $self->_store_stockprop('Terminators', $self->Terminators);
    }

    if ($self->BacterialResistantMarker){
        $self->_store_stockprop('BacterialResistantMarker', $self->BacterialResistantMarker);
    }
    if ($self->PlantAntibioticResistantMarker){
        $self->_store_stockprop('PlantAntibioticResistantMarker', $self->PlantAntibioticResistantMarker);
    }

    if ($self->other_editable_stock_props){
        while (my ($key, $value) = each %{$self->other_editable_stock_props}) {

            # For other_editable_stock_props that can come from accession file upload and are defined in the editable_stock_props configuration
            my $q = "SELECT t.cvterm_id FROM cvterm as t JOIN cv ON(t.cv_id=cv.cv_id) WHERE t.name=? and cv.name=?;";
            my $h = $self->schema->storage->dbh()->prepare($q);
            $h->execute($key, 'stock_property');
            my ($cvterm_id) = $h->fetchrow_array();
            if (!$cvterm_id) {
                my $new_term = $self->schema->resultset("Cv::Cvterm")->create_with({
                   name => $key,
                   cv => 'stock_property'
                });
                $cvterm_id = $new_term->cvterm_id();
            }

            $self->_store_stockprop($key, $value);
        }
    }

    print STDERR "Saving with ID $id.\n";
    $self->stock_id($id);

    return $self->stock_id();
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;

