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

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);
has 'stock_name' => (isa => 'Str', is => 'rw', predicate => 'has_stock_name', clearer => 'clear_stock_name');

sub get_stock {
  my $self = shift;
  my $stock_rs = $self->_get_stock_resultset();
  my $stock;
  if ($stock_rs->count == 1) {
    $stock = $stock_rs->first;
  } else {
    return;
  }
  return $stock;
}

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
