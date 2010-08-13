=head1 NAME

t/validate/feature.t - validation tests for feature.pl

=head1 DESCRIPTION

Validation tests for feature.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More tests => 6;
use Test::WWW::Mechanize;
BAIL_OUT "Need to set the SGN_TEST_SERVER environment variable" unless $ENV{SGN_TEST_SERVER};

use lib 't/lib';
use SGN::Test qw/validate_urls/;

my $base_url      = "/feature.pl";

SKIP: {
    validate_urls({
        "feature request with nonexistent name" => "$base_url?name=this_does_not_exist",
        "feature request with id" => "$base_url?id=12721702",
    });
}
