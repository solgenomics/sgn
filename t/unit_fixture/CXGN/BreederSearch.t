
use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::BreederSearch;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });

my $criteria_list = [
               'years'
             ];
my $dataref = {};
my $queryref = {};

my $results = $bs->metadata_query($criteria_list, $dataref, $queryref);
print STDERR Dumper $results;
is_deeply($results, {
               'results' => [
                              [
                                '2014',
                                '2014'
                              ],
                              [
                                '2015',
                                '2015'
                              ],
                              [
                                '2016',
                                '2016'
                              ],
                              [
                                '2017',
                                '2017'
                              ],

                            ]
             }, 'wizard one category query');

$criteria_list = [
               'years',
               'locations'
             ];
$dataref = {
               'locations' => {
                              'years' => '\'2014\''
                            }
             };
$queryref = {
               'locations' => {
                              'years' => 0
                            }
             };

$results = $bs->metadata_query($criteria_list, $dataref, $queryref);
is_deeply($results, {
               'results' => [
                              [
                                23,
                                'test_location'
                              ]
                            ]
             }, "wizard two category query" );

$criteria_list = [
               'years',
               'locations',
               'trials'
             ];
$dataref = {
               'trials' => {
                           'locations' => '\'23\'',
                           'years' => '\'2014\''
                         }
             };
$queryref = {
               'trials' => {
                           'locations' => 0,
                           'years' => 0
                         }
             };
$results = $bs ->metadata_query($criteria_list, $dataref, $queryref);
is_deeply($results, {
               'results' => [
                              [
                                139,
                                'Kasese solgs trial'
                              ],
                              [
                                137,
                                'test_trial'
                              ],
                              [
                                141,
                                'trial2 NaCRRI'
                              ]
                            ]
             }, "wizard three category query");

$criteria_list = [
               'years',
               'locations',
               'trials',
               'genotyping_protocols'
             ];
$dataref = {
               'genotyping_protocols' => {
                                         'trials' => '\'139\'',
                                         'locations' => '\'23\'',
                                         'years' => '\'2014\''
                                       }
             };
$queryref = {
               'genotyping_protocols' => {
                                         'trials' => 0,
                                         'locations' => 0,
                                         'years' => 0
                                       }
             };
$results = $bs ->metadata_query($criteria_list, $dataref, $queryref);
is_deeply($results, {
               'results' => [
                              [
                                1,
                                'GBS ApeKI genotyping v4'
                              ]
                            ]
             }, "wizard four category query");

$criteria_list = [
               'breeding_programs',
               'trials',
               'traits'
             ];
$dataref = {
               'traits' => {
                           'trials' => '\'139\',\'141\'',
                           'breeding_programs' => '\'134\''
                         }
             };
$queryref = {
               'traits' => {
                           'trials' => 1,
                           'breeding_programs' => 0
                         }
             };
$results = $bs ->metadata_query($criteria_list, $dataref, $queryref);
is_deeply($results, {
               'results' => [
                              [
                                70741,
                                'dry matter content percentage|CO_334:0000092'
                              ],
                              [
                                70666,
                                'fresh root weight|CO_334:0000012'
                              ],
                              [
                                70773,
                                'fresh shoot weight measurement in kg|CO_334:0000016'
                              ]
                            ]
             }, "wizard intersect query");

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
is_deeply($results, {
               'results' => []
             }, "wizard 0 results error query");

done_testing();
