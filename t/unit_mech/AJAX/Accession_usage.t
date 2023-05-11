
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use Data::Dumper;
use JSON;
use CXGN::Trial::Download;
use Spreadsheet::WriteExcel;
use Excel::Writer::XLSX;
use Spreadsheet::Read;

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->get_ok('http://localhost:3010/ajax/accession_usage_trials');
$response = decode_json $mech->content;
my $data = $response->{data};
ok(scalar(@$data) == 439);

is_deeply($data->[0],
['<a href="/stock/38878/view">UG120001</a>',3,6]
, 'first row');


is_deeply($data->[100],
['<a href="/stock/38978/view">UG120115</a>',3,6]
, '101th row');

#test retrieving female parents and numbers of progenies
$mech->get_ok('http://localhost:3010/ajax/accession_usage_female');
$response = decode_json $mech->content;

is_deeply($response,{'data' => [['<a href="/stock/38843/view">test_accession4</a>',15],['<a href="/stock/38840/view">test_accession1</a>',1],['<a href="/stock/38842/view">test_accession3</a>',1]]}, 'female usage');

#test downloading female parents and numbers of progenies
my $tempfile = "/tmp/test_download_female_parents.xlsx";
my $format = 'FemaleParentsAndNumbersOfProgeniesXLSX';
my $create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema                => $schema,
    filename                  => $tempfile,
    format                    => $format,
});

$create_spreadsheet->download();
my $contents = ReadData $tempfile;

my $column_1 = $contents->[1]->{'cell'}->[1];
my $header_1 = $column_1->[1];
my $column_1_line_2 = $column_1->[2];
my $column_1_line_3 = $column_1->[3];
my $column_1_line_4 = $column_1->[4];

is($header_1, 'Female Parent Name');
is($column_1_line_2, 'test_accession4');
is($column_1_line_3, 'test_accession1');
is($column_1_line_4, 'test_accession3');

my $column_2 = $contents->[1]->{'cell'}->[2];
my $header_2 = $column_2->[1];
my $column_2_line_2 = $column_2->[2];
my $column_2_line_3 = $column_2->[3];
my $column_2_line_4 = $column_2->[4];
is($header_2, 'Number of Progenies');
is($column_2_line_2, '15');
is($column_2_line_3, '1');
is($column_2_line_4, '1');

#test retrieving male parents and numbers of progenies
$mech->get_ok('http://localhost:3010/ajax/accession_usage_male');
$response = decode_json $mech->content;
is_deeply($response, {'data' => [['<a href="/stock/38844/view">test_accession5</a>',15],['<a href="/stock/38841/view">test_accession2</a>',1]]}, 'male usage');

#test downloading male parents and numbers of progenies
my $male_tempfile = "/tmp/test_download_male_parents.xlsx";
my $male_format = 'MaleParentsAndNumbersOfProgeniesXLSX';
my $male_create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema                => $schema,
    filename                  => $male_tempfile,
    format                    => $male_format,
});

$male_create_spreadsheet->download();
my $male_contents = ReadData $male_tempfile;

my $male_column_1 = $male_contents->[1]->{'cell'}->[1];
my $male_header_1 = $male_column_1->[1];
my $male_column_1_line_2 = $male_column_1->[2];
my $male_column_1_line_3 = $male_column_1->[3];

is($male_header_1, 'Male Parent Name');
is($male_column_1_line_2, 'test_accession5');
is($male_column_1_line_3, 'test_accession2');

my $male_column_2 = $male_contents->[1]->{'cell'}->[2];
my $male_header_2 = $male_column_2->[1];
my $male_column_2_line_2 = $male_column_2->[2];
my $male_column_2_line_3 = $male_column_2->[3];
is($male_header_2, 'Number of Progenies');
is($male_column_2_line_2, '15');
is($male_column_2_line_3, '1');


$mech->get_ok('http://localhost:3010/ajax/accession_usage_phenotypes?display=plots_accession');
$response = decode_json $mech->content;

is(scalar(@{$response->{data}}), 1563, 'accession phenotypes usage');


done_testing();
