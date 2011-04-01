use strict;
use warnings;
use Test::More;

use CXGN::Marker::Search;

use lib 't/lib';
use SGN::Test 'with_test_level';

with_test_level( local => sub {
    require SGN::Context;
    my $dbh = SGN::Context->new->dbc->dbh;

for ( 0..10 ) { # test a few times

  my $msearch = CXGN::Marker::Search->new($dbh);
  $msearch->must_be_mapped();
  $msearch->has_subscript();
  $msearch->random();
  #$msearch->marker_id(518);
  $msearch->perform_search();
  #diag("search finished, creating locations\n");
  my ($loc) = $msearch->fetch_location_markers();
  #diag("finished creating locations\n");

  isa_ok($loc, 'CXGN::Marker::LocMarker');

#  use Data::Dumper;
#  diag(Dumper $loc->{loc});

  my $loc_id = $loc->location_id();
  ok($loc_id, "loc_id is $loc_id");

  my $chr = $loc->chr();
  cmp_ok($chr, '>', 0, "chromosome = $chr");

  my $pos = $loc->position();
  cmp_ok($pos, '>=', 0 , "position = $pos");

  my $sub = $loc->subscript();
  like($sub, qr/^[ABC]$/i, "subscript = $sub");

  my $conf = $loc->confidence();
  like($conf, qr/I|LOD|uncalculated/, "confidence = $conf");

  my $mv = $loc->map_version();
  cmp_ok($mv, '>', 0, "map version = $mv");

  my $map = $loc->map_id();
  cmp_ok($map, '>', 0, "map_id = $map");

}
});

done_testing;
