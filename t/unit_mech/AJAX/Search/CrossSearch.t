
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::List;
use Data::Dumper;
use JSON;
use CXGN::Trial::Download;
use Spreadsheet::WriteExcel;
use Excel::Writer::XLSX;
use Spreadsheet::Read;

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};


#test search male parents
$mech->post_ok('http://localhost:3010/ajax/search/pedigree_male_parents',["pedigree_female_parent" => "test_accession4"] );
$response = decode_json $mech->content;
is_deeply($response, {'data' => [
['test_accession5']
]},'male parent search');


#test search female parents
$mech->post_ok('http://localhost:3010/ajax/search/pedigree_female_parents',["pedigree_male_parent" => "test_accession5"] );
$response = decode_json $mech->content;
is_deeply($response, {'data' => [
['test_accession4']
]},'female parent search');


#test search progenies using both female and male parent
$mech->post_ok('http://localhost:3010/ajax/search/progenies',["pedigree_female_parent" => "test_accession4","pedigree_male_parent" => "test_accession5"] );
$response = decode_json $mech->content;
is_deeply($response, {'data' => [['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38846/view">new_test_crossP001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38847/view">new_test_crossP002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38848/view">new_test_crossP003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38849/view">new_test_crossP004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38850/view">new_test_crossP005</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38851/view">new_test_crossP006</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38852/view">new_test_crossP007</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38853/view">new_test_crossP008</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38854/view">new_test_crossP009</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38855/view">new_test_crossP010</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38873/view">test5P001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38874/view">test5P002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38875/view">test5P003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38876/view">test5P004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38877/view">test5P005</a>', undef]]}, 'progeny search');


#test search progenies using female parent
$mech->post_ok('http://localhost:3010/ajax/search/progenies',["pedigree_female_parent" => "test_accession4"] );
$response = decode_json $mech->content;
is_deeply($response, {'data' => [['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38846/view">new_test_crossP001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38847/view">new_test_crossP002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38848/view">new_test_crossP003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38849/view">new_test_crossP004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38850/view">new_test_crossP005</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38851/view">new_test_crossP006</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38852/view">new_test_crossP007</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38853/view">new_test_crossP008</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38854/view">new_test_crossP009</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38855/view">new_test_crossP010</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38873/view">test5P001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38874/view">test5P002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38875/view">test5P003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38876/view">test5P004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38877/view">test5P005</a>', undef]]}, 'all progeny search');


#test search progenies using male parent
$mech->post_ok('http://localhost:3010/ajax/search/progenies',["pedigree_male_parent" => "test_accession5"] );
$response = decode_json $mech->content;
is_deeply($response, {'data' => [['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38846/view">new_test_crossP001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38847/view">new_test_crossP002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38848/view">new_test_crossP003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38849/view">new_test_crossP004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38850/view">new_test_crossP005</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38851/view">new_test_crossP006</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38852/view">new_test_crossP007</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38853/view">new_test_crossP008</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38854/view">new_test_crossP009</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38855/view">new_test_crossP010</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38873/view">test5P001</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38874/view">test5P002</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38875/view">test5P003</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38876/view">test5P004</a>', undef],['<a href="/stock/38843/view">test_accession4</a>','<a href="/stock/38844/view">test_accession5</a>','<a href="/stock/38877/view">test5P005</a>', undef]]}, 'all progeny search');


#test search cross male parents
$mech->post_ok('http://localhost:3010/ajax/search/cross_male_parents',["female_parent" => "TestAccession1"] );
$response = decode_json $mech->content;
is_deeply($response, {'data' => [
['TestAccession1'],
['TestAccession2'],
['TestAccession3'],
['TestAccession4'],
['TestPopulation1'],
['TestPopulation2']
]},'male parent search');


#test search cross female parents
$mech->post_ok('http://localhost:3010/ajax/search/cross_female_parents',["male_parent" => "TestAccession4"] );
$response = decode_json $mech->content;
is_deeply($response, {'data' => [
['TestAccession1']
]},'female parent search');


#test retrieving accessions with pedigree info
$mech->get_ok('http://localhost:3010/ajax/stock/accessions_with_pedigree');
$response = decode_json $mech->content;

my $results = $response->{'data'};
my @accessions_with_pedigree = @$results;
my $number_of_accessions = scalar(@accessions_with_pedigree);
is($number_of_accessions, 17);

#test accessions with pedigree download
my $tempfile = "/tmp/test_download_accessions_with_pedigree.xlsx";
my $format = 'AccessionsWithPedigreeXLSX';
my $create_spreadsheet = CXGN::Trial::Download->new({
    bcs_schema                => $f->bcs_schema,
    filename                  => $tempfile,
    format                    => $format,
});

$create_spreadsheet->download();
my $contents = ReadData $tempfile;

my $column_1 = $contents->[1]->{'cell'}->[1];
my @column_1_rows = @$column_1;
my $header_1 = $column_1_rows[1];
is(scalar @column_1_rows,19);
is($header_1, "Accession Name");

my $column_2 = $contents->[1]->{'cell'}->[2];
my @column_2_rows = @$column_2;
my $header_2 = $column_2_rows[1];
is(scalar @column_2_rows,19);
is($header_2, "Female Parent");

#create a list of accessions
$mech->get_ok('http://localhost:3010/list/new?name=accession_list&desc=test');
$response = decode_json $mech->content;
my $accession_list_id = $response->{list_id};
#print STDERR "ACCESSION LIST ID =".Dumper($accession_list_id)."\n";
ok($accession_list_id);

my @accessions = qw(new_test_crossP001 new_test_crossP002 new_test_crossP003 new_test_crossP004 new_test_crossP005 new_test_crossP006 test_accession4 test_accession5);

my $accession_list = CXGN::List->new( { dbh=>$dbh, list_id => $accession_list_id });
my $response = $accession_list->add_bulk(\@accessions);
is($response->{'count'},8);

#test searching common parents
$mech->get_ok('http://localhost:3010/ajax/search/common_parents?accession_list_id='.$accession_list_id);
$response = decode_json $mech->content;
my $rows = $response->{'data'};
my @data_array = @$rows;
is(scalar @data_array, 3);

my $first_row = $rows->[0];
my $second_row = $rows->[1];
my $third_row = $rows->[2];

is($first_row->{'female_name'}, 'test_accession1');
is($first_row->{'male_name'}, 'test_accession2');
is($first_row->{'no_of_accessions'}, '1');

is($second_row->{'female_name'}, 'test_accession3');
is($second_row->{'male_name'}, 'unknown');
is($second_row->{'no_of_accessions'}, '1');

is($third_row->{'female_name'}, 'test_accession4');
is($third_row->{'male_name'}, 'test_accession5');
is($third_row->{'no_of_accessions'}, '6');

#Delete list
CXGN::List::delete_list($schema->storage->dbh, $accession_list_id);


done_testing();
