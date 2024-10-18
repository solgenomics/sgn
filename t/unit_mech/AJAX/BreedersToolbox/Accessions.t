
# Tests all functions in SGN::Controller::AJAX::Accessions. These are the functions called from Accessions.js when adding new accessions.

use strict;
use warnings;
use utf8;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
use URI::Encode qw(uri_encode uri_decode);
use CXGN::Chado::Stock;
use LWP::UserAgent;
use CXGN::List;
use CXGN::Stock::Accession;
use Encode;

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;
my $json = JSON->new->allow_nonref;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

$mech->post_ok('http://localhost:3010/ajax/accession_list/verify', [ "accession_list"=> '["new_accession1", "test_accession1", "test_accessionx", "test_accessiony", "test_accessionД"]', "do_fuzzy_search"=> "true" ]);
print STDERR "CONTENTS: ".$mech->content;
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
    "option_form3" => { "fuzzy_name" => "test_accessionД", "fuzzy_select" => "test_accession1", "fuzzy_option" => "keep" }
};

$mech->post_ok('http://localhost:3010/ajax/accession_list/fuzzy_options', [ "accession_list_id"=> '3', "fuzzy_option_data"=>$json->encode($fuzzy_option_data), "names_to_add"=>$json->encode($response->{'absent'}) ]);

print STDERR $mech->content;
my $final_response = decode_json $mech->content;
print STDERR Dumper $final_response;

is_deeply($final_response, {'names_to_add' => ['new_accession1','test_accessionД'],'success' => '1'}, 'check verify fuzzy options response content');

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
    };
}

$mech->post_ok('http://localhost:3010/ajax/accession_list/add', [ 'full_info'=>$json->encode(\@full_info), 'allowed_organisms'=>$json->encode(['Manihot esculenta']) ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;

my $acc1 = 'new_accession1';
my $acc2 = 'test_accessionД';
my $check1row = $schema->resultset('Stock::Stock')->find({ uniquename => $acc1 });
my $check2row = $schema->resultset('Stock::Stock')->find({ uniquename => $acc2 });

is_deeply($response, {'added' => [[ $check1row->stock_id(),'new_accession1'],[$check2row->stock_id(),'test_accessionД']],'success' => '1'}, "added accessions check");

#Remove added synonym so tests downstream do not fail.
my $stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accession1'})->stock_id();
my $stock = CXGN::Chado::Stock->new($schema,$stock_id);
$stock->remove_synonym('test_accessiony');

#Remove added stocks so tests downstream do not fail
#my $accession_name = encode('utf8', 'test_accessionД');
$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>$acc2})->stock_id();
$stock = CXGN::Chado::Stock->new($schema,$stock_id);
$stock->set_is_obsolete(1) ;
$stock->store();
my @stock_ids;
push @stock_ids, $stock_id;

$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'new_accession1'})->stock_id();
$stock = CXGN::Chado::Stock->new($schema,$stock_id);
$stock->set_is_obsolete(1) ;
$stock->store();
push @stock_ids, $stock_id;

#remove added population so tets downstreadm do not fail
my $population = $schema->resultset("Stock::Stock")->find({uniquename => 'population_ajax_test_1'});
$population->delete();

# Test uploading accession file
my $file = $f->config->{basepath}."/t/data/stock/test_accession_upload.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/accessions/verify_accessions_file',
        Content_Type => 'form-data',
        Content => [
            new_accessions_upload_file => [ $file, 'test_accession_upload', Content_Type => 'application/vnd.ms-excel', ],
            "sgn_session_id"=>$sgn_session_id,
            "fuzzy_check_upload_accessions"=>1
        ]
    );

#print STDERR Dumper $response;
ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR Dumper $message_hash;

#is_deeply($message_hash->{'full_data'}, {'new_test_accession03' => {'accessionNumber' => 'ITC00003','germplasmName' => 'new_test_accession03','populationName' => 'test_population','defaultDisplayName' => 'new_test_accession03','organizationName' => 'test_organization','countryOfOriginCode' => 'Nigeria','synonyms' => ['new_test_accession3_synonym1'],'species' => 'Manihot esculenta'},'IITA-TMS-IBA010749' => {'populationName' => 'test_population','species' => 'Manihot esculenta','organizationName' => undef,'defaultDisplayName' => 'IITA-TMS-IBA010749','germplasmName' => 'IITA-TMS-IBA010749','synonyms' => ['IITA-TMS-IBA010746_synonym1','IITA-TMS-IBA010746_synonym2']},'new_test_accession02' => {'populationName' => 'test_population','defaultDisplayName' => 'new_test_accession02','organizationName' => 'test_organization','accessionNumber' => 'ITC00002','germplasmName' => 'new_test_accession02','species' => 'Manihot esculenta','countryOfOriginCode' => 'Nigeria','synonyms' => []},'new_test_accession04' => {'defaultDisplayName' => 'new_test_accession04','organizationName' => 'test_organization','populationName' => 'test_population','germplasmName' => 'new_test_accession04','accessionNumber' => 'ITC00004','species' => 'Manihot esculenta','synonyms' => [],'countryOfOriginCode' => 'Nigeria'},'new_test_accession01' => {'organizationName' => 'test_organization','defaultDisplayName' => 'new_test_accession01','populationName' => 'test_population','germplasmName' => 'new_test_accession01','locationCode' => 'ITH','accessionNumber' => 'ITC00001','ploidyLevel' => '2','species' => 'Manihot esculenta','synonyms' => ['new_test_accession_synonym1','new_test_accession_synonym2','new_test_accession_synonym3'],'countryOfOriginCode' => 'Nigeria'}}, 'check parsed accession file');


is_deeply($message_hash->{full_data}, {'new_test_accession02' => {'accessionNumber' => 'ITC00002','defaultDisplayName' => 'new_test_accession02','synonyms' => [],'germplasmName' => 'new_test_accession02','organizationName' => 'test_organization','countryOfOriginCode' => 'Nigeria','species' => 'Manihot esculenta','populationName' => 'test_population','description' => ''},'new_test_accession01' => {'germplasmName' => 'new_test_accession01','synonyms' => ['new_test_accession_synonym1','new_test_accession_synonym2','new_test_accession_synonym3'],'defaultDisplayName' => 'new_test_accession01','accessionNumber' => 'ITC00001','description' => 'the best','locationCode' => 'ITH','countryOfOriginCode' => 'Nigeria','species' => 'Manihot esculenta','ploidyLevel' => '2','populationName' => 'test_population|xyz','organizationName' => 'test_organization'},'IITA-TMS-IBA010749' => {'organizationName' => undef,'populationName' => 'test_population','species' => 'Manihot esculenta','description' => '','defaultDisplayName' => 'IITA-TMS-IBA010749','synonyms' => ['IITA-TMS-IBA010746_synonym1','IITA-TMS-IBA010746_synonym2'],'germplasmName' => 'IITA-TMS-IBA010749'},'new_test_accession04' => {'description' => '','species' => 'Manihot esculenta','populationName' => 'test_population','countryOfOriginCode' => 'Nigeria','organizationName' => 'test_organization','germplasmName' => 'new_test_accession04','synonyms' => [],'defaultDisplayName' => 'new_test_accession04','accessionNumber' => 'ITC00004'},'new_test_accession03' => {'organizationName' => 'test_organization','description' => '','countryOfOriginCode' => 'Nigeria','populationName' => 'test_population','species' => 'Manihot esculenta','defaultDisplayName' => 'new_test_accession03','accessionNumber' => 'ITC00003','germplasmName' => 'new_test_accession03','synonyms' => ['new_test_accession3_synonym1']}}, 'check parsed accession file');


is(scalar @{$message_hash->{'fuzzy'}}, 1, 'check verify fuzzy match response content');
is_deeply($message_hash->{'found'}, [], 'check verify fuzzy match response content');
is(scalar @{$message_hash->{'absent'}}, 4, 'check verify fuzzy match response content');
is_deeply($message_hash->{'found_organisms'}, [{'unique_name' => 'Manihot esculenta','matched_string' => 'Manihot esculenta'}], 'check verify fuzzy match response content');

my @full_info2;
foreach (keys %{$message_hash->{'full_data'}}){
    push @full_info2, $message_hash->{'full_data'}->{$_};
}

$mech->post_ok('http://localhost:3010/ajax/accession_list/add', [ 'full_info'=>$json->encode(\@full_info2), 'allowed_organisms'=>$json->encode(['Manihot esculenta']) ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;

is(scalar @{$response->{'added'}}, 5);

#Remove added list so tests downstream pass
my $list_id = $message_hash->{list_id};
CXGN::List::delete_list($schema->storage->dbh, $list_id);

############## test upload file for Email functionality ###################
my $file2 = $f->config->{basepath}."/t/data/stock/test_accession_email_upload.xlsx";
my $email_address;
my $session_id;

my $verify_response = $ua->post(
    'http://localhost:3010/ajax/accessions/verify_accessions_file',
    Content_Type => 'form-data',
    Content => [
        new_accessions_upload_file => [ $file2, 'test_accession_email_upload.xlsx', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id" => $session_id,
        "fuzzy_check_upload_accessions" => 1,
    ]
);
ok($verify_response->is_success, 'Verify accessions file request successful');
my $verify_message = $verify_response->decoded_content;
my $verify_hash;
eval { $verify_hash = decode_json($verify_message); };
ok(!$@, 'Verify response is valid JSON') or diag("JSON parse error: $@");
diag("Verify response: " . Dumper($verify_hash));

SKIP: {
    skip "Verification failed, cannot proceed with adding accessions", 1 unless $verify_hash && $verify_hash->{success};

    # Now, add the accessions
    my $add_response = $ua->post(
        'http://localhost:3010/ajax/accession_list/add',
        Content_Type => 'form-data',
        Content => [
            full_info => encode_json($verify_hash->{full_data}),
            allowed_organisms => encode_json(['Solanum lycopersicum']),
            "sgn_session_id" => $sgn_session_id,
            "email_address_upload" => $email_address,
        ]
    );

    ok($add_response->is_success, 'Add accessions request successful');
    my $add_message = $add_response->decoded_content;
    my $add_hash;
    eval { $add_hash = decode_json($add_message); };
    ok(!$@, 'Add response is valid JSON') or diag("JSON parse error: $@");
    diag("Add response: " . Dumper($add_hash));

    ok($add_hash->{success}, 'Accessions added successfully');
    is(scalar @{$add_hash->{added}}, 2, 'Two accessions were added');
}

#Remove added list so tests downstream pass
# Clean up
if ($verify_hash && $verify_hash->{list_id}) {
    CXGN::List::delete_list($schema->storage->dbh, $verify_hash->{list_id});
}

###############################

# test upload of synonym append / replace function
my $synonyms_file = $f->config->{basepath}."/t/data/stock/test_accession_upload_synonyms.xls";
$response = $ua->post(
    'http://localhost:3010/ajax/accessions/verify_accessions_file',
    Content_Type => 'form-data',
    Content => [
        new_accessions_upload_file => [ $synonyms_file, 'test_accession_upload', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id"=>$sgn_session_id,
        "fuzzy_check_upload_accessions"=>1,
        "append_synonyms"=>1
    ]
);
ok($response->is_success);
my $resp_append = decode_json $response->decoded_content;
is_deeply($resp_append->{'full_data'}->{'new_test_accession03'}->{'synonyms'}, ['new_test_accession3_synonym1','new_test_accession3_synonym2']);

$response = $ua->post(
    'http://localhost:3010/ajax/accessions/verify_accessions_file',
    Content_Type => 'form-data',
    Content => [
        new_accessions_upload_file => [ $synonyms_file, 'test_accession_upload', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id"=>$sgn_session_id,
        "fuzzy_check_upload_accessions"=>1,
        "append_synonyms"=>0
    ]
);
ok($response->is_success);
my $resp_replace = decode_json $response->decoded_content;
is_deeply($resp_replace->{'full_data'}->{'new_test_accession03'}->{'synonyms'}, ['new_test_accession3_synonym2']);

#Remove added stocks so tests downstream do not fail, but also test if for attributes
$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'new_test_accession01'})->stock_id();
$stock = CXGN::Stock::Accession->new(schema=>$schema,stock_id=>$stock_id);
is($stock->organization_name, 'test_organization');
is($stock->population_name, 'test_population,xyz');
is($stock->ploidyLevel, '2');
is($stock->locationCode, 'ITH');
is($stock->countryOfOriginCode, 'Nigeria');
is($stock->accessionNumber, 'ITC00001');
is_deeply($stock->synonyms, ['new_test_accession_synonym1','new_test_accession_synonym2','new_test_accession_synonym3']);
$stock->is_obsolete(1) ;
$stock->store();
push @stock_ids, $stock_id;

$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'new_test_accession02'})->stock_id();
$stock = CXGN::Stock::Accession->new(schema=>$schema,stock_id=>$stock_id);
is($stock->organization_name, 'test_organization');
is($stock->population_name, 'test_population');
is($stock->countryOfOriginCode, 'Nigeria');
is($stock->accessionNumber, 'ITC00002');
$stock->is_obsolete(1) ;
$stock->store();
push @stock_ids, $stock_id;

$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'new_test_accession03'})->stock_id();
$stock = CXGN::Stock::Accession->new(schema=>$schema,stock_id=>$stock_id);
is($stock->organization_name, 'test_organization');
is($stock->population_name, 'test_population');
is_deeply($stock->synonyms, ['new_test_accession3_synonym1']);
is($stock->countryOfOriginCode, 'Nigeria');
is($stock->accessionNumber, 'ITC00003');
$stock->is_obsolete(1) ;
$stock->store();
push @stock_ids, $stock_id;

$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'new_test_accession04'})->stock_id();
$stock = CXGN::Stock::Accession->new(schema=>$schema,stock_id=>$stock_id);
is($stock->organization_name, 'test_organization');
is($stock->population_name, 'test_population');
is($stock->countryOfOriginCode, 'Nigeria');
is($stock->accessionNumber, 'ITC00004');
$stock->is_obsolete(1) ;
$stock->store();
push @stock_ids, $stock_id;

$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'IITA-TMS-IBA010749'})->stock_id();
$stock = CXGN::Stock::Accession->new(schema=>$schema,stock_id=>$stock_id);
is($stock->population_name, 'test_population');
is_deeply($stock->synonyms, ['IITA-TMS-IBA010746_synonym1','IITA-TMS-IBA010746_synonym2']);
$stock->is_obsolete(1) ;
$stock->store();
push @stock_ids, $stock_id;

#remove added population so tets downstreadm do not fail
$population = $schema->resultset("Stock::Stock")->find({uniquename => 'test_population'});
$population->delete();


# Delete stocks created
my $dbh = $schema->storage->dbh;
my $q = "delete from phenome.stock_owner where stock_id=?";
my $h = $dbh->prepare($q);

foreach (@stock_ids){
    my $row  = $schema->resultset('Stock::Stock')->find({stock_id=>$_});
    $h->execute($_);
    $row->delete();
}

$f->clean_up_db();

done_testing();
