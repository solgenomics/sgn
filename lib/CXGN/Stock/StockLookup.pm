package CXGN::Stock::StockLookup;

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
    ->search({
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


#######
1;
#######
