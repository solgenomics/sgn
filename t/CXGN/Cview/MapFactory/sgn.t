
use strict;

use Test::More;
use CXGN::DB::Connection;

use_ok('CXGN::Cview::MapFactory');

my %maps = ( agp => "CXGN::Cview::Map::SGN::AGP",
	     itag => "CXGN::Cview::Map::SGN::ITAG",
	      9 => "CXGN::Cview::Map::SGN::Genetic",
	     p9 => "CXGN::Cview::Map::SGN::Physical",
    );

my $dbh = CXGN::DB::Connection->new();

my $mf = CXGN::Cview::MapFactory->new($dbh);

foreach my $k (keys %maps) { 
    #print STDERR "testing $k...\n";
    my $map = $mf->create( {map_id=>$k});

    if( $map ) {
        is(ref($map), $maps{$k}, "map type test");
        is(scalar($map->get_chromosome_names()), 12, "chromosome count test");
    }
}


done_testing;
