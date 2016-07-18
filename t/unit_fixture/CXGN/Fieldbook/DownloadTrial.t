
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::Download;
use Spreadsheet::WriteExcel;
use Spreadsheet::Read;
use CXGN::Fieldbook::DownloadTrial;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $metadata_schema = $f->metadata_schema;
my $phenome_schema = $f->phenome_schema;

my $trial_id = $schema->resultset("Project::Project")->find({ name => 'test_trial'})->project_id();

my $tempfile = "/tmp/test_create_trial_fieldbook.xls";

my $create_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
    bcs_schema => $schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $trial_id,
    tempfile => $tempfile,
    archive_path => $f->config->{archive_path},
    user_id => 41,
    user_name => "janedoe",
    data_level => 'plots',
});

my $create_fieldbook_return = $create_fieldbook->download();
ok($create_fieldbook_return, "check that download trial fieldbook returns something.");

my @contents = ReadData ($create_fieldbook_return->{'file'});

#print STDERR Dumper @contents->[0]->[0];
is_deeply(@contents->[0]->[0], {
          'error' => undef,
          'sheet' => {
                       'Sheet1' => 1
                     },
          'sheets' => 1,
          'version' => '0.65',
          'type' => 'xls',
          'parser' => 'Spreadsheet::ParseExcel'
      }, 'check type of file that was created.');

my $columns = @contents->[0]->[1]->{'cell'};
#print STDERR Dumper scalar(@$columns);
ok(scalar(@$columns) == 7, "check number of col in created file.");

#print STDERR Dumper $columns;

is_deeply($columns->[1], [
    undef,
    'plot_id',
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
], "check contents of first col.");

is_deeply($columns->[2], [
    undef,
    'range',
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
], "check contents of second col.");
    
is_deeply($columns->[3], [
    undef,
    'plot',
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
], "check contents of third col.");
      
is_deeply($columns->[4], [
    undef,
    'rep',
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
], "check contents of fourth col.");
        
is_deeply($columns->[5], [
    undef,
    'accession',
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
], "check contents of fifth col.");

is_deeply($columns->[6], [
    undef,
    'is_a_control'
], "check contents of sixth col.");


my $trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id });
if (!$trial->has_plant_entries) {
    $trial->create_plant_entities('2');
}

my $tempfile = "/tmp/test_create_trial_fieldbook_plants.xls";

my $create_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
    bcs_schema => $schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $trial_id,
    tempfile => $tempfile,
    archive_path => $f->config->{archive_path},
    user_id => 41,
    user_name => "janedoe",
    data_level => 'plants',
});

my $create_fieldbook_return = $create_fieldbook->download();
ok($create_fieldbook_return, "check that download trial fieldbook returns something.");

my @contents = ReadData ($create_fieldbook_return->{'file'});

#print STDERR Dumper @contents->[0]->[0];
is_deeply(@contents->[0]->[0], {
          'parser' => 'Spreadsheet::ParseExcel',
          'sheets' => 1,
          'sheet' => {
                       'Sheet1' => 1
                     },
          'type' => 'xls',
          'version' => '0.65',
          'error' => undef
      }, "check fieldbook plant file");

my $columns = @contents->[0]->[1]->{'cell'};
#print STDERR Dumper scalar(@$columns);
ok(scalar(@$columns) == 8, "check number of col in created file.");

#print STDERR Dumper $columns;

is_deeply($columns->[1], [
            undef,
            'plot_id',
            'test_trial21_plant_1',
            'test_trial21_plant_2',
            'test_trial22_plant_1',
            'test_trial22_plant_2',
            'test_trial23_plant_1',
            'test_trial23_plant_2',
            'test_trial24_plant_1',
            'test_trial24_plant_2',
            'test_trial25_plant_1',
            'test_trial25_plant_2',
            'test_trial26_plant_1',
            'test_trial26_plant_2',
            'test_trial27_plant_1',
            'test_trial27_plant_2',
            'test_trial28_plant_1',
            'test_trial28_plant_2',
            'test_trial29_plant_1',
            'test_trial29_plant_2',
            'test_trial210_plant_1',
            'test_trial210_plant_2',
            'test_trial211_plant_1',
            'test_trial211_plant_2',
            'test_trial212_plant_1',
            'test_trial212_plant_2',
            'test_trial213_plant_1',
            'test_trial213_plant_2',
            'test_trial214_plant_1',
            'test_trial214_plant_2',
            'test_trial215_plant_1',
            'test_trial215_plant_2'
          ], "check contents of first col");

is_deeply($columns->[2], [
            undef,
            'range',
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
            '1',
            '1'
          ], "check contents of second col");

is_deeply($columns->[3],[
            undef,
            'plant',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2',
            '1',
            '2'
          ], "check contents of third col");

is_deeply($columns->[4], [
            undef,
            'plot',
            '1',
            '1',
            '2',
            '2',
            '3',
            '3',
            '4',
            '4',
            '5',
            '5',
            '6',
            '6',
            '7',
            '7',
            '8',
            '8',
            '9',
            '9',
            '10',
            '10',
            '11',
            '11',
            '12',
            '12',
            '13',
            '13',
            '14',
            '14',
            '15',
            '15'
          ], "check contents of fourth col");

is_deeply($columns->[5], [
            undef,
            'rep',
            '1',
            '1',
            '1',
            '1',
            '1',
            '1',
            '2',
            '2',
            '1',
            '1',
            '2',
            '2',
            '2',
            '2',
            '2',
            '2',
            '1',
            '1',
            '3',
            '3',
            '3',
            '3',
            '3',
            '3',
            '2',
            '2',
            '3',
            '3',
            '3',
            '3'
          ], "check contents of fifth col");

is_deeply($columns->[6],[
            undef,
            'accession',
            'test_accession4',
            'test_accession4',
            'test_accession5',
            'test_accession5',
            'test_accession3',
            'test_accession3',
            'test_accession3',
            'test_accession3',
            'test_accession1',
            'test_accession1',
            'test_accession4',
            'test_accession4',
            'test_accession5',
            'test_accession5',
            'test_accession1',
            'test_accession1',
            'test_accession2',
            'test_accession2',
            'test_accession3',
            'test_accession3',
            'test_accession1',
            'test_accession1',
            'test_accession5',
            'test_accession5',
            'test_accession2',
            'test_accession2',
            'test_accession4',
            'test_accession4',
            'test_accession2',
            'test_accession2'
          ], "check contents of sixth col");

is_deeply($columns->[7],[
            undef,
            'is_a_control'
          ], "check contents of 7th col");

done_testing();
