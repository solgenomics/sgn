#test all functions in CXGN::BreedersToolbox::Projects

use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::BreedersToolbox::Projects;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

my $p = CXGN::BreedersToolbox::Projects->new({schema=>$schema});

my $trial_id = $schema->resultset('Project::Project')->find({name=>'test_trial'})->project_id();
ok($p->trial_exists($trial_id));

my $projects = $p->get_breeding_programs();
#print STDERR Dumper $projects;
is_deeply($projects, [
          [
            134,
            'test',
            'test'
          ]
        ], 'test get bps');

my $bp_project_id = $p->get_breeding_program_by_name('test');
ok($bp_project_id);

my ($field_trials, $cross_trials, $genotyping_trials) = $p->get_trials_by_breeding_program($bp_project_id->project_id);
my @sorted_field_trials = sort {$a->[0] cmp $b->[0]} @$field_trials;
print STDERR Dumper \@sorted_field_trials;
is_deeply(\@sorted_field_trials, [
          [
            '137',
            'test_trial',
            'test trial'
          ],
          [
            '139',
            'Kasese solgs trial',
            'This trial was loaded into the fixture to test solgs.'
          ],
          [
            '141',
            'trial2 NaCRRI',
            'another trial for solGS'
          ],
          [
            '144',
            'test_t',
            'test tets'
          ],
          [
            '165',
            'CASS_6Genotypes_Sampling_2015',
            'Copy of trial with postcomposed phenotypes from cassbase.'
          ]
        ], 'test get trials');
#print STDERR Dumper $cross_trials;
my @sorted_cross_trials = sort {$a->[0] cmp $b->[0]} @$cross_trials;
#print STDERR Dumper \@sorted_cross_trials;
is_deeply(\@sorted_cross_trials, [
          [
            '138',
            'test5',
            'test5'
          ],
          [
            '145',
            'cross_test1',
            'cross_test1'
          ],
          [
            '146',
            'cross_test4',
            'cross_test4'
          ],
          [
            '147',
            'cross_test5',
            'cross_test5'
          ],
          [
            '148',
            'cross_test6',
            'cross_test6'
          ],
          [
            '149',
            'cross_test2',
            'cross_test2'
          ],
          [
            '150',
            'cross_test3',
            'cross_test3'
          ],
          [
            '151',
            'TestCross1',
            'TestCross1'
          ],
          [
            '152',
            'TestCross2',
            'TestCross2'
          ],
          [
            '153',
            'TestCross3',
            'TestCross3'
          ],
          [
            '154',
            'TestCross4',
            'TestCross4'
          ],
          [
            '155',
            'TestCross5',
            'TestCross5'
          ],
          [
            '156',
            'TestCross6',
            'TestCross6'
          ],
          [
            '157',
            'TestCross7',
            'TestCross7'
          ],
          [
            '158',
            'TestCross8',
            'TestCross8'
          ],
          [
            '159',
            'TestCross9',
            'TestCross9'
          ],
          [
            '160',
            'TestCross10',
            'TestCross10'
          ],
          [
            '161',
            'TestCross11',
            'TestCross11'
          ],
          [
            '162',
            'TestCross12',
            'TestCross12'
          ],
          [
            '163',
            'TestCross13',
            'TestCross13'
          ],
          [
            '164',
            'TestCross14',
            'TestCross14'
          ]
        ], 'test get crosses');
#print STDERR Dumper $genotyping_trials;
is_deeply($genotyping_trials, undef, 'test get geno trials');

my $locations = $p->get_locations_by_breeding_program($bp_project_id->project_id);
print STDERR Dumper $locations;
is_deeply($locations,[
          [
            23,
            'test_location',
            5
          ]
        ], 'get locations by bp');

my $all_locations = $p->get_all_locations();
#print STDERR Dumper $all_locations;
is_deeply($all_locations,[
          [
            24,
            'Cornell Biotech'
          ],
          [
            23,
            'test_location'
          ]
        ], 'get all locations');

my $all_locations = $p->get_locations();
print STDERR Dumper $all_locations;
is_deeply($all_locations, [
          [
            23,
            'test_location',
            undef,
            undef,
            undef,
            5456
          ],
          [
            24,
            'Cornell Biotech',
            undef,
            undef,
            undef,
            0
          ]
        ], 'get all locations');

my @all_years = $p->get_all_years();
print STDERR Dumper \@all_years;
is_deeply(\@all_years, [
          '2017',
          '2016',
          '2015',
          '2014'
        ], 'get all years');

my $new_bp_error = $p->new_breeding_program('test_new_bp', 'test_new_bp_desc');
#print STDERR Dumper $new_bp_error;
ok(!$new_bp_error);

my $bp_projects = $p->get_breeding_program_with_trial($trial_id);
#print STDERR Dumper $bp_projects;
is_deeply($bp_projects, [
          [
            134,
            'test',
            'test'
          ]
        ], 'get bps');

my $gt_protocols = $p->get_gt_protocols();
#print STDERR Dumper $gt_protocols;
is_deeply($gt_protocols, [
          [
            1,
            'GBS ApeKI genotyping v4'
          ]
        ], 'get gt protocols');

my $trial_id = $schema->resultset('Project::Project')->find({name=>'test_new_bp'})->project_id();
ok($p->delete_breeding_program($trial_id));

done_testing;
