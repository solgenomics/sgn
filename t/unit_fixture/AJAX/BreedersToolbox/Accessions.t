
# Tests all functions in SGN::Controller::AJAX::Accessions. These are the functions called from Accessions.js when adding new accessions.

use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Chado::Stock;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;
my $json = JSON->new->allow_nonref;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'success'}, 'Login Successfull');

$mech->post_ok('http://localhost:3010/ajax/accession_list/verify', [ "accession_list"=> '["new_accession1", "test_accession1", "test_accessionx", "test_accessiony", "test_accessionz"]', "do_fuzzy_search"=> "true" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response->{'fuzzy'};
print STDERR Dumper $response->{'found'};
print STDERR Dumper $response->{'absent'};

is(scalar @{$response->{'fuzzy'}}, 3, 'check verify fuzzy match response content');
is_deeply($response->{'found'}, [{'matched_string' => 'test_accession1','unique_name' => 'test_accession1'}], 'check verify fuzzy match response content');
is_deeply($response->{'absent'}, ['new_accession1'], 'check verify fuzzy match response content');

my $fuzzy_option_data = {
    "option_form1" => { "fuzzy_name" => "test_accessionx", "fuzzy_select" => "test_accession1", "fuzzy_option" => "replace" },
    "option_form2" => { "fuzzy_name" => "test_accessiony", "fuzzy_select" => "test_accession1", "fuzzy_option" => "synonymize" },
    "option_form3" => { "fuzzy_name" => "test_accessionz", "fuzzy_select" => "test_accession1", "fuzzy_option" => "keep" }
};

$mech->post_ok('http://localhost:3010/ajax/accession_list/fuzzy_options', [ "accession_list_id"=> '3', "fuzzy_option_data"=>$json->encode($fuzzy_option_data), "names_to_add"=>$json->encode($response->{'absent'}) ]);
my $final_response = decode_json $mech->content;
print STDERR Dumper $final_response;

is_deeply($final_response, {'names_to_add' => ['new_accession1','test_accessionz'],'success' => '1'}, 'check verify fuzzy options response content');

$mech->get_ok('http://localhost:3010/organism/verify_name?species_name='.uri_encode("Manihot esculenta") );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'success' => '1'});

my @full_info;
foreach (@{$final_response->{'names_to_add'}}){
    push @full_info, {
        'species'=>'Manihot esculenta',
        'defaultDisplayName'=>$_,
        'germplasmName'=>$_,
        'organizationName'=>'test',
        'populationName'=>'population_ajax_test_1',
    }
}

$mech->post_ok('http://localhost:3010/ajax/accession_list/add', [ 'full_info'=>$json->encode(\@full_info), 'allowed_organisms'=>$json->encode(['Manihot esculenta']) ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'added' => [[41303,'new_accession1'],[41305,'test_accessionz']],'success' => '1'});

#Remove added synonym so tests downstream do not fail.
my $stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accession1'})->stock_id();
my $stock = CXGN::Chado::Stock->new($schema,$stock_id);
$stock->remove_synonym('test_accessiony');

#Remove added stocks so tests downstream do not fail
my $stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accessionz'})->stock_id();
my $stock = CXGN::Chado::Stock->new($schema,$stock_id);
$stock->set_is_obsolete(1) ;
$stock->store();
my $stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'new_accession1'})->stock_id();
my $stock = CXGN::Chado::Stock->new($schema,$stock_id);
$stock->set_is_obsolete(1) ;
$stock->store();

#remove added population so tets downstreadm do not fail
my $population = $schema->resultset("Stock::Stock")->find({uniquename => 'population_ajax_test_1'});
$population->delete();

done_testing();