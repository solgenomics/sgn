
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;

use CXGN::Trial::Search;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $trial_search = CXGN::Trial::Search->new({
    bcs_schema=>$schema,
});
my $result = $trial_search->search();
#print STDERR Dumper $result;
is_deeply($result, [
          {
            'trial_type' => 'Clonal Evaluation',
            'folder_name' => undef,
            'location_id' => '23',
            'breeding_program_id' => 134,
            'folder_id' => undef,
            'design' => 'Alpha',
            'planting_date' => undef,
            'location_name' => 'test_location',
            'breeding_program_name' => 'test',
            'harvest_date' => undef,
            'description' => 'This trial was loaded into the fixture to test solgs.',
            'trial_id' => 139,
            'trial_name' => 'Kasese solgs trial',
            'year' => '2014'
          },
          {
            'location_name' => undef,
            'harvest_date' => undef,
            'breeding_program_name' => 'test',
            'description' => 'new_test_cross',
            'trial_id' => 135,
            'trial_name' => 'new_test_cross',
            'year' => undef,
            'folder_name' => undef,
            'trial_type' => undef,
            'location_id' => undef,
            'breeding_program_id' => 134,
            'folder_id' => undef,
            'design' => undef,
            'planting_date' => undef
          },
          {
            'location_name' => undef,
            'breeding_program_name' => undef,
            'harvest_date' => undef,
            'description' => 'selection_population',
            'trial_id' => 143,
            'trial_name' => 'selection_population',
            'year' => '2015',
            'trial_type' => undef,
            'folder_name' => undef,
            'location_id' => undef,
            'breeding_program_id' => undef,
            'folder_id' => undef,
            'design' => undef,
            'planting_date' => undef
          },
          {
            'year' => '2015',
            'trial_name' => 'test_genotyping_project',
            'description' => 'test_genotyping_project',
            'trial_id' => 140,
            'harvest_date' => undef,
            'breeding_program_name' => undef,
            'location_name' => undef,
            'planting_date' => undef,
            'design' => undef,
            'folder_id' => undef,
            'breeding_program_id' => undef,
            'location_id' => undef,
            'trial_type' => undef,
            'folder_name' => undef
          },
          {
            'year' => '2015',
            'trial_name' => 'test_population2',
            'harvest_date' => undef,
            'breeding_program_name' => undef,
            'location_name' => undef,
            'description' => 'test_population2',
            'trial_id' => 142,
            'folder_id' => undef,
            'design' => undef,
            'planting_date' => undef,
            'location_id' => undef,
            'trial_type' => undef,
            'folder_name' => undef,
            'breeding_program_id' => undef
          },
          {
            'trial_name' => 'test_t',
            'year' => '2016',
            'description' => 'test tets',
            'trial_id' => 144,
            'breeding_program_name' => 'test',
            'harvest_date' => undef,
            'location_name' => 'test_location',
            'planting_date' => undef,
            'folder_id' => undef,
            'design' => 'CRD',
            'breeding_program_id' => 134,
            'location_id' => '23',
            'folder_name' => undef,
            'trial_type' => undef
          },
          {
            'year' => '2014',
            'trial_name' => 'test_trial',
            'harvest_date' => undef,
            'breeding_program_name' => 'test',
            'location_name' => 'test_location',
            'description' => 'test trial',
            'trial_id' => 137,
            'design' => 'CRD',
            'folder_id' => undef,
            'planting_date' => undef,
            'location_id' => '23',
            'folder_name' => undef,
            'trial_type' => undef,
            'breeding_program_id' => 134
          },
          {
            'year' => '2014',
            'trial_name' => 'trial2 NaCRRI',
            'description' => 'another trial for solGS',
            'trial_id' => 141,
            'harvest_date' => undef,
            'breeding_program_name' => 'test',
            'location_name' => 'test_location',
            'planting_date' => undef,
            'folder_id' => undef,
            'design' => 'CRD',
            'breeding_program_id' => 134,
            'location_id' => '23',
            'trial_type' => undef,
            'folder_name' => undef
          }
        ], 'trial search test 1');

$trial_search = CXGN::Trial::Search->new({
    bcs_schema=>$schema,
    location_list=>['test_location'],
    program_list=>['test'],
});
$result = $trial_search->search();
#print STDERR Dumper $result;
is_deeply($result, [
          {
            'folder_name' => undef,
            'breeding_program_id' => 134,
            'year' => '2014',
            'location_id' => '23',
            'breeding_program_name' => 'test',
            'planting_date' => undef,
            'location_name' => 'test_location',
            'harvest_date' => undef,
            'trial_id' => 139,
            'description' => 'This trial was loaded into the fixture to test solgs.',
            'design' => 'Alpha',
            'trial_type' => 'Clonal Evaluation',
            'folder_id' => undef,
            'trial_name' => 'Kasese solgs trial'
          },
          {
            'folder_name' => undef,
            'location_id' => '23',
            'year' => '2016',
            'breeding_program_id' => 134,
            'planting_date' => undef,
            'breeding_program_name' => 'test',
            'harvest_date' => undef,
            'location_name' => 'test_location',
            'description' => 'test tets',
            'trial_id' => 144,
            'folder_id' => undef,
            'trial_type' => undef,
            'design' => 'CRD',
            'trial_name' => 'test_t'
          },
          {
            'trial_id' => 137,
            'description' => 'test trial',
            'trial_name' => 'test_trial',
            'design' => 'CRD',
            'trial_type' => undef,
            'folder_id' => undef,
            'breeding_program_id' => 134,
            'year' => '2014',
            'location_id' => '23',
            'folder_name' => undef,
            'location_name' => 'test_location',
            'harvest_date' => undef,
            'planting_date' => undef,
            'breeding_program_name' => 'test'
          },
          {
            'location_name' => 'test_location',
            'harvest_date' => undef,
            'planting_date' => undef,
            'breeding_program_name' => 'test',
            'breeding_program_id' => 134,
            'location_id' => '23',
            'year' => '2014',
            'folder_name' => undef,
            'trial_name' => 'trial2 NaCRRI',
            'trial_type' => undef,
            'design' => 'CRD',
            'folder_id' => undef,
            'trial_id' => 141,
            'description' => 'another trial for solGS'
          }
        ], 'trial search test 2');

done_testing();
