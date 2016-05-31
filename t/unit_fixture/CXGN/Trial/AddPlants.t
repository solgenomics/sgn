
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Trial::TrialLayout;
use CXGN::Trial;

my $f = SGN::Test::Fixture->new();

my $trial_id = 137;

my $tl = CXGN::Trial::TrialLayout->new({ schema => $f->bcs_schema(), trial_id => $trial_id });

my $d = $tl->get_design();

#print STDERR Dumper($d);

is_deeply($d, {
          '6' => {
                   'accession_id' => 38843,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession4',
                   'plant_ids' => [],
                   'plot_id' => 38862,
                   'plot_number' => '6',
                   'rep_number' => '2',
                   'plot_name' => 'test_trial26'
                 },
          '11' => {
                    'accession_id' => 38840,
                    'block_number' => '1',
                    'plant_names' => [],
                    'accession_name' => 'test_accession1',
                    'plant_ids' => [],
                    'plot_id' => 38867,
                    'plot_number' => '11',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial211'
                  },
          '3' => {
                   'accession_id' => 38842,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession3',
                   'plant_ids' => [],
                   'plot_id' => 38859,
                   'plot_number' => '3',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial23'
                 },
          '7' => {
                   'accession_id' => 38844,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession5',
                   'plant_ids' => [],
                   'plot_id' => 38863,
                   'plot_number' => '7',
                   'rep_number' => '2',
                   'plot_name' => 'test_trial27'
                 },
          '9' => {
                   'accession_id' => 38841,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession2',
                   'plant_ids' => [],
                   'plot_id' => 38865,
                   'plot_number' => '9',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial29'
                 },
          '12' => {
                    'accession_id' => 38844,
                    'block_number' => '1',
                    'plant_names' => [],
                    'accession_name' => 'test_accession5',
                    'plant_ids' => [],
                    'plot_id' => 38868,
                    'plot_number' => '12',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial212'
                  },
          '2' => {
                   'accession_id' => 38844,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession5',
                   'plant_ids' => [],
                   'plot_id' => 38858,
                   'plot_number' => '2',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial22'
                 },
          '15' => {
                    'accession_id' => 38841,
                    'block_number' => '1',
                    'plant_names' => [],
                    'accession_name' => 'test_accession2',
                    'plant_ids' => [],
                    'plot_id' => 38871,
                    'plot_number' => '15',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial215'
                  },
          '14' => {
                    'accession_id' => 38843,
                    'block_number' => '1',
                    'plant_names' => [],
                    'accession_name' => 'test_accession4',
                    'plant_ids' => [],
                    'plot_id' => 38870,
                    'plot_number' => '14',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial214'
                  },
          '8' => {
                   'accession_id' => 38840,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession1',
                   'plant_ids' => [],
                   'plot_id' => 38864,
                   'plot_number' => '8',
                   'rep_number' => '2',
                   'plot_name' => 'test_trial28'
                 },
          '1' => {
                   'accession_id' => 38843,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession4',
                   'plant_ids' => [],
                   'plot_id' => 38857,
                   'plot_number' => '1',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial21'
                 },
          '4' => {
                   'accession_id' => 38842,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession3',
                   'plant_ids' => [],
                   'plot_id' => 38860,
                   'plot_number' => '4',
                   'rep_number' => '2',
                   'plot_name' => 'test_trial24'
                 },
          '13' => {
                    'accession_id' => 38841,
                    'block_number' => '1',
                    'plant_names' => [],
                    'accession_name' => 'test_accession2',
                    'plant_ids' => [],
                    'plot_id' => 38869,
                    'plot_number' => '13',
                    'rep_number' => '2',
                    'plot_name' => 'test_trial213'
                  },
          '10' => {
                    'accession_id' => 38842,
                    'block_number' => '1',
                    'plant_names' => [],
                    'accession_name' => 'test_accession3',
                    'plant_ids' => [],
                    'plot_id' => 38866,
                    'plot_number' => '10',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial210'
                  },
          '5' => {
                   'accession_id' => 38840,
                   'block_number' => '1',
                   'plant_names' => [],
                   'accession_name' => 'test_accession1',
                   'plant_ids' => [],
                   'plot_id' => 38861,
                   'plot_number' => '5',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial25'
                 }
        }, 'check tl object prior to adding plants');


my $trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id });
$trial->create_plant_entities('2');

my $tl = CXGN::Trial::TrialLayout->new({ schema => $f->bcs_schema(), trial_id => $trial_id });
my $d = $tl->get_design();

#print STDERR Dumper($d);

is_deeply( $d, {
          '6' => {
                   'accession_id' => 38843,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial26_plant_1',
                                      'test_trial26_plant_2'
                                    ],
                   'accession_name' => 'test_accession4',
                   'plant_ids' => [
                                    41263,
                                    41264
                                  ],
                   'plot_id' => 38862,
                   'plot_number' => '6',
                   'rep_number' => '2',
                   'plot_name' => 'test_trial26'
                 },
          '11' => {
                    'accession_id' => 38840,
                    'block_number' => '1',
                    'plant_names' => [
                                       'test_trial211_plant_1',
                                       'test_trial211_plant_2'
                                     ],
                    'accession_name' => 'test_accession1',
                    'plant_ids' => [
                                     41265,
                                     41266
                                   ],
                    'plot_id' => 38867,
                    'plot_number' => '11',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial211'
                  },
          '3' => {
                   'accession_id' => 38842,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial23_plant_1',
                                      'test_trial23_plant_2'
                                    ],
                   'accession_name' => 'test_accession3',
                   'plant_ids' => [
                                    41267,
                                    41268
                                  ],
                   'plot_id' => 38859,
                   'plot_number' => '3',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial23'
                 },
          '7' => {
                   'accession_id' => 38844,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial27_plant_1',
                                      'test_trial27_plant_2'
                                    ],
                   'accession_name' => 'test_accession5',
                   'plant_ids' => [
                                    41269,
                                    41270
                                  ],
                   'plot_id' => 38863,
                   'plot_number' => '7',
                   'rep_number' => '2',
                   'plot_name' => 'test_trial27'
                 },
          '9' => {
                   'accession_id' => 38841,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial29_plant_1',
                                      'test_trial29_plant_2'
                                    ],
                   'accession_name' => 'test_accession2',
                   'plant_ids' => [
                                    41271,
                                    41272
                                  ],
                   'plot_id' => 38865,
                   'plot_number' => '9',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial29'
                 },
          '12' => {
                    'accession_id' => 38844,
                    'block_number' => '1',
                    'plant_names' => [
                                       'test_trial212_plant_1',
                                       'test_trial212_plant_2'
                                     ],
                    'accession_name' => 'test_accession5',
                    'plant_ids' => [
                                     41273,
                                     41274
                                   ],
                    'plot_id' => 38868,
                    'plot_number' => '12',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial212'
                  },
          '2' => {
                   'accession_id' => 38844,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial22_plant_1',
                                      'test_trial22_plant_2'
                                    ],
                   'accession_name' => 'test_accession5',
                   'plant_ids' => [
                                    41275,
                                    41276
                                  ],
                   'plot_id' => 38858,
                   'plot_number' => '2',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial22'
                 },
          '15' => {
                    'accession_id' => 38841,
                    'block_number' => '1',
                    'plant_names' => [
                                       'test_trial215_plant_1',
                                       'test_trial215_plant_2'
                                     ],
                    'accession_name' => 'test_accession2',
                    'plant_ids' => [
                                     41277,
                                     41278
                                   ],
                    'plot_id' => 38871,
                    'plot_number' => '15',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial215'
                  },
          '14' => {
                    'accession_id' => 38843,
                    'block_number' => '1',
                    'plant_names' => [
                                       'test_trial214_plant_1',
                                       'test_trial214_plant_2'
                                     ],
                    'accession_name' => 'test_accession4',
                    'plant_ids' => [
                                     41279,
                                     41280
                                   ],
                    'plot_id' => 38870,
                    'plot_number' => '14',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial214'
                  },
          '8' => {
                   'accession_id' => 38840,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial28_plant_1',
                                      'test_trial28_plant_2'
                                    ],
                   'accession_name' => 'test_accession1',
                   'plant_ids' => [
                                    41281,
                                    41282
                                  ],
                   'plot_id' => 38864,
                   'plot_number' => '8',
                   'rep_number' => '2',
                   'plot_name' => 'test_trial28'
                 },
          '1' => {
                   'accession_id' => 38843,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial21_plant_1',
                                      'test_trial21_plant_2'
                                    ],
                   'accession_name' => 'test_accession4',
                   'plant_ids' => [
                                    41283,
                                    41284
                                  ],
                   'plot_id' => 38857,
                   'plot_number' => '1',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial21'
                 },
          '4' => {
                   'accession_id' => 38842,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial24_plant_1',
                                      'test_trial24_plant_2'
                                    ],
                   'accession_name' => 'test_accession3',
                   'plant_ids' => [
                                    41285,
                                    41286
                                  ],
                   'plot_id' => 38860,
                   'plot_number' => '4',
                   'rep_number' => '2',
                   'plot_name' => 'test_trial24'
                 },
          '13' => {
                    'accession_id' => 38841,
                    'block_number' => '1',
                    'plant_names' => [
                                       'test_trial213_plant_1',
                                       'test_trial213_plant_2'
                                     ],
                    'accession_name' => 'test_accession2',
                    'plant_ids' => [
                                     41287,
                                     41288
                                   ],
                    'plot_id' => 38869,
                    'plot_number' => '13',
                    'rep_number' => '2',
                    'plot_name' => 'test_trial213'
                  },
          '10' => {
                    'accession_id' => 38842,
                    'block_number' => '1',
                    'plant_names' => [
                                       'test_trial210_plant_1',
                                       'test_trial210_plant_2'
                                     ],
                    'accession_name' => 'test_accession3',
                    'plant_ids' => [
                                     41289,
                                     41290
                                   ],
                    'plot_id' => 38866,
                    'plot_number' => '10',
                    'rep_number' => '3',
                    'plot_name' => 'test_trial210'
                  },
          '5' => {
                   'accession_id' => 38840,
                   'block_number' => '1',
                   'plant_names' => [
                                      'test_trial25_plant_1',
                                      'test_trial25_plant_2'
                                    ],
                   'accession_name' => 'test_accession1',
                   'plant_ids' => [
                                    41291,
                                    41292
                                  ],
                   'plot_id' => 38861,
                   'plot_number' => '5',
                   'rep_number' => '1',
                   'plot_name' => 'test_trial25'
                 }
        }, 'check tl object after adding plants');

done_testing();



