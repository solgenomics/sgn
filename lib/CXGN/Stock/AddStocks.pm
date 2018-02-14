package CXGN::Stock::AddStocks;

=head1 NAME

########## DEPRECATED ####################
# Please use CXGN::Stock::Accession->store. This new object inherits store procedure from CXGN::Stock, and adds complete passport info in store.
##########################################

CXGN::Stock::AddStocks - a module to add a list of stocks.

=head1 USAGE

 my $stock_add = CXGN::Stock::AddStocks->new({ schema => $schema, phenome_schema => $phenome_schema, dbh => $dbh, stocks => \@stocks, species => $species_name, owner_name => $owner_name } );
 my $validated_stocks = $stock_add->validate_stocks(); #is true when none of the stock names in the array exist in the database.
 my $validated_owner = $stock_add->validate_owner(); #is true when the owner exists in the database.
 my $validated_organism = $stock_add->validate_organism(); #is true when the organism name exists in the database.
 $stock_add->add_accessions();

=head1 DESCRIPTION

Adds an array of stocks. The stock names must not already exist in the database, and the verify function does this check.   This module is intended to be used in independent loading scripts and interactive dialogs.  Stock types "accession" and "plot" are supported by the methods add_accessions() and add_plots().

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use CXGN::People::Person;
use SGN::Model::Cvterm;


has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		 predicate => 'has_schema',
		);
has 'stocks' => (isa => 'ArrayRef', is => 'rw', predicate => 'has_stocks');
has 'species' => (isa => 'Str', is => 'rw', predicate => 'has_species');
has 'owner_name' => (isa => 'Str', is => 'rw', predicate => 'has_owner_name',required => 1,);
has 'organization_name' => (isa => 'Str', is => 'rw', predicate => 'has_organization_name',required => 0);
has 'population_name' => (isa => 'Str', is => 'rw', predicate => 'has_population_name');
has 'dbh' => (is  => 'rw',predicate => 'has_dbh', required => 1,);
has 'phenome_schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 predicate => 'has_phenome_schema',
		 required => 1,
		);

sub add_accessions {
  my $self = shift;
  my $added = $self->_add_stocks('accession');
  return $added;
}

sub add_plots {
  my $self = shift;
  my $added = $self->_add_stocks('plot');
  return $added;
}

#### Jeremy Edwards needs the ability to create accession groups
sub add_population {
  my $self = shift;
  my $added = $self->_add_stocks('population');
  return $added;
}
####

sub _add_stocks {
  my $self = shift;
  my $stock_type = shift;
  if (!$self->validate_stocks()) {
    return;
  }
  my $schema = $self->get_schema();
  my $species = $self->get_species();
  my $stocks_rs = $self->get_stocks();
  my @stocks = @$stocks_rs;
  my @added_stock_ids;
  my @added_stocks;
  my $phenome_schema = $self->get_phenome_schema();

  my $organism = $schema->resultset("Organism::Organism")
    ->find({
	    species => $species,
	   } );
  my $organism_id = $organism->organism_id();

  #lookup user by name
  my $owner_name = $self->get_owner_name();;
  my $dbh = $self->get_dbh();
  my $owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $owner_name); #add person id as an option.

  my $coderef = sub {

    my $stock_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, $stock_type,'stock_type');

    my $population_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'population','stock_type');
    
    my $population_member_cvterm =  SGN::Model::Cvterm->get_cvterm_row($schema, 'member_of','stock_relationship');

    #### assign accessions to populations
    my $population;
    if ($self->has_population_name()) {
        $population = $schema->resultset("Stock::Stock")
            ->find_or_create({
                uniquename => $self->get_population_name(),
                name => $self->get_population_name(),
                organism_id => $organism_id,
                type_id => $population_cvterm->cvterm_id(),
                   });
        if (!$population){
            print STDERR "Could not find population $population\n";
            return;
        }
    }
    ####

    foreach my $stock_name (@stocks) {
      my $stock = $schema->resultset("Stock::Stock")
	->create({
		  organism_id => $organism_id,
		  name       => $stock_name,
		  uniquename => $stock_name,
		  type_id     => $stock_cvterm->cvterm_id,
		 } );
      if ($population) {
          $stock->find_or_create_related('stock_relationship_objects', {
	      type_id => $population_member_cvterm->cvterm_id(),
	      object_id => $population->stock_id(),
	      subject_id => $stock->stock_id(),
					 } );
      }
	  if ($self->has_organization_name && $self->get_organization_name){
		  my $org_stockprop = SGN::Model::Cvterm->get_cvterm_row($schema, 'organization', 'stock_property')->name();
		  my $organization = $stock->create_stockprops({ $org_stockprop => $self->get_organization_name});
	  }
      push (@added_stock_ids,  $stock->stock_id());
      push @added_stocks, [$stock->stock_id, $stock_name];
    }
  };

  my $transaction_error;
  try {
    $schema->txn_do($coderef);
  } catch {
    $transaction_error =  $_;
  };
  if ($transaction_error) {
    print STDERR "Transaction error storing stocks: $transaction_error\n";
    return;
  }

  foreach my $stock_id (@added_stock_ids) {
    #add the owner for this stock
    $phenome_schema->resultset("StockOwner")
      ->find_or_create({
			stock_id     => $stock_id,
			sp_person_id =>  $owner_sp_person_id,
		       });
  }

  return \@added_stocks;
}

sub validate_stocks {
  my $self = shift;
  if (!$self->has_schema() || !$self->has_species() || !$self->has_stocks()) {
    return;
  }
  my $schema = $self->get_schema();
  my $species = $self->get_species();
  my $stocks_rs = $self->get_stocks();
  my @stocks = @$stocks_rs;

  my $name_conflicts = 0;
  foreach my $stock_name (@stocks) {
    my $stock_search = $schema->resultset("Stock::Stock")
      ->search({
		uniquename => $stock_name,
	       } );
    if ($stock_search->first()) {
      $name_conflicts++;
      print STDERR "Stock name conflict for: $stock_name\n";
    }
  }

  if ($name_conflicts > 0) {
    print STDERR "There were $name_conflicts conflict(s)\n";
    return;
  }

  return 1;
}

sub validate_organism {
  my $self = shift;
  if (!$self->has_schema() || !$self->has_species() || !$self->has_stocks()) {
    return;
  }
  my $schema = $self->get_schema();
  my $species = $self->get_species();
  my $organism = $schema->resultset("Organism::Organism")
    ->find({
	    species => $species,
	   } );
  if ($organism->organism_id()) {
      return 1;
  }
  return;
}

sub validate_owner {
  my $self = shift;
  if (!$self->has_schema() || !$self->has_species() || !$self->has_stocks()) {
    return;
  }
  my $schema = $self->get_schema();
  my $phenome_schema = $self->get_phenome_schema();
  my $owner_name = $self->get_owner_name();;
  my $dbh = $self->get_dbh();
  my $owner_sp_person_id = CXGN::People::Person->get_person_by_username($dbh, $owner_name);
  my $owner_search = $phenome_schema->resultset("StockOwner")
    ->find({
	sp_person_id =>  $owner_sp_person_id,
	   });
  if ($owner_search) {
      return 1;
  }
  return;
}

####  Check that accession group exists
sub validate_population {
  my $self = shift;
  if (!$self->has_schema() || !$self->has_species() || !$self->has_stocks()) {
    return;
  }
  my $schema = $self->get_schema();
  my $population_cvterm = SGN::Model::Cvterm->get_cvterm_row($schema, 'population',  'stock_type');
  my $population_search = $schema->resultset("Stock::Stock")
      ->search({
	  uniquename => $self->get_population_name(),
	  type_id => $population_cvterm->cvterm_id(),
	       } );
    if ($population_search->first()) {
	return 1;
    }
  return;
}


#######
1;
#######
