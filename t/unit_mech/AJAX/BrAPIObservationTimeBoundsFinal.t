use strict;
use warnings;
use Test::More;
use JSON::XS qw(encode_json decode_json);
use LWP::UserAgent;
use URI;

my $base=$ENV{SGN_TEST_SERVER} || 'http://localhost:3010';
my $ua=LWP::UserAgent->new(timeout=>30);
my $login=$ua->post("$base/brapi/v1/token",[username=>'janedoe',password=>'secretpw',grant_type=>'password']);
my $token=eval{decode_json($login->decoded_content)->{access_token}};
BAIL_OUT('Fixture HTTP login unavailable') if !$token;
$ua->default_header(Authorization=>"Bearer $token");
for my $version(qw(v1 v2)){
    my $uri=URI->new("$base/brapi/$version/observations");
    $uri->query_form(studyDbId=>137,observationLevel=>'plot',pageSize=>1,observationTimeStampRangeStart=>'2026-11-02T00:00:00Z');
    my $valid=$ua->get($uri);
    is($valid->code,200,"$version valid timestamp GET control");
    ok(eval{ref(decode_json($valid->decoded_content))eq'HASH'},"$version valid control returns JSON");
    for my $bound(qw(observationTimeStampRangeStart observationTimeStampRangeEnd)){
        $uri->query_form(studyDbId=>137,observationLevel=>'plot',pageSize=>1,$bound=>'not-a-timestamp');
        my $r=$ua->get($uri);
        my $json=eval{decode_json($r->decoded_content)};
        my $excerpt=$r->decoded_content =~ s/<[^>]*>/ /gr;
        $excerpt =~ s/\s+/ /g;
        my($error)=$excerpt =~ /((?:Invalid timestamp|Caught exception).{0,500})/;
        diag(encode_json({version=>$version,bound=>$bound,http_status=>$r->code,content_type=>$r->header('Content-Type'),json=>ref($json)eq'HASH'?1:0,status=>ref($json)eq'HASH'?$json->{metadata}{status}:undef,error=>$error||substr($excerpt,0,100)}));
        is($r->code,400,"$version invalid $bound is a controlled client error");
        ok(ref($json)eq'HASH' && (grep {($_->{messageType}//'') eq'ERROR'} @{$json->{metadata}{status}||[]}),"$version invalid $bound has JSON ERROR metadata");
    }
}
done_testing;
