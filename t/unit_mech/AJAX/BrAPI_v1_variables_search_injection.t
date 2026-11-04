
use strict;
use warnings;

# Regression test for commit 18174a0ebe ("Use placeholders for BrAPI v1
# variable and observation level filters"). CXGN::BrAPI::v1::ObservationVariables::search
# pasted the name/datatype/ontologyXref request values into the SQL string.
# /brapi/v1/variables-search does not call _authenticate_user, so this was
# reachable without logging in.

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use URI::Escape qw(uri_escape);

my $f = SGN::Test::Fixture->new();

# Anonymous on purpose: the endpoint takes no session token.
my $mech = Test::WWW::Mechanize->new;

sub get_search {
    my ($params) = @_;
    my $qs = join '&', map { "$_=" . uri_escape($params->{$_}) } keys %$params;
    my $url = 'http://localhost:3010/brapi/v1/variables-search?' . $qs;
    $mech->get($url);
    return $mech;
}

# 1) A single quote in each interpolated filter used to break the SQL string
# outright (syntax error -> 500). With placeholders it is just a literal
# value that matches no variable.
for my $case (
    { param => 'name',        label => 'name' },
    { param => 'datatype',    label => 'datatype' },
    { param => 'ontologyXref', label => 'ontologyXref' },
) {
    get_search({ $case->{param} => "quote'test" });
    is($mech->status, 200, "variables-search with a quote in $case->{label} does not error");
    my $response = eval { decode_json($mech->content) };
    ok($response, "variables-search with a quote in $case->{label} returns parseable JSON")
        or diag("content: " . $mech->content);
    is($response->{metadata}->{pagination}->{totalCount}, 0,
        "variables-search with a quote in $case->{label} matches nothing")
        if $response;
}

# 2) A classic boolean-injection payload in datatype used to turn
# "cvtermprop.value = '$_'" into an always-true condition and return every
# variable instead of zero.
get_search({ datatype => "nonexistent' OR '1'='1" });
is($mech->status, 200, 'variables-search with a boolean payload in datatype does not error');
my $response = decode_json($mech->content);
is($response->{metadata}->{pagination}->{totalCount}, 0,
    'variables-search with a boolean payload in datatype matches nothing (injection closed)');

$f->clean_up_db();

done_testing();
