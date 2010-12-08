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

use lib 't/lib';
use SGN::Test qw/validate_urls/;

my $base_url = $ENV{SGN_TEST_SERVER};
my $url      = "/phenome/population_indls.pl?population_id=12&cvterm_id=47515";

my $mech = Test::WWW::Mechanize->new;
$mech->get("$base_url/$url");
if ($mech->content =~ m/temp dir .* not (found|writable)|Failed to obtain lock|failed to submit cluster job/) {
    plan skip_all => "Skipping QTL Analysis page due to incomplete configuration";
} else {
    validate_urls({
        "QTL Analysis Page" => $url ,
        });
}

done_testing;
