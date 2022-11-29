
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use CXGN::Trial::Download;
use Spreadsheet::Read;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

for my $extension ("xls", "xlsx") {

        my $trial_id = $schema->resultset("Project::Project")->find({ name => 'test_trial' })->project_id();
        my @trait_list = ("dry matter content percentage|CO_334:0000092", "fresh root weight|CO_334:0000012");
        my $tempfile = "/tmp/test_create_pheno_spreadsheet.$extension";
        my $format = 'ExcelBasic';

        my $create_spreadsheet = CXGN::Trial::Download->new({
            bcs_schema => $schema,
            trial_list => [ $trial_id ],
            trait_list => \@trait_list,
            filename   => $tempfile,
            format     => $format,
        });

        $create_spreadsheet->download();
        my $contents = ReadData $tempfile;

        #print STDERR Dumper $contents->[0];
        is($contents->[0]->{'type'}, $extension, "check that type of file is correct");
        is($contents->[0]->{'sheets'}, '1', "check that type of file is correct");

        my $columns = $contents->[1]->{'cell'};
        #print STDERR Dumper scalar(@$columns);
        ok(scalar(@$columns) == 12, "check number of columns in created pheno spreadsheet.");

        #print STDERR Dumper $contents->[1];
        #print STDERR Dumper $contents->[1]->{'cell'}->[1];
        is_deeply($contents->[1]->{'cell'}->[1], [
            undef,
            'Spreadsheet ID',
            'Trial name(s)',
            'Description(s)',
            'Trial location(s)',
            'Predefined Columns',
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
        ], "check contents of first column in created pheno spreadsheet."
        );

        my $contents_col_2 = $contents->[1]->{'cell'}->[2];
        #remove unique ID number from test...
        splice @$contents_col_2, 0, 2;
        #print STDERR Dumper $contents_col_2;
        is_deeply($contents_col_2, [
            'test_trial',
            'test_trial: test trial',
            'test_trial: test_location',
            '[]',
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
        ], "check contents of second col in created pheno spreadsheet"
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[3];
        is_deeply($contents->[1]->{'cell'}->[3], [
            undef,
            'Spreadsheet format',
            'Operator',
            'Date',
            'Design Type(s)',
            undef,
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
        ], "check contents of third column in created pheno spreadsheet."
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[4];
        is_deeply($contents->[1]->{'cell'}->[4], [
            undef,
            'BasicExcel',
            'Enter operator here',
            'Enter date here',
            'test_trial: CRD',
            undef,
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
        ], "check contents of fourth column in created pheno spreadsheet."
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[5];
        is_deeply($contents->[1]->{'cell'}->[5], [
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            'is_a_control'
        ], "check contents of fifth column in created pheno spreadsheet."
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[6];
        is_deeply($contents->[1]->{'cell'}->[6], [
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
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
        ], "check contents of sixth column in created pheno spreadsheet."
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[7];
        is_deeply($contents->[1]->{'cell'}->[7], [
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            'planting_date',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04',
            '2017-July-04'
        ], "check contents of 7column in created pheno spreadsheet."
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[8];
        is_deeply($contents->[1]->{'cell'}->[8], [
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            'harvest_date',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21',
            '2017-July-21'
        ], "check contents of 8 column in created pheno spreadsheet."
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[9];
        is_deeply($contents->[1]->{'cell'}->[9], [
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
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
        ], "check contents of 9 column in created pheno spreadsheet."
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[10];
        is_deeply($contents->[1]->{'cell'}->[10], [
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            'dry matter content percentage|CO_334:0000092'
        ], "check contents of 10 column in created pheno spreadsheet."
        );

        #print STDERR Dumper $contents->[1]->{'cell'}->[11];
        is_deeply($contents->[1]->{'cell'}->[11], [
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            'fresh root weight|CO_334:0000012'
        ], "check contents of 11 column in created pheno spreadsheet."
        );
        $f->clean_up_db();
}

done_testing();
