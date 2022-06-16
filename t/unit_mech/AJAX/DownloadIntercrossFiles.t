use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::List;
use Data::Dumper;
use JSON;
use CXGN::Pedigree::AddCrossingtrial;


local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

#adding crossing experiment and lists for downloaded files
$mech->post_ok('http://localhost:3010/ajax/cross/add_crossingtrial', [ 'crossingtrial_name' => 'crossing_experiment_1', 'crossingtrial_program_id' => 134 ,
    'crossingtrial_location' => 'test_location', 'year' => '2022', 'project_description' => 'test description' ]);

$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $crossing_experiment_rs = $schema->resultset('Project::Project')->find({name =>'crossing_experiment_1'});
my $crossing_experiment_id = $crossing_experiment_rs->project_id();

$mech->get_ok('http://localhost:3010/list/new?name=accession_list&desc=test');
$response = decode_json $mech->content;
my $accession_list_id = $response->{list_id};
ok($accession_list_id);

my @accessions = qw(UG120001 UG120002 UG120003 UG120004);

my $accession_list = CXGN::List->new( { dbh=>$dbh, list_id => $accession_list_id });
$response = $accession_list->add_bulk(\@accessions);
is($response->{'count'},4);

#test creating intercross parents file
$mech->post_ok('http://localhost:3010/ajax/intercross/create_parents_file?female_list_id='.$accession_list_id.'&male_list_id='.$accession_list_id.'&crossing_experiment_id='.$crossing_experiment_id);
$response = decode_json $mech->content;

my $parents_rows = $response->{'data'};

is_deeply($parents_rows, [
    [38878,'0','UG120001'],
    [38879,'0','UG120002'],
    [38880,'0','UG120003'],
    [38881,'0','UG120004'],
    [38878,'1','UG120001'],
    [38879,'1','UG120002'],
    [38880,'1','UG120003'],
    [38881,'1','UG120004']
    ], 'intercross parents');

#test creating intercross wishlist
my @data = ({'female_name'=> 'UG120001','male_name'=> 'UG120002','activity_info'=> 'flower,10,100'},{'female_name'=> 'UG120002','male_name'=> 'UG120003','activity_info'=> 'flower,5,50'},{'female_name'=> 'UG120003','male_name'=> 'UG120004','activity_info'=> 'flower,100,200'});
my $data_string = encode_json(\@data);

$mech->post_ok('http://localhost:3010/ajax/intercross/create_intercross_wishlist?wishlist_data='.$data_string.'&crossing_experiment_id='.$crossing_experiment_id);
$response = decode_json $mech->content;

my $wishlist_rows = $response->{'data'};

is_deeply($wishlist_rows, [
    [38878,38879,'UG120001','UG120002','flower','10','100'],
    [38879,38880,'UG120002','UG120003','flower','5','50'],
    [38880,38881,'UG120003','UG120004','flower','100','200']
    ], 'intercross wishlist');

# remove crossing experiment after test
my $delete_experiment = $crossing_experiment_rs->delete();
my $delete_list = CXGN::List::delete_list($f->dbh(), $accession_list_id);

$f->clean_up_db();
done_testing();
