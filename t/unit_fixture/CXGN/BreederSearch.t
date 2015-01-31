
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::BreederSearch;


my $f = SGN::Test::Fixture->new();

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });

my $criteria_list = [ 'year', 'location' ];

my $dataref = { location => { year=> "'2006/07'" } };

my $results = $bs->get_intersect($criteria_list, $dataref, "CO");

foreach my $r (@$results) { 
    print join ", ", @$r;
    print "\n";
}

$criteria_list = [ 'location', 'year' ];

$dataref = { year => { location => 3 } };

$results = $bs->get_intersect($criteria_list, $dataref, "CO");

foreach my $r (@$results) { 
    print join ", ", @$r;
    print "\n";
}

$criteria_list = [ 'location', 'year', 'project' ];
$dataref = {};
$dataref = { project => { location => 3, 
			year     => "'2006/07'",
	     }
};

$results = $bs ->get_intersect($criteria_list, $dataref, "CO");

foreach my $r (@$results) { 
    print join ", ", @$r;
    print "\n";
}




