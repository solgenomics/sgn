
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
use Spreadsheet::Read;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'userDisplayName'}, 'Jane Doe');

my $trial_id = 137;
my $data_level = 'plots';
my $selected_columns = encode_json {'plot_name'=>1,'block_number'=>1,'plot_number'=>1,'rep_number'=>1,'row_number'=>1,'col_number'=>1,'accession_name'=>1,'is_a_control'=>1,'pedigree'=>1,'location_name'=>1,'trial_name'=>1,'year'=>1,'synonyms'=>1,'tier'=>1,'seedlot_name'=>1,'seed_transaction_operator'=>1,'num_seed_per_plot'=>1};
my $trait_list = 13;

$mech->post_ok('http://localhost:3010/ajax/fieldbook/create', ['trial_id'=>$trial_id, 'data_level'=>$data_level, 'selected_columns'=>$selected_columns, 'trait_list'=>$trait_list] );
$response = decode_json $mech->content;
print STDERR Dumper $response;
my $file_name = $response->{file};

my $contents = ReadData ($file_name);
#print STDERR Dumper $contents;

my $cells = $contents->[1]->{cell};
#print STDERR Dumper $cells;
is_deeply($cells, [
                        [],
                        [
                          undef,
                          'plot_name',
                          'test_trial21',
                          'test_trial22',
                          'test_trial23',
                          'test_trial24',
                          'test_trial25',
                          'test_trial26',
                          'test_trial27',
                          'test_trial28',
                          'test_trial29',
                          'test_trial210',
                          'test_trial211',
                          'test_trial212',
                          'test_trial213',
                          'test_trial214',
                          'test_trial215'
                        ],
                        [
                          undef,
                          'block_number',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1',
                          '1'
                        ],
                        [
                          undef,
                          'plot_number',
                          '1',
                          '2',
                          '3',
                          '4',
                          '5',
                          '6',
                          '7',
                          '8',
                          '9',
                          '10',
                          '11',
                          '12',
                          '13',
                          '14',
                          '15'
                        ],
                        [
                          undef,
                          'rep_number',
                          '1',
                          '1',
                          '1',
                          '2',
                          '1',
                          '2',
                          '2',
                          '2',
                          '1',
                          '3',
                          '3',
                          '3',
                          '2',
                          '3',
                          '3'
                        ],
                        [
                          undef,
                          'row_number'
                        ],
                        [
                          undef,
                          'col_number'
                        ],
                        [
                          undef,
                          'accession_name',
                          'test_accession4',
                          'test_accession5',
                          'test_accession3',
                          'test_accession3',
                          'test_accession1',
                          'test_accession4',
                          'test_accession5',
                          'test_accession1',
                          'test_accession2',
                          'test_accession3',
                          'test_accession1',
                          'test_accession5',
                          'test_accession2',
                          'test_accession4',
                          'test_accession2'
                        ],
                        [
                          undef,
                          'is_a_control'
                        ],
                        [
                          undef,
                          'pedigree',
                          'test_accession1/test_accession2',
                          'test_accession3/NA',
                          'NA/NA',
                          'NA/NA',
                          'NA/NA',
                          'test_accession1/test_accession2',
                          'test_accession3/NA',
                          'NA/NA',
                          'NA/NA',
                          'NA/NA',
                          'NA/NA',
                          'test_accession3/NA',
                          'NA/NA',
                          'test_accession1/test_accession2',
                          'NA/NA'
                        ],
                        [
                          undef,
                          'location_name',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location',
                          'test_location'
                        ],
                        [
                          undef,
                          'trial_name',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial',
                          'test_trial'
                        ],
                        [
                          undef,
                          'year',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014',
                          '2014'
                        ],
                        [
                          undef,
                          'synonyms',
                          undef,
                          undef,
                          'test_accession3_synonym1',
                          'test_accession3_synonym1',
                          'test_accession1_synonym1',
                          undef,
                          undef,
                          'test_accession1_synonym1',
                          'test_accession2_synonym1,test_accession2_synonym2',
                          'test_accession3_synonym1',
                          'test_accession1_synonym1',
                          undef,
                          'test_accession2_synonym1,test_accession2_synonym2',
                          undef,
                          'test_accession2_synonym1,test_accession2_synonym2'
                        ],
                        [
                          undef,
                          'tier',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/',
                          '/'
                        ],
                        [
                            undef,
                            'seedlot_name'
                        ],
                        [
                            undef,
                            'seed_transaction_operator'
                        ],
                        [
                            undef,
                            'num_seed_per_plot'
                        ],
                        [
                          undef,
                          'CO_334:0000008'
                        ],
                        [
                          undef,
                          'CO_334:0000009'
                        ],
                        [
                          undef,
                          'CO_334:0000010'
                        ],
                        [
                          undef,
                          'CO_334:0000011'
                        ],
                        [
                          undef,
                          'CO_334:0000012'
                        ],
                        [
                          undef,
                          'CO_334:0000013'
                        ],
                        [
                          undef,
                          'CO_334:0000014'
                        ],
                        [
                          undef,
                          'CO_334:0000015'
                        ],
                        [
                          undef,
                          'CO_334:0000016'
                        ],
                        [
                          undef,
                          'CO_334:0000017'
                        ]
                      ], 'test fieldbook ajax file contents');

done_testing;
