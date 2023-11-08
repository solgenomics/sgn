
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::List;
use CXGN::Stock::Seedlot;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON::XS;
use SGN::Model::Cvterm;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;

# get highest nd_experiment
my $rs = $f->bcs_schema()->resultset('NaturalDiversity::NdExperiment')->search({});

my $max_nd_experiment_id = $rs->get_column('nd_experiment_id')->max();

print STDERR "MAX ND EXPERIMENT ID = $max_nd_experiment_id\n";

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

#test uploading transactions
#from existing seedlots to new seedlots
my $seedlot_test2_id = $schema->resultset('Stock::Stock')->find({ name => 'seedlot_test2' })->stock_id();
my $seedlot_test2_before = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_id);
is($seedlot_test2_before->current_count, 99, "check current count before transferring");

my $file = $f->config->{basepath}."/t/data/stock/seedlots_to_new_seedlots.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/upload_transactions',
        Content_Type => 'form-data',
        Content => [
            seedlots_to_new_seedlots_file => [ $file, 'seedlot_upload', Content_Type => 'application/vnd.ms-excel'],
            "new_seedlot_breeding_program_id"=>$breeding_program_id,
            "new_seedlot_location"=>'test_location',
            "new_seedlot_organization_name"=>"testorg1",
            "sgn_session_id"=>$sgn_session_id
        ]
    );

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is_deeply($message_hash, { 'success' => 1 });

my $seedlot_test2_after = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_id);
is($seedlot_test2_after->current_count, 49, "check current count after transferring");

#check new seedlots
my $seedlot_test2_1_id = $schema->resultset('Stock::Stock')->find({ name => 'seedlot_test2_1' })->stock_id();
my $seedlot_test2_1 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_1_id);
is($seedlot_test2_1->current_count, 30, "check current count for new seedlot");

my $seedlot_test2_2_id = $schema->resultset('Stock::Stock')->find({ name => 'seedlot_test2_2' })->stock_id();
my $seedlot_test2_2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_2_id);
is($seedlot_test2_2->current_count, 20, "check current count for new seedlot");


#test discarding seedlot
my $seedlot_test1_rs = $schema->resultset('Stock::Stock')->find({ name => 'seedlot_test1' });
my $seedlot_test1_id = $seedlot_test1_rs->stock_id();

$mech->post_ok('http://localhost:3010/ajax/breeders/seedlot/discard', [ 'seedlot_name' => 'seedlot_test1', 'discard_reason' => 'test' ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

my $seedlot = CXGN::Stock::Seedlot->new(
    schema => $schema,
    phenome_schema => $phenome_schema,
    seedlot_id => $seedlot_test1_id
);

my $current_count = $seedlot->get_current_count_property();
is($current_count, 'DISCARDED');

#test undo discarding seedlot
$mech->post_ok('http://localhost:3010/ajax/breeders/seedlot/undo_discard', [ 'seedlot_id' => $seedlot_test1_id ]);
my $undo_response = decode_json $mech->content;
is($undo_response->{'success'}, '1');

my $undo_seedlot = CXGN::Stock::Seedlot->new(
    schema => $schema,
    phenome_schema => $phenome_schema,
    seedlot_id => $seedlot_test1_id
);

my $undo_current_count = $undo_seedlot->get_current_count_property();
is($undo_current_count, '10');

#delete seedlot list
my $delete = CXGN::List::delete_list($f->dbh(), $seedlot_list_id);

#Clean up

END{
    #Remove seedlots

    print STDERR "REMOVING SEEDLOTS... ";

    my $dbh = $f->dbh();
    my $seedlot_ids = join ("," , @$added_seedlot);
    my $seedlot_ids2 = join ("," , @$added_seedlot2);

    my $q = "delete from phenome.stock_owner where stock_id in ($seedlot_ids);";
    $q .= "delete from phenome.stock_owner where stock_id in ($seedlot_ids2);";
    $q .= "delete from stock where stock_id in ($seedlot_ids);";
    $q .= "delete from stock where stock_id in ($seedlot_ids2);";
    $q .= "delete from nd_experiment where nd_experiment_id > ".$max_nd_experiment_id;
    my $sth = $dbh->prepare($q);
    $sth->execute;

    my $cvterm_id = SGN::Model::Cvterm->get_cvterm_row($f->bcs_schema(), 'seed transaction', 'stock_relationship')->cvterm_id();
    #remove transactions
    my $row = $schema->resultset("Stock::Stock")->find({ name => 'test_accession2_001' });

    my  $rel_rs = $schema->resultset("Stock::StockRelationship")->search({ subject_id => $row->stock_id, type_id => $cvterm_id });
    foreach my $rel_row ($rel_rs->all()) {
	print STDERR "TYPE_ID = ".$rel_row->type_id()."\n";
	#$rel_row->delete();
    }


    $row = $schema->resultset("Stock::Stock")->find({ name => 'test_accession4_001' });

    $rel_rs = $schema->resultset("Stock::StockRelationship")->search({ subject_id => $row->stock_id, type_id => $cvterm_id });
    foreach my $rel_row ($rel_rs->all()) {
	#	$rel_row->delete();
	print STDERR "TYPE_ID = ".$rel_row->type_id()."\n";
    }

    $row = $schema->resultset("Stock::Stock")->find({ name => 'test_accession3_001' });

    $rel_rs = $schema->resultset("Stock::StockRelationship")->search({ subject_id => $row->stock_id, type_id => $cvterm_id });
    foreach my $rel_row ($rel_rs->all()) {

	print STDERR "TYPE_ID = ".$rel_row->type_id()."\n";
	#	    $rel_row->delete();
    }

    print STDERR "DONE.\n";
}

$f->clean_up_db();

done_testing();
