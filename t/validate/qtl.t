=head1 NAME

population.t - tests for cgi-bin/phenome/population*

=head1 DESCRIPTION

Tests for cgi-bin/phenome/population/*

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More;
use Test::WWW::Mechanize;
BAIL_OUT "Need to set the SGN_TEST_SERVER environment variable" unless $ENV{SGN_TEST_SERVER};

use lib 't/lib';
use SGN::Test qw/validate_urls/;

my $base_url = $ENV{SGN_TEST_SERVER};
my $url      = "/phenome/population_indls.pl?population_id=12&cvterm_id=47515";

my $mech = Test::WWW::Mechanize->new;
$mech->get("$base_url/$url");
if ($mech->content =~ m/temp dir .* not found|Failed to obtain lock/) {
    plan skip_all => "Skipping QTL Analysis page due to production temp dir not working";
} else {
    plan tests => 3;
    validate_urls({ "QTL Analysis Page" => $url });
}
