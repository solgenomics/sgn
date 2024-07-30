use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use Data::Dumper;
use JSON::XS;
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
is($rows->[2]->{'progeny name'}, 'XG120251');
is($rows->[2]->{'female parent accession'}, 'XG120287');
is($rows->[2]->{'male parent accession'}, undef);
is($rows->[2]->{'type'}, 'open');

$mech->post_ok('http://localhost:3010/ajax/pedigrees/upload_store', [ 'pedigree_data' => $pedigrees_string ]);
$response = decode_json $mech->content;
is($response->{'success'}, '1');


$f->clean_up_db();

done_testing();
