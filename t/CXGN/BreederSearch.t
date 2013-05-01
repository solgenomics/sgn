
use strict;
use Test::More;
use CXGN::DB::Connection;
use CXGN::BreederSearch;

my $dbh = CXGN::DB::Connection->new();

my $bs = CXGN::BreederSearch->new(dbh=>$dbh);


my $criteria_list = [ 'year', 'location' ];

my $dataref = { location => { year=> "'2006/07'" } };

my $results = $bs->get_intersect($criteria_list, $dataref);

foreach my $r (@$results) { 
    print join ", ", @$r;
    print "\n";
}

$criteria_list = [ 'location', 'year' ];

$dataref = { year => { location => 3 } };

$results = $bs->get_intersect($criteria_list, $dataref);

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

$results = $bs ->get_intersect($criteria_list, $dataref);

foreach my $r (@$results) { 
    print join ", ", @$r;
    print "\n";
}




