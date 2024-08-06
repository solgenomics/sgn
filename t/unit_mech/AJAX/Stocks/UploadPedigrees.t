use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use Data::Dumper;
use JSON::XS;
use SGN::Model::Cvterm;

local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = JSON::XS->new->decode($mech->content);
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $file = $f->config->{basepath}."/t/data/cross/pedigree_upload.xlsx";
my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/pedigrees/upload_verify',
    Content_Type => 'form-data',
    Content => [
        pedigrees_uploaded_file => [ $file, 'pedigree_upload.xlsx', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id"=>$sgn_session_id
    ]
);

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = JSON::XS->new->decode($message);
my $pedigrees_string = $message_hash->{'pedigree_data'};
my $pedigrees = decode_json $pedigrees_string;
my $rows = $pedigrees->{'pedigrees'};

is($rows->[0]->{'progeny name'}, 'XG120251');
is($rows->[0]->{'female parent accession'}, 'XG120261');
is($rows->[0]->{'male parent accession'}, 'XG120273');
is($rows->[0]->{'type'}, 'biparental');
is($rows->[1]->{'progeny name'}, 'XG120273');
is($rows->[1]->{'female parent accession'}, 'XG120261');
is($rows->[1]->{'male parent accession'}, 'XG120261');
is($rows->[1]->{'type'}, 'self');

$mech->post_ok('http://localhost:3010/ajax/pedigrees/upload_store', [ 'pedigree_data' => $pedigrees_string ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');

#checking pedigrees
my $XG120251_id = $schema->resultset('Stock::Stock')->find({ name => 'XG120251' })->stock_id();
my $XG120273_id = $schema->resultset('Stock::Stock')->find({ name => 'XG120273' })->stock_id();
my $XG120261_id = $schema->resultset('Stock::Stock')->find({ name => 'XG120261' })->stock_id();

my $female_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'female_parent', 'stock_relationship')->cvterm_id();
my $male_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'male_parent', 'stock_relationship')->cvterm_id();

my $rs_1 = $schema->resultset("Stock::StockRelationship")->find( { type_id=>$female_cvterm_id, object_id => $XG120251_id } );
my $female_parent_id_1 = $rs_1->subject_id;
my $cross_type_1 = $rs_1->value;

my $rs_2 = $schema->resultset("Stock::StockRelationship")->find( { type_id=>$male_cvterm_id, object_id => $XG120251_id } );
my $male_parent_id_1 = $rs_2->subject_id;

is($female_parent_id_1, $XG120261_id);
is($male_parent_id_1, $XG120273_id);
is($cross_type_1, 'biparental');

my $rs_3 = $schema->resultset("Stock::StockRelationship")->find( { type_id=>$female_cvterm_id, object_id => $XG120273_id } );
my $female_parent_id_2 = $rs_3->subject_id;
my $cross_type_2 = $rs_3->value;

my $rs_4 = $schema->resultset("Stock::StockRelationship")->find( { type_id=>$male_cvterm_id, object_id => $XG120273_id } );
my $male_parent_id_2 = $rs_4->subject_id;

is($female_parent_id_2, $XG120261_id);
is($male_parent_id_2, $XG120261_id);
is($cross_type_2, 'self');

$f->clean_up_db();

done_testing();
