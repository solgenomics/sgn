
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
    selected_columns=> {'plot_name'=>1,'block_number'=>1,'plot_number'=>1,'rep_number'=>1,'row_number'=>1,'col_number'=>1,'accession_name'=>1,'is_a_control'=>1}
});

my $create_fieldbook_return = $create_fieldbook->download();
print STDERR Dumper $create_fieldbook_return;
ok($create_fieldbook_return, "check that download trial fieldbook returns something.");

my $contents = ReadData $create_fieldbook_return->{'file'};
#print STDERR Dumper @contents->[0]->[0];
is($contents->[0]->{'type'}, 'xls', "check that type of file is correct");
is($contents->[0]->{'sheets'}, '1', "check that type of file is correct");

my $columns = $contents->[1]->{'cell'};
#print STDERR Dumper scalar(@$columns);
ok(scalar(@$columns) == 9, "check number of col in created file.");

#print STDERR Dumper $columns;

is_deeply($columns, [
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
            'is_a_control'
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
          ]
        ], 'check file contents');


my $tempfile = "/tmp/test_create_trial_fieldbook2.xls";

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
    selected_columns=> {'plot_name'=>1,'block_number'=>1,'plot_number'=>1,'rep_number'=>1,'row_number'=>1,'col_number'=>1,'accession_name'=>1,'is_a_control'=>1,'synonyms'=>1,'trial_name'=>1,'location_name'=>1,'year'=>1,'pedigree'=>1,'tier'=>1},
    selected_trait_ids=>[70666,70668],
});

my $create_fieldbook_return = $create_fieldbook->download();
print STDERR Dumper $create_fieldbook_return;
ok($create_fieldbook_return, "check that download trial fieldbook returns something.");

my $contents = ReadData $create_fieldbook_return->{'file'};
#print STDERR Dumper @contents->[0]->[0];
is($contents->[0]->{'type'}, 'xls', "check that type of file is correct");
is($contents->[0]->{'sheets'}, '1', "check that type of file is correct");

my $columns = $contents->[1]->{'cell'};
#print STDERR Dumper scalar(@$columns);
ok(scalar(@$columns) == 15, "check number of col in created file.");

print STDERR Dumper $columns;
is_deeply ($columns,[
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
            'is_a_control'
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
          ]
        ], "check selectable fieldbook cols");

done_testing();
