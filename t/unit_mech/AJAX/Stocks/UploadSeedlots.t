
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::List;
use CXGN::Stock::Seedlot;
use SGN::Model::Cvterm;

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

my $file = $f->config->{basepath}."/t/data/stock/seedlot_upload_named_accessions.xlsx";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/seedlot-upload',
        Content_Type => 'form-data',
        Content => [
            seedlot_uploaded_file => [ $file, 'seedlot_upload_named_accessions.xlsx', Content_Type => 'application/vnd.ms-excel', ],
            "upload_seedlot_breeding_program_id"=>$breeding_program_id,
            "upload_seedlot_location"=>'test_location',
            "upload_seedlot_organization_name"=>"testorg1",
            "upload_seedlot_material_type"=>"seed",
            "sgn_session_id"=>$sgn_session_id
        ]
    );

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new->decode($message);

is_deeply($message_hash->{'success'}, 1);
my $added_seedlot = $message_hash->{'added_seedlot'};

#test uploading with invalid source
my $error_file = $f->config->{basepath}."/t/data/stock/seedlot_upload_named_accessions_error.xlsx";
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/seedlot-upload',
        Content_Type => 'form-data',
        Content => [
            seedlot_uploaded_file => [ $error_file, 'seedlot_upload_named_accessions_error.xlsx', Content_Type => 'application/vnd.ms-excel', ],
            "upload_seedlot_breeding_program_id"=>$breeding_program_id,
            "upload_seedlot_location"=>'test_location',
            "upload_seedlot_organization_name"=>"testorg1",
            "upload_seedlot_material_type"=>"seed",
            "sgn_session_id"=>$sgn_session_id
        ]
    );

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new->decode($message);
is($message_hash->{'error_string'}, 'The source name: test_trial21 is not linked to the same accession as the access content: test_accession1<br><br>');

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
            "upload_seedlot_material_type"=>"seed",
            "sgn_session_id"=>$sgn_session_id
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new()->decode($message);

is_deeply($message_hash->{'success'}, 1);
my $added_seedlot2 = $message_hash->{'added_seedlot'};

#test seedlot_inventory csv upload with weight info
$file = $f->config->{basepath}."/t/data/stock/seedlot_inventory_android_app.csv";
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/seedlot-inventory-upload',
        Content_Type => 'form-data',
        Content => [
            seedlot_uploaded_inventory_file => [ $file, 'seedlot_inventory_android_app.csv'],
            "sgn_session_id"=>$sgn_session_id
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
$message = $response->decoded_content;
$message_hash = JSON::XS->new()->decode($message);
#print STDERR Dumper $message_hash;
is_deeply($message_hash, {'success' => 1});

my $seedlot4_stock_id = $schema->resultset('Stock::Stock')->find({ name => 'test_accession4_001' })->stock_id();
my $seedlot4 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot4_stock_id);
my $seedlot4_weight = $seedlot4->current_weight;
is($seedlot4_weight, 10);

my $seedlot3_stock_id = $schema->resultset('Stock::Stock')->find({ name => 'test_accession3_001' })->stock_id();
my $seedlot3 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot3_stock_id);
my $seedlot3_weight = $seedlot3->current_weight;
is($seedlot3_weight, 12);

my $seedlot2_stock_id = $schema->resultset('Stock::Stock')->find({ name => 'test_accession2_001' })->stock_id();
my $seedlot2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot2_stock_id);
my $seedlot2_weight = $seedlot2->current_weight;
is($seedlot2_weight, 0);

#test seedlot_inventory xlsx upload with amount info
$file = $f->config->{basepath}."/t/data/stock/seedlot_inventory_amount.xlsx";
$ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/breeders/seedlot-inventory-upload',
        Content_Type => 'form-data',
        Content => [
            seedlot_uploaded_inventory_file => [ $file, 'seedlot_inventory_amount.xlsx', Content_Type => 'application/vnd.ms-excel'],
            "sgn_session_id"=>$sgn_session_id
        ]
    );

ok($response->is_success);
$message = $response->decoded_content;
$message_hash = JSON::XS->new()->decode($message);
is_deeply($message_hash, {'success' => 1});

my $seedlot4_2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot4_stock_id);
my $seedlot4_count = $seedlot4_2->current_count;
is($seedlot4_count, 100);

my $seedlot3_2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot3_stock_id);
my $seedlot3_count = $seedlot3_2->current_count;
is($seedlot3_count, 110);

my $seedlot2_2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot2_stock_id);
my $seedlot2_count = $seedlot2_2->current_count;
is($seedlot2_count, 120);

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
is($first_row->{'material_type'}, 'seed');
is($first_row->{'current_count'}, '10');
is($first_row->{'box_name'}, 'box1');
is($first_row->{'quality'}, 'mold');

is($third_row->{'seedlot_name'}, 'seedlot_test_from_cross_1');
is($third_row->{'content_name'}, 'cross_test1');
is($third_row->{'content_type'}, 'cross');
is($third_row->{'material_type'}, 'seed');
is($third_row->{'current_count'}, '5');
is($third_row->{'box_name'}, 'b1');
is($third_row->{'quality'}, '');

#test uploading transactions
#from existing seedlots to new seedlots
my $seedlot_test2_id = $schema->resultset('Stock::Stock')->find({ name => 'seedlot_test2' })->stock_id();
my $seedlot_test2_before = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_id);
is($seedlot_test2_before->current_count, 99, "check current count before transferring");

my $file_1 = $f->config->{basepath}."/t/data/stock/seedlots_to_new_seedlots.xlsx";
my $ua_1 = LWP::UserAgent->new;
my $response_1 = $ua_1->post(
        'http://localhost:3010/ajax/breeders/upload_transactions',
        Content_Type => 'form-data',
        Content => [
            seedlots_to_new_seedlots_file => [ $file_1, "seedlots_to_new_seedlots.xlsx", Content_Type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
            "new_seedlot_breeding_program_id"=>$breeding_program_id,
            "new_seedlot_location"=>'test_location',
            "new_seedlot_organization_name"=>"testorg1",
            "sgn_session_id"=>$sgn_session_id
        ]
    );

ok($response_1->is_success);
my $message_1 = $response_1->decoded_content;
my $message_hash_1 = decode_json $message_1;
is_deeply($message_hash_1, { 'success' => 1 });

my $seedlot_test2_after = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_id);
is($seedlot_test2_after->current_count, 49, "check current count after transferring");

#check new seedlots
my $seedlot_test2_1_id = $schema->resultset('Stock::Stock')->find({ name => 'seedlot_test2_1' })->stock_id();
my $seedlot_test2_1 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_1_id);
is($seedlot_test2_1->current_count, 30, "check current count for new seedlot");

my $seedlot_test2_2_id = $schema->resultset('Stock::Stock')->find({ name => 'seedlot_test2_2' })->stock_id();
my $seedlot_test2_2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_2_id);
is($seedlot_test2_2->current_count, 20, "check current count for new seedlot");

#from existing seedlots to existing seedlots
my $file_2 = $f->config->{basepath}."/t/data/stock/seedlots_to_seedlots.xlsx";
my $ua_2 = LWP::UserAgent->new;
my $response_2 = $ua_2->post(
        'http://localhost:3010/ajax/breeders/upload_transactions',
        Content_Type => 'form-data',
        Content => [
            seedlots_to_seedlots_file => [ $file_2, "seedlots_to_seedlots.xlsx", Content_Type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
            "sgn_session_id"=>$sgn_session_id
        ]
    );

ok($response_2->is_success);
my $message_2 = $response_2->decoded_content;
my $message_hash_2 = decode_json $message_2;
is_deeply($message_hash_2, { 'success' => 1 });

my $seedlot_test2_after_2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_id);
is($seedlot_test2_after_2->current_count, 34, "check current count after transferring");

my $seedlot_test2_1_after_2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_1_id);
is($seedlot_test2_1_after_2->current_count, 40, "check current count after adding");

my $seedlot_test2_2_after_2 = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_2_id);
is($seedlot_test2_2_after_2->current_count, 25, "check current count after adding");

#add seedlots for plots
my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();
my $seedlot_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'seedlot', 'stock_type')->cvterm_id();

my $new_seedlot_1 = CXGN::Stock::Seedlot->new(schema => $schema);
my $test_accession4_id = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accession4'})->stock_id;
$new_seedlot_1->uniquename("test_seedlot_4");
$new_seedlot_1->location_code("XYZ-123");
$new_seedlot_1->accession_stock_id($test_accession4_id);
$new_seedlot_1->organization_name('bti');
$new_seedlot_1->breeding_program_id($breeding_program_id);
my $return_1 = $new_seedlot_1->store();
my $test_seedlot_4_id = $return_1->{seedlot_id};

my $trans_1 = CXGN::Stock::Seedlot::Transaction->new(schema => $schema,);
$trans_1->from_stock([$test_accession4_id, 'test_accession4', $accession_type_id]);
$trans_1->to_stock([$test_seedlot_4_id, 'test_seedlot_4', $seedlot_type_id]);
$trans_1->amount(50);
$trans_1->timestamp(localtime);
$trans_1->description('test');
$trans_1->operator('janedoe');
my $trans_id_1 = $trans_1->store();

my $new_seedlot_2 = CXGN::Stock::Seedlot->new(schema => $schema);
my $test_accession5_id = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accession5'})->stock_id;
$new_seedlot_2->uniquename("test_seedlot_5");
$new_seedlot_2->location_code("XYZ-123");
$new_seedlot_2->accession_stock_id($test_accession5_id);
$new_seedlot_2->organization_name('bti');
$new_seedlot_2->breeding_program_id($breeding_program_id);
my $return_2 = $new_seedlot_2->store();
my $test_seedlot_5_id = $return_2->{seedlot_id};

my $trans_2 = CXGN::Stock::Seedlot::Transaction->new(schema => $schema,);
$trans_2->from_stock([$test_accession5_id, 'test_accession5', $accession_type_id]);
$trans_2->to_stock([$test_seedlot_5_id, 'test_seedlot_5', $seedlot_type_id]);
$trans_2->amount(40);
$trans_2->timestamp(localtime);
$trans_2->description('test');
$trans_2->operator('janedoe');
my $trans_id_2 = $trans_2->store();

my $file_3 = $f->config->{basepath}."/t/data/stock/seedlots_to_plots.xlsx";
my $ua_3 = LWP::UserAgent->new;
my $response_3 = $ua_3->post(
        'http://localhost:3010/ajax/breeders/upload_transactions',
        Content_Type => 'form-data',
        Content => [
            seedlots_to_plots_file => [ $file_3, "seedlots_to_plots.xlsx", Content_Type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
            "sgn_session_id"=>$sgn_session_id
        ]
    );

ok($response_3->is_success);
my $message_3 = $response_3->decoded_content;
my $message_hash_3 = decode_json $message_3;
print STDERR "MESSAGE HASH =".Dumper($message_hash_3)."\n";
is_deeply($message_hash_3, { 'success' => 1 });

my $test_seedlot_4_after = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $test_seedlot_4_id);
is($test_seedlot_4_after->current_count, 45, "check current count after being transferred to plot");

my $test_seedlot_5_after = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $test_seedlot_5_id);
is($test_seedlot_5_after->current_count, 35, "check current count after being transferred to plot");

#from existing seedlots to unspecified names
my $file_4 = $f->config->{basepath}."/t/data/stock/seedlots_to_unspecified.xlsx";
my $ua_4 = LWP::UserAgent->new;
my $response_4 = $ua_4->post(
    'http://localhost:3010/ajax/breeders/upload_transactions',
    Content_Type => 'form-data',
    Content => [
        seedlots_to_unspecified_names_file => [ $file_4, "seedlots_to_unspecified.xlsx", Content_Type => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
        "sgn_session_id"=>$sgn_session_id
    ]
);

ok($response_4->is_success);
my $message_4 = $response_4->decoded_content;
my $message_hash_4 = decode_json $message_4;
is_deeply($message_hash_4, { 'success' => 1 });

my $seedlot_test2_1_after_removed = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_1_id);
is($seedlot_test2_1_after_removed->current_count, 38, "check current count after removing seeds");

my $seedlot_test2_2_after_removed = CXGN::Stock::Seedlot->new(schema => $schema, seedlot_id => $seedlot_test2_2_id);
is($seedlot_test2_2_after_removed->current_count, 23, "check current count after removing seeds");

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

#test retrieving accession seedlot info
my $test_accession1_id = $schema->resultset('Stock::Stock')->find({ name => 'test_accession1' })->stock_id();
$mech->post_ok("http://localhost:3010/ajax/stock/stock_related_seedlots/$test_accession1_id");
$response = decode_json $mech->content;
my $all_seedlots = $response->{data};
my $number_of_seedlots = scalar (@$all_seedlots);
my $seedlot_info = $all_seedlots->[0];
my $seedlot_name = $seedlot_info->{seedlot_stock_uniquename};
my $amount = $seedlot_info->{count};
my $weight_gram = $seedlot_info->{weight_gram};
my $seedlot_quality = $seedlot_info->{seedlot_quality};
my $material_type = $seedlot_info->{material_type};
my $box_name = $seedlot_info->{box};
my $location = $seedlot_info->{location};
my $breeding_program_name = $seedlot_info->{breeding_program_name};
is($number_of_seedlots, 1);
is($seedlot_name, 'seedlot_test1');
is($amount, 10);
is($weight_gram, 12);
is($seedlot_quality, 'mold');
is($material_type, 'seed');
is($box_name, 'box1');
is($location, 'test_location');
is($breeding_program_name, 'test');

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
