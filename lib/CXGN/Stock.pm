=head1 NAME

CXGN::Stock - a second-level object for Stock

Version: 2.0

=head1 DESCRIPTION

This object was re-factored from CXGN::Chado::Stock and moosified.

CXGN::Stock should be used for all appropriate stock related queries.

The stock table stores different types of objects, such as accessions,
plots, populations, tissue_samples, etc.

CXGN::Stock is the parent object for different flavors of objects
representing these derived types, such as CXGN::Stock::Seedlot, or
CXGN::Stock::TissueSample. (Currently there is no CXGN::Stock::Plot, but
that should probably be added in the future, along with a factory
object that instantiates the correct object given the stock_id).

=head1 AUTHORS

 Naama Menda <nm249@cornell.edu>
 Lukas Mueller <lam87@cornell.edu>

=cut

package CXGN::Stock;

use Moose;

use Carp;
use Data::Dumper;
use JSON::Any;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use SGN::Model::Cvterm;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use base qw / CXGN::DB::Object / ;
use CXGN::Stock::StockLookup;
use Try::Tiny;
use CXGN::Metadata::Metadbdata;
use File::Basename qw | basename dirname|;

=head2 accessor schema()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects: provides access to Bio::Chado::Schema
 Example:

=cut

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

=head2 accessor phenome_schema()

 Usage:
 Desc:         provides access the the CXGN::People::Schema, needed for
               certain user related functions
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
);

=head2 accessor metadata_schema()

 Usage:
 Desc:         provides access the the CXGN::Metadata::Schema, needed for
               certain user related functions
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
);

=head2 accessor check_name_exists()

 Usage:
 Desc:
 Ret:          1 if exists, 0 if not
 Args:
 Side Effects:
 Example:

=cut

has 'check_name_exists' => (
    isa => 'Bool',
    is => 'rw',
    default => 1
);

=head2 accessor stock()

 Usage:
 Desc:         DBIx::Class object for this stock row
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'stock' => (
    isa => 'Bio::Chado::Schema::Result::Stock::Stock',
    is => 'rw',
);

=head2 accessor stock_id()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'stock_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);

=head2 accessor is_saving()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'is_saving' => (
    isa => 'Bool',
    is => 'rw',
    default => 0
);


=head2 accessor owners()

 Usage:
 Desc:
 Ret:          the stock_owners as [sp_person_id, sp_person_id2, ..]
 Args:
 Side Effects:
 Example:

=cut

has 'owners' => (
    isa => 'Maybe[ArrayRef[Int]]',
    is => 'rw',
    lazy     => 1,
    builder  => '_retrieve_stock_owner',
);

=head2 accessor organism()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'organism' => (
    isa => 'Bio::Chado::Schema::Result::Organism::Organism',
    is => 'rw',
);

=head2 accessor organism_id()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'organism_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);

=head2 accessor species()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'species' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

=head2 accessor genus()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'genus' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

=head2 accessor organism_common_name()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'organism_common_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

=head2 accessor organism_abbreviation()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'organism_abbreviation' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

=head2 accessor organism_comment()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'organism_comment' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

=head2 accessor type()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'type' => (
    isa => 'Str',
    is => 'rw'
);

=head2 accessor type_id()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'type_id' => (
    isa => 'Int',
    is => 'rw',
);

=head2 accessor name()

 Usage:        this should be set to the same value as uniquename,
               which is used as the canonical name in the database.
               (synonyms are stored as stockprops, see synonyms()).
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'name' => (
    isa => 'Str',
    is => 'rw',
);

=head2 accessor uniquename()

 Usage:
 Desc:         the canonical name of the accession.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'uniquename' => (
    isa => 'Str',
    is => 'rw',
);

=head2 accessor description()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'description' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    default => '',
);

=head2 accessor is_obsolete()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'is_obsolete' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

=head2 accessor organization_name()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'organization_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

=head2 accessor population_name()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'population_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

=head2 accessor populations()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'populations' => (
    isa => 'Maybe[ArrayRef[ArrayRef]]',
    is => 'rw'
);

=head2 accessor sp_person_id()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'sp_person_id' => (
    isa => 'Int',
    is => 'rw',
);

=head2 accessor user_name()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'user_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

=head2 accessor modification_note()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'modification_note' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'create_date' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    );


has 'objects' => (
    isa => 'Maybe[Ref]',
    is => 'rw',
);

has 'subjects' => (
    isa => 'Maybe[Ref]',
    is => 'rw',
);

=head2 accessor obsolete_note()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

has 'obsolete_note' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

sub BUILD {
    my $self = shift;

    #print STDERR "RUNNING BUILD FOR STOCK.PM...\n";
    my $stock;
    if ($self->stock_id){
        $stock = $self->schema()->resultset("Stock::Stock")->find({ stock_id => $self->stock_id() });
        $self->stock($stock);
        $self->stock_id($stock->stock_id);
	$self->create_date($stock->create_date);
    }
    elsif ($self->uniquename) {
	$stock = $self->schema()->resultset("Stock::Stock")->find( { uniquename => $self->uniquename() });
	if (!$stock) {
	    print STDERR "Can't find stock ".$self->uniquename.". Generating empty object.\n";
	}
	else {
	    $self->stock($stock);
	    $self->create_date($stock->create_date());
	    $self->stock_id($stock->stock_id);
	}
    }


    if (defined $stock && !$self->is_saving) {
        $self->organism_id($stock->organism_id);
#	my $organism = $self->schema()->resultset("Organism::Organism")->find( { organism_id => $stock->organism_id() });
#	$self->organism($organism);
        $self->name($stock->name);
        $self->uniquename($stock->uniquename);
        $self->description($stock->description() || '');
        $self->type_id($stock->type_id);
        $self->type($self->schema()->resultset("Cv::Cvterm")->find({ cvterm_id=>$self->type_id() })->name());
        $self->is_obsolete($stock->is_obsolete);
        $self->organization_name($self->_retrieve_stockprop('organization'));
        $self->_retrieve_populations();
    }


    if ($self->stock_id()) {

	my @objects;
	my $object_rs = $self->schema()->resultset("Stock::Stock")->find( { stock_id => $self->stock_id() })->stock_relationship_objects();
	foreach my $object ($object_rs->all()) {
	    push @objects, [ $object->object->stock_id, $object->object->uniquename(), $object->type->name() ];
	}
	$self->objects(\@objects);

	my @subjects;
	my $subject_rs = $self->schema()->resultset("Stock::Stock")->find( { stock_id => $self->stock_id() })->stock_relationship_subjects();
	foreach my $subject ($subject_rs->all()) {
	    push @subjects, [ $subject->subject->stock_id, $subject->subject->uniquename(), $subject->type->name() ];
	}

	$self->subjects(\@subjects);
    }


    return $self;
}


sub _retrieve_stock_owner {
    my $self = shift;
    my $owner_rs = $self->phenome_schema->resultset("StockOwner")->search({
        stock_id => $self->stock_id,
    });
    my @owners;
    while (my $r = $owner_rs->next){
        push @owners, $r->sp_person_id;
    }
    $self->owners(\@owners);
}


=head2 store()

 Usage: $self->store
 Desc:  store a new stock or update an existing stock
 Ret:   a database id
 Args:  none
 Side Effects: checks for stock uniqueness using the organism_id and case-insensitive uniquename
checks if the stock exists in the database (if a stock_id is provided), and if does, will attempt to update
 Example:

=cut

sub store {
    my $self = shift;
    my %return;

    my $stock = $self->stock;
    my $schema = $self->schema();

    #no stock id . Check first if the name  exists in te database
    my $exists;
    if ($self->check_name_exists){
        $exists= $self->exists_in_database();
    }

    # If provided set type_id based on supplied type, otherwise get existing type_id from db
    if ($self->type()) {
        my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), $self->type(), 'stock_type')->cvterm_id();
        $self->type_id($type_id);
    } else {
        $self->type_id($stock->type_id);
    }

    if (!$self->organism_id){
        if ($self->species){

            my $organism_rs = $self->schema->resultset("Organism::Organism")->search({ species=>$self->species });
            if ($organism_rs->count > 1){
                return $return{error} = "More than one organism returned for species: ".$self->species;
            }
            if ($organism_rs->count == 0){
                return $return{error} = "NO ORGANISM FOUND OF SPECIES: ".$self->species;
            }
            if ($organism_rs->count == 1){
                my $organism = $organism_rs->first();
                $self->organism($organism);
                $self->organism_id($organism->organism_id);
                $self->organism_abbreviation($organism->abbreviation);
                $self->genus($organism->genus);
                $self->species($organism->species);
                $self->organism_common_name($organism->common_name);
                $self->organism_comment($organism->comment);
            }
        }
    }

    # ###Check first if the name  exists in te database
    # $exists = 0;
    # if ($self->check_name_exists){
    # 	print STDERR "Checking stock uniquename \n";
    #     $exists= $self->exists_in_database();
    # }
    # print STDERR "Stock exists check: $exists\n";
    ####
    if (!$stock) { #Trying to create a new stock
        print STDERR "Storing Stock ".localtime."\n";
        if (!$exists) {

            my $new_row = $self->schema()->resultset("Stock::Stock")->create({
                name => $self->name(),
                uniquename => $self->uniquename(),
                description => $self->description(),
                type_id => $self->type_id(),
                organism_id => $self->organism_id(),
                is_obsolete => $self->is_obsolete(),
            });
            $new_row->insert();

            my $id = $new_row->stock_id();
            $self->stock_id($id);
            $self->stock($new_row);

            if ($self->organization_name){
                $self->_store_stockprop('organization', $self->organization_name());
            }
            if ($self->population_name){
                print STDERR "**STOCK.PM This stock has population name " . $self->population_name . "\n\n";
                #DO NOT INSERT POPULATION RELATIONSHIP FROM THE STOCK STORE FUNCTION
                $self->_store_population_relationship();
            }

        }
        else {
            die "The entry ".$self->uniquename()." already exists in the database. Error: $exists\n";
        }
    }
    else {
        print STDERR "Updating Stock ".localtime."\n";
        if (!$self->name && $self->uniquename){
            $self->name($self->uniquename);
        }
        my $row = $self->schema()->resultset("Stock::Stock")->find({ stock_id => $self->stock_id() });
        if ($self->name){ $row->name($self->name()) };
        if ($self->uniquename){ $row->uniquename($self->uniquename()) };
        if ($self->description){ $row->description($self->description()) };
        if ($self->type_id){ $row->type_id($self->type_id()) };
        if ($self->organism_id){ $row->organism_id($self->organism_id()) };
        if (defined($self->is_obsolete)){ $row->is_obsolete($self->is_obsolete()) };
        $row->update();
        if ($self->organization_name){
            $self->_update_stockprop('organization', $self->organization_name());
        }
        if ($self->population_name){
            print STDERR "**STOCK.PM This stock has population name " . $self->population_name . "\n\n";
            #DO NOT INSERT POPULATION RELATIONSHIP FROM THE STOCK STORE FUNCTION
            $self->_update_population_relationship();
        }
    }
    $self->associate_owner($self->sp_person_id, $self->sp_person_id, $self->user_name, $self->modification_note, $self->obsolete_note);

    return $self->stock_id();
}

########################

=head2 Class functions

=head2 exists_in_database()

 Usage: $self->exists_in_database()
 Desc:  check if the uniquename exists in the stock table
 Ret: Error message if the stock name exists in the database
 Args:
 Side Effects:
 Example:

=cut

sub exists_in_database {
    my $self = shift;
    my $schema = $self->schema;
    my $stock = $self->stock;
    my $stock_id = $self->stock_id;
    my $uniquename = $self->uniquename || '' ;
    print STDERR "Stock lookup for name $uniquename\n\n";
    my $stock_lookup = CXGN::Stock::StockLookup->new({
        schema => $schema,
        stock_name => $uniquename,
    });
    my $s = $stock_lookup->get_stock_exact($self->type_id, $self->organism_id );

    # loading new stock - $stock_id is undef
    #
    if (defined($s) && !$stock ) {
        return "Uniquename already exists in database with stock_id: ".$s->stock_id;
    }

    # updating an existing stock
    #
    elsif ($stock && defined($s) ) {
	if ( ($s->stock_id == $stock_id) ) {
	    return 0;
	    #trying to update the uniquename
	}
	elsif ( $s->stock_id != $stock_id ) {
	    return " Can't update an existing stock $stock_id uniquename:$uniquename.";
	    # if the new name we're trying to update/insert does not exist
	    # in the stock table..
	    #
	}
	elsif ($stock && !$s->stock_id) {
	    return 0;
	}
    }
    return;
}




=head2 get_organism()

 Usage: $self->get_organism
 Desc:  find the organism object of this stock
 Ret:   L<Bio::Chado::Schema::Organism::Organism> object
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_organism {
    my $self = shift;
    my $bcs_stock = $self->schema()->resultset("Stock::Stock")->find( { stock_id => $self->stock_id() });
    if ($bcs_stock) {
        return $bcs_stock->organism;
    }
    return;
}


=head2 get_species()

 Usage: $self->get_species
 Desc:  find the species name of this stock , if one exists
 Ret:   string
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_species {
    my $self = shift;
    my $organism = $self->get_organism;
    if ($organism) {
        return $organism->species;
    }
    else {
	return;
    }
}

=head2 get_genus()

 Usage: $self->get_genus
 Desc:  find the genus name of this stock , if one exists
 Ret:   string
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_genus {
    my $self = shift;
    my $organism = $self->get_organism;
    if ($organism) {
        return $organism->genus;
    }
    else {
	return;
    }
}

=head2 get_species_authority()

 Usage: $self->get_species_authority
 Desc:  find the species_authority of this stock , if one exists
 Ret:   string
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_species_authority {
    my $self = shift;
    return $self->_retrieve_organismprop('species authority');
}

=head2 get_subtaxa()

 Usage: $self->get_subtaxa
 Desc:  find the subtaxa of this stock , if one exists
 Ret:   string
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_subtaxa {
    my $self = shift;
    return $self->_retrieve_organismprop('subtaxa');
}

=head2 get_subtaxa_authority()

 Usage: $self->get_subtaxa_authority
 Desc:  find the subtaxa_authority of this stock , if one exists
 Ret:   string
 Args:  none
 Side Effects: none
 Example:

=cut

sub get_subtaxa_authority {
    my $self = shift;
    return $self->_retrieve_organismprop('subtaxa authority');
}

=head2 set_species()

Usage: $self->set_species
 Desc:  set organism_id for the stock using organism.species name
 Ret:   nothing
 Args:  species name (case insensitive)
 Side Effects: sets the organism_id for the stock
 Example:

=cut

sub set_species {
    my $self = shift;
    my $species_name = shift; # this has to be EXACTLY as stored in the organism table
    my $organism = $self->get_schema->resultset('Organism::Organism')->search(
        { 'lower(species)' => { like =>  lc($species_name) } } )->single ; #should be 1 result
    if ($organism) {
        $self->organism_id($organism->organism_id);
    }
    else {
        warn "NO organism found for species name $species_name!!\n";
    }
}

=head2 function get_image_ids()

  Synopsis:     my @images = $self->get_image_ids()
  Arguments:    none
  Returns:      a list of image ids
  Side effects:	none
  Description:	a method for fetching all images associated with a stock

=cut

sub get_image_ids {
    my $self = shift;
    my @ids;
    my $q = "select distinct image_id, cvterm.name, stock_image.display_order FROM phenome.stock_image JOIN stock USING(stock_id) JOIN cvterm ON(type_id=cvterm_id) WHERE stock_id = ? ORDER BY stock_image.display_order ASC";
    my $h = $self->schema->storage->dbh()->prepare($q);
    $h->execute($self->stock_id);
    while (my ($image_id, $stock_type, $display_order) = $h->fetchrow_array()){
        push @ids, [$image_id, $stock_type];
    }
    return @ids;
}


=head2 get_genotypes

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_genotypeprop_ids {
    my $self = shift;

    my $q = "SELECT genotypeprop_id FROM stock JOIN nd_experiment_stock using(stock_id) JOIN nd_experiment_genotype USING(nd_experiment_id) JOIN genotypeprop USING(genotype_id) WHERE stock.stock_id=?";
    my $h = $self->schema->storage->dbh()->prepare($q);
    $h->execute($self->stock_id());
    my @genotypeprop_ids;
    while (my ($genotypeprop_id) = $h->fetchrow_array()) {
	push @genotypeprop_ids, $genotypeprop_id;
    }

    return \@genotypeprop_ids;

}

=head2 associate_allele

 Usage: $self->associate_allele($allele_id, $sp_person_id)
 Desc:  store a stock-allele link in phenome.stock_allele
 Ret:   a database id
 Args:  allele_id, sp_person_id
 Side Effects:  store a metadata row
 Example:

=cut

sub associate_allele {
    my $self = shift;
    my $allele_id = shift;
    my $sp_person_id = shift;
    if (!$allele_id || !$sp_person_id) {
        warn "Need both allele_id and person_id for linking the stock with an allele!";
        return
    }
    my $metadata_id = $self->_new_metadata_id($sp_person_id);
    #check if the allele is already linked
    my $ids =  $self->schema()->storage()->dbh()->selectcol_arrayref
        ( "SELECT stock_allele_id FROM phenome.stock_allele WHERE stock_id = ? AND allele_id = ?",
          undef,
          $self->stock_id,
          $allele_id
        );
    if ($ids) { warn "Allele $allele_id is already linked with stock " . $self->stock_id ; }
#store the allele_id - stock_id link
    my $q = "INSERT INTO phenome.stock_allele (stock_id, allele_id, metadata_id) VALUES (?,?,?) RETURNING stock_allele_id";
    my $sth  = $self->schema()->storage()->dbh()->prepare($q);
    $sth->execute($self->stock_id, $allele_id, $metadata_id);
    my ($id) =  $sth->fetchrow_array;
    return $id;
}

=head2 associate_owner()

 Usage: $self->associate_owner($owner_sp_person_id, $sp_person_id)
 Desc:  store a stock-owner link in phenome.stock_owner
 Ret:   a database id
 Args:  owner_id, sp_person_id
 Side Effects:  store a metadata row
 Example:

=cut

sub associate_owner {
    my $self = shift;
    my $owner_id = shift;
    my $sp_person_id = shift;
    my $user_name = shift;
    my $modification_note = shift;
    my $obsolete_note = shift;
    if (!$owner_id || !$sp_person_id) {
        warn "Need both owner_id and person_id for linking the stock with an owner!";
        return;
    }
    my $metadata_id = $self->_new_metadata_id($sp_person_id, $user_name, $modification_note, $obsolete_note);
    #check if the owner is already linked
    my $ids =  $self->schema()->storage()->dbh()->selectcol_arrayref
        ( "SELECT stock_owner_id FROM phenome.stock_owner WHERE stock_id = ? AND sp_person_id = ?",
          undef,
          $self->stock_id,
          $owner_id
        );
    if ($ids) { warn "Owner $owner_id is already linked with stock " . $self->stock_id ; }
#store the owner_id - stock_id link
    my $q = "INSERT INTO phenome.stock_owner (stock_id, sp_person_id, metadata_id) VALUES (?,?,?) RETURNING stock_owner_id";
    my $sth  = $self->schema()->storage()->dbh()->prepare($q);
    $sth->execute($self->stock_id, $owner_id, $metadata_id);
    my ($id) =  $sth->fetchrow_array;
    return $id;
}

=head2 associate_owner()

 Usage: $self->associate_uploaded_file($owner_sp_person_id, $archived_filename_with_path, $md5checksum, $stock_id )
 Desc:  Associate files with metadata and stock
 Ret:   a database id
 Args:  owner_id, archived_filename_with_path, md5checksum, stock_id
 Side Effects:  store a metadata row
 Example:

=cut

sub associate_uploaded_file {

    my $self = shift;
    my $user_id = shift;
    my $archived_filename_with_path = shift;
    my $md5checksum = shift;
    my $stock_id = shift;

    my $metadata_id = $self->_new_metadata_id($user_id);

    my $metadata_schema = CXGN::Metadata::Schema->connect(
        sub { $self->schema()->storage()->dbh() },
        { on_connect_do => [ 'SET search_path TO metadata'], limit_dialect => 'LimitOffset' }
        );

    my $file_row = $metadata_schema->resultset("MdFiles")
        ->create({
            basename => basename($archived_filename_with_path),
            dirname  => dirname($archived_filename_with_path),
            filetype => 'accession_additional_file_upload',
            md5checksum => $md5checksum,
            metadata_id => $metadata_id,
        });
    my $file_id = $file_row->file_id();

    my $phenome_schema = CXGN::Phenome::Schema->connect(
	sub { $self->schema()->storage()->dbh() }, { on_connect_do => [ 'SET search_path TO phenome, public, sgn'], limit_dialect => 'LimitOffset' }
	);

    my $stock_file = $phenome_schema->resultset("StockFile")
        ->create({
            stock_id => $stock_id,
            file_id => $file_id,
        });

    return {success => 1, file_id=>$file_id};
}

=head2 obsolete_uploaded_file()

 Usage: $self->obsolete_uploaded_file($file_id, $user_id, $role )
 Desc:  Obsolete files with metadata
 Side Effects:
 Example:

=cut

sub obsolete_uploaded_file {

    my $self = shift;
    my $file_id = shift;
    my $user_id = shift;
    my $role = shift;

    my @errors;
    # check ownership of that file
    my $q = "SELECT metadata.md_metadata.create_person_id, metadata.md_metadata.metadata_id, metadata.md_files.file_id
    FROM metadata.md_metadata
    join metadata.md_files using(metadata_id)
    where md_metadata.obsolete=0 and md_files.file_id=? and md_metadata.create_person_id=?";

    my $dbh = $self->bcs_schema->storage()->dbh();
    my $h = $dbh->prepare($q);

    $h->execute($file_id, $user_id);

    if (my ($create_person_id, $metadata_id, $file_id) = $h->fetchrow_array()) {
	if ($create_person_id == $user_id || $role eq "curator") {
	    my $uq = "UPDATE metadata.md_metadata SET obsolete=1 where metadata_id = ?";
	    my $uh = $dbh->prepare($uq);
	    $uh->execute($metadata_id);
	}
	else {
	    push @errors, "Only the owner of the uploaded file, or a curator, can delete this file.";
	}

    }
    else {
	push @errors, "No such file currently exists.";
    }

    if (@errors >0) {
	return { errors => \@errors };
    }

    return { success => 1 };
}

=head2 get_trait_list()

 Usage:
 Desc:         gets the list of traits that have been measured
               on this stock
 Ret:          a list of lists  ( [ cvterm_id, cvterm_name] , ...)
 Args:
 Side Effects:
 Example:

=cut

sub get_trait_list {
    my $self = shift;

    my $q = "select distinct(cvterm.cvterm_id), db.name || ':' || dbxref.accession, cvterm.name, avg(phenotype.value::Real), stddev(phenotype.value::Real) from stock as accession join stock_relationship on (accession.stock_id=stock_relationship.object_id) JOIN stock as plot on (plot.stock_id=stock_relationship.subject_id) JOIN nd_experiment_stock ON (plot.stock_id=nd_experiment_stock.stock_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN cvterm ON (phenotype.cvalue_id = cvterm.cvterm_id) JOIN dbxref ON(cvterm.dbxref_id = dbxref.dbxref_id) JOIN db USING(db_id) where accession.stock_id=? and phenotype.value~? group by cvterm.cvterm_id, db.name || ':' || dbxref.accession, cvterm.name";
    my $h = $self->schema()->storage()->dbh()->prepare($q);
    my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';
    $h->execute($self->stock_id(), $numeric_regex);
    my @traits;
    while (my ($cvterm_id, $cvterm_accession, $cvterm_name, $avg, $stddev) = $h->fetchrow_array()) {
	push @traits, [ $cvterm_id, $cvterm_accession, $cvterm_name, $avg, $stddev ];
    }

    # get directly associated traits
    #
    $q = "select distinct(cvterm.cvterm_id), db.name || ':' || dbxref.accession, cvterm.name, avg(phenotype.value::Real), stddev(phenotype.value::Real) from stock JOIN nd_experiment_stock ON (stock.stock_id=nd_experiment_stock.stock_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN cvterm ON (phenotype.cvalue_id = cvterm.cvterm_id) JOIN dbxref ON(cvterm.dbxref_id = dbxref.dbxref_id) JOIN db USING(db_id) where stock.stock_id=? and phenotype.value~? group by cvterm.cvterm_id, db.name || ':' || dbxref.accession, cvterm.name";

    $h = $self->schema()->storage()->dbh()->prepare($q);
    $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';
    $h->execute($self->stock_id(), $numeric_regex);

    while (my ($cvterm_id, $cvterm_accession, $cvterm_name, $avg, $stddev) = $h->fetchrow_array()) {
	push @traits, [ $cvterm_id, $cvterm_accession, $cvterm_name, $avg, $stddev ];
    }

    return @traits;
}

=head2 get_trials()

 Usage:
 Desc:          gets the list of trails this stock was used in
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_trials {
    my $self = shift;
    my $dbh = $self->schema()->storage()->dbh();

    my $geolocation_q = "SELECT nd_geolocation_id, description FROM nd_geolocation;";
    my $geolocation_h = $dbh->prepare($geolocation_q);
    $geolocation_h->execute();
    my %geolocations;

    while (my ($nd_geolocation_id, $description) = $geolocation_h->fetchrow_array()) {
        $geolocations{$nd_geolocation_id} = $description;
    }

    my $geolocation_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'project location', 'project_property')->cvterm_id();
    my $q = "select distinct(project.project_id), project.name, projectprop.value from stock as accession join stock_relationship on
	(accession.stock_id=stock_relationship.object_id) JOIN stock as plot on (plot.stock_id=stock_relationship.subject_id)
	JOIN nd_experiment_stock ON (plot.stock_id=nd_experiment_stock.stock_id) JOIN nd_experiment_project USING(nd_experiment_id)
	JOIN project USING (project_id) LEFT JOIN projectprop ON (project.project_id=projectprop.project_id)
	where projectprop.type_id=$geolocation_type_id AND accession.stock_id=?;";

    my $h = $dbh->prepare($q);
    $h->execute($self->stock_id());

    my @trials;
    while (my ($project_id, $project_name, $nd_geolocation_id) = $h->fetchrow_array()) {
        push @trials, [ $project_id, $project_name, $nd_geolocation_id, $geolocations{$nd_geolocation_id} ];
    }
    return @trials;
}

=head2 get_ancestor_hash()

 Usage:
 Desc:          gets a multi-dimensional hash of this stock's ancestors
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_ancestor_hash {
  my ($self, $stock_id, $direct_descendant_ids) = @_;

  if (!$stock_id) { $stock_id = $self->stock_id(); }
  push @$direct_descendant_ids, $stock_id; #excluded in parent retrieval to prevent loops

  my $stock = $self->schema->resultset("Stock::Stock")->find({stock_id => $stock_id});
  #print STDERR "Stock ".$stock->uniquename()." decendants are: ".Dumper($direct_descendant_ids)."\n";
  my %pedigree;
  $pedigree{'id'} = $stock_id;
  $pedigree{'name'} = $stock->uniquename();
  $pedigree{'female_parent'} = undef;
  $pedigree{'male_parent'} = undef;
  $pedigree{'link'} = "/stock/$stock_id/view";

  #get cvterms for parent relationships
  my $cvterm_female_parent = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'female_parent', 'stock_relationship');
  my $cvterm_male_parent = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'male_parent', 'stock_relationship');
  my $cvterm_rootstock_of = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'rootstock_of', 'stock_relationship');
  my $cvterm_scion_of = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'scion_of', 'stock_relationship');

  #get the stock relationships for the stock, find stock relationships for types "female_parent" and "male_parent", and get the corresponding subject stock IDs and stocks.
  my $stock_relationships = $stock->search_related("stock_relationship_objects",undef,{ prefetch => ['type','subject'] });
  my $female_parent_relationship = $stock_relationships->find({type_id => { in => [ $cvterm_female_parent->cvterm_id(), $cvterm_scion_of->cvterm_id() ]},  subject_id => {'not_in' => $direct_descendant_ids}});
  if ($female_parent_relationship) {
    my $female_parent_stock_id = $female_parent_relationship->subject_id();
    $pedigree{'cross_type'} = $female_parent_relationship->value();
	$pedigree{'female_parent'} = get_ancestor_hash( $self, $female_parent_stock_id, $direct_descendant_ids );
  }

  my $male_parent_relationship = $stock_relationships->find({type_id => { in => [ $cvterm_male_parent->cvterm_id(), $cvterm_rootstock_of->cvterm_id() ]}, subject_id => {'not_in' => $direct_descendant_ids}});
  if ($male_parent_relationship) {
    my $male_parent_stock_id = $male_parent_relationship->subject_id();
	$pedigree{'male_parent'} = get_ancestor_hash( $self, $male_parent_stock_id, $direct_descendant_ids );
  }
  pop @$direct_descendant_ids; # falling back a level while recursing pedigree tree
  return \%pedigree;
}

=head2 get_descendant_hash()

 Usage:
 Desc:          gets a multi-dimensional hash of this stock's descendants
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_descendant_hash {
  my ($self, $stock_id, $direct_ancestor_ids) = @_;

  if (!$stock_id) { $stock_id = $self->stock_id(); }
  push @$direct_ancestor_ids, $stock_id; #excluded in child retrieval to prevent loops

  my $stock = $self->schema->resultset("Stock::Stock")->find({stock_id => $stock_id});
  #print STDERR "Stock ".$stock->uniquename()." ancestors are: ".Dumper($direct_ancestor_ids)."\n";
  my %descendants;
  my %progeny;
  $descendants{'id'} = $stock_id;
  $descendants{'name'} = $stock->uniquename();
  $descendants{'link'} = "/stock/$stock_id/view";
  #get cvterms for parent relationships
  my $cvterm_female_parent = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'female_parent','stock_relationship');
  my $cvterm_male_parent = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'male_parent', 'stock_relationship');

  #get the stock relationships for the stock, find stock relationships for types "female_parent" and "male_parent", and get the corresponding subject stock IDs and stocks.
  my $descendant_relationships = $stock->search_related("stock_relationship_subjects",{ object_id => {'not_in' => $direct_ancestor_ids}},{ prefetch => ['type','object'] });
  if ($descendant_relationships) {
    while (my $descendant_relationship = $descendant_relationships->next) {
      my $descendant_stock_id = $descendant_relationship->object_id();
      if (($descendant_relationship->type_id() == $cvterm_female_parent->cvterm_id()) || ($descendant_relationship->type_id() == $cvterm_male_parent->cvterm_id())) {
          $progeny{$descendant_stock_id} = get_descendant_hash($self, $descendant_stock_id, $direct_ancestor_ids);
      }
    }
    $descendants{'descendants'} = \%progeny;
    pop @$direct_ancestor_ids; # falling back a level while recursing descendant tree
    return \%descendants;
  }
}

=head2 get_pedigree_rows()

 Usage:
 Desc:          get an array of pedigree rows from an array of stock ids, conatining female parent, male parent, and cross type if defined
 Ret:
 Args: $accession_ids, $format (either 'parents_only' or 'full'), $include (either 'ancestors' or 'ancestors_descendants')
 Side Effects:
 Example:

=cut

sub get_pedigree_rows {
    my ($self, $accession_ids, $format, $include) = @_;
    #print STDERR "Accession ids are: ".Dumper(@$accession_ids)."\n";

    my $placeholders = join ( ',', ('?') x @$accession_ids );
    my @values = ();

    # set the filter criteria based on whether to include ancestors and descendants
    my ($query, $pedigree_rows);
    my $where = "";
    if ( $include eq 'ancestors_descendants' ) {
        $where = "child.stock_id IN ($placeholders) OR m_rel.subject_id IN ($placeholders) OR f_rel.subject_id IN ($placeholders)";
        push(@values, @$accession_ids, @$accession_ids, @$accession_ids);
    }
    else {
        $where = "child.stock_id IN ($placeholders)";
        push(@values, @$accession_ids);
    }

    if ($format eq 'parents_only') {
        $query = "
        SELECT child.uniquename AS Accession,
            mother.uniquename AS Female_Parent,
            father.uniquename AS Male_Parent,
            m_rel.value AS cross_type
        FROM stock child
        LEFT JOIN stock_relationship m_rel ON(child.stock_id = m_rel.object_id and m_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'female_parent'))
        LEFT JOIN stock mother ON(m_rel.subject_id = mother.stock_id)
        LEFT JOIN stock_relationship f_rel ON(child.stock_id = f_rel.object_id and f_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'male_parent'))
        LEFT JOIN stock father ON(f_rel.subject_id = father.stock_id)
        WHERE $where
        GROUP BY 1,2,3,4
        ORDER BY 1";
    }
    elsif ($format eq 'full') {
        $query = "
        WITH RECURSIVE included_rows(child, child_id, mother, mother_id, father, father_id, type, depth, path, cycle) AS (
                SELECT child.uniquename AS child,
                child.stock_id AS child_id,
                m.uniquename AS mother,
                m.stock_id AS mother_id,
                f.uniquename AS father,
                f.stock_id AS father_id,
                m_rel.value AS type,
                1,
                ARRAY[child.stock_id],
                false
                FROM stock child
                LEFT JOIN stock_relationship m_rel ON(child.stock_id = m_rel.object_id and m_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'female_parent'))
                LEFT JOIN stock m ON(m_rel.subject_id = m.stock_id)
                LEFT JOIN stock_relationship f_rel ON(child.stock_id = f_rel.object_id and f_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'male_parent'))
                LEFT JOIN stock f ON(f_rel.subject_id = f.stock_id)
                WHERE $where
                GROUP BY 1,2,3,4,5,6,7,8,9,10
            UNION
                SELECT c.uniquename AS child,
                c.stock_id AS child_id,
                m.uniquename AS mother,
                m.stock_id AS mother_id,
                f.uniquename AS father,
                f.stock_id AS father_id,
                m_rel.value AS type,
                included_rows.depth + 1,
                path || c.stock_id,
                c.stock_id = ANY(path)
                FROM included_rows, stock c
                LEFT JOIN stock_relationship m_rel ON(c.stock_id = m_rel.object_id and m_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'female_parent'))
                LEFT JOIN stock m ON(m_rel.subject_id = m.stock_id)
                LEFT JOIN stock_relationship f_rel ON(c.stock_id = f_rel.object_id and f_rel.type_id = (SELECT cvterm_id FROM cvterm WHERE name = 'male_parent'))
                LEFT JOIN stock f ON(f_rel.subject_id = f.stock_id)
                WHERE c.stock_id IN (included_rows.mother_id, included_rows.father_id) AND NOT cycle
                GROUP BY 1,2,3,4,5,6,7,8,9,10
        )
        SELECT child, mother, father, type
        FROM included_rows
        GROUP BY 1,2,3,4
        ORDER BY 1;";
        # depth was removed from this query since including it was creating a lot of duplicate rows
    }

    my $sth = $self->schema()->storage()->dbh()->prepare($query);
    $sth->execute(@values);

    no warnings 'uninitialized';
    while (my ($name, $mother, $father, $cross_type, $depth) = $sth->fetchrow_array()) {
        #print STDERR "For child $name:\n\tMother:$mother\n\tFather:$father\n\tCross Type:$cross_type\n\tDepth:$depth\n\n";
	    push @$pedigree_rows, "$name\t$mother\t$father\t$cross_type\n";
    }
    return $pedigree_rows;
}

=head2 get_pedigree_string()

 Usage:
 Desc:          get the properly formatted pedigree string of the given level (Parents, Grandparents, or Great-Grandparents) for this stock
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_pedigree_string {
    my ($self, $level) = @_;

    my $pedigree_hashref = $self->get_ancestor_hash();

    #print STDERR "Getting string of level $level from pedigree hashref ".Dumper($pedigree_hashref)."\n";
    if ($level eq "Parents") {
        return $self->_get_parent_string($pedigree_hashref);
    }
    elsif ($level eq "Grandparents") {
        my $maternal_parent_string = $self->_get_parent_string($pedigree_hashref->{'female_parent'});
        my $paternal_parent_string = $self->_get_parent_string($pedigree_hashref->{'male_parent'});
        return "$maternal_parent_string//$paternal_parent_string";
    }
    elsif ($level eq "Great-Grandparents") {
        my $mm_parent_string = $self->_get_parent_string($pedigree_hashref->{'female_parent'}->{'female_parent'});
        my $mf_parent_string = $self->_get_parent_string($pedigree_hashref->{'female_parent'}->{'male_parent'});
        my $pm_parent_string = $self->_get_parent_string($pedigree_hashref->{'male_parent'}->{'female_parent'});
        my $pf_parent_string = $self->_get_parent_string($pedigree_hashref->{'male_parent'}->{'male_parent'});
        return "$mm_parent_string//$mf_parent_string///$pm_parent_string//$pf_parent_string";
    }
}

sub _get_parent_string {
    my ($self, $pedigree_hashref) = @_;
    my $mother = $pedigree_hashref->{'female_parent'}->{'name'} || 'NA';
    my $father = $pedigree_hashref->{'male_parent'}->{'name'} || 'NA';
    return "$mother/$father";
}

sub get_parents {
    my $self =  shift;
    my $pedigree_hashref = $self->get_ancestor_hash();
    my %parents;
    $parents{'mother'} = $pedigree_hashref->{'female_parent'}->{'name'};
    $parents{'mother_id'} = $pedigree_hashref->{'female_parent'}->{'id'};
    $parents{'father'} = $pedigree_hashref->{'male_parent'}->{'name'};
    $parents{'father_id'} = $pedigree_hashref->{'male_parent'}->{'id'};
    $parents{'cross_type'} = $pedigree_hashref->{'female_parent'}->{'cross_type'};
    return \%parents;
}

sub _store_stockprop {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    # print STDERR Dumper $type;
    my $stockprop = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->name();
    my @arr = split ',', $value;
    foreach (@arr){
        my $stored_stockprop = $self->stock->create_stockprops({ $stockprop => $_});
    }
}

sub _update_stockprop {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $stockprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->cvterm_id();
    my $rs = $self->stock->search_related('stockprops', {'type_id'=>$stockprop_cvterm_id});
    while(my $r=$rs->next){
        $r->delete();
    }
    $self->_store_stockprop($type,$value);
}

# Doesn't split the value like the _store_stockprop method
sub _store_stockprop_raw {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    # print STDERR Dumper $type;
    my $stockprop = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->name();
    my $stored_stockprop = $self->stock->create_stockprops({ $stockprop => $value});
}

sub _update_stockprop_raw {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $stockprop_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->cvterm_id();
    my $rs = $self->stock->search_related('stockprops', {'type_id'=>$stockprop_cvterm_id});
    while(my $r=$rs->next){
        $r->delete();
    }
    $self->_store_stockprop_raw($type,$value);
}

=head2 _retrieve_stockprop

 Usage:
 Desc:         Retrieves stockprops as a comma separated string
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub _retrieve_stockprop {
    my $self = shift;
    my $type = shift;
    my @results;

    try {
        my $stockprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->cvterm_id();
        my $rs = $self->schema()->resultset("Stock::Stockprop")->search({ stock_id => $self->stock_id(), type_id => $stockprop_type_id }, { order_by => {-asc => 'stockprop_id'} });

        while (my $r = $rs->next()){
            push @results, $r->value;
        }
    } catch {
        #print STDERR "Cvterm $type does not exist in this database\n";
    };

    my $res = join ',', @results;
    return $res;
}

=head2 _retrieve_stockprops

 Usage:
 Desc:         Retrieves stockprop as a list of [stockprop_id, value]
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub _retrieve_stockprops {
    my $self = shift;
    my $type = shift;
    my @results;

    try {
        my $stockprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->cvterm_id();
        my $rs = $self->schema()->resultset("Stock::Stockprop")->search({ stock_id => $self->stock_id(), type_id => $stockprop_type_id }, { order_by => {-asc => 'stockprop_id'} });

        while (my $r = $rs->next()){
            push @results, [ $r->stockprop_id(), $r->value() ];
        }
    } catch {
        #print STDERR "Cvterm $type does not exist in this database\n";
    };

    return @results;
}

sub _remove_stockprop {
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->cvterm_id();
    my $rs = $self->schema()->resultset("Stock::Stockprop")->search( { type_id=>$type_id, stock_id => $self->stock_id(), value=>$value } );

    if ($rs->count() == 1) {
        $rs->first->delete();
        return 1;
    }
    elsif ($rs->count() == 0) {
        return 0;
    }
    else {
        print STDERR "Error removing stockprop from stock ".$self->stock_id().". Please check this manually.\n";
        return 0;
    }

}

sub _remove_stockprop_all_of_type {

    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->cvterm_id();
    my $rs = $self->schema()->resultset("Stock::Stockprop")->search( { type_id=>$type_id, stock_id => $self->stock_id() } );

    if ($rs->count() > 0) {
        while (my $row = $rs->next()) {
            $row->delete();
        }
        return 1;
    }
    elsif ($rs->count() == 0) {
        return 0;
    }
    else {
        print STDERR "Error removing stockprop from stock ".$self->stock_id().". Please check this manually.\n";
        return 0;
    }
}

sub _retrieve_organismprop {
    my $self = shift;
    my $type = shift;
    my @results;

    try {
        my $organismprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'organism_property')->cvterm_id();
        my $rs = $self->schema()->resultset("Organism::Organismprop")->search({ organism_id => $self->stock->organism_id, type_id => $organismprop_type_id }, { order_by => {-asc => 'organismprop_id'} });

        while (my $r = $rs->next()){
            push @results, $r->value;
        }
    } catch {
        #print STDERR "Cvterm $type does not exist in this database\n";
    };

    my $res = join ',', @results;
    return $res;
}

##Move to a population child object##
sub _store_population_relationship {
    my $self = shift;
    my $schema = $self->schema;
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population','stock_type')->cvterm_id();
    my $population_member_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of','stock_relationship')->cvterm_id();

    my @populations = split /\|/, $self->population_name();

    foreach my $population_name (@populations) {

	print STDERR "***STOCK.PM : find_or_create population relationship $population_cvterm_id \n\n";
	my $population_row = $schema->resultset("Stock::Stock")->find_or_create({
	    uniquename => $population_name,
	    name => $population_name,
	    organism_id => $self->organism_id(),
	    type_id => $population_cvterm_id,
        });
	$self->stock->find_or_create_related('stock_relationship_subjects', {
	    type_id => $population_member_cvterm_id,
	    object_id => $population_row->stock_id(),
	    subject_id => $self->stock_id(),
        });
    }
}

##Move to a population child object##
sub _update_population_relationship {
    my $self = shift;
    print STDERR "***STOCK.PM Updating population relationship\n\n";
    my $population_member_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($self->schema, 'member_of','stock_relationship')->cvterm_id();
    my $pop_rs = $self->stock->search_related('stock_relationship_subjects', {'type_id'=>$population_member_cvterm_id});
    while (my $r=$pop_rs->next){
        $r->delete();
    }
    $self->_store_population_relationship();
}


##
sub _retrieve_populations {
    my $self = shift;
    my $schema = $self->schema;
    my $population_member_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of','stock_relationship')->cvterm_id();

    my $rs = $schema->resultset("Stock::StockRelationship")->search({
        type_id => $population_member_cvterm_id,
        subject_id => $self->stock_id(),
    });
    if ($rs->count == 0) {
        #print STDERR "No population saved for this stock!\n";
    }
    else {
        my @population_names;
        my @population_name;
        while (my $row = $rs->next) {
            my $population = $row->object;
            push @population_name, $population->uniquename();
            push @population_names, [$population->stock_id(), $population->uniquename()];
        }
        my $pop_string = join ',', @population_name;
        $self->populations(\@population_names);
        $self->population_name($pop_string);
    }
}

sub _store_parent_relationship {
    my $self = shift;
    my $relationship_type = shift;
    my $parent_accession = shift;
    my $cross_type = shift;
    my $schema = $self->schema;
    my $parent_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, $relationship_type,'stock_relationship')->cvterm_id();
    my %return;

    print STDERR "***STOCK.PM : Storing parent relationship $parent_cvterm_id \n\n";
    my $parent = $schema->resultset("Stock::Stock")->find({
        uniquename => $parent_accession
    });

    # TODO: Check the cross type

    if (defined $parent) {
        # Object is the child, subject is the mother
        $self->stock->find_or_create_related('stock_relationship_subjects', {
            type_id    => $parent_cvterm_id,
            object_id  => $self->stock_id(),
            subject_id => $parent->stock_id(),
            value      => $cross_type
        });
    } else {
        return $return{error} = "Parent accession not found: ".$parent_accession;
    }
}

sub _remove_parent_relationship {
    my $self = shift;
    my $relationship_type = shift;
    my $parent_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($self->schema, $relationship_type,'stock_relationship')->cvterm_id();
    my $rs = $self->schema()->resultset("Stock::StockRelationship")->search( { type_id=>$parent_cvterm_id, object_id => $self->stock_id() } );

    while (my $r=$rs->next){
        $r->delete();
    }
}

###

=head2 _new_metadata_id()

Usage: my $md_id = $self->_new_metatada_id($sp_person_id)
Desc:  Store a new md_metadata row with a $sp_person_id
Ret:   a database id
Args:  sp_person_id

=cut

sub _new_metadata_id {
    my $self = shift;
    my $sp_person_id = shift;
    my $user_name = shift;
    my $modification_note = shift;
    my $obsolete_note = shift;
    my $metadata_schema = CXGN::Metadata::Schema->connect(
        sub { $self->schema()->storage()->dbh() },
        );
    $metadata_schema->storage->dbh->do('SET search_path TO metadata');
    my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema);
    $metadata->set_create_person_id($sp_person_id);
    my $metadata_id = $metadata->store()->get_metadata_id();
    if ($modification_note){
        my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema, $user_name, $metadata_id);
        $metadata->set_modification_note($modification_note);
        $metadata->set_obsolete_note($obsolete_note);
        $metadata_id = $metadata->store()->get_metadata_id();
    }
    $metadata_schema->storage->dbh->do('SET search_path TO public,sgn');
    return $metadata_id;
}

=head2 add_synonym

Usage: $self->add_synonym
 Desc:  add a synonym for this stock. a stock can have many synonyms
 Ret:   nothing
 Args:  name
 Side Effects:
 Example:

=cut

sub add_synonym {
    my $self = shift;
    my $synonym = shift;
    my $synonym_cvterm = SGN::Model::Cvterm->get_cvterm_row($self->get_schema, 'stock_synonym', 'stock_property');
    my $stock = $self->schema()->resultset("Stock::Stock")->find( { stock_id => $self->stock_id() });
    $stock->create_stockprops({$synonym_cvterm->name() => $synonym});
}



=head2 merge()

 Usage:         $s->merge(221, 1);
 Desc:          merges stock $s with stock_id 221. Optional delete boolean
                parameter indicates whether other stock should be deleted.
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub merge {
    my $self = shift;
    my $other_stock_id = shift;
    my $delete_other_stock = shift;

    if ($other_stock_id == $self->stock_id()) {
	print STDERR "Trying to merge stock into itself ($other_stock_id) Skipping...\n";
	return "Error: cannot merge stock into itself";
    }

    my $stockprop_count=0;
    my $subject_rel_count=0;
    my $object_rel_count=0;
    my $stock_allele_count=0;
    my $image_count=0;
    my $experiment_stock_count=0;
    my $stock_dbxref_count=0;
    my $stock_owner_count=0;
    my $parent_1_count=0;
    my $parent_2_count=0;
    my $nd_experiment_stock_count=0;
    my $other_stock_deleted = 'NO';
    my $add_old_name_as_synonym = 0;
    my $pui_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, 'PUI', 'stock_property')->cvterm_id();

    my $schema = $self->schema();

    my $other_row = $schema->resultset("Stock::Stock")->find( { stock_id => $other_stock_id });

    # check if parents are the same
    my $other_stock = CXGN::Stock->new( { schema => $self->schema(), stock_id => $other_stock_id });

    my $other_parents = $other_stock->get_parents();
    my $this_parents = $self->get_parents();

    print STDERR "OTHER parents: ".Dumper($other_parents);
    print STDERR "This parents: ".Dumper($this_parents);

    my $skip_mother_comp = 0;
    my $skip_father_comp = 0;

    if (! defined($other_parents->{mother_id}) || ! defined($this_parents->{mother_id})) {
	print STDERR "Can't compare mothers for these accessions.\n";
	$skip_mother_comp =1;
    }

    if (! defined($other_parents->{father_id}) || ! defined($this_parents->{father_id})) {
	print STDERR "Can't compare fathers for this accession.\n";
	$skip_father_comp = 1;
    }

    my $mother_identical = 0;
    my $father_identical = 0;
    if (! $skip_mother_comp) {
	if ( (defined($other_parents->{mother_id}) && defined($this_parents->{mother_id})) && ($other_parents->{mother_id} == $this_parents->{mother_id})) {
	    $mother_identical = 1;
	}
    }
    if (! $skip_father_comp) {
	if ( (defined($other_parents->{father_id}) && defined($this_parents->{father_id})) && ( $other_parents->{father_id} == $this_parents->{father_id})) {
	    $father_identical = 1;
	}
    }

    if ( (!$skip_mother_comp && $mother_identical) && (!$skip_father_comp && $father_identical)) {
	print STDERR "Mother and Father between this and other match ($other_parents->{mother_id} vs $this_parents->{mother_id}).\n";
    }
    elsif ($skip_mother_comp && $father_identical || $skip_father_comp && $mother_identical) {
	print STDERR "One parent undefined, the other matches...\n";
    }
    elsif ($skip_mother_comp && $skip_father_comp) {
	print STDERR "Skipping this comparison - not enough data! \n";
    }
    else {
	return join ("\t", $self->uniquename(), $other_stock->uniquename(), "MOTHERS", $other_parents->{mother_id}, $other_parents->{mother}, $this_parents->{mother_id}, $this_parents->{mother}, "FATHERS", $other_parents->{father_id}, $other_parents->{father}, $this_parents->{father_id}, $this_parents->{father}, "PARENTS DO NOT MATCH!")."\n";
    }

    # move stockprops
    #
    my $other_sprs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $other_stock_id });

    while (my $row = $other_sprs->next()) {
	# not sure what this does...
	if ($delete_other_stock && ($row->type_id() eq $pui_cvterm_id)) {
	    # Do not save PUIs of stocks that will be deleted
	    next();
	}
	# check if this stockprop already exists for this stock; save only if not
	#
	my $thissprs = $schema->resultset("Stock::Stockprop")->search(
	    {
		stock_id => $self->stock_id(),
		type_id => $row->type_id(),
		value => $row->value()
	    });

	if ($thissprs->count() == 0) {
	    my $value = $row->value();
	    my $type_id = $row->type_id();

	    my $rank_rs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $self->stock_id(), type_id => $type_id });

	    my $rank;
	    if ($rank_rs->count() > 0) {
		$rank = $rank_rs->get_column("rank")->max();
	    }

	    $rank++;
	    $row->rank($rank);
	    $row->stock_id($self->stock_id());

	    $row->update();

	    print STDERR "MERGED stockprop_id ".$row->stockprop_id." for stock $other_stock_id type_id $type_id value $value into stock ".$self->stock_id()."\n";
	    $stockprop_count++;
	}

    }

    # move subject relationships
    #
    my $ssrs = $schema->resultset("Stock::StockRelationship")->search( { subject_id => $other_stock_id });

    while (my $row = $ssrs->next()) {

	# the next query is done to make sure that we don't add the same information again.
	# Only if the info is not already there can we safely add it. This will for example
	# prevent us from ending up with 4 parents etc.
	#
	my $this_subject_rel_rs = $schema->resultset("Stock::StockRelationship")->search( { subject_id => $self->stock_id(), object_id => $other_stock_id, type_id => $row->type_id() });

	if ($this_subject_rel_rs->count() != 0) { # this stock does not have the relationship
	    print STDERR "Target object ".$row->uniquename()." already has this relationship (".$this_subject_rel_rs->count()." counts)\n";
	}
	else {
	    # get the max rank
	    my $rank_rs = $schema->resultset("Stock::StockRelationship")->search( { subject_id => $self->stock_id(), type_id => $row->type_id() });
	    my $rank = 0;
	    if ($rank_rs->count() > 0) {
		$rank = $rank_rs->get_column("rank")->max();
	    }
	    $rank++;
	    $row->rank($rank);
	    $row->subject_id($self->stock_id());
	    $row->update();
	    print STDERR "Moving subject relationships from stock $other_stock_id to stock ".$self->stock_id()."\n";
	    $subject_rel_count++;
	}
    }

    my $osrs = $schema->resultset("Stock::StockRelationship")->search( { object_id => $other_stock_id });
    while (my $row = $osrs->next()) {
	my $this_object_rel_rs = $schema->resultset("Stock::StockRelationship")->search( { object_id => $self->stock_id, subject_id => $other_stock_id, type_id => $row->type_id() });

	if ($this_object_rel_rs->count() != 0) {
	    print STDERR "Target object ".$row->uniquename()." already has this relationship with ".$this_object_rel_rs->count()." counts\n";;
	}
	else {
	    my $rank_rs = $schema->resultset("Stock::StockRelationship")->search( { object_id => $self->stock_id(), type_id => $row->type_id() });
	    my $rank = 0;
	    if ($rank_rs->count() > 0) {
		$rank = $rank_rs->get_column("rank")->max();
	    }
	    $rank++;
	    $row->rank($rank);
	    $row->object_id($self->stock_id());
	    $row->update();
	    print STDERR "Moving object relationships from stock $other_stock_id to stock ".$self->stock_id()."\n";
	    $object_rel_count++;
	}
    }

    # move experiment_stock
    #
    my $esrs = $schema->resultset("NaturalDiversity::NdExperimentStock")->search( { stock_id => $other_stock_id });
    while (my $row = $esrs->next()) {
	$row->stock_id($self->stock_id());
	$row->update();
	print STDERR "Moving experiments for stock $other_stock_id to stock ".$self->stock_id()."\n";
	$experiment_stock_count++;
    }

    # move stock_cvterm relationships
    #
    my $scvr = $schema->resultset("Stock::StockCvterm")->search( { stock_id => $other_stock_id } );
    while (my $row = $scvr->next()) {
	$row->stock_id($self->stock_id);
	$row->update();
	print STDERR "Moving stock_cvterm relationships for $other_stock_id to stock ".$self->stock_id()."\n";
    }

    # move stock_dbxref
    #
    my $sdrs = $schema->resultset("Stock::StockDbxref")->search( { stock_id => $other_stock_id });
    while (my $row = $sdrs->next()) {

	# check if the current stock already has the same dbxref assigned
	# and if yes, do not move as it violates a unique constraint.
	#
	my $check_row = $schema-> resultset("Stock::StockDbxref")->find( { dbxref_id => $row->dbxref_id(), stock_id => $self->stock_id() });

        if ($check_row) {

            $row->stock_id($self->stock_id());
            $row->update();
            $stock_dbxref_count++;
            print STDERR "Moving stock_dbxref relationships from $other_stock_id to stock ".$self->stock_id()."\n";
        }
        else {
            print STDERR "Not moving stock_dbxref because it already exists for that stock (".$self->stock_id().")\n";
        }
    }

    # move sgn.pcr_exp_accession relationships
    #


    # move sgn.pcr_experiment relationships
    #



    # move stock_genotype relationships and other nd_experiment entries
    #
    my $ndes = $schema->resultset("NaturalDiversity::NdExperimentStock")->search( { stock_id => $other_stock_id } );
    while (my $row = $ndes->next()) {
	$row->stock_id($self->stock());
	$row->update();
	$nd_experiment_stock_count++;
	print STDERR "Moving nd_experiment_stock relationships from $other_stock_id to stock ".$self->stock_id()."\n";
    }

    my $phenome_schema = CXGN::Phenome::Schema->connect(
	sub { $self->schema()->storage()->dbh() }, { on_connect_do => [ 'SET search_path TO phenome, public, sgn'], limit_dialect => 'LimitOffset' }
	);

    # move phenome.stock_allele relationships
    #
    my $sars = $phenome_schema->resultset("StockAllele")->search( { stock_id => $other_stock_id });
    while (my $row = $sars->next()) {
	$row->stock_id($self->stock_id());
	$row->update();
	print STDERR "Moving stock alleles from stock $other_stock_id to stock ".$self->stock_id()."\n";
	$stock_allele_count++;
    }

    # move image relationships
    #
    my $irs = $phenome_schema->resultset("StockImage")->search( { stock_id => $other_stock_id });
    while (my $row = $irs->next()) {

	my $this_rs = $phenome_schema->resultset("StockImage")->search( { stock_id => $self->stock_id(), image_id => $row->image_id() } );
	if ($this_rs->count() == 0) {
	    $row->stock_id($self->stock_id());
	    $row->update();
	    print STDERR "Moving image ".$row->image_id()." from stock $other_stock_id to stock ".$self->stock_id()."\n";
	    $image_count++;
	}
	else {
	    print STDERR "Removing stock_image entry...\n";
	    $row->delete(); # there is no cascade delete on image relationships, so we need to remove dangling relationships.
	}
    }

    # move stock owners
    #
    my $sors = $phenome_schema->resultset("StockOwner")->search( { stock_id => $other_stock_id });
    while (my $row = $sors->next()) {

	my $this_rs = $phenome_schema->resultset("StockOwner")->search( { stock_id => $self->stock_id(), sp_person_id => $row->sp_person_id() });
	if ($this_rs->count() == 0) {
	    $row->stock_id($self->stock_id());
	    $row->update();
	    print STDERR "Moved stock_owner ".$row->sp_person_id()." of stock $other_stock_id to stock ".$self->stock_id()."\n";
	    $stock_owner_count++;
	}
	else {
	    print STDERR "(Deleting stock owner entry for stock $other_stock_id, owner ".$row->sp_person_id()."\n";
	    $row->delete(); # see comment for move image relationships
	}
    }

    # move map parents
    #
    my $sgn_schema = SGN::Schema->connect(
	sub { $self->schema()->storage()->dbh() }, { limit_dialect => 'LimitOffset' }
	);

    my $mrs1 = $sgn_schema->resultset("Map")->search( { parent_1 => $other_stock_id });
    while (my $row = $mrs1->next()) {
	$row->parent_1($self->stock_id());
	$row->update();
	print STDERR "Move map parent_1 $other_stock_id to ".$self->stock_id()."\n";
	$parent_1_count++;
    }

    my $mrs2 = $sgn_schema->resultset("Map")->search( { parent_2 => $other_stock_id });
    while (my $row = $mrs2->next()) {
	$row->parent_2($self->stock_id());
	$row->update();
	print STDERR "Move map parent_2 $other_stock_id to ".$self->stock_id()."\n";
	$parent_2_count++;
    }


    # transfer the other uniquename as a synonym
    #
    $self->add_synonym($other_row->uniquename());
    $add_old_name_as_synonym++;
    # deletion is handled by the script now
#    if ($delete_other_stock) {
#	my $row = $self->schema()->resultset("Stock::Stock")->find( { stock_id => $other_stock_id });
#	$row->delete();
#	$other_stock_deleted = 'YES';
 #   }


    print STDERR "Done with merge of stock_id $other_stock_id into ".$self->stock_id()."\n";
    print STDERR "Relationships moved: \n";
    print STDERR <<COUNTS;
    Stock props: $stockprop_count
    Subject rels: $subject_rel_count
    Object rels: $object_rel_count
    Alleles: $stock_allele_count
    Images: $image_count
    Experiments: $experiment_stock_count
    Dbxrefs: $stock_dbxref_count
    Stock owners: $stock_owner_count
    Map parents: $parent_1_count
    Map parents: $parent_2_count
    Added old name as synonym: $add_old_name_as_synonym
    Other stock deleted: $other_stock_deleted.
COUNTS

	return;
}

=head2 delete

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub hard_delete {
    my $self = shift;

    # delete sgn.stock_owner entry
    #
    my $q = "DELETE FROM phenome.stock_owner WHERE stock_id=?";
    my $h = $self->schema()->storage()->dbh()->prepare($q);
    $h->execute($self->stock_id());

    # delete sgn.stock_image entry
    #
    $q = "DELETE FROM phenome.stock_image WHERE stock_id=?";
    $h = $self->schema()->storage()->dbh()->prepare($q);
    $h->execute($self->stock_id());

    # delete stock entry
    #
    $q = "DELETE FROM stock WHERE stock_id=?";
    $h = $self->schema()->storage()->dbh()->prepare($q);
    $h->execute($self->stock_id());
}


###__PACKAGE__->meta->make_immutable;

##########
1;########
##########
