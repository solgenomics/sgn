=head1 NAME

t/validate/feature.t - validation tests for feature.pl

=head1 DESCRIPTION

Validation tests for feature.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use warnings;
use Test::More;
use Test::WWW::Mechanize;

use lib 't/lib';
use SGN::Test qw/validate_urls/;

my $base_url      = "/feature.pl";

SKIP: {
    validate_urls({
        "feature request with nonexistent name" => "$base_url?name=this_does_not_exist",
        "feature request with id" => "$base_url?id=12721702",
    });
}

done_testing;

