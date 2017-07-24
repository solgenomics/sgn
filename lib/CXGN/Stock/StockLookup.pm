package CXGN::Stock::StockLookup;

=head1 NAME

CXGN::Stock::StockLookup - a module to lookup stock names by unique name or synonym.

=head1 USAGE

 my $stock_lookup = CXGN::Stock::StockLookup->new({ schema => $schema} );


=head1 DESCRIPTION

Looks up stocks ("Stock::Stock") that have a match with the unique name or synonym to the searched name.  Provides a count of matching stocks when more than one stock is found.  Provides the Stock::Stock object when only a single stock matches.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use SGN::Model::Cvterm;

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);

=head2 predicate has_stock_name(), clearer clear_stock_name(), accessors stock_name()

functions to test, clear, set or get the stock name.

=cut

has 'stock_name' => (isa => 'Str', is => 'rw', predicate => 'has_stock_name', clearer => 'clear_stock_name');

=head2 function get_stock()

retrieves a stock row

=cut

sub get_stock {
  my $self = shift;
  my $stock_rs = $self->_get_stock_resultset();
  my $stock;
  if ($stock_rs->count > 0) {
    $stock = $stock_rs->first;
  } else {
    return;
  }
  return $stock;
}

=head2 function get_stock_exact()

retrieves the stock row with an exact match to the stock name or synonym

=cut

sub get_stock_exact {
  my $self = shift;
  my $stock_rs = $self->_get_stock_resultset_exact();
  my $stock;
  if ($stock_rs->count == 1) {
    $stock = $stock_rs->first;
  } else {
    return;
  }
  return $stock;
}

=head2 function get_matching_stock_count()

retrieves the number of stocks that match the name (or synonym)

=cut

sub get_matching_stock_count {
  my $self = shift;
  my $stock_name = $self->get_stock_name();
  my $stock_rs = $self->_get_stock_resultset();
  if (!$stock_rs) {
    return;
  }
  my $stock_match_count = $stock_rs->count;
  if (!$stock_match_count) {
    return 0;
  }
  if ($stock_match_count == 0) {
    return;
  }
  return $stock_match_count;
}

sub get_synonym_hash_lookup {
    my $self = shift;
    print STDERR "Synonym Start:".localtime."\n";
    my $schema = $self->get_schema();
    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
    my $q = "SELECT stock.uniquename, stockprop.value FROM stock JOIN stockprop USING(stock_id) WHERE stock.type_id=$accession_type_id AND stockprop.type_id=$synonym_type_id ORDER BY stockprop.value;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %result;
    while (my ($uniquename, $synonym) = $h->fetchrow_array()) {
        push @{$result{$uniquename}}, $synonym;
    }
    print STDERR "Synonym End:".localtime."\n";
    return \%result;
}

sub get_owner_hash_lookup {
    my $self = shift;
    print STDERR "StockOwner Start:".localtime."\n";
    my $schema = $self->get_schema();
    my $q = "SELECT stock_id, sp_person_id, username, first_name, last_name FROM sgn_people.sp_person JOIN phenome.stock_owner USING(sp_person_id) ORDER BY sp_person_id;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %result;
    while (my ($stock_id, $sp_person_id, $username, $first_name, $last_name) = $h->fetchrow_array()) {
        push @{$result{$stock_id}}, [$sp_person_id, $username, $first_name, $last_name];
    }
    print STDERR "StockOwner End:".localtime."\n";
    return \%result;
}

sub get_organization_hash_lookup {
    my $self = shift;
    print STDERR "StockOrg Start:".localtime."\n";
    my $schema = $self->get_schema();
	my $organization_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'organization', 'stock_property')->cvterm_id();
    my $q = "SELECT stock_id, value FROM stockprop WHERE type_id=$organization_type_id ORDER BY value;";
    my $h = $schema->storage->dbh()->prepare($q);
    $h->execute();
    my %result;
    while (my ($stock_id, $organization) = $h->fetchrow_array()) {
        push @{$result{$stock_id}}, $organization;
    }
    print STDERR "StockOrg End:".localtime."\n";
    return \%result;
}

sub _get_stock_resultset {
  my $self = shift;
  my $schema = $self->get_schema();
  my $stock_name = $self->get_stock_name();
  my $stock_rs = $schema->resultset("Stock::Stock")
      ->search({ 'me.is_obsolete' => { '!=' => 't' },
	      -or => [
		      'lower(me.uniquename)' => { like => lc($stock_name) },

		      -and => [
			       'lower(type.name)'       => { like => '%synonym%' },
			       'lower(stockprops.value)' => { like => lc($stock_name) },
			      ],
		     ],
	     },
	     {
	      join => { 'stockprops' => 'type'} ,
	      distinct => 1
	     }
	    );
  return $stock_rs;
}

sub _get_stock_resultset_exact {
  my $self = shift;
  my $schema = $self->get_schema();
  my $stock_name = $self->get_stock_name();
  my $stock_rs = $schema->resultset("Stock::Stock")
    ->search({ 'me.is_obsolete' => { '!=' => 't' },
	      'lower(uniquename)' => lc($stock_name),
	     },
	     {
	      join => { 'stockprops' => 'type'} ,
	      distinct => 1,
	     }
	    );
  return $stock_rs;
}

#######
1;
#######
