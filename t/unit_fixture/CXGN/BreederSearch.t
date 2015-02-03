
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::BreederSearch;


my $f = SGN::Test::Fixture->new();

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });

my $criteria_list = [ 'years', 'locations' ];

my $dataref = { locations => { years=> "'2014'" } };

my $results = $bs->get_intersect($criteria_list, $dataref, "CO");

is_deeply($results, { results => [ [ 23, 'test_location' ]] } );

$criteria_list = [ 'locations', 'years' ];

$dataref = { years => { locations => 23 } };

$results = $bs->get_intersect($criteria_list, $dataref, "CO");

is_deeply($results, { results => [ [ 2014, 2014 ]] } );

$criteria_list = [ 'locations', 'years', 'projects' ];
$dataref = {};
$dataref = { projects => { locations => 23, 
			years     => "'2014'",
	     }
};

$results = $bs ->get_intersect($criteria_list, $dataref, "CO");

is_deeply($results, { results => [ [ 137, 'test_trial' ] ]}, "wizard project query");


done_testing();


