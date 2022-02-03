use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CXGN::List;
use CXGN::Genotype::Protocol;
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
#print STDERR "CROSSING EXPERIMENT ID =".Dumper($crossing_experiment_id)."\n";

$mech->get_ok('http://localhost:3010/list/new?name=accession_list&desc=test');
$response = decode_json $mech->content;
my $accession_list_id = $response->{list_id};
#print STDERR "FEMALE LIST ID =".Dumper($accession_list_id)."\n";
ok($accession_list_id);

my @accessions = qw(UG120001 UG120002 UG120003 UG120004);

my $accession_list = CXGN::List->new( { dbh=>$dbh, list_id => $accession_list_id });
$response = $accession_list->add_bulk(\@accessions);
is($response->{'count'},4);

$mech->post_ok('http://localhost:3010/ajax/intercross/download_parents_file?female_list_id='.$accession_list_id.'&male_list_id='.$accession_list_id.'&crossing_experiment_id='.$crossing_experiment_id);
$response = decode_json $mech->content;

my $rows = $response->{'data'};

is_deeply($rows, [
    [1446,'0','UG120001'],
    [1447,'0','UG120002'],
    [1448,'0','UG120003'],
    [1449,'0','UG120004'],
    [1446,'1','UG120001'],
    [1447,'1','UG120002'],
    [1448,'1','UG120003'],
    [1449,'1','UG120004']
    ], 'intercross parents');





done_testing();
