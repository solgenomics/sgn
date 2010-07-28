=head1 NAME

t/validate/cview.t - validation tests for cview/map.pl

=head1 DESCRIPTION

Validation tests for cview/map.pl

=head1 AUTHORS

Jonathan "Duke" Leto

=cut

use strict;
use Test::More;
use Test::WWW::Mechanize;
BAIL_OUT "Need to set the SGN_TEST_SERVER environment variable" unless $ENV{SGN_TEST_SERVER};
use SGN::Test qw/validate_urls/;

my $base_url = $ENV{SGN_TEST_SERVER};
my $url      = "/cview/map.pl?map_id=c9";

my $mech = Test::WWW::Mechanize->new;
$mech->get("$base_url/$url");
if ($mech->content =~ m/No database found/) {
    plan skip_all => "Skipping Contig map due to missing database";
} else {
    plan tests => 3;
    validate_urls({ "Contig map" => $url });
}
