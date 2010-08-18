=head1 NAME

t/integration/account-confirm.t - tests for solpeople/account-confirm.pl

=head1 DESCRIPTION

Tests for account-confirm.t

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More tests => 2;
use Test::JSON;
use Test::WWW::Mechanize;
BAIL_OUT "Need to set the SGN_TEST_SERVER environment variable" unless $ENV{SGN_TEST_SERVER};

my $base_url = $ENV{SGN_TEST_SERVER};
my $mech = Test::WWW::Mechanize->new;
my $url = "/solpeople/account-confirm.pl";
$mech->get_ok("$base_url/$url?username=fiddlestix");
$mech->content_like(qr/.*Sorry, we are unable to process this confirmation request\..*No confirmation is required for user .*fiddlestix/ms);

