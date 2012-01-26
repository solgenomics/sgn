
use strict;

use Test::More qw | no_plan |;

use lib 't/lib';
use SGN::Test::WWW::Mechanize;

use_ok('CXGN::Cview::Map::SGN::Genetic');

my $m = SGN::Test::WWW::Mechanize->new();

my $dbh = $m->context->dbc->dbh();

my $map = CXGN::Cview::Map::SGN::Genetic->new($dbh, 53);

my @chr = ();

foreach my $i (1..12) { 
    $chr[$i] = $map->get_chromosome($i);
}

foreach my $i (1..12) {  
    isnt($chr[$i]->get_markers(), undef, "marker test");
    is($chr[$i]->get_caption(), $i, "marker caption test");
    is($chr[$i]->get_name(), $i, "marker name test");
}
