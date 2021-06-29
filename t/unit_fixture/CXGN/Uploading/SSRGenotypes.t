use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::Dataset;
use CXGN::Dataset::Cache;
use CXGN::Genotype::Protocol;
use CXGN::Genotype::Search;
use Bio::GeneticRelationships::Pedigree;
use CXGN::Pedigree::AddPedigrees;
use Bio::GeneticRelationships::Individual;
use CXGN::List;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $dbh = $schema->storage->dbh;
my $people_schema = $f->people_schema;

my $mech = Test::WWW::Mechanize->new;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

#test uploading SSR marker info
my $file = $f->config->{basepath}."/t/data/genotype_data/ssr_marker_info.xls";

my $ua = LWP::UserAgent->new;
$response = $ua->post(
    'http://localhost:3010/ajax/genotype/upload_ssr_protocol',
    Content_Type => 'form-data',
    Content => [
        "xls_ssr_protocol_file" => [ $file, 'ssr_marker_info.xls', Content_Type => 'application/vnd.ms-excel', ],
        "sgn_session_id" => $sgn_session_id,
        "upload_ssr_protocol_name" => "SSR_protocol_1",
        "upload_ssr_protocol_description_input" => "test SSR marker info upload",
        "upload_ssr_species_name_input" => "Manihot esculenta",
        "upload_ssr_sample_type_select" => "accession"
    ]
);

ok($response->is_success);
my $message = $response->decoded_content;
my $message_hash = decode_json $message;
is_deeply($message_hash, {'success' => 1});

done_testing();
