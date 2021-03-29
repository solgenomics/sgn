
#test all functions in CXGN::Stock::Seedlot

use strict;
use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Stock::Order;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();
my $people_schema = $f->people_schema();

my $order = CXGN::Stock::Order->new( { people_schema => $people_schema } );

$order->order_from_id(41);

$order->order_to_id(42);

$order->comments('big order $$$');

my $id = $order->store();

ok($id, 'has id '.$id);

done_testing();
