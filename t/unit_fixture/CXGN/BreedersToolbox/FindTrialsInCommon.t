#This script should test all functions in CXGN::Trial, CXGN::Trial::TrialLayout, CXGN::Trial::TrialDesign, CXGN::Trial::TrialCreate

use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::BreederSearch;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

my $bs = CXGN::BreederSearch->new( { dbh=> $f->dbh() });

my $criteria_list = [
               'accessions',
               'trials'
             ];
my $dataref = {
               'trials' => {
                             'accessions' => '\'38878\',\'38879\',\'38880\''
                           }
             };
my $queryref = {
               'trials' => {
                             'accessions' => 1
                           }
             };

my $results = $bs->metadata_query($criteria_list, $dataref, $queryref);
#print STDERR Dumper $results;
is_deeply($results, {
               'results' => [
                              [
                                139,
                                'Kasese solgs trial'
                              ],
                              [
                                144,
                                'test_t'
                              ],
                              [
                                141,
                                'trial2 NaCRRI'
                              ]
                            ]
             }, 'trials in common query');

done_testing();
