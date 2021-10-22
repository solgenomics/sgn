

# Tests trial deletion functions as they are used from the trial detail page through AJAX requests

use strict;
use warnings;

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
use CXGN::Trial;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $metadata_schema = $f->metadata_schema;
my $phenome_schema = $f->phenome_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;
my $json = JSON->new->allow_nonref;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};

my $project_rs = $schema->resultset("Project::Project")->find({name=>'CASS_6Genotypes_Sampling_2015'});
my $project_id = $project_rs->project_id;

my $trial = CXGN::Trial->new({
    bcs_schema => $schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $project_id
});

my $traits_assayed = $trial->get_traits_assayed();
my @trait_ids;
foreach (@$traits_assayed){
    push @trait_ids, $_->[0];
}

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$project_id.'/delete/layout');
$response = decode_json $mech->content;
print STDERR Dumper $response;
ok($response->{'error'});

$mech->post_ok('http://localhost:3010/ajax/breeders/trial/'.$project_id.'/delete_single_trait', [ "traits_id"=> encode_json(\@trait_ids) ]);
$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'success' => 1});

$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$project_id.'/delete/layout');

sleep(30); # deletion script takes time... (?)

$response = decode_json $mech->content;
print STDERR Dumper $response;
is_deeply($response, {'message' => 'Successfully deleted trial data.','success' => 1}, 'test trial layout + entry deletion');

my $project_rs_after_delete = $schema->resultset("Project::Project")->find({name=>'CASS_6Genotypes_Sampling_2015'});
ok(!$project_rs_after_delete);

my $plot_rs_after_delete = $schema->resultset("Stock::Stock")->find({name=>'CASS_6Genotypes_103'});
ok(!$plot_rs_after_delete);

done_testing();
