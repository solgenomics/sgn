
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

has 'owner_sp_person' => (
    isa => 'ArrayRef',
    is => 'rw',
    lazy    => 1,
    builder => '_build_owner_sp_person',
);

has 'main_production_site_url' => (
    isa => 'Str',
    is => 'rw',
);

has 'accessionNumber' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_accessionNumber',
);

has 'germplasmPUI' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_germplasmPUI',
);

has 'pedigree' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'germplasmSeedSource' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_germplasmSeedSource',
);

has 'synonyms' => (
    isa => 'Maybe[ArrayRef[Str]]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_synonyms',
);

has 'instituteCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_instituteCode',
);

has 'instituteName' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_instituteName',
);

has 'biologicalStatusOfAccessionCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_biologicalStatusOfAccessionCode',
);

has 'countryOfOriginCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_countryOfOriginCode',
);

has 'typeOfGermplasmStorageCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_typeOfGermplasmStorageCode',
);

has 'donors' => (
    isa => 'Maybe[ArrayRef[HashRef]]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_donors',
);

has 'acquisitionDate' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_acquisitionDate',
);

has 'entryNumber' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_entryNumber',
);

has 'variety' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_variety',
);

has 'state' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_state',
);

has 'notes' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_notes',
);

has 'locationCode' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_location_code',
);

has 'ploidyLevel' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_ploidy_level',
);

has 'genomeStructure' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_genome_structure',
);

has 'transgenic' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_transgenic',
);

has 'introgression_parent' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_introgression_parent',
);

has 'introgression_backcross_parent' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_introgression_backcross_parent',
);

has 'introgression_map_version' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_introgression_map_version',
);

has 'introgression_chromosome' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_introgression_chromosome',
);

has 'introgression_start_position_bp' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_introgression_start_position_bp',
);

has 'introgression_end_position_bp' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_introgression_end_position_bp',
);

sub BUILD {
    my $self = shift;

}

sub _retrieve_germplasmPUI {
    my $self = shift;
    $self->germplasmPUI($self->_retrieve_stockprop('PUI'));
}

sub _retrieve_accessionNumber {
    my $self = shift;
    $self->accessionNumber($self->_retrieve_stockprop('accession number'));
}

sub _retrieve_germplasmSeedSource {
    my $self = shift;
    $self->germplasmSeedSource($self->_retrieve_stockprop('seed source'));
}

sub _retrieve_synonyms {
    my $self = shift;
    my @synonyms = $self->_retrieve_stockprop('stock_synonym') ? split ',', $self->_retrieve_stockprop('stock_synonym') : ();
    $self->synonyms(\@synonyms);
}

sub _retrieve_instituteCode {
    my $self = shift;
    $self->instituteCode($self->_retrieve_stockprop('institute code'));
}

sub _retrieve_instituteName {
    my $self = shift;
    $self->instituteName($self->_retrieve_stockprop('institute name'));
}

sub _retrieve_entryNumber {
    my $self = shift;
    $self->entryNumber($self->_retrieve_stockprop('entry number'));
}

sub _retrieve_variety {
    my $self = shift;
    $self->variety($self->_retrieve_stockprop('variety'));
}

sub _retrieve_state {
    my $self = shift;
    $self->state($self->_retrieve_stockprop('state'));
}

sub _retrieve_biologicalStatusOfAccessionCode {
    my $self = shift;
    $self->biologicalStatusOfAccessionCode($self->_retrieve_stockprop('biological status of accession code'));
}

sub _retrieve_countryOfOriginCode {
    my $self = shift;
    $self->countryOfOriginCode($self->_retrieve_stockprop('country of origin'));
}

sub _retrieve_typeOfGermplasmStorageCode {
    my $self = shift;
    $self->typeOfGermplasmStorageCode($self->_retrieve_stockprop('type of germplasm storage code'));
}

sub _retrieve_acquisitionDate {
    my $self = shift;
    $self->acquisitionDate($self->_retrieve_stockprop('acquisition date'));
}

sub _retrieve_donors {
    my $self = shift;
    my @donor_accessions = $self->_retrieve_stockprop('donor') ? split ',', $self->_retrieve_stockprop('donor') : ();
    my @donor_institutes = $self->_retrieve_stockprop('donor institute') ? split ',', $self->_retrieve_stockprop('donor institute') : ();
    my @donor_puis = $self->_retrieve_stockprop('donor PUI') ? split ',', $self->_retrieve_stockprop('donor PUI') : ();
    my @donor_array;
    if (scalar(@donor_accessions)>0 && scalar(@donor_institutes)>0 && scalar(@donor_puis)>0 && scalar(@donor_accessions) == scalar(@donor_institutes) && scalar(@donor_accessions) == scalar(@donor_puis)){
        for (0 .. scalar(@donor_accessions)-1){
            push @donor_array, {
                'donorGermplasmName'=>$donor_accessions[$_],
                'donorAccessionNumber'=>$donor_accessions[$_],
                'donorInstituteCode'=>$donor_institutes[$_],
                'germplasmPUI'=>$donor_puis[$_]
            };
        }
    }
    $self->donors(\@donor_array);
}

sub _retrieve_notes {
    my $self = shift;
    $self->notes($self->_retrieve_stockprop('notes'));
}

sub _retrieve_location_code {
    my $self = shift;
    $self->locationCode($self->_retrieve_stockprop('location_code'));
}

sub _retrieve_ploidy_level {
    my $self = shift;
    $self->ploidyLevel($self->_retrieve_stockprop('ploidy_level'));
}

sub _retrieve_genome_structure {
    my $self = shift;
    $self->genomeStructure($self->_retrieve_stockprop('genome_structure'));
}

sub _retrieve_transgenic {
    my $self = shift;
    $self->transgenic($self->_retrieve_stockprop('transgenic'));
}

sub _retrieve_introgression_parent {
    my $self = shift;
    $self->introgression_parent($self->_retrieve_stockprop('introgression_parent'));
}

sub _retrieve_introgression_backcross_parent {
    my $self = shift;
    $self->introgression_backcross_parent($self->_retrieve_stockprop('introgression_backcross_parent'));
}

sub _retrieve_introgression_map_version {
    my $self = shift;
    $self->introgression_map_version($self->_retrieve_stockprop('introgression_map_version'));
}

sub _retrieve_introgression_chromosome {
    my $self = shift;
    $self->introgression_chromosome($self->_retrieve_stockprop('introgression_chromosome'));
}

sub _retrieve_introgression_start_position_bp {
    my $self = shift;
    $self->introgression_start_position_bp($self->_retrieve_stockprop('introgression_start_position_bp'));
}

sub _retrieve_introgression_end_position_bp {
    my $self = shift;
    $self->introgression_end_position_bp($self->_retrieve_stockprop('introgression_end_position_bp'));
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
    if($self->pedigree){
        print STDERR "CXGN::Stock::Accession->store does not store pedigree info yet!\n";
    }
    if ($self->variety){
        $self->_store_stockprop('variety', $self->variety);
    }
    if ($self->state){
        $self->_store_stockprop('state', $self->state);
    }
    if ($self->notes){
        $self->_store_stockprop('notes', $self->notes);
    }
    if ($self->locationCode){
        $self->_store_stockprop('location_code', $self->locationCode);
    }
    if ($self->ploidyLevel){
        $self->_store_stockprop('ploidy_level', $self->ploidyLevel);
    }
    if ($self->genomeStructure){
        $self->_store_stockprop('genome_structure', $self->genomeStructure);
    }
    if ($self->transgenic){
        $self->_store_stockprop('transgenic', $self->transgenic);
    }
    if ($self->introgression_parent){
        $self->_store_stockprop('introgression_parent', $self->introgression_parent);
    }
    if ($self->introgression_backcross_parent){
        $self->_store_stockprop('introgression_backcross_parent', $self->introgression_backcross_parent);
    }
    if ($self->introgression_map_version){
        $self->_store_stockprop('introgression_map_version', $self->introgression_map_version);
    }
    if ($self->introgression_chromosome){
        $self->_store_stockprop('introgression_chromosome', $self->introgression_chromosome);
    }
    if ($self->introgression_start_position_bp){
        $self->_store_stockprop('introgression_start_position_bp', $self->introgression_start_position_bp);
    }
    if ($self->introgression_end_position_bp){
        $self->_store_stockprop('introgression_end_position_bp', $self->introgression_end_position_bp);
    }

    print STDERR "Saving returned ID $id.\n";
    $self->stock_id($id);

    return $self->stock_id();
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;

