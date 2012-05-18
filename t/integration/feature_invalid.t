=head1 NAME

t/integration/feature_invalid.t - integration tests for invalid feature URLs

=head1 DESCRIPTION

Tests for feature URLs

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use lib 't/lib';
BEGIN { $ENV{SGN_SKIP_CGI} = 1 }
use SGN::Test::WWW::Mechanize;

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get("/feature/JUNK/details");
is($mech->status, 404, 'status is 404');
$mech->content_contains("Feature not found");

$mech->get("/feature/-1/details");
is($mech->status, 400, 'status is 400');
$mech->content_contains("positive integer");

$mech->get("/feature/JUNK/details");
is($mech->status, 404, 'status is 404');

done_testing;
