=head1 NAME

CXGN::Stock - a second-level object for Stock

Version: 2.0

=head1 DESCRIPTION

This object was re-factored from CXGN::Chado::Stock and moosified.

Functions such as 'get_obsolete' , 'store' , and 'exists_in_database' are required , and do not use standard DBIC syntax.

=head1 AUTHOR

Naama Menda <nm249@cornell.edu>
Lukas Mueller <lam87@cornell.edu>

=cut

package CXGN::Stock ;

use Moose;

use Carp;
use Data::Dumper;
use Bio::Chado::Schema;
use CXGN::Metadata::Schema;
use SGN::Model::Cvterm;
use Bio::GeneticRelationships::Pedigree;
use Bio::GeneticRelationships::Individual;
use base qw / CXGN::DB::Object / ;
use CXGN::Stock::StockLookup;

has 'schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'check_name_exists' => (
    isa => 'Bool',
    is => 'rw',
    default => 1
);

has 'stock' => (
    isa => 'Bio::Chado::Schema::Result::Stock::Stock',
    is => 'rw',
);

has 'stock_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);

has 'organism' => (
    isa => 'Bio::Chado::Schema::Result::Organism::Organism',
    is => 'rw',
);

has 'organism_id' => (
    isa => 'Maybe[Int]',
    is => 'rw',
);

has 'species' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'genus' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'organism_common_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'organism_abbreviation' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'organism_comment' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'type' => (
    isa => 'Str',
    is => 'rw',
    default => 'accession',
);

has 'type_id' => (
    isa => 'Int',
    is => 'rw',
);

has 'name' => (
    isa => 'Str',
    is => 'rw',
);

has 'uniquename' => (
    isa => 'Str',
    is => 'rw',
);

has 'description' => (
    isa => 'Maybe[Str]',
    is => 'rw',
    default => '',
);

has 'is_obsolete' => (
    isa => 'Bool',
    is => 'rw',
    default => 0,
);

has 'organization_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'population_name' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);


sub BUILD {
    my $self = shift;

    print STDERR "RUNNING BUILD FOR STOCK.PM...\n";
    my $stock;
    if ($self->stock_id){
        $stock = $self->schema()->resultset("Stock::Stock")->find({ stock_id => $self->stock_id() });
    }
    if (defined $stock) {
        $self->stock($stock);
        $self->stock_id($stock->stock_id);
        $self->name($stock->name);
        $self->uniquename($stock->uniquename);
        $self->description($stock->description() || '');
        $self->type_id($stock->type_id);
        $self->type($self->schema()->resultset("Cv::Cvterm")->find({ cvterm_id=>$self->type_id() })->name());
        $self->is_obsolete($stock->is_obsolete);
        $self->organization_name($self->_retrieve_stockprop('organization'));
        $self->_retrieve_population();
    }

    return $self;
}



=head2 store

 Usage: $self->store
 Desc:  store a new stock or update an existing stock
 Ret:   a database id
 Args:  none
 Side Effects: checks if the stock exists in the database (if a stock_id is provided), and if does, will attempt to update
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

    if (!$self->type_id) { 
        my $type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), $self->type(), 'stock_type')->cvterm_id();
        $self->type_id($type_id);
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

    if (!$stock) { #Trying to create a new stock
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
                $self->_store_population_relationship();
            }

        }
        else {
            die "The entry ".$self->uniquename()." already exists in the database. Error: $exists\n";
        }
    }
    else {  # entry exists, so update
        print STDERR "EXISTS: $exists\n";
        my $row = $self->schema()->resultset("Stock::Stock")->find({ stock_id => $self->stock_id() });
        $row->name($self->name());
        $row->uniquename($self->uniquename());
        $row->description($self->description());
        $row->type_id($self->type_id());
        $row->organism_id($self->organism_id());
        $row->is_obsolete($self->is_obsolete());
        $row->update();
    }
    return $self->stock_id();
}

########################


=head2 exists_in_database

 Usage: $self->exists_in_database()
 Desc:  check if the uniquename exists in the stock table
 Ret:
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
    my $stock_lookup = CXGN::Stock::StockLookup->new({
        schema => $schema,
        stock_name => $uniquename
    });
    my $s = $stock_lookup->get_stock();

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
    return undef;
}

=head2 get_organism

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
    return undef;
}


=head2 get_species

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
	return undef; 
    }
}

=head2 set_species

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

=head2 function get_image_ids

  Synopsis:     my @images = $self->get_image_ids()
  Arguments:    none
  Returns:      a list of image ids
  Side effects:	none
  Description:	a method for fetching all images associated with a stock

=cut

sub get_image_ids {
    my $self = shift;
    my $ids = $self->schema()->storage->dbh->selectcol_arrayref
	( "SELECT image_id FROM phenome.stock_image WHERE stock_id=? ",
	  undef,
	  $self->stock_id
        );
    return @$ids;
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

=head2 associate_owner

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
    if (!$owner_id || !$sp_person_id) {
        warn "Need both owner_id and person_id for linking the stock with an owner!";
        return;
    }
    my $metadata_id = $self->_new_metadata_id($sp_person_id);
    #check if the owner is already linked
    my $ids =  $self->schema()->storage()->dbh()->selectcol_arrayref
        ( "SELECT stock_owner_id FROM phenome.stock_owner WHERE stock_id = ? AND owner_id = ?",
          undef,
          $self->stock_id,
          $owner_id
        );
    if ($ids) { warn "Owner $owner_id is already linked with stock " . $self->stock_id ; }
#store the owner_id - stock_id link
    my $q = "INSERT INTO phenome.stock_owner (stock_id, owner_id, metadata_id) VALUES (?,?,?) RETURNING stock_owner_id";
    my $sth  = $self->schema()->storage()->dbh()->prepare($q);
    $sth->execute($self->stock_id, $owner_id, $metadata_id);
    my ($id) =  $sth->fetchrow_array;
    return $id;
}

=head2 get_trait_list

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
    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($self->stock_id(), $numeric_regex);
    my @traits;
    while (my ($cvterm_id, $cvterm_accession, $cvterm_name, $avg, $stddev) = $h->fetchrow_array()) {
	push @traits, [ $cvterm_id, $cvterm_accession, $cvterm_name, $avg, $stddev ];
    }

    # get directly associated traits
    #
    $q = "select distinct(cvterm.cvterm_id), db.name || ':' || dbxref.accession, cvterm.name, avg(phenotype.value::Real), stddev(phenotype.value::Real) from stock JOIN nd_experiment_stock ON (stock.stock_id=nd_experiment_stock.stock_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenotype USING (phenotype_id) JOIN cvterm ON (phenotype.cvalue_id = cvterm.cvterm_id) JOIN dbxref ON(cvterm.dbxref_id = dbxref.dbxref_id) JOIN db USING(db_id) where stock.stock_id=? and phenotype.value~? group by cvterm.cvterm_id, db.name || ':' || dbxref.accession, cvterm.name";

    $h = $self->schema()->storage()->dbh()->prepare($q);
    $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($self->stock_id(), $numeric_regex);

    while (my ($cvterm_id, $cvterm_accession, $cvterm_name, $avg, $stddev) = $h->fetchrow_array()) {
	push @traits, [ $cvterm_id, $cvterm_accession, $cvterm_name, $avg, $stddev ];
    }

    return @traits;
}

=head2 get_trials

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
    my $q = "select distinct(project.project_id), project.name, projectprop.value from stock as accession join stock_relationship on (accession.stock_id=stock_relationship.object_id) JOIN stock as plot on (plot.stock_id=stock_relationship.subject_id) JOIN nd_experiment_stock ON (plot.stock_id=nd_experiment_stock.stock_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN project USING (project_id) LEFT JOIN projectprop ON (project.project_id=projectprop.project_id) where projectprop.type_id=$geolocation_type_id AND accession.stock_id=?;";

    my $h = $dbh->prepare($q);
    $h->execute($self->stock_id());

    my @trials;
    while (my ($project_id, $project_name, $nd_geolocation_id) = $h->fetchrow_array()) {
        push @trials, [ $project_id, $project_name, $nd_geolocation_id, $geolocations{$nd_geolocation_id} ];
    }
    return @trials;
}

sub get_direct_parents {
    my $self = shift;
    my $stock_id = shift || $self->stock_id();

    print STDERR "get_direct_parents with $stock_id...\n";

    my $female_parent_id;
    my $male_parent_id;
    eval {
	$female_parent_id = $self->schema()->resultset("Cv::Cvterm")->find( { name => 'female_parent' })->cvterm_id();
	$male_parent_id = $self->schema()->resultset("Cv::Cvterm")->find( { name => 'male_parent' }) ->cvterm_id();
    };
    if ($@) {
	die "Cvterm for female_parent and/or male_parent seem to be missing in the database\n";
    }

    my $rs = $self->schema()->resultset("Stock::StockRelationship")->search( { object_id => $stock_id, type_id => { -in => [ $female_parent_id, $male_parent_id ] } });
    my @parents;
    while (my $row = $rs->next()) {
	print STDERR "Found parent...\n";
	my $prs = $self->schema()->resultset("Stock::Stock")->find( { stock_id => $row->subject_id() });
	my $parent_type = "";
	if ($row->type_id() == $female_parent_id) {
	    $parent_type = "female";
	}
	if ($row->type_id() == $male_parent_id) {
	    $parent_type = "male";
	}
	push @parents, [ $prs->stock_id(), $prs->uniquename(), $parent_type ];
    }

    return @parents;
}

sub get_recursive_parents {
    my $self = shift;
    my $individual = shift;
    my $max_level = shift || 1;
    my $current_level = shift;

    if (!defined($individual)) { return; }

    if ($current_level > $max_level) {
	print STDERR "Reached level $current_level of $max_level... we are done!\n";
	return;
    }

    $current_level++;
    my @parents = $self->get_direct_parents($individual->get_id());

    my $pedigree = Bio::GeneticRelationships::Pedigree->new( { name => $individual->get_name()."_pedigree", cross_type=>"unknown"} );

    foreach my $p (@parents) {
	my ($parent_id, $parent_name, $relationship) = @$p;

	my ($female_parent, $male_parent, $attributes);
	my $parent = Bio::GeneticRelationships::Individual->new( { name => $parent_name, id=> $parent_id });
	if ($relationship eq "female") {
	    $pedigree->set_female_parent($parent);
	}

	if ($relationship eq "male") {
	    print STDERR "Adding male parent...\n";
	    $pedigree->set_male_parent($parent);
	}
	$self->get_recursive_parents($parent, $max_level, $current_level);
    }
    $individual->set_pedigree($pedigree);
}

sub get_parents {
    my $self = shift;
    my $max_level = shift || 1;

    my $root = Bio::GeneticRelationships::Individual->new(
	{
	    name => $self->uniquename(),
	    id => $self->stock_id(),
	});

    $self->get_recursive_parents($root, $max_level, 0);

    return $root;
}

sub _store_stockprop { 
    my $self = shift;
    my $type = shift;
    my $value = shift;
    my $stockprop = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->name();
    my $stored_stockprop = $self->stock->create_stockprops({ $stockprop => $value});
}

sub _retrieve_stockprop {
    my $self = shift;
    my $type = shift;

    my $stockprop_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema, $type, 'stock_property')->cvterm_id();
    my $rs = $self->schema()->resultset("Stock::Stockprop")->search({ stock_id => $self->stock_id(), type_id => $stockprop_type_id }, { order_by => {-asc => 'stockprop_id'} });

    my @results;
    while (my $r = $rs->next()){
        push @results, $r->value;
    }
    my $res = join ',', @results;
    return $res;
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

sub _store_population_relationship {
    my $self = shift;
    my $schema = $self->schema;
    my $population_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'population','stock_type')->cvterm_id();
    my $population_member_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of','stock_relationship')->cvterm_id();

    my $population = $schema->resultset("Stock::Stock")->find_or_create({
        uniquename => $self->population_name(),
        name => $self->population_name(),
        organism_id => $self->organism_id(),
        type_id => $population_cvterm_id,
    });
    $self->stock->find_or_create_related('stock_relationship_objects', {
        type_id => $population_member_cvterm_id,
        object_id => $population->stock_id(),
        subject_id => $self->stock_id(),
    });
}

sub _retrieve_population {
    my $self = shift;
    my $schema = $self->schema;
    my $population_member_cvterm_id =  SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of','stock_relationship')->cvterm_id();

    my $rs = $schema->resultset("Stock::StockRelationship")->search({
        type_id => $population_member_cvterm_id,
        subject_id => $self->stock_id(),
    });
    if ($rs->count == 1) {
        my $population = $rs->first->object;
        $self->population_name($population->uniquename);
    }
    elsif ($rs->count > 1) {
        die "More than one population saved for this stock!\n";
    }
    elsif ($rs->count == 0) {
        print STDERR "No population saved for this stock!\n";
    }
}

=head2 _new_metadata_id

Usage: my $md_id = $self->_new_metatada_id($sp_person_id)
Desc:  Store a new md_metadata row with a $sp_person_id
Ret:   a database id
Args:  sp_person_id

=cut

sub _new_metadata_id {
    my $self = shift;
    my $sp_person_id = shift;
    my $metadata_schema = CXGN::Metadata::Schema->connect(
        sub { $self->schema()->storage()->dbh() },
        );
    my $metadata = CXGN::Metadata::Metadbdata->new($metadata_schema);
    $metadata->set_create_person_id($sp_person_id);
    my $metadata_id = $metadata->store()->get_metadata_id();
    return $metadata_id;
}

=head2 merge

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
	return;
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
    my $other_stock_deleted = 'NO';


    my $schema = $self->schema();

    # move stockprops
    #
    my $sprs = $schema->resultset("Stock::Stockprop")->search( { stock_id => $other_stock_id });
    while (my $row = $sprs->next()) {

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

	my $this_subject_rel_rs = $schema->resultset("Stock::StockRelationship")->search( { subject_id => $self->stock_id(), object_id => $row->object_id, type_id => $row->type_id() });

	if ($this_subject_rel_rs->count() == 0) { # this stock does not have the relationship
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

    # move object relationships
    #
    my $osrs = $schema->resultset("Stock::StockRelationship")->search( { object_id => $other_stock_id });
    while (my $row = $osrs->next()) {
	my $this_object_rel_rs = $schema->resultset("Stock::StockRelationship")->search( { object_id => $self->stock_id, subject_id => $row->subject_id(), type_id => $row->type_id() });

	if ($this_object_rel_rs->count() == 0) {
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


    # move stock_dbxref
    #
    my $sdrs = $schema->resultset("Stock::StockDbxref")->search( { stock_id => $other_stock_id });
    while (my $row = $sdrs->next()) {
	$row->stock_id($self->stock_id());
	$row->update();
	$stock_dbxref_count++;
    }

    # move sgn.pcr_exp_accession relationships
    #


    # move sgn.pcr_experiment relationships
    #



    # move stock_genotype relationships
    #


    my $phenome_schema = CXGN::Phenome::Schema->connect(
	sub { $self->schema()->storage()->dbh() }, { on_connect_do => [ 'SET search_path TO phenome, public, sgn'], limit_dialect => 'LimitOffset' }
	);

    # move phenome.stock_allele relationships
    #
    my $sars = $phenome_schema->resultset("StockAllele")->search( { stock_id => $other_stock_id });
    while (my $row = $sars->next()) {
	$row->stock_id($self->stock_id());
	$row->udate();
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

    if ($delete_other_stock) {
	my $row = $self->schema()->resultset("Stock::Stock")->find( { stock_id => $other_stock_id });
	$row->delete();
	$other_stock_deleted = 'YES';
    }


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
    Other stock deleted: $other_stock_deleted.
COUNTS

}

__PACKAGE__->meta->make_immutable;

##########
1;########
##########
