
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::BreederSearch;


my $f = SGN::Test::Fixture->new();

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });

my $criteria_list = [ 'years', 'locations' ];

my $dataref = { locations => { years => "'2014'" } };

my $queryref = { locations => { years => '0' } };

my $results = $bs->metadata_query($criteria_list, $dataref, $queryref);

is_deeply($results, { results => [ [ 23, 'test_location' ]] } );

$criteria_list = [ 'locations', 'years' ];

$dataref = { years => { locations => 23 } };

$queryref = { years => { locations => '0' } };

$results = $bs->metadata_query($criteria_list, $dataref, $queryref);

is_deeply($results, { results => [ [ 2014, 2014 ]] } );

$criteria_list = [ 'locations', 'years', 'trials' ];
$dataref = {};
$dataref = { projects => { locations => 23,
			years     => "'2014'",
	     }
};
$queryref = {'trials' => {'locations' => '0','years' => '0'}};

$results = $bs ->metadata_query($criteria_list, $dataref, $queryref);

is_deeply($results->{results}, [[139,'Kasese solgs trial'],[137,'test_trial'],[141,'trial2 NaCRRI']], "wizard project query");

$criteria_list = [
               'trials',
               'accessions',
               'plots'
             ];
$dataref = {
               'plots' => {
                          'trials' => '\'137\'',
                          'accessions' => '\'38840\',\'38841\''
                        }
             };
$queryref = {
               'plots' => {
                          'trials' => 0,
                          'accessions' => 0
                        }
             };
$results = $bs ->metadata_query($criteria_list, $dataref, $queryref);
is_deeply($results->{results}, [
                              [
                                38867,
                                'test_trial211'
                              ],
                              [
                                38869,
                                'test_trial213'
                              ],
                              [
                                38871,
                                'test_trial215'
                              ],
                              [
                                38861,
                                'test_trial25'
                              ],
                              [
                                38864,
                                'test_trial28'
                              ],
                              [
                                38865,
                                'test_trial29'
                              ]
                            ]
, "wizard union query");

$criteria_list = [
               'trials',
               'accessions',
               'plots'
             ];
$dataref = {
               'plots' => {
                          'trials' => '\'137\'',
                          'accessions' => '\'38840\',\'38841\''
                        }
             };
$queryref = {
               'plots' => {
                          'trials' => 0,
                          'accessions' => 1
                        }
             };
$results = $bs ->metadata_query($criteria_list, $dataref, $queryref);
is_deeply($results->{error}, '0 matches. No results to display', "wizard intersect query");

done_testing();
