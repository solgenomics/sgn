
# Tests all functions in SGN::Controller::AJAX::Vectors.

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
use CXGN::Stock::Vector;
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


#Start test adding some vectors data
my $fuzzy_option_data = {
    "option_form1" => { "fuzzy_name" => "test_vector_x", "fuzzy_select" => "test_vector1", "fuzzy_option" => "replace" },
    "option_form2" => { "fuzzy_name" => "test_vector_y", "fuzzy_select" => "test_vector1", "fuzzy_option" => "keep" },
    "option_form3" => { "fuzzy_name" => "test_vector_m", "fuzzy_select" => "test_vector1", "fuzzy_option" => "keep" }
};

$mech->post_ok('http://localhost:3010/ajax/vector_list/fuzzy_options', [ "vector_list_id"=> '3', "fuzzy_option_data"=>$json->encode($fuzzy_option_data), "names_to_add"=>$json->encode($response->{'absent'}) ]);

my $final_response = decode_json $mech->content;
is_deeply($final_response, {'names_to_add' => ['test_vector_m','test_vector_y'],'success' => '1'}, 'check verify fuzzy options response content');

$mech->get_ok('http://localhost:3010/organism/verify_name?species_name='.uri_encode("Manihot esculenta") );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'success' => '1'});

my @full_info;
foreach (@{$final_response->{'names_to_add'}}){
    push @full_info, {
        'species_name'=>'Manihot esculenta',
        'defaultDisplayName'=>$_,
        'uniqueName'=>$_,
    };
}

$mech->post_ok('http://localhost:3010/ajax/create_vector_construct', [ 'data'=>$json->encode(\@full_info), 'allowed_organisms'=>$json->encode(['Manihot esculenta']) ]);
$response = decode_json $mech->content;
print STDERR "\n\n response: " . Dumper $response;

my $acc1 = 'test_vector_m';
my $acc2 = 'test_vector_y';
my $check1row = $schema->resultset('Stock::Stock')->find({ uniquename => $acc1 });
my $check2row = $schema->resultset('Stock::Stock')->find({ uniquename => $acc2 });

is_deeply($response, {'added' => [[$check1row->stock_id(),'test_vector_m'],[ $check2row->stock_id(),'test_vector_y']],'success' => '1', 'response' => '' }, "added vectors check");


#Remove added stocks so tests downstream do not fail

my $stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>$acc2})->stock_id();
my $stock = CXGN::Chado::Stock->new($schema,$stock_id);
$stock->set_is_obsolete(1) ;
$stock->store();
my @stock_ids;
push @stock_ids, $stock_id;

$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'test_vector_m'})->stock_id();
$stock = CXGN::Chado::Stock->new($schema,$stock_id);
$stock->set_is_obsolete(1) ;
$stock->store();
push @stock_ids, $stock_id;


# Test uploading vector file
my $file = $f->config->{basepath}."/t/data/stock/test_vector_upload.xls";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
        'http://localhost:3010/ajax/vectors/verify_vectors_file',
        Content_Type => 'form-data',
        Content => [
            new_vectors_upload_file => [ $file, 'test_vector_upload', Content_Type => 'application/vnd.ms-excel', ],
            "sgn_session_id"=>$sgn_session_id,
            "fuzzy_check_upload_vectors"=>1
        ]
    );

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
print STDERR "\n\n#Test line 118: " . Dumper $message_hash;

is_deeply($message_hash->{'full_data'},  {'vector3' => {'germplasmName' => 'vector3','Strain' => 'St-XL1-Blue-MRF`','species_name' => 'Manihot esculenta','SelectionMarker' => 'Kan/Amp','CloningOrganism' => 'E. coli','VectorType' => 'Nitab','Gene' => 'gene3','Backbone' => 'CL','CassetteName' => 'Pr35S35S-Biogemma ExArabidopsis yeast -glg 2-like TeCaMV polyA-Biogemma','Terminators' => 'TeCaMV','uniqueName' => 'vector3','InherentMarker' => 'Tetracycline','Promotors' => 'Pr35S35S-Biogemma'},'vector2' => {'Backbone' => 'CL','CassetteName' => 'Pr35S35S-Biogemma ExArabidopsis  yeast-glg2-like  TeCaMV polyA-Biogemma','uniqueName' => 'vector2','InherentMarker' => 'Tetracycline','Promotors' => 'Pr35S35S-Biogemma','species_name' => 'Manihot esculenta','Strain' => 'St-XL1-Blue-MRF`','germplasmName' => 'vector2','SelectionMarker' => 'Kan/Amp','CloningOrganism' => 'E. coli','VectorType' => 'Nitab_constructs','Gene' => 'gene2'},'vector1' => {'uniqueName' => 'vector1','Promotors' => 'PrLEAF','InherentMarker' => 'Streptomycin','Backbone' => 'BNP','CassetteName' => 'PrLEAF Ex3\' subsequence of tobacco pol TeNOS','Terminators' => 'TeNOS','CloningOrganism' => 'A. tumefaciens','VectorType' => 'Nitab_constructs','Gene' => 'gene1','Strain' => 'St-LBA-4404','species_name' => 'Manihot esculenta','germplasmName' => 'vector1','SelectionMarker' => 'Kanamycin'}}, 'check parse vector file');

is(scalar @{$message_hash->{'fuzzy'}}, 0, 'check verify fuzzy match response content');
is_deeply($message_hash->{'found'}, [], 'check verify fuzzy match response content');
is(scalar @{$message_hash->{'absent'}}, 3, 'check verify fuzzy match response content');
is_deeply($message_hash->{'found_organisms'}, [{'unique_name' => 'Manihot esculenta','matched_string' => 'Manihot esculenta'}], 'check verify fuzzy match response content');

my @full_info2;
foreach (keys %{$message_hash->{'full_data'}}){
    push @full_info2, $message_hash->{'full_data'}->{$_};
}

$mech->post_ok('http://localhost:3010/ajax/create_vector_construct', [ 'data'=>$json->encode(\@full_info2), 'allowed_organisms'=>$json->encode(['Manihot esculenta']) ]);
$response = decode_json $mech->content;
is(scalar @{$response->{'added'}}, 3);

#Remove added list so tests downstream pass
my $list_id = $message_hash->{list_id};
CXGN::List::delete_list($schema->storage->dbh, $list_id);

#Remove added stocks so tests downstream do not fail, but also test if for attributes
$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'vector1'})->stock_id();
$stock = CXGN::Stock::Vector->new(schema=>$schema,stock_id=>$stock_id);
is($stock->VectorType, 'Nitab_constructs');
is($stock->Strain, 'St-LBA-4404');
is($stock->CloningOrganism, 'A. tumefaciens');
is($stock->InherentMarker, 'Streptomycin');
is($stock->Backbone, 'BNP');
is($stock->SelectionMarker, 'Kanamycin');
is($stock->CassetteName, "PrLEAF Ex3' subsequence of tobacco pol TeNOS");
is($stock->Gene, 'gene1');
is($stock->Promotors, 'PrLEAF');
is($stock->Terminators, 'TeNOS');

$stock->is_obsolete(1) ;
$stock->store();
push @stock_ids, $stock_id;

$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'vector2'})->stock_id();
push @stock_ids, $stock_id;

$stock_id = $schema->resultset('Stock::Stock')->find({uniquename=>'vector3'})->stock_id();
push @stock_ids, $stock_id;


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
