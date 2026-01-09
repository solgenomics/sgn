
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Trial::TrialLayout;
use CXGN::Trial;
use CXGN::Trial::Download;
use Spreadsheet::WriteExcel;
use Spreadsheet::Read;
use CXGN::Fieldbook::DownloadTrial;
use File::Temp 'tempfile';
use DateTime;

my $f = SGN::Test::Fixture->new();

for my $extension ("xls", "xlsx") {

    my $trial_id = 137;

    my $tl = CXGN::Trial::TrialLayout->new({ schema => $f->bcs_schema(), trial_id => $trial_id, experiment_type => 'field_layout' });

    my $d = $tl->get_design();
    print STDERR Dumper($d);

    my @plot_nums;
    my @accessions;
    my @plant_names;
    my @rep_nums;
    my @plot_names;
    foreach my $plot_num (keys %$d) {
        push @plot_nums, $plot_num;
        push @accessions, $d->{$plot_num}->{'accession_name'};
        push @plant_names, $d->{$plot_num}->{'plant_names'};
        push @rep_nums, $d->{$plot_num}->{'rep_number'};
        push @plot_names, $d->{$plot_num}->{'plot_name'};
    }
    @plot_nums = sort @plot_nums;
    @accessions = sort @accessions;
    @plant_names = sort @plant_names;
    @rep_nums = sort @rep_nums;
    @plot_names = sort @plot_names;

    #print STDERR Dumper \@plot_nums;
    #print STDERR Dumper \@accessions;
    #print STDERR Dumper \@plant_names;
    #print STDERR Dumper \@rep_nums;
    #print STDERR Dumper \@plot_names;

    is_deeply(\@plot_nums, [
        '1',
        '10',
        '11',
        '12',
        '13',
        '14',
        '15',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9'
    ], 'check design plot_nums');

    is_deeply(\@accessions, [
        'test_accession1',
        'test_accession1',
        'test_accession1',
        'test_accession2',
        'test_accession2',
        'test_accession2',
        'test_accession3',
        'test_accession3',
        'test_accession3',
        'test_accession4',
        'test_accession4',
        'test_accession4',
        'test_accession5',
        'test_accession5',
        'test_accession5'
    ], 'check design accessions');

    is_deeply(\@plant_names, [
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        [],
        []
    ], "check design plant_names");

    is_deeply(\@rep_nums, [
        '1',
        '1',
        '1',
        '1',
        '1',
        '2',
        '2',
        '2',
        '2',
        '2',
        '3',
        '3',
        '3',
        '3',
        '3'
    ], "check design rep_nums");

    is_deeply(\@plot_names, [
        'test_trial21',
        'test_trial210',
        'test_trial211',
        'test_trial212',
        'test_trial213',
        'test_trial214',
        'test_trial215',
        'test_trial22',
        'test_trial23',
        'test_trial24',
        'test_trial25',
        'test_trial26',
        'test_trial27',
        'test_trial28',
        'test_trial29'
    ], "check design plot_names");

    my $trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id });
    $trial->create_plant_entities('2');

    my $tl = CXGN::Trial::TrialLayout->new({ schema => $f->bcs_schema(), trial_id => $trial_id, experiment_type => 'field_layout' });
    $d = $tl->get_design();
    print STDERR Dumper($d);

    @plot_nums = ();
    @accessions = ();
    @plant_names = ();
    @rep_nums = ();
    @plot_names = ();
    my @plant_names_flat;
    foreach my $plot_num (keys %$d) {
        push @plot_nums, $plot_num;
        push @accessions, $d->{$plot_num}->{'accession_name'};
        push @plant_names, $d->{$plot_num}->{'plant_names'};
        push @rep_nums, $d->{$plot_num}->{'rep_number'};
        push @plot_names, $d->{$plot_num}->{'plot_name'};
    }
    @plot_nums = sort @plot_nums;
    @accessions = sort @accessions;
    @rep_nums = sort @rep_nums;
    @plot_names = sort @plot_names;

    foreach my $plant_name_arr_ref (@plant_names) {
        foreach (@$plant_name_arr_ref) {
            push @plant_names_flat, $_;
        }
    }
    @plant_names_flat = sort @plant_names_flat;

    #print STDERR Dumper \@plot_nums;
    #print STDERR Dumper \@accessions;
    #print STDERR Dumper \@plant_names_flat;
    #print STDERR Dumper \@rep_nums;
    #print STDERR Dumper \@plot_names;

    is_deeply(\@plot_nums, [
        '1',
        '10',
        '11',
        '12',
        '13',
        '14',
        '15',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9'
    ], "check plot_nums after plant addition");

    is_deeply(\@accessions, [
        'test_accession1',
        'test_accession1',
        'test_accession1',
        'test_accession2',
        'test_accession2',
        'test_accession2',
        'test_accession3',
        'test_accession3',
        'test_accession3',
        'test_accession4',
        'test_accession4',
        'test_accession4',
        'test_accession5',
        'test_accession5',
        'test_accession5'
    ], "check accessions after plant addition");

    is_deeply(\@plant_names_flat, [
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
        'test_trial215_plant_2',
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
        'test_trial29_plant_2'
    ], "check plant names");

    is_deeply(\@rep_nums, [
        '1',
        '1',
        '1',
        '1',
        '1',
        '2',
        '2',
        '2',
        '2',
        '2',
        '3',
        '3',
        '3',
        '3',
        '3'
    ], "check rep nums after plant addition");

    is_deeply(\@plot_names, [
        'test_trial21',
        'test_trial210',
        'test_trial211',
        'test_trial212',
        'test_trial213',
        'test_trial214',
        'test_trial215',
        'test_trial22',
        'test_trial23',
        'test_trial24',
        'test_trial25',
        'test_trial26',
        'test_trial27',
        'test_trial28',
        'test_trial29'
    ], "check plot_names after plant addition");

    my $tempfile = "/tmp/test_create_trial_fieldbook_plots.$extension";

    my $create_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
        bcs_schema       => $f->bcs_schema,
        metadata_schema  => $f->metadata_schema,
        phenome_schema   => $f->phenome_schema,
        trial_id         => $trial_id,
        tempfile         => $tempfile,
        archive_path     => $f->config->{archive_path},
        user_id          => 41,
        user_name        => "janedoe",
        data_level       => 'plots',
        selected_columns => { 'plot_name' => 1, 'block_number' => 1, 'plot_number' => 1, 'rep_number' => 1, 'row_number' => 1, 'col_number' => 1, 'accession_name' => 1, 'is_a_control' => 1 }
    });

    my $create_fieldbook_return = $create_fieldbook->download();
    ok($create_fieldbook_return, "check that download trial fieldbook returns something.");

    my $contents = ReadData $create_fieldbook_return->{'file'};

    #print STDERR Dumper @contents->[0]->[0];
    is($contents->[0]->{'type'}, $extension, "check that type of file is correct");
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
    ], "check fieldbook creation of plots after plants created");

    my $tempfile = "/tmp/test_create_trial_fieldbook_plants.$extension";

    my $create_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
        bcs_schema       => $f->bcs_schema,
        metadata_schema  => $f->metadata_schema,
        phenome_schema   => $f->phenome_schema,
        trial_id         => $trial_id,
        tempfile         => $tempfile,
        archive_path     => $f->config->{archive_path},
        user_id          => 41,
        user_name        => "janedoe",
        data_level       => 'plants',
        selected_columns => { 'plant_name' => 1, 'plot_name' => 1, 'block_number' => 1, 'plant_number' => 1, 'plot_number' => 1, 'rep_number' => 1, 'row_number' => 1, 'col_number' => 1, 'accession_name' => 1, 'is_a_control' => 1 }
    });

    my $create_fieldbook_return = $create_fieldbook->download();
    ok($create_fieldbook_return, "check that download trial fieldbook returns something.");

    my $contents = ReadData $create_fieldbook_return->{'file'};

    #print STDERR Dumper @contents->[0]->[0];
    is($contents->[0]->{'type'}, $extension, "check that type of file is correct");
    is($contents->[0]->{'sheets'}, '1', "check that type of file is correct");

    my $columns = $contents->[1]->{'cell'};
    #print STDERR Dumper scalar(@$columns);
    ok(scalar(@$columns) == 11, "check number of col in created file.");

    #print STDERR Dumper $columns;
    is_deeply($columns, [
        [],
        [
            undef,
            'plant_name',
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
        ],
        [
            undef,
            'plot_name',
            'test_trial21',
            'test_trial21',
            'test_trial22',
            'test_trial22',
            'test_trial23',
            'test_trial23',
            'test_trial24',
            'test_trial24',
            'test_trial25',
            'test_trial25',
            'test_trial26',
            'test_trial26',
            'test_trial27',
            'test_trial27',
            'test_trial28',
            'test_trial28',
            'test_trial29',
            'test_trial29',
            'test_trial210',
            'test_trial210',
            'test_trial211',
            'test_trial211',
            'test_trial212',
            'test_trial212',
            'test_trial213',
            'test_trial213',
            'test_trial214',
            'test_trial214',
            'test_trial215',
            'test_trial215'
        ],
        [
            undef,
            'accession_name',
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
        ],
        [
            undef,
            'plot_number',
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
            'plant_number',
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
        ]
    ], 'test file contents');

    my @trait_list = ("dry matter content percentage|CO_334:0000092", "fresh root weight|CO_334:0000012");
    my $tempfile = "/tmp/test_create_pheno_spreadsheet_plots_after_plants.$extension";
    my $format = 'ExcelBasic';
    my $create_spreadsheet = CXGN::Trial::Download->new(
        {
            bcs_schema => $f->bcs_schema,
            trial_list => [ $trial_id ],
            trait_list => \@trait_list,
            filename   => $tempfile,
            format     => $format,
            data_level => 'plots',
        });

    $create_spreadsheet->download();
    my $contents = ReadData $tempfile;

    my $columns = $contents->[1]->{'cell'};
    #print STDERR Dumper scalar(@$columns);
    ok(scalar(@$columns) == 12, "check number of col in created file.");

    #print STDERR Dumper $contents->[0];
    is($contents->[0]->{'type'}, $extension, "check that type of file is correct");
    is($contents->[0]->{'sheets'}, '1', "check that type of file is correct");

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
    ], "check 1st col");

    my $contents_col_2 = $contents->[1]->{'cell'}->[2];
    #remove unique ID number from test...
    splice @$contents_col_2, 0, 2;
    #print STDERR Dumper $contents_col_2;
    is_deeply($contents_col_2, [ 'test_trial',
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
    ], "check 2nd col");

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
    ], "check thrid col");

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
    ], "check 4th col");

    is_deeply($contents->[1]->{'cell'}->[5], [
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        'is_a_control'
    ], "check 5th col");

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
    ], "check 6th col");

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
    ], "check 7th col");

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
    ], "check 8th col");

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
    ], "check 9th col");

    is_deeply($contents->[1]->{'cell'}->[10], [
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        'dry matter content percentage|CO_334:0000092'
    ], "check 10th col");

    is_deeply($contents->[1]->{'cell'}->[11], [
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        'fresh root weight|CO_334:0000012'
    ], "check 11th col");

    my @trait_list = ("dry matter content percentage|CO_334:0000092", "fresh root weight|CO_334:0000012");
    my $tempfile = "/tmp/test_create_pheno_spreadsheet_plots_after_plants.$extension";
    my $format = 'ExcelBasic';
    my $create_spreadsheet = CXGN::Trial::Download->new(
        {
            bcs_schema         => $f->bcs_schema,
            trial_list         => [ $trial_id ],
            trait_list         => \@trait_list,
            filename           => $tempfile,
            format             => $format,
            data_level         => 'plants',
            sample_number      => '2',
            predefined_columns => [ { 'plant_age' => '2 weeks' } ],
        });

    $create_spreadsheet->download();
    my $contents = ReadData $tempfile;

    my $columns = $contents->[1]->{'cell'};
    #print STDERR Dumper scalar(@$columns);
    ok(scalar(@$columns) == 14, "check number of col in created file.");

    #print STDERR Dumper @contents->[0];
    is($contents->[0]->{'type'}, $extension, "check that type of file is correct");
    is($contents->[0]->{'sheets'}, '1', "check that type of file is correct");

    #print STDERR Dumper $contents->[1]->{'cell'}->[1];
    is_deeply($contents->[1]->{'cell'}->[1], [
        undef,
        'Spreadsheet ID',
        'Trial name(s)',
        'Description(s)',
        'Trial location(s)',
        'Predefined Columns',
        undef,
        'plant_name',
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
    ], "check col1");

    my $contents_col_2 = $contents->[1]->{'cell'}->[2];
    #remove unique ID number from test...
    splice @$contents_col_2, 0, 2;
    #print STDERR Dumper $contents_col_2;
    is_deeply($contents_col_2, [ 'test_trial',
        'test_trial: test trial',
        'test_trial: test_location',
        '["plant_age"]',
        undef,
        'plot_name',
        'test_trial21',
        'test_trial21',
        'test_trial22',
        'test_trial22',
        'test_trial23',
        'test_trial23',
        'test_trial24',
        'test_trial24',
        'test_trial25',
        'test_trial25',
        'test_trial26',
        'test_trial26',
        'test_trial27',
        'test_trial27',
        'test_trial28',
        'test_trial28',
        'test_trial29',
        'test_trial29',
        'test_trial210',
        'test_trial210',
        'test_trial211',
        'test_trial211',
        'test_trial212',
        'test_trial212',
        'test_trial213',
        'test_trial213',
        'test_trial214',
        'test_trial214',
        'test_trial215',
        'test_trial215'
    ], "check col2");

    #print STDERR Dumper $contents->[1]->{'cell'}->[3];
    is_deeply($contents->[1]->{'cell'}->[3], [ #test 40
        undef,
        'Spreadsheet format',
        'Operator',
        'Date',
        'Design Type(s)',
        undef,
        undef,
        'accession_name',
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
    ], "check col3");

    #print STDERR Dumper $contents->[1]->{'cell'}->[4];
    is_deeply($contents->[1]->{'cell'}->[4], [
        undef,
        'BasicExcel',
        'Enter operator here',
        'Enter date here',
        'test_trial: CRD',
        undef,
        undef,
        'plot_number',
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
    ], "check col4");

    is_deeply($contents->[1]->{'cell'}->[5], [
        undef,
        undef,
        undef,
        undef,
        undef,
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
    ], "check col5");

    is_deeply($contents->[1]->{'cell'}->[6], [
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        'is_a_control'
    ], "check col6");

    is_deeply($contents->[1]->{'cell'}->[7], [
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
    ], "check col7");

    #print STDERR Dumper $contents->[1]->{'cell'}->[8];
    is_deeply($contents->[1]->{'cell'}->[8], [
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
        '2017-July-04',
        '2017-July-04'
    ], "check col8");

    #print STDERR Dumper $contents->[1]->{'cell'}->[9];
    is_deeply($contents->[1]->{'cell'}->[9], [
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
        '2017-July-21',
        '2017-July-21'
    ], "check col9");

    #print STDERR Dumper $contents->[1]->{'cell'}->[10];
    is_deeply($contents->[1]->{'cell'}->[10], [
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
        'test_trial',
        'test_trial'
    ], "check col10");

    is_deeply($contents->[1]->{'cell'}->[11], [
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        'plant_age',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks',
        '2 weeks'
    ], "check col11");

    is_deeply($contents->[1]->{'cell'}->[12], [
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        'dry matter content percentage|CO_334:0000092'
    ], "check col12");

    is_deeply($contents->[1]->{'cell'}->[13], [
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        undef,
        'fresh root weight|CO_334:0000012'
    ], "check col13");

    $trial = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => $trial_id, phenome_schema => $f->phenome_schema, metadata_schema => $f->metadata_schema});
    my $temp_basedir = $f->config->{tempfiles_subdir};
    my $site_basedir = $f->config->{basepath};
    if (! -d "$site_basedir/$temp_basedir/delete_nd_experiment_ids/"){
        mkdir("$site_basedir/$temp_basedir/delete_nd_experiment_ids/");
    }
    my (undef, $tempfile) = tempfile("$site_basedir/$temp_basedir/delete_nd_experiment_ids/fileXXXX");
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $phenotype_store_config = {
        basepath => "$site_basedir/$temp_basedir",
        dbhost => $f->config->{dbhost},
        dbuser => $f->config->{dbuser},
        dbname => $f->config->{dbname},
        dbpass => $f->config->{dbpass},
        temp_file_nd_experiment_id => $tempfile,
        user_id => '41',
        metadata_hash => {
            archived_file => 'none',
            archived_file_type => 'new stock treatment auto inheritance',
            operator => 'janedoe',
            date => $timestamp
        }
    };
    is($trial->create_tissue_samples(['leaf', ], 1, 0, undef, undef, $phenotype_store_config), 1, 'test create tissue samples without tissue numbers');#test 51
    is($trial->create_tissue_samples(['root', 'fruit' ], 1, 1, undef, undef, $phenotype_store_config), 1, 'test create tissue samples with tissue numbers');#test 52

    `rm $tempfile`;

    my $trial_with_tissues_layout = CXGN::Trial::TrialLayout->new({ schema => $f->bcs_schema(), trial_id => $trial_id, experiment_type => 'field_layout' })->get_design();
    print STDERR Dumper $trial_with_tissues_layout;
    print STDERR scalar(keys %$trial_with_tissues_layout) . "\n";
    is(scalar(keys(%$trial_with_tissues_layout)), 15, 'test trial layout count');
    is_deeply($trial_with_tissues_layout->{5}->{tissue_sample_names}, [
        'test_trial25_plant_1_leaf',        # sample without tissue number
        'test_trial25_plant_2_leaf',        # sample without tissue number
        'test_trial25_plant_1_root1',       # sample with tissue number
        'test_trial25_plant_1_fruit2',      # sample with tissue number
        'test_trial25_plant_2_root1',       # sample with tissue number
        'test_trial25_plant_2_fruit2'       # sample with tissue number
    ], 'test layout with tissue samples');

    is_deeply($trial_with_tissues_layout->{5}->{plants_tissue_sample_names}, {
        'test_trial25_plant_2' => [
            'test_trial25_plant_2_leaf',    # sample without tissue number
            'test_trial25_plant_2_root1',   # sample with tissue number
            'test_trial25_plant_2_fruit2'   # sample with tissue number
        ],
        'test_trial25_plant_1' => [
            'test_trial25_plant_1_leaf',    # sample without tissue number
            'test_trial25_plant_1_root1',   # sample with tissue number
            'test_trial25_plant_1_fruit2'   # sample with tissue number
        ]
    }, 'test layout with tissues samples');


#retrieving all stock entries for this trial
    my $trial = CXGN::Trial->new( { bcs_schema => $f->bcs_schema(), trial_id => $trial_id});
    my $stock_entries = $trial->get_stock_entry_summary();
    my @all_entries = @$stock_entries;
    is(scalar @all_entries, '90');

    my $first_stock_linkage = $all_entries[0];
    my $accession_name_1 = $first_stock_linkage->[0];
    my $plot_name_1 = $first_stock_linkage->[3];
    my $plant_name_1 = $first_stock_linkage->[5];
    my $tissue_sample_name_1 = $first_stock_linkage->[7];
    is($accession_name_1, 'test_accession1');
    is($plot_name_1, 'test_trial211');
    is($plant_name_1, 'test_trial211_plant_1');
    is($tissue_sample_name_1,'test_trial211_plant_1_fruit2');

    my $second_stock_linkage = $all_entries[1];
    my $accession_name_2 = $second_stock_linkage->[0];
    my $plot_name_2 = $second_stock_linkage->[3];
    my $plant_name_2 = $second_stock_linkage->[5];
    my $tissue_sample_name_2 = $second_stock_linkage->[7];
    is($accession_name_2, 'test_accession1');
    is($plot_name_2, 'test_trial211');
    is($plant_name_2, 'test_trial211_plant_1');
    is($tissue_sample_name_2, 'test_trial211_plant_1_leaf');

    my $third_stock_linkage = $all_entries[2];
    my $accession_name_3 = $third_stock_linkage->[0];
    my $plot_name_3 = $third_stock_linkage->[3];
    my $plant_name_3 = $third_stock_linkage->[5];
    my $tissue_sample_name_3 = $third_stock_linkage->[7];
    is($accession_name_3, 'test_accession1');
    is($plot_name_3, 'test_trial211');
    is($plant_name_3, 'test_trial211_plant_1');
    is($tissue_sample_name_3, 'test_trial211_plant_1_root1');

    $f->clean_up_db();
}

done_testing();
