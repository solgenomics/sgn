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

=head2  get_stock

 Usage: $self-> get_stock($stock_type_id, $stock_organism_id)
 Desc:  check if the uniquename exists in the stock table
 Ret:   stock object_row
 Args: optional: stock_type_id (cvterm_id) , $stock_organism_id (organism_id)
 Side Effects: calls _get_stock_resultset, returns only one object row even if multiple stocks are found (would happen only if there are multiple stocks with the same uniquename of different letter case or different type_id or different organism_id)
 Example: $self->get_stock(undef, $manihot_esculenta_organism_id)

=cut

sub get_stock {
  my $self = shift;
  my $stock_type_id = shift;
  my $stock_organism_id = shift;
  my $stock_rs = $self->_get_stock_resultset($stock_type_id, $stock_organism_id);
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
    my $stock_ids;
    my $where_clause = '';
    print STDERR "StockOwner Start:".localtime."\n";
    if ($stock_ids){
        my $stock_id_sql = join ',', @$stock_ids;
        $where_clause = "WHERE stock_id IN ($stock_id_sql)";
    }
    my $schema = $self->get_schema();
    my $q = "SELECT stock_id, sp_person_id, username, first_name, last_name FROM sgn_people.sp_person JOIN phenome.stock_owner USING(sp_person_id) $where_clause GROUP BY (stock_id, sp_person_id, username, first_name, last_name) ORDER BY sp_person_id;";
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
  my $stock_type_id = shift;
  my $stock_organism_id = shift;
  my $schema = $self->get_schema();
  my $stock_name = $self->get_stock_name();
  my $search_hash = {
      'me.is_obsolete' => { '!=' => 't' },
      -or => [
          'lower(me.uniquename)' => { like => lc($stock_name) },
          -and => [
               'lower(type.name)'       => { like => '%synonym%' },
               'lower(stockprops.value)' => { like => lc($stock_name) },
              ],
         ],
  };
  if ($stock_type_id){
      $search_hash->{'me.type_id'} = $stock_type_id;
  }
  if ($stock_organism_id) {
      $search_hash->{'me.organism_id'} = $stock_organism_id;
  }
  my $stock_rs = $schema->resultset("Stock::Stock")
      ->search($search_hash,
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
	      'uniquename' => $stock_name,
	     },
	     {
	      join => { 'stockprops' => 'type'} ,
	      distinct => 1,
	     }
	    );
  return $stock_rs;
}

sub get_stock_synonyms {
	my $self = shift;
    my $search_type = shift; # 'stock_id' | 'uniquename' | 'any_name'
    my $stock_type = shift; # type of stock ex 'accession'
    my $to_get = shift; # array ref

	my $schema = $self->get_schema();

  my $stock_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,$stock_type,'stock_type')->cvterm_id;

	my $table_joins = {
		join => { 'stockprops' => 'type'},
		'+select' => ['stockprops.value','type.name'],
		'+as' => ['stockprop_value','cvterm_name']
		# join_type => 'FULL_OUTER'
 	};
	my $query = {
		'me.is_obsolete' => { '!=' => 't' },
    'me.type_id' => {'=' => $stock_type_id}
	};
    if ($search_type eq 'stock_id'){
		$query->{'me.stock_id'} = {-in=>$to_get};
  } elsif ($search_type eq 'uniquename'){
		$query->{'me.uniquename'} = {-in=>$to_get};
  } elsif ($search_type eq 'any_name'){
		$query->{'-or'} = [
			'me.uniquename' => {-in=>$to_get},
			-and => [
				'type.name' => 'stock_synonym',
				'stockprops.value' => {-in=>$to_get}
			]
		];
    } else {
		die;
	}
	my $stock_rs = $schema->resultset("Stock::Stock")
	  ->search($query,$table_joins);
    my $synonym_hash = {};
	while( my $row = $stock_rs->next) {
  	    my $uname = $row->uniquename;
		if (not defined $synonym_hash->{$uname}){
			$synonym_hash->{$uname} = [];
		}
    my $cvname = $row->get_column('cvterm_name');
		if ($cvname && $cvname eq 'stock_synonym'){
			push @{$synonym_hash->{$uname}}, $row->get_column('stockprop_value');
		}
  	}
	return $synonym_hash;
}

=head2 function get_cross_exact()

retrieves the stock row with cross stock type and with an exact match to the stock name

=cut

sub get_cross_exact {
    my $self = shift;
	my $schema = $self->get_schema();
	my $stock_name = $self->get_stock_name();
	my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,'cross','stock_type')->cvterm_id;

	my $stock_rs = $schema->resultset("Stock::Stock")->search({ 'me.is_obsolete' => { '!=' => 't' }, 'uniquename' => $stock_name, 'type_id' => $cross_type_id });
    my $stock;
    if ($stock_rs->count == 1) {
        $stock = $stock_rs->first;
    } else {
        return;
    }
    return $stock;
}


=head2 function get_accession_exact()

retrieves the stock row with accession stock type and with an exact match to the stock name

=cut

sub get_accession_exact {
    my $self = shift;
	my $schema = $self->get_schema();
	my $stock_name = $self->get_stock_name();
	my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,'accession','stock_type')->cvterm_id;

	my $stock_rs = $schema->resultset("Stock::Stock")->search({ 'me.is_obsolete' => { '!=' => 't' }, 'uniquename' => $stock_name, 'type_id' => $accession_type_id });
    my $stock;
    if ($stock_rs->count == 1) {
        $stock = $stock_rs->first;
    } else {
        return;
    }
    return $stock;
}

sub get_stock_variety {
    my $self = shift;
    my $schema = $self->get_schema();
    my $stock_name = $self->get_stock_name();
    my $variety_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'variety', 'stock_property')->cvterm_id();

    my $stock_rs = $schema->resultset("Stock::Stock")->find({uniquename => $stock_name});
    my $stock_id = $stock_rs->stock_id();

    my $stock_variety;
    my $variety_stockprop = $schema->resultset("Stock::Stockprop")->find({stock_id => $stock_id, type_id => $variety_type_id});
    if (defined $variety_stockprop) {
        $stock_variety = $variety_stockprop->value();
    }

    return $stock_variety;

}

=head2 function get_tracking_identifier_exact()

retrieves the stock row with tracking_identifier stock type and with an exact match to the stock name

=cut

sub get_tracking_identifier_exact {
    my $self = shift;
    my $schema = $self->get_schema();
    my $stock_name = $self->get_stock_name();
    my $tracking_identifier_type_id = SGN::Model::Cvterm->get_cvterm_row($schema,'tracking_identifier','stock_type')->cvterm_id;

    my $stock_rs = $schema->resultset("Stock::Stock")->search({ 'me.is_obsolete' => { '!=' => 't' }, 'uniquename' => $stock_name, 'type_id' => $tracking_identifier_type_id });
    my $stock;
    if ($stock_rs->count == 1) {
        $stock = $stock_rs->first;
    } else {
        return;
    }
    return $stock;
}


#######
1;
#######
