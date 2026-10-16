
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
$response = decode_json $mech->content;
my $access_token = $response->{access_token};
$mech->default_header("Content-Type" => "application/json");
$mech->default_header('Authorization'=> 'Bearer ' . $access_token);

# Keep going when a call fails, so every case below is reported
sub get_json {
    my ($url, $name) = @_;
    $mech->get($url);
    is($mech->status, 200, $name || "GET $url");
    return eval { decode_json($mech->content) } || {};
}

# phenotypes-search passed an end index instead of a row count as LIMIT
$response = get_json('http://localhost:3010/brapi/v1/phenotypes-search?pageSize=2');
is(scalar(@{$response->{result}->{data} || []}), 2, 'phenotypes-search page 0 returns pageSize rows');
$response = get_json('http://localhost:3010/brapi/v1/phenotypes-search?pageSize=3&page=1');
is(scalar(@{$response->{result}->{data} || []}), 3, 'phenotypes-search page 1 returns pageSize rows');

# trials returned every row on every page, and died when nothing matched
$response = get_json('http://localhost:3010/brapi/v1/trials?pageSize=1000');
my @all_trials = map { $_->{trialDbId} } @{$response->{result}->{data} || []};
my $trial_count = $response->{metadata}->{pagination}->{totalCount};
is(scalar(@all_trials), $trial_count, 'trials total count matches unpaged rows');
ok($trial_count >= 1, 'fixture has at least one trial');

$response = get_json('http://localhost:3010/brapi/v1/trials?pageSize=1&page=0');
is_deeply([ map { $_->{trialDbId} } @{$response->{result}->{data} || []} ], [ $all_trials[0] ], 'trials page 0 returns only the first row');
is($response->{metadata}->{pagination}->{totalCount}, $trial_count, 'trials paging keeps the total count');

$response = get_json("http://localhost:3010/brapi/v1/trials?pageSize=1&page=$trial_count");
is_deeply($response->{result}->{data}, [], 'trials page past the last row is empty');

$response = get_json('http://localhost:3010/brapi/v1/trials?programDbId=999999999');
is_deeply($response->{result}->{data}, [], 'trials with no matching program returns an empty list');

# CXGN::BrAPI::v1::Studies::observation_units() had the identical
# page_size*(page+1)-1 LIMIT bug as v1 ObservationUnits.pm: page 0 returned
# one row fewer than pageSize, and later pages returned more than pageSize.
$response = get_json('http://localhost:3010/brapi/v1/studies/165/observationunits?pageSize=2&page=0');
is(scalar(@{$response->{result}->{data} || []}), 2, 'studies/{id}/observationunits page 0 returns pageSize rows');
$response = get_json('http://localhost:3010/brapi/v1/studies/165/observationunits?pageSize=3&page=1');
is(scalar(@{$response->{result}->{data} || []}), 3, 'studies/{id}/observationunits page 1 returns pageSize rows');

$f->clean_up_db();

done_testing();
