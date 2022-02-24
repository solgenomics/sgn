
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::List;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON::XS;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = JSON::XS->new->decode($mech->content);
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

my $breeding_program_id = $schema->resultset('Project::Project')->find({name=>'test'})->project_id();

my $file = $f->config->{basepath}."/t/data/stock/seedlot_upload_named_accessions";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/seedlot-upload',
        Content_Type => 'form-data',
        Content => [
            seedlot_uploaded_file => [ $file, 'seedlot_upload', Content_Type => 'application/vnd.ms-excel', ],
            "upload_seedlot_breeding_program_id"=>$breeding_program_id,
            "upload_seedlot_location"=>'test_location',
            "upload_seedlot_organization_name"=>"testorg1",
            "sgn_session_id"=>$sgn_session_id
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
print STDERR "MESSAGE: $message\n";
my $message_hash = JSON::XS->new->decode($message);

is_deeply($message_hash->{'success'}, 1);
my $added_seedlot = $message_hash->{'added_seedlot'};


$file = $f->config->{basepath}."/t/data/stock/seedlot_upload_harvested";
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/seedlot-upload',
        Content_Type => 'form-data',
        Content => [
            seedlot_harvested_uploaded_file => [ $file, 'seedlot_harvested_upload', Content_Type => 'application/vnd.ms-excel', ],
            "upload_seedlot_breeding_program_id"=>$breeding_program_id,
            "upload_seedlot_location"=>'test_location',
            "upload_seedlot_organization_name"=>"testorg1",
            "sgn_session_id"=>$sgn_session_id
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new()->decode($message);

is_deeply($message_hash->{'success'}, 1);
my $added_seedlot2 = $message_hash->{'added_seedlot'};

$file = $f->config->{basepath}."/t/data/stock/seedlot_inventory_android_app";
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/seedlot-inventory-upload',
        Content_Type => 'form-data',
        Content => [
            seedlot_uploaded_inventory_file => [ $file, 'seedlot_inventory_upload', Content_Type => 'application/vnd.ms-excel', ],
            "sgn_session_id"=>$sgn_session_id
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = JSON::XS->new()->decode($message);
print STDERR Dumper $message_hash;
is_deeply($message_hash, {'success' => 1});

#test seedlot list details
my $seedlot_list_id = CXGN::List::create_list($f->dbh(), 'test_seedlot_list', 'test_desc', 41);
my $seedlot_list = CXGN::List->new( { dbh => $f->dbh(), list_id => $seedlot_list_id } );
$seedlot_list->type("seedlots");
$seedlot_list->add_bulk(['seedlot_test1','seedlot_test2','seedlot_test_from_cross_1','seedlot_test_from_cross_2']);
my $items = $seedlot_list->elements;

$mech->get_ok("http://localhost:3010/ajax/list/details/$seedlot_list_id");
$response = decode_json $mech->content;

my $results = $response->{'data'};
my @seedlots = @$results;
my $number_of_rows = scalar(@seedlots);
is($number_of_rows, 4);
my $first_row = $seedlots[0];
my $third_row = $seedlots[2];

is($first_row->{'seedlot_name'}, 'seedlot_test1');
is($first_row->{'content_name'}, 'test_accession1');
is($first_row->{'content_type'}, 'accession');
is($first_row->{'current_count'}, '10');
is($first_row->{'box_name'}, 'box1');
is($first_row->{'quality'}, 'mold');

is($third_row->{'seedlot_name'}, 'seedlot_test_from_cross_1');
is($third_row->{'content_name'}, 'cross_test1');
is($third_row->{'content_type'}, 'cross');
is($third_row->{'current_count'}, '5');
is($third_row->{'box_name'}, 'b1');
is($third_row->{'quality'}, '');

#delete seedlot list
my $delete = CXGN::List::delete_list($f->dbh(), $seedlot_list_id);

#Clean up

END{
    #Remove seedlots
    my $dbh = $f->dbh();
    my $seedlot_ids = join ("," , @$added_seedlot);
    my $seedlot_ids2 = join ("," , @$added_seedlot2);

    my $q = "delete from phenome.stock_owner where stock_id in ($seedlot_ids);";
    $q .= "delete from phenome.stock_owner where stock_id in ($seedlot_ids2);";
    $q .= "delete from stock where stock_id in ($seedlot_ids);";
    $q .= "delete from stock where stock_id in ($seedlot_ids2);";
    my $sth = $dbh->prepare($q);
    $sth->execute;

    #remove transactions
    my $rs = $schema->resultset("Stock::Stock")->find({ name => 'test_accession2_001' });
    my $row = $schema->resultset("Stock::StockRelationship")->find({ subject_id => $rs->stock_id });
    $row->delete();

    my $rs = $schema->resultset("Stock::Stock")->find({ name => 'test_accession4_001' });
    my $row = $schema->resultset("Stock::StockRelationship")->find({ subject_id => $rs->stock_id });
    $row->delete();

    my $rs = $schema->resultset("Stock::Stock")->find({ name => 'test_accession3_001' });
    my $row = $schema->resultset("Stock::StockRelationship")->find({ subject_id => $rs->stock_id });
    $row->delete();
}

done_testing();
