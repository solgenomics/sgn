=head1 NAME

t/validate/feature.t - validation tests for feature.pl

=head1 DESCRIPTION

Validation tests for feature.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More tests => 3;
use Test::WWW::Mechanize;
BAIL_OUT "Need to set the SGN_TEST_SERVER environment variable" unless $ENV{SGN_TEST_SERVER};
use SGN::Test qw/validate_urls/;

my $base_url = $ENV{SGN_TEST_SERVER};
my $url      = "/cgi-bin/feature.pl?name=this_does_not_exist";

SKIP: {
    my $mech = Test::WWW::Mechanize->new;
    $mech->get("$base_url/$url");
    validate_urls({ "Basic feature request" => $url });
}
